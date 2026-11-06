-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local GoldTracker = LibTSMService:Init("Ledger.GoldTracker")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Reactive = LibTSMService:From("LibTSMReactive"):Include("Reactive")
local GoldLog = LibTSMService:From("LibTSMTypes"):IncludeClassType("GoldLog")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Guild = LibTSMService:From("LibTSMWoW"):Include("API.Guild")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	goldStream = nil, ---@type ReactiveStream<number?>
	warbankGoldStream = nil, ---@type ReactiveStream<number?>
	warbankString = nil,
	isPlayerFunc = nil,
	truncateGoldLog = {},
	characterLog = {}, ---@type table<string,GoldLog>
	characterLastUpdate = {}, ---@type table<string,number>
	guildLog = {}, ---@type table<string,GoldLog>
	guildLastUpdate = {}, ---@type table<string,number>
	warbankLog = nil, ---@type GoldLog?
	warbankLogLastUpdate = nil, ---@type number?
	currentCharacterKey = nil, ---@type string
	playerLogCount = 0,
	playerGoldRetryTimer = nil,
}
local SECONDS_PER_MIN = 60
local SECONDS_PER_DAY = 60 * 60 * 24
local COPPER_PER_GOLD = 10000



-- ============================================================================
-- Module Loading
-- ============================================================================

GoldTracker:OnModuleLoad(function()
	private.goldStream = Reactive.GetStream(function() return nil end)
	private.warbankGoldStream = Reactive.GetStream(function() return nil end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the gold tracking code.
---@param warbankString string The localized string to use for the warbank
---@param isPlayerFunc fun(name: string): boolean Function that checks if a character belongs to the player
function GoldTracker.Configure(warbankString, isPlayerFunc)
	private.warbankString = warbankString
	private.isPlayerFunc = isPlayerFunc
end

---Creates a publisher for the current character's money amount.
---@return ReactivePublisherSchema<number>
function GoldTracker.MoneyPublisher()
	return private.goldStream:Publisher()
		:IgnoreNil()
end

---Creates a publisher for the warbank money amount.
---@return ReactivePublisherSchema<number>
function GoldTracker.WarbankMoneyPublisher()
	return private.warbankGoldStream:Publisher()
		:IgnoreNil()
end

---Loads character gold data.
---@param characterKey string The character key
---@param data string The serialized data
---@param lastUpdate number The last update time
function GoldTracker.LoadCharacter(characterKey, data, lastUpdate)
	assert(not private.characterLog[characterKey])
	local log = GoldLog.Load(data)
	if log then
		log:Clean()
		private.characterLastUpdate[characterKey] = lastUpdate
		private.characterLog[characterKey] = log
	else
		Log.Err("Failed to decode (%s, %d)", characterKey, #data)
		private.characterLog[characterKey] = GoldLog.New()
	end
end

---Loads guild gold data.
---@param guild string The name of the guild
---@param data string The serialized data
---@param lastUpdate table<string,number?> The last update time
---@param isValid boolean Whether or not the guild is valid
function GoldTracker.LoadGuild(guild, data, lastUpdate, isValid)
	local log = GoldLog.Load(data) or GoldLog.New()
	private.guildLog[guild] = log
	local endMinute = log:GetEndMinute()
	local lastEntryTime = endMinute and endMinute * SECONDS_PER_MIN or math.huge
	if not isValid and max(lastEntryTime, lastUpdate[guild] or 0) < floor(LibTSMService.GetTime()) - 30 * SECONDS_PER_DAY then
		-- This guild may not be valid and the last entry is over 30 days old, so truncate the data
		private.truncateGoldLog[guild] = lastEntryTime
	end
end

---Loads warbank gold data.
---@param data string The serialized data
---@param lastUpdate number The last update time
function GoldTracker.LoadWarbank(data, lastUpdate)
	assert(not private.warbankLog)
	local log = GoldLog.Load(data) or GoldLog.New()
	log:Clean()
	private.warbankLog = log
	private.warbankLogLastUpdate = lastUpdate
end

---Starts the gold tracking code.
function GoldTracker.Start()
	private.playerGoldRetryTimer = DelayTimer.New("PLAYER_GOLD_RETRY", private.PlayerLogGold)
	if not LibTSMService.IsVanillaClassic() then
		DefaultUI.RegisterGuildBankVisibleCallback(private.GuildLogGold, true)
		Event.Register("GUILDBANK_UPDATE_MONEY", private.GuildLogGold)
	end
	if LibTSMService.IsRetail() then
		DefaultUI.RegisterBankVisibleCallback(private.WarbankLogGold, true)
		Event.Register("ACCOUNT_MONEY", private.WarbankLogGold)
	end
	Event.Register("PLAYER_MONEY", private.PlayerLogGold)

	private.currentCharacterKey = SessionInfo.FormatCharacterName(SessionInfo.GetCharacterName(), SessionInfo.GetFactionrealmName(), true)
	assert(private.characterLog[private.currentCharacterKey])

	-- Log the current player gold (need to wait for OnEnable, otherwise GetMoney() returns 0 when first logging in)
	private.PlayerLogGold()
	-- Log warbank gold amount
	private.WarbankLogGold()
end

---Saves character gold data.
---@return string data
---@return number lastUpdate
function GoldTracker.SaveCharacter()
	private.PlayerLogGold()
	local log = private.characterLog[private.currentCharacterKey]:Serialize()
	local lastUpdate = private.characterLastUpdate[private.currentCharacterKey]
	return log, lastUpdate
end

---Saves guild gold data.
---@param guild string The guild to save
---@return string? data
---@return number? lastUpdate
function GoldTracker.SaveGuild(guild)
	local log = private.guildLog[guild]
	if not log then
		return nil, nil
	end
	return log:Serialize(), private.guildLastUpdate[guild]
end

---Saves warbank gold data.
---@return string? data
---@return number? lastUpdate
function GoldTracker.SaveWarbank()
	if not private.warbankLog then
		return nil, nil
	end
	return private.warbankLog:Serialize(), private.warbankLogLastUpdate
end

---Gets all the characters and guilds.
---@param resultTbl string[] The table to store the list of characters and guilds in
function GoldTracker.GetCharacterGuilds(resultTbl)
	Table.GetKeys(private.characterLog, resultTbl)
	Table.GetKeys(private.guildLog, resultTbl)
	if private.warbankLog then
		tinsert(resultTbl, private.warbankString)
	end
end

---Gets the gold value at the specified time.
---@param timestamp number The time
---@param ignoredCharactersGuilds table<string,boolean> Whether or not characters / guilds are ignored
---@return number
function GoldTracker.GetGoldAtTime(timestamp, ignoredCharactersGuilds)
	local value = 0
	local timestampMinute = floor(timestamp / SECONDS_PER_MIN)
	for key, log in pairs(private.characterLog) do
		if not ignoredCharactersGuilds[key] and (private.truncateGoldLog[key] or math.huge) > timestamp then
			value = value + log:GetValue(timestampMinute)
		end
	end
	for key, log in pairs(private.guildLog) do
		if not ignoredCharactersGuilds[key] and (private.truncateGoldLog[key] or math.huge) > timestamp then
			value = value + log:GetValue(timestampMinute)
		end
	end
	if private.warbankLog and not ignoredCharactersGuilds[private.warbankString] then
		value = value + private.warbankLog:GetValue(timestampMinute)
	end
	return value
end

---Gets the time range of available data.
---@param ignoredCharactersGuilds table<string,boolean> Whether or not characters / guilds are ignored
---@return number minTime
---@return number maxTime
---@return number interval
function GoldTracker.GetGraphTimeRange(ignoredCharactersGuilds)
	local minTime = Math.Floor(LibTSMService.GetTime(), SECONDS_PER_MIN)
	for key, log in pairs(private.characterLog) do
		if not ignoredCharactersGuilds[key] then
			local startMinute = log:GetStartMinute()
			if startMinute then
				minTime = min(minTime, startMinute * SECONDS_PER_MIN)
			end
		end
	end
	for key, log in pairs(private.guildLog) do
		if not ignoredCharactersGuilds[key] then
			local startMinute = log:GetStartMinute()
			if startMinute then
				minTime = min(minTime, startMinute * SECONDS_PER_MIN)
			end
		end
	end
	if private.warbankLog and not ignoredCharactersGuilds[private.warbankString] then
		local startMinute = private.warbankLog:GetStartMinute()
		if startMinute then
			minTime = min(minTime, startMinute * SECONDS_PER_MIN)
		end
	end
	return minTime, Math.Floor(LibTSMService.GetTime(), SECONDS_PER_MIN), SECONDS_PER_MIN
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GuildLogGold()
	local guild = Guild.GetName()
	local isGuildLeader = Guild.IsLeader()
	if guild and not isGuildLeader then
		-- Check if our alt is the guild leader
		for _, name, isLeader in Guild.MemberIterator() do
			if isLeader and private.isPlayerFunc(name) then
				isGuildLeader = true
			end
		end
	end
	if guild and isGuildLeader then
		if not private.guildLog[guild] then
			private.guildLog[guild] = GoldLog.New()
		end
		local timestamp = floor(LibTSMService.GetTime())
		private.guildLog[guild]:Append(floor(timestamp / SECONDS_PER_MIN), private.RoundCopperValue(Guild.GetMoney()))
		private.guildLastUpdate[guild] = timestamp
	end
end

function private.WarbankLogGold()
	if not private.warbankLog or not Container.CanAccessWarbank() then
		return
	end
	local copper = Container.GetWarbankMoney()
	local currentMinute = floor(LibTSMService.GetTime() / SECONDS_PER_MIN)
	private.warbankLog:Append(currentMinute, private.RoundCopperValue(copper))
	private.warbankLogLastUpdate = floor(LibTSMService.GetTime())
	private.warbankGoldStream:Send(copper)
end

function private.PlayerLogGold()
	-- GetMoney sometimes returns 0 for a while after login, so keep trying for 30 seconds before recording a 0
	local money = Currency.GetMoney()
	if money == 0 and private.playerLogCount < 30 then
		private.playerLogCount = private.playerLogCount + 1
		private.playerGoldRetryTimer:RunForTime(1)
		return
	end
	private.playerLogCount = 0
	local timestamp = floor(LibTSMService.GetTime())
	private.characterLog[private.currentCharacterKey]:Append(floor(timestamp / SECONDS_PER_MIN), private.RoundCopperValue(money))
	private.characterLastUpdate[private.currentCharacterKey] = timestamp
	private.goldStream:Send(money)
end

function private.RoundCopperValue(copper)
	return Math.Round(copper, COPPER_PER_GOLD * ((LibTSMService.IsRetail() and 1000) or ((LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() or LibTSMService.IsForever()) and 1) or 100))
end

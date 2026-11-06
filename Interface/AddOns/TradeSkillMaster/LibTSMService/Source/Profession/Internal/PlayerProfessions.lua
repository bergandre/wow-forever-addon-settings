-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local PlayerProfessions = LibTSMService:InitInternal("Profession.PlayerProfessions")
local Data = LibTSMService:Include("Profession.Data")
local State = LibTSMService:Include("Profession.State")
local Professions = LibTSMService:From("LibTSMData"):Include("Professions")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ProfessionBook = LibTSMService:From("LibTSMWoW"):Include("API.ProfessionBook")
local Spell = LibTSMService:From("LibTSMWoW"):Include("API.Spell")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local CombatLockdown = LibTSMService:From("LibTSMWoW"):Include("Service.CombatLockdown")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	db = nil,
	query = nil,
	scanTimer = nil,
	lastQuery = 0,
	settings = nil,
	forgetTemp = {},
}
local MIN_QUERY_INTERVAL = 3
local MISSING_INFO_DELAY_TIME = 0.1
local FIRST_AID_SPELL_ID = 129

---@class PlayerProfessionsSettings: SettingsView
---@field playerProfessions table<string,PlayerProfessionInfo>

---@class PlayerProfessionInfo
---@field skillId number?
---@field level number
---@field maxLevel number
---@field isSecondary boolean
---@field prompted boolean
---@field link string



-- ============================================================================
-- Module Loading
-- ============================================================================

PlayerProfessions:OnModuleLoad(function()
	private.db = Database.NewSchema("PLAYER_PROFESSIONS")
		:AddStringField("player")
		:AddStringField("profession")
		:AddNumberField("skillId")
		:AddNumberField("level")
		:AddNumberField("maxLevel")
		:AddBooleanField("isSecondary")
		:AddIndex("player")
		:Commit()
	private.query = private.db:NewOwnedQuery()
		:OrderBy("isSecondary", true)
		:OrderBy("level", false)
		:OrderBy("profession", true)
	private.scanTimer = DelayTimer.New("PLAYER_PROFESSIONS_SCAN", private.DoScan)
	Event.Register("SKILL_LINES_CHANGED", private.QueueScan)
	Event.Register("LEARNED_SPELL_IN_SKILL_LINE", private.QueueScan)
	State.RegisterCallback(private.HandleProfessionStateChange)
	private.QueueScan()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the settings.
---@param settings PlayerProfessionsSettings The settings object
function PlayerProfessions.Load(settings)
	private.settings = settings
end

---Gets the current skill level for a given profession.
---@param profession string The profession name
---@return number?
function PlayerProfessions.GetSkill(profession)
	return private.db:NewAutoReleaseQuery()
		:Equal("player", SessionInfo.GetCharacterName())
		:Equal("profession", profession)
		:GetFirstResult("level")
end

---Returns whether or not the specified character has the specified profession.
---@param character string The character name
---@param profession string The profession name
function PlayerProfessions.HasProfession(character, profession)
	return private.db:NewAutoReleaseQuery()
		:Equal("player", character)
		:Equal("profession", profession)
		:IsNotEmpty()
end

---Creates a query for the player professions.
---@return DatabaseQuery
function PlayerProfessions.CreateQuery()
	return private.db:NewOwnedQuery()
end

---Iterates over the player professions.
---@return IteratorObject<fun(): number, string, string, number, number, number> @Iterator with fields: `index`, `player`, `profession`, `skillId`, `level`, `maxLevel`
function PlayerProfessions.Iterator()
	return private.query:Iterator("player", "profession", "skillId", "level", "maxLevel")
end

---Updates the current profession's link.
function PlayerProfessions.UpdateLink()
	local professionName = State.GetCurrentProfession()
	assert(professionName)
	private.settings.playerProfessions[professionName].link = TradeSkill.GetLink()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueueScan()
	private.scanTimer:Cancel()
	private.scanTimer:RunForFrames(0)
end

function private.DoScan()
	if CombatLockdown.IsActive() then
		private.scanTimer:RunForFrames(0)
		return
	end

	if LibTSMService.GetTime() - private.lastQuery > MIN_QUERY_INTERVAL then
		ProfessionBook.Query()
		private.lastQuery = LibTSMService.GetTime()
	end

	if not ProfessionBook.HasProfessionInfo() then
		private.scanTimer:RunForTime(MISSING_INFO_DELAY_TIME)
		return
	end

	Log.Info("Player professions updated")
	assert(not next(private.forgetTemp))
	for name, info in pairs(private.settings.playerProfessions) do
		-- Don't forget station professions (e.g. Dye Crafting) as they aren't in GetProfessions()
		if info.skillId ~= nil then
			private.forgetTemp[name] = true
		end
	end

	local hasProfession = false
	if LibTSMService.IsRetail() or LibTSMService.IsForever() or LibTSMService.IsMistsClassic() then
		for index, _, name, level, maxLevel, skillId in ProfessionBook.MistsRetailProfessionInfoIterator() do
			if not Data.IsIgnored(name) then
				hasProfession = true
				local isSecondary = index > 2
				Log.Info("Scanned profession (name=%s, level=%d/%d, isSecondary=%s)", name, level, maxLevel, isSecondary)
				private.forgetTemp[name] = nil
				private.UpdatePlayerProfessionInfo(name, skillId, level, maxLevel, isSecondary)
			end
		end
	else
		for _, name, subName in ProfessionBook.SpellBookProfessionInfoIterator() do
			local level, maxLevel = nil, nil
			name, level, maxLevel = private.GetProfessionInfo(name, subName)
			if name and level and maxLevel then
				hasProfession = true
				local isSecondary = name == Spell.GetInfo(FIRST_AID_SPELL_ID)
				Log.Info("Scanned profession (name=%s, level=%d/%d, isSecondary=%s)", name, level, maxLevel, isSecondary)
				private.forgetTemp[name] = nil
				private.UpdatePlayerProfessionInfo(name, -1, level, maxLevel, isSecondary)
			end
		end
	end
	if hasProfession then
		-- Forgot removed professions
		for name in pairs(private.forgetTemp) do
			Log.Info("Forgetting profession (%s)", name)
			private.settings.playerProfessions[name] = nil
		end

		-- Update our DB
		private.db:TruncateAndBulkInsertStart()
		for _, playerProfessions, character in private.settings:LocalValueIterator("playerProfessions") do
			for name, info in pairs(playerProfessions) do
				private.db:BulkInsertNewRow(character, name, info.skillId or -1, info.level, info.maxLevel, info.isSecondary)
			end
		end
		private.db:BulkInsertEnd()
	end
	wipe(private.forgetTemp)
end

function private.GetProfessionInfo(name, subName)
	if not name or not subName or not private.IsValidName(name, subName) then
		return nil, nil, nil
	elseif Data.IsIgnored(name) then
		-- Ignored profession
		return nil, nil, nil
	end
	local level, maxLevel = nil, nil
	for _, skillName, skillRank, skillMaxRank in ProfessionBook.SkillLineInfoIterator() do
		if skillName == name then
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif name == TradeSkill.NAMES.SMELTING and skillName == TradeSkill.NAMES.MINING then
			name = skillName
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif Professions.LocalizedNameToSkillMap[name] == skillName then
			name = skillName
			level = skillRank
			maxLevel = skillMaxRank
			break
		end
	end
	return name, level, maxLevel
end

function private.IsValidName(name, subName)
	if TradeSkill.IsClassicSubName(strtrim(subName, " ")) then
		return true
	elseif name == TradeSkill.NAMES.SMELTING then
		return true
	elseif name == TradeSkill.NAMES.POISONS then
		return true
	elseif Professions.LocalizedNameToSkillMap[name] then
		return true
	else
		return false
	end
end

function private.HandleProfessionStateChange()
	if not private.settings or State.IsClosed() then
		return
	end
	local professionName, skillId = State.GetCurrentProfession()
	if not professionName or skillId or private.settings.playerProfessions[professionName] then
		return
	end
	-- This is a station profession (e.g. Dye Crafting) not returned by GetProfessions()
	Log.Info("Registering station profession: %s", professionName)
	private.UpdatePlayerProfessionInfo(professionName, nil, 0, 0, false)
	private.QueueScan()
end

function private.UpdatePlayerProfessionInfo(name, skillId, level, maxLevel, isSecondary)
	local professionInfo = private.settings.playerProfessions[name] or {}
	private.settings.playerProfessions[name] = professionInfo
	-- Preserve whether or not we've prompted to create groups and the profession link if possible
	local oldPrompted = professionInfo.prompted or nil
	local oldLink = professionInfo.link or nil ---@diagnostic disable-line: redundant-or
	wipe(professionInfo)
	professionInfo.skillId = skillId
	professionInfo.level = level
	professionInfo.maxLevel = maxLevel
	professionInfo.isSecondary = isSecondary
	professionInfo.prompted = oldPrompted
	professionInfo.link = oldLink
end

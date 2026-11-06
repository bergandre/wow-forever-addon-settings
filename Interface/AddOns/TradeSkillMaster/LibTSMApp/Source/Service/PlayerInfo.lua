-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local PlayerInfo = LibTSMApp:Init("Service.PlayerInfo")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Iterator = LibTSMApp:From("LibTSMUtil"):Include("BaseType.Iterator")
local String = LibTSMApp:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local CharacterInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.CharacterInfo")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local private = {
	settingsDB = nil,
	settings = nil,
	connectedAlts = {},
	isPlayerCache = { ---@type table<string,boolean>|{lastUpdate: number}
		lastUpdate = 0,
	},
	auctionIsPlayerCache = { ---@type table<string,boolean>|{lastUpdate: number}
		lastUpdate = 0,
	},
	validGuildsTemp = {},
	guildIterTemp = {},
}
local PLAYER_LOWER = strlower(SessionInfo.GetCharacterName())
local FACTION_LOWER = strlower(SessionInfo.GetFactionName())
local REALM_LOWER = strlower(SessionInfo.GetRealmName())
local PLAYER_REALM_LOWER = PLAYER_LOWER.." - "..REALM_LOWER



-- ============================================================================
-- Module Loading
-- ============================================================================

PlayerInfo:OnModuleLoad(function()
	Guild.RegisterNameCallback(private.HandleGuildNameChange)
end)

AddonSettings.RegisterOnLoad(PlayerInfo, function(db)
	private.settingsDB = db
	private.settings = db:NewView("PlayerInfoSettings")
		:AddKey("factionrealm", "internalData", "guildVaults")
		:AddKey("factionrealm", "coreOptions", "ignoreGuilds")
		:AddKey("factionrealm", "internalData", "characterGuilds")
		:AddKey("sync", "internalData", "classKey")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Return all connected realm alt characters as a table.
---@return string[]
function PlayerInfo.GetConnectedAlts()
	wipe(private.connectedAlts)
	for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
		for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm) do
			local realm = strmatch(factionrealm, "^[^%-]+ %- (.+)$")
			assert(realm)
			realm = gsub(realm, "%-", "")
			character = CharacterInfo.Ambiguate(gsub(character.."-"..realm, " ", ""))
			if character ~= SessionInfo.GetCharacterName() then
				tinsert(private.connectedAlts, character)
			end
		end
	end
	sort(private.connectedAlts)
	return private.connectedAlts
end

---Iterate over all characters which are accessible.
---@param currentAccountOnly boolean If true, will only include the current account
---@return IteratorObject<fun(): number, string, string> @Iterator with fields: `index`, `character`, `factionrealm`
function PlayerInfo.CharacterIterator(currentAccountOnly)
	local iter = Iterator.Acquire(private.settings:AccessibleValueIterator("classKey"))
		:SetMapFunc(private.CharacterIteratorMap)
	if currentAccountOnly then
		iter:Filter(private.CharacterIteratorCurrentAccountOnlyFilter)
	end
	return iter
end

---Iterate over all the guilds which are accessible.
---@param includeIgnored? boolean Include ignored guilds
---@return IteratorObject<fun(): number, string, string> @Iterator with fields: `index`, `guildName`, `factionrealm`
function PlayerInfo.GuildIterator(includeIgnored)
	assert(not next(private.guildIterTemp))
	for _, guildVaults, factionrealm in private.settings:AccessibleValueIterator("guildVaults") do
		local ignoreGuilds = private.settings:GetForScopeKey("ignoreGuilds", factionrealm)
		for guildName in pairs(guildVaults) do
			if includeIgnored or not ignoreGuilds[guildName] then
				Table.InsertMultiple(private.guildIterTemp, guildName, factionrealm)
			end
		end
	end
	return Iterator.Acquire(Table.StrideIterator(private.guildIterTemp, 2))
		:SetCleanupFunc(Table.WipeAndDeallocate)
end

---Get the player's guild.
---@param character string The name of the player
---@param factionrealm string The factionrealm
---@return string?
function PlayerInfo.GetPlayerGuild(character, factionrealm)
	return private.settings:GetForScopeKey("characterGuilds", factionrealm)[character]
end

---Check whether or not a player belongs to the user.
---@param target string The name of the player
---@param includeAlts? boolean Whether or not to include alts
---@param includeOtherFaction? boolean Whether or not to include players on the other faction
---@param includeOtherAccounts? boolean Whether or not to include connected accounts
---@return boolean
function PlayerInfo.IsPlayer(target, includeAlts, includeOtherFaction, includeOtherAccounts)
	local cacheKey = strjoin("%", target, includeAlts and "1" or "0", includeOtherFaction and "1" or "0", includeOtherAccounts and "1" or "0")
	if private.isPlayerCache.lastUpdate ~= ClientInfo.GetFrameNumber() then
		wipe(private.isPlayerCache)
		private.isPlayerCache.lastUpdate = ClientInfo.GetFrameNumber()
	end
	if private.isPlayerCache[cacheKey] == nil then
		private.isPlayerCache[cacheKey] = private.IsPlayerHelper(target, includeAlts, includeOtherFaction, includeOtherAccounts)
	end
	return private.isPlayerCache[cacheKey]
end

---Checks if an auction owner string contains the player.
---@param ownerStr string The auction owner string
---@return boolean
function PlayerInfo.AuctionOwnerIsPlayer(ownerStr)
	if LibTSMApp.GetTime() - private.auctionIsPlayerCache.lastUpdate > 60 then
		wipe(private.auctionIsPlayerCache)
		private.auctionIsPlayerCache.lastUpdate = LibTSMApp.GetTime()
	end
	if private.auctionIsPlayerCache[ownerStr] == nil then
		private.auctionIsPlayerCache[ownerStr] = false
		for owner in String.SplitIterator(ownerStr, ",") do
			if PlayerInfo.IsPlayer(owner, true, true, true) then
				private.auctionIsPlayerCache[ownerStr] = true
				break
			end
		end
	end
	return private.auctionIsPlayerCache[ownerStr]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsPlayerHelper(target, includeAlts, includeOtherFaction, includeOtherAccounts)
	target = strlower(target)
	if not strfind(target, " %- ") then
		target = gsub(target, "%-", " - ", 1)
	end
	if target == PLAYER_LOWER then
		return true
	elseif strfind(target, " %- ") and target == PLAYER_REALM_LOWER then
		return true
	end
	if not strfind(target, " %- ") then
		target = target.." - "..REALM_LOWER
	end
	if includeAlts then
		local factionrealmIter = private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide)
		for _, factionrealm in factionrealmIter do
			local charIter = private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true)
			for _, character in charIter do
				local factionKey, realm = strmatch(factionrealm, "(.+) %- (.+)")
				assert(factionKey and realm)
				factionKey = strlower(factionKey)
				if target == strlower(character).." - "..strlower(realm) and (includeOtherFaction or factionKey == FACTION_LOWER) and (includeOtherAccounts or private.IsLocalAccountOwner(character, factionrealm)) then
					charIter:Release()
					factionrealmIter:Release()
					return true
				end
			end
		end
	end
	return false
end

function private.IsLocalAccountOwner(character, factionrealm)
	return private.settingsDB:GetOwnerSyncAccountKey(character, factionrealm) == private.settingsDB:GetLocalSyncAccountKey(factionrealm)
end

function private.CharacterIteratorMap(_, _, character, factionrealm)
	return character, factionrealm
end

function private.CharacterIteratorCurrentAccountOnlyFilter(_, _, character, factionrealm)
	return private.IsLocalAccountOwner(character, factionrealm)
end

function private.HandleGuildNameChange(name)
	private.settings.characterGuilds[SessionInfo.GetCharacterName()] = name
	if not name then
		return
	end

	-- Clean up any guilds with no players in them
	assert(not next(private.validGuildsTemp))
	for _, character in private.settingsDB:AccessibleCharacterIterator(private.settingsDB:GetLocalSyncAccountKey()) do
		local guild = private.settings.characterGuilds[character]
		if guild then
			private.validGuildsTemp[guild] = true
		end
	end
	Table.FilterValueNotInTable(private.settings.characterGuilds, private.validGuildsTemp)
	Table.FilterKeyNotInTable(private.settings.guildVaults, private.validGuildsTemp)
	Table.WipeAndDeallocate(private.validGuildsTemp)
end

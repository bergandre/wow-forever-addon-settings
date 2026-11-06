-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local SessionInfo = LibTSMWoW:Init("Util.SessionInfo")
local PLAYER_SEP = " - "
local CHARACTER = UnitName("player")
local CLASS = select(2, UnitClass("player"))
local FACTION = UnitFactionGroup("player")
local REALM = GetRealmName()
local CHARACTER_WITH_REALM = gsub(CHARACTER.."-"..REALM, "%s+", "")
if LibTSMWoW.IsForever() then
	local surname = select(2, UnitName("player")) --[[@as string?]]
	if surname then
		CHARACTER = CHARACTER..Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR..surname ---@diagnostic disable-line: undefined-field
	end
	CHARACTER_WITH_REALM = CHARACTER
	local isRP = C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset) ---@diagnostic disable-line: undefined-field
	local isPvP = C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset) ---@diagnostic disable-line: undefined-field
	if C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then
		REALM = "Hardcore"
	elseif isRP and isPvP then
		REALM = "Roleplay PvP"
	elseif isRP then
		REALM = "Roleplay"
	elseif isPvP then
		REALM = "PvP"
	else
		REALM = "Normal"
	end
end
local FACTIONREALM = FACTION..PLAYER_SEP..REALM
local REALM_ID = GetRealmID()



-- ============================================================================
-- Module Functions
-- ============================================================================

---Get the name of the current character.
---@return string
function SessionInfo.GetCharacterName()
	return CHARACTER
end

---Get the class of the current character.
---@return string
function SessionInfo.GetCharacterClass()
	return CLASS
end

---Gets the disambiguated character name (with the realm).
---@return string
function SessionInfo.GetDisambiguatedCharacterName()
	return CHARACTER_WITH_REALM
end

---Get the name of the current faction.
---@return string
function SessionInfo.GetFactionName()
	return FACTION
end

---Get the name of the current realm.
---@return string
function SessionInfo.GetRealmName()
	return REALM
end

---Gets the ID of the current realm.
---@return number
function SessionInfo.GetRealmId()
	return REALM_ID
end

---Get the name of the current factionrealm.
---@return string
function SessionInfo.GetFactionrealmName()
	return FACTIONREALM
end

---Check if the specified character (and optionally factionrealm) is the current character.
---@param character string The name of the character to check
---@param factionrealm? string The name of the factionrealm which the character belongs to
---@return boolean
function SessionInfo.IsPlayer(character, factionrealm)
	return character == CHARACTER and (factionrealm == nil or factionrealm == FACTIONREALM)
end

---Formats a character name for display.
---@param character string The name of the character
---@param factionrealm string The factionrealm for the character
---@param full? boolean Use the full factionrealm even if it's the current factionrealm
function SessionInfo.FormatCharacterName(character, factionrealm, full)
	if full then
		return strjoin(PLAYER_SEP, character, factionrealm)
	elseif factionrealm == FACTIONREALM then
		return character
	else
		local faction, realm = strmatch(factionrealm, "^([^ ]+) %- (.+)$")
		return strjoin(PLAYER_SEP, character, realm == REALM and faction or factionrealm)
	end
end

---Gets the region from the C-var.
---@return string
function SessionInfo.GetRegion()
	local result = GetCVar("Portal")
	return result ~= "public-test" and result or "PTR"
end

---Checks if we're on a hardcore realm.
---@return boolean
function SessionInfo.IsHardcore()
	if LibTSMWoW.IsForever() then
		return C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset)
	end
	return C_Seasons.HasActiveSeason() and C_Seasons.GetActiveSeason() == Enum.SeasonID.Hardcore
end

---Checks if we're on a season of discovery realm.
---@return boolean
function SessionInfo.IsSeasonOfDiscovery()
	return C_Seasons.HasActiveSeason() and C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery
end

---Returns whether or not limited mode is active.
---@return boolean
function SessionInfo.IsLimited()
	return GameLimitedMode_IsActive()
end

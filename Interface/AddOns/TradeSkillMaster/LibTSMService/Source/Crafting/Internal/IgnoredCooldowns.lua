-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local IgnoredCooldowns = LibTSMService:InitInternal("Crafting.IgnoredCooldowns")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	db = nil,
	settingsTable = nil,
}
local SETTINGS_SEP = "\001"
local CHARACTER_KEY = SessionInfo.GetCharacterName().." - "..SessionInfo.GetRealmName()



-- ============================================================================
-- Module Loading
-- ============================================================================

IgnoredCooldowns:OnModuleLoad(function()
	private.db = Database.NewSchema("IGNORED_COOLDOWNS")
		:AddStringField("characterKey")
		:AddStringField("craftString")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the ignored cooldowns settings tables.
---@param ignored table<string,true> The settings table
function IgnoredCooldowns.Load(ignored)
	private.settingsTable = ignored
	private.LoadData()
end

---Creates a query.
---@return DatabaseQuery
function IgnoredCooldowns.CreateQuery()
	return private.db:NewOwnedQuery()
		:VirtualField("name", "string", CraftInfoDB.GetName, "craftString", "?")
end

---Returns whether or not a craft is ignored for the current character.
---@param craftString string The craft string
---@return boolean
function IgnoredCooldowns.IsIgnored(craftString)
	return private.settingsTable[CHARACTER_KEY..SETTINGS_SEP..craftString] or false
end

---Adds an ignored cooldown for the current character.
---@param craftString string The craft string
function IgnoredCooldowns.Add(craftString)
	local key = CHARACTER_KEY..SETTINGS_SEP..craftString
	assert(not private.settingsTable[key])
	private.settingsTable[key] = true
	private.db:InsertRow(CHARACTER_KEY, craftString)
end

---Removes an ignored cooldown.
---@param characterKey string The character key
---@param craftString string The craft string
function IgnoredCooldowns.Remove(characterKey, craftString)
	local key = characterKey..SETTINGS_SEP..craftString
	assert(private.settingsTable[key])
	private.settingsTable[key] = nil
	local uuid = private.db:NewAutoReleaseQuery()
		:Equal("characterKey", characterKey)
		:Equal("craftString", craftString)
		:GetFirstResultWithUUID()
	assert(uuid)
	private.db:DeleteRow(uuid)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData()
	private.db:BulkInsertStart()
	for entry in pairs(private.settingsTable) do
		local characterKey, craftString = strsplit(SETTINGS_SEP, entry)
		if CraftInfoDB.HasCraftString(craftString) then
			private.db:BulkInsertNewRow(characterKey, craftString)
		else
			private.settingsTable[entry] = nil
		end
	end
	private.db:BulkInsertEnd()
end

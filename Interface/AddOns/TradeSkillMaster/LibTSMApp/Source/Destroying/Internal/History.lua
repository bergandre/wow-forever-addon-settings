-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local History = LibTSMApp:InitInternal("Destroying.History")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local BinarySearch = LibTSMApp:From("LibTSMUtil"):Include("Util.BinarySearch")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local private = {
	settings = nil,
}
local CLEANUP_TIME_THRESHOLD = 60 * 24 * 60 * 60
local CLEANUP_MAX_ENTRIES = 100



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(History, function(db)
	private.settings = db:NewView("HistorySettings")
		:AddKey("global", "internalData", "destroyingHistory")
		:Commit()

	local cleanupTime = LibTSMApp.GetTime() - CLEANUP_TIME_THRESHOLD
	for spellId, entries in pairs(private.settings.destroyingHistory) do
		-- Rely on the entries being sorted in ascending time
		local index, insertIndex = BinarySearch.Table(entries, cleanupTime, private.GetHistoryEntryTime)
		local removeThroughIndex = max((index or insertIndex) - 1, #entries - CLEANUP_MAX_ENTRIES)
		if removeThroughIndex > 0 then
			Log.Info("Removing %d old entries for %s", removeThroughIndex, tostring(spellId))
			Table.RemoveRange(entries, 1, removeThroughIndex)
		end
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds an entry to the destroying history.
---@param itemString string The item string which was destroyed
---@param spellId number The destroy spell ID
---@param lootResult table<string,number> The result of the destroy (this table reference must remain value)
function History.Add(itemString, spellId, lootResult)
	local newEntry = {
		item = itemString,
		time = floor(LibTSMApp.GetTime()),
		result = lootResult,
	}
	private.settings.destroyingHistory[spellId] = private.settings.destroyingHistory[spellId] or {}
	tinsert(private.settings.destroyingHistory[spellId], newEntry)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetHistoryEntryTime(entry)
	return entry.time
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

if not TSMDEV then ---@diagnostic disable-line: redundant-condition
	return
end
TSMDEV.Tracing = {}
local Tracing = TSMDEV.Tracing



-- ============================================================================
-- Module Functions
-- ============================================================================

function Tracing.Enable(apiName)
	C_AddOns.LoadAddOn("Blizzard_EventTrace")
	local tableName, tableKey = strsplit(".", apiName)
	---@cast tableKey string?
	if not tableKey then
		tableKey = tableName
		tableName = nil
	end
	assert(tableKey)
	hooksecurefunc(tableName and _G[tableName] or _G, tableKey, function(...) EventTrace:LogEvent(apiName, ...) end)
end

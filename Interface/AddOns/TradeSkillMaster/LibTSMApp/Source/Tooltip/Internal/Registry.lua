-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Registry = LibTSMApp:InitInternal("Tooltip.Registry")
local private = {
	registeredInfo = {}, ---@type TooltipInfo[]
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds tooltip info into the registry.
---@param info TooltipInfo
function Registry.Add(info)
	info:_CheckDefaults() ---@diagnostic disable-line: invisible
	tinsert(private.registeredInfo, info)
end

---Gets registered tooltip info at the specified index.
---@param index number The registry index
---@return TooltipInfo
function Registry.Get(index)
	return private.registeredInfo[index]
end

---Iterates over registered tooltip info.
---@return fun(): number, TooltipInfo @Iterator with fields: `index`, `info`
function Registry.Iterator()
	return private.IteratorHelper
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IteratorHelper(_, index)
	index = (index or 0) + 1
	if index > #private.registeredInfo then
		return
	end
	return index, private.registeredInfo[index]
end

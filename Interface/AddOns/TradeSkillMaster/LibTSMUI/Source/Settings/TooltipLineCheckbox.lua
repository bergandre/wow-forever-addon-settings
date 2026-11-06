-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")

---@class TooltipLineInfo
---@field label string



-- ============================================================================
-- Element Definition
-- ============================================================================

local TooltipLineCheckbox = ComponentRegistry.Define("TooltipLineCheckbox", "Checkbox")
TooltipLineCheckbox._STATE_SCHEMA = TooltipLineCheckbox._STATE_SCHEMA:Extend("TooltipLineCheckboxState")
	:AddOptionalTableField("info", function(value) return value == nil or type(value.label) == "string" end)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the tooltip line info.
---@param info TooltipLineInfo The info object
---@return self
function TooltipLineCheckbox:SetInfo(info)
	self._state.info = info
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function TooltipLineCheckbox.__protected:_SendActionScript(script)
	assert(script == "OnValueChanged")
	assert(self._state.info)
	self.__super:_SendActionScript(script, self._state.info, self._state.checked)
end

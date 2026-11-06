-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ItemSelectorButton = ComponentRegistry.Define("ItemSelectorButton", "BaseButton")
ItemSelectorButton._STATE_SCHEMA = ItemSelectorButton._STATE_SCHEMA:Extend("ItemSelectorButtonState")
	:AddOptionalStringField("itemString")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the item string for the button.
---@param itemString string The item string
---@return self
function ItemSelectorButton:SetItemString(itemString)
	assert(itemString)
	self._state.itemString = itemString
	self:SetBackgroundWithItemHighlight(itemString)
	self:SetTooltip(itemString)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function ItemSelectorButton.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		return self.__super:_SendActionScript(script, self._state.itemString)
	else
		return self.__super:_SendActionScript(script, ...)
	end
end

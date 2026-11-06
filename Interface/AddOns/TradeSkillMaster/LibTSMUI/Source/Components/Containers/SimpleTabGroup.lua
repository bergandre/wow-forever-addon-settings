-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local BUTTON_HEIGHT = 24
local BUTTON_PADDING_BOTTOM = 2



-- ============================================================================
-- Element Definition
-- ============================================================================

local SimpleTabGroup = ComponentRegistry.Define("SimpleTabGroup", "BaseTabGroup")



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param button TabGroupButton
function SimpleTabGroup.__protected:_CreateTab(_, button)
	return button
		:SetWidth("AUTO")
		:SetMargin(8, 8, 0, BUTTON_PADDING_BOTTOM)
		:SetJustifyH("LEFT")
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SimpleTabGroup:_GetContentPadding(side)
	if side == "TOP" then
		return BUTTON_HEIGHT + BUTTON_PADDING_BOTTOM
	end
	return self.__super:_GetContentPadding(side)
end

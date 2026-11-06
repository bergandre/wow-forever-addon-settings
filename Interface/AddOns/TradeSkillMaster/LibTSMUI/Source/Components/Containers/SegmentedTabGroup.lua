-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local TAB_HEIGHT = 20
local BAR_PADDING = 4
local CONTENT_SPACING = 8



-- ============================================================================
-- Element Definition
-- ============================================================================

local SegmentedTabGroup = ComponentRegistry.Define("SegmentedTabGroup", "BaseTabGroup")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SegmentedTabGroup:Acquire()
	self.__super:Acquire()
	self._state.contentFrame
		:SetHeight(TAB_HEIGHT + BAR_PADDING * 2)
		:SetPadding(0, 0, BAR_PADDING, BAR_PADDING)
		:SetRoundedBackgroundColor("container/low")
end

---Sets the horizontal margin of the tab bar without affecting the content.
---@param margin number The margin on the left and right of the tab bar
---@return self
function SegmentedTabGroup:SetBarMargin(margin)
	self._state.contentFrame
		:WipeAnchors()
		:AddAnchor("TOPLEFT", margin, 0)
		:AddAnchor("TOPRIGHT", -margin, 0)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param button TabGroupButton
function SegmentedTabGroup.__protected:_CreateTab(path, button)
	local tab = nil
	for _ in self._state:WithAutoStorePaused() do
		tab = UIElements.New("BaseFrame", "Tab_"..gsub(path, " ", ""))
			:SetLayout("VERTICAL")
			:SetMargin(BAR_PADDING, BAR_PADDING, 0, 0)
			:SetRoundedBackgroundColor(self._state:Publisher("path"):ToBooleanEquals(path):ReplaceBooleanWith("container/high", nil))
			:AddChild(button
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("CENTER")
			)
	end
	return tab
end



-- ===========================================================================
-- Private Class Methods
-- ============================================================================

function SegmentedTabGroup:_GetContentPadding(side)
	if side == "TOP" then
		return TAB_HEIGHT + BAR_PADDING * 2 + CONTENT_SPACING
	end
	return self.__super:_GetContentPadding(side)
end

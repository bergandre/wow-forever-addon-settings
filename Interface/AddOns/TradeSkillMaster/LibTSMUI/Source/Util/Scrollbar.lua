-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Scrollbar = LibTSMUI:InitInternal("Util.Scrollbar")
local Widgets = LibTSMUI:Include("Util.Widgets")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	scrollbars = {},
}

---@class Scrollbar: SliderExtended
---@field dragging boolean?



-- ============================================================================
-- Module Loading
-- ============================================================================

Scrollbar:OnModuleLoad(function()
	Theme.RegisterChangeCallback(private.OnThemeChange)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a scrollbar.
---@generic T: Class
---@param owner T The class object which owns the new scrollbar (for debug purposes)
---@param parent Frame The parent frame
---@param isHorizontal boolean Whether the scrollbar is horizontal or not (vertical)
---@return Scrollbar
function Scrollbar.Create(owner, parent, isHorizontal)
	local scrollbar = Widgets.CreateSlider(owner, parent)
	scrollbar:ClearAllPoints()
	if isHorizontal then
		scrollbar:SetOrientation("HORIZONTAL")
		scrollbar:SetHitRectInsets(-4, -4, -6, -10)
		scrollbar:SetHeight(Theme.GetScrollbarWidth())
		scrollbar:SetPoint("BOTTOMLEFT", Theme.GetScrollbarMargin(), Theme.GetScrollbarMargin())
		scrollbar:SetPoint("BOTTOMRIGHT", -Theme.GetScrollbarMargin(), Theme.GetScrollbarMargin())
	else
		scrollbar:SetOrientation("VERTICAL")
		scrollbar:SetHitRectInsets(-6, -10, -4, -4)
		scrollbar:SetWidth(Theme.GetScrollbarWidth())
		scrollbar:SetPoint("TOPRIGHT", -Theme.GetScrollbarMargin(), -Theme.GetScrollbarMargin())
		scrollbar:SetPoint("BOTTOMRIGHT", -Theme.GetScrollbarMargin(), Theme.GetScrollbarMargin())
	end
	scrollbar:SetValueStep(1)
	scrollbar:SetObeyStepOnDrag(true)
	scrollbar:TSMSetScript("OnShow", private.ScrollbarOnLeave)
	scrollbar:TSMSetScript("OnHide", private.ScrollbarOnMouseUp)
	scrollbar:TSMSetScript("OnUpdate", private.ScrollbarOnUpdate)
	scrollbar:TSMSetScript("OnEnter", private.ScrollbarOnEnter)
	scrollbar:TSMSetScript("OnLeave", private.ScrollbarOnLeave)
	scrollbar:TSMSetScript("OnMouseDown", private.ScrollbarOnMouseDown)
	scrollbar:TSMSetScript("OnMouseUp", private.ScrollbarOnMouseUp)

	scrollbar:TSMCreateThumbTexture(owner)
	scrollbar:TSMSetThumbColorTexture("outline/main")
	tinsert(private.scrollbars, scrollbar)

	return scrollbar --[[@as Scrollbar]]
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

---@param scrollbar Scrollbar
function private.ScrollbarOnUpdate(scrollbar)
	scrollbar:SetFrameLevel(scrollbar:GetParent():GetFrameLevel() + 5)
end

---@param scrollbar Scrollbar
function private.ScrollbarOnEnter(scrollbar)
	scrollbar:TSMSetThumbColorTexture("outline/main+SELECTED_HOVER")
end

---@param scrollbar Scrollbar
function private.ScrollbarOnLeave(scrollbar)
	scrollbar:TSMSetThumbColorTexture("outline/main")
end

---@param scrollbar Scrollbar
function private.ScrollbarOnMouseDown(scrollbar)
	scrollbar.dragging = true
end

---@param scrollbar Scrollbar
function private.ScrollbarOnMouseUp(scrollbar)
	scrollbar.dragging = nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnThemeChange()
	for _, scrollbar in ipairs(private.scrollbars) do
		scrollbar:TSMSetThumbColorTexture("outline/main")
	end
end

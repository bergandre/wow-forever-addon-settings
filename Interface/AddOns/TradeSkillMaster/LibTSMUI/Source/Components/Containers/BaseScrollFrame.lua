-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local DRAG_SCROLL_SPEED_FACTOR = 12



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseScrollFrame = ComponentRegistry.Define("BaseScrollFrame", "Container")
BaseScrollFrame._STATE_SCHEMA = BaseScrollFrame._STATE_SCHEMA:Extend("BaseScrollFrameState")
	:AddOptionalStringField("backgroundColor", Theme.IsValidColor)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BaseScrollFrame:__init()
	local frame = self:_CreateScrollFrame()
	self._frame = frame
	self.__super:__init(frame)

	self._scrollValue = 0

	local backgroundColorPublisher = self._state:Publisher("backgroundColor")
		:Share()

	self._background = self:_CreateRectangle(1)
	self._background:SetCornerRadius(0)
	self._background:SetShown(backgroundColorPublisher:ToBooleanNotEquals(nil):IgnoreDuplicates())
	self._background:SubscribeColor(backgroundColorPublisher:IgnoreNil())

	frame:EnableMouseWheel(true)
	frame:SetClipsChildren(true)
	frame:TSMSetOnUpdate(self:__closure("_FrameOnUpdate"))
	frame:TSMSetScript("OnMouseWheel", self:__closure("_FrameOnMouseWheel"))

	self._scrollbar = self:_CreateScrollbar()
	self._scrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnScrollValueChanged"))

	self._content = self:_CreateFrame()
	self._content:SetPoint("TOPLEFT")
	self._content:SetPoint("TOPRIGHT")
	frame:SetScrollChild(self._content)

	backgroundColorPublisher:EndShare()
end

function BaseScrollFrame:Acquire()
	self.__super:Acquire()
	self._scrollValue = 0
	self._scrollbar:SetValue(0)
end

---Sets the background of the scroll frame.
---@param color? ThemeColorKey The background color as a theme color key or nil
---@return self
function BaseScrollFrame:SetBackgroundColor(color)
	self._state.backgroundColor = color
	return self
end

---Scrolls the scroll frame in response to the user dragging an element.
function BaseScrollFrame:ScrollForDragging()
	local baseFrame = self:_GetBaseFrame()
	local uiScale = baseFrame:GetEffectiveScale()
	local x, y = GetCursorPosition()
	x = x / uiScale
	y = y / uiScale
	local top = baseFrame:GetTop()
	local bottom = baseFrame:GetBottom()
	local scrollAmount = nil
	if y > top then
		scrollAmount = top - y
	elseif y < bottom then
		scrollAmount = bottom - y
	else
		scrollAmount = 0
	end
	self._scrollbar:SetValue(self._scrollbar:GetValue() + scrollAmount / DRAG_SCROLL_SPEED_FACTOR) ---@diagnostic disable-line: invisible
end

function BaseScrollFrame:Draw()
	self.__super.__super:Draw()

	local width = self:_GetDimension("WIDTH")
	self._content:SetWidth(width)
	width = width - self:_GetPadding("LEFT") - self:_GetPadding("RIGHT")

	local totalHeight = self:_GetPadding("TOP") + self:_GetPadding("BOTTOM")
	for _, child in self:LayoutChildrenIterator() do
		child:_GetBaseFrame():SetParent(self._content)
		child:_GetBaseFrame():ClearAllPoints()

		-- Set the height
		local childHeight, childHeightCanExpand = child:_GetMinimumDimension("HEIGHT")
		assert(not childHeightCanExpand, "Invalid height for child: "..tostring(child))
		child:_SetDimension("HEIGHT", childHeight)
		totalHeight = totalHeight + childHeight + child:_GetMargin("TOP") + child:_GetMargin("BOTTOM")

		-- Set the width
		local childWidth, childWidthCanExpand = child:_GetMinimumDimension("WIDTH")
		if childWidthCanExpand then
			childWidth = max(childWidth, width - child:_GetMargin("LEFT") - child:_GetMargin("RIGHT"))
		end
		child:_SetDimension("WIDTH", childWidth)
	end
	self._content:SetHeight(totalHeight)
	local maxScroll = self:_GetMaxScroll()
	self._scrollbar:SetMinMaxValues(0, maxScroll)
	self._scrollbar:SetValue(min(self._scrollValue, maxScroll))
	self._scrollbar:TSMUpdateThumbLength(totalHeight, self:_GetDimension("HEIGHT"))

	local yOffset = -1 * self:_GetPadding("TOP")
	for _, child in self:LayoutChildrenIterator() do
		local childFrame = child:_GetBaseFrame()
		yOffset = yOffset - child:_GetMargin("TOP")
		childFrame:SetPoint("TOPLEFT", child:_GetMargin("LEFT") + self:_GetPadding("LEFT"), yOffset)
		yOffset = yOffset - childFrame:GetHeight() - child:_GetMargin("BOTTOM")
	end

	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function BaseScrollFrame.__private:_OnScrollValueChanged(_, value)
	value = max(min(value, self:_GetMaxScroll()), 0)
	self._frame:SetVerticalScroll(value)
	self._scrollValue = value
end

function BaseScrollFrame.__private:_GetMaxScroll()
	return max(self._content:GetHeight() - self:_GetDimension("HEIGHT"), 0)
end

function BaseScrollFrame:_GetMinimumDimension(dimension)
	local styleResult = nil
	if dimension == "WIDTH" then
		styleResult = self._state.width
	elseif dimension == "HEIGHT" then
		styleResult = self._state.height
	else
		error("Invalid dimension: "..tostring(dimension))
	end
	if styleResult then
		return styleResult, false
	elseif dimension == "HEIGHT" or self:_GetNumLayoutChildren() == 0 then
		-- regarding the first condition for this if statement, a scrollframe can be any height (including greater than
		-- the height of the content if no scrolling is needed), so has no minimum and can always expand
		return 0, true
	else
		-- we're trying to determine the width based on the max width of any of the children
		local result = 0
		local canExpand = false
		for _, child in self:LayoutChildrenIterator() do
			local childMin, childCanExpand = child:_GetMinimumDimension(dimension)
			childMin = childMin + child:_GetMargin("LEFT") + child:_GetMargin("RIGHT")
			canExpand = canExpand or childCanExpand
			result = max(result, childMin)
		end
		result = result + self:_GetPadding("LEFT") + self:_GetPadding("RIGHT")
		return result, canExpand
	end
end

function BaseScrollFrame.__private:_FrameOnUpdate()
	if (self._frame:IsMouseOver() and self:_GetMaxScroll() > 0) or self._scrollbar.dragging then
		self._scrollbar:Show()
	else
		self._scrollbar:Hide()
	end
end

function BaseScrollFrame.__private:_FrameOnMouseWheel(_, direction)
	local minValue, maxValue = self._scrollbar:GetMinMaxValues()
	if self._scrollbar:GetValue() ~= (direction > 0 and minValue or maxValue) then
		-- Scroll this scroll frame
		self:_ApplyMouseWheel(direction)
		return
	end
	-- Try to scroll the parent
	local parent = self:GetParentElement()
	while parent do
		if UIElements.IsType(parent, "BaseScrollFrame") then
			parent:_ApplyMouseWheel(direction)
			return
		else
			parent = parent:GetParentElement()
		end
	end
end

---@private
function BaseScrollFrame:_ApplyMouseWheel(direction)
	local scrollAmount = min(self:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
	self._scrollbar:SetValue(self._scrollbar:GetValue() + -1 * direction * scrollAmount)
end

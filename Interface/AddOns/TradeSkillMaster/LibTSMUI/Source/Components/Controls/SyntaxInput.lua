-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local SyntaxHelpers = LibTSMUI:From("LibTSMService"):Include("UI.SyntaxHelpers")
local CORNER_RADIUS = 4

---@alias SyntaxInputValidateFunc fun(value: string, context?: any): boolean, string?



-- ============================================================================
-- Element Definition
-- ============================================================================

local SyntaxInput = ComponentRegistry.Define("SyntaxInput", "Element")
SyntaxInput._STATE_SCHEMA = SyntaxInput._STATE_SCHEMA:Extend("SyntaxInputState")
	:AddOptionalStringField("validationError")
	:Commit()
SyntaxInput:_AddActionScripts("OnValueChanged", "OnDoneEditing")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SyntaxInput:__init()
	local frame = self:_CreateScrollFrame()
	self._frame = frame
	frame:EnableMouseWheel(true)
	frame:SetClipsChildren(true)
	self._editBox = self:_CreateEditBox(frame)
	frame:SetScrollChild(self._editBox)

	self.__super:__init(frame)

	frame:TSMSetScript("OnUpdate", self:__closure("_HandleFrameUpdate"))
	frame:TSMSetScript("OnMouseWheel", self:__closure("_HandleFrameMouseWheel"))
	frame:TSMSetScript("OnMouseUp", self:__closure("_HandleFrameMouseUp"))

	self._scrollbar = self:_CreateScrollbar()
	self._scrollbar:TSMSetScript("OnValueChanged", self:__closure("_HandleScrollbarValueChanged"))

	self._backgroundTexture = self:_CreateRectangle(1)
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)
	self._backgroundTexture:SubscribeColor(self:_GetOneShotPublisher("container/lowest"))

	self._editBox:TSMSetFont("BODY_SMALL")
	self._editBox:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface"))
	-- TODO: Better highlight color
	self._editBox:SetHighlightColor(0.2, 0.2, 0.2, 1)
	self._editBox:SetShadowColor(0, 0, 0, 0)
	self._editBox:SetAutoFocus(false)
	self._editBox:SetMultiLine(true)
	self._editBox:SetTextInsets(8, 8, 4, 4)
	self._editBox:SetJustifyH("LEFT")
	self._editBox:SetJustifyV("TOP")
	self._editBox:TSMSetScript("OnEscapePressed", self:__closure("_HandleEscapePressed"))
	self._editBox:TSMSetScript("OnKeyDown", self:__closure("_HandleKeyDown"))
	self._editBox:TSMSetScript("OnMouseUp", self:__closure("_HandleMouseUp"))
	self._editBox:TSMSetScript("OnCursorChanged", self:__closure("_HandleCursorChanged"))
	self._editBox:TSMSetScript("OnSizeChanged", self:__closure("_HandleSizeChanged"))

	self._value = nil
	self._prevValue = nil
	self._prevIndentValue = nil
	self._numLinesCache = nil
	self._validateFunc = nil ---@type SyntaxInputValidateFunc!
	self._validateContext = nil
	self._scrollValue = 0
	self._lastClickPos = nil
	self._lastClickTime = nil
end

function SyntaxInput:Acquire()
	self.__super:Acquire()

	self._editBox:TSMSetScript("OnEnterPressed", self:__closure("_HandleEnterPressed"))
	self._editBox:TSMSetScript("OnTextChanged", self:__closure("_HandleTextChanged"))
	self._editBox:SetFocus()

	self._scrollValue = 0
	self._scrollbar:SetValue(0)
end

function SyntaxInput:Release()
	self._editBox:TSMSetScript("OnEnterPressed", nil)
	self._editBox:TSMSetScript("OnTextChanged", nil)
	self._editBox:SetText("")
	self._editBox:ClearFocus()
	self._editBox:Enable()
	self._editBox:EnableMouse(true)
	self._editBox:EnableKeyboard(true)
	self._editBox:HighlightText(0, 0)
	self._editBox:SetHitRectInsets(0, 0, 0, 0)
	self._editBox:SetMaxLetters(2147483647)
	self._editBox:SetMaxBytes(2147483647)
	self._value = nil
	self._prevValue = nil
	self._prevIndentValue = nil
	self._numLinesCache = nil
	self._validateFunc = nil
	self._validateContext = nil
	self.__super:Release()
end

---Sets the current value.
---@param value string The value
---@return self
function SyntaxInput:SetValue(value)
	assert(type(value) == "string")
	self._prevValue = nil
	self._prevIndentValue = nil
	self._numLinesCache = nil
	self:_SetValueHelper(value)
	self:_SetSyntax(SyntaxHelpers.SetAutoIndent(value))
	return self
end

---Sets the function to use to validate the input text.
---@param validateFunc SyntaxInputValidateFunc A function which returns whether or not the value is valid and an error message if not
---@param context? any Extra context to pass to the validate function
---@return self
function SyntaxInput:SetValidateFunc(validateFunc, context)
	assert(type(validateFunc) == "function")
	self._validateFunc = validateFunc
	self._validateContext = context
	return self
end

---Get the value of the input and any active validation error.
---@return string? value
---@return string? validationError
function SyntaxInput:GetValue()
	return self._value, self._state.validationError
end

function SyntaxInput:Draw()
	self._editBox:SetWidth(self._frame:GetWidth())
	self.__super:Draw()

	local maxScroll = self:_GetMaxScroll()
	self._scrollbar:SetMinMaxValues(0, maxScroll)
	self._scrollbar:SetValue(min(self._scrollValue, maxScroll))
	self._scrollbar:TSMUpdateThumbLength(self._editBox:GetHeight(), self:_GetDimension("HEIGHT"))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SyntaxInput:_SetValueHelper(value)
	local sanitizedValue = SyntaxHelpers.StripColors(value)
	sanitizedValue = SyntaxHelpers.StripWhitespace(sanitizedValue)
	sanitizedValue = strtrim(sanitizedValue)
	local isValid, errMsg = self._validateFunc(sanitizedValue, self._validateContext)
	assert(type(isValid) == "boolean" and isValid == not errMsg)
	self._value = isValid and sanitizedValue or nil
	self._state.validationError = errMsg
	self:_SendActionScript("OnValueChanged", self._value, self._state.validationError)
	return isValid
end

function SyntaxInput:_SetSyntax(value)
	if value == self._prevValue then
		return
	end
	local cursor = self._editBox:GetCursorPosition()
	local newValue, newCursor = SyntaxHelpers.SetSyntaxColor(value, cursor)
	local numLines = select(2, gsub(newValue, "\n", ""))
	self._prevValue = newValue
	if value ~= newValue then
		self:_SetValueHelper(newValue)
		self._editBox:SetText(newValue)
		self:Draw()
		if newCursor then
			cursor = Math.Bound(newCursor, 0, #newValue)
			self._editBox:SetCursorPosition(cursor)
		end
	end
	if numLines ~= self._numLinesCache then
		self._numLinesCache = numLines
		value = self._editBox:GetText()
		if value ~= self._prevIndentValue then
			newValue, newCursor = SyntaxHelpers.SetIndent(value, cursor)
			self._prevIndentValue = newValue
			if value ~= newValue then
				self:_SetValueHelper(newValue)
				self._editBox:SetText(newValue)
				self:Draw()
				if newCursor then
					self._editBox:SetCursorPosition(Math.Bound(newCursor, 0, #newValue))
				end
			end
		end
	end
end

function SyntaxInput:_GetMaxScroll()
	return max(self._editBox:GetHeight() - self:_GetDimension("HEIGHT"), 0)
end

function SyntaxInput:_HandleFrameUpdate()
	if (self._frame:IsMouseOver() and self:_GetMaxScroll() > 0) or self._scrollbar.dragging then
		self._scrollbar:Show()
	else
		self._scrollbar:Hide()
	end
end

function SyntaxInput.__private:_HandleFrameMouseWheel(_, direction)
	local minValue, maxValue = self._scrollbar:GetMinMaxValues()
	if self._scrollbar:GetValue() ~= (direction > 0 and minValue or maxValue) then
		-- Scroll this input
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
function SyntaxInput:_ApplyMouseWheel(direction)
	local scrollAmount = min(self:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
	self._scrollbar:SetValue(self._scrollbar:GetValue() + -1 * direction * scrollAmount)
end

function SyntaxInput:_HandleFrameMouseUp()
	self._editBox:SetFocus()
end

function SyntaxInput:_HandleScrollbarValueChanged(_, value)
	value = max(min(value, self:_GetMaxScroll()), 0)
	self._frame:SetVerticalScroll(value)
	self._scrollValue = value
end

function SyntaxInput:_HandleEscapePressed()
	self._editBox:ClearFocus()
	self:_SendActionScript("OnDoneEditing", false)
end

function SyntaxInput:_HandleKeyDown()
	if IsShiftKeyDown() then
		self._editBox:TSMSetScript("OnEnterPressed", self:__closure("_HandleEnterPressed"))
	else
		self._editBox:TSMSetScript("OnEnterPressed", nil)
	end
end

function SyntaxInput:_HandleMouseUp()
	if (self._lastClickTime or math.huge) < (LibTSMUI.GetTime() - 0.5) then
		self._lastClickTime = nil
		self._lastClickPos = nil
	end
	local cursorPos = self._editBox:GetUTF8CursorPosition()
	if self._lastClickTime and self._lastClickPos == cursorPos then
		if self._lastClickTime > (LibTSMUI.GetTime() - 0.5) then
			local value = self._editBox:GetText()
			local starPos, endPos = 0, 0
			for i = 1, cursorPos do
				if not strmatch(strsub(value, i, i), "[a-zA-Z]") then
					starPos = i
				end
			end
			for i = cursorPos + 1, #value do
				if not strmatch(strsub(value, i, i), "[a-zA-Z]") then
					endPos = i - 1
					break
				end
			end
			self._editBox:HighlightText(starPos, endPos)
		end
	else
		self._lastClickTime = LibTSMUI.GetTime()
		self._lastClickPos = cursorPos
	end
end

function SyntaxInput:_HandleCursorChanged(_, x, y, _, lineHeight)
	y = abs(y)
	local offset = y - self._scrollValue
	if offset < 0 or offset > self:_GetDimension("HEIGHT") - lineHeight then
		self._scrollbar:SetValue(y)
	end
end

function SyntaxInput:_HandleSizeChanged(_, _, height)
	local maxScroll = self:_GetMaxScroll()
	self._scrollbar:SetMinMaxValues(0, maxScroll)
	self._scrollbar:SetValue(min(self._scrollValue, maxScroll))
	self._scrollbar:TSMUpdateThumbLength(self._editBox:GetHeight(), self:_GetDimension("HEIGHT"))
end

function SyntaxInput:_HandleEnterPressed()
	self._editBox:ClearFocus()
	self._editBox:HighlightText(0, 0)
	self:_SendActionScript("OnDoneEditing", self._value and true or false)
end

function SyntaxInput:_HandleTextChanged(_, isUserInput)
	if not isUserInput then
		return
	end
	local value = self._editBox:GetText()
	self:_SetValueHelper(value)
	self:_SetSyntax(value)
end

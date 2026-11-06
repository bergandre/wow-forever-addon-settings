-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local DelayTimer = LibTSMUI:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local CORNER_RADIUS = 4
local PADDING_LEFT_RIGHT = 8
local PADDING_TOP_BOTTOM = 4
local STYLE_INFO = { ---@type table<BaseInput.State,BaseInput.StyleInfo>
	ACTIVE = {
		backgroundColor = "container/lowest",
		borderColor = "outline/variant",
		textColor = "on/surface",
		hintTextColor = "on/surface/low",
	},
	ACTIVE_INVALID = {
		backgroundColor = "container/lowest",
		borderColor = "error/main",
		textColor = "on/surface",
		hintTextColor = "on/surface/low",
	},
	HOVER = {
		backgroundColor = "container/lowest",
		borderColor = "outline/main",
		textColor = "on/surface",
		hintTextColor = "on/surface/low",
	},
	HOVER_INVALID = {
		backgroundColor = "container/lowest",
		borderColor = "error/main+HOVER",
		textColor = "on/surface",
		hintTextColor = "on/surface/low",
	},
	FOCUS = {
		backgroundColor = "container/lowest",
		borderColor = "outline/main",
		textColor = "on/surface",
		hintTextColor = "on/surface/low%40",
	},
	FOCUS_INVALID = {
		backgroundColor = "container/lowest",
		borderColor = "error/main",
		textColor = "on/surface",
		hintTextColor = "on/surface/low%40",
	},
	DISABLED = {
		backgroundColor = "container/lowest%40",
		borderColor = "outline/variant%40",
		textColor = "on/surface%40",
		hintTextColor = "on/surface/low%40",
	},
}

---@alias BaseInput.State
---|'"ACTIVE"'
---|'"ACTIVE_INVALID"'
---|'"HOVER"'
---|'"HOVER_INVALID"'
---|'"FOCUS"'
---|'"FOCUS_INVALID"'
---|'"DISABLED"'

---@class BaseInput.StyleInfo
---@field backgroundColor string
---@field borderColor string
---@field textColor string
---@field hintTextColor string



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseInput = ComponentRegistry.Define("BaseInput", "Element", "ABSTRACT")
BaseInput._STATE_SCHEMA = BaseInput._STATE_SCHEMA:Extend("BaseInputState")
	:AddStringField("justifyH", "LEFT", private.ValidateJustifyH)
	:AddStringField("justifyV", "MIDDLE", private.ValidateJustifyV)
	:AddBooleanField("mouseOver", false)
	:AddBooleanField("disabled", false)
	:AddStringField("font", "BODY_SMALL", Theme.IsValidFont)
	:AddBooleanField("isValid", true)
	:AddBooleanField("hasFocus", false)
	:AddStringField("displayValue", "")
	:AddStringField("hintText", "")
	:AddStringField("value", "")
	:AddBooleanField("backgroundShown", true)
	:Commit()
BaseInput:_AddActionScripts("OnValueChanged", "OnEnterPressed", "OnValidationChanged", "OnFocusLost")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BaseInput:__init(frame, editBox)
	self.__super:__init(frame)
	self._editBox = editBox ---@type EditBoxExtended

	self._lostFocusTimer = DelayTimer.New("INPUT_LOST_FOCUS_"..tostring(frame), self:__closure("_HandleFocusLost"))
	self._escValue = nil
	self._pasteMode = nil
	self._readOnly = nil
	self._validateFunc = nil
	self._validateContext = nil
	self._settingTable = nil
	self._settingKey = nil
	self._tabPrevElement = nil
	self._tabNextElement = nil
	self._pasteChars = {}

	local styleInfoPublisher = self._state:Publisher([[(disabled and "DISABLED") or (hasFocus and (isValid and "FOCUS" or "FOCUS_INVALID")) or (mouseOver and (isValid and "HOVER" or "HOVER_INVALID")) or (isValid and "ACTIVE" or "ACTIVE_INVALID")]])
		:Map(STYLE_INFO)
		:Share()
	local fontPublisher = self._state:Publisher("font")
		:Share()

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)
	self._backgroundTexture:SubscribeColor(styleInfoPublisher:Map("borderColor"):IgnoreDuplicates())
	self._backgroundTexture:SetShown(self._state:Publisher("backgroundShown"))

	self._borderOverlay = self:_CreateRectangle(1)
	self._borderOverlay:SetCornerRadius(CORNER_RADIUS)
	self._borderOverlay:SetInset(1)
	self._borderOverlay:SubscribeColor(styleInfoPublisher:Map("backgroundColor"):IgnoreDuplicates())
	self._borderOverlay:SetShown(self._state:Publisher("backgroundShown"))

	self._editBox:SetShadowColor(0, 0, 0, 0)
	self._editBox:SetAutoFocus(false)
	self._editBox:SetTextInsets(PADDING_LEFT_RIGHT, PADDING_LEFT_RIGHT, PADDING_TOP_BOTTOM, PADDING_TOP_BOTTOM)
	self._editBox:TSMSetFont(fontPublisher)
	self._editBox:TSMSetJustifyH(self._state:Publisher("justifyH"))
	self._editBox:TSMSetJustifyV(self._state:Publisher("justifyV"))
	self._editBox:TSMSubscribeTextColor(styleInfoPublisher:Map("textColor"):IgnoreDuplicates())
	self._editBox:TSMSubscribeHighlightColor(self:_GetOneShotPublisher("on/surface%HIGHLIGHT"))
	self._editBox:TSMSetScript("OnEscapePressed", self:__closure("_OnEscapePressed"))
	self._editBox:TSMSetScript("OnTabPressed", self:__closure("_OnTabPressed"))
	self._editBox:TSMSetScript("OnEditFocusGained", self:__closure("_OnEditFocusGained"))
	self._editBox:TSMSetScript("OnEditFocusLost", self:__closure("_OnEditFocusLost"))
	self._editBox:TSMSetScript("OnChar", self:__closure("_OnChar"))
	self._editBox:TSMHookScript("OnEnter", self:__closure("_HandleFrameEnter"))
	self._editBox:TSMHookScript("OnLeave", self:__closure("_HandleFrameLeave"))

	self._hintText = self:_CreateFontString()
	self._hintText:TSMSetFont(fontPublisher)
	self._hintText:SetJustifyH("LEFT")
	self._hintText:SetJustifyV("MIDDLE")
	self._hintText:TSMSetText(self._state:Publisher("hintText"))
	self._hintText:TSMSetShown(self._state:Publisher([[displayValue == "" and hintText ~= ""]]))
	self._hintText:TSMSubscribeTextColor(styleInfoPublisher:Map("hintTextColor"):IgnoreDuplicates())
	self._hintText:SetPoint("TOPLEFT", PADDING_LEFT_RIGHT, 0)
	self._hintText:SetPoint("BOTTOMRIGHT", -PADDING_LEFT_RIGHT, 0)

	fontPublisher:EndShare()
	styleInfoPublisher:EndShare()
end

function BaseInput:Acquire()
	self.__super:Acquire()
	self._editBox:TSMSetScript("OnEnterPressed", self:__closure("_OnEnterPressed"))
	self._editBox:TSMSetScript("OnTextChanged", self:__closure("_HandleOnTextChanged"))
end

function BaseInput:Release()
	self._lostFocusTimer:Cancel()
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
	self._escValue = nil
	self._pasteMode = nil
	self._readOnly = nil
	self._validateFunc = nil
	self._validateContext = nil
	self._settingTable = nil
	self._settingKey = nil
	self._tabPrevElement = nil
	self._tabNextElement = nil
	wipe(self._pasteChars)
	self.__super:Release()
end

---Sets the horizontal justification of the input.
---@param justifyH JustifyHValue The horizontal justification
---@return self
function BaseInput:SetJustifyH(justifyH)
	self._state.justifyH = justifyH
	return self
end

---Sets the vertical justification of the input.
---@param justifyV JustifyVValue The vertical justification
---@return self
function BaseInput:SetJustifyV(justifyV)
	self._state.justifyV = justifyV
	return self
end

---Sets the font.
---@param font string The font key
---@return self
function BaseInput:SetFont(font)
	self._state.font = font
	return self
end

---Sets the hint text (shown when there's no other text in the input).
---@param value string|ReactivePublisherSchemaBase The hint text or a publisher
---@return self
function BaseInput:SetHintText(value)
	if type(value) == "string" then
		self._state.hintText = value
	else
		self:_MethodPublisher(value, "SetHintText")
	end
	return self
end

---Sets the inputs to jump to when tab (or shift-tab to go backwards) is pressed.
---@param prevElement BaseInput The previous input (for shift-tab)
---@param nextElement BaseInput The next input (for tab)
---@return self
function BaseInput:SetTabElements(prevElement, nextElement)
	self._tabPrevElement = prevElement
	self._tabNextElement = nextElement
	return self
end

---Set the highlight to all or some of the input's text.
---@param starting? number The position at which to start the highlight
---@param ending? number The position at which to stop the highlight
---@return self
function BaseInput:HighlightText(starting, ending)
	if starting and ending then
		self._editBox:HighlightText(starting, ending)
	else
		self._editBox:HighlightText()
	end
	return self
end

---Sets the current value.
---@param value string|number|ReactivePublisherSchemaBase The value or a publisher
---@return self
function BaseInput:SetValue(value)
	if type(value) == "number" then
		value = tostring(value)
	end
	if type(value) == "string" then
		assert(type(value) == "string")
		if self:_SetValueHelper(value, true) then
			self._escValue = self._state.value
		else
			self._escValue = nil
		end
		if not self._state.hasFocus then
			self._editBox:SetText(self._state.value)
			self._state.displayValue = self._state.value
		end
	else
		self:_MethodPublisher(value, "SetValue")
	end
	return self
end

---Sets whether or not the input is disabled.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the input is disabled or a publisher
---@return self
function BaseInput:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.disabled = value
		self._editBox:TSMSetDisabled(value)
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end

---Sets the function to use to validate the input text.
---@param validateFunc? fun(value: string, context: any): boolean, string? The validation func
---@param context? any Extra context to pass to the validate function.
---@return self
function BaseInput:SetValidateFunc(validateFunc, context)
	assert(type(validateFunc) == "function")
	self._validateFunc = validateFunc
	self._validateContext = context
	return self
end

---Returns the input's focus state.
---@return boolean
function BaseInput:HasFocus()
	return self._editBox:HasFocus()
end

---Sets whether or not this input is focused.
---@param focused boolean Whether or not this input is focused
---@return self
function BaseInput:SetFocused(focused)
	if focused then
		self._editBox:SetFocus()
	else
		self._editBox:ClearFocus()
	end
	return self
end

---Clears the highlight.
---@return self
function BaseInput:ClearHighlight()
	self._editBox:HighlightText(0, 0)
	return self
end

---Set the maximum number of letters for the input's entered text.
---@param number number The number of letters for entered text
---@return self
function BaseInput:SetMaxLetters(number)
	self._editBox:SetMaxLetters(number)
	return self
end

---Gets the input value.
---@return string
function BaseInput:GetValue()
	return strtrim(self._state.value)
end

---Sets the setting info.
---
-- This method is used to have the value of the input automatically correspond with the value of a
-- field in a table. This is useful for inputs which are tied directly to settings.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the input state
---@return self
function BaseInput:SetSettingInfo(tbl, key)
	assert(self._state.value == self._state:GetDefaultValue("value"))
	self._settingTable = tbl
	self._settingKey = key
	self:SetValue(tbl[key])
	return self
end

---Get the current validation state.
---@return boolean
function BaseInput:IsValid()
	return self._state.isValid
end

---Sets the input into paste mode for supporting the pasting of large strings.
---@return self
function BaseInput:SetPasteMode()
	self._pasteMode = true
	self._editBox:TSMSetScript("OnTextChanged", nil)
	self._editBox:SetMaxBytes(1)
	return self
end

---Sets the input as read-only so its text can be selected and copied but not edited.
---@return self
function BaseInput:SetReadOnly()
	self._readOnly = true
	return self
end

---Binds a state property to whether or not the input is valid.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function BaseInput:BindIsValid(state, key)
	self._bindings:Add("IS_VALID", state, key)
	return self
end

---Binds a state property to the input value.
---@param state ReactiveState The state to store the values in
---@param key string The state key to store the value at
---@return self
function BaseInput:BindValue(state, key)
	self._bindings:Add("VALUE", state, key)
	return self
end

---Mirrors the value with the specified state.
---@param state ReactiveState The state to mirror
---@param key string The state key to mirror
---@return self
function BaseInput:MirrorValueState(state, key)
	self:SetValue(state:Publisher(key))
	self:BindValue(state, key)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function BaseInput.__protected:_SetValueHelper(value, noCallback)
	if self:_ValidateValue(value) then
		self._state.value = strtrim(value)
		if self._settingTable then
			assert(self._settingKey)
			if type(self._settingTable[self._settingKey]) == "number" then
				value = tonumber(value)
				assert(value)
			end
			self._settingTable[self._settingKey] = value
		end
		if not noCallback then
			self._bindings:Process("VALUE", self:GetValue())
			self:_SendActionScript("OnValueChanged")
		end
		self:_SetIsValid(true)
		return true
	else
		if self._state.value == "" then
			self._state.value = strtrim(value)
		end
		self:_SetIsValid(false)
		return false
	end
end

function BaseInput.__protected:_ValidateValue(value)
	if not self._validateFunc then
		return true, nil
	end
	return self._validateFunc(strtrim(value), self._validateContext)
end

function BaseInput.__protected:_SetIsValid(isValid)
	if self._state.isValid == isValid then
		return
	end
	self._state.isValid = isValid
	self._bindings:Process("IS_VALID", isValid)
	self:_SendActionScript("OnValidationChanged")
end

function BaseInput.__protected:_ShouldKeepFocus()
	-- Can be overridden
	return false
end

function BaseInput.__protected:_OnFocusGained()
end

function BaseInput.__protected:_OnFocusLost()
end

function BaseInput.__protected:_SelectValue(value)
	if self:_SetValueHelper(value) then
		self._escValue = self._state.value
	end
	self._editBox:SetText(self._state.value)
	self._state.displayValue = self._state.value
end

function BaseInput.__protected:_OnChar(_, c)
	-- Can be overridden
	if not self._pasteMode then
		return
	end
	tinsert(self._pasteChars, c)
	self._editBox:TSMSetOnUpdate(self:__closure("_PasteOnUpdate"))
end

function BaseInput.__protected:_SetTextInsets(left, right, top, bottom)
	self._editBox:SetTextInsets(left, right, top, bottom)
	self._hintText:ClearAllPoints()
	self._hintText:SetPoint("TOPLEFT", left, 0)
	self._hintText:SetPoint("BOTTOMRIGHT", -right, 0)
	-- For some reason the text insets don't take effect right away, so on the next frame, we call GetTextInsets() which seems to fix things
	self._editBox:TSMSetOnUpdate(self:__closure("_FixInsetsOnUpdate"))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function BaseInput.__private:_HandleFocusLost()
	if self:HasFocus() then
		return
	end
	self:_OnFocusLost()
	self:_SendActionScript("OnFocusLost")
end

function BaseInput.__private:_OnEscapePressed()
	if self._escValue then
		self._state.value = self._escValue
		assert(self:_SetValueHelper(self._escValue))
	end
	self:SetFocused(false)
	self:HighlightText(0, 0)
	self._editBox:SetText(self._state.value)
	self._state.displayValue = self._state.value
end

function BaseInput.__private:_OnTabPressed()
	local isValid, err = self:_ValidateValue(self._editBox:GetText())
	if not isValid and err then
		-- TODO: Better way to show the error message?
		ChatMessage.PrintUser(err)
	end
	self:SetFocused(false)
	self:HighlightText(0, 0)
	if self._tabPrevElement and IsShiftKeyDown() then
		self._tabPrevElement:SetFocused(true)
	elseif self._tabNextElement and not IsShiftKeyDown() then
		self._tabNextElement:SetFocused(true)
	end
end

function BaseInput.__private:_OnEditFocusGained()
	self._state.hasFocus = true
	self._lostFocusTimer:Cancel()
	self:HighlightText()
	self:_OnFocusGained()
end

function BaseInput.__private:_OnEditFocusLost()
	self._state.hasFocus = false
	if self:_ShouldKeepFocus() then
		self:SetFocused(true)
		return
	end
	if self._state.isValid then
		self._escValue = self._state.value
	end
	self:HighlightText(0, 0)
	self._editBox:SetText(self._state.value)
	self._state.displayValue = self._state.value
	self:_SetIsValid(true)

	-- Wait until the next frame before calling the handler
	self._lostFocusTimer:RunForFrames(0)
end

function BaseInput.__private:_OnEnterPressed()
	local isValid, err = self:_ValidateValue(self._editBox:GetText())
	if not isValid and err then
		-- TODO: better way to show the error message?
		ChatMessage.PrintUser(err)
	end
	if isValid then
		self:SetFocused(false)
		self:HighlightText(0, 0)
		self:_SendActionScript("OnEnterPressed")
	end
end

function BaseInput.__private:_HandleOnTextChanged(_, isUserInput)
	if not isUserInput then
		return
	elseif self._readOnly then
		self._editBox:SetText(self._state.value)
		return
	end
	local value = self._editBox:GetText()
	self:_SetValueHelper(value)
	self._state.displayValue = value
end

function BaseInput.__private:_PasteOnUpdate()
	self._editBox:TSMSetOnUpdate(nil)
	local value = table.concat(self._pasteChars)
	wipe(self._pasteChars)
	self:_SetValueHelper(value)
	self._state.displayValue = value
end

function BaseInput.__private:_FixInsetsOnUpdate()
	self._editBox:TSMSetOnUpdate(nil)
	self._editBox:GetTextInsets()
end

function BaseInput.__private:_HandleFrameEnter()
	self._state.mouseOver = true
end

function BaseInput.__private:_HandleFrameLeave()
	self._state.mouseOver = false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateJustifyH(justifyH)
	return justifyH == "LEFT" or justifyH == "CENTER" or justifyH == "RIGHT"
end

function private.ValidateJustifyV(justifyV)
	return justifyV == "TOP" or justifyV == "MIDDLE" or justifyV == "BOTTOM"
end

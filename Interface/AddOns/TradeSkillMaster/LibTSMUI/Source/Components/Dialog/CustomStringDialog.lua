-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CustomStringDialog = ComponentRegistry.Define("CustomStringDialog", "BaseFrame")
CustomStringDialog._STATE_SCHEMA = CustomStringDialog._STATE_SCHEMA:Extend("CustomStringDialogState")
	:AddDeferredUIElementField("stringInput", "SyntaxInput")
	:AddStringField("title", "")
	:AddOptionalStringField("validationError")
	:Commit()
CustomStringDialog:_AddActionScripts("OnDoneEditing", "OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CustomStringDialog:__init()
	self.__super:__init()
	self._configured = false
	self._value = nil
	self._originalValue = nil
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function CustomStringDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetSize(590, 442)
		:SetPadding(12)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:AddAnchor("CENTER")
		:SetMouseEnabled(true)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 8)
			:AddChild(UIElements.New("Text", "title")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetJustifyH("LEFT")
				:SetText(EDIT..": ")
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetJustifyH("LEFT")
				:SetText(self._state:Publisher("title"))
			)
		)
	end
	self:_AddHeaderElements()
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("SyntaxInput", "input")
			:BindElement(self._state, "stringInput")
			:SetManager(self._childManager)
			:SetAction("OnValueChanged", "ACTION_HANDLE_INPUT_VALUE_CHANGED")
			:SetAction("OnDoneEditing", "ACTION_HANDLE_INPUT_DONE_EDITING")
		)
		self:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Text", "status")
				:SetMargin(0, 10, 0, 0)
				:SetFont("BODY_XSMALL")
				:SetJustifyH("RIGHT")
				:SetText(self._state:PublisherForFunctionWithKeys(private.ValidationErrorToStatusText, "validationError"))
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "cancelBtn")
				:SetWidth(81)
				:SetMargin(0, 10, 0, 0)
				:SetText(CANCEL)
				:SetAction("OnClick", "ACTION_CANCEL")
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "saveBtn")
				:SetWidth(121)
				:SetText(L["Save & Close"])
				:SetDisabled(self._state:Publisher("validationError"):ToBooleanNotEquals(nil))
				:SetAction("OnClick", "ACTION_SAVE")
			)
		)
	end
end

function CustomStringDialog:Release()
	self._configured = false
	self._value = nil
	self._originalValue = nil
	self.__super:Release()
end

---Configures the custom string dialog.
---@param title string The title text
---@param value string The current value
---@param validateFunc SyntaxInputValidateFunc The validation function
---@param badSources? table Bad sources to pass to the validation function as context
---@return self
function CustomStringDialog:Configure(title, value, validateFunc, badSources)
	assert(not self._configured)
	self._configured = true
	self._originalValue = value
	self._state.title = title
	self._state.stringInput
		:SetValidateFunc(validateFunc, badSources)
		:SetValue(value)
	self:_UpdateValidationError()
	self._value = value
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function CustomStringDialog.__protected:_AddHeaderElements()
	-- May be overridden by child classes
end

---@param manager UIManager<CustomStringDialogState>
---@param state CustomStringDialogState
function CustomStringDialog.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_CANCEL" then
		self:_HandleValue(self._originalValue)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	elseif action == "ACTION_SAVE" then
		assert(self._value)
		self:_HandleValue(self._value)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	elseif action == "ACTION_HANDLE_INPUT_VALUE_CHANGED" then
		local value = ...
		self._value = value
		self:_UpdateValidationError()
		self:_HandleValueChanged(not state.validationError and value or nil)
	elseif action == "ACTION_HANDLE_INPUT_DONE_EDITING" then
		local shouldSave = ...
		return manager:ProcessAction(shouldSave and "ACTION_SAVE" or "ACTION_CANCEL")
	else
		error("Unknown action: "..tostring(action))
	end
end

function CustomStringDialog.__protected:_HandleValue(value)
	self:_SendActionScript("OnDoneEditing", value)
end

function CustomStringDialog.__protected:_UpdateValidationError()
	local _, validationError = self._state.stringInput:GetValue()
	self._state.validationError = validationError
end

function CustomStringDialog.__protected:_HandleValueChanged(value)
	self:_SendActionScript("OnValueChanged", value)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidationErrorToStatusText(validationError)
	if validationError then
		return Theme.GetColor("error/main"):ColorText(validationError)
	else
		return L["Saved"]
	end
end

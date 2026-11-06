-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local FORMAT_LIST_KEYS = {
	"gold",
	"number",
	"pct",
}
local FORMAT_LIST = {
	format(L["Gold (%s)"], Money.ToStringForTooltip(12345678)),
	format(L["Number (%s)"], FormatLargeNumber(1234)),
	format(L["Percent (%s)"], Theme.GetAuctionPercentColor(89):ColorText("89%")),
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CustomSourceEditDialog = ComponentRegistry.Define("CustomSourceEditDialog", "CustomStringDialog")
CustomSourceEditDialog._STATE_SCHEMA = CustomSourceEditDialog._STATE_SCHEMA:Extend("CustomSourceEditDialogState")
	:AddDeferredUIElementField("nameInput", "Input")
	:AddBooleanField("nameIsValid", false)
	:AddStringField("name", "")
	:AddStringField("prevName", "")
	:AddOptionalStringField("newName")
	:AddNumberField("formatSelection", 1)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CustomSourceEditDialog:__init()
	self.__super:__init()
	self._nameValidateFunc = nil ---@type SyntaxInputValidateFunc!
end

function CustomSourceEditDialog:Release()
	self._nameValidateFunc = nil
	self.__super:Release()
end

---Configures the custom source edit dialog.
---@param name string The current custom source name
---@param nameValidateFunc SyntaxInputValidateFunc The validation function for the name
---@param formatKey "gold"|"number"|"pct" The format key
---@param value string The current value
---@param valueValidateFunc SyntaxInputValidateFunc The validation function for the custom string
---@return self
function CustomSourceEditDialog:Configure(name, nameValidateFunc, formatKey, value, valueValidateFunc)
	self.__super:Configure(L["Custom Source"], value, valueValidateFunc)
	self._state.prevName = name
	self._state.formatSelection = Table.KeyByValue(FORMAT_LIST_KEYS, formatKey)
	self._nameValidateFunc = nameValidateFunc
	self._state.nameIsValid = self:_ValidateName(name)
	self:_UpdateValidationError()
	self._state.name = name
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function CustomSourceEditDialog.__protected:_AddHeaderElements()
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "extraFields")
			:SetLayout("VERTICAL")
			:SetMargin(0, 0, 0, 8)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Text", "name")
				:SetHeight(20)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("LEFT")
				:SetText(L["Name"])
			)
			:AddChild(UIElements.New("Input", "nameInput")
				:SetHeight(24)
				:BindElement(self._state, "nameInput")
				:BindIsValid(self._state, "nameIsValid")
				:SetValue(self._state:Publisher("name"))
				:SetValidateFunc(self:__closure("_ValidateName"))
				:SetAction("OnValueChanged", "ACTION_HANDLE_NAME_CHANGE")
				:SetAction("OnValidationChanged", "ACTION_HANDLE_NAME_VALIDATION_CHANGE")
			)
			:AddChild(UIElements.New("Text", "format")
				:SetHeight(20)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("LEFT")
				:SetText(L["Display Format"])
			)
			:AddChild(UIElements.New("ListDropdown", "formatDropdown")
				:SetHeight(24)
				:SetItems(FORMAT_LIST)
				:MirrorSelectedItemIndexState(self._state, "formatSelection")
				:SetHintText(L["Select format"])
			)
			:AddChild(UIElements.New("Text", "string")
				:SetHeight(20)
				:SetMargin(0, 0, 6, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("LEFT")
				:SetText(L["String"])
			)
		)
	end
end

---@param manager UIManager<CustomSourceEditDialogState>
---@param state CustomSourceEditDialogState
function CustomSourceEditDialog.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_NAME_CHANGE" then
		state.newName = state.nameInput:GetValue()
	elseif action == "ACTION_HANDLE_NAME_VALIDATION_CHANGE" then
		self:_UpdateValidationError()
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function CustomSourceEditDialog.__private:_ValidateName(value)
	if value == "" then
		return false
	elseif gsub(value, "([a-z]+)", "") ~= "" then
		return false, L["Custom price names can only contain lowercase letters."]
	elseif value ~= self._state.prevName then
		return self._nameValidateFunc(value)
	else
		return true
	end
end

function CustomSourceEditDialog.__protected:_HandleValue(value)
	local oldName = self._state.prevName
	local newName = self._state.newName or self._state.prevName
	local format = FORMAT_LIST_KEYS[self._state.formatSelection]
	assert(format)
	self:_SendActionScript("OnDoneEditing", oldName, newName, format, value)
end

function CustomSourceEditDialog.__protected:_UpdateValidationError()
	self.__super:_UpdateValidationError()
	if not self._state.validationError and not self._state.nameIsValid then
		self._state.validationError = L["Invalid name"]
	end
end

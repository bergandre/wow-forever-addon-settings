-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkedCraftingPrice = ComponentRegistry.Define("OperationLinkedCraftingPrice", "OperationLinkedSettingLine")
OperationLinkedCraftingPrice._STATE_SCHEMA = OperationLinkedCraftingPrice._STATE_SCHEMA:Extend("OperationLinkedCraftingPriceState")
	:AddDeferredUIElementField("toggle", "ToggleYesNo")
	:AddDeferredUIElementField("input", "CustomStringSingleLineInput")
	:AddBooleanField("toggleValue", false)
	:AddBooleanField("isConfigured", false)
	:Commit()
OperationLinkedCraftingPrice:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedCraftingPrice:__init()
	self.__super:__init()
	self._defaultValue = nil
end

function OperationLinkedCraftingPrice:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		local disablePublisher = self._state:Publisher([[relationshipSet or disabled]])
			:Share()
		local toggleValuePublisher = self._state:Publisher("toggleValue")
			:Share()
		self:SetHeight(toggleValuePublisher:ReplaceBooleanWith(76, 40))
		self:AddChild(UIElements.New("ToggleYesNo", "toggle")
			:SetHeight(18)
			:BindElement(self._state, "toggle")
			:SetManager(self._childManager)
			:SetDisabled(disablePublisher)
			:BindValue(self._state, "toggleValue")
			:SetAction("OnValueChanged", "ACTION_VALUE_CHANGED")
		)
		self:AddChild(UIElements.New("CustomStringSingleLineInput", "input")
			:SetHeight(24)
			:SetMargin(0, 0, 12, 0)
			:BindElement(self._state, "input")
			:SetDisabled(disablePublisher)
			:SetShown(toggleValuePublisher)
		)
		self:AddCancellable(disablePublisher:EndShare())
		self:AddCancellable(toggleValuePublisher:EndShare())
	end
end

function OperationLinkedCraftingPrice:Release()
	self._defaultValue = nil
	self.__super:Release()
end

---Sets the operation setting to display in the toggle.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@param defaultValue string|nil The default value or nil to use the operation default
---@return self
function OperationLinkedCraftingPrice:SetOperationSetting(typeName, operationName, settingKey, defaultValue)
	assert(not self._state.isConfigured)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	self._defaultValue = defaultValue
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.input:SetSettingInfo(operationSettings, settingKey)
	self._state.toggle:SetValue(operationSettings[settingKey] ~= "")
	self._state.isConfigured = true
	return self
end

---Sets the bad sources for the custom string input.
---@param badSources? table<string,any> The bad sources as keys
---@return self
function OperationLinkedCraftingPrice:SetBadSources(badSources)
	self._state.input:SetBadSources(badSources)
	return self
end

---Configures the text shown by the element.
---@param toggleLabel string The label for the toggle
---@param toggleTooltip string The tooltip for the toggle
---@param valueLabel string The label for the value
---@param valueTooltip string The tooltip for the value
---@return self
function OperationLinkedCraftingPrice:ConfigureText(toggleLabel, valueLabel, toggleTooltip, valueTooltip)
	self:SetLabel(toggleLabel)
	self._state.toggle:SetTooltip(toggleTooltip, true)
	self._state.input
		:SetPopoutTitle(valueLabel)
		:SetTooltip(valueTooltip, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param state OperationLinkedCraftingPriceState
function OperationLinkedCraftingPrice.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_VALUE_CHANGED" then
		local value = ...
		if not state.isConfigured then
			return
		end
		if value then
			if self._defaultValue ~= nil then
				Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] = self._defaultValue
			else
				Operation.Reset(self._typeName, self._operationName, self._settingKey)
			end
		else
			Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] = ""
		end
		self:_UpdateValue()
		self:_SendActionScript("OnValueChanged", value)
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function OperationLinkedCraftingPrice.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	local value = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey]
	self._state.toggle:SetValue(value ~= "")
	self:_UpdateValue()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationLinkedCraftingPrice.__private:_UpdateValue()
	self._state.input
		:SetFocused(false)
		:SetValue(Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as string]])
	return self
end

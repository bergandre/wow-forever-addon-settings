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

local OperationLinkedToggleYesNoLine = ComponentRegistry.Define("OperationLinkedToggleYesNoLine", "OperationLinkedSettingLine")
OperationLinkedToggleYesNoLine._STATE_SCHEMA = OperationLinkedToggleYesNoLine._STATE_SCHEMA:Extend("OperationLinkedToggleYesNoLineState")
	:AddDeferredUIElementField("toggle", "ToggleYesNo")
	:Commit()
OperationLinkedToggleYesNoLine:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedToggleYesNoLine:__init()
	self.__super:__init()
	self._isOptionalStringSetting = false
end

function OperationLinkedToggleYesNoLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(40)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("ToggleYesNo", "toggle")
			:SetHeight(18)
			:BindElement(self._state, "toggle")
			:SetManager(self._childManager)
			:SetDisabled(self._state:Publisher([[relationshipSet or disabled]]))
			:SetAction("OnValueChanged", "ACTION_VALUE_CHANGED")
		)
	end
end

function OperationLinkedToggleYesNoLine:Release()
	self._isOptionalStringSetting = false
	self.__super:Release()
end

---Sets the operation setting to display in the toggle.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@param isOptionalStringSetting? boolean Treat an empty string as the "no" state of the toggle
---@return self
function OperationLinkedToggleYesNoLine:SetOperationSetting(typeName, operationName, settingKey, isOptionalStringSetting)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._isOptionalStringSetting = isOptionalStringSetting or false
	if isOptionalStringSetting then
		self._state.toggle:SetValue(operationSettings[settingKey] ~= "")
	else
		self._state.toggle:SetSettingInfo(operationSettings, settingKey)
	end
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param tooltip string The tooltip
---@return self
function OperationLinkedToggleYesNoLine:ConfigureText(label, tooltip)
	self:SetLabel(label)
	self._state.toggle:SetTooltip(tooltip, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param state OperationLinkedToggleYesNoLineState
function OperationLinkedToggleYesNoLine.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_VALUE_CHANGED" then
		local value = ...
		self:_SendActionScript("OnValueChanged", value)
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function OperationLinkedToggleYesNoLine.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	local value = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey]
	if self._isOptionalStringSetting then
		self._state.toggle:SetValue(value ~= "")
	else
		self._state.toggle:SetValue(value --[[@as boolean]])
	end
end

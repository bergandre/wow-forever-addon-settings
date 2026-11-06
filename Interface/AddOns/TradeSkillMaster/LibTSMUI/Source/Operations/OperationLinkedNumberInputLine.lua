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

local OperationLinkedNumberInputLine = ComponentRegistry.Define("OperationLinkedNumberInputLine", "OperationLinkedSettingLine")
OperationLinkedNumberInputLine._STATE_SCHEMA = OperationLinkedNumberInputLine._STATE_SCHEMA:Extend("OperationLinkedNumberInputLineState")
	:AddDeferredUIElementField("input", "CustomStringSingleLineInput")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedNumberInputLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("CustomStringSingleLineInput", "input")
			:SetHeight(24)
			:BindElement(self._state, "input")
			:SetDisabled(self._state:Publisher([[relationshipSet or disabled]]))
		)
	end
end

---Sets the operation setting to display in the input line.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkedNumberInputLine:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.input
		:SetSettingInfo(operationSettings, settingKey)
		:SetIsNumber(true)
	return self
end

---Sets the bad sources for the custom string input.
---@param badSources? table<string,any> The bad sources as keys
---@return self
function OperationLinkedNumberInputLine:SetBadSources(badSources)
	self._state.input:SetBadSources(badSources)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param tooltip string The tooltip
---@param range Range The valid range
---@return self
function OperationLinkedNumberInputLine:ConfigureText(label, tooltip, range)
	self:SetLabel(label)
	self._state.input
		:SetPopoutTitle(label)
		:SetRangeTooltip(tooltip, range, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OperationLinkedNumberInputLine.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	self._state.input
		:SetFocused(false)
		:SetValue(Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as string]])
end

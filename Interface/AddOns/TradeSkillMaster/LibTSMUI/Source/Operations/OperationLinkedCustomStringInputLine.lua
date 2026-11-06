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

local OperationLinkedCustomStringInputLine = ComponentRegistry.Define("OperationLinkedCustomStringInputLine", "OperationLinkedSettingLine")
OperationLinkedCustomStringInputLine._STATE_SCHEMA = OperationLinkedCustomStringInputLine._STATE_SCHEMA:Extend("OperationLinkedCustomStringInputLineState")
	:AddDeferredUIElementField("input", "CustomStringSingleLineInput")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedCustomStringInputLine:Acquire()
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
---@param isUndercut? boolean Whether or not this is an undercut setting
---@return self
function OperationLinkedCustomStringInputLine:SetOperationSetting(typeName, operationName, settingKey, isUndercut)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	self._state.input
		:SetIsUndercut(isUndercut or false)
		:SetSettingInfo(Operation.GetSettings(typeName, operationName), settingKey)
	return self
end

---Sets the bad sources for the custom string input.
---@param badSources? table<string,any> The bad sources as keys
---@return self
function OperationLinkedCustomStringInputLine:SetBadSources(badSources)
	self._state.input:SetBadSources(badSources)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param tooltip string The tooltip
---@return self
function OperationLinkedCustomStringInputLine:ConfigureText(label, tooltip)
	self:SetLabel(label)
	self._state.input
		:SetPopoutTitle(label)
		:SetTooltip(tooltip, true)
	return self
end

---Updates the value shown by the input line.
---@return self
function OperationLinkedCustomStringInputLine:UpdateValue()
	self._state.input
		:SetFocused(false)
		:SetValue(Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as string]])
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OperationLinkedCustomStringInputLine.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	self:UpdateValue()
end

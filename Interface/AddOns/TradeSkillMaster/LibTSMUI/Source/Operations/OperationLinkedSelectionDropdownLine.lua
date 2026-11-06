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

local OperationSelectionDropdownLine = ComponentRegistry.Define("OperationSelectionDropdownLine", "OperationLinkedSettingLine")
OperationSelectionDropdownLine._STATE_SCHEMA = OperationSelectionDropdownLine._STATE_SCHEMA:Extend("OperationSelectionDropdownLineState")
	:AddDeferredUIElementField("dropdown", "SelectionDropdown")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationSelectionDropdownLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("SelectionDropdown", "dropdown")
			:SetHeight(24)
			:BindElement(self._state, "dropdown")
			:SetDisabled(self._state:Publisher([[relationshipSet or disabled]]))
		)
	end
end

---Sets the operation setting to display in the dropdown.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationSelectionDropdownLine:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.dropdown:SetSettingInfo(operationSettings, settingKey)
	return self
end

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@param itemKeys (string|number)[] A list of keys which go with the item at the corresponding index in the items list
---@return self
function OperationSelectionDropdownLine:SetItems(items, itemKeys)
	self._state.dropdown:SetItems(items, itemKeys)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param hintText string The dropdown hint text
---@param tooltip string The tooltip
---@return self
function OperationSelectionDropdownLine:ConfigureText(label, hintText, tooltip)
	self:SetLabel(label)
	self._state.dropdown:SetHintText(hintText)
	self._state.dropdown:SetTooltip(tooltip, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OperationSelectionDropdownLine.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	local selection = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as string|number]]
	self._state.dropdown:SetSelectedItemByKey(selection, true)
end

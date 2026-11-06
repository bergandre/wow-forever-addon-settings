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

local OperationLinkedListDropdownLine = ComponentRegistry.Define("OperationLinkedListDropdownLine", "OperationLinkedSettingLine")
OperationLinkedListDropdownLine._STATE_SCHEMA = OperationLinkedListDropdownLine._STATE_SCHEMA:Extend("OperationLinkedListDropdownLineState")
	:AddDeferredUIElementField("dropdown", "ListDropdown")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedListDropdownLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("ListDropdown", "dropdown")
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
function OperationLinkedListDropdownLine:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.dropdown:SetSettingInfo(operationSettings, settingKey)
	return self
end

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@return self
function OperationLinkedListDropdownLine:SetItems(items)
	self._state.dropdown:SetItems(items)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param hintText string The dropdown hint text
---@param tooltip string The tooltip
---@return self
function OperationLinkedListDropdownLine:ConfigureText(label, hintText, tooltip)
	self:SetLabel(label)
	self._state.dropdown:SetHintText(hintText)
	self._state.dropdown:SetTooltip(tooltip, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OperationLinkedListDropdownLine.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	local selection = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as number]]
	self._state.dropdown:SetSelectedItemByIndex(selection, true)
end

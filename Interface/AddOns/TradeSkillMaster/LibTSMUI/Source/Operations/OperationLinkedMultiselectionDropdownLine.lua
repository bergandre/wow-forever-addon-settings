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

local OperationLinkedMultiselectionDropdownLine = ComponentRegistry.Define("OperationLinkedMultiselectionDropdownLine", "OperationLinkedSettingLine")
OperationLinkedMultiselectionDropdownLine._STATE_SCHEMA = OperationLinkedMultiselectionDropdownLine._STATE_SCHEMA:Extend("OperationLinkedMultiselectionDropdownLineState")
	:AddDeferredUIElementField("dropdown", "MultiselectionDropdown")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedMultiselectionDropdownLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
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
function OperationLinkedMultiselectionDropdownLine:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.dropdown:SetSettingInfo(operationSettings, settingKey)
	return self
end

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@param itemKeys? string[] A list of keys which go with the item at the corresponding index in the items list
---@return self
function OperationLinkedMultiselectionDropdownLine:SetItems(items, itemKeys)
	self._state.dropdown:SetItems(items, itemKeys)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param noneText string The selection text string when none are selected
---@param partialText string The selection text string for a partial selection
---@param allText string The selection text string when all are selected
---@param hintText string The hint text for the dropdown
---@param tooltip string The tooltip
---@return self
function OperationLinkedMultiselectionDropdownLine:ConfigureText(label, noneText, partialText, allText, hintText, tooltip)
	self:SetLabel(label)
	self._state.dropdown
		:SetSelectionText(noneText, partialText, allText)
		:SetHintText(hintText)
		:SetTooltip(tooltip, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OperationLinkedMultiselectionDropdownLine.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	local selection = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as table]]
	self._state.dropdown:SetSelectedItemKeys(selection)
end

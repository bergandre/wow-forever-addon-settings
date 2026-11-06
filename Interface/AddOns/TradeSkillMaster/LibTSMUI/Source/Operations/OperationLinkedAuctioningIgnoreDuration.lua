-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkedAuctioningIgnoreDuration = ComponentRegistry.Define("OperationLinkedAuctioningIgnoreDuration", "OperationLinkedSettingLine")
OperationLinkedAuctioningIgnoreDuration._STATE_SCHEMA = OperationLinkedAuctioningIgnoreDuration._STATE_SCHEMA:Extend("OperationLinkedAuctioningIgnoreDurationState")
	:AddDeferredUIElementField("dropdown", "ListDropdown")
	:AddNumberField("duration", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedAuctioningIgnoreDuration:__init()
	self.__super:__init()
	self._childManager:SuppressActionLog("ACTION_REBUILD_DB")
end

function OperationLinkedAuctioningIgnoreDuration:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("ListDropdown", "dropdown")
			:SetHeight(24)
			:BindElement(self._state, "dropdown")
			:SetManager(self._childManager)
			:SetDisabled(self._state:Publisher([[relationshipSet or disabled]]))
			:SetHintText(L["Select duration"])
			:SetAction("OnSelectionChanged", "ACTION_REBUILD_DB")
		)
	end
end

---Sets the operation setting to display in the dropdown.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkedAuctioningIgnoreDuration:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local selection = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey]
	assert(type(selection) == "number")
	local index = selection + 1
	self._state.dropdown:SetSelectedItemByIndex(index, true)
	return self
end

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@return self
function OperationLinkedAuctioningIgnoreDuration:SetItems(items)
	self._state.dropdown:SetItems(items)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param tooltip string The tooltip
---@return self
function OperationLinkedAuctioningIgnoreDuration:ConfigureText(label, tooltip)
	self:SetLabel(label)
	self._state.dropdown:SetTooltip(tooltip, true)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param manager UIManager<OperationLinkedAuctioningIgnoreDurationState>
---@param state OperationLinkedAuctioningIgnoreDurationState
function OperationLinkedAuctioningIgnoreDuration.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_REBUILD_DB" then
		local selection = state.dropdown:GetSelectedItemIndex()
		assert(selection)
		Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] = selection - 1
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function OperationLinkedAuctioningIgnoreDuration.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	self._state.dropdown:SetSelectedItemByIndex(Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as number]] + 1, true)
end

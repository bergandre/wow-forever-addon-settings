-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationManagementSettingsFrame = ComponentRegistry.Define("OperationManagementSettingsFrame", "BaseFrame")
OperationManagementSettingsFrame._STATE_SCHEMA = OperationManagementSettingsFrame._STATE_SCHEMA:Extend("OperationManagementSettingsFrameState")
	:AddDeferredUIElementField("ignoreSettingsFrame", "OperationIgnoreSettingsFrame")
	:AddDeferredUIElementField("groupManagementFrame", "OperationGroupManagementFrame")
	:Commit()
OperationManagementSettingsFrame:_AddActionScripts("OnViewGroup", "OnGroupsChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationManagementSettingsFrame:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function OperationManagementSettingsFrame:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:AddChild(UIElements.New("OperationIgnoreSettingsFrame", "ignoreSettings")
		:SetMargin(0, 0, 0, 24)
		:BindElement(self._state, "ignoreSettingsFrame")
	)
	self:AddChild(UIElements.New("OperationGroupManagementFrame", "groupManagement")
		:SetMargin(0, 0, 0, 24)
		:BindElement(self._state, "groupManagementFrame")
		:SetManager(self._childManager)
	)
end

---Configures the operation ignore settings frame.
---@param typeName string The operation type name
---@param operationName string The operation name
---@param settingsDB SettingsDB The settings DB to use to get the available factionrealms and characters
---@return self
function OperationManagementSettingsFrame:Configure(typeName, operationName, settingsDB)
	self._state.ignoreSettingsFrame
		:Configure(typeName, operationName, settingsDB)
	self._state.groupManagementFrame
		:SetOperation(typeName, operationName)
		:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
		:SetAction("OnGroupsChanged", "ACTION_GROUPS_CHANGED")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state OperationGroupManagementFrameState
function OperationManagementSettingsFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		self:_SendActionScript("OnViewGroup", groupPath)
	elseif action == "ACTION_GROUPS_CHANGED" then
		self:_SendActionScript("OnGroupsChanged")
	else
		error("Unknown action: "..tostring(action))
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationGroupManagementFrame = ComponentRegistry.Define("OperationGroupManagementFrame", "SettingsCollapsibleContainer")
OperationGroupManagementFrame._STATE_SCHEMA = OperationGroupManagementFrame._STATE_SCHEMA:Extend("OperationGroupManagementFrameState")
	:AddDeferredUIElementField("groupSelector", "GroupSelector")
	:Commit()
OperationGroupManagementFrame:_AddActionScripts("OnViewGroup", "OnGroupsChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationGroupManagementFrame:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._typeName = nil ---@type string!
	self._operationName = nil ---@type string!
end

function OperationGroupManagementFrame:Acquire()
	self.__super:Acquire()
	self:SetLargeHeading()
	self:SetHeadingDescription(L["Group Management"], L["Here you can add/remove what groups this operation is attached to."])
	self:AddChild(UIElements.New("SettingsField", "applyNewGroup")
		:SetManager(self._childManager)
		:SetLabel(L["Apply operation to group"])
		:AddChild(UIElements.New("GroupSelector", "group")
			:SetHeight(24)
			:BindElement(self._state, "groupSelector")
			:SetHintText(L["Add operation to groups"])
			:SetAction("OnSelectionChanged", "ACTION_ADD_OPERATION_TO_GROUP")
		)
	)
end

function OperationGroupManagementFrame:Release()
	self._typeName = nil
	self._operationName = nil
	self.__super:Release()
end

---Sets the current operation.
---@param typeName string The operation type name
---@param operationName string The operation name
---@return self
function OperationGroupManagementFrame:SetOperation(typeName, operationName)
	assert(not self._typeName)
	self._typeName = typeName
	self._operationName = operationName
	for _, groupPath in GroupOperation.GroupIteratorByOperation(self._typeName, self._operationName, true) do
		self:_AddGroupLine(groupPath)
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param state OperationGroupManagementFrameState
function OperationGroupManagementFrame.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		self:_SendActionScript("OnViewGroup", groupPath)
	elseif action == "ACTION_REMOVE_GROUP" then
		local line = ...
		self._state.contentFrame:RemoveChild(line)
		self:_SendActionScript("OnGroupsChanged")
	elseif action == "ACTION_ADD_OPERATION_TO_GROUP" then
		for groupPath in state.groupSelector:SelectedGroupIterator() do
			if not GroupOperation.HasOperation(groupPath, self._typeName, self._operationName) then
				local removedOperationName = GroupOperation.Add(groupPath, self._typeName, self._operationName)
				if removedOperationName then
					ChatMessage.PrintfUser(L["%s previously had the max number of operations, so removed %s."], ChatMessage.ColorUserAccentText(Group.FormatPath(groupPath)), ChatMessage.ColorUserAccentText(removedOperationName))
				end
				ChatMessage.PrintfUser(L["Added %s to %s."], ChatMessage.ColorUserAccentText(self._operationName), ChatMessage.ColorUserAccentText(groupPath == Group.GetRootPath() and L["Base Group"] or Group.FormatPath(groupPath)))
				self:_AddGroupLine(groupPath)
			end
		end
		state.groupSelector:ClearSelectedGroups(true)
		self:_SendActionScript("OnGroupsChanged")
	else
		error("Unknown action: "..tostring(action))
	end
end

function OperationGroupManagementFrame.__private:_AddGroupLine(groupPath)
	self:AddChild(UIElements.New("OperationGroupLine", "group")
		:SetHeight(20)
		:SetMargin(0, 0, 12, 0)
		:SetGroupAndOperation(groupPath, self._typeName, self._operationName)
		:SetManager(self._childManager)
		:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
		:SetAction("OnRemoved", "ACTION_REMOVE_GROUP")
	)
end

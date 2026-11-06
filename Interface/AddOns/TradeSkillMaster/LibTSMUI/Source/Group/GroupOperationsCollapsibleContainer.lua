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
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local Analytics = LibTSMUI:From("LibTSMService"):Include("Util.Analytics")
local TYPE_LABELS = {
	Auctioning = L["Auctioning operations control posting to and canceling from the AH."],
	Crafting = L["Crafting operations control how queuing profession crafts."],
	Mailing = L["Mailing operations control mailing to other characters."],
	Shopping = L["Shopping operations control buyout from the AH."],
	Sniper = L["Sniper operations control sniping from the AH."],
	Vendoring = L["Vendoring operations control selling to and buying from a vendor."],
	Warehousing = L["Warehousing operations control moving in and out of the bank."],
}
local ROW_HEIGHT = 36



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupOperationsCollapsibleContainer = ComponentRegistry.Define("GroupOperationsCollapsibleContainer", "CollapsibleContainer")
GroupOperationsCollapsibleContainer._STATE_SCHEMA = GroupOperationsCollapsibleContainer._STATE_SCHEMA:Extend("GroupOperationsCollapsibleContainerState")
	:AddDeferredUIElementField("rowsContainer", "BaseFrame")
	:AddDeferredStringField("groupPath")
	:AddDeferredStringField("typeName")
	:AddBooleanField("override", false)
	:AddNumberField("numOperations", 0)
	:AddNumberField("maxOperations", 0)
	:Commit()
GroupOperationsCollapsibleContainer:_AddActionScripts("OnDraggingUpdate", "OnShowSettings", "OnContentUpdated")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupOperationsCollapsibleContainer:__init()
	self.__super:__init()
	self._childManager:SuppressActionLog("ACTION_UPDATE_DRAGGING")
end

function GroupOperationsCollapsibleContainer:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		local typeNamePublisher = self._state:Publisher("typeName")
			:IgnoreNil()
			:Share()
			:Map(Operation.GetMaxNumber)
			:AssignToTableKey(self._state, "maxOperations")
		self:SetHeadingText(typeNamePublisher:ToStringFormat(L["%s Operations"]))
		self:AddChild(UIElements.New("Text", "moduleDesc")
			:SetSize("AUTO", 20)
			:SetFont("BODY_XSMALL")
			:SetText(typeNamePublisher:Map(TYPE_LABELS))
		)
		self:AddChild(UIElements.New("Checkbox", "overrideCheckbox")
			:SetHeight(20)
			:SetMargin(0, 0, 6, 0)
			:SetText(L["Override Parent Operations"])
			:SetManager(self._childManager)
			:MirrorIsCheckedState(self._state, "override")
			:SetAction("OnValueChanged", "ACTION_SET_OVERRIDE")
			:SetShown(self._state:Publisher("groupPath"):IgnoreNil():ToBooleanNotEquals(Group.GetRootPath()))
		)
		self:AddChild(UIElements.New("BaseFrame", "container")
			:SetLayout("VERTICAL")
			:SetHeight(self._state:Publisher(format([[%d * numOperations]], ROW_HEIGHT)))
			:BindElement(self._state, "rowsContainer")
		)
		self:AddChild(UIElements.New("BaseFrame", "addMore")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("SmallTertiaryActionButton", "button")
				:SetWidth("AUTO")
				:SetPadding(8, 8, 0, 0)
				:SetText(L["Add More Operations"])
				:SetManager(self._childManager)
				:SetAction("OnClick", "ACTION_SHOW_ADD_DIALOG")
			)
			:SetShown(self._state:Publisher([[override and numOperations < maxOperations]]))
		)
		self:AddCancellable(typeNamePublisher:EndShare())
	end
end

---Configures the container.
---@param typeName string The type of the operation
---@param groupPath GroupPathValue The current group path
---@return self
function GroupOperationsCollapsibleContainer:Configure(typeName, groupPath)
	self._state.typeName = typeName
	self._state.groupPath = groupPath
	self._childManager:ProcessAction("ACTION_UPDATE_CONTENT")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GroupOperationsCollapsibleContainerState>
---@param state GroupOperationsCollapsibleContainerState
function GroupOperationsCollapsibleContainer.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_CONTENT" then
		assert(state.typeName and state.groupPath)
		state.numOperations =  GroupOperation.NumOperations(state.groupPath, state.typeName)
		state.override = GroupOperation.HasOverride(state.groupPath, state.typeName) or state.groupPath == Group.GetRootPath()
		state.rowsContainer:ReleaseAllChildren()
		for i, operationName in GroupOperation.Iterator(state.groupPath, state.typeName) do
			state.rowsContainer:AddChild(UIElements.New("GroupOperationRow", "operation"..i)
				:SetHeight(28)
				:SetMargin(0, 0, 8, 0)
				:Configure(state.typeName, i, operationName, state.groupPath)
				:SetManager(self._childManager)
				:SetAction("OnDraggingUpdate", "ACTION_UPDATE_DRAGGING")
				:SetAction("OnDraggingDone", "ACTION_UPDATE_CONTENT")
				:SetAction("OnConfigure", "ACTION_SHOW_SETTINGS")
				:SetAction("OnRemove", "ACTION_REMOVE")
			)
		end
		self:_SendActionScript("OnContentUpdated")
	elseif action == "ACTION_UPDATE_DRAGGING" then
		self:_SendActionScript("OnDraggingUpdate")
	elseif action == "ACTION_SET_OVERRIDE" then
		assert(state.typeName and state.groupPath and state.groupPath ~= Group.GetRootPath())
		GroupOperation.SetOverride(state.groupPath, state.typeName, state.override)
		Analytics.Action("CHANGED_GROUP_OVERRIDE", state.groupPath, state.typeName, state.override)
		return manager:ProcessAction("ACTION_UPDATE_CONTENT", state.typeName)
	elseif action == "ACTION_REMOVE" then
		local operationName = ...
		local operationIndex = nil
		for index, name in GroupOperation.Iterator(state.groupPath, state.typeName) do
			if name == operationName then
				operationIndex = index
			end
		end
		assert(operationIndex)
		GroupOperation.Remove(state.groupPath, state.typeName, operationIndex)
		Analytics.Action("REMOVED_GROUP_OPERATION", state.groupPath, state.typeName, operationName)
		return manager:ProcessAction("ACTION_UPDATE_CONTENT")
	elseif action == "ACTION_SHOW_ADD_DIALOG" then
		assert(state.typeName and state.groupPath)
		self:GetBaseElement():ShowDialogFrame(UIElements.New("GroupAddOperationDialog", "frame")
			:SetSize(464, 318)
			:AddAnchor("CENTER")
			:SetManager(manager)
			:Configure(state.typeName, state.groupPath)
			:SetAction("OnOperationCreatedAndAdded", "ACTION_SHOW_SETTINGS")
			:SetAction("OnOperationAdded", "ACTION_HANDLE_OPERATION_ADDED")
		)
	elseif action == "ACTION_SHOW_SETTINGS" then
		local operationName = ...
		assert(state.typeName)
		self:GetBaseElement():HideDialog()
		self:_SendActionScript("OnShowSettings", state.typeName, operationName)
	elseif action == "ACTION_HANDLE_OPERATION_ADDED" then
		self:GetBaseElement():HideDialog()
		return manager:ProcessAction("ACTION_UPDATE_CONTENT")
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

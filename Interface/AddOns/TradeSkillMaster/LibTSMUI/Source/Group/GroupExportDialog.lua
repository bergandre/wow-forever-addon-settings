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
local GroupExport = LibTSMUI:From("LibTSMTypes"):IncludeClassType("GroupExport")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local IGNORED_OPERATION_TYPES = { "Mailing" }



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupExportDialog = ComponentRegistry.Define("GroupExportDialog", "BaseFrame")
GroupExportDialog._STATE_SCHEMA = GroupExportDialog._STATE_SCHEMA:Extend("GroupExportDialogState")
	:AddDeferredUIElementField("groupSelector", "GroupSelector")
	:AddDeferredUIElementField("input", "MultiLineInput")
	:AddStringField("groupPath", Group.GetRootPath())
	:AddStringField("str", "")
	:AddNumberField("numItems", 0)
	:AddNumberField("numSubGroups", 0)
	:AddNumberField("numOperations", 0)
	:AddNumberField("numCustomSources", 0)
	:AddBooleanField("excludeOperations", false)
	:AddBooleanField("excludeCustomSources", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupExportDialog:__init()
	self.__super:__init()
	self._exportObj = GroupExport.New(IGNORED_OPERATION_TYPES)
	self._db = nil ---@type DatabaseTable!
	self._exportSubGroups = {}
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function GroupExportDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(658, 408)
	self:SetPadding(12)
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:SetMouseEnabled(true)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 12)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetJustifyH("CENTER")
				:SetText(self._state:PublisherForFunctionWithKeys(private.GroupPathToColoredGroupName, "groupPath"):ToStringFormat(L["Export"]..": %s"))
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		self:AddChild(UIElements.New("Text", "desc")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_XSMALL")
			:SetText(L["You can use the export string below to share this group with others."])
		)
		self:AddChild(UIElements.New("BaseFrame", "options")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("GroupSelector", "subGroups")
				:SetWidth(240)
				:SetMargin(0, 12, 0, 0)
				:BindElement(self._state, "groupSelector")
				:SetSelectedText(L["%d subgroups included"])
				:SetSelection(self._exportSubGroups)
				:SetHintText(L["Select included subgroups"])
				:SetAction("OnSelectionChanged", "ACTION_UPDATE_SUB_GROUPS")
			)
			:AddChild(UIElements.New("Checkbox", "excludeOperations")
				:SetWidth("AUTO")
				:SetMargin(0, 12, 0, 0)
				:SetText(L["Exclude operations?"])
				:MirrorIsCheckedState(self._state, "excludeOperations")
				:SetAction("OnValueChanged", "ACTION_HANDLE_EXCLUDE_OPTIONS_CHANGED")
			)
			:AddChild(UIElements.New("Checkbox", "excludeCustomSources")
				:SetWidth("AUTO")
				:SetMargin(0, 12, 0, 0)
				:SetText(L["Exclude custom sources?"])
				:MirrorIsCheckedState(self._state, "excludeCustomSources")
				:SetDisabled(self._state:Publisher("excludeOperations"))
				:SetAction("OnValueChanged", "ACTION_HANDLE_EXCLUDE_OPTIONS_CHANGED")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
		self:AddChild(UIElements.New("Text", "heading")
			:SetMargin(0, 0, 0, 8)
			:SetHeight(20)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(L["Export String"])
		)
		self:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetRoundedBackgroundColor("container/lowest")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("MultiLineInput", "input")
				:BindElement(self._state, "input")
				:SetValue(self._state:Publisher("str"))
				:SetAction("OnValueChanged", "ACTION_HANDLE_INPUT_CHANGED")
			)
			:AddChild(UIElements.New("BaseFrame", "footer")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:SetPadding(8, 8, 4, 4)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "items")
					:SetWidth("AUTO")
					:SetMargin(8, 8, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(self._state:Publisher("numItems"):ToStringFormat(L["%d Items"]))
				)
				:AddChild(UIElements.New("Text", "subGroups")
					:SetWidth("AUTO")
					:SetMargin(8, 8, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(self._state:Publisher("numSubGroups"):ToStringFormat(L["%d Sub-Groups"]))
				)
				:AddChild(UIElements.New("Text", "operations")
					:SetWidth("AUTO")
					:SetMargin(8, 8, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(self._state:Publisher("numOperations"):ToStringFormat(L["%d Operations"]))
				)
				:AddChild(UIElements.New("Text", "customSources")
					:SetWidth("AUTO")
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(self._state:Publisher("numCustomSources"):ToStringFormat(L["%d Custom Sources"]))
				)
			)
		)
	end
end

function GroupExportDialog:Release()
	self._db = nil
	wipe(self._exportSubGroups)
	self.__super:Release()
end

---Configures the export dialog.
---@param groupPath GroupPathValue The group path
---@param db DatabaseTable A database table to use to populate with export data
---@return self
function GroupExportDialog:Configure(groupPath, db)
	self._db = db
	self._state.groupSelector:SetCustomQueryFunc(self:__closure("_CreateQuery"))
	self._state.groupPath = groupPath
	self._exportObj:Reset()
	self._exportObj:SetPath(groupPath)
	self._exportObj:SetOperationsIncluded(not self._state.excludeOperations, not self._state.excludeOperations and not self._state.excludeCustomSources)
	self._db:TruncateAndBulkInsertStart()
	wipe(self._exportSubGroups)
	for _, childGroupPath in GroupOperation.GroupIterator() do
		if Group.IsChild(childGroupPath, groupPath) then
			local relativeGroupPath = Group.GetRelativePath(childGroupPath, self._state.groupPath)
			self._db:BulkInsertNewRow(relativeGroupPath, Group.GetSortableString(relativeGroupPath))
			self._exportSubGroups[relativeGroupPath] = true
		end
	end
	self._db:BulkInsertEnd()
	self._exportObj:SetSubGroupsIncluded(self._exportSubGroups)
	self:_UpdateStateFromExportObj()
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GroupExportDialogState>
---@param state GroupExportDialogState
function GroupExportDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_HANDLE_EXCLUDE_OPTIONS_CHANGED" then
		self._exportObj:SetOperationsIncluded(not state.excludeOperations, not state.excludeOperations and not state.excludeCustomSources)
		self:_UpdateStateFromExportObj()
	elseif action == "ACTION_UPDATE_SUB_GROUPS" then
		wipe(self._exportSubGroups)
		for relativeGroupPath in state.groupSelector:SelectedGroupIterator() do
			self._exportSubGroups[relativeGroupPath] = true
		end
		self._exportObj:SetSubGroupsIncluded(self._exportSubGroups)
		self:_UpdateStateFromExportObj()
	elseif action == "ACTION_HANDLE_INPUT_CHANGED" then
		state.input:SetValue(self._exportObj:GetString())
			:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

function GroupExportDialog.__private:_UpdateStateFromExportObj()
	self._state.str = self._exportObj:GetString()
	self._state.numItems = self._exportObj:GetNumItems()
	self._state.numSubGroups = self._exportObj:GetNumSubGroups()
	self._state.numOperations = self._exportObj:GetNumOperations()
	self._state.numCustomSources = self._exportObj:GetNumCustomSources()
	self:Draw()
end

function GroupExportDialog.__private:_CreateQuery()
	return self._db:NewOwnedQuery()
		:OrderBy("orderStr", true)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GroupPathToColoredGroupName(groupPath)
	return Theme.GetGroupColor(Group.GetLevel(groupPath)):ColorText(Group.GetName(groupPath))
end

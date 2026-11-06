-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local CustomString = LibTSMUI:From("LibTSMTypes"):Include("CustomString")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupImport = LibTSMUI:From("LibTSMTypes"):IncludeClassType("GroupImport")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local DEFAULT_IMPORT_GROUP_TREE_CONTEXT = { unselected = {}, collapsed = {} }
local IMPORT_EXPORT_IGNORED_OPERATION_TYPES = { "Mailing" }
local private = {}
local GROUPS_URL = nil
do
	if LibTSMUI.IsRetail() or LibTSMUI.IsForever() then
		GROUPS_URL = "https://tradeskillmaster.com/retail/groups"
	elseif LibTSMUI.IsMistsClassic() then
		GROUPS_URL = "https://tradeskillmaster.com/classic-progression/groups"
	else
		GROUPS_URL = "https://tradeskillmaster.com/classic/groups"
	end
end



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupImportDialog = ComponentRegistry.Define("GroupImportDialog", "BaseFrame")
GroupImportDialog._STATE_SCHEMA = GroupImportDialog._STATE_SCHEMA:Extend("GroupImportDialogState")
	:AddDeferredUIElementField("view", "ViewContainer")
	:AddDeferredUIElementField("input", "MultiLineInput")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddBooleanField("moveItems", true)
	:AddBooleanField("includeOperations", true)
	:AddBooleanField("replaceOperations", true)
	:AddNumberField("numItems", 0)
	:AddNumberField("numGroups", 0)
	:AddNumberField("numExistingItems", 0)
	:AddNumberField("numOperations", 0)
	:AddNumberField("numExistingOperations", 0)
	:AddNumberField("numExistingCustomSources", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupImportDialog:__init()
	self.__super:__init()
	self._db = nil ---@type DatabaseTable!
	self._groupTreeContext = {}
	self._importObj = GroupImport.New(L["Imported Group"], CustomString.IsCustomSourceRegistered, IMPORT_EXPORT_IGNORED_OPERATION_TYPES)
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function GroupImportDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:SetMouseEnabled(true)
	self:AddChild(UIElements.New("ViewContainer", "view")
		:SetManager(self._childManager)
		:SetNavCallback(self:__closure("_GetViewContentFrame"))
		:AddPath("input", true)
		:AddPath("summary")
		:BindElement(self._state, "view")
	)
end

function GroupImportDialog:Release()
	self._importObj:Reset()
	self._db = nil
	wipe(self._groupTreeContext)
	self.__super:Release()
end

---Configures the dialog.
---@param db DatabaseTable A database table to use to populate with export data
---@return self
function GroupImportDialog:Configure(db)
	self._db = db
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GroupImportDialogState>
---@param state GroupImportDialogState
function GroupImportDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_HANDLE_VALUE_CHANGED" then
		local value = state.input:GetValue()
		local success, numInvalidItems, numChangedOperations = self._importObj:Process(value)
		if not success then
			ChatMessage.PrintUser(L["The pasted value was not valid. Ensure you are pasting the entire import string."])
			return manager:ProcessAction("ACTION_CLOSE_DIALOG")
		end
		if numInvalidItems > 0 then
			ChatMessage.PrintfUser(L["NOTE: The import contained %d invalid items which were ignored."], numInvalidItems)
		end
		if numChangedOperations > 0 then
			ChatMessage.PrintfUser(L["NOTE: The import contained %d operations with at least one invalid setting which was reset."], numChangedOperations)
		end

		-- Build the import group DB
		self._db:TruncateAndBulkInsertStart()
		local groupName = self._importObj:GetPendingGroupName()
		for groupPath in self._importObj:PendingGroupIterator() do
			groupPath = groupPath == Group.GetRootPath() and groupName or Group.JoinPath(groupName, groupPath)
			self._db:BulkInsertNewRow(groupPath, Group.GetSortableString(groupPath))
		end
		self._db:BulkInsertEnd()

		-- Switch to the summary view
		state.view:SetPath("summary")
		self:_UpdateTotals()
	elseif action == "ACTION_HANDLE_GROUPS_UPDATED" then
		local groupName = self._importObj:GetPendingGroupName()
		-- Make sure the parent of any selected groups are also selected
		for relativeGroupPath in self._importObj:PendingGroupIterator() do
			local groupPath = relativeGroupPath == Group.GetRootPath() and groupName or Group.JoinPath(groupName, relativeGroupPath)
			local isSelected = state.groupTree:IsGroupSelected(groupPath)
			self._importObj:SetGroupFiltered(relativeGroupPath, not isSelected)
			if isSelected then
				local tempGroupPath = Group.SplitPath(groupPath)
				while tempGroupPath do
					state.groupTree:SetGroupSelected(tempGroupPath, true)
					tempGroupPath = Group.SplitPath(tempGroupPath)
				end
			end
		end
		for relativeGroupPath in self._importObj:PendingGroupIterator() do
			local groupPath = relativeGroupPath == Group.GetRootPath() and groupName or Group.JoinPath(groupName, relativeGroupPath)
			local isSelected = state.groupTree:IsGroupSelected(groupPath)
			self._importObj:SetGroupFiltered(relativeGroupPath, not isSelected)
		end
		self:_UpdateTotals()
	elseif action == "ACTION_COMMIT" then
		local groupName, numItems, numOperations, numCustomSources = self._importObj:Commit(state.moveItems, state.includeOperations, state.replaceOperations)
		ChatMessage.PrintfUser(L["Imported group (%s) with %d items, %d operations, and %d custom sources."], groupName, numItems, numOperations, numCustomSources)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end

function GroupImportDialog.__private:_GetViewContentFrame(_, path)
	if path == "input" then
		self:SetSize(658, 250)
		self:SetPadding(12)
		local frame = nil
		for _ in self._state:WithAutoStorePaused() do
			frame = UIElements.New("BaseFrame", "selection")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, -4, 12)
					:AddChild(UIElements.New("Spacer", "spacer")
						:SetWidth(20)
					)
					:AddChild(UIElements.New("Text", "title")
						:SetFont("BODY_BODY1_EXTRABOLD")
						:SetJustifyH("CENTER")
						:SetText(L["Import Groups & Operations"])
					)
					:AddChild(UIElements.New("BaseButton", "closeBtn")
						:SetMargin(0, -4, 0, 0)
						:SetBackgroundAndSize("iconPack.24x24/Close/Default")
						:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
					)
				)
				:AddChild(UIElements.New("Text", "desc")
					:SetHeight(40)
					:SetMargin(0, 0, 0, 12)
					:SetFont("BODY_XSMALL")
					:SetText(format(L["You can import groups by pasting an import string into the box below. Group import strings can be found at: %s"], GROUPS_URL))
				)
				:AddChild(UIElements.New("Text", "text")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 8)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Import String"])
				)
				:AddChild(UIElements.New("MultiLineInput", "input")
					:SetMargin(0, 0, 0, 12)
					:SetFocused(true)
					:SetPasteMode()
					:BindElement(self._state, "input")
					:SetAction("OnValueChanged", "ACTION_HANDLE_VALUE_CHANGED")
				)
		end
		return frame
	elseif path == "summary" then
		self:SetSize(612, 437)
		self:SetPadding(8)
		local frame = nil
		for _ in self._state:WithAutoStorePaused() do
			frame = UIElements.New("BaseFrame", "selection")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, -4, 16)
					:AddChild(UIElements.New("Spacer", "spacer")
						:SetWidth(20)
					)
					:AddChild(UIElements.New("Text", "title")
						:SetFont("BODY_BODY1_EXTRABOLD")
						:SetJustifyH("CENTER")
						:SetText(L["Import Summary"])
					)
					:AddChild(UIElements.New("BaseButton", "closeBtn")
						:SetMargin(0, -4, 0, 0)
						:SetBackgroundAndSize("iconPack.24x24/Close/Default")
						:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "nav")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "groups")
						:SetWidth("AUTO")
						:SetMargin(8, 8, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetJustifyH("CENTER")
						:SetText(self._state:Publisher("numGroups"):ToStringFormat(L["%d Groups"]))
					)
					:AddChild(UIElements.New("Text", "operations")
						:SetWidth("AUTO")
						:SetMargin(8, 8, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetJustifyH("CENTER")
						:SetText(self._state:Publisher("numOperations"):ToStringFormat(L["%d Operations"]))
					)
					:AddChild(UIElements.New("BaseButton", "items")
						:SetWidth("AUTO")
						:SetMargin(8, 8, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetJustifyH("CENTER")
						:SetText(self._state:Publisher("numItems"):ToStringFormat(L["%d Items"]))
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
				:AddChild(UIElements.New("BaseFrame", "container")
					:SetLayout("VERTICAL")
					:SetPadding(2)
					:SetMargin(0, 0, 0, 12)
					:SetBackgroundColor("container/lowest")
					:SetBorderColor("outline/variant")
					:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
						:KeepTopLevelGroupSelected()
						:SetContextTable(self._groupTreeContext, DEFAULT_IMPORT_GROUP_TREE_CONTEXT)
						:SetQuery(self._db:NewOwnedQuery()
							:OrderBy("orderStr", true)
						)
						:BindElement(self._state, "groupTree")
						:SetAction("OnGroupSelectionChanged", "ACTION_HANDLE_GROUPS_UPDATED")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "items")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 12)
					:SetShown(self._state:Publisher("numExistingItems"):ToBooleanGreaterThanOrEquals(1))
					:AddChild(UIElements.New("Checkbox", "moveCheckbox")
						:SetWidth("AUTO")
						:SetMargin(0, 8, 0, 0)
						:MirrorIsCheckedState(self._state, "moveItems")
						:SetText(self._state:Publisher("numExistingItems"):ToStringFormat(L["Move %d already grouped items?"]))
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
				:AddChild(UIElements.New("BaseFrame", "operations")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 12)
					:SetShown(self._state:Publisher("numOperations"):ToBooleanGreaterThanOrEquals(1))
					:AddChild(UIElements.New("Checkbox", "includeCheckbox")
						:SetWidth("AUTO")
						:SetMargin(0, 8, 0, 0)
						:MirrorIsCheckedState(self._state, "includeOperations")
						:SetText(L["Include operations?"])
					)
					:AddChild(UIElements.New("Checkbox", "replaceCheckbox")
						:SetWidth("AUTO")
						:SetMargin(0, 8, 0, 0)
						:MirrorIsCheckedState(self._state, "replaceOperations")
						:SetText(self._state:PublisherForFunctionWithKeys(private.StateToReplaceOperationsCheckboxLabel, "numExistingOperations", "numExistingCustomSources"))
						:SetShown(self._state:Publisher([[includeOperations and numOperations > 0 and numExistingOperations > 0]]))
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
				:AddChild(UIElements.New("MediumPrimaryActionButton", "btn")
					:SetText(L["Import"])
					:SetAction("OnClick", "ACTION_COMMIT")
				)
		end
		return frame
	else
		error("Invalid path: "..tostring(path))
	end
end

function GroupImportDialog.__private:_UpdateTotals()
	self._state.numItems, self._state.numGroups, self._state.numExistingItems, self._state.numOperations, self._state.numExistingOperations, self._state.numExistingCustomSources = self._importObj:GetTotals()
	self:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToReplaceOperationsCheckboxLabel(numExistingOperations, numExistingCustomSources)
	if numExistingCustomSources > 0 then
		return format(L["Replace %d existing operations and %d existing custom sources?"], numExistingOperations, numExistingCustomSources)
	else
		return format(L["Replace %d existing operations?"], numExistingOperations)
	end
end

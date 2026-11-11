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
local TimeFormat = LibTSMUI:From("LibTSMWoW"):Include("UI.TimeFormat")
local AppHelper = LibTSMUI:From("LibTSMService"):Include("AppHelper")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local DEFAULT_IMPORT_GROUP_TREE_CONTEXT = { unselected = {}, collapsed = {} }
local IMPORT_EXPORT_IGNORED_OPERATION_TYPES = { "Mailing" }
local APP_GROUP_IMPORT_ROW_HEIGHT = 24
local APP_GROUP_IMPORT_ROW_SPACING = 8
local MAX_VISIBLE_APP_GROUP_IMPORTS = 3
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
	:AddOptionalStringField("appGroupImportId")
	:Commit()
GroupImportDialog:_AddActionScripts("OnGroupImported")



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

---Shows the summary for a group import sent from the website (must be called after the dialog is shown).
---@param id string The id of the group import
function GroupImportDialog:ReviewAppGroupImport(id)
	self._childManager:ProcessAction("ACTION_REVIEW_APP_GROUP_IMPORT", id)
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
		return manager:ProcessAction("ACTION_PROCESS_IMPORT_STRING", state.input:GetValue())
	elseif action == "ACTION_REVIEW_APP_GROUP_IMPORT" then
		local id = ...
		local appGroupImport = AppHelper.GetGroupImport(id)
		assert(appGroupImport)
		state.appGroupImportId = id
		return manager:ProcessAction("ACTION_PROCESS_IMPORT_STRING", appGroupImport.importString)
	elseif action == "ACTION_PROCESS_IMPORT_STRING" then
		local importString = ...
		local success, numInvalidItems, numChangedOperations = self._importObj:Process(importString)
		if not success then
			if state.appGroupImportId then
				AppHelper.SetGroupImportResult(state.appGroupImportId, "DISCARDED")
				ChatMessage.PrintUser(L["The group sent from tradeskillmaster.com could not be read and was discarded."])
			else
				ChatMessage.PrintUser(L["The pasted value was not valid. Ensure you are pasting the entire import string."])
			end
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
		if state.appGroupImportId then
			AppHelper.SetGroupImportResult(state.appGroupImportId, "IMPORTED")
		end
		self:_SendActionScript("OnGroupImported", groupName)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	elseif action == "ACTION_DISCARD" then
		assert(state.appGroupImportId)
		AppHelper.SetGroupImportResult(state.appGroupImportId, "DISCARDED")
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end

function GroupImportDialog.__private:_GetViewContentFrame(_, path)
	if path == "input" then
		local appGroupImports = AppHelper.GetPendingGroupImports()
		local numVisibleAppGroupImports = min(#appGroupImports, MAX_VISIBLE_APP_GROUP_IMPORTS)
		local appGroupImportsHeight = numVisibleAppGroupImports * (APP_GROUP_IMPORT_ROW_HEIGHT + APP_GROUP_IMPORT_ROW_SPACING) - APP_GROUP_IMPORT_ROW_SPACING
		self:SetSize(658, 250 + (#appGroupImports > 0 and (40 + appGroupImportsHeight) or 0))
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
				:AddChildrenWithFunction(private.AddAppGroupImports, appGroupImports, appGroupImportsHeight)
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
		local appGroupImport = self._state.appGroupImportId and AppHelper.GetGroupImport(self._state.appGroupImportId)
		self:SetSize(612, appGroupImport and 457 or 437)
		self:SetPadding(8)
		local frame = nil
		for _ in self._state:WithAutoStorePaused() do
			frame = UIElements.New("BaseFrame", "selection")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, -4, appGroupImport and 4 or 16)
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
				:AddChildIf(appGroupImport ~= nil, UIElements.New("Text", "source")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 12)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("CENTER")
					:SetText(appGroupImport and private.GetAppGroupImportSourceText(appGroupImport) or "")
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
				:AddChild(UIElements.New("BaseFrame", "buttons")
					:SetLayout("HORIZONTAL")
					:SetHeight(28)
					:AddChild(UIElements.New("MediumPrimaryActionButton", "btn")
						:SetText(L["Import"])
						:SetAction("OnClick", "ACTION_COMMIT")
					)
					:AddChildIf(appGroupImport ~= nil, UIElements.New("MediumSecondaryActionButton", "discardBtn")
						:SetMargin(8, 0, 0, 0)
						:SetText(L["Discard"])
						:SetAction("OnClick", "ACTION_DISCARD")
					)
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

function private.AddAppGroupImports(frame, appGroupImports, height)
	if #appGroupImports == 0 then
		return
	end
	frame:AddChild(UIElements.New("Text", "appGroupImportsText")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 8)
		:SetFont("BODY_SMALL_SEMIBOLD")
		:SetText(L["Sent from tradeskillmaster.com"])
	)
	local list = UIElements.New("BaseScrollFrame", "appGroupImports")
		:SetHeight(height)
		:SetMargin(0, 0, 0, 12)
		:SetPadding(0, #appGroupImports > MAX_VISIBLE_APP_GROUP_IMPORTS and (Theme.GetScrollbarWidth() + Theme.GetScrollbarMargin() * 2) or 0, 0, 0)
	for i, appGroupImport in ipairs(appGroupImports) do
		local groupText = Theme.GetGroupColor(1):ColorText(appGroupImport.name)
		list:AddChild(UIElements.New("AppGroupImportRow", "row"..i)
			:SetHeight(APP_GROUP_IMPORT_ROW_HEIGHT)
			:SetMargin(0, 0, i > 1 and APP_GROUP_IMPORT_ROW_SPACING or 0, 0)
			:Configure(appGroupImport.id, format(L["%s by %s, sent %s ago"], groupText, appGroupImport.author, private.GetSentDuration(appGroupImport)))
			:SetAction("OnReview", "ACTION_REVIEW_APP_GROUP_IMPORT")
		)
	end
	frame:AddChild(list)
end

function private.GetAppGroupImportSourceText(appGroupImport)
	local siteText = Theme.GetColor("accent/main"):ColorText("tradeskillmaster.com")
	return format(L["From %s, sent %s ago - %s by %s"], siteText, private.GetSentDuration(appGroupImport), appGroupImport.name, appGroupImport.author)
end

function private.GetSentDuration(appGroupImport)
	return TimeFormat.Duration(max(LibTSMUI.GetTime() - appGroupImport.sentAt, 1))
end

function private.StateToReplaceOperationsCheckboxLabel(numExistingOperations, numExistingCustomSources)
	if numExistingCustomSources > 0 then
		return format(L["Replace %d existing operations and %d existing custom sources?"], numExistingOperations, numExistingCustomSources)
	else
		return format(L["Replace %d existing operations?"], numExistingOperations)
	end
end

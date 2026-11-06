-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Groups = App:Init("MainUI.Groups")
local BaseGroup = App:Include("MainUI.Groups.BaseGroup")
local Items = App:Include("MainUI.Groups.Items")
local Operations = App:Include("MainUI.Groups.Operations")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Database = App:From("LibTSMDatabase"):Include("Database")
local Group = App:From("LibTSMTypes"):Include("Group")
local GroupOperation = App:From("LibTSMTypes"):Include("GroupOperation")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Analytics = App:From("LibTSMService"):Include("Util.Analytics")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
	importExportGroupDB = nil,
	itemsTemp = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("GroupsUIState")
	:AddDeferredUIElementField("frame", "DividedContainer")
	:AddDeferredUIElementField("view", "ViewContainer")
	:AddDeferredUIElementField("groupTree", "ManagementGroupTree")
	:AddDeferredUIElementField("searchInput", "Input")
	:AddOptionalUIElementField("titleText", "EditableText")
	:AddOptionalUIElementField("tabGroup", "SegmentedTabGroup")
	:AddStringField("groupPath", Group.GetRootPath())
	:AddStringField("name", L["Base Group"])
	:AddStringField("groupSearch", "")
	:AddBooleanField("matchesSearch", true)
	:AddBooleanField("editingName", false)
	:Commit()

---@event GroupsUIAction
---| "ACTION_SET_SELECTED_GROUP" -> groupPath: GroupPathValue
---| "ACTION_HANDLE_GROUP_ADDED"
---| "ACTION_HANDLE_GROUP_TREE_DRAG_RECEIVED" -> context: string[], destGroupPath: GroupPathValue
---| "ACTION_HANDLE_GROUP_SEARCH_CHANGED"
---| "ACTION_HANDLE_NAME_CHANGED" -> newValue: string
---| "ACTION_SHOW_IMPORT_DIALOG"
---| "ACTION_TOGGLE_EXPAND_ALL"
---| "ACTION_START_EDITING_NAME"
---| "ACTION_EXPORT"



-- ============================================================================
-- Module Loading
-- ============================================================================

Groups:OnModuleLoad(function()
	private.importExportGroupDB = Database.NewSchema("IMPORT_EXPORT_GROUPS")
		:AddStringField("groupPath")
		:AddStringField("orderStr")
		:AddIndex("groupPath")
		:Commit()
end)

AddonSettings.RegisterOnLoad(Groups, function(db)
	private.settings = db:NewView("GroupsSettings")
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "mainUIContext", "groupsDividedContainer")
		:AddKey("global", "userData", "ungroupedItemMode")
		:AddKey("char", "mainUIContext", "groupsManagementGroupTree")
		:AddKey("global", "userData", "customPriceSources")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("GROUPS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_GROUP_SEARCH_CHANGED")
		:AddFrameBuilder(private.GetGroupsFrame)

	-- Set up some computed properties
	private.manager:SetStateFromPublisher("name", state:PublisherForFunctionWithKeys(private.GroupPathToName, "groupPath"))
	private.manager:SetStateFromPublisher("matchesSearch", state:PublisherForFunctionWithKeys(private.StateToMatchesSearch, "name", "groupSearch"))
	private.manager:AddCancellable(state:Publisher("matchesSearch")
		:CallFunction(BaseGroup.SetMatchesSearch)
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the groups code.
---@param showOperationSettingsCallback fun(typeName: string, operationName: string) The callback to show the settings of an operation
function Groups.Configure(showOperationSettingsCallback)
	Operations.Configure(showOperationSettingsCallback)
end

---Gets the groups frame.
---@return DividedContainer
function Groups.GetFrame()
	return private.manager:BuildFrame()
end

---Sets the selected group.
---@param groupPath GroupPathValue The group path
function Groups.SetSelectedGroup(groupPath)
	private.manager:ProcessAction("ACTION_SET_SELECTED_GROUP", groupPath)
end



-- ============================================================================
-- Groups UI
-- ============================================================================

---@param state GroupsUIState
function private.GetGroupsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "groups")
	return UIElements.New("DividedContainer", "groups")
		:SetSettingsContext(private.settings, "groupsDividedContainer")
		:SetMinWidth(250, 250)
		:HideDivider()
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:SetLeftChild(UIElements.New("BaseFrame", "groupSelection")
			:SetLayout("VERTICAL")
			:SetMargin(0, 3, 0, 0)
			:SetPadding(8)
			:SetRoundedBackgroundColor("container/low")
			:AddChild(UIElements.New("BaseFrame", "search")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Input", "input")
					:SetLeadIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:AllowItemInsert(true)
					:SetValue(state.groupSearch)
					:SetHintText(L["Search Groups"])
					:BindElement(state, "searchInput")
					:SetAction("OnValueChanged", "ACTION_HANDLE_GROUP_SEARCH_CHANGED")
				)
				:AddChild(UIElements.New("BaseButton", "expandAllBtn")
					:SetSize(24, 24)
					:SetMargin(8, 0, 0, 0)
					:SetBackground("iconPack.18x18/Expand All")
					:SetAction("OnClick", "ACTION_TOGGLE_EXPAND_ALL")
					:SetTooltip(L["Expand / Collapse All Groups"])
				)
				:AddChild(UIElements.New("BaseButton", "importBtn")
					:SetSize(24, 24)
					:SetMargin(8, 0, 0, 0)
					:SetBackground("iconPack.18x18/Import")
					:SetAction("OnClick", "ACTION_SHOW_IMPORT_DIALOG")
					:SetTooltip(L["Import group"])
				)
			)
			:AddChild(UIElements.New("ManagementGroupTree", "groupTree")
				:SetBackgroundColor("container/low")
				:SetSettingsContext(private.settings, "groupsManagementGroupTree")
				:SetQuery(GroupOperation.CreateQuery())
				:SetSelectedGroup(state.groupPath)
				:SetSearchString(state.groupSearch)
				:BindElement(state, "groupTree")
				:SetAction("OnGroupSelected", "ACTION_SET_SELECTED_GROUP")
				:SetAction("OnAddGroup", "ACTION_HANDLE_GROUP_ADDED")
				:SetAction("OnDragReceived", "ACTION_HANDLE_GROUP_TREE_DRAG_RECEIVED")
			)
		)
		:SetRightChild(UIElements.New("ViewContainer", "view")
			:SetMargin(3, 0, 0, 0)
			:SetContext(state)
			:BindElement(state, "view")
			:SetNavCallback(private.GetViewContainerContent)
			:AddPath("base")
			:AddPath("group")
			:SetPath(state.groupPath == Group.GetRootPath() and "base" or "group")
		)
end

---@param viewContainer ViewContainer
function private.GetViewContainerContent(viewContainer, path)
	local state = viewContainer:GetContext() ---@type GroupsUIState
	if path == "base" then
		return BaseGroup.GetFrame()
	elseif path == "group" then
		return private.GetGroupContentFrame(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state GroupsUIState
function private.GetGroupContentFrame(state)
	local groupColorKeyPublisher = state:PublisherForFunctionWithKeys(Group.GetLevel, "groupPath")
		:Map(Theme.GetGroupColorKey)
		:IgnoreDuplicates()
		:Share()
	local editExportShownPublisher = state:Publisher([[not editingName and matchesSearch]])
		:Share()
	return UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("VERTICAL")
			:SetSize("EXPAND", 40)
			:SetPadding(8)
			:AddChild(UIElements.New("BaseFrame", "title")
				:SetLayout("HORIZONTAL")
				:AddChild(UIElements.New("BaseTexture", "icon")
					:SetMargin(0, 8, 0, 0)
					:SetTextureAndSize(groupColorKeyPublisher:Map(private.GroupColorKeyToFolderTexture))
				)
				:AddChild(UIElements.New("EditableText", "text")
					:AllowItemInsert(true)
					:SetFont("BODY_BODY1_EXTRABOLD")
					:BindElement(state, "titleText")
					:SetText(state:Publisher([[matchesSearch and name or nil]]):CoalesceNil(L["No group selected"]))
					:SetTextColor(groupColorKeyPublisher)
					:BindEditing(state, "editingName")
					:SetAction("OnValueChanged", "ACTION_HANDLE_NAME_CHANGED")
				)
				:AddChild(UIElements.New("BaseButton", "renameBtn")
					:SetMargin(8, 0, 0, 0)
					:SetBackgroundAndSize("iconPack.18x18/Edit")
					:SetTooltip(L["Rename this group"])
					:SetShown(editExportShownPublisher)
					:SetAction("OnClick", "ACTION_START_EDITING_NAME")
				)
				:AddChild(UIElements.New("BaseButton", "exportBtn")
					:SetMargin(8, 4, 0, 0)
					:SetBackgroundAndSize("iconPack.18x18/Export")
					:SetTooltip(L["Export this group"])
					:SetShown(editExportShownPublisher)
					:SetAction("OnClick", "ACTION_EXPORT")
				)
			)
		)
		:AddChild(UIElements.New("SegmentedTabGroup", "buttons")
			:SetBarMargin(8)
			:SetContext(state)
			:BindElement(state, "tabGroup")
			:SetNavCallback(private.GetGroupTabContent)
			:AddPath(L["Items"], true)
			:AddPath(L["Operations"])
			:SetShown(state:Publisher("matchesSearch"))
		)
		:AddCancellable(groupColorKeyPublisher:EndShare())
		:AddCancellable(editExportShownPublisher:EndShare())
end

---@param tabGroup SegmentedTabGroup
function private.GetGroupTabContent(tabGroup, path)
	local state = tabGroup:GetContext() ---@type GroupsUIState
	if path == L["Items"] then
		return Items.GetFrame(state.groupPath)
	elseif path == L["Operations"] then
		return Operations.GetFrame(state.groupPath)
	else
		error("Unexpected path: "..tostring(path))
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<GroupsUIState>
---@param state GroupsUIState
---@param action GroupsUIAction
---@param ... params<GroupsUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_SELECTED_GROUP" then
		local groupPath = ...
		state.groupPath = groupPath
		local isBaseGroup = groupPath == Group.GetRootPath()
		state.view:SetPath(isBaseGroup and "base" or "group", true)
		if state.titleText then
			state.titleText:SetEditing(false)
		end
		state.view:Draw()
		if state.tabGroup then
			state.tabGroup:ReloadContent()
		end
	elseif action == "ACTION_HANDLE_GROUP_ADDED" then
		if state.titleText then
			state.titleText:SetEditing(true)
		end
	elseif action == "ACTION_HANDLE_GROUP_TREE_DRAG_RECEIVED" then
		local context, destGroupPath = ...
		assert(not next(private.itemsTemp))
		for _, itemString in ipairs(context) do
			if Group.GetPathByItem(itemString) ~= destGroupPath then
				tinsert(private.itemsTemp, itemString)
			end
		end
		Group.SetItemsGroup(private.itemsTemp, destGroupPath ~= Group.GetRootPath() and destGroupPath or nil)
		Table.WipeAndDeallocate(private.itemsTemp)
	elseif action == "ACTION_HANDLE_GROUP_SEARCH_CHANGED" then
		local text = strlower(state.searchInput:GetValue())
		if state.groupSearch == text then
			return
		end
		state.groupSearch = text
		state.groupTree:SetSelectedGroup(state.matchesSearch and state.groupPath or Group.GetRootPath())
		if not state.matchesSearch and state.titleText then
			state.titleText:SetEditing(false)
		end
		if state.tabGroup then
			state.tabGroup:Draw()
		end
		state.groupTree:SetSearchString(state.groupSearch)
		state.view:Draw()
	elseif action == "ACTION_HANDLE_NAME_CHANGED" then
		local newValue = ...
		newValue = strtrim(newValue)
		local parent = Group.GetParent(state.groupPath)
		local newPath = parent and parent ~= Group.GetRootPath() and Group.JoinPath(parent, newValue) or newValue
		assert(state.titleText)
		if newPath == state.groupPath then
			-- Didn't change
			state.titleText:Draw()
		elseif not Group.IsValidName(newValue) then
			ChatMessage.PrintUser(L["Invalid group name."])
			state.titleText:Draw()
		elseif Group.Exists(newPath) then
			ChatMessage.PrintUser(L["Group already exists."])
			state.titleText:Draw()
		else
			GroupOperation.MoveGroup(state.groupPath, newPath)
			Analytics.Action("MOVED_GROUP", state.groupPath, newPath)
			state.groupTree:SetSelectedGroup(newPath, true)
		end
	elseif action == "ACTION_SHOW_IMPORT_DIALOG" then
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("GroupImportDialog", "frame")
			:AddAnchor("CENTER")
			:SetManager(private.manager)
			:Configure(private.importExportGroupDB)
	)
	elseif action == "ACTION_TOGGLE_EXPAND_ALL" then
		state.groupTree:ToggleExpandAll()
	elseif action == "ACTION_START_EDITING_NAME" then
		assert(state.titleText)
		state.titleText:SetEditing(true)
	elseif action == "ACTION_EXPORT" then
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("GroupExportDialog", "frame")
			:AddAnchor("CENTER")
			:Configure(state.groupPath, private.importExportGroupDB)
		)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GroupColorKeyToFolderTexture(groupColorKey)
	return TextureAtlas.GetColoredKey("iconPack.18x18/Folder", groupColorKey)
end

function private.GroupPathToName(groupPath)
	if groupPath == Group.GetRootPath() then
		return L["Base Group"]
	else
		return Group.GetName(groupPath)
	end
end

function private.StateToMatchesSearch(name, groupSearch)
	return strmatch(strlower(name), String.Escape(groupSearch)) and true or false
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local BaseGroup = App:Init("MainUI.Groups.BaseGroup")
local Operations = App:Include("MainUI.Groups.Operations")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local SmartMap = App:From("LibTSMUtil"):IncludeClassType("SmartMap")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local Group = App:From("LibTSMTypes"):Include("Group")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local ItemFilter = App:From("LibTSMService"):IncludeClassType("ItemFilter")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Analytics = App:From("LibTSMService"):Include("Util.Analytics")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	itemFilter = ItemFilter.New(),
	itemFilterSmartMap = nil,
	ungroupedItemStringSmartMap = nil,
	manager = nil,
	settings = nil,
	itemsTemp = {},
	numResultsCancellable = nil,
	baseItemInfoQuery = nil,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("GroupsBaseGroupUIState")
	:AddDeferredUIElementField("view", "ViewContainer")
	:AddDeferredUIElementField("itemList", "ItemList")
	:AddDeferredUIElementField("input", "Input")
	:AddStringField("moveGroupPath", Group.GetRootPath())
	:AddStringField("itemSearch", "")
	:AddNumberField("numSelected", 0)
	:AddNumberField("numResults", 0)
	:AddBooleanField("matchesSearch", true)
	:Commit()

---@event GroupsBaseGroupAction
---| "ACTION_HANDLE_SEARCH"
---| "ACTION_TOGGLE_SELECT_ALL"
---| "ACTION_MOVE"
---| "ACTION_BACK"
---| "ACTION_HANDLE_SEARCH_CHANGED"
---| "ACTION_CANCEL_NUM_RESULTS_PUBLISHER"
---| "ACTION_SET_MATCHES_SEARCH" -> matchesSearch: boolean



-- ============================================================================
-- Module Loading
-- ============================================================================

BaseGroup:OnModuleLoad(function()
	private.itemFilter:ParseStr("")
	private.itemFilterSmartMap = SmartMap.New("string", "boolean", private.ItemFilterLookup)
	private.ungroupedItemStringSmartMap = SmartMap.New("string", "string", private.UngroupedItemStringLookup)
end)

AddonSettings.RegisterOnLoad(BaseGroup, function(db)
	private.settings = db:NewView("BaseGroupSettings")
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "userData", "ungroupedItemMode")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("GROUPS_BASE_GROUP", state, private.ActionHandler)
		:SuppressActionLog("ACTION_SET_MATCHES_SEARCH")
		:SuppressActionLog("ACTION_HANDLE_SEARCH_CHANGED")
		:AddFrameBuilder(private.GetViewContainer)

	private.manager:AddCancellable(state:Publisher("itemSearch")
		:IgnoreIfEquals("")
		:CallFunction(private.UpdateItemFilter)
	)
	private.manager:AddCancellable(private.settings:PublisherForKey("ungroupedItemMode")
		:CallFunction(function()
			private.ungroupedItemStringSmartMap:Invalidate()
		end)
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the base group frame.
---@return ViewContainer
function BaseGroup.GetFrame()
	return private.manager:BuildFrame()
end

---Sets whether or not the current group search matches the selected (base) group.
---@param matchesSearch boolean Whether or not the search matches
function BaseGroup.SetMatchesSearch(matchesSearch)
	private.manager:ProcessAction("ACTION_SET_MATCHES_SEARCH", matchesSearch)
end



-- ============================================================================
-- Base Group UI
-- ============================================================================

---@param state GroupsBaseGroupUIState
function private.GetViewContainer(state)
	return UIElements.New("ViewContainer", "view")
		:SetContext(state)
		:BindElement(state, "view")
		:SetNavCallback(private.GetBaseViewContainerContent)
		:AddPath("content", true)
		:AddPath("search")
end

---@param viewContainer ViewContainer
function private.GetBaseViewContainerContent(viewContainer, path)
	local state = viewContainer:GetContext() ---@type GroupsBaseGroupUIState
	if path == "content" then
		return private.GetBaseContentFrame(state)
	elseif path == "search" then
		return private.GetSearchFrame(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state GroupsBaseGroupUIState
function private.GetBaseContentFrame(state)
	local matchesSearchPublisher = state:Publisher("matchesSearch")
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
					:SetTextureAndSize("iconPack.18x18/Folder")
				)
				:AddChild(UIElements.New("Text", "text")
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(matchesSearchPublisher:ReplaceBooleanWith(L["Base Group"], L["No group selected"]))
				)
			)
		)
		:AddChild(UIElements.New("SegmentedTabGroup", "buttons")
			:SetBarMargin(8)
			:SetContext(state)
			:SetNavCallback(private.GetBaseTabContent)
			:AddPath(L["Information"], true)
			:AddPath(L["Operations"])
			:SetShown(matchesSearchPublisher)
		)
		:AddCancellable(matchesSearchPublisher:EndShare())
end

---@param tabGroup SegmentedTabGroup
function private.GetBaseTabContent(tabGroup, path)
	local state = tabGroup:GetContext() ---@type GroupsBaseGroupUIState
	if path == L["Information"] then
		return private.GetBaseGroupFrame(state)
	elseif path == L["Operations"] then
		return Operations.GetFrame(Group.GetRootPath())
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state GroupsBaseGroupUIState
function private.GetBaseGroupFrame(state)
	private.itemFilter:ParseStr("")
	private.itemFilterSmartMap:Invalidate()
	private.ungroupedItemStringSmartMap:Invalidate()
	state.itemSearch = ""
	state.numSelected = 0
	if state.moveGroupPath ~= "" and not Group.Exists(state.moveGroupPath) then
		state.moveGroupPath = ""
	end
	UIUtils.AnalyticsRecordPathChange("main", "groups", "information")
	return UIElements.New("BaseFrame", "items")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:AddChild(UIElements.New("Text", "text")
			:SetHeight(42)
			:SetMargin(8, 8, 0, 8)
			:SetFont("BODY_XSMALL")
			:SetText(L["The Base Group contains all ungrouped items in the game. Use the search and filter controls to find items to add to other groups."])
		)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:AddChild(UIElements.New("Input", "filter")
				:SetHeight(24)
				:SetMargin(0, 8, 0, 0)
				:SetLeadIconTexture("iconPack.18x18/Search")
				:AllowItemInsert()
				:SetClearButtonEnabled(true)
				:SetValidateFunc(private.ValidateBaseSearchValue)
				:MirrorValueState(state, "itemSearch")
				:SetHintText(L["Search items"])
				:SetAction("OnValueChanged", "ACTION_HANDLE_SEARCH")
			)
			:AddChild(UIElements.New("BaseButton", "selectAllBtn")
				:SetSize(24, 24)
				:SetBackground("iconPack.18x18/Select All")
				:SetAction("OnClick", "ACTION_TOGGLE_SELECT_ALL")
				:SetTooltip(L["Select / Deselect All Results"])
			)
		)
		:AddChild(UIElements.New("BaseFrame", "header2")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8, 8, 0, 8)
			:AddChild(UIElements.New("Text", "text")
				:SetSize("AUTO", 24)
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(L["Show ungrouped items as:"])
			)
			:AddChild(UIElements.New("SelectionDropdown", "itemMode")
				:SetHeight(24)
				:AddItem(L["Specific Item"], "specific")
				:AddItem(L["Item Level"], "level")
				:AddItem(L["Base Item"], "base")
				:SetHintText(L["Select item type"])
				:SetSettingInfo(private.settings, "ungroupedItemMode")
			)
		)
		:AddChild(UIElements.New("ListContainer", "list")
			:SetMargin(8, 8, 0, 0)
			:AddChild(UIElements.New("ItemList", "itemList")
				:AddSectionQuery(Theme.GetColor("accent/main"):ColorText(L["Ungrouped Items in Bags"]), private.CreateUngroupedBagItemQueryAndGetFields())
				:BindElement(state, "itemList")
				:BindNumSelected(state, "numSelected")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "bottom")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:AddChild(UIElements.New("GroupSelector", "group")
				:SetMargin(0, 8, 0, 0)
				:SetHintText(L["Select Group"])
				:SetSingleSelection(true)
				:AddCreateNew()
				:MirrorSelectionString(state, "moveGroupPath")
			)
			:AddChild(UIElements.New("SmallPrimaryActionButton", "move")
				:SetWidth(124)
				:SetDisabled(state:Publisher([[moveGroupPath == "" or numSelected == 0]]))
				:SetText(state:Publisher("numSelected"):ToStringFormat(L["Move %d |4Item:Items"]))
				:SetAction("OnClick", "ACTION_MOVE")
			)
		)
end

---@param state GroupsBaseGroupUIState
function private.GetSearchFrame(state)
	private.UpdateBaseItemInfoQuery()
	if state.moveGroupPath ~= "" and not Group.Exists(state.moveGroupPath) then
		state.moveGroupPath = ""
	end
	private.numResultsCancellable = private.baseItemInfoQuery:Publisher()
		:Map("Count()")
		:AssignToTableKey(state, "numResults")
		:Stored()
	return UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:AddChild(UIElements.New("BackButton", "button")
				:SetMargin(0, 8, 0, 0)
				:SetAction("OnClick", "ACTION_BACK")
			)
			:AddChild(UIElements.New("Input", "input")
				:SetMargin(0, 8, 0, 0)
				:SetLeadIconTexture("iconPack.18x18/Search")
				:AllowItemInsert()
				:SetClearButtonEnabled(true)
				:SetValidateFunc(private.ValidateBaseSearchValue)
				:SetHintText(L["Search items"])
				:MirrorValueState(state, "itemSearch")
				:BindElement(state, "input")
				:SetAction("OnValueChanged", "ACTION_HANDLE_SEARCH_CHANGED")
			)
			:AddChild(UIElements.New("BaseButton", "selectAllBtn")
				:SetSize(24, 24)
				:SetBackground("iconPack.18x18/Select All")
				:SetAction("OnClick", "ACTION_TOGGLE_SELECT_ALL")
				:SetTooltip(L["Select / Deselect All Results"])
			)
		)
		:AddChild(UIElements.New("BaseFrame", "header2")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetPadding(8, 8, 0, 8)
			:AddChild(UIElements.New("Text", "label")
				:SetFont("BODY_SMALL")
				:SetText(state:Publisher("numResults"):ToStringFormat(L["%d Results"]))
			)
			:AddChild(UIElements.New("Text", "text")
				:SetWidth("AUTO")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(L["Show results as:"])
			)
			:AddChild(UIElements.New("SelectionDropdown", "itemMode")
				:SetSize(150, 24)
				:AddItem(L["Specific Item"], "specific")
				:AddItem(L["Item Level"], "level")
				:AddItem(L["Base Item"], "base")
				:SetHintText(L["Select item type"])
				:SetSettingInfo(private.settings, "ungroupedItemMode")
			)
		)
		:AddChild(UIElements.New("ListContainer", "list")
			:SetMargin(8, 8, 0, 0)
			:AddChild(UIElements.New("ItemList", "itemList")
				:AddSectionQuery(Theme.GetColor("accent/main"):ColorText(L["Search Results"]), private.baseItemInfoQuery, "ungroupedItemString", "texture", "coloredItemName", true)
				:BindElement(state, "itemList")
				:BindNumSelected(state, "numSelected")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "bottom")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:AddChild(UIElements.New("GroupSelector", "group")
				:SetMargin(0, 8, 0, 0)
				:SetHintText(L["Select Group"])
				:SetSingleSelection(true)
				:AddCreateNew()
				:MirrorSelectionString(state, "moveGroupPath")
			)
			:AddChild(UIElements.New("SmallPrimaryActionButton", "move")
				:SetWidth(124)
				:SetDisabled(state:Publisher([[moveGroupPath == "" or numSelected == 0]]))
				:SetText(state:Publisher("numSelected"):ToStringFormat(L["Move %d |4Item:Items"]))
				:SetAction("OnClick", "ACTION_MOVE")
			)
		)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_CANCEL_NUM_RESULTS_PUBLISHER"))
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<GroupsBaseGroupUIState>
---@param state GroupsBaseGroupUIState
---@param action GroupsBaseGroupAction
---@param ... params<GroupsBaseGroupAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_SEARCH" then
		if state.itemSearch == "" then
			return
		end
		private.UpdateBaseItemInfoQuery()
		state.view:SetPath("search", true)
		state.input
			:SetFocused(true)
			:ClearHighlight()
	elseif action == "ACTION_TOGGLE_SELECT_ALL" then
		state.itemList:ToggleSelectAll()
	elseif action == "ACTION_MOVE" then
		assert(state.moveGroupPath ~= "")
		assert(not next(private.itemsTemp))
		state.itemList:GetSelectedItems(private.itemsTemp)
		Group.SetItemsGroup(private.itemsTemp, state.moveGroupPath)
		Analytics.Action("ADDED_GROUP_ITEMS", state.moveGroupPath, #private.itemsTemp)
		Table.WipeAndDeallocate(private.itemsTemp)
	elseif action == "ACTION_BACK" then
		state.view:SetPath("content", true)
	elseif action == "ACTION_HANDLE_SEARCH_CHANGED" then
		if state.itemSearch == "" then
			return
		end
		private.UpdateBaseItemInfoQuery()
	elseif action == "ACTION_CANCEL_NUM_RESULTS_PUBLISHER" then
		assert(private.numResultsCancellable)
		private.numResultsCancellable:Cancel()
		private.numResultsCancellable = nil
	elseif action == "ACTION_SET_MATCHES_SEARCH" then
		state.matchesSearch = ...
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateBaseSearchValue(value)
	if value == "" then
		return true
	elseif #value < 3 then
		return false, L["The search term must be at least 3 characters."]
	elseif not private.itemFilter:ParseStr(value) then
		return false, L["Invalid search term."]
	end
	local str = private.itemFilter:GetStr()
	if str and #str < 3 then
		return false, L["The name portion of the search term must be at least 3 characters if present."]
	elseif private.itemFilter:GetMinPrice() or private.itemFilter:GetMaxPrice() then
		return false, L["Invalid search term. Cannot filter by price here."]
	end
	return true
end

function private.CreateUngroupedBagItemQueryAndGetFields()
	local query = BagTracking.CreateQueryBags()
		:Equal("isBound", false)
		:VirtualSmartMapField("ungroupedItemString", private.ungroupedItemStringSmartMap, "itemString")
		:Distinct("ungroupedItemString")
		:LeftJoin(Group.GetItemDBForJoin(), "ungroupedItemString", "itemString")
		:IsNil("groupPath")
		:VirtualField("name", "string", ItemInfo.GetName, "ungroupedItemString", "?")
		:VirtualField("texture", "number", ItemInfo.GetTexture, "ungroupedItemString", ItemInfo.GetTexture(ItemString.GetUnknown()))
		:VirtualField("coloredItemName", "string", UIUtils.GetDisplayItemName, "ungroupedItemString", Theme.GetColor("error/main"):ColorText("?"))
		:VirtualSmartMapField("matchesFilter", private.itemFilterSmartMap, "ungroupedItemString")
		:Equal("matchesFilter", true)
		:OrderBy("name", true)
	return query, "ungroupedItemString", "texture", "coloredItemName"
end

function private.UpdateBaseItemInfoQuery()
	local shouldPause = private.baseItemInfoQuery ~= nil
	if shouldPause then
		private.baseItemInfoQuery:SetUpdatesPaused(true)
	end
	private.baseItemInfoQuery = ItemInfo.MatchItemFilterQuery(private.itemFilter, private.baseItemInfoQuery)
		:VirtualSmartMapField("ungroupedItemString", private.ungroupedItemStringSmartMap, "itemString")
		:Distinct("ungroupedItemString")
		:LeftJoin(Group.GetItemDBForJoin(), "ungroupedItemString", "itemString")
		:IsNil("groupPath")
		:Equal("isBOP", 0)
		:OrderBy("name", true)
		:VirtualField("coloredItemName", "string", UIUtils.GetDisplayItemName, "itemString", Theme.GetColor("error/main"):ColorText("?"))
	if shouldPause then
		private.baseItemInfoQuery:SetUpdatesPaused(false)
	end
end

function private.ItemFilterLookup(itemString)
	local basePrice = CustomString.GetValue(private.settings.groupPriceSource, itemString)
	return private.itemFilter:Matches(itemString, basePrice)
end

function private.UngroupedItemStringLookup(itemString)
	if private.settings.ungroupedItemMode == "level" then
		return ItemString.ToLevel(itemString)
	elseif private.settings.ungroupedItemMode == "base" then
		return ItemString.GetBaseFast(itemString)
	elseif private.settings.ungroupedItemMode == "specific" then
		return itemString
	else
		error("Invalid ungrouped item mode: "..tostring(private.settings.ungroupedItemMode))
	end
end

function private.UpdateItemFilter(str)
	local isValid = private.itemFilter:ParseStr(str)
	assert(isValid)
	private.itemFilterSmartMap:Invalidate()
end

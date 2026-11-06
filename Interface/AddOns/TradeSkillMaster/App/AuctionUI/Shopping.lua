-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Shopping = App:Init("AuctionUI.Shopping")
local AuctionBuyScan = App:IncludeClassType("AuctionBuyScan")
local Iterator = App:From("LibTSMUtil"):Include("BaseType.Iterator")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local ShoppingSavedSearches = App:From("LibTSMTypes"):Include("SavedSearches.ShoppingSavedSearches")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local AuctionPostContext = App:From("LibTSMService"):IncludeClassType("AuctionPostContext")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local ShoppingApp = App:From("LibTSMApp"):Include("Shopping")
local TaskList = App:From("LibTSMApp"):Include("TaskList")
local private = {
	manager = nil,
	settings = nil,
	selectedGroups = {},
	itemPostContext = AuctionPostContext.New(),
}
local STATE_SCHEMA = Reactive.CreateStateSchema("ShoppingUIState")
	:AddDeferredUIElementField("frame", "ViewContainer")
	:AddDeferredUIElementField("selectionView", "ViewContainer")
	:AddOptionalUIElementField("advancedSearchFrame", "ShoppingAdvancedSearch")
	:AddOptionalUIElementField("scrollTable", "AuctionScrollTable")
	:AddDeferredUIElementField("filterInput", "Input")
	:AddOptionalUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddDeferredClassField("auctionBuyScan", AuctionBuyScan)
	:AddStringField("contentPath", "selection")
	:AddStringField("searchName", "")
	:AddBooleanField("filterIsValid", (not App.IsVanillaClassic() and not App.IsBCClassic()))
	:AddBooleanField("groupSelectionCleared", true)
	:AddBooleanField("greatDealsAvailable", false)
	:Commit()

---@event ShoppingAction
---| "ACTION_FRAME_HIDDEN"
---| "ACTION_SHOW_ADVANCED_SEARCH"
---| "ACTION_ADVANCED_SEARCH_BACK"
---| "ACTION_START_GROUP_SEARCH"
---| "ACTION_START_ADVANCED_SEARCH" -> filter: string
---| "ACTION_SET_SEARCH_FAVORITE" -> index: number, isFavorite: boolean
---| "ACTION_RECENT_SEARCH_DELETE" -> index: number
---| "ACTION_FAVORITE_SEARCH_DELETE" -> index: number
---| "ACTION_FAVORITE_SEARCH_EDIT" -> index: number
---| "ACTION_RENAMED_SAVED_SEARCH" -> name: string, index: number
---| "ACTION_RECENT_SEARCH_LIST_ROW_CLICK" -> index: number
---| "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK" -> index: number
---| "ACTION_START_GATHERING_SEARCH" -> items: table<string,number>, stateCallback: fun(state: string), buyCallback: fun(itemString: string, quantity: number), mode: EnumValue
---| "ACTION_START_ITEM_SEARCH" -> itemLink: string
---| "ACTION_ITEM_LINKED" -> name: string, itemLink: string
---| "ACTION_START_VENDOR_SEARCH"
---| "ACTION_START_DISENCHANT_SEARCH"
---| "ACTION_START_DEALS_SEARCH"
---| "ACTION_FILTER_INPUT_CHANGED"
---| "ACTION_START_FILTER_INPUT_SEARCH"
---| "ACTION_START_FILTER_SEARCH" -> filter: string
---| "ACTION_START_SEARCH" -> searchContext: AuctionSearchContext?
---| "ACTION_SCAN_BACK_BUTTON_CLICKED"
---| "ACTION_RESCAN"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Shopping, function(db)
	private.settings = db:NewView("ShoppingSettings")
		:AddKey("global", "auctionUIContext", "shoppingSelectionDividedContainer")
		:AddKey("global", "auctionUIContext", "shoppingAuctionScrollingTable")
		:AddKey("global", "auctionUIContext", "shoppingSearchesTabGroup")
		:AddKey("global", "shoppingOptions", "searchAutoFocus")
		:AddKey("global", "shoppingOptions", "buyoutConfirm")
		:AddKey("global", "shoppingOptions", "buyoutAlertSource")
		:AddKey("char", "auctionUIContext", "shoppingGroupTree")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SHOPPING", state, private.ActionHandler)
		:SuppressActionLog("ACTION_FILTER_INPUT_CHANGED")
		:SuppressActionLog("ACTION_START_FILTER_SEARCH")
		:AddFrameBuilder(private.GetShoppingFrame)

	-- Create the auction buy scan
	state.auctionBuyScan = AuctionBuyScan.NewBrowse(L["Browse"], private.IsPlayer, private.GetAlertThreshold)
	private.manager:AddCancellable(state:Publisher("scrollTable")
		:CallMethod(state.auctionBuyScan, "SetAuctionScrollTable")
	)

	TaskList.SetStartGatheringFunc(function(items, stateCallback, buyCallback, mode)
		private.manager:ProcessAction("ACTION_START_GATHERING_SEARCH", items, stateCallback, buyCallback, mode)
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the Browse frame.
---@return ViewContainer
function Shopping.GetFrame()
	return private.manager:BuildFrame()
end

---Handles an item being linked.
---@param name string The item name
---@param itemLink string The item link
---@return boolean
function Shopping.HandleItemLinked(name, itemLink)
	private.manager:ProcessAction("ACTION_ITEM_LINKED", name, itemLink)
	return true
end



-- ============================================================================
-- Shopping UI
-- ============================================================================

---@param state ShoppingUIState
function private.GetShoppingFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "shopping")
	if not state.auctionBuyScan:GetSearchContext() then
		state.contentPath = "selection"
	end
	local frame = UIElements.New("ViewContainer", "shopping")
		:SetContext(state)
		:SetNavCallback(private.GetShoppingContentFrame)
		:AddPath("selection")
		:AddPath("scan")
		:SetPath(state.contentPath)
		:SetManager(private.manager)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_FRAME_HIDDEN"))
		:BindElement(state, "frame")
	TaskList.HandleShoppingTaskUIUpdate()
	TaskList.SetShoppingTaskUIVisible(true)
	return frame
end

function private.GetShoppingContentFrame(viewContainer, path)
	local state = viewContainer:GetContext() ---@type ShoppingUIState
	state.contentPath = path
	if path == "selection" then
		return private.GetSelectionFrame(state)
	elseif path == "scan" then
		return private.GetScanFrame(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state ShoppingUIState
function private.GetSelectionFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "shopping", "selection")
	return UIElements.New("DividedContainer", "selection")
		:SetSettingsContext(private.settings, "shoppingSelectionDividedContainer")
		:SetMinWidth(220, 350)
		:SetPadding(4)
		:HideDivider()
		:SetLeftChild(UIElements.New("BaseFrame", "groupSelection")
			:SetLayout("VERTICAL")
			:SetMargin(0, 3, 0, 0)
			:SetPadding(8)
			:SetRoundedBackgroundColor("container/low")
			:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
				:SetOperationType("Shopping")
				:BindElement(state, "groupTree")
				:BindSelectionCleared(state, "groupSelectionCleared")
				:SetSettingsContext(private.settings, "shoppingGroupTree")
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "scanBtn")
				:SetMargin(0, 0, 12, 0)
				:SetText(L["Run Shopping Scan"])
				:SetDisabled(state:Publisher("groupSelectionCleared"))
				:SetAction("OnClick", "ACTION_START_GROUP_SEARCH")
			)
		)
		:SetRightChild(UIElements.New("ViewContainer", "content")
			:SetMargin(3, 0, 0, 0)
			:SetContext(state)
			:BindElement(state, "selectionView")
			:SetNavCallback(private.GetSelectionContent)
			:AddPath("search", true)
			:AddPath("advanced")
		)
end

function private.GetSelectionContent(frame, path)
	local state = frame:GetContext() ---@type ShoppingUIState
	if path == "search" then
		state.greatDealsAvailable = ShoppingApp.IsGreatDealsAvailable()
		return UIElements.New("BaseFrame", "search")
			:SetLayout("VERTICAL")
			:SetPadding(8)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("Input", "filterInput")
					:BindElement(state, "filterInput")
					:SetLeadIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:SetFocused(private.settings.searchAutoFocus)
					:SetHintText(L["Search the auction house"])
					:SetAction("OnValueChanged", "ACTION_FILTER_INPUT_CHANGED")
					:SetAction("OnEnterPressed", "ACTION_START_FILTER_INPUT_SEARCH")
				)
				:AddChild(UIElements.New("SmallPrimaryActionButton", "search")
					:SetWidth("AUTO")
					:SetPadding(16, 16, 0, 0)
					:SetMargin(8, 0, 0, 0)
					:SetText(GlobalStrings.Get("SEARCH"))
					:SetDisabled(state:Publisher("filterIsValid"):InvertBoolean())
					:SetAction("OnClick", "ACTION_START_FILTER_INPUT_SEARCH")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "buttonsLine1")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("MediumSecondaryActionButton", "advSearchBtn")
					:SetMargin(0, 8, 0, 0)
					:SetText(L["Advanced Item Search"])
					:SetAction("OnClick", "ACTION_SHOW_ADVANCED_SEARCH")
				)
				:AddChild(UIElements.New("MediumSecondaryActionButton", "vendorBtn")
					:SetText(L["Vendor Search"])
					:SetAction("OnClick", "ACTION_START_VENDOR_SEARCH")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "buttonsLine2")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:AddChild(UIElements.New("MediumSecondaryActionButton", "disenchantBtn")
					:SetMargin(0, 8, 0, 0)
					:SetText(L["Disenchant Search"])
					:SetAction("OnClick", "ACTION_START_DISENCHANT_SEARCH")
				)
				:AddChild(UIElements.New("MediumSecondaryActionButton", "dealsBtn")
					:SetText(L["Great Deals Search"])
					:SetDisabled(state:Publisher("greatDealsAvailable"):InvertBoolean())
					:SetAction("OnClick", "ACTION_START_DEALS_SEARCH")
				)
			)
			:AddChild(UIElements.New("SegmentedTabGroup", "buttons")
				:SetMargin(0, 0, 16, 0)
				:SetNavCallback(private.GetSearchesElement)
				:SetSettingsContext(private.settings, "shoppingSearchesTabGroup")
				:AddPath(L["Recent Searches"])
				:AddPath(L["Favorite Searches"])
			)
	elseif path == "advanced" then
		return UIElements.New("ShoppingAdvancedSearch", "advanced")
			:BindElement(state, "advancedSearchFrame")
			:SetAction("OnBackClicked", "ACTION_ADVANCED_SEARCH_BACK")
			:SetAction("OnStartScanClicked", "ACTION_START_ADVANCED_SEARCH")
	else
		error("Unexpected path: "..tostring(path))
	end
end

function private.GetSearchesElement(_, button)
	if button == L["Recent Searches"] then
		return UIElements.New("SearchList", "list")
			:SetBackgroundColor("surface/main")
			:SetEditEnabled(false)
			:SetQuery(ShoppingSavedSearches.CreateRecentQuery())
			:SetAction("OnFavoriteChanged", "ACTION_SET_SEARCH_FAVORITE")
			:SetAction("OnDelete", "ACTION_RECENT_SEARCH_DELETE")
			:SetAction("OnRowClick", "ACTION_RECENT_SEARCH_LIST_ROW_CLICK")
	elseif button == L["Favorite Searches"] then
		return UIElements.New("SearchList", "list")
			:SetBackgroundColor("surface/main")
			:SetEditEnabled(true)
			:SetQuery(ShoppingSavedSearches.CreateFavoriteQuery())
			:SetAction("OnFavoriteChanged", "ACTION_SET_SEARCH_FAVORITE")
			:SetAction("OnEdit", "ACTION_FAVORITE_SEARCH_EDIT")
			:SetAction("OnDelete", "ACTION_FAVORITE_SEARCH_DELETE")
			:SetAction("OnRowClick", "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK")
	else
		error("Unexpected button: "..tostring(button))
	end
end

---@param state ShoppingUIState
function private.GetScanFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "shopping", "scan")
	return UIElements.New("BaseFrame", "scan")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("ExitScanButton", "back")
				:SetMargin(0, 8, 0, 0)
				:SetAction("OnClick", "ACTION_SCAN_BACK_BUTTON_CLICKED")
			)
			:AddChild(UIElements.New("Input", "filterInput")
				:BindElement(state, "filterInput")
				:SetLeadIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:SetHintText(L["Enter Filter"])
				:SetValue(state.searchName)
				:SetAction("OnEnterPressed", "ACTION_START_FILTER_INPUT_SEARCH")
			)
			:AddChild(UIElements.New("SmallSecondaryActionButton", "rescanBtn")
				:SetWidth(140)
				:SetMargin(8, 0, 0, 0)
				:SetText(L["Rescan"])
				:SetDisabled(state:Publisher("searchName"):ToBooleanEquals(L["Gathering Search"]))
				:SetAction("OnClick", "ACTION_RESCAN")
			)
		)
		:AddChild(UIElements.New("ListContainer", "results")
			:AddChild(UIElements.New("AuctionScrollTable", "auctions")
				:SetSettings(private.settings, "shoppingAuctionScrollingTable")
				:SetCreatedGroupName(L["Browse"].." - "..state.searchName)
				:SetBrowseResultsVisible(true)
				:SetIsPlayerFunction(PlayerInfo.AuctionOwnerIsPlayer)
				:BindElement(state, "scrollTable")
			)
		)
		:AddChild(state.auctionBuyScan:CreateBottomUIFrameForBrowse())
end


-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<ShoppingUIState>
---@param state ShoppingUIState
---@param action ShoppingAction
---@param ... params<ShoppingAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_HIDDEN" then
		TaskList.HandleShoppingTaskUIUpdate()
		TaskList.SetShoppingTaskUIVisible(false)
	elseif action == "ACTION_SHOW_ADVANCED_SEARCH" then
		state.selectionView:SetPath("advanced", true)
	elseif action == "ACTION_ADVANCED_SEARCH_BACK" then
		state.selectionView:SetPath("search", true)
	elseif action == "ACTION_START_GROUP_SEARCH" then
		return manager:ProcessAction("ACTION_START_SEARCH", private.GetGroupSearchContext(state))
	elseif action == "ACTION_START_ADVANCED_SEARCH" then
		local filter = ...
		return manager:ProcessAction("ACTION_START_FILTER_SEARCH", filter)
	elseif action == "ACTION_SET_SEARCH_FAVORITE" then
		local index, isFavorite = ...
		ShoppingSavedSearches.SetIsFavorite(index, isFavorite)
	elseif action == "ACTION_RECENT_SEARCH_DELETE" then
		local index = ...
		ShoppingSavedSearches.Delete(index, private.GetSearchListFields("RECENT", index, "filter"))
	elseif action == "ACTION_FAVORITE_SEARCH_DELETE" then
		local index = ...
		ShoppingSavedSearches.Delete(index, private.GetSearchListFields("FAVORITE", index, "filter"))
	elseif action == "ACTION_FAVORITE_SEARCH_EDIT" then
		local index = ...
		local dialog = UIElements.New("SavedSearchEditDialog", "frame")
			:SetSize(600, 114)
			:AddAnchor("CENTER")
			:Configure(private.GetSearchListFields("FAVORITE", index, "name"), index)
			:SetManager(manager)
			:SetAction("OnNameChanged", "ACTION_RENAMED_SAVED_SEARCH")
		state.frame:GetBaseElement():ShowDialogFrame(dialog)
		dialog:SetNameInputFocused(true)
	elseif action == "ACTION_RENAMED_SAVED_SEARCH" then
		local name, index = ...
		ShoppingSavedSearches.Rename(index, name)
	elseif action == "ACTION_RECENT_SEARCH_LIST_ROW_CLICK" then
		local index = ...
		local filter = private.GetSearchListFields("RECENT", index, "filter")
		return manager:ProcessAction("ACTION_START_FILTER_SEARCH", filter)
	elseif action == "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK" then
		local index = ...
		local filter = private.GetSearchListFields("FAVORITE", index, "filter")
		return manager:ProcessAction("ACTION_START_FILTER_SEARCH", filter)
	elseif action == "ACTION_START_GATHERING_SEARCH" then
		local items, stateCallback, buyCallback, mode = ...
		return manager:ProcessAction("ACTION_START_SEARCH", private.GetGatheringSearchContext(state, items, stateCallback, buyCallback, mode))
	elseif action == "ACTION_START_ITEM_SEARCH" then
		local itemLink = ...
		return manager:ProcessAction("ACTION_START_SEARCH", private.GetLinkedItemSearchContext(state, ItemInfo.GetName(itemLink), itemLink))
	elseif action == "ACTION_ITEM_LINKED" then
		local name, itemLink = ...
		if state.advancedSearchFrame then
			-- They are on the advanced search UI, so just populate the filter dialog instead of starting a search
			state.advancedSearchFrame:SetKeywordFilter(name)
			return
		end
		return manager:ProcessAction("ACTION_START_ITEM_SEARCH", itemLink)
	elseif action == "ACTION_START_VENDOR_SEARCH" then
		return manager:ProcessAction("ACTION_START_SEARCH", ShoppingApp.GetVendorSearchContext())
	elseif action == "ACTION_START_DISENCHANT_SEARCH" then
		return manager:ProcessAction("ACTION_START_SEARCH", ShoppingApp.GetDisenchantSearchContext())
	elseif action == "ACTION_START_DEALS_SEARCH" then
		assert(state.greatDealsAvailable)
		return manager:ProcessAction("ACTION_START_SEARCH", ShoppingApp.GetGreatDealsSearchContext())
	elseif action == "ACTION_FILTER_INPUT_CHANGED" then
		local value = state.filterInput:GetValue()
		state.filterIsValid = (not App.IsVanillaClassic() and not App.IsBCClassic()) or value ~= ""
	elseif action == "ACTION_START_FILTER_INPUT_SEARCH" then
		local filter = state.filterInput:GetValue()
		if (App.IsVanillaClassic() or App.IsBCClassic()) and filter == "" then
			return
		end
		return manager:ProcessAction("ACTION_START_FILTER_SEARCH", filter)
	elseif action == "ACTION_START_FILTER_SEARCH" then
		local filter = ...
		return manager:ProcessAction("ACTION_START_SEARCH", ShoppingApp.GetFilterSearchContext(filter))
	elseif action == "ACTION_START_SEARCH" then
		local searchContext = ...
		state.frame:SetPath("selection", true)
		if not searchContext then
			return
		end
		if not state.auctionBuyScan:PrepareStartSearch() then
			return
		end
		local name = searchContext:GetName()
		assert(name)
		state.searchName = name
		state.auctionBuyScan:StartSearch(searchContext)
		state.frame:SetPath("scan", true)
	elseif action == "ACTION_SCAN_BACK_BUTTON_CLICKED" then
		state.searchName = ""
		state.frame:SetPath("selection", true)
		state.auctionBuyScan:EndSearch()
	elseif action == "ACTION_RESCAN" then
		return manager:ProcessAction("ACTION_START_SEARCH", state.auctionBuyScan:GetSearchContext())
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param state ShoppingUIState
function private.GetGroupSearchContext(state)
	wipe(private.selectedGroups)
	assert(state.groupTree)
	for _, groupPath in state.groupTree:SelectedGroupsIterator() do
		if groupPath ~= "" and not strmatch(groupPath, "^`") then
			tinsert(private.selectedGroups, groupPath)
		end
	end
	local searchContext = ShoppingApp.GetGroupSearchContext(private.selectedGroups)
	assert(searchContext)
	return searchContext
end

function private.GetGatheringSearchContext(_, items, stateCallback, buyCallback, mode)
	local filter = Iterator.Acquire(pairs(items))
		:SetMapFunc(private.GatheringFilterPart)
		:ToJoinedValueString(";")
	local searchContext = ShoppingApp.GetGatheringSearchContext(filter, mode)
	assert(searchContext)
	searchContext:SetCallbacks(buyCallback, stateCallback)
	return searchContext
end

function private.GatheringFilterPart(itemString, quantity)
	return itemString.."/x"..quantity
end

---@param state ShoppingUIState
function private.GetLinkedItemSearchContext(state, name, itemLink)
	local itemString = ItemString.Get(itemLink)
	assert(itemString)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local baseName = ItemInfo.GetName(baseItemString) or name
	assert(baseName)
	if itemString == baseItemString then
		baseName = baseName.."/exact"
	end
	state.frame:SetPath("selection")
	state.frame:GetBaseElement():HideDialog()
	private.itemPostContext:PopulateForItem(itemString)
	return ShoppingApp.GetFilterSearchContext(baseName, private.itemPostContext)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsPlayer(character, includeAlts)
	if includeAlts then
		return PlayerInfo.IsPlayer(character, true, true, true)
	else
		return PlayerInfo.IsPlayer(character)
	end
end

function private.GetAlertThreshold(itemString)
	return private.settings.buyoutConfirm and (CustomString.GetValue(private.settings.buyoutAlertSource, itemString) or 0) or nil
end

function private.GetSearchListFields(listType, index, ...)
	local query = nil
	if listType == "RECENT" then
		query = ShoppingSavedSearches.CreateRecentQuery()
	elseif listType == "FAVORITE" then
		query = ShoppingSavedSearches.CreateFavoriteQuery()
	else
		error("Invalid search list type: "..tostring(listType))
	end
	return query
		:AutoRelease()
		:Equal("index", index)
		:GetFirstResult(...)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local AuctioningSavedSearches = App:From("LibTSMTypes"):Include("SavedSearches.AuctioningSavedSearches")
local UIElements = App:From("LibTSMUI"):Include("UIElements")

---@class AuctioningSelectionSettings: SettingsView
---@field auctioningSelectionDividedContainer table
---@field auctioningGroupTree table
---@field auctioningSelectionVerticalDividedContainer table
---@field auctioningTabGroup table
---@field auctioningBagScrollingTable table



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningSelection = UIElements.Define("AuctioningSelection", "DividedContainer")
AuctioningSelection._STATE_SCHEMA = AuctioningSelection._STATE_SCHEMA:Extend("AuctioningSelectionState")
	:AddDeferredUIElementField("contentFrame", "DividedContainer")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddDeferredUIElementField("bagScrollTable", "AuctioningBagScrollTable")
	:AddDeferredUIElementField("savedSearchesTabGroup", "SegmentedTabGroup")
	:AddBooleanField("groupSelectionCleared", true)
	:AddBooleanField("bagAllSelected", false)
	:AddBooleanField("bagNoneSelected", true)
	:Commit()
AuctioningSelection:_AddActionScripts("OnStartGroupPostScan", "OnStartBagPostScan", "OnStartGroupCancelScan", "OnStartSavedSearch")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningSelection:__init()
	self.__super:__init()
	self._childManager
		:SuppressActionLog("ACTION_BAG_SELECT_ALL")
		:SuppressActionLog("ACTION_BAG_CLEAR_ALL")
end

function AuctioningSelection:Acquire()
	self.__super:Acquire()

	self
		:SetMinWidth(220, 250)
		:SetPadding(4)
		:HideDivider()
	local leftChild, rightChild = nil, nil
	for _ in self._state:WithAutoStorePaused() do
		local groupSelectionClearedPublisher = self._state:Publisher("groupSelectionCleared")
			:Share()
		leftChild = UIElements.New("BaseFrame", "groupSelection")
			:SetLayout("VERTICAL")
			:SetMargin(0, 3, 0, 0)
			:SetPadding(8)
			:SetRoundedBackgroundColor("container/low")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
				:SetOperationType("Auctioning")
				:BindSelectionCleared(self._state, "groupSelectionCleared")
				:BindElement(self._state, "groupTree")
			)
			:AddChild(UIElements.New("MediumSecondaryActionButton", "postScanBtn")
				:SetMargin(0, 0, 12, 0)
				:SetText(L["Run Post Scan"])
				:SetDisabled(groupSelectionClearedPublisher)
				:SetAction("OnClick", "ACTION_START_GROUP_POST_SCAN")
			)
			:AddChild(UIElements.New("MediumSecondaryActionButton", "cancelScanBtn")
				:SetMargin(0, 0, 8, 0)
				:SetText(L["Run Cancel Scan"])
				:SetDisabled(groupSelectionClearedPublisher)
				:SetAction("OnClick", "ACTION_START_GROUP_CANCEL_SCAN")
			)
		self:AddCancellable(groupSelectionClearedPublisher:EndShare())
		local bagNoneSelectedPublisher = self._state:Publisher("bagNoneSelected")
			:Share()
		rightChild = UIElements.New("DividedContainer", "content")
			:SetVertical()
			:HideDivider()
			:BindElement(self._state, "contentFrame")
			:SetManager(self._childManager)
			:SetMargin(3, 0, 0, 0)
			:SetMinWidth(50, 100)
			:SetTopChild(UIElements.New("SegmentedTabGroup", "buttons")
				:SetMargin(0, 0, 4, 3)
				:SetNavCallback(self:__closure("_GetScansElement"))
				:AddPath(L["Recent Scans"], true)
				:AddPath(L["Favorite Scans"])
				:BindElement(self._state, "savedSearchesTabGroup")
			)
			:SetBottomChild(UIElements.New("BaseFrame", "bottom")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 3, 0)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(20)
					:SetFont("BODY_BODY1_MEDIUM")
					:SetJustifyH("CENTER")
					:SetText(L["Post Items from Bags"])
				)
				:AddChild(UIElements.New("ListContainer", "table")
					:SetMargin(0, 0, 8, 8)
					:AddChild(UIElements.New("AuctioningBagScrollTable", "bagScrollingTable")
						:BindElement(self._state, "bagScrollTable")
						:BindSelectionstate(self._state, "bagAllSelected", "bagNoneSelected")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "footer")
					:SetLayout("HORIZONTAL")
					:SetHeight(28)
					:AddChild(UIElements.New("MediumPrimaryActionButton", "postSelected")
						:SetMargin(0, 4, 0, 0)
						:SetDisabled(bagNoneSelectedPublisher)
						:SetText(L["Post Selected"])
						:SetAction("OnClick", "ACTION_START_BAGS_POST_SCAN")
					)
					:AddChild(UIElements.New("MediumTertiaryActionButton", "selectAll")
						:SetWidth("AUTO")
						:SetPadding(16, 16, 0, 0)
						:SetMargin(0, 4, 0, 0)
						:SetText(L["Select All"])
						:SetDisabled(self._state:Publisher("bagAllSelected"))
						:SetAction("OnClick", "ACTION_BAG_SELECT_ALL")
					)
					:AddChild(UIElements.New("MediumTertiaryActionButton", "clearAll")
						:SetWidth("AUTO")
						:SetPadding(16, 16, 0, 0)
						:SetText(L["Clear All"])
						:SetDisabled(bagNoneSelectedPublisher)
						:SetAction("OnClick", "ACTION_BAG_CLEAR_ALL")
					)
				)
			)
		self:AddCancellable(bagNoneSelectedPublisher:EndShare())
	end
	self:SetLeftChild(leftChild)
	self:SetRightChild(rightChild)
end

---Configure the Auctioning selection UI.
---@param settings AuctioningSelectionSettings The settings object
---@param bagsQuery DatabaseQuery The query for posting from bags
---@return self
function AuctioningSelection:Configure(settings, bagsQuery)
	self:SetSettingsContext(settings, "auctioningSelectionDividedContainer")
	self._state.groupTree:SetSettingsContext(settings, "auctioningGroupTree")
	self._state.contentFrame:SetSettingsContext(settings, "auctioningSelectionVerticalDividedContainer")
	self._state.savedSearchesTabGroup:SetSettingsContext(settings, "auctioningTabGroup")
	self._state.bagScrollTable:SetSettings(settings, "auctioningBagScrollingTable")
	self._state.bagScrollTable:SetQuery(bagsQuery)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<AuctioningSelectionState>
---@param state AuctioningSelectionState
function AuctioningSelection.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_START_GROUP_POST_SCAN" then
		self:_SendActionScript("OnStartGroupPostScan", state.groupTree:SelectedGroupsIterator())
	elseif action == "ACTION_START_GROUP_CANCEL_SCAN" then
		self:_SendActionScript("OnStartGroupCancelScan", state.groupTree:SelectedGroupsIterator())
	elseif action == "ACTION_FAVORITE_SAVED_SEARCH" then
		local index, isFavorite = ...
		AuctioningSavedSearches.SetIsFavorite(index, isFavorite)
	elseif action == "ACTION_DELETE_SAVED_SEARCH" then
		local index = ...
		AuctioningSavedSearches.Delete(index)
	elseif action == "ACTION_EDIT_FAVORITE_SEARCH" then
		local index, name = ...
		local dialog = UIElements.New("SavedSearchEditDialog", "frame")
			:SetSize(600, 114)
			:AddAnchor("CENTER")
			:Configure(name, index)
			:SetManager(manager)
			:SetAction("OnNameChanged", "ACTION_RENAMED_SAVED_SEARCH")
		self:GetBaseElement():ShowDialogFrame(dialog)
		dialog:SetNameInputFocused(true)
	elseif action == "ACTION_RENAMED_SAVED_SEARCH" then
		local name, index = ...
		AuctioningSavedSearches.Rename(index, name)
	elseif action == "ACTION_START_SAVED_SEARCH" then
		local index = ...
		self:_SendActionScript("OnStartSavedSearch", index)
	elseif action == "ACTION_START_BAGS_POST_SCAN" then
		self:_SendActionScript("OnStartBagPostScan", state.bagScrollTable:SelectedItemsIterator())
	elseif action == "ACTION_BAG_SELECT_ALL" then
		state.bagScrollTable:SetSelectionState(true)
	elseif action == "ACTION_BAG_CLEAR_ALL" then
		state.bagScrollTable:SetSelectionState(false)
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function AuctioningSelection.__private:_GetScansElement(_, path)
	if path == L["Recent Scans"] then
		return UIElements.New("SearchList", "list")
			:SetBackgroundColor("surface/main")
			:SetEditEnabled(false)
			:SetQuery(AuctioningSavedSearches.CreateRecentQuery())
			:SetAction("OnFavoriteChanged", "ACTION_FAVORITE_SAVED_SEARCH")
			:SetAction("OnDelete", "ACTION_DELETE_SAVED_SEARCH")
			:SetAction("OnRowClick", "ACTION_START_SAVED_SEARCH")
	elseif path == L["Favorite Scans"] then
		return UIElements.New("SearchList", "list")
			:SetBackgroundColor("surface/main")
			:SetEditEnabled(true)
			:SetQuery(AuctioningSavedSearches.CreateFavoriteQuery())
			:SetAction("OnEdit", "ACTION_EDIT_FAVORITE_SEARCH")
			:SetAction("OnFavoriteChanged", "ACTION_FAVORITE_SAVED_SEARCH")
			:SetAction("OnDelete", "ACTION_DELETE_SAVED_SEARCH")
			:SetAction("OnRowClick", "ACTION_START_SAVED_SEARCH")
	else
		error("Unknown path: "..tostring(path))
	end
end

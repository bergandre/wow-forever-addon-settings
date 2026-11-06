-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local MyAuctions = App:Init("AuctionUI.MyAuctions")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local AuctionHouse = App:From("LibTSMWoW"):Include("API.AuctionHouse")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local MyAuctionsApp = App:From("LibTSMApp"):Include("MyAuctions")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
}
local DURATION_LIST = {
	L["None"],
	select(2, AuctionHouse.GetTimeLeftStrings(1)),
	select(2, AuctionHouse.GetTimeLeftStrings(2)),
	select(2, AuctionHouse.GetTimeLeftStrings(3)),
	select(2, AuctionHouse.GetTimeLeftStrings(4)),
}
local PROGRESS_TEXTS = {
	cancel = L["Canceling Auction..."],
	ready = L["Ready to Cancel"],
	select = L["Select Auction to Cancel"],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("MyAuctionsUIState")
	:AddOptionalUIElementField("frame", "BaseFrame")
	:AddDeferredUIElementField("auctionsScrollTable", "MyAuctionsScrollTable")
	:AddOptionalClassField("query", "DatabaseQuery")
	:AddOptionalClassField("queryCancellable", "ReactivePublisher")
	:AddBooleanField("hasFilter", false)
	:AddOptionalNumberField("selectedAuctionId")
	:AddBooleanField("isSelectionPending", false)
	:AddBooleanField("canCancel", false)
	:AddNumberField("numPosted", 0)
	:AddNumberField("numSold", 0)
	:AddNumberField("postedGold", 0)
	:AddNumberField("soldGold", 0)
	:AddBooleanField("cancelPending", false)
	:AddStringField("keywordText", "")
	:AddOptionalNumberField("durationIndex")
	:AddStringField("groupSelectorStr", "")
	:AddBooleanField("ignoreBidChecked", false)
	:AddBooleanField("onlyBidChecked", false)
	:AddBooleanField("onlySoldChecked", false)
	:AddOptionalStringField("keywordFilter")
	:AddOptionalStringField("groupsFilter")
	:AddOptionalNumberField("durationFilter")
	:AddOptionalBooleanField("bidFilter")
	:AddBooleanField("soldFilter", false)
	:Commit()

---@event MyAuctionsAction
---| "ACTION_FRAME_SHOW"
---| "ACTION_RESET_STATE"
---| "ACTION_DATA_UPDATED"
---| "ACTION_FILTER_UPDATED"
---| "ACTION_CANCEL_AUCTION"
---| "ACTION_SKIP_AUCTION"
---| "ACTION_ITEM_LINKED" -> name: string
---| "ACTION_CLEAR_FILTERS"



-- ============================================================================
-- Module Functions
-- ============================================================================

AddonSettings.RegisterOnLoad(MyAuctions, function(db)
	private.settings = db:NewView("MyAuctionsSettings")
		:AddKey("global", "auctionUIContext", "myAuctionsScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MY_AUCTIONS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_DATA_UPDATED")
		:SuppressActionLog("ACTION_FILTER_UPDATED")
		:AddFrameBuilder(private.GetMyAuctionsFrame)

	private.manager:ProcessActionFromPublisher("ACTION_RESET_STATE", state:Publisher("frame")
		:IgnoreIfNotEquals(nil)
	)

	-- Set up some computed state properties
	if App.IsVanillaClassic() or App.IsBCClassic() then
		private.manager:SetStateFromPublisher("canCancel", state:Publisher([[not cancelPending and not isSelectionPending and selectedAuctionId ~= nil]]))
	else
		private.manager:SetStateFromPublisher("canCancel", state:Publisher([[not cancelPending and not isSelectionPending and selectedAuctionId or nil]])
			:MapNonNil(AuctionHouse.GetCancelCost)
			:Map(function(cancelCost) return (cancelCost or math.huge) <= Currency.GetMoney() end)
		)
	end

	-- Uncheck the other toggle in the pair of "bid" toggles
	private.manager:SetStateFromPublisher("onlyBidChecked", state:Publisher([[ignoreBidChecked and bidFilter == true or nil]])
		:IgnoreNil()
		:ReplaceWith(false)
	)
	private.manager:SetStateFromPublisher("ignoreBidChecked", state:Publisher([[onlyBidChecked and bidFilter == false or nil]])
		:IgnoreNil()
		:ReplaceWith(false)
	)
	-- Uncheck the other toggle in the pair of "only" toggles
	private.manager:SetStateFromPublisher("onlySoldChecked", state:Publisher([[onlyBidChecked and soldFilter == true or nil]])
		:IgnoreNil()
		:ReplaceWith(false)
	)
	private.manager:SetStateFromPublisher("onlyBidChecked", state:Publisher([[onlySoldChecked and bidFilter == true or nil]])
		:IgnoreNil()
		:ReplaceWith(false)
	)

	private.manager:AddCancellable(MyAuctionsApp.IsPendingPublisher()
		:AssignToTableKey(state, "cancelPending")
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the MyAuctions frame.
---@return BaseFrame
function MyAuctions.GetFrame()
	return private.manager:BuildFrame()
end

---Handles an item being linked.
---@param name string The item name
---@param itemLink string The item link
---@return boolean
function MyAuctions.HandleItemLinked(name, itemLink)
	private.manager:ProcessAction("ACTION_ITEM_LINKED", name)
	return true
end



-- ============================================================================
-- MyAuctions UI
-- ============================================================================

---@param state MyAuctionsUIState
function private.GetMyAuctionsFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "my_auctions")
	return UIElements.New("BaseFrame", "myAuctions")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "filters")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("ListDropdown", "duration")
				:SetWidth(232)
				:SetItems(DURATION_LIST)
				:SetHintText(L["Filter by duration"])
				:MirrorSelectedItemIndexState(state, "durationIndex")
				:SetAction("OnSelectionChanged", "ACTION_FILTER_UPDATED")
			)
			:AddChild(UIElements.New("GroupSelector", "group")
				:SetWidth(232)
				:SetMargin(8, 8, 0, 0)
				:SetHintText(L["Filter by groups"])
				:MirrorSelectionString(state, "groupSelectorStr")
				:SetAction("OnSelectionChanged", "ACTION_FILTER_UPDATED")
			)
			:AddChild(UIElements.New("Input", "keyword")
				:SetLeadIconTexture("iconPack.18x18/Search")
				:AllowItemInsert(false)
				:SetClearButtonEnabled(true)
				:SetHintText(L["Filter by keyword"])
				:MirrorValueState(state, "keywordText")
				:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "toggles")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("Checkbox", "ignoreBid")
				:SetWidth("AUTO")
				:SetText(L["Hide auctions with bids"])
				:MirrorIsCheckedState(state, "ignoreBidChecked")
				:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
			)
			:AddChild(UIElements.New("Checkbox", "onlyBid")
				:SetMargin(16, 0, 0, 0)
				:SetWidth("AUTO")
				:SetText(L["Show only auctions with bids"])
				:MirrorIsCheckedState(state, "onlyBidChecked")
				:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
			)
			:AddChild(UIElements.New("Checkbox", "onlySold")
				:SetMargin(16, 0, 0, 0)
				:SetWidth("AUTO")
				:SetText(L["Only show sold auctions"])
				:MirrorIsCheckedState(state, "onlySoldChecked")
				:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("SmallTertiaryActionButton", "clearfilter")
				:SetWidth("AUTO")
				:SetPadding(8, 8, 0, 0)
				:SetText(L["Clear Filters"])
				:SetDisabled(state:Publisher("hasFilter"):InvertBoolean())
				:SetAction("OnClick", "ACTION_CLEAR_FILTERS")
			)
		)
		:AddChild(UIElements.New("ListContainer", "auctions")
			:AddChild(UIElements.New("MyAuctionsScrollTable", "table")
				:SetSortingDisabled(App.IsVanillaClassic() or App.IsBCClassic())
				:SetSettings(private.settings, "myAuctionsScrollingTable")
				:SetQuery(MyAuctionsApp.CreateQuery())
				:BindElement(state, "auctionsScrollTable")
				:BindSelectedAuctionId(state, "selectedAuctionId")
				:BindIsSelectionPending(state, "isSelectionPending")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "totals")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetMargin(0, 0, 8, 0)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("Text", "sold")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(state:PublisherForFunctionWithKeys(private.StateToSoldText, "hasFilter", "numSold"))
			)
			:AddChild(UIElements.New("Text", "soldValue")
				:SetWidth("AUTO")
				:SetMargin(0, 24, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForAH, "soldGold"))
			)
			:AddChild(UIElements.New("Text", "posted")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(state:PublisherForFunctionWithKeys(private.StateToPostedText, "hasFilter", "numPosted"))
			)
			:AddChild(UIElements.New("Text", "postedValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForAH, "postedGold"))
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)
		:AddChild(UIElements.New("BaseFrame", "bottom")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("ProgressBar", "progressBar")
				:SetMargin(0, 8, 0, 0)
				:SetTextColor("on/surface/low")
				:SetProgress(0)
				:SetText(state:Publisher([[(cancelPending and "cancel") or (selectedAuctionId and "ready") or "select"]]):Map(PROGRESS_TEXTS))
				:SetProgressIconHidden(state:Publisher("cancelPending"):InvertBoolean())
			)
			:AddChild(UIElements.New("MediumSecondaryActionButton", "skipBtn")
				:SetWidth(110)
				:SetMargin(0, 8, 0, 0)
				:SetText(L["Skip"])
				:DisableClickCooldown()
				:SetDisabled(state:Publisher("selectedAuctionId"):ToBooleanEquals(nil))
				:SetAction("OnClick", "ACTION_SKIP_AUCTION")
			)
			:AddChild(UIElements.NewNamed("MediumPrimaryActionButton", "cancelBtn", "TSMCancelAuctionBtn")
				:SetWidth(110)
				:SetText(GlobalStrings.Get("CANCEL"))
				:DisableClickCooldown()
				:SetDisabled(state:Publisher("canCancel"):InvertBoolean())
				:SetAction("OnClick", "ACTION_CANCEL_AUCTION")
			)
		)
		:WithProcessAction("ACTION_FRAME_SHOW")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MyAuctionsUIState>
---@param state MyAuctionsUIState
---@param action MyAuctionsAction
---@param ... params<MyAuctionsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW" then
		assert(not state.query and not state.queryCancellable)
		state.query = MyAuctionsApp.CreateQuery()
		state.queryCancellable = state.query:Publisher()
			:CallFunction(manager:CallbackToProcessAction("ACTION_DATA_UPDATED"))
			:Stored()
		state.auctionsScrollTable:SetFilters(state.keywordFilter, state.durationFilter, state.groupsFilter, state.bidFilter, state.soldFilter)
		private.UpdateQueryTotals(state)
	elseif action == "ACTION_RESET_STATE" then
		if state.queryCancellable then
			state.queryCancellable:Cancel()
			state.queryCancellable = nil
		end
		if state.query then
			state.query:Release()
			state.query = nil
		end
		state.selectedAuctionId = nil
		state.isSelectionPending = false
	elseif action == "ACTION_DATA_UPDATED" then
		if not state.frame then
			return
		end
		private.UpdateQueryTotals(state)
	elseif action == "ACTION_FILTER_UPDATED" then
		private.UpdateFilters(state)
		private.UpdateQueryTotals(state)
	elseif action == "ACTION_CANCEL_AUCTION" then
		assert(state.selectedAuctionId)
		MyAuctionsApp.CancelAuction(state.selectedAuctionId)
	elseif action == "ACTION_SKIP_AUCTION" then
		state.auctionsScrollTable:SelectNextRow()
	elseif action == "ACTION_ITEM_LINKED" then
		local name = ...
		state.keywordText = name
		return manager:ProcessAction("ACTION_FILTER_UPDATED")
	elseif action == "ACTION_CLEAR_FILTERS" then
		state.durationIndex = nil
		state.groupSelectorStr = ""
		state.keywordText = ""
		state.ignoreBidChecked = false
		state.onlyBidChecked = false
		state.onlySoldChecked = false
		return manager:ProcessAction("ACTION_FILTER_UPDATED")
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param state MyAuctionsUIState
function private.UpdateQueryTotals(state)
	local numPosted, numSold, postedGold, soldGold = state.auctionsScrollTable:GetTotals()
	state.numPosted = numPosted
	state.numSold = numSold
	state.postedGold = postedGold
	state.soldGold = soldGold
end

---@param state MyAuctionsUIState
function private.UpdateFilters(state)
	local didChange = false

	-- Clear the duration selection if "None" is selected
	if state.durationIndex == 1 then
		state.durationIndex = nil
	end

	local duration = state.durationIndex and (state.durationIndex - 1) or nil
	if duration ~= state.durationFilter then
		state.durationFilter = duration
		didChange = true
	end

	local keyword = state.keywordText ~= "" and String.Escape(state.keywordText) or nil
	if keyword ~= state.keywordFilter then
		state.keywordFilter = keyword
		didChange = true
	end

	local groupsFilter = state.groupSelectorStr
	groupsFilter = groupsFilter ~= "" and groupsFilter or nil
	if groupsFilter ~= state.groupsFilter then
		state.groupsFilter = groupsFilter
		didChange = true
	end

	local bid = nil
	if state.ignoreBidChecked then
		bid = false
	elseif state.onlyBidChecked then
		bid = true
	end
	if bid ~= state.bidFilter then
		state.bidFilter = bid
		didChange = true
	end

	local sold = state.onlySoldChecked
	if sold ~= state.soldFilter then
		state.soldFilter = sold
		didChange = true
	end

	state.hasFilter = (duration or keyword or groupsFilter or bid ~= nil or sold) and true or false
	if didChange then
		state.auctionsScrollTable:SetFilters(state.keywordFilter, state.durationFilter, state.groupsFilter, state.bidFilter, state.soldFilter)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToSoldText(hasFilter, numSold)
	return format((hasFilter and L["%s Sold Auctions (Filtered)"] or L["%s Sold Auctions"])..":", Theme.GetColor("accent/main"):ColorText(numSold))
end

function private.StateToPostedText(hasFilter, numPosted)
	return format((hasFilter and L["%s Posted Auctions (Filtered)"] or L["%s Posted Auctions"])..":", numPosted)
end

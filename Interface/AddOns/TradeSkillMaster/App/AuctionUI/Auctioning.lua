-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Auctioning = App:Init("AuctionUI.Auctioning")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TempTable = App:From("LibTSMUtil"):Include("BaseType.TempTable")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local Group = App:From("LibTSMTypes"):Include("Group")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local AuctioningSavedSearches = App:From("LibTSMTypes"):Include("SavedSearches.AuctioningSavedSearches")
local Threading = App:From("LibTSMTypes"):Include("Threading")
local AuctionHouse = App:From("LibTSMWoW"):Include("API.AuctionHouse")
local AuctionHouseWrapper = App:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local DefaultUI = App:From("LibTSMWoW"):Include("UI.DefaultUI")
local SoundAlert = App:From("LibTSMWoW"):Include("UI.SoundAlert")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local AuctionScan = App:From("LibTSMService"):Include("AuctionScan")
local GoldTracker = App:From("LibTSMService"):Include("Ledger.GoldTracker")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AuctioningApp = App:From("LibTSMApp"):Include("Auctioning")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local private = {
	manager = nil,
	settings = nil,
	scanContext = {},
	canHandleItemLink = false,
	currentRowQueryUpdateNum = 0,
	existingAuctionsTemp = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("AuctioningUIState")
	:AddStringField("contentPath", "selection")
	:AddDeferredUIElementField("frame", "ViewContainer")
	:AddDeferredUIElementField("selectionFrame", "AuctioningSelection")
	:AddDeferredUIElementField("scanFrame", "BaseFrame")
	:AddDeferredUIElementField("bottomFrame", "BaseFrame")
	:AddDeferredUIElementField("existingAuctionsList", "ExistingAuctionsList")
	:AddOptionalEnumField("scanType", EnumTypes.AUCTIONING_SCAN_TYPE)
	:AddBooleanField("hasLastScan", false)
	:AddOptionalStringField("scanThreadId")
	:AddBooleanField("isScanning", false)
	:AddBooleanField("doneScanning", false)
	:AddDeferredClassField("auctionScan", "AuctionScanManager")
	:AddOptionalNumberField("scanNumItems")
	:AddNumberField("scanProgress", 0)
	:AddOptionalBooleanField("scanIsPaused")
	:AddDeferredClassField("pendingFuture", "Future")
	:AddBooleanField("canStartNewScan", false)
	:AddOptionalBooleanField("pausePending")
	:AddBooleanField("canProcess", false)
	:AddDeferredClassField("currentRowCancellable", "ReactivePublisher")
	:AddOptionalNumberField("currentRowDepositCost")
	:AddOptionalNumberField("currentRowAuctionId")
	:AddDeferredClassField("currentRowQuery", "DatabaseQuery")
	:AddNumberField("currentRowQueryUpdateNum", 0)
	:AddDeferredClassField("statusCancellable", "ReactivePublisher")
	:AddDeferredClassField("postSkipCancellable", "ReactivePublisher")
	:AddOptionalNumberField("statusNumProcessed")
	:AddOptionalNumberField("statusNumConfirmed")
	:AddOptionalNumberField("statusNumFailed")
	:AddOptionalNumberField("statusTotalNum")
	:AddNumberField("playerMoney", 0)
	:AddOptionalNumberField("saleTotal")
	:AddOptionalNumberField("numPosting")
	:AddOptionalNumberField("numSkipping")
	:Commit()

---@event AuctioningAction
---| "ACTION_START_GROUP_POST_SCAN" -> groupIterator: IteratorObject<fun(): number, string>
---| "ACTION_START_GROUP_CANCEL_SCAN" -> groupIterator: IteratorObject<fun(): number, string>
---| "ACTION_START_GROUP_SCAN" -> scanType: EnumValue, groupIterator: IteratorObject<fun(): number, string>
---| "ACTION_START_BAG_POST_SCAN" -> itemIterator: IteratorObject<fun(): string>
---| "ACTION_START_SAVED_SEARCH" -> index: number
---| "ACTION_START_SCAN" -> scanType: EnumValue, scanContext: table
---| "ACTION_SCAN_PROGRESS_UPDATED"
---| "ACTION_SCAN_COMPLETED"
---| "ACTION_STATUS_UPDATED" -> status: number[]
---| "ACTION_POST_SKIP_UPDATED" -> status: number[]
---| "ACTION_TOGGLE_SCAN_PAUSED"
---| "ACTION_PROCESS_AUCTION"
---| "ACTION_FUTURE_DONE" -> value: boolean
---| "ACTION_HANDLE_PROCESS_RESULT" -> success: boolean, canRetry: boolean
---| "ACTION_SKIP_AUCTION"
---| "ACTION_RESCAN"
---| "ACTION_STOP_SCANNING"
---| "ACTION_RESET_STATE"
---| "ACTION_DRAW_BOTTOM_FRAME"
---| "ACTION_UPDATE_EXISTING_AUCTIONS"
---| "ACTION_POSTING_MOVED" -> itemBuyout: number



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Auctioning, function(db)
	private.settings = db:NewView("AuctionUISettings")
		:AddKey("char", "auctionUIContext", "auctioningGroupTree")
		:AddKey("global", "auctionUIContext", "auctioningSelectionDividedContainer")
		:AddKey("global", "auctionUIContext", "auctioningSelectionVerticalDividedContainer")
		:AddKey("global", "auctionUIContext", "auctioningBagScrollingTable")
		:AddKey("global", "auctionUIContext", "auctioningLogScrollingTable")
		:AddKey("global", "auctionUIContext", "auctioningAuctionScrollingTable")
		:AddKey("global", "auctionUIContext", "auctioningTabGroup")
		:AddKey("global", "auctionUIContext", "auctioningPostDividedContainer")
		:AddKey("global", "auctionUIContext", "auctioningPostLogScrollingTable")
		:AddKey("global", "auctioningOptions", "scanCompleteSound")
		:AddKey("global", "auctioningOptions", "confirmCompleteSound")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("AUCTIONING", state, private.ActionHandler)
		:SuppressActionLog("ACTION_SCAN_PROGRESS_UPDATED")
		:AddFrameBuilder(private.GetFrame)

	-- Set up some state publishers
	private.manager:SetStateFromPublisher("doneScanning", state:Publisher([[scanProgress == 1 and not isScanning]]))
	private.manager:SetStateFromPublisher("canProcess", state:Publisher([[pausePending == nil and (doneScanning or scanIsPaused) or false]]))
	state:SetAutoDeferred(true)
	private.manager:ProcessActionFromPublisher("ACTION_DRAW_BOTTOM_FRAME", state:PublisherForKeys("scanFrame", "canProcess", "canStartNewScan"))
	private.manager:ProcessActionFromPublisher("ACTION_UPDATE_EXISTING_AUCTIONS", state:PublisherForKeys("existingAuctionsList", "currentRowQueryUpdateNum"))
	state:SetAutoDeferred(false)
	private.manager:SetStateFromPublisher("playerMoney", GoldTracker.MoneyPublisher())
	private.canHandleItemLink = false -- Explicitly set private.canHandleItemLink at least once to appease the linter
	private.manager:AddCancellable(state:Publisher([[selectionFrame or canStartNewScan]])
		:AssignToTableKey(private, "canHandleItemLink")
	)

	-- Set up some event handlers
	DefaultUI.RegisterAuctionHouseVisibleCallback(function() private.manager:ProcessAction("ACTION_STOP_SCANNING") end, false)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the Browse frame.
---@return ViewContainer
function Auctioning.GetFrame()
	return private.manager:BuildFrame()
end

---Handles an item being linked.
---@param name string The item name
---@param itemLink string The item link
---@return boolean
function Auctioning.HandleItemLinked(name, itemLink)
	if not private.canHandleItemLink or not AuctionScan.AcquireLock(L["Auctioning"]) then
		return false
	end
	wipe(private.scanContext)
	private.scanContext.isItems = true
	local itemString = ItemString.Get(itemLink)
	assert(itemString)
	tinsert(private.scanContext, Group.TranslateItemString(itemString))
	private.manager:ProcessAction("ACTION_START_SCAN", EnumTypes.AUCTIONING_SCAN_TYPE.POST, private.scanContext)
	return true
end



-- ============================================================================
-- Auctioning UI
-- ============================================================================

function private.GetFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning")
	if not state.hasLastScan then
		state.contentPath = "selection"
	end
	return UIElements.New("ViewContainer", "auctioning")
		:SetContext(state)
		:SetNavCallback(private.GetContentFrame)
		:BindElement(state, "frame")
		:AddPath("selection")
		:AddPath("postScan")
		:AddPath("cancelScan")
		:SetPath(state.contentPath)
end

function private.GetContentFrame(frame, path)
	local state = frame:GetContext() ---@type AuctioningUIState
	state.contentPath = path
	if path == "selection" then
		return private.GetSelectionFrame(state)
	elseif path == "postScan" then
		return private.GetPostScanFrame(state)
	elseif path == "cancelScan" then
		return private.GetCancelScanFrame(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state AuctioningUIState
function private.GetSelectionFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "selection")
	return UIElements.New("AuctioningSelection", "selection")
		:Configure(private.settings --[[@as AuctioningSelectionSettings]], AuctioningApp.CreatePostBagsQuery())
		:SetManager(private.manager)
		:SetAction("OnStartGroupPostScan", "ACTION_START_GROUP_POST_SCAN")
		:SetAction("OnStartBagPostScan", "ACTION_START_BAG_POST_SCAN")
		:SetAction("OnStartGroupCancelScan", "ACTION_START_GROUP_CANCEL_SCAN")
		:SetAction("OnStartSavedSearch", "ACTION_START_SAVED_SEARCH")
		:BindElement(state, "selectionFrame")
end

---@param state AuctioningUIState
function private.GetPostScanFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "postScan")
	local actionDisabledPublisher = state:Publisher([[not canProcess or not canStartNewScan]])
		:Share()
	return UIElements.New("BaseFrame", "scan")
		:SetLayout("VERTICAL")
		:BindElement(state, "scanFrame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetMargin(4)
			:SetHeight(30)
			:AddChild(UIElements.New("ExitScanButton", "back")
				:SetMargin(0, 8, 0, 0)
				:SetAction("OnClick", "ACTION_STOP_SCANNING")
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetRoundedBackgroundColor("container/low")
				:SetBorderColor("outline/variant")
				:AddChild(UIElements.New("Spacer", "leftSpacer"))
				:AddChild(UIElements.New("Text", "postingLabel")
					:SetWidth("AUTO")
					:SetMargin(0, 4, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Posting"]..":")
				)
				:AddChild(UIElements.New("Text", "postingText")
					:SetWidth("AUTO")
					:SetMargin(0, 24, 0, 0)
					:SetFont("BODY_SMALL")
					:SetText(state:Publisher("numPosting"):CoalesceNil(0):ToStringFormat(L["%d Items"]))
				)
				:AddChild(UIElements.New("Text", "skippingLabel")
					:SetWidth("AUTO")
					:SetMargin(0, 4, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Skipping"]..":")
				)
				:AddChild(UIElements.New("Text", "skippingText")
					:SetWidth("AUTO")
					:SetMargin(0, 24, 0, 0)
					:SetFont("BODY_SMALL")
					:SetText(state:Publisher("numSkipping"):CoalesceNil(0):ToStringFormat(L["%d Items"]))
				)
				:AddChild(UIElements.New("Text", "totalLabel")
					:SetWidth("AUTO")
					:SetMargin(0, 4, 0, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Potential Sale Total"]..":")
				)
				:AddChild(UIElements.New("Text", "totalText")
					:SetWidth("AUTO")
					:SetMargin(0, 24, 0, 0)
					:SetFont("BODY_SMALL")
					:SetText(state:Publisher("saleTotal"):MapNonNil(Money.ToStringForUI):CoalesceNil("---"))
				)
				:AddChild(UIElements.New("Spacer", "rightSpacer"))
			)
		)
		:AddChild(UIElements.New("DividedContainer", "content")
			:SetMinWidth(200, 200)
			:SetSettingsContext(private.settings, "auctioningPostDividedContainer")
			:HideDivider()
			:SetLeftChild(UIElements.New("BaseFrame", "left")
				:SetLayout("VERTICAL")
				:SetMargin(4)
				:AddChild(UIElements.New("ListContainer", "log")
					:AddChild(UIElements.New("AuctioningLogScrollTable", "table")
						:SetSettings(private.settings, "auctioningPostLogScrollingTable")
						:SetQuery(AuctioningApp.CreateLogQuery())
						:SetSelectedIndex(state:Publisher("currentRowAuctionId"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "progress")
					:SetLayout("HORIZONTAL")
					:SetHeight(28)
					:SetMargin(0, 0, 8, 0)
					:AddChild(UIElements.New("ScanPauseResumeButton", "pauseResumeBtn")
						:SetDisabled(state:Publisher([[pausePending ~= nil or doneScanning or (scanIsPaused and statusNumProcessed ~= statusNumConfirmed) or statusNumProcessed == statusTotalNum]]))
						:SetAction("OnClick", "ACTION_TOGGLE_SCAN_PAUSED")
					)
					:AddChild(UIElements.New("ProgressBar", "progressBar")
						:SetTextColor("on/surface/low")
						:SetText(state:PublisherForFunctionWithKeys(private.StateToProgressText, "canProcess", "scanType", "pausePending", "scanIsPaused", "scanNumItems", "statusNumConfirmed", "statusTotalNum", "statusNumProcessed"))
						:SetProgress(state:Publisher([[(not canProcess and scanProgress) or (statusTotalNum > 0 and (statusNumProcessed / statusTotalNum)) or 1]]))
						:SetProgressIconHidden(state:Publisher([[canProcess and (statusNumConfirmed == statusTotalNum or (statusNumProcessed ~= statusTotalNum and statusNumProcessed == statusNumConfirmed))]]))
					)
				)
			)
			:SetRightChild(UIElements.New("BaseFrame", "right")
				:SetLayout("VERTICAL")
				:SetMargin(4)
				:AddChild(UIElements.New("BaseFrame", "details")
					:SetLayout("VERTICAL")
					:SetBackgroundColor("container/low")
					:SetBorderColor("outline/variant")
					:SetPadding(1)
					:AddChild(UIElements.New("AuctioningPostDetails", "content")
						:Configure(AuctioningApp.ChangePostDetail)
						:SetAuctionRow(state:PublisherForKeys("currentRowQuery", "currentRowQueryUpdateNum"):Map("currentRowQuery"):IgnoreNil())
					)
					:AddChild(UIElements.New("ExistingAuctionsList", "list")
						:SetMargin(0, 0, 8, 0)
						:SetDropPriceFunction(AuctioningApp.GetUndercutPostPrice)
						:SetAction("OnPostingMoved", "ACTION_POSTING_MOVED")
						:BindElement(state, "existingAuctionsList")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "bottom")
					:SetLayout("HORIZONTAL")
					:SetHeight(28)
					:SetMargin(0, 0, 8, 0)
					:BindElement(state, "bottomFrame")
					:AddChild(UIElements.New("MediumSecondaryActionButton", "skipBtn")
						:SetMargin(0, 8, 0, 0)
						:SetText(L["Skip"])
						:DisableClickCooldown()
						:SetDisabled(state:Publisher([[not canProcess or statusNumProcessed == statusTotalNum]]))
						:SetShown(actionDisabledPublisher)
						:SetAction("OnClick", "ACTION_SKIP_AUCTION")
					)
					:AddChild(UIElements.NewNamed("MediumPrimaryActionButton", "processBtn", "TSMAuctioningBtn")
						:SetText(L["Post"])
						:DisableClickCooldown()
						:SetDisabled(state:Publisher([[(not canProcess or statusNumProcessed == statusTotalNum or (currentRowDepositCost and currentRowDepositCost > playerMoney) or pendingFuture) and true or false]]))
						:SetShown(actionDisabledPublisher)
						:SetAction("OnClick", "ACTION_PROCESS_AUCTION")
					)
					:AddChild(UIElements.New("MediumSecondaryActionButton", "rescanBtn")
						:SetText(L["Rescan"])
						:SetShown(state:Publisher([[canProcess and canStartNewScan]]))
						:SetAction("OnClick", "ACTION_RESCAN")
					)
				)
			)
		)
		:AddCancellable(actionDisabledPublisher:EndShare())
end

---@param state AuctioningUIState
function private.GetCancelScanFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "cancelScan")
	local actionDisabledPublisher = state:Publisher([[not canProcess or not canStartNewScan]])
		:Share()
	return UIElements.New("BaseFrame", "scan")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:BindElement(state, "scanFrame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:AddChild(UIElements.New("ExitScanButton", "back")
				:SetMargin(0, 8, 0, 0)
				:SetAction("OnClick", "ACTION_STOP_SCANNING")
			)
			:AddChild(UIElements.New("AuctioningCancelDetails", "details")
				:SetAuctionRow(state:PublisherForKeys("currentRowQuery", "currentRowQueryUpdateNum"):Map("currentRowQuery"):IgnoreNil())
			)
		)
		:AddChild(UIElements.New("SegmentedTabGroup", "tabs")
			:SetMargin(0, 0, 8, 0)
			:SetContext(state)
			:SetNavCallback(private.ScanNavCallback)
			:AddPath(L["Auctioning Log"], true)
			:AddPath(L["All Auctions"])
		)
		:AddChild(UIElements.New("BaseFrame", "bottom")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:BindElement(state, "bottomFrame")
			:AddChild(UIElements.New("ScanPauseResumeButton", "pauseResumeBtn")
				:SetDisabled(state:Publisher([[pausePending ~= nil or doneScanning or (scanIsPaused and statusNumProcessed ~= statusNumConfirmed) or statusNumProcessed == statusTotalNum]]))
				:SetAction("OnClick", "ACTION_TOGGLE_SCAN_PAUSED")
			)
			:AddChild(UIElements.New("ProgressBar", "progressBar")
				:SetMargin(0, 8, 0, 0)
				:SetTextColor("on/surface/low")
				:SetText(state:PublisherForFunctionWithKeys(private.StateToProgressText, "canProcess", "scanType", "pausePending", "scanIsPaused", "scanNumItems", "statusNumConfirmed", "statusTotalNum", "statusNumProcessed"))
				:SetProgress(state:Publisher([[(not canProcess and scanProgress) or (statusTotalNum > 0 and (statusNumProcessed / statusTotalNum)) or 1]]))
				:SetProgressIconHidden(state:Publisher([[canProcess and (statusNumConfirmed == statusTotalNum or (statusNumProcessed ~= statusTotalNum and statusNumProcessed == statusNumConfirmed))]]))
			)
			:AddChild(UIElements.New("MediumSecondaryActionButton", "skipBtn")
				:SetWidth(160)
				:SetMargin(0, 8, 0, 0)
				:SetText(L["Skip"])
				:DisableClickCooldown()
				:SetDisabled(state:Publisher([[not canProcess or statusNumProcessed == statusTotalNum]]))
				:SetShown(actionDisabledPublisher)
				:SetAction("OnClick", "ACTION_SKIP_AUCTION")
			)
			:AddChild(UIElements.NewNamed("MediumPrimaryActionButton", "processBtn", "TSMAuctioningBtn")
				:SetWidth(160)
				:DisableClickCooldown()
				:SetText(GlobalStrings.Get("CANCEL"))
				:SetDisabled(state:Publisher([[(not canProcess or statusNumProcessed == statusTotalNum or pendingFuture) and true or false]]))
				:SetShown(actionDisabledPublisher)
				:SetAction("OnClick", "ACTION_PROCESS_AUCTION")
			)
			:AddChild(UIElements.New("MediumSecondaryActionButton", "rescanBtn")
				:SetWidth(160)
				:SetText(L["Rescan"])
				:SetShown(state:Publisher([[canProcess and canStartNewScan]]))
				:SetAction("OnClick", "ACTION_RESCAN")
			)
		)
		:AddCancellable(actionDisabledPublisher:EndShare())
end

function private.ScanNavCallback(frame, path)
	local state = frame:GetContext() ---@type AuctioningUIState
	if path == L["Auctioning Log"] then
		UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "cancelScan", "log")
		return UIElements.New("ListContainer", "logFrame")
			:AddChild(UIElements.New("AuctioningLogScrollTable", "log")
				:SetSettings(private.settings, "auctioningLogScrollingTable")
				:SetQuery(AuctioningApp.CreateLogQuery())
				:SetSelectedIndex(state:Publisher("currentRowAuctionId"))
			)
	elseif path == L["All Auctions"] then
		UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "cancelScan", "auctions")
		return UIElements.New("ListContainer", "auctionsFrame")
			:AddChild(UIElements.New("AuctionScrollTable", "auctions")
				:SetSettings(private.settings, "auctioningAuctionScrollingTable")
				:SetCreatedGroupName(L["Auctioning"].." - "..L["All Auctions"])
				:SetBrowseResultsVisible(true)
				:SetMarketValueFunction(private.MarketValueFunction)
				:SetIsPlayerFunction(PlayerInfo.AuctionOwnerIsPlayer)
				:SetAuctionScan(state.auctionScan)
			)
	else
		error("Unexpected path: "..tostring(path))
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<AuctioningUIState>
---@param state AuctioningUIState
---@param action AuctioningAction
---@param ... params<AuctioningAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_START_GROUP_POST_SCAN" then
		local groupIterator = ...
		return manager:ProcessAction("ACTION_START_GROUP_SCAN", EnumTypes.AUCTIONING_SCAN_TYPE.POST, groupIterator)
	elseif action == "ACTION_START_GROUP_CANCEL_SCAN" then
		local groupIterator = ...
		return manager:ProcessAction("ACTION_START_GROUP_SCAN", EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL, groupIterator)
	elseif action == "ACTION_START_GROUP_SCAN" then
		local scanType, groupIterator = ...
		local scanContext = private.PrepareGroupScan(groupIterator)
		if scanContext then
			return manager:ProcessAction("ACTION_START_SCAN", scanType, scanContext)
		end
	elseif action == "ACTION_START_BAG_POST_SCAN" then
		local itemIterator = ...
		local scanContext = private.PreparePostBagsScan(itemIterator)
		if scanContext then
			return manager:ProcessAction("ACTION_START_SCAN", EnumTypes.AUCTIONING_SCAN_TYPE.POST, scanContext)
		end
	elseif action == "ACTION_START_SAVED_SEARCH" then
		local index = ...
		local scanType, scanContext = private.PrepareSearchListScan(index)
		if scanType then
			return manager:ProcessAction("ACTION_START_SCAN", scanType, scanContext)
		end
	elseif action == "ACTION_START_SCAN" then
		local scanType, scanContext = ...
		if state.scanFrame then
			-- Switch back to the selection frame first
			state.frame:SetPath("selection", true)
		end
		if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
			state.frame:SetPath("postScan", true)
		elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
			state.frame:SetPath("cancelScan", true)
		else
			error("Invalid scan type: "..tostring(scanType))
		end
		manager:ProcessAction("ACTION_RESET_STATE")
		state.playerMoney = Currency.GetMoney()
		state.scanType = scanType
		state.hasLastScan = true
		local currentRowPublisher, statusPublisher, postSkipPublisher = nil, nil, nil
		state.scanThreadId, currentRowPublisher, statusPublisher, postSkipPublisher = AuctioningApp.PrepareScan(scanType)
		currentRowPublisher = currentRowPublisher:Share()
		if state.scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
			currentRowPublisher
				:MapNonNil("GetFirstResult()", "depositCost")
				:AssignToTableKey(state, "currentRowDepositCost")
		elseif state.scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
			state.currentRowDepositCost = nil
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		state.currentRowCancellable = currentRowPublisher
			:MapNonNil("GetFirstResult()", "auctionId")
			:AssignToTableKey(state, "currentRowAuctionId")
			:AssignToTableKey(state, "currentRowQuery")
			:Map(private.GetNextCurrentRowQueryUpdateNum)
			:AssignToTableKey(state, "currentRowQueryUpdateNum")
			:EndShare()
			:Stored()
		state.statusCancellable = statusPublisher
			:CallFunction(manager:CallbackToProcessAction("ACTION_STATUS_UPDATED"))
			:Stored()
		if postSkipPublisher then
			state.postSkipCancellable = postSkipPublisher
				:CallFunction(manager:CallbackToProcessAction("ACTION_POST_SKIP_UPDATED"))
				:Stored()
		end
		state.auctionScan = AuctionScan.GetManager()
			:SetResolveSellers(App.IsVanillaClassic() or App.IsBCClassic())
			:SetUIManager(manager)
			:SetAction("OnProgressUpdate", "ACTION_SCAN_PROGRESS_UPDATED")
			:BindNumAuctions(state, "scanNumItems")
		Threading.SetCallback(state.scanThreadId, manager:CallbackToProcessAction("ACTION_SCAN_COMPLETED"))
		Threading.Start(state.scanThreadId, state.auctionScan, scanContext)
		state.isScanning = true
	elseif action == "ACTION_SCAN_PROGRESS_UPDATED" then
		local scanProgress, scanIsPaused = state.auctionScan:GetProgress()
		if state.pausePending == scanIsPaused then
			state.pausePending = nil
		end
		if scanIsPaused and state.pausePending == nil then
			state.isScanning = false
		end
		state.scanProgress = scanProgress
		state.scanIsPaused = scanIsPaused
	elseif action == "ACTION_SCAN_COMPLETED" then
		AuctionScan.ReleaseLock(L["Auctioning"])
		state.scanThreadId = nil
		SoundAlert.Play(private.settings.scanCompleteSound)
		state.scanProgress = 1
		state.isScanning = false
		if state.statusTotalNum == 0 then
			state.canStartNewScan = true
		end
	elseif action == "ACTION_STATUS_UPDATED" then
		local numProcessed, numConfirmed, numFailed, totalNum, saleTotal = TempTable.UnpackAndRelease(...)
		state.statusNumProcessed = numProcessed
		state.statusNumConfirmed = numConfirmed
		state.statusNumFailed = numFailed
		state.statusTotalNum = totalNum
		state.saleTotal = saleTotal
	elseif action == "ACTION_POST_SKIP_UPDATED" then
		local numPosting, numSkipping = TempTable.UnpackAndRelease(...)
		state.numPosting = numPosting
		state.numSkipping = numSkipping
	elseif action == "ACTION_TOGGLE_SCAN_PAUSED" then
		assert(state.pausePending == nil)
		state.pausePending = state.isScanning
		state.auctionScan:SetPaused(state.pausePending)
		state.isScanning = true
	elseif action == "ACTION_PROCESS_AUCTION" then
		if state.existingAuctionsList and state.existingAuctionsList:IsDragging() then
			return
		end
		state.frame:GetBaseElement():HideDialog()
		assert(state.scanType)
		local result, canRetry = AuctioningApp.DoProcess(state.scanType)
		if result then
			manager:ManageFuture("pendingFuture", result, "ACTION_FUTURE_DONE")
		else
			-- We failed to post / cancel
			return manager:ProcessAction("ACTION_HANDLE_PROCESS_RESULT", false, canRetry)
		end
	elseif action == "ACTION_FUTURE_DONE" then
		local value = ...
		return manager:ProcessAction("ACTION_HANDLE_PROCESS_RESULT", value == true, value == false)
	elseif action == "ACTION_HANDLE_PROCESS_RESULT" then
		local success, canRetry = ...
		assert(state.scanType)
		local isDone = AuctioningApp.HandleConfirm(state.scanType, success, canRetry)
		if isDone and state.scanIsPaused then
			-- Unpause the scan now that we're done
			assert(state.pausePending == nil)
			state.pausePending = false
			state.auctionScan:SetPaused(false)
			state.isScanning = true
		elseif isDone then
			state.canStartNewScan = true
			AuctionHouseWrapper.AutoQueryOwnedAuctions()
			SoundAlert.Play(private.settings.confirmCompleteSound)
		end
	elseif action == "ACTION_SKIP_AUCTION" then
		assert(state.scanType)
		AuctioningApp.DoSkip(state.scanType)
		local isDone = state.statusNumConfirmed == state.statusTotalNum and state.statusNumFailed == 0
		if isDone and state.scanIsPaused then
			-- Unpause the scan now that we're done
			assert(state.pausePending == nil)
			state.pausePending = false
			state.auctionScan:SetPaused(false)
			state.isScanning = true
		elseif isDone then
			state.canStartNewScan = true
			AuctionHouseWrapper.AutoQueryOwnedAuctions()
			SoundAlert.Play(private.settings.confirmCompleteSound)
		end
	elseif action == "ACTION_RESCAN" then
		if not state.scanFrame or not AuctionScan.AcquireLock(L["Auctioning"]) then
			return
		end
		return manager:ProcessAction("ACTION_START_SCAN", state.scanType, private.scanContext)
	elseif action == "ACTION_STOP_SCANNING" then
		AuctionHouse.ClearSellItem()
		if state.scanFrame then
			state.frame:SetPath("selection", true)
		end
		manager:ProcessAction("ACTION_RESET_STATE")
		AuctionScan.ReleaseLock(L["Auctioning"])
	elseif action == "ACTION_RESET_STATE" then
		if state.currentRowCancellable then
			state.currentRowCancellable:Cancel()
			state.currentRowCancellable = nil
		end
		if state.statusCancellable then
			state.statusCancellable:Cancel()
			state.statusCancellable = nil
		end
		if state.postSkipCancellable then
			state.postSkipCancellable:Cancel()
			state.postSkipCancellable = nil
		end
		AuctioningApp.Reset()
		if state.pendingFuture then
			manager:CancelFuture("pendingFuture")
		end
		if state.scanThreadId then
			Threading.Kill(state.scanThreadId)
			state.scanThreadId = nil
		end
		if state.auctionScan then
			state.auctionScan:Release()
			state.auctionScan = nil
		end
		state.hasLastScan = false
		state.scanNumItems = nil
		state.scanProgress = 0
		state.scanIsPaused = nil
		state.pausePending = nil
		state.isScanning = false
		state.scanType = nil
		state.canStartNewScan = false
	elseif action == "ACTION_DRAW_BOTTOM_FRAME" then
		if not state.bottomFrame then
			return
		end
		state.bottomFrame:Draw()
	elseif action == "ACTION_UPDATE_EXISTING_AUCTIONS" then
		if not state.existingAuctionsList then
			return
		end
		wipe(private.existingAuctionsTemp)
		local minPrice, normalPrice, maxPrice = nil, nil, nil
		if state.auctionScan and state.currentRowQuery then
			minPrice, normalPrice, maxPrice = AuctioningApp.GetCurrentPostAuctions(state.auctionScan, private.existingAuctionsTemp)
		end
		state.existingAuctionsList:SetData(private.existingAuctionsTemp, minPrice, normalPrice, maxPrice)
	elseif action == "ACTION_POSTING_MOVED" then
		local itemBuyout = ...
		AuctioningApp.ChangePostDetail("itemBuyout", itemBuyout)
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param groupIterator IteratorObject<fun(): number, string>
function private.PrepareGroupScan(groupIterator)
	if not AuctionScan.AcquireLock(L["Auctioning"]) then
		groupIterator:Release()
		return nil
	end
	wipe(private.scanContext)
	for _, groupPath in groupIterator do
		tinsert(private.scanContext, groupPath)
	end
	return private.scanContext
end

---@param itemIterator IteratorObject<fun(): string>
function private.PreparePostBagsScan(itemIterator)
	if not AuctionScan.AcquireLock(L["Auctioning"]) then
		itemIterator:Release()
		return nil
	end
	wipe(private.scanContext)
	private.scanContext.isItems = true
	for autoBaseItemString in itemIterator do
		tinsert(private.scanContext, autoBaseItemString)
	end
	return private.scanContext
end

function private.PrepareSearchListScan(index)
	if not AuctionScan.AcquireLock(L["Auctioning"]) then
		return nil, nil
	end
	wipe(private.scanContext)
	local searchType = AuctioningSavedSearches.GetInfo(index, private.scanContext)
	local scanType = nil
	if searchType == AuctioningSavedSearches.SEARCH_TYPE.POST_ITEMS then
		private.scanContext.isItems = true
		scanType = EnumTypes.AUCTIONING_SCAN_TYPE.POST
	elseif searchType == AuctioningSavedSearches.SEARCH_TYPE.POST_GROUPS then
		scanType = EnumTypes.AUCTIONING_SCAN_TYPE.POST
	elseif searchType == AuctioningSavedSearches.SEARCH_TYPE.CANCEL_GROUPS then
		scanType = EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL
	else
		error("Unknown search type: "..tostring(searchType))
	end
	return scanType, private.scanContext
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToProgressText(canProcess, scanType, pausePending, scanIsPaused, scanNumItems, statusNumConfirmed, statusTotalNum, statusNumProcessed)
	if not canProcess then
		-- We're scanning or pausing
		if pausePending ~= nil then
			return scanIsPaused and L["Resuming Scan..."] or L["Pausing Scan..."]
		else
			return scanNumItems and format(L["Scanning (%d Items)"], scanNumItems) or L["Starting Scan..."]
		end
	elseif statusNumConfirmed == statusTotalNum then
		-- We're completely done
		if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
			return L["Done Posting"]
		elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
			return L["Done Canceling"]
		else
			error("Invalid scan type: "..tostring(scanType))
		end
	elseif statusNumProcessed == statusTotalNum then
		-- We're done processing and just confirming
		return format(L["Confirming %d / %d"], statusNumConfirmed + 1, statusTotalNum)
	else
		-- We're done (or paused) scanning so start Posting/Canceling
		local progressFmtStr = scanIsPaused and (L["Scan Paused"].." | ") or ""
		if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
			progressFmtStr = progressFmtStr..L["Posting %d / %d"]
		elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
			progressFmtStr = progressFmtStr..L["Canceling %d / %d"]
		else
			error("Invalid scan type: "..tostring(scanType))
		end
		if statusNumProcessed == statusNumConfirmed then
			return format(progressFmtStr, statusNumProcessed + 1, statusTotalNum)
		else
			return format(progressFmtStr.." ("..L["Confirming %d / %d"]..")", statusNumProcessed + 1, statusTotalNum, statusNumConfirmed + 1, statusTotalNum)
		end
	end
end

function private.MarketValueFunction(row)
	local value = CustomString.GetValue("dbmarket", row:GetItemString() or row:GetBaseItemString())
	return value
end

function private.GetNextCurrentRowQueryUpdateNum()
	private.currentRowQueryUpdateNum = private.currentRowQueryUpdateNum + 1
	return private.currentRowQueryUpdateNum
end

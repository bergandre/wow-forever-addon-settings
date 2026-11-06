-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local PostScan = LibTSMApp:InitInternal("Auctioning.PostScan")
local AuctioningLog = LibTSMApp:Include("Auctioning.Log")
local Util = LibTSMApp:Include("Auctioning.Util")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local Reactive = LibTSMApp:From("LibTSMReactive"):Include("Reactive")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMApp:From("LibTSMTypes"):Include("GroupOperation")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Operation = LibTSMApp:From("LibTSMTypes"):Include("Operation")
local AuctioningSavedSearches = LibTSMApp:From("LibTSMTypes"):Include("SavedSearches.AuctioningSavedSearches")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local AuctionHouse = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouse")
local AuctionHouseWrapper = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local Container = LibTSMApp:From("LibTSMWoW"):Include("API.Container")
local DelayTimer = LibTSMApp:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local DefaultUI = LibTSMApp:From("LibTSMWoW"):Include("UI.DefaultUI")
local AuctionHouseUIUtils = LibTSMApp:From("LibTSMUI"):Include("AuctionHouse.AuctionHouseUIUtils")
local private = {
	state = nil,
	settings = nil,
	scanThreadId = nil,
	queueDB = nil,
	nextQueueAuctionId = -1,
	bagDB = nil,
	itemList = {},
	operationDB = nil,
	subRowsTemp = {},
	groupsQuery = nil, ---@diagnostic disable-line: tsm-private
	operationsQuery = nil, ---@diagnostic disable-line: tsm-private
	operationsChangedTimer = nil,
	currentRowQuery = nil,
	statusQuery = nil,
	bagCountsTemp = {},
	usedSlotsTemp = {},
	lowestAuctionTemp = {}, ---@type AuctioningOperationLowestAuction
	bagRemoveTemp = {},
}
local MAX_COMMODITY_STACKS_PER_AUCTION = 40
local COPPER_PER_SILVER = 100
local DEPOSIT_COST_ARG_FIELDS = { "itemString", "postTime", "stackSize", "bid", "buyout" }
local STATE_SCHEMA = Reactive.CreateStateSchema("AuctioningPostScanState")
	:AddNumberField("numPosting", 0)
	:AddNumberField("numSkipping", 0)
	:Commit()


-- ============================================================================
-- Module Loading
-- ============================================================================

PostScan:OnModuleLoad(function()
	private.state = STATE_SCHEMA:CreateState()
	private.operationsChangedTimer = DelayTimer.New("POST_SCAN_OPERATIONS_CHANGED", private.UpdateOperationDB)
	BagTracking.RegisterQuantityCallback(private.UpdateOperationDB)
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.UpdateOperationDB, true)
	private.operationDB = Database.NewSchema("AUCTIONING_OPERATIONS")
		:AddUniqueStringField("autoBaseItemString")
		:AddStringField("firstOperation")
		:Commit()
	private.scanThreadId = Threading.New("POST_SCAN", private.ScanThread)
	private.queueDB = Database.NewSchema("AUCTIONING_POST_QUEUE")
		:AddNumberField("auctionId")
		:AddStringField("itemString")
		:AddStringField("operationName")
		:AddNumberField("bid")
		:AddNumberField("buyout")
		:AddNumberField("itemBid")
		:AddNumberField("itemBuyout")
		:AddNumberField("stackSize")
		:AddNumberField("numStacks")
		:AddNumberField("postTime")
		:AddNumberField("numProcessed")
		:AddNumberField("numConfirmed")
		:AddNumberField("numFailed")
		:AddNumberField("minPrice")
		:AddNumberField("normalPrice")
		:AddNumberField("maxPrice")
		:AddIndex("auctionId")
		:AddIndex("itemString")
		:Commit()
	-- We maintain our own bag database rather than using the one in BagTracking since we need to be able to remove items
	-- as they are posted, without waiting for bag update events, and control when our DB updates.
	private.bagDB = Database.NewSchema("AUCTIONING_POST_BAGS")
		:AddStringField("itemString")
		:AddNumberField("quantity")
		:AddUniqueNumberField("slotId")
		:AddIndex("itemString")
		:AddIndex("slotId")
		:Commit()
	-- Create our queries
	private.currentRowQuery = private.queueDB:NewOwnedQuery()
		:LessThan("numProcessed", Database.OtherFieldQueryParam("numStacks"))
		:OrderBy("auctionId", false)
		:VirtualField("depositCost", "number", private.DepositCost, DEPOSIT_COST_ARG_FIELDS)
	private.statusQuery = private.queueDB:NewOwnedQuery()
end)

AddonSettings.RegisterOnLoad(PostScan, function(db)
	private.settings = db:NewView("PostScanSettings")
		:AddKey("global", "auctioningOptions", "disableInvalidMsg")
		:Commit()
	-- Create a groups and operations query just to register for updates
	private.groupsQuery = GroupOperation.CreateQuery()
		:SetUpdateCallback(private.OnGroupsOperationsChanged)
	private.operationsQuery = Operation.NewQuery()
		:SetUpdateCallback(private.OnGroupsOperationsChanged)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function PostScan.CreateBagsQuery()
	return BagTracking.CreateQueryBagsAuctionable()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:VirtualField("name", "string", ItemInfo.GetName, "autoBaseItemString", "")
		:VirtualField("groupPath", "string", Group.GetPathByItem, "itemString", "")
		:Distinct("autoBaseItemString")
		:LeftJoin(private.operationDB, "autoBaseItemString")
end

---Gets the scan thread ID.
---@return string
function PostScan.GetThreadId()
	return private.scanThreadId
end

function PostScan.CurrentRowPublisher()
	return private.currentRowQuery:Publisher()
end

function PostScan.StatusQueryPublisher()
	return private.statusQuery:Publisher()
		:Map(private.StatusQueryToQueueStatus)
end

function PostScan.NumPostSkipPublisher()
	return private.state:PublisherForKeys("numPosting", "numSkipping")
		:Map(private.NumPostSkipAsTempTable)
end

---Processes the current row.
---@return Future? future
---@return boolean canRetry
function PostScan.DoProcess()
	local result = nil
	local uuid, itemString, stackSize, bid, buyout, itemBuyout, postTime, numProcessed, numStacks, auctionId = private.currentRowQuery:GetFirstResultWithUUID("itemString", "stackSize", "bid", "buyout", "itemBuyout", "postTime", "numProcessed", "numStacks", "auctionId")
	assert(uuid)
	local slotId, canRetry = private.GetPostBagSlot(itemString, stackSize)
	if slotId then
		local bagQuantity = Container.GetStackCount(slotId)
		Log.Info("Posting %s x %d from %d (%d)", itemString, stackSize, slotId, bagQuantity or -1)
		if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
			result = AuctionHouseWrapper.PostAuction(slotId, postTime, stackSize, 1, bid, buyout)
		else
			result = AuctionHouseWrapper.PostAuction(slotId, postTime, stackSize, 1, bid / stackSize, itemBuyout)
		end
		if not result then
			Log.Err("Failed to post (%s, %d)", itemString, slotId)
		end
	else
		-- We couldn't find this item, so mark this post as failed and we'll try again later
		result = nil
		if not canRetry then
			ChatMessage.PrintfUser(L["Failed to post %sx%d as the item no longer exists in your bags."], ItemInfo.GetLink(itemString), stackSize)
		end
	end
	if result then
		if numProcessed + 1 == numStacks then
			-- Update the log
			AuctioningLog.UpdateRowByIndex(auctionId, "state", AuctioningLog.STATE.POSTED)
		end
	end
	private.queueDB:UpdateRow(uuid, "numProcessed", numProcessed + 1)
	return result, canRetry
end

function PostScan.DoSkip()
	local uuid, auctionId, numStacks = private.currentRowQuery:GetFirstResultWithUUID("auctionId", "numStacks")
	assert(uuid)
	local updates = TempTable.Acquire()
	updates.numProcessed = numStacks
	updates.numConfirmed = numStacks
	private.queueDB:UpdateRow(uuid, updates)
	TempTable.Release(updates)
	-- Update the log
	AuctioningLog.UpdateRowByIndex(auctionId, "state", AuctioningLog.STATE.SKIPPED)
end

---Handles confirmation of the previous post.
---@param success boolean Whether the previous post was successful
---@param canRetry boolean Whether or not the post can be retried if it failed
function PostScan.HandleConfirm(success, canRetry)
	local uuid, numFailed, numConfirmed = private.queueDB:NewAutoReleaseQuery()
		:LessThan("numConfirmed", Database.OtherFieldQueryParam("numProcessed"))
		:OrderBy("auctionId", true)
		:GetFirstResultWithUUID("numFailed", "numConfirmed")
	if not uuid then
		-- We may have posted something outside of TSM
		return
	end
	local updates = TempTable.Acquire()
	updates.numConfirmed = numConfirmed + 1
	if canRetry then
		assert(not success)
		updates.numFailed = numFailed + 1
	end
	private.queueDB:UpdateRow(uuid, updates)
	TempTable.Release(updates)
end

---Gets the scan queue status.
---@return boolean isDone
---@return number numFailed
function PostScan.GetQueueStatus()
	local _, numConfirmed, numFailed, totalNum = Util.GetQueueStatus(private.statusQuery)
	local isDone = numConfirmed == totalNum
	return isDone, numFailed
end

---Gets the existing auctions for the item of the current row, including the pending post.
---@param auctionScan AuctionScanManager The auction scan manager
---@param result ExistingAuctionsList.Entry[] The table to store the result in (sorted by unit price)
---@return number? minPrice
---@return number? normalPrice
---@return number? maxPrice
function PostScan.GetCurrentRowAuctions(auctionScan, result)
	local itemString, operationName, itemBuyout, stackSize, numStacks, numProcessed, minPrice, normalPrice, maxPrice = private.currentRowQuery:GetFirstResult("itemString", "operationName", "itemBuyout", "stackSize", "numStacks", "numProcessed", "minPrice", "normalPrice", "maxPrice")
	if not itemString then
		return nil, nil, nil
	end
	local operationSettings = Operation.GetSettings("Auctioning", operationName)
	for _, query in auctionScan:QueryIterator() do
		for _, subRow in query:ItemSubRowIterator(itemString) do
			local _, subRowItemBuyout = subRow:GetBuyouts()
			local quantity, numAuctions = subRow:GetQuantities()
			local timeLeft = subRow:GetListingInfo()
			local isIgnored = AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, subRowItemBuyout, quantity, timeLeft)
			private.AddExistingAuction(result, subRowItemBuyout, quantity * numAuctions, isIgnored, false)
		end
	end
	private.AddExistingAuction(result, itemBuyout, stackSize * (numStacks - numProcessed), false, true)
	sort(result, private.ExistingAuctionSortHelper)
	return minPrice, normalPrice, maxPrice
end

---Gets the item buyout the current row would have if it undercut an existing auction.
---@param unitPrice number The unit price of the auction to undercut
---@return number
function PostScan.GetUndercutPrice(unitPrice)
	local itemString, operationName = private.currentRowQuery:GetFirstResult("itemString", "operationName")
	assert(itemString)
	local undercut = AuctioningOperation.GetItemUndercut(itemString, Operation.GetSettings("Auctioning", operationName)) or 0
	local itemBuyout = unitPrice - undercut
	if LibTSMApp.IsRetail() then
		itemBuyout = max(Math.Round(itemBuyout, COPPER_PER_SILVER), COPPER_PER_SILVER)
	end
	return Math.Bound(itemBuyout, 1, AuctionHouse.GetMaxPrice() - (LibTSMApp.IsRetail() and 99 or 0))
end

function PostScan.PrepareFailedPosts()
	local query = private.queueDB:NewAutoReleaseQuery()
		:AutoPauseDBQueryUpdates()
		:GreaterThan("numFailed", 0)
		:OrderBy("auctionId", false)
	for uuid, numFailed, numProcessed, numConfirmed in query:Iterator("numFailed", "numProcessed", "numConfirmed") do
		assert(numProcessed >= numFailed and numConfirmed >= numFailed)
		local updates = TempTable.Acquire()
		updates.numFailed = 0
		updates.numProcessed = numProcessed - numFailed
		updates.numConfirmed = numConfirmed - numFailed
		private.queueDB:UpdateRow(uuid, updates)
		TempTable.Release(updates)
	end
	private.UpdateBagDB()
end

function PostScan.Reset()
	private.queueDB:Truncate()
	private.nextQueueAuctionId = -1
	private.bagDB:Truncate()
	private.state:ResetToDefault()
end

---Changes a post detail.
---@param field string The field to change
---@param value number The new value
function PostScan.ChangePostDetail(field, value)
	local uuid, itemString, stackSize, currentItemBuyout, currentItemBid, auctionId = private.currentRowQuery:GetFirstResultWithUUID("itemString", "stackSize", "itemBuyout", "itemBid", "auctionId")
	assert(uuid)
	local isCommodity = ItemInfo.IsCommodity(itemString)
	local updates = TempTable.Acquire()
	if field == "bid" or field == "itemBid" then
		assert(not isCommodity)
		value = max(value, 1)
		local itemBid = field == "itemBid" and value or floor(value / stackSize)
		local itemBuyout = currentItemBuyout
		if itemBuyout > 0 then
			itemBid = min(itemBid, itemBuyout)
		end
		updates.bid = itemBid * stackSize
		updates.itemBid = itemBid
	elseif field == "buyout" or field == "itemBuyout" then
		local itemBuyout = field == "itemBuyout" and value or floor(value / stackSize)
		if isCommodity or (itemBuyout > 0 and itemBuyout < currentItemBid) then
			updates.bid = itemBuyout * stackSize
			updates.itemBid = itemBuyout
		end
		AuctioningLog.UpdateRowByIndex(auctionId, "buyout", itemBuyout)
		updates.buyout = itemBuyout * stackSize
		updates.itemBuyout = itemBuyout
	elseif field == "postTime" then
		updates.postTime = value
	else
		error("Invalid field: "..tostring(field))
	end
	private.queueDB:UpdateRow(uuid, updates)
	TempTable.Release(updates)
end



-- ============================================================================
-- Private Helper Functions (General)
-- ============================================================================

function private.OnGroupsOperationsChanged()
	private.operationsChangedTimer:RunForFrames(1)
end

function private.UpdateOperationDB()
	if not DefaultUI.IsAuctionHouseVisible() then
		return
	end
	private.operationDB:TruncateAndBulkInsertStart()
	local query = BagTracking.CreateQueryBagsAuctionable()
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Distinct("autoBaseItemString")
	for _, itemString in query:Iterator("autoBaseItemString") do
		local _, operationName = AuctioningOperation.GetFirstByItem(itemString)
		if operationName then
			private.operationDB:BulkInsertNewRow(itemString, operationName)
		end
	end
	private.operationDB:BulkInsertEnd()
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

---@param auctionScan AuctionScanManager
function private.ScanThread(auctionScan, scanContext)
	auctionScan:SetScript("OnQueryDone", private.AuctionScanOnQueryDone)
	private.UpdateBagDB()

	-- Get the state of the player's bags
	assert(not next(private.bagCountsTemp))
	private.bagDB:NewAutoReleaseQuery()
		:GroupedSum("itemString", "quantity", private.bagCountsTemp)

	-- Generate the list of items we want to scan for
	wipe(private.itemList)
	for itemString, numHave in pairs(private.bagCountsTemp) do
		local groupPath = Group.GetPathByItem(itemString)
		local contextFilter = scanContext.isItems and itemString or groupPath
		if tContains(scanContext, contextFilter) and private.CanPostItem(itemString, groupPath, numHave) then
			tinsert(private.itemList, itemString)
		end
	end
	Table.WipeAndDeallocate(private.bagCountsTemp)
	if #private.itemList == 0 then
		return
	end

	-- Record this search
	local searchType = scanContext.isItems and AuctioningSavedSearches.SEARCH_TYPE.POST_ITEMS or AuctioningSavedSearches.SEARCH_TYPE.POST_GROUPS
	AuctioningSavedSearches.Record(scanContext, searchType)

	-- Run the scan
	for _, query in auctionScan:AddItemListQueriesThreaded(private.itemList) do
		query:SetIsBrowseDoneFunction(private.QueryIsBrowseDoneFunction)
		query:AddCustomFilter(private.QueryBuyoutFilter)
	end
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
end



-- ============================================================================
-- Private Helper Functions for Scanning
-- ============================================================================

function private.UpdateBagDB()
	private.bagDB:TruncateAndBulkInsertStart()
	local query = BagTracking.CreateQueryBagsAuctionable()
		:AutoRelease()
		:OrderBy("slotId", true)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
	for _, slotId, itemString, quantity in query:Iterator("slotId", "autoBaseItemString", "quantity") do
		private.bagDB:BulkInsertNewRow(itemString, quantity, slotId)
	end
	private.bagDB:BulkInsertEnd()
end

function private.CanPostItem(itemString, groupPath, numHave)
	local hasValidOperation = false
	local iter = GroupOperation.OperationIterator(groupPath, "Auctioning")
	for _, operationName, operationSettings in iter do
		---@cast operationSettings AuctioningOperationSettings
		local isValid, numUsed = private.IsOperationValid(itemString, numHave, operationName, operationSettings)
		if isValid == true then
			assert(numUsed and numUsed > 0)
			numHave = numHave - numUsed
			hasValidOperation = true
		elseif isValid == false then
			iter:Release()
			return false
		else
			-- we are ignoring this operation
			assert(isValid == nil, "Invalid return value")
		end
	end

	return hasValidOperation
end

---@param operationSettings AuctioningOperationSettings
function private.IsOperationValid(itemString, num, operationName, operationSettings, noLog)
	local shouldPost, errTypeOrNum, errArgOrKeepQuantity, errArg2 = AuctioningOperation.ValidateForPosting(itemString, num, operationSettings)
	if shouldPost then
		if not noLog then
			-- Check if we should warn about the vendor sell price
			local vendorSellPrice = ItemInfo.GetVendorSell(itemString) or 0
			if vendorSellPrice > 0 and AuctioningOperation.IsMinPriceBelowVendorSell(itemString, operationSettings, vendorSellPrice) then
				-- Just a warning, not an error
				ChatMessage.PrintfUser(L["WARNING: Your minimum price for %s is below its vendorsell price (with AH cut taken into account). Consider raising your minimum price, or vendoring the item."], ItemInfo.GetLink(itemString))
			end
		end
		return shouldPost, errTypeOrNum, errArgOrKeepQuantity
	elseif errTypeOrNum == nil then
		return shouldPost
	end

	local errMsg = nil
	if errTypeOrNum == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		errMsg = private.GetInvalidGroupError(itemString, errTypeOrNum, errArgOrKeepQuantity, errArg2)
	elseif errTypeOrNum ~= AuctioningOperation.RESULT.NOT_POSTING then
		error("Unknown result: "..tostring(errTypeOrNum))
	end
	if errMsg and not private.settings.disableInvalidMsg then
		ChatMessage.PrintUser(errMsg)
	end
	if not noLog then
		AuctioningLog.AddEntry(itemString, operationName, errTypeOrNum, "", 0, math.huge, errMsg)
	end
	return shouldPost
end

function private.GetInvalidGroupError(itemString, errType, errArg, errArg2)
	local itemLink = ItemInfo.GetLink(itemString)
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.POST_CAP then
		return format(L["Did not post %s because your post cap (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.STACK_SIZE then
		if errArg then
			return format(L["Did not post %s because your stack size (%s) is invalid. Check your settings."], itemLink, errArg)
		else
			return format(L["Did not post %s because Blizzard didn't provide all necessary information for it. Try again later."], itemLink)
		end
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.KEEP_QUANTITY then
		return format(L["Did not post %s because your keep quantity (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_EXPIRES then
		return format(L["Did not post %s because your max expires (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MIN_PRICE then
		return format(L["Did not post %s because your minimum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_PRICE then
		return format(L["Did not post %s because your maximum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE then
		return format(L["Did not post %s because your normal price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.UNDERCUT then
		return format(L["Did not post %s because your undercut (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN then
		return format(L["Did not post %s because your normal price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN then
		return format(L["Did not post %s because your maximum price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	else
		error("Unknown error type: "..tostring(errType))
	end
end

function private.QueryBuyoutFilter(_, row)
	local _, itemBuyout, minItemBuyout = row:GetBuyouts()
	return (itemBuyout and itemBuyout == 0) or (minItemBuyout and minItemBuyout == 0)
end

function private.QueryIsBrowseDoneFunction(query)
	if not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic() then
		return false
	end
	local isDone = true
	for itemString in query:ItemIterator() do
		isDone = isDone and private.QueryIsBrowseDoneForItem(query, itemString)
	end
	return isDone
end

function private.QueryIsBrowseDoneForItem(query, itemString)
	local groupPath = Group.GetPathByItem(itemString)
	local isFilterDone = true
	local iter = GroupOperation.OperationIterator(groupPath, "Auctioning")
	for _, _, operationSettings in iter do
		---@cast operationSettings AuctioningOperationSettings
		local numBuyouts, minItemBuyout = 0, nil
		for _, subRow in query:ItemSubRowIterator(itemString) do
			local _, itemBuyout = subRow:GetBuyouts()
			local timeLeft = subRow:GetListingInfo()
			local quantity = subRow:GetQuantities()
			if not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
				numBuyouts = numBuyouts + 1
				minItemBuyout = min(minItemBuyout or math.huge, itemBuyout)
			end
		end
		if AuctioningOperation.ShouldKeepScanningForPosting(itemString, operationSettings, numBuyouts, minItemBuyout) then
			isFilterDone = false
			iter:Release()
			break
		end
	end
	return isFilterDone
end

function private.AuctionScanOnQueryDone(_, query)
	for itemString in query:ItemIterator() do
		local groupPath = Group.GetPathByItem(itemString)
		local numHave = private.bagDB:NewAutoReleaseQuery()
			:Equal("itemString", itemString)
			:Sum("quantity")

		for _, operationName, operationSettings in GroupOperation.OperationIterator(groupPath, "Auctioning") do
			---@cast operationSettings AuctioningOperationSettings
			local isValid, _, keepQuantity = private.IsOperationValid(itemString, numHave, operationName, operationSettings, true)
			local operationNumHave = isValid and (numHave - keepQuantity) or 0
			if operationNumHave > 0 then
				assert(not next(private.subRowsTemp))
				Util.GetFilteredSubRows(query, itemString, operationSettings, private.subRowsTemp)
				local reason, numUsed, itemBuyout, seller, auctionId, errMsg = private.GeneratePosts(itemString, operationName, operationSettings, operationNumHave, private.subRowsTemp)
				if errMsg and not private.settings.disableInvalidMsg then
					ChatMessage.PrintUser(errMsg)
				end
				wipe(private.subRowsTemp)
				numHave = numHave - (numUsed or 0)
				seller = seller or ""
				auctionId = auctionId or -math.huge
				AuctioningLog.AddEntry(itemString, operationName, reason, seller, itemBuyout or 0, auctionId, errMsg)
				if reason == AuctioningOperation.RESULT.POSTING then
					private.state.numPosting = private.state.numPosting + 1
				else
					private.state.numSkipping = private.state.numSkipping + 1
				end
			end
		end
		assert(numHave >= 0)
	end
end

---@param operationSettings AuctioningOperationSettings
function private.GeneratePosts(itemString, operationName, operationSettings, numHave, subRows)
	local maxCanPost, perAuction, postCap = AuctioningOperation.GetPostQuantities(itemString, operationSettings, numHave)
	if not maxCanPost or not perAuction or not postCap then
		return AuctioningOperation.RESULT.NOT_POSTING.NOT_ENOUGH
	end

	assert(not next(private.lowestAuctionTemp))
	local lowestAuction = private.lowestAuctionTemp
	if not Util.GetLowestAuction(subRows, itemString, operationSettings, lowestAuction) then
		wipe(lowestAuction)
		lowestAuction = nil
	end
	local reason, seller, bid, buyout, activeAuctionsBid, activeAuctionsBuyout = AuctioningOperation.MakePostDecision(itemString, lowestAuction, operationSettings)
	local errMsg = nil
	if reason == AuctioningOperation.RESULT.INVALID.SELLER then
		ChatMessage.PrintfUser(L["The seller name of the lowest auction for %s was not given by the server. Skipping this item."], ItemInfo.GetLink(itemString))
	end
	if lowestAuction then
		wipe(lowestAuction)
	end
	if reason ~= AuctioningOperation.RESULT.POSTING then
		return reason, nil, nil, seller, nil, errMsg
	end
	local activeAuctions = 0
	if activeAuctionsBid or activeAuctionsBuyout then
		assert(activeAuctionsBid and activeAuctionsBuyout)
		activeAuctions = Util.GetPlayerAuctionCount(subRows, itemString, operationSettings, activeAuctionsBid, activeAuctionsBuyout, perAuction)
	end
	assert(bid and buyout)
	if LibTSMApp.IsRetail() then
		bid = max(Math.Round(bid, COPPER_PER_SILVER), COPPER_PER_SILVER)
		buyout = max(Math.Round(buyout, COPPER_PER_SILVER), COPPER_PER_SILVER)
	else
		bid = floor(bid)
	end

	bid = min(bid, AuctionHouse.GetMaxPrice() - (LibTSMApp.IsRetail() and 99 or 0))
	buyout = min(buyout, AuctionHouse.GetMaxPrice() - (LibTSMApp.IsRetail() and 99 or 0))

	-- Check if we can't post anymore
	local numPending = private.GetNumPendingPosts(itemString, buyout, perAuction)
	activeAuctions = activeAuctions + numPending
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		maxCanPost = min(postCap - activeAuctions, maxCanPost)
	else
		perAuction = min(postCap - activeAuctions, perAuction)
	end
	if maxCanPost <= 0 or perAuction <= 0 then
		return AuctioningOperation.RESULT.POSTING_NOT_NEEDED.TOO_MANY
	end

	if (LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and (bid * perAuction > AuctionHouse.GetMaxPrice() or buyout * perAuction > AuctionHouse.GetMaxPrice()) then
		errMsg = format(L["The buyout price for %s would be above the maximum allowed price. Skipping this item."], ItemInfo.GetLink(itemString))
		return AuctioningOperation.RESULT.INVALID.ITEM_GROUP.OTHER, nil, nil, nil, nil, errMsg
	end

	-- Insert the posts into our DB
	local auctionId = private.nextQueueAuctionId
	local postTime, stackSizeIsCap = AuctioningOperation.GetPostSettings(operationSettings)
	local minPrice = AuctioningOperation.GetItemMinPrice(itemString, operationSettings)
	local normalPrice = AuctioningOperation.GetItemNormalPrice(itemString, operationSettings)
	local maxPrice = AuctioningOperation.GetItemMaxPrice(itemString, operationSettings)
	assert(minPrice and normalPrice and maxPrice)
	local extraStack = 0
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		private.AddToQueue(itemString, operationName, bid, buyout, perAuction, maxCanPost, postTime, minPrice, normalPrice, maxPrice)
		-- Check if we can post an extra partial stack
		extraStack = (maxCanPost < postCap and stackSizeIsCap and (numHave % perAuction)) or 0
	else
		assert(maxCanPost == 1)
		if ItemInfo.IsCommodity(itemString) then
			local maxPerAuction = (ItemInfo.GetMaxStack(itemString) or 1) * MAX_COMMODITY_STACKS_PER_AUCTION
			maxCanPost = floor(perAuction / maxPerAuction)
			-- Check if we can post an extra partial stack
			extraStack = perAuction % maxPerAuction
			perAuction = min(perAuction, maxPerAuction)
			bid = buyout
		else
			-- Post non-commodities as single stacks
			maxCanPost = perAuction
			perAuction = 1
		end
		assert(maxCanPost > 0 or extraStack > 0)
		if maxCanPost > 0 then
			private.AddToQueue(itemString, operationName, bid, buyout, perAuction, maxCanPost, postTime, minPrice, normalPrice, maxPrice)
		end
	end
	if extraStack > 0 then
		private.AddToQueue(itemString, operationName, bid, buyout, extraStack, 1, postTime, minPrice, normalPrice, maxPrice)
	end
	return reason, (perAuction * maxCanPost) + extraStack, buyout, seller, auctionId
end

function private.GetNumPendingPosts(itemString, itemBuyout, stackSize)
	local query = private.queueDB:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:Equal("itemBuyout", itemBuyout)
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		return query:Equal("stackSize", stackSize):Sum("numStacks")
	else
		return query:SumOfProduct("stackSize", "numStacks")
	end
end

function private.AddToQueue(itemString, operationName, itemBid, itemBuyout, stackSize, numStacks, postTime, minPrice, normalPrice, maxPrice)
	local bid = itemBid * stackSize
	local buyout = itemBuyout * stackSize
	private.queueDB:InsertRow(private.nextQueueAuctionId, itemString, operationName, bid, buyout, itemBid, itemBuyout, stackSize, numStacks, postTime, 0, 0, 0, minPrice, normalPrice, maxPrice)
	private.nextQueueAuctionId = private.nextQueueAuctionId - 1
end



-- ============================================================================
-- Private Helper Functions for Posting
-- ============================================================================

function private.GetPostBagSlot(itemString, quantity)
	-- Start with the slot which is closest to the desired stack size
	local slotId = private.bagDB:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:GreaterThanOrEqual("quantity", quantity)
		:OrderBy("quantity", true)
		:GetFirstResult("slotId")
	if not slotId then
		slotId = private.bagDB:NewAutoReleaseQuery()
			:Equal("itemString", itemString)
			:LessThanOrEqual("quantity", quantity)
			:OrderBy("quantity", false)
			:GetFirstResult("slotId")
	end
	if not slotId then
		-- This item was likely removed from the player's bags, so just give up
		Log.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
		return nil, false
	end
	assert(not next(private.bagRemoveTemp))
	local removeContext = private.bagRemoveTemp
	slotId = private.ItemBagSlotHelper(itemString, slotId, quantity, removeContext)

	local link = Container.GetItemLink(slotId)
	local bagItemString = link and ItemString.Get(link)
	if not bagItemString or Group.TranslateItemString(bagItemString) ~= itemString then
		-- Something changed with the player's bags so we can't post the item right now
		wipe(removeContext)
		return nil, true
	end
	local _, _, quality = Container.GetItemInfo(slotId)
	if not quality or quality == -1 then
		-- The game client doesn't have item info cached for this item, so we can't post it yet
		wipe(removeContext)
		return nil, true
	end
	for removeSlotId, removeQuantity in pairs(removeContext) do
		private.RemoveBagQuantity(removeSlotId, removeQuantity)
	end
	wipe(removeContext)
	return slotId, true
end

function private.ItemBagSlotHelper(itemString, slotId, quantity, removeContext)
	-- Try to post completely from the selected slot
	local found = private.bagDB:NewAutoReleaseQuery()
		:Equal("slotId", slotId)
		:GreaterThanOrEqual("quantity", quantity)
		:IsNotEmpty()
	if found then
		removeContext[slotId] = quantity
		return slotId
	end

	-- try to find a stack at a lower slot which has enough to post from
	local foundSlotId = private.bagDB:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:LessThan("slotId", slotId)
		:GreaterThanOrEqual("quantity", quantity)
		:OrderBy("slotId", true)
		:GetFirstResult("slotId")
	if foundSlotId then
		removeContext[foundSlotId] = quantity
		return foundSlotId
	end

	-- try to post using the selected slot and the lower slots
	local selectedQuantity = private.bagDB:NewAutoReleaseQuery()
		:Equal("slotId", slotId)
		:GetFirstResult("quantity")
	local numNeeded = quantity - selectedQuantity
	local numUsed = 0
	assert(not next(private.usedSlotsTemp))
	local query = private.bagDB:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:LessThan("slotId", slotId)
		:OrderBy("slotId", true)
	for _, rowSlotId, rowQuantity in query:Iterator("slotId", "quantity") do
		if numNeeded ~= numUsed then
			numUsed = min(numUsed + rowQuantity, numNeeded)
			tinsert(private.usedSlotsTemp, rowSlotId)
		end
	end
	if numNeeded == numUsed then
		removeContext[slotId] = selectedQuantity
		for _, rowSlotId in ipairs(private.usedSlotsTemp) do
			local rowQuantity = private.bagDB:GetRowFields(private.bagDB:GetUniqueRow("slotId", rowSlotId), "quantity")
			local rowNumUsed = min(numUsed, rowQuantity)
			numUsed = numUsed - rowNumUsed
			removeContext[rowSlotId] = (removeContext[rowSlotId] or 0) + rowNumUsed
		end
		wipe(private.usedSlotsTemp)
		return slotId
	else
		wipe(private.usedSlotsTemp)
	end

	-- Try posting from the next highest slot
	local rowSlotId = private.bagDB:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:GreaterThan("slotId", slotId)
		:OrderBy("slotId", true)
		:GetFirstResult("slotId")
	return private.ItemBagSlotHelper(itemString, rowSlotId, quantity, removeContext)
end

function private.RemoveBagQuantity(slotId, quantity)
	local uuid = private.bagDB:GetUniqueRow("slotId", slotId)
	local remainingQuantity = private.bagDB:GetRowFields(uuid, "quantity") - quantity
	if remainingQuantity > 0 then
		private.bagDB:UpdateRow(uuid, "quantity", remainingQuantity)
	else
		assert(remainingQuantity == 0)
		private.bagDB:DeleteRow(uuid)
	end
end

function private.StatusQueryToQueueStatus(query)
	local numProcessed, numConfirmed, numFailed, numStacks = Util.GetQueueStatus(query)
	return TempTable.Acquire(numProcessed, numConfirmed, numFailed, numStacks, query:SumOfProduct("buyout", "numStacks"))
end

---@param result ExistingAuctionsList.Entry[]
---@param unitPrice number
---@param quantity number
---@param isIgnored boolean
---@param isPosting boolean
function private.AddExistingAuction(result, unitPrice, quantity, isIgnored, isPosting)
	if not isPosting then
		for _, entry in ipairs(result) do
			if entry.unitPrice == unitPrice and entry.isIgnored == isIgnored and not entry.isPosting then
				entry.quantity = entry.quantity + quantity
				return
			end
		end
	end
	tinsert(result, {
		unitPrice = unitPrice,
		quantity = quantity,
		isIgnored = isIgnored,
		isPosting = isPosting,
	})
end

---@param a ExistingAuctionsList.Entry
---@param b ExistingAuctionsList.Entry
function private.ExistingAuctionSortHelper(a, b)
	if a.unitPrice ~= b.unitPrice then
		return a.unitPrice < b.unitPrice
	elseif a.isPosting ~= b.isPosting then
		return a.isPosting
	end
	return b.isIgnored and not a.isIgnored
end

---@param state AuctioningPostScanState
function private.NumPostSkipAsTempTable(state)
	return TempTable.Acquire(state.numPosting, state.numSkipping)
end

function private.DepositCost(itemString, postTime, stackSize, bid, buyout)
	return AuctionHouseUIUtils.CalculateDeposit(itemString, true, postTime, stackSize, bid, buyout) or 0
end

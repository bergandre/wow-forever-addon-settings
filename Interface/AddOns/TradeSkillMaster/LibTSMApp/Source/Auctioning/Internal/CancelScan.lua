-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local CancelScan = LibTSMApp:InitInternal("Auctioning.CancelScan")
local AuctioningLog = LibTSMApp:Include("Auctioning.Log")
local Util = LibTSMApp:Include("Auctioning.Util")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMApp:From("LibTSMTypes"):Include("GroupOperation")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local AuctioningSavedSearches = LibTSMApp:From("LibTSMTypes"):Include("SavedSearches.AuctioningSavedSearches")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local AuctionHouse = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouse")
local AuctionHouseWrapper = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local Currency = LibTSMApp:From("LibTSMWoW"):Include("API.Currency")
local private = {
	settings = nil,
	scanThreadId = nil,
	queueDB = nil,
	currentRowQuery = nil,
	statusQuery = nil,
	itemList = {},
	usedAuctionIndex = {},
	subRowsTemp = {},
	---@diagnostic disable-next-line: missing-fields
	listedAuctionTemp = {}, ---@type AuctioningOperationListedAuction
	scanResultTemp = {}, ---@type AuctioningOperationCancelScanResult
	lowestAuctionTemp = {}, ---@type AuctioningOperationLowestAuction
}
local CLASSIC_AH_HASH_ARG_FIELDS = { "autoBaseItemString", "buyout", "currentBid", "auctionId" }
local ITEM_BID_ARG_FIELDS = { "stackSize", "currentBid" }
local ITEM_BUYOUT_ARG_FIELDS = { "stackSize", "buyout" }



-- ============================================================================
-- Module Loading
-- ============================================================================

CancelScan:OnModuleLoad(function()
	private.scanThreadId = Threading.New("CANCEL_SCAN", private.ScanThread)
	private.queueDB = Database.NewSchema("AUCTIONING_CANCEL_QUEUE")
		:AddNumberField("auctionId")
		:AddStringField("itemString")
		:AddStringField("operationName")
		:AddNumberField("bid")
		:AddNumberField("buyout")
		:AddNumberField("itemBid")
		:AddNumberField("itemBuyout")
		:AddNumberField("stackSize")
		:AddNumberField("duration")
		:AddNumberField("numStacks")
		:AddNumberField("numProcessed")
		:AddNumberField("numConfirmed")
		:AddNumberField("numFailed")
		:AddIndex("auctionId")
		:AddIndex("itemString")
		:Commit()
	-- Create our queries
	private.currentRowQuery = private.queueDB:NewOwnedQuery()
		:LessThan("numProcessed", Database.OtherFieldQueryParam("numStacks"))
		:OrderBy("auctionId", false)
	private.statusQuery = private.queueDB:NewOwnedQuery()
end)

AddonSettings.RegisterOnLoad(CancelScan, function(db)
	private.settings = db:NewView("CancelScanSettings")
		:AddKey("global", "auctioningOptions", "cancelWithBid")
		:AddKey("global", "auctioningOptions", "disableInvalidMsg")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the scan thread ID.
---@return string
function CancelScan.GetThreadId()
	return private.scanThreadId
end

function CancelScan.CurrentRowPublisher()
	return private.currentRowQuery:Publisher()
end

function CancelScan.StatusQueryPublisher()
	return private.statusQuery:Publisher()
		:Map(private.StatusQueryToQueueStatus)
end

---Processes the current row.
---@return Future? future
---@return boolean canRetry
function CancelScan.DoProcess()
	local uuid, cancelItemString, stackSize, numProcessed, numStacks, cancelAuctionId, cancelItemBid, cancelItemBuyout = private.currentRowQuery:GetFirstResultWithUUID("itemString", "stackSize", "numProcessed", "numStacks", "auctionId", "itemBid", "itemBuyout")
	assert(uuid)
	local auctionId, itemString, currentBid, buyout = private.NewAuctionsAutoReleaseQuery(cancelItemString, cancelItemString)
		:Equal("stackSize", stackSize)
		:If(LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic())
			:VirtualField("hash", "string", private.ClassicAuctionHashField, CLASSIC_AH_HASH_ARG_FIELDS)
			:VirtualField("itemBid", "number", private.ItemBidField, ITEM_BID_ARG_FIELDS)
			:VirtualField("itemBuyout", "number", private.ItemBuyoutField, ITEM_BUYOUT_ARG_FIELDS)
			:NotInTable("hash", private.usedAuctionIndex)
			:Equal("itemBid", cancelItemBid)
			:Equal("itemBuyout", cancelItemBuyout)
		:Else()
			:Equal("auctionId", cancelAuctionId)
			:NotInTable("auctionId", private.usedAuctionIndex)
		:End()
		:If(not private.settings.cancelWithBid)
			:Equal("highBidder", "")
		:End()
		:GetFirstResult("auctionId", "autoBaseItemString", "currentBid", "buyout")
	if auctionId then
		local usedAuctionIndex = (LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and (itemString..buyout..currentBid..auctionId) or auctionId
		private.usedAuctionIndex[usedAuctionIndex] = true
		local result = AuctionHouseWrapper.CancelAuction(auctionId)
		local isRowDone = numProcessed + 1 == numStacks
		private.queueDB:UpdateRow(uuid, "numProcessed", numProcessed + 1)
		if result and isRowDone then
			-- Update the log
			AuctioningLog.UpdateRowByIndex(auctionId, "state", AuctioningLog.STATE.CANCELLED)
		end
		return result, true
	end

	-- We couldn't find this item, so mark this cancel as failed and we'll try again later
	private.queueDB:UpdateRow(uuid, "numProcessed", numProcessed + 1)
	return nil, true
end

function CancelScan.DoSkip()
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

---Handles confirmation of the previous cancel.
---@param success boolean Whether the previous cancel was successful
---@param canRetry boolean Whether or not the cancel can be retried if it failed
function CancelScan.HandleConfirm(success, canRetry)
	local uuid, numFailed, numConfirmed = private.queueDB:NewAutoReleaseQuery()
		:LessThan("numConfirmed", Database.OtherFieldQueryParam("numProcessed"))
		:OrderBy("auctionId", true)
		:GetFirstResultWithUUID("numFailed", "numConfirmed")
	if not uuid then
		-- We may have cancelled something outside of TSM
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
function CancelScan.GetQueueStatus()
	local _, numConfirmed, numFailed, totalNum = Util.GetQueueStatus(private.statusQuery)
	local isDone = numConfirmed == totalNum
	return isDone, numFailed
end

---Prepares to retry failed cancels.
function CancelScan.PrepareFailedCancels()
	wipe(private.usedAuctionIndex)
	local query = private.queueDB:NewAutoReleaseQuery()
		:AutoPauseDBQueryUpdates()
		:GreaterThan("numFailed", 0)
	for uuid, numFailed, numProcessed, numConfirmed in query:Iterator("numFailed", "numProcessed", "numConfirmed") do
		assert(numProcessed >= numFailed and numConfirmed >= numFailed)
		local updates = TempTable.Acquire()
		updates.numFailed = 0
		updates.numProcessed = numProcessed - numFailed
		updates.numConfirmed = numConfirmed - numFailed
		private.queueDB:UpdateRow(uuid, updates)
		TempTable.Release(updates)
	end
end

---Resets the cancel scan state.
function CancelScan.Reset()
	private.queueDB:Truncate()
	wipe(private.usedAuctionIndex)
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

---@param auctionScan AuctionScanManager
function private.ScanThread(auctionScan, groupList)
	auctionScan:SetScript("OnQueryDone", private.AuctionScanOnQueryDone)

	-- generate the list of items we want to scan for
	wipe(private.itemList)
	local query = Auction.NewIndexQuery()
		:AutoRelease()
		:Equal("isSold", false)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:If(not private.settings.cancelWithBid)
			:Equal("highBidder", "")
		:End()
		:Distinct("autoBaseItemString")
	for _, itemString in query:Iterator("autoBaseItemString") do
		if private.CanCancelItem(itemString, groupList) then
			tinsert(private.itemList, itemString)
		end
	end

	if #private.itemList == 0 then
		return
	end
	AuctioningSavedSearches.Record(groupList, AuctioningSavedSearches.SEARCH_TYPE.CANCEL_GROUPS)

	-- Run the scan
	for _, scanQuery in auctionScan:AddItemListQueriesThreaded(private.itemList) do
		scanQuery:AddCustomFilter(private.QueryBuyoutFilter)
	end
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CanCancelItem(itemString, groupList)
	local groupPath = Group.GetPathByItem(itemString)
	if not groupPath or not tContains(groupList, groupPath) then
		return false
	end

	local hasValidOperation = false
	local iter = GroupOperation.OperationIterator(groupPath, "Auctioning")
	for _, operationName, operationSettings in iter do
		---@cast operationSettings AuctioningOperationSettings
		local isValid = private.IsOperationValid(itemString, operationName, operationSettings)
		if isValid == true then
			hasValidOperation = true
		elseif isValid == false then
			iter:Release()
			return false
		else
			-- We are ignoring this operation
			assert(isValid == nil, "Invalid return value")
		end
	end
	return hasValidOperation
end

function private.IsOperationValid(itemString, operationName, operationSettings)
	local errType, errArg, errArg2 = AuctioningOperation.ValidateForCanceling(itemString, operationSettings)
	if not errType then
		return true
	end
	local errMsg = nil
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		errMsg = private.GetInvalidGroupError(itemString, errType, errArg, errArg2)
		if not private.settings.disableInvalidMsg then
			ChatMessage.PrintUser(errMsg)
		end
	end
	AuctioningLog.AddEntry(itemString, operationName, errType, "", 0, 0, errMsg)
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		return false
	elseif errType == AuctioningOperation.RESULT.WONT_CANCEL.DISABLED then
		-- Ignore this operation
		return nil
	else
		error("Unknown error: "..tostring(errType))
	end
end

function private.GetInvalidGroupError(itemString, errType, errArg, errArg2)
	local itemLink = ItemInfo.GetLink(itemString)
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MIN_PRICE then
		return format(L["Did not cancel %s because your minimum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_PRICE then
		return format(L["Did not cancel %s because your maximum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE then
		return format(L["Did not cancel %s because your normal price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.CANCEL_REPOST_THRESHOLD then
		return format(L["Did not cancel %s because your cancel to repost threshold (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.UNDERCUT then
		return format(L["Did not cancel %s because your undercut (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN then
		return format(L["Did not cancel %s because your maximum price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN then
		return format(L["Did not cancel %s because your normal price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	else
		error("Unknown error type: "..tostring(errType))
	end
end

function private.QueryBuyoutFilter(_, row)
	local _, itemBuyout, minItemBuyout = row:GetBuyouts()
	return (itemBuyout and itemBuyout == 0) or (minItemBuyout and minItemBuyout == 0)
end

function private.NewAuctionsAutoReleaseQuery(itemString, autoBaseItemString)
	local itemStringField = nil
	if itemString == ItemString.GetBaseFast(itemString) then
		itemStringField = "baseItemString"
	elseif ItemString.IsLevel(itemString) then
		itemStringField = "levelItemString"
	else
		itemStringField = "itemString"
	end
	return Auction.NewIndexQuery()
		:AutoRelease()
		:Equal("isSold", false)
		:Equal(itemStringField, itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", autoBaseItemString)
		:OrderBy("auctionId", false)
end

function private.AuctionScanOnQueryDone(_, query)
	for itemString in AuctioningLog.WithQueryUpdatesPaused(query:ItemIterator()) do
		local groupPath = Group.GetPathByItem(itemString)
		local baseItemString = ItemString.GetBaseFast(itemString)
		local levelItemString = ItemString.ToLevel(itemString)
		local isLevelItemString = itemString == levelItemString and itemString ~= baseItemString
		local auctionsDBQuery = private.NewAuctionsAutoReleaseQuery(isLevelItemString and baseItemString or itemString, itemString)
		for _, auctionId, stackSize, currentBid, buyout, highBidder, duration in auctionsDBQuery:Iterator("auctionId", "stackSize", "currentBid", "buyout", "highBidder", "duration") do
			assert(not next(private.listedAuctionTemp))
			private.PopulateListedAuction(private.listedAuctionTemp, auctionId, stackSize, currentBid, buyout, highBidder, duration)
			private.GenerateCancels(private.listedAuctionTemp, itemString, groupPath, query)
			wipe(private.listedAuctionTemp)
		end
	end
end

---@param listedAuction AuctioningOperationListedAuction
function private.PopulateListedAuction(listedAuction, auctionId, stackSize, currentBid, buyout, highBidder, duration)
	listedAuction.auctionId = auctionId
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		listedAuction.itemBuyout = floor(buyout / stackSize)
		listedAuction.itemBid = floor(currentBid / stackSize)
	else
		listedAuction.itemBuyout = buyout
		listedAuction.itemBid = currentBid
	end
	listedAuction.stackSize = stackSize
	listedAuction.duration = duration
	listedAuction.hasBid = highBidder ~= "" and not private.settings.cancelWithBid
	listedAuction.canAffordCancel = LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() or AuctionHouse.GetCancelCost(auctionId) <= Currency.GetMoney()
end

---@param listedAuction AuctioningOperationListedAuction
function private.GenerateCancels(listedAuction, itemString, groupPath, query)
	local iter = GroupOperation.OperationIterator(groupPath, "Auctioning")
	for _, operationName, operationSettings in iter do
		---@cast operationSettings AuctioningOperationSettings
		if private.IsOperationValid(itemString, operationName, operationSettings) then
			assert(not next(private.subRowsTemp))
			Util.GetFilteredSubRows(query, itemString, operationSettings, private.subRowsTemp)
			local handled, result, seller = private.GenerateCancel(listedAuction, itemString, operationName, operationSettings, private.subRowsTemp)
			wipe(private.subRowsTemp)
			if result then
				seller = seller or ""
				AuctioningLog.AddEntry(itemString, operationName, result, seller, listedAuction.itemBuyout, listedAuction.auctionId)
			end
			if handled then
				iter:Release()
				break
			end
		end
	end
end

---@param listedAuction AuctioningOperationListedAuction
function private.GenerateCancel(listedAuction, itemString, operationName, operationSettings, subRows)
	assert(not next(private.lowestAuctionTemp))
	local lowestAuction = private.lowestAuctionTemp
	if not Util.GetLowestAuction(subRows, itemString, operationSettings, lowestAuction) then
		wipe(lowestAuction)
		lowestAuction = nil
	end
	assert(not next(private.scanResultTemp))
	Util.GetCancelScanResult(subRows, itemString, operationSettings, lowestAuction, private.scanResultTemp)
	local handled, result = AuctioningOperation.MakeCancelDecision(itemString, operationSettings, lowestAuction, listedAuction, private.scanResultTemp)
	wipe(private.scanResultTemp)
	local seller = lowestAuction and lowestAuction.seller or nil
	if lowestAuction then
		wipe(lowestAuction)
	end
	if result == AuctioningOperation.RESULT.INVALID.SELLER then
		ChatMessage.PrintfUser(L["The seller name of the lowest auction for %s was not given by the server. Skipping this item."], ItemInfo.GetLink(itemString))
	elseif result == AuctioningOperation.RESULT.CANCELING or result == AuctioningOperation.RESULT.CANCELING_EXCESS then
		private.AddToQueue(itemString, operationName, listedAuction)
	end
	return handled, result, seller
end

---@param listedAuction AuctioningOperationListedAuction
function private.AddToQueue(itemString, operationName, listedAuction)
	local bid = listedAuction.itemBid * listedAuction.stackSize
	local buyout = listedAuction.itemBuyout * listedAuction.stackSize
	private.queueDB:InsertRow(listedAuction.auctionId, itemString, operationName, bid, buyout, listedAuction.itemBid, listedAuction.itemBuyout, listedAuction.stackSize, listedAuction.duration, 1, 0, 0, 0)
end

function private.ClassicAuctionHashField(itemString, buyout, currentBid, auctionId)
	return itemString..buyout..currentBid..auctionId
end

function private.ItemBidField(stackSize, bid)
	return floor(bid / stackSize)
end

function private.ItemBuyoutField(stackSize, buyout)
	return floor(buyout / stackSize)
end

function private.StatusQueryToQueueStatus(query)
	return TempTable.Acquire(Util.GetQueueStatus(query))
end

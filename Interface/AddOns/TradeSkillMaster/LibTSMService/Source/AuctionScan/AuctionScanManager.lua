-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionScanManager = LibTSMService:DefineClassType("AuctionScanManager")
local FindThread = LibTSMService:Include("AuctionScan.FindThread")
local QueryUtil = LibTSMService:Include("AuctionScan.QueryUtil")
local AuctionQuery = LibTSMService:IncludeClassType("AuctionQuery")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local UIBindings = LibTSMService:From("LibTSMReactive"):IncludeClassType("UIBindings")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local AuctionHouseWrapper = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local private = {
	objectPool = ObjectPool.New("AUCTION_SCAN_MANAGER", AuctionScanManager, 1),
	itemsTemp = {},
}
-- Arbitrary estimate that finishing the browse request is worth 10% of the query's progress
local BROWSE_PROGRESS = 0.1
local ACTION_SCRIPTS = { OnProgressUpdate = true, OnQueryDone = true, OnCurrentSearchChanged = true, OnNumItemsChanged = true }

---@alias AuctionScanManagerProgressUpdateHandler fun(self: AuctionScanManager)
---@alias AuctionScanManagerQueryDoneHandler fun(self: AuctionScanManager, query: AuctionQuery, numResults: number)
---@alias AuctionScanManagerCurrentSearchChangedHandler fun(self: AuctionScanManager, baseItemString?: string)
---@alias AuctionScanManagerScriptHandler (AuctionScanManagerProgressUpdateHandler|AuctionScanManagerQueryDoneHandler|AuctionScanManagerCurrentSearchChangedHandler)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets an auction scan manager.
---@return AuctionScanManager
function AuctionScanManager.__static.Get()
	return private.objectPool:Get()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function AuctionScanManager:__init()
	self._manager = nil
	self._bindings = UIBindings.Create()
	self._scriptAction = {}
	self._resolveSellers = nil ---@type boolean!
	self._queries = {} ---@type AuctionQuery[]
	self._queriesScanned = 0
	self._queryDidBrowse = false
	self._numSearchRows = 0
	self._numSearchedRows = 0
	self._onProgressUpdateHandler = nil ---@type AuctionScanManagerProgressUpdateHandler?
	self._onQueryDoneHandler = nil ---@type AuctionScanManagerQueryDoneHandler?
	self._resultsUpdateCallbacks = CallbackRegistry.NewList()
	self._nextSearchItemFunction = nil
	self._currentSearchChangedCallback = nil ---@type AuctionScanManagerCurrentSearchChangedHandler?
	self._findResult = {}
	self._cancelled = false
	self._shouldPause = false
	self._paused = false
	self._scanQuery = nil ---@type AuctionQuery?
	self._findQuery = nil ---@type AuctionQuery?
	self._queryCallback = function(query, searchRow, changedBaseItemStrings)
		self._resultsUpdateCallbacks:CallAll(self, query, searchRow, changedBaseItemStrings)
	end
end

function AuctionScanManager:_Release()
	self._manager = nil
	self._bindings:Clear()
	wipe(self._scriptAction)
	self._resolveSellers = nil
	for _, query in ipairs(self._queries) do
		query:Release()
	end
	wipe(self._queries)
	self._queriesScanned = 0
	self._queryDidBrowse = false
	self._numSearchRows = 0
	self._numSearchedRows = 0
	self._onProgressUpdateHandler = nil
	self._onQueryDoneHandler = nil
	self._resultsUpdateCallbacks:Wipe()
	self._nextSearchItemFunction = nil
	self._currentSearchChangedCallback = nil
	self._cancelled = false
	self._shouldPause = false
	self._paused = false
	wipe(self._findResult)
	self._scanQuery = nil
	if self._findQuery then
		self._findQuery:Release()
		self._findQuery = nil
	end
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Releases the scan manager.
function AuctionScanManager:Release()
	FindThread.StopForAuctionScan(self)
	self:_Release()
	private.objectPool:Recycle(self)
end

---Sets whether or not to resolve seller names.
---@param resolveSellers boolean
---@return self
function AuctionScanManager:SetResolveSellers(resolveSellers)
	self._resolveSellers = resolveSellers
	return self
end

---Sets the UI manager to send actions to.
---@param manager UIManager The UI manager
---@return self
function AuctionScanManager:SetUIManager(manager)
	assert(not self._manager and manager)
	self._manager = manager
	return self
end

---Binds a state property to the number of auctions.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function AuctionScanManager:BindNumAuctions(state, key)
	self._bindings:Add("NUM_ITEMS", state, key)
	return self
end

---Sets the UI manager action to send for one of the scripts.
---@param script "OnProgressUpdate"|"OnQueryDone"|"OnCurrentSearchChanged" The script to send the action for
---@param action string The action to send
---@return self
function AuctionScanManager:SetAction(script, action)
	assert(ACTION_SCRIPTS[script])
	assert(not self._scriptAction[script])
	self._scriptAction[script] = action
	return self
end

---Registers a script handler.
---@overload fun(script: "OnProgressUpdate", handler: AuctionScanManagerProgressUpdateHandler?)
---@overload fun(script: "OnQueryDone", handler: AuctionScanManagerQueryDoneHandler?)
---@overload fun(script: "OnCurrentSearchChanged", handler: AuctionScanManagerCurrentSearchChangedHandler?)
---@param script "OnProgressUpdate"|"OnQueryDone"|"OnCurrentSearchChanged" The script to register for
---@param handler? AuctionScanManagerScriptHandler The function called with the applicable arguments
---@return self
function AuctionScanManager:SetScript(script, handler)
	if script == "OnProgressUpdate" then
		self._onProgressUpdateHandler = handler
	elseif script == "OnQueryDone" then
		self._onQueryDoneHandler = handler
	elseif script == "OnCurrentSearchChanged" then
		self._currentSearchChangedCallback = handler
	else
		error("Unknown AuctionScanManager script: "..tostring(script))
	end
	return self
end

---Adds a callback when results are updated.
---@param func fun(manager: AuctionScanManager, query: AuctionQuery, row?: AuctionRow, changedBaseItemStrings?: table<string,true>) The callback function
function AuctionScanManager:AddResultsUpdateCallback(func)
	self._resultsUpdateCallbacks:Add(func)
end

---Removes a callback which was previously registered.
---@param func function
function AuctionScanManager:RemoveResultsUpdateCallback(func)
	self._resultsUpdateCallbacks:Remove(func)
end

---Sets the function to use to get the next item to be searched.
---@param func? fun(): string Function which returns the base item string of the next item
function AuctionScanManager:SetNextSearchItemFunction(func)
	self._nextSearchItemFunction = func
end

---Gets the number of queries.
---@return number
function AuctionScanManager:GetNumQueries()
	return #self._queries
end

---Iterates over the queries registered with the scan manager.
---@return fun(): number, AuctionQuery @Iterator with fields: `index`, `query`
---@return table
---@return number
function AuctionScanManager:QueryIterator()
	return private.QueryIteratorHelper, self._queries, 0
end

---Creates a new query.
---@return AuctionQuery
function AuctionScanManager:NewQuery()
	local query = AuctionQuery.Get()
	self:_AddQuery(query)
	return query
end

---Adds queries which are generated from a list of items and returns an iterator for the newly added queries.
---@param itemList string[] The list of items to generate and add queries for
---@return fun(): number, AuctionQuery @Iterator with fields: `index`, `query`
---@return table
---@return number
function AuctionScanManager:AddItemListQueriesThreaded(itemList)
	assert(Threading.IsThreadContext())
	-- Remove duplicates
	assert(not next(private.itemsTemp))
	for i = #itemList, 1, -1 do
		local itemString = itemList[i]
		if private.itemsTemp[itemString] then
			tremove(itemList, i)
		end
		private.itemsTemp[itemString] = true
	end
	Table.WipeAndDeallocate(private.itemsTemp)
	self._bindings:Process("NUM_ITEMS", #itemList)
	local prevNumQueries = self:GetNumQueries()
	QueryUtil.GenerateThreaded(itemList, self:__closure("_AddQuery"))
	return private.QueryIteratorHelper, self._queries, prevNumQueries
end

---Scans for all the added queries and returns if they were all successful.
---@return boolean
function AuctionScanManager:ScanQueriesThreaded()
	assert(Threading.IsThreadContext())
	self._queriesScanned = 0
	self._cancelled = false
	AuctionHouseWrapper.GetAndResetTotalHookedTime()
	self:_NotifyProgressUpdate()
	self:_Pause()

	-- Loop through each filter to perform
	local allSuccess = true
	while self._queriesScanned < #self._queries do
		local query = self._queries[self._queriesScanned + 1]
		-- Run the browse query
		local querySuccess, numNewResults = self:_ProcessQuery(query)
		if not querySuccess then
			allSuccess = false
			break
		end
		self._queriesScanned = self._queriesScanned + 1
		self._queryDidBrowse = false
		self._numSearchRows = 0
		self._numSearchedRows = 0
		self:_NotifyProgressUpdate()
		self:_SendActionScript("OnQueryDone")
		if self._onQueryDoneHandler then
			self:_onQueryDoneHandler(query, numNewResults)
		end
		self:_Pause()
	end

	if allSuccess then
		local hookedTime, topAddon, topTime = AuctionHouseWrapper.GetAndResetTotalHookedTime()
		if hookedTime > 1 and topAddon ~= "Blizzard_AuctionHouseUI" and topTime then
			Log.Warn("Scan was slowed down by %s seconds by other AH addons (%s seconds by %s).", Math.Round(hookedTime, 0.1), Math.Round(topTime, 0.1), topAddon)
		end
	end
	return allSuccess
end

---Sleeps while checking for the scan being paused.
---@param seconds number The time to sleep for in seconds
function AuctionScanManager:SleepThreaded(seconds)
	Threading.Yield(true)
	while seconds > 0 do
		local stepSeconds = min(seconds, 0.5)
		Threading.Sleep(stepSeconds)
		seconds = seconds - stepSeconds
		self:_Pause()
	end
end

---Finds the specified auction
---@param auction AuctionSubRow The sub row to find
---@param callback fun(...: any) The result callback
---@param noSeller boolean Ignore seller names
function AuctionScanManager:FindAuction(auction, callback, noSeller)
	FindThread.StartFindAuction(self, auction, callback, noSeller)
end

---Checks if an auction can be bid on.
---@param subRow AuctionSubRow
---@return boolean
function AuctionScanManager:CanBid(subRow)
	assert(subRow:IsSubRow())
	local _, _, _, isHighBidder = subRow:GetBidInfo()
	local displayedBid = subRow:GetDisplayedBids()
	local buyout = subRow:GetBuyouts()
	if isHighBidder then
		return false
	elseif displayedBid == buyout then
		return false
	elseif not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() and subRow:IsCommodity() then
		return false
	elseif Currency.GetMoney() < subRow:GetRequiredBid() then
		return false
	end
	return true
end

---Checks if an auction can be bought.
---@param subRow AuctionSubRow The auction sub row to check
---@return boolean
function AuctionScanManager:CanBuy(subRow)
	assert(subRow:IsSubRow())
	local buyout, itemBuyout = subRow:GetBuyouts()
	if not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() then
		buyout = itemBuyout
	end
	local itemString = subRow:GetItemString()
	if buyout == 0 or Currency.GetMoney() < buyout then
		return false
	elseif not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() and subRow:IsCommodity() then
		assert(itemString)
		-- Make sure it's the cheapest
		local isCheapest = false
		for _, query in self:QueryIterator() do
			isCheapest = isCheapest or subRow == query:GetCheapestSubRow(itemString)
		end
		if not isCheapest then
			return false
		end
	end
	return true
end

---Prepares to bid or buy on an auction.
---@param index? number The index of the auction
---@param subRow AuctionSubRow The sub row for the auction
---@param noSeller boolean Whether or not to ignore the seller name
---@param quantity number The quantity to prepare to bid or buy
---@param itemBuyout? number The per-item buyout
---@return boolean
---@return Future?
function AuctionScanManager:PrepareForBidOrBuyout(index, subRow, noSeller, quantity, itemBuyout)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		assert(index)
		return subRow:EqualsIndex(index, noSeller)
	else
		local itemString = subRow:GetItemString()
		assert(itemString)
		if ItemInfo.IsCommodity(itemString) then
			assert(itemBuyout)
			local future = AuctionHouseWrapper.StartCommoditiesPurchase(ItemString.ToId(itemString), quantity, itemBuyout)
			if not future then
				return false
			end
			return true, future
		else
			return true
		end
	end
end

---Places a bid or buyout for an auction.
---@param index? number The index of the auction
---@param bidBuyout number The amount to bid or buy for
---@param subRow AuctionSubRow The auction sub row
---@param quantity number The quantity to bid or buy
---@return Future?
function AuctionScanManager:PlaceBidOrBuyout(index, bidBuyout, subRow, quantity)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		assert(index)
		return AuctionHouseWrapper.PlaceBid(index, bidBuyout)
	else
		local itemString = subRow:GetItemString()
		assert(itemString)
		local future = nil
		if ItemInfo.IsCommodity(itemString) then
			local itemId = ItemString.ToId(itemString)
			future = AuctionHouseWrapper.ConfirmCommoditiesPurchase(itemId, quantity)
		else
			local _, auctionId = subRow:GetListingInfo()
			future = AuctionHouseWrapper.PlaceBid(auctionId, bidBuyout)
			quantity = 1
		end
		return future
	end
end

---Gets the progress of the scan.
---@return number progress
---@return boolean? paused
function AuctionScanManager:GetProgress()
	local numQueries = self:GetNumQueries()
	if self._queriesScanned == numQueries then
		return 1, self._paused
	end
	local searchProgress = nil
	if self._queryDidBrowse and not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() then
		local rowProgress = self._numSearchRows > 0 and self._numSearchedRows / self._numSearchRows or 0
		searchProgress = rowProgress * (1 - BROWSE_PROGRESS) + BROWSE_PROGRESS
	else
		searchProgress = 0
	end
	local queryStep = 1 / numQueries
	local progress = min((self._queriesScanned + searchProgress) * queryStep, 1)
	return progress, self._paused
end

---Cancels the scan.
function AuctionScanManager:Cancel()
	self._cancelled = true
	if self._scanQuery then
		self._scanQuery:CancelBrowseOrSearch()
		self._scanQuery = nil
	end
end

---Sets whether or not the scan is paused.
---@param paused boolean
function AuctionScanManager:SetPaused(paused)
	self._shouldPause = paused
	if self._scanQuery then
		self._scanQuery:CancelBrowseOrSearch()
		self._scanQuery = nil
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
function AuctionScanManager:_FindAuctionThreaded(findSubRow, noSeller)
	assert(Threading.IsThreadContext())
	wipe(self._findResult)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		return self:_FindAuctionThreadedClassic(findSubRow, noSeller)
	else
		return self:_FindAuctionThreadedRetail(findSubRow)
	end
end

---@private
function AuctionScanManager:_HandleFindThreadKilled()
	self._scanQuery = nil
	if self._findQuery then
		self._findQuery:Release()
		self._findQuery = nil
	end
end

function AuctionScanManager.__private:_SendActionScript(script)
	assert(ACTION_SCRIPTS[script])
	local action = self._scriptAction[script]
	if not self._manager or not action then
		return
	end
	self._manager:ProcessAction(action)
end

function AuctionScanManager.__private:_AddQuery(query)
	query:SetResolveSellers(self._resolveSellers)
	query:SetCallback(self._queryCallback)
	tinsert(self._queries, query)
end

function AuctionScanManager.__private:_Pause()
	if not self._shouldPause then
		return
	end
	self._paused = true
	self:_NotifyProgressUpdate()
	self:_SendActionScript("OnCurrentSearchChanged")
	if self._currentSearchChangedCallback then
		self:_currentSearchChangedCallback()
	end
	while self._shouldPause do ---@diagnostic disable-line: redundant-condition
		Threading.Yield(true)
	end
	self._paused = false
	self:_NotifyProgressUpdate()
	self:_SendActionScript("OnCurrentSearchChanged")
	if self._currentSearchChangedCallback then
		self:_currentSearchChangedCallback()
	end
end

function AuctionScanManager.__private:_NotifyProgressUpdate()
	self:_SendActionScript("OnProgressUpdate")
	if self._onProgressUpdateHandler then
		self:_onProgressUpdateHandler()
	end
end

---@param query AuctionQuery
function AuctionScanManager.__private:_ProcessQuery(query)
	local prevMaxBrowseId = 0
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		for _, row in query:BrowseResultsIterator() do
			prevMaxBrowseId = max(prevMaxBrowseId, row:GetMinBrowseId())
		end
	end

	-- run the browse query
	self._queryDidBrowse = false
	self._numSearchRows = 0
	self._numSearchedRows = 0
	while not self:_DoBrowse(query) do
		if self._shouldPause then
			-- this browse failed due to a pause request, so try again after we're resumed
			self:_Pause()
			-- wipe the browse results since we're going to do another search
			query:WipeBrowseResults()
		else
			return false, 0
		end
	end
	self._queryDidBrowse = true
	self:_NotifyProgressUpdate()

	local numNewResults = 0
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		for _, row in query:BrowseResultsIterator() do
			if row:GetMinBrowseId() > prevMaxBrowseId then
				numNewResults = numNewResults + row:GetNumSubRows()
			end
		end
		return true, numNewResults
	end

	local rows = Threading.AcquireSafeTempTable() ---@type table<string,AuctionRow>
	for baseItemString, row in query:BrowseResultsIterator() do
		rows[baseItemString] = row
		self._numSearchRows = self._numSearchRows + 1
	end
	while true do
		local baseItemString, row = self:_GetNextSearchRow(query, rows)
		if not baseItemString or not row then
			break
		end
		self:_SendActionScript("OnCurrentSearchChanged")
		if self._currentSearchChangedCallback then
			self:_currentSearchChangedCallback(baseItemString)
		end
		-- store all the existing auctionIds so we can see what changed
		local prevAuctionIds = Threading.AcquireSafeTempTable()
		for _, subRow in row:SubRowIterator() do
			local _, auctionId = subRow:GetListingInfo()
			assert(not prevAuctionIds[auctionId])
			prevAuctionIds[auctionId] = true
		end
		-- send the query for this item
		while not self:_DoSearch(query, row, false) and query:GetResultRow(baseItemString) == row do
			if self._shouldPause then
				-- this search failed due to a pause request, so try again after we're resumed
				self:_Pause()
				if query:GetResultRow(baseItemString) ~= row then
					break
				end
				-- wipe the search results since we're going to do another search
				row:WipeSearchResults()
				self._queryCallback(query, row)
			else
				TempTable.Release(prevAuctionIds)
				TempTable.Release(rows)
				return false, numNewResults
			end
		end

		if query:GetResultRow(baseItemString) == row then
			local numSubRows = row:GetNumSubRows()
			for _, subRow in row:SubRowIterator() do
				local _, auctionId = subRow:GetListingInfo()
				if not prevAuctionIds[auctionId] then
					numNewResults = numNewResults + 1
				end
			end
			if numSubRows == 0 then
				-- Remove this row since there are no search results
				query:RemoveResultRow(row)
			end
		end
		TempTable.Release(prevAuctionIds)

		self._numSearchedRows = self._numSearchedRows + 1
		self:_NotifyProgressUpdate()
		self:_Pause()
		Threading.Yield()
	end
	TempTable.Release(rows)
	return true, numNewResults
end

---@param query AuctionQuery
---@param rows table<string,AuctionRow>
---@return string? baseItemString
---@return AuctionRow? row
function AuctionScanManager.__private:_GetNextSearchRow(query, rows)
	while true do
		local baseItemString, row = nil, nil
		if self._nextSearchItemFunction then
			baseItemString = self._nextSearchItemFunction()
			row = baseItemString and rows[baseItemString]
		end
		if not row then
			baseItemString, row = next(rows)
		end
		if not row then
			return nil, nil
		end
		rows[baseItemString] = nil
		if query:GetResultRow(baseItemString) == row then
			return baseItemString, row
		end
		self._numSearchRows = self._numSearchRows - 1
	end
end

---@param query AuctionQuery
function AuctionScanManager.__private:_DoBrowse(query)
	return self:_DoBrowseSearchHelper(query, query:Browse())
end

---@param query AuctionQuery
---@param row AuctionRow
---@param useCachedData boolean
function AuctionScanManager.__private:_DoSearch(query, row, useCachedData)
	return self:_DoBrowseSearchHelper(query, query:Search(row, useCachedData))
end

---@param query AuctionQuery
---@param future? Future
function AuctionScanManager.__private:_DoBrowseSearchHelper(query, future)
	if not future then
		return false
	end
	self._scanQuery = query
	local result = Threading.WaitForFuture(future)
	self._scanQuery = nil
	Threading.Yield()
	return result
end

function AuctionScanManager.__private:_FindAuctionThreadedClassic(row, noSeller)
	self._cancelled = false
	-- Make sure we're not in the middle of a query where the results are going to change on us
	Threading.WaitForFunction(AuctionHouse.CanSendQuery)

	-- Search the current page for the auction
	if self:_FindAuctionOnCurrentPage(row, noSeller) then
		Log.Info("Found on current page")
		return self._findResult
	end

	-- Search for the item
	local page, maxPage = 0, nil
	while true do
		-- Query the AH
		if self._findQuery then
			self._findQuery:Release()
		end
		local itemString = row:GetItemString()
		local level = ItemInfo.GetMinLevel(itemString)
		local quality = ItemInfo.GetQuality(itemString)
		assert(level and quality)
		self._findQuery = AuctionQuery.Get()
			:SetStr(ItemInfo.GetName(itemString), true)
			:SetQualityRange(quality, quality)
			:SetLevelRange(level, level)
			:SetClass(ItemInfo.GetClassId(itemString), ItemInfo.GetSubClassId(itemString))
			:SetItems(itemString)
			:SetResolveSellers(not noSeller)
			:SetPage(page)
		local filterSuccess = self:_DoBrowse(self._findQuery)
		self._findQuery:Release()
		self._findQuery = nil
		if not filterSuccess then
			break
		end
		-- search this page for the row
		if self:_FindAuctionOnCurrentPage(row, noSeller) then
			Log.Info("Found auction (%d)", page)
			return self._findResult
		elseif self._cancelled then
			break
		end

		local numPages = AuctionHouse.GetNumPages()
		local canBeLater = self:_FindAuctionCanBeOnLaterPage(row)
		maxPage = maxPage or numPages - 1
		if not canBeLater and page < maxPage then
			maxPage = page
		end
		if canBeLater and page < maxPage then
			Log.Info("Trying next page (%d)", page + 1)
			page = page + 1
		else
			return
		end
	end
end

function AuctionScanManager.__private:_FindAuctionCanBeOnLaterPage(row)
	local pageAuctions = AuctionHouse.GetNumAuctions()
	if pageAuctions == 0 then
		-- There are no auctions on this page, so it cannot be on a later one
		return false
	end
	local _, _, stackSize, _, buyout, seller = AuctionHouse.GetBrowseResult(pageAuctions)

	local itemBuyout = buyout and (buyout > 0) and floor(buyout / stackSize) or 0
	local _, rowItemBuyout = row:GetBuyouts()
	if rowItemBuyout > itemBuyout then
		-- Item must be on a later page since it would be sorted after the last auction on this page
		return true
	elseif rowItemBuyout < itemBuyout then
		-- Item cannot be on a later page since it would be sorted before the last auction on this page
		return false
	end

	local rowStackSize = row:GetQuantities()
	if rowStackSize > stackSize then
		-- Item must be on a later page since it would be sorted after the last auction on this page
		return true
	elseif rowStackSize < stackSize then
		-- Item cannot be on a later page since it would be sorted before the last auction on this page
		return false
	end

	seller = seller or "?"
	local rowSeller = row:GetOwnerInfo()
	if rowSeller > seller then
		-- Item must be on a later page since it would be sorted after the last auction on this page
		return true
	elseif rowSeller < seller then
		-- Item cannot be on a later page since it would be sorted before the last auction on this page
		return false
	end

	-- All the things we are sorting on are the same, so the auction could be on a later page
	return true
end

function AuctionScanManager.__private:_FindAuctionOnCurrentPage(subRow, noSeller)
	local found = false
	for i = 1, AuctionHouse.GetNumAuctions() do
		if subRow:EqualsIndex(i, noSeller) then
			tinsert(self._findResult, i)
			found = true
		end
	end
	return found
end

---@param findSubRow AuctionSubRow
function AuctionScanManager.__private:_FindAuctionThreadedRetail(findSubRow)
	assert(findSubRow:IsSubRow())
	self._cancelled = false

	local row = findSubRow:GetResultRow()
	local findHash, findHashNoSeller = findSubRow:GetHashes()

	if not self:_DoSearch(row:GetQuery(), row, false) then
		return nil
	end
	local result = nil
	-- first try to find a subRow with a full matching hash
	for _, subRow in row:SubRowIterator() do
		local quantity, numAuctions = subRow:GetQuantities()
		local hash = subRow:GetHashes()
		if hash == findHash then
			result = (result or 0) + quantity * numAuctions
		end
	end
	if result then
		return result
	end
	-- next try to find the first subRow with a matching no-seller hash
	local firstHash = nil
	for _, subRow in row:SubRowIterator() do
		local quantity, numAuctions = subRow:GetQuantities()
		local hash, hashNoSeller = subRow:GetHashes()
		if (not firstHash or hash == firstHash) and hashNoSeller == findHashNoSeller then
			firstHash = hash
			result = (result or 0) + quantity * numAuctions
		end
	end
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueryIteratorHelper(tbl, index)
	index = index + 1
	if index > #tbl then
		return
	end
	return index, tbl[index]
end

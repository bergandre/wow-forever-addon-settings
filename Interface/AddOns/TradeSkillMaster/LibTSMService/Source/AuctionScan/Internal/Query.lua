-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionQuery = LibTSMService:DefineInternalClassType("AuctionQuery")
local AuctionRow = LibTSMService:IncludeClassType("AuctionRow")
local Scanner = LibTSMService:Include("AuctionScan.Scanner")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Iterator = LibTSMService:From("LibTSMUtil"):Include("BaseType.Iterator")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Range = LibTSMService:From("LibTSMUtil"):IncludeClassType("Range")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local AuctionHouseWrapper = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local private = {
	objectPool = ObjectPool.New("AUCTION_SCAN_QUERY", AuctionQuery, 1),
	itemKeysTemp = {},
	changedBrowseResultsTemp = {},
}
local ITEM_SPECIFIC = newproxy(false)
local ITEM_BASE = newproxy(false)

---@alias AuctionQueryCallbackFunc fun(query: AuctionQuery, row?: AuctionRow, changedBaseItemStrings?: table<string,true>)



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets an auction query.
---@return AuctionQuery
function AuctionQuery.__static.Get()
	return private.objectPool:Get()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function AuctionQuery:__init()
	self._str = ""
	self._strLower = ""
	self._strMatch = ""
	self._exact = false
	self._qualityRange = Range.AcquireStartEnd(0, math.huge)
	self._levelRange = Range.AcquireStartEnd(-math.huge, math.huge)
	self._itemLevelRange = Range.AcquireStartEnd(-math.huge, math.huge)
	self._class = nil
	self._subClass = nil
	self._invType = nil
	self._classFilter1 = {}
	self._classFilter2 = {}
	self._usable = false
	self._uncollected = false
	self._upgrades = false
	self._unlearned = false
	self._canLearn = false
	self._minPrice = 0
	self._maxPrice = math.huge
	self._items = {}
	self._customFilters = {}
	self._isBrowseDoneFunc = nil
	self._specifiedPage = nil ---@type "FIRST"|"LAST"|number|nil
	self._resolveSellers = false
	self._callback = nil ---@type AuctionQueryCallbackFunc?
	self._browseResults = {} ---@type table<string,AuctionRow?>
	self._changedBrowseResults = {} ---@type table<string,true>
	self._page = 0
end

function AuctionQuery:_Release()
	self._str = ""
	self._strLower = ""
	self._strMatch = ""
	self._exact = false
	self._qualityRange:SetStartEnd(0, math.huge)
	self._levelRange:SetStartEnd(-math.huge, math.huge)
	self._itemLevelRange:SetStartEnd(-math.huge, math.huge)
	self._class = nil
	self._subClass = nil
	self._invType = nil
	wipe(self._classFilter1)
	wipe(self._classFilter2)
	self._usable = false
	self._uncollected = false
	self._upgrades = false
	self._unlearned = false
	self._canLearn = false
	self._minPrice = 0
	self._maxPrice = math.huge
	wipe(self._items)
	wipe(self._customFilters)
	self._isBrowseDoneFunc = nil
	self._specifiedPage = nil
	self._resolveSellers = false
	self._callback = nil
	for baseItemString, row in pairs(self._browseResults) do
		self._browseResults[baseItemString] = nil
		private.ReleaseRow(row)
	end
	wipe(self._changedBrowseResults)
	self._page = 0
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Release the query.
function AuctionQuery:Release()
	self:_Release()
	private.objectPool:Recycle(self)
end

---Sets the string to query on.
---@param str? string
---@param exact? boolean
---@return self
function AuctionQuery:SetStr(str, exact)
	self._str = str or ""
	self._strLower = strlower(self._str)
	self._strMatch = String.Escape(self._strLower)
	self._exact = exact or false
	return self
end

---Sets the item quality range.
---@param minQuality? number
---@param maxQuality? number
---@return self
function AuctionQuery:SetQualityRange(minQuality, maxQuality)
	self._qualityRange:SetStartEnd(minQuality or 0, maxQuality or math.huge)
	return self
end

---Sets the level range.
---@param minLevel? number
---@param maxLevel? number
---@return self
function AuctionQuery:SetLevelRange(minLevel, maxLevel)
	self._levelRange:SetStartEnd(minLevel or -math.huge, maxLevel or math.huge)
	return self
end

---Gets the item level range.
---@param minItemLevel? number
---@param maxItemLevel? number
---@return self
function AuctionQuery:SetItemLevelRange(minItemLevel, maxItemLevel)
	self._itemLevelRange:SetStartEnd(minItemLevel or -math.huge, maxItemLevel or math.huge)
	return self
end

---Sets the class filter.
---@param class? number
---@param subClass? number
---@param invType? number
---@return self
function AuctionQuery:SetClass(class, subClass, invType)
	self._class = class or nil
	self._subClass = subClass or nil
	self._invType = invType or nil
	return self
end

---Sets the usable filter.
---@param usable? boolean
---@return self
function AuctionQuery:SetUsable(usable)
	self._usable = usable or false
	return self
end

---Sets the uncollected filter.
---@param uncollected? boolean
---@return self
function AuctionQuery:SetUncollected(uncollected)
	self._uncollected = uncollected or false
	return self
end

---Sets the upgrades filter.
---@param upgrades? boolean
---@return self
function AuctionQuery:SetUpgrades(upgrades)
	self._upgrades = upgrades or false
	return self
end

---Sets the unlearned filter.
---@param unlearned? boolean
---@return self
function AuctionQuery:SetUnlearned(unlearned)
	self._unlearned = unlearned or false
	return self
end

---Sets the can learn filter.
---@param canLearn? boolean
---@return self
function AuctionQuery:SetCanLearn(canLearn)
	self._canLearn = canLearn or false
	return self
end

---Sets the price range.
---@param minPrice? number
---@param maxPrice? number
---@return self
function AuctionQuery:SetPriceRange(minPrice, maxPrice)
	self._minPrice = minPrice or 0
	self._maxPrice = maxPrice or math.huge
	return self
end

---Sets the list of items to query for.
---@param items string[]|string|nil A list of item strings, a single item string, or nil for no items
---@return self
function AuctionQuery:SetItems(items)
	wipe(self._items)
	if type(items) == "table" then
		for _, itemString in ipairs(items) do
			local baseItemString = ItemString.GetBaseFast(itemString)
			self._items[itemString] = ITEM_SPECIFIC
			if baseItemString ~= itemString then
				self._items[baseItemString] = self._items[baseItemString] or ITEM_BASE
			end
		end
	elseif type(items) == "string" then
		local itemString = items
		local baseItemString = ItemString.GetBaseFast(itemString)
		self._items[itemString] = ITEM_SPECIFIC
		if baseItemString ~= itemString then
			self._items[baseItemString] = self._items[baseItemString] or ITEM_BASE
		end
	end
	return self
end

---Adds a custom filter function.
---@param func fun(query: self, row: AuctionRow|AuctionSubRow, isSubRow: boolean, itemKey: ItemKey): boolean
---@return self
function AuctionQuery:AddCustomFilter(func)
	self._customFilters[func] = true
	return self
end

---Sets a function to call for checking if we're done with a browse query.
---@param func fun(query: self): boolean
---@return self
function AuctionQuery:SetIsBrowseDoneFunction(func)
	self._isBrowseDoneFunc = func
	return self
end

---Sets the page to query for.
---@param page number|string|nil The specific page number or "FIRST"/"LAST" for relative pages
---@return self
function AuctionQuery:SetPage(page)
	if page == nil then
		self._specifiedPage = nil
	elseif type(page) == "number" or page == "FIRST" or page == "LAST" then
		assert(LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic())
		self._specifiedPage = page
	else
		error("Invalid page: "..tostring(page))
	end
	return self
end

---Sets whether or not to resolve seller names.
---@param resolveSellers boolean
---@return self
function AuctionQuery:SetResolveSellers(resolveSellers)
	self._resolveSellers = resolveSellers
	return self
end

---Sets a callback for the results of the query changing.
---@param callback AuctionQueryCallbackFunc The callback function
---@return self
function AuctionQuery:SetCallback(callback)
	self._callback = callback
	return self
end

---Starts the browse query.
---@return Future
function AuctionQuery:Browse()
	local noScan = false
	if not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() then
		local numItems = 0
		for _, itemType in pairs(self._items) do
			if itemType == ITEM_SPECIFIC then
				numItems = numItems + 1
			end
		end
		if numItems > 0 and numItems < 500 then
			-- it's faster to just issue individual item searches instead of a browse query
			noScan = true
		end
	end

	if noScan then
		assert(not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic())
		assert(not next(private.itemKeysTemp))
		for itemString in pairs(self._items) do
			if itemString == ItemString.GetBaseFast(itemString) then
				local itemId, battlePetSpeciesId = nil, nil
				if ItemString.IsPet(itemString) then
					itemId = ItemString.ToId(ItemString.GetPetCage())
					battlePetSpeciesId = ItemString.ToId(itemString)
				else
					itemId = ItemString.ToId(itemString)
					battlePetSpeciesId = 0
				end
				tinsert(private.itemKeysTemp, AuctionHouse.MakeItemKey(itemId, battlePetSpeciesId))
			end
		end
		local future = Scanner.BrowseNoScan(self, private.itemKeysTemp, self._callback)
		wipe(private.itemKeysTemp)
		return future
	else
		self._page = 0
		return Scanner.Browse(self, self._resolveSellers, self._callback)
	end
end

---Iterates over the sub rows for an item.
---@param itemString string The item string
---@return IteratorObject<fun(): number, AuctionSubRow> @Iterator with fields: `index`, `subRow`
function AuctionQuery:ItemSubRowIterator(itemString)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local row = self._browseResults[baseItemString]
	if not row then
		return Iterator.AcquireEmpty()
	end

	local levelItemString = ItemString.ToLevel(itemString)
	local result = TempTable.Acquire()
	for _, subRow in row:SubRowIterator() do
		if private.SubRowIteratorShouldInclude(baseItemString, levelItemString, itemString, subRow) then
			tinsert(result, subRow)
		end
	end
	return Iterator.Acquire(ipairs(result))
		:SetCleanupFunc(TempTable.Release)
end

---Returns whether or not there are sub rows for a given item.
---@param itemString string The item string
---@return boolean
function AuctionQuery:HasItemSubRow(itemString)
	local iter = self:ItemSubRowIterator(itemString)
	return iter:GetValueAndRelease() and true or false
end

---Gets the cheapest sub row for an item.
---@param itemString string The item string
---@return AuctionSubRow?
function AuctionQuery:GetCheapestSubRow(itemString)
	assert(not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic())
	local cheapest, cheapestItemBuyout = nil, nil
	for _, subRow in self:ItemSubRowIterator(itemString) do
		local quantity = subRow:GetQuantities()
		local _, numOwnerItems = subRow:GetOwnerInfo()
		local _, itemBuyout = subRow:GetBuyouts()
		if numOwnerItems ~= quantity and itemBuyout < (cheapestItemBuyout or math.huge) then
			cheapest = subRow
			cheapestItemBuyout = itemBuyout
		end
	end
	return cheapest
end

---Iterates over the browse results
---@return fun(): string, AuctionRow @Iterator with fields: `baseItemString`, `row`
---@return table
function AuctionQuery:BrowseResultsIterator()
	return pairs(self._browseResults)
end

---Gets the row for an item from the results.
---@param baseItemString string The base item string
---@return AuctionRow?
function AuctionQuery:GetResultRow(baseItemString)
	return self._browseResults[baseItemString]
end

---Removes a row from the results.
---@param row AuctionRow The row to remove
function AuctionQuery:RemoveResultRow(row)
	local baseItemString = row:GetBaseItemString()
	assert(self._browseResults[baseItemString])
	self._browseResults[baseItemString] = nil
	private.ReleaseRow(row)
	if self._callback then
		private.changedBrowseResultsTemp[baseItemString] = true
		self:_callback(nil, private.changedBrowseResultsTemp)
		wipe(private.changedBrowseResultsTemp)
	end
end

---Searches for an auction row.
---@param row AuctionRow The row to search for
---@param useCachedData boolean Use cached data for the search
---@return Future
function AuctionQuery:Search(row, useCachedData)
	assert(not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic())
	assert(self._browseResults)
	return Scanner.Search(self, self._resolveSellers, useCachedData, row, self._callback)
end

---Cancels the current browse or search.
function AuctionQuery:CancelBrowseOrSearch()
	Scanner.Cancel()
end

---Iterates over the items involved in the query.
---@return fun(): string @Iterator with fields: `itemString`
---@return table
function AuctionQuery:ItemIterator()
	return private.ItemIteratorHelper, self._items
end

---Wipes the browse results.
function AuctionQuery:WipeBrowseResults()
	for baseItemString, row in pairs(self._browseResults) do
		self._browseResults[baseItemString] = nil
		private.ReleaseRow(row)
	end
	wipe(self._changedBrowseResults)
	if self._callback then
		self:_callback()
	end
end



-- ============================================================================
-- Private Class Methods (Called by the Scanner Code)
-- ============================================================================

function AuctionQuery:_SetSort()
	return AuctionHouseWrapper.SetSort(type(self._specifiedPage) == "string")
end

function AuctionQuery:_SendWowQuery()
	local minLevel, maxLevel = self._levelRange:GetValues()
	minLevel = minLevel ~= -math.huge and minLevel or nil
	maxLevel = maxLevel ~= math.huge and maxLevel or nil
	local minQuality, maxQuality = self._qualityRange:GetValues()
	if self._specifiedPage == "LAST" then
		self._page = max(AuctionHouse.GetNumPages() - 1, 0)
	elseif self._specifiedPage == "FIRST" then
		self._page = 0
	elseif self._specifiedPage then
		self._page = self._specifiedPage
	end
	return AuctionHouseWrapper.SendQuery(self._str, self._class, self._subClass, self._invType, minLevel, maxLevel, minQuality, maxQuality, self._uncollected, self._usable, self._upgrades, self._exact, self._page --[[@as number?]])
end

function AuctionQuery:_IsFiltered(row, isSubRow, itemKey)
	local baseItemString = row:GetBaseItemString()
	local itemString = row:GetItemString()
	assert(baseItemString)
	local name, quality, itemLevel = row:GetItemInfo(itemKey)
	local _, itemBuyout, minItemBuyout = row:GetBuyouts(itemKey)
	if row:IsSubRow() and itemBuyout == 0 then
		_, itemBuyout = row:GetBidInfo()
	end

	if next(self._items) then
		if not self._items[baseItemString] then
			return true
		end
		local levelItemString = itemString and ItemString.ToLevel(itemString)
		if isSubRow and itemString and self._items[itemString] ~= ITEM_SPECIFIC and self._items[levelItemString] ~= ITEM_SPECIFIC and self._items[baseItemString] ~= ITEM_SPECIFIC then
			-- this is a sub row and we're not looking for this item
			return true
		elseif not isSubRow and itemString and not self._items[itemString] then
			-- this is a base row but the base item doesn't match any item we're interested in
			return true
		end
	end
	if self._str ~= "" and name then
		name = strlower(name)
		if not strmatch(name, self._strMatch) or (self._exact and name ~= self._strLower) then
			return true
		end
	end
	if self._levelRange:GetStart() ~= -math.huge or self._levelRange:GetEnd() ~= math.huge then
		local minLevel = ItemString.IsPet(baseItemString) and itemLevel or ItemInfo.GetMinLevel(baseItemString)
		assert(minLevel)
		if not self._levelRange:Includes(minLevel) then
			return true
		end
	end
	if itemLevel and not self._itemLevelRange:Includes(itemLevel) then
		return true
	end
	if quality and not self._qualityRange:Includes(quality) then
		return true
	end
	if self._class and ItemInfo.GetClassId(baseItemString) ~= self._class then
		return true
	end
	if self._subClass and ItemInfo.GetSubClassId(baseItemString) ~= self._subClass then
		return true
	end
	if self._invType and ItemInfo.GetInvSlotId(baseItemString) ~= self._invType then
		return true
	end
	if self._unlearned and CanIMogIt:PlayerKnowsTransmog(ItemInfo.GetLink(baseItemString)) then
		return true
	end
	if self._canLearn and not CanIMogIt:CharacterCanLearnTransmog(ItemInfo.GetLink(baseItemString)) then
		return true
	end
	if itemBuyout and (itemBuyout < self._minPrice or itemBuyout > self._maxPrice) then
		return true
	end
	if minItemBuyout and minItemBuyout > self._maxPrice then
		return true
	end
	for func in pairs(self._customFilters) do
		if func(self, row, isSubRow, itemKey) then
			return true
		end
	end
	return false
end

function AuctionQuery:_BrowseIsDone(isRetry)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		local numPages = AuctionHouse.GetNumPages()
		if self._specifiedPage then
			if isRetry then
				return false
			end
			-- check if we're on the right page
			local specifiedPage = (self._specifiedPage == "FIRST" and 0) or (self._specifiedPage == "LAST" and numPages - 1) or self._specifiedPage
			return self._page == specifiedPage
		elseif self._isBrowseDoneFunc and self:_isBrowseDoneFunc() then
			return true
		else
			return self._page >= numPages
		end
	else
		if self._isBrowseDoneFunc and self:_isBrowseDoneFunc() then
			return true
		end
		return AuctionHouse.HasFullBrowseResults()
	end
end

function AuctionQuery:_BrowseIsPageValid()
	if not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() then
		return true
	end
	if self._specifiedPage then
		return self:_BrowseIsDone()
	else
		return true
	end
end

function AuctionQuery:_BrowseRequestMore(isRetry)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		if self._specifiedPage then
			return self:_SendWowQuery()
		end
		if not isRetry then
			self._page = self._page + 1
		end
		return self:_SendWowQuery()
	else
		return AuctionHouseWrapper.RequestMoreBrowseResults()
	end
end

function AuctionQuery:_OnSubRowRemoved(row)
	local baseItemString = row:GetBaseItemString()
	assert(row == self._browseResults[baseItemString])
	if row:GetNumSubRows() == 0 then
		self._browseResults[baseItemString] = nil
		private.ReleaseRow(row)
		row = nil
	end
	if self._callback then
		self:_callback(row)
	end
end

---@private
function AuctionQuery:_GetBrowseResults(baseItemString)
	local row = self._browseResults[baseItemString]
	assert(row)
	return row
end

---@private
function AuctionQuery:_ProcessBrowseResult(baseItemString, ...)
	self._changedBrowseResults[baseItemString] = true
	if self._browseResults[baseItemString] then
		self._browseResults[baseItemString]:Merge(...)
	else
		self._browseResults[baseItemString] = AuctionRow.Get(self, ...)
	end
end

---@private
function AuctionQuery:_GetChangedBrowseResults()
	return self._changedBrowseResults
end

---@private
function AuctionQuery:_WipeChangedBrowseResults()
	wipe(self._changedBrowseResults)
end

---@private
function AuctionQuery:_FilterBrowseResults()
	local numRemoved = 0
	for baseItemString in pairs(self._changedBrowseResults) do
		local row = self._browseResults[baseItemString]
		-- Filter the itemKeys we don't care about and rows which don't match the query
		if row and (row:IsFiltered(self) or ((LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic()) and row:FilterSubRows(self))) then
			private.ReleaseRow(row)
			self._browseResults[baseItemString] = nil
			numRemoved = numRemoved + 1
		end
	end
	return numRemoved
end

---@private
function AuctionQuery:_PopulateBrowseData(missingItemIds)
	local success = true
	local numRemoved = 0
	for baseItemString in pairs(self._changedBrowseResults) do
		local row = self._browseResults[baseItemString]
		if row then
			local hasInfo, giveUp = row:PopulateBrowseData(missingItemIds)
			if not hasInfo and giveUp then
				-- Remove this row completely
				private.ReleaseRow(row)
				self._browseResults[baseItemString] = nil
				numRemoved = numRemoved + 1
			elseif not hasInfo then
				success = false
				-- Keep going so we issue requests for all pending rows
			end
		end
	end
	return success, numRemoved
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ReleaseRow(row)
	Scanner.HandleRowReleased(row)
	row:Release()
end

function private.SubRowIteratorShouldInclude(baseItemString, levelItemString, itemString, subRow)
	if itemString == baseItemString then
		return subRow:GetBaseItemString() == itemString
	elseif itemString == levelItemString then
		return ItemString.ToLevel(subRow:GetItemString()) == itemString
	else
		return subRow:GetItemString() == itemString
	end
end

function private.ItemIteratorHelper(items, index)
	while true do
		local itemString, itemType = next(items, index)
		if not itemString then
			return
		elseif itemType == ITEM_SPECIFIC then
			return itemString
		end
		index = itemString
	end
end

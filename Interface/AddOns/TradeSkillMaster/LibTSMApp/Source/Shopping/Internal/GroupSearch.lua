-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local GroupSearch = LibTSMApp:DefineInternalClassType("GroupSearch")
local GroupSearchContext = LibTSMApp:IncludeClassType("GroupSearchContext")
local CustomPrice = LibTSMApp:Include("Price.CustomPrice")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local ShoppingOperation = LibTSMApp:From("LibTSMSystem"):Include("ShoppingOperation")
local private = {
	created = false,
	removeTemp = {},
}



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function GroupSearch:__init()
	-- This is a singleton class since it contains a thread
	assert(not private.created)
	private.created = true
	self._scanThreadId = Threading.New("SHOPPING_GROUP_SEARCH", self:__closure("_ScanThread"))
	self._searchContext = GroupSearchContext(self, self._scanThreadId, private.MarketValueFunction)
	self._itemListTemp = {}
	self._queries = {}
	self._maxQuantity = {}
	self._seenMaxPrice = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the search context for a group search.
---@param groupList GroupPathValue[] The list of group paths
---@return AuctionSearchContext
function GroupSearch:GetSearchContext(groupList)
	return self._searchContext:SetScanContext(L["Group Search"], groupList, nil, L["Max Price"])
end

---Gets the max quantity of an item which can be bought.
---@param itemString string The item
---@return number?
function GroupSearch:GetMaxCanBuy(itemString)
	return self._maxQuantity[Group.TranslateItemString(itemString)]
end

---Handles a purchase of an item.
---@param itemString string The item which was bought
---@param quantity number The quantity bought
function GroupSearch:HandlePurchase(itemString, quantity)
	itemString = Group.TranslateItemString(itemString)
	if not self._maxQuantity[itemString] then
		return
	end

	self._maxQuantity[itemString] = self._maxQuantity[itemString] - quantity
	if self._maxQuantity[itemString] <= 0 then
		self._maxQuantity[itemString] = nil
		for _, query in ipairs(self._queries) do
			for _, row in query:BrowseResultsIterator() do
				if row:HasItemInfo() then
					assert(not next(private.removeTemp))
					for _, subRow in row:SubRowIterator() do
						local subRowItemString = subRow:GetItemString()
						if subRowItemString and Group.TranslateItemString(subRowItemString) == itemString then
							tinsert(private.removeTemp, subRow)
						end
					end
					for _, subRow in ipairs(private.removeTemp) do
						row:RemoveSubRow(subRow)
					end
					wipe(private.removeTemp)
				end
			end
		end
	end
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

---@param auctionScan AuctionScanManager
---@param groupList GroupPathValue[]
function GroupSearch.__private:_ScanThread(auctionScan, groupList)
	wipe(self._itemListTemp)
	wipe(self._maxQuantity)
	wipe(self._queries)
	wipe(self._seenMaxPrice)

	-- Create the list of items, and add filters for them
	for _, groupPath in ipairs(groupList) do
		for _, itemString in Group.ItemIterator(groupPath) do
			local isValid, maxQuantity = private.GetRestockQuantity(itemString)
			if isValid then
				self._maxQuantity[itemString] = maxQuantity
				tinsert(self._itemListTemp, itemString)
			end
		end
		Threading.Yield()
	end
	if #self._itemListTemp == 0 then
		return false
	end

	for _, query in auctionScan:AddItemListQueriesThreaded(self._itemListTemp) do
		query:SetIsBrowseDoneFunction(self:__closure("_QueryIsBrowseDoneFunction"))
		query:AddCustomFilter(self:__closure("_QueryFilter"))
		tinsert(self._queries, query)
	end
	wipe(self._itemListTemp)

	-- Run the scan
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
	return true
end

---@param query AuctionQuery
function GroupSearch.__private:_QueryIsBrowseDoneFunction(query)
	local isDone = true
	for itemString in query:ItemIterator() do
		if ShoppingOperation.ShouldShowAboveMaxPrice(itemString) then
			-- need to scan all the auctions
			isDone = false
		elseif not self._seenMaxPrice[itemString] then
			-- we haven't seen any auctions above the max price, so need to keep scanning
			isDone = false
		end
	end
	return isDone
end

---@param query AuctionQuery
---@param row AuctionRow|AuctionSubRow
function GroupSearch.__private:_QueryFilter(query, row)
	local baseItemString = row:GetBaseItemString()
	local itemString = row:GetItemString()
	local auctionBuyout, itemBuyout, minItemBuyout = row:GetBuyouts()
	itemBuyout = itemBuyout or minItemBuyout
	if not itemBuyout then
		return false
	elseif auctionBuyout == 0 then
		return true
	end
	if itemString then
		local groupItemString = Group.TranslateItemString(itemString)
		local isFiltered, aboveMax = ShoppingOperation.IsFiltered(groupItemString, itemBuyout)
		self._seenMaxPrice[groupItemString] = self._seenMaxPrice[groupItemString] or aboveMax
		return isFiltered
	else
		local allFiltered = true
		for queryItemString in query:ItemIterator() do
			if ItemString.GetBaseFast(queryItemString) == baseItemString and not ShoppingOperation.IsFiltered(queryItemString, itemBuyout) then
				allFiltered = false
			end
		end
		return allFiltered
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param row AuctionSubRow
function private.MarketValueFunction(row)
	local itemString = row:GetItemString()
	return itemString and ShoppingOperation.GetMaxPrice(Group.TranslateItemString(itemString)) or nil
end

function private.GetRestockQuantity(itemString)
	local isValid, maxQuantityOrErrType, errArg = ShoppingOperation.ValidateAndGetRestockQuantity(itemString)
	if isValid then
		return true, maxQuantityOrErrType
	end
	if maxQuantityOrErrType == ShoppingOperation.ERROR.MAX_PRICE_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		assert(errStr)
		ChatMessage.PrintUser(format(L["Your max price (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..errStr)
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		assert(errStr)
		ChatMessage.PrintUser(format(L["Your max restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..errStr)
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_INVALID_RANGE then
		ChatMessage.PrintfUser(L["Your restock quantity (%s) is invalid for %s."].." "..L["Must be between %d and %d."], errArg, ItemInfo.GetLink(itemString), ShoppingOperation.GetRestockValueRange():GetValues())
	elseif maxQuantityOrErrType ~= nil then
		error("Invalid error type: "..tostring(maxQuantityOrErrType))
	end
	return false, nil
end

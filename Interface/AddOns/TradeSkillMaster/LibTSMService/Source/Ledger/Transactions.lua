-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Transactions = LibTSMService:Init("Ledger.Transactions")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local CSV = LibTSMService:From("LibTSMUtil"):Include("Format.CSV")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local SmartMap = LibTSMService:From("LibTSMUtil"):IncludeClassType("SmartMap")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Hash = LibTSMService:From("LibTSMUtil"):Include("Util.Hash")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local Group = LibTSMService:From("LibTSMTypes"):Include("Group")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	db = nil,
	dbSummary = nil,
	dataChanged = false,
	baseStatsQuery = nil,
	levelStatsQuery = nil,
	statsQuery = nil,
	baseStatsMinTimeQuery = nil,
	levelStatsMinTimeQuery = nil,
	statsMinTimeQuery = nil,
	syncHashesThread = nil,
	isSyncHashesThreadRunning = false,
	syncHashDayCache = {},
	syncHashDayCacheIsInvalid = {},
	pendingSyncHashCharacters = {},
	filteredItemStringSmartMap = nil,
	filteredItemMode = "specific",
	dataCallbacks = CallbackRegistry.NewList(),
	syncDataCallbacks = CallbackRegistry.NewList(),
	summaryTemp = {
		sale = {
			quantity = {},
			price = {},
		},
		buy = {
			quantity = {},
			price = {},
		},
	},
	realmsTemp = {},
}
local OLD_CSV_KEYS = {
	sale = { "itemString", "stackSize", "quantity", "price", "buyer", "player", "time", "source" },
	buy = { "itemString", "stackSize", "quantity", "price", "seller", "player", "time", "source" },
}
local CSV_KEYS = { "itemString", "stackSize", "quantity", "price", "otherPlayer", "player", "time", "source" }
local COMBINE_TIME_THRESHOLD = 300 -- group transactions within 5 minutes together
local MAX_CSV_RECORDS = 55000 -- the max number of records we can store without WoW corrupting the SV file
local TRIMMED_CSV_RECORDS = 50000 -- how many records to trim to if we're over the limit (so we don't trim every time)
local ALT_REALM_CSV_LENGTH = 4000000 -- max amount of data to load for other realm than the current one
local SECONDS_PER_DAY = 24 * 60 * 60
local SYNC_FIELDS = { "type", "itemString", "stackSize", "quantity", "price", "otherPlayer", "time", "source", "saveTime" }

---@alias LedgerTransactionType "sale"|"buy"



-- ============================================================================
-- Module Loading
-- ============================================================================

Transactions:OnModuleLoad(function()
	private.filteredItemStringSmartMap = SmartMap.New("string", "string", private.FilteredItemStringLookup)
	private.db = Database.NewSchema("TRANSACTIONS_LOG")
		:AddStringField("baseItemString")
		:AddStringField("type")
		:AddStringField("itemString")
		:AddStringField("levelItemString")
		:AddNumberField("stackSize")
		:AddNumberField("quantity")
		:AddNumberField("price")
		:AddStringField("otherPlayer")
		:AddStringField("player")
		:AddNumberField("time")
		:AddStringField("source")
		:AddNumberField("saveTime")
		:AddBooleanField("isCurrentRealm")
		:AddIndex("baseItemString")
		:AddIndex("levelItemString")
		:AddIndex("time")
		:AddIndex("saveTime")
		:Commit()
	private.dbSummary = Database.NewSchema("TRANSACTIONS_SUMMARY")
		:AddUniqueStringField("itemString")
		:AddNumberField("sold")
		:AddNumberField("avgSellPrice")
		:AddNumberField("bought")
		:AddNumberField("avgBuyPrice")
		:AddNumberField("avgProfit")
		:AddNumberField("totalProfit")
		:AddNumberField("profitPct")
		:Commit()
	private.baseStatsQuery = private.db:NewOwnedQuery()
		:Equal("type", Database.BoundQueryParam())
		:Equal("baseItemString", Database.BoundQueryParam())
		:NotEqual("source", "Vendor")
	private.levelStatsQuery = private.db:NewOwnedQuery()
		:Equal("type", Database.BoundQueryParam())
		:Equal("baseItemString", Database.BoundQueryParam())
		:Equal("levelItemString", Database.BoundQueryParam())
		:NotEqual("source", "Vendor")
	private.statsQuery = private.db:NewOwnedQuery()
		:Equal("type", Database.BoundQueryParam())
		:Equal("baseItemString", Database.BoundQueryParam())
		:Equal("itemString", Database.BoundQueryParam())
		:NotEqual("source", "Vendor")
	private.baseStatsMinTimeQuery = private.db:NewOwnedQuery()
		:Equal("type", Database.BoundQueryParam())
		:Equal("baseItemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())
		:NotEqual("source", "Vendor")
	private.levelStatsMinTimeQuery = private.db:NewOwnedQuery()
		:Equal("type", Database.BoundQueryParam())
		:Equal("baseItemString", Database.BoundQueryParam())
		:Equal("levelItemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())
		:NotEqual("source", "Vendor")
	private.statsMinTimeQuery = private.db:NewOwnedQuery()
		:Equal("type", Database.BoundQueryParam())
		:Equal("baseItemString", Database.BoundQueryParam())
		:Equal("itemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())
		:NotEqual("source", "Vendor")
	private.syncHashesThread = Threading.New("TRANSACTIONS_SYNC_HASHES", private.SyncHashesThread)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for when the transaction data changes.
---@param callback fun(recordType: string, itemString?: string, maxChangedTime?: number) Callback function for when data changes
function Transactions.RegisterCallback(callback)
	private.dataCallbacks:Add(callback)
end

---Registers a callback for when the transaction sync data changes.
---@param callback fun() Callback function for when sync data changes
function Transactions.RegisterSyncCallback(callback)
	private.syncDataCallbacks:Add(callback)
end

---Loads auctions data.
---@param data table The data as a flattened table with fields: `recordType, `csvRecords`, `csvSaveTimes`, `realm`
---@param truncatedRealms string[] A table to store a list of truncated realms
function Transactions.LoadData(data, truncatedRealms)
	private.LoadData(data, truncatedRealms)
end

---Returns whether or not the data has changed.
---@return boolean
function Transactions.DataDidChange()
	return private.dataChanged
end

---Saves the transaction data.
---@return string csvSales
---@return string saveTimeSales
---@return number|nil trimmedSales
---@return string csvBuys
---@return string saveTimeBuys
---@return any|nil trimmedBuys
function Transactions.SaveData()
	local csvSales, saveTimeSales, trimmedSales = private.SaveData("sale")
	local csvBuys, saveTimeBuys, trimmedBuys = private.SaveData("buy")
	return csvSales, saveTimeSales, trimmedSales, csvBuys, saveTimeBuys, trimmedBuys
end

---Inserts an auction sale record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
---@param buyer string The buyer name
---@param timestamp number The timestamp of the sale
function Transactions.InsertAuctionSale(itemString, stackSize, price, buyer, timestamp)
	private.InsertRecord("sale", itemString, "Auction", stackSize, price, buyer, timestamp)
end

---Inserts an auction purchase record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
---@param seller string The seller name
---@param timestamp number The timestamp of the purchase
function Transactions.InsertAuctionBuy(itemString, stackSize, price, seller, timestamp)
	private.InsertRecord("buy", itemString, "Auction", stackSize, price, seller, timestamp)
end

---Inserts a COD sale record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
---@param buyer string The buyer name
---@param timestamp number The timestamp of the sale
function Transactions.InsertCODSale(itemString, stackSize, price, buyer, timestamp)
	private.InsertRecord("sale", itemString, "COD", stackSize, price, buyer, timestamp)
end

---Inserts a COD purchase record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
---@param seller string The seller name
---@param timestamp number The timestamp of the purchase
function Transactions.InsertCODBuy(itemString, stackSize, price, seller, timestamp)
	private.InsertRecord("buy", itemString, "COD", stackSize, price, seller, timestamp)
end

---Inserts a trade sale record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
---@param buyer string The buyer name
function Transactions.InsertTradeSale(itemString, stackSize, price, buyer)
	private.InsertRecord("sale", itemString, "Trade", stackSize, price, buyer, floor(LibTSMService.GetTime()))
end

---Inserts a trade purchase record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
---@param seller string The seller name
function Transactions.InsertTradeBuy(itemString, stackSize, price, seller)
	private.InsertRecord("buy", itemString, "Trade", stackSize, price, seller, floor(LibTSMService.GetTime()))
end

---Inserts a vendor sale record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
function Transactions.InsertVendorSale(itemString, stackSize, price)
	private.InsertRecord("sale", itemString, "Vendor", stackSize, price, "Merchant", floor(LibTSMService.GetTime()))
end

---Inserts a vendor purchase record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param price number The price
function Transactions.InsertVendorBuy(itemString, stackSize, price)
	private.InsertRecord("buy", itemString, "Vendor", stackSize, price, "Merchant", floor(LibTSMService.GetTime()))
end

---Creates a DB query.
---@return DatabaseQuery
function Transactions.CreateQuery()
	return private.db:NewOwnedQuery()
		:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

---Creates a raw DB query.
---@return DatabaseQuery
function Transactions.CreateRawQuery()
	return private.db:NewOwnedQuery()
end

---Removes old transactions data and returns the number of records removed.
---@param days number The max age in days
---@return number
function Transactions.RemoveOldData(days)
	private.dataChanged = true
	local numRecords = private.db:NewAutoReleaseQuery()
		:LessThan("time", LibTSMService.GetTime() - days * SECONDS_PER_DAY)
		:Equal("isCurrentRealm", true)
		:Delete()
	private.dataCallbacks:CallAll("sale")
	private.dataCallbacks:CallAll("buy")
	private.syncDataCallbacks:CallAll()
	return numRecords
end

---Gets the sale stats for an item.
---@param itemString string The item string
---@param minTime? number The minimum time
---@return (number totalAmount, number totalNum)|(nil, nil)
function Transactions.GetSaleStats(itemString, minTime)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local levelItemString = ItemString.ToLevel(itemString)
	local isBaseItemString = itemString == baseItemString
	local isLevelItemString = itemString == levelItemString
	local query = nil
	if minTime then
		if isBaseItemString then
			query = private.baseStatsMinTimeQuery:BindParams("sale", baseItemString, minTime)
		elseif isLevelItemString then
			query = private.levelStatsMinTimeQuery:BindParams("sale", baseItemString, levelItemString, minTime)
		else
			query = private.statsMinTimeQuery:BindParams("sale", baseItemString, itemString, minTime)
		end
	else
		if isBaseItemString then
			query = private.baseStatsQuery:BindParams("sale", baseItemString)
		elseif isLevelItemString then
			query = private.levelStatsQuery:BindParams("sale", baseItemString, levelItemString)
		else
			query = private.statsQuery:BindParams("sale", baseItemString, itemString)
		end
	end
	query:ResetOrderBy()
	local totalNum = query:Sum("quantity")
	if totalNum == 0 then
		return nil, nil
	end
	return query:SumOfProduct("quantity", "price"), totalNum
end

---Gets the buy stats for an item.
---@param itemString string The item string
---@param totalQuantity? number The quantity of buy data to consider
---@return (number totalAmount, number totalNum)|(nil, nil)
function Transactions.GetBuyStats(itemString, totalQuantity)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local levelItemString = ItemString.ToLevel(itemString)
	local isBaseItemString = itemString == baseItemString
	local isLevelItemString = itemString == levelItemString
	local query = nil
	if isBaseItemString then
		query = private.baseStatsQuery:BindParams("buy", baseItemString)
	elseif isLevelItemString then
		query = private.levelStatsQuery:BindParams("buy", baseItemString, levelItemString)
	else
		query = private.statsQuery:BindParams("buy", baseItemString, itemString)
	end
	query:ResetOrderBy()

	if totalQuantity then
		query:OrderBy("time", false)

		local remainingSmartQuantity = totalQuantity
		local priceSum, quantitySum = 0, 0
		for _, quantity, price in query:Iterator("quantity", "price") do
			if remainingSmartQuantity > 0 then
				quantity = min(remainingSmartQuantity, quantity)
				remainingSmartQuantity = remainingSmartQuantity - quantity
				priceSum = priceSum + price * quantity
				quantitySum = quantitySum + quantity
			end
		end
		if priceSum == 0 then
			return nil, nil
		end
		return priceSum, quantitySum
	else
		local quantitySum = query:Sum("quantity")
		if quantitySum == 0 then
			return nil, nil
		end
		local priceSum = query:SumOfProduct("quantity", "price")
		if priceSum == 0 then
			return nil, nil
		end
		return priceSum, quantitySum
	end
end

---Gets the max sale price of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetMaxSalePrice(itemString)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", "sale")
		:NotEqual("source", "Vendor")
		:OrderBy("price", false)
		:GetFirstResult("price")
end

---Gets the max buy price of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetMaxBuyPrice(itemString)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", "buy")
		:NotEqual("source", "Vendor")
		:OrderBy("price", false)
		:GetFirstResult("price")
end

---Gets the min sale price of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetMinSalePrice(itemString)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", "sale")
		:NotEqual("source", "Vendor")
		:OrderBy("price", true)
		:GetFirstResult("price")
end

---Gets the min buy price of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetMinBuyPrice(itemString)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", "buy")
		:NotEqual("source", "Vendor")
		:OrderBy("price", true)
		:GetFirstResult("price")
end

---Gets the average sale price of an item.
---@param itemString string The item string
---@return number? avgPrice
---@return number? totalNum
function Transactions.GetAverageSalePrice(itemString)
	local totalPrice, totalNum = Transactions.GetSaleStats(itemString)
	if not totalPrice or totalPrice == 0 then
		return nil, nil
	end
	return Math.Round(totalPrice / totalNum), totalNum
end

---Gets the average buy price of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetAverageBuyPrice(itemString)
	local totalPrice, totalNum = Transactions.GetBuyStats(itemString)
	return totalPrice and Math.Round(totalPrice / totalNum) or nil
end

---Gets the last sale time of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetLastSaleTime(itemString)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", "sale")
		:NotEqual("source", "Vendor")
		:OrderBy("time", false)
		:GetFirstResult("time")
end

---Gets the last buy time of an item.
---@param itemString string The item string
---@return number?
function Transactions.GetLastBuyTime(itemString)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", "buy")
		:NotEqual("source", "Vendor")
		:OrderBy("time", false)
		:GetFirstResult("time")
end

---Gets the quantity of an item.
---@param itemString string The item string
---@param timeFilter? number A time duration to filter on
---@param typeFilter LedgerTransactionType The type to query for
---@return number
function Transactions.GetQuantity(itemString, timeFilter, typeFilter)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", typeFilter)
		:If(timeFilter ~= nil)
			:GreaterThan("time", LibTSMService.GetTime() - (timeFilter or 0))
		:End()
		:Sum("quantity")
end

---Gets the average price of an item.
---@param itemString string The item string
---@param timeFilter? number A time duration to filter on
---@param typeFilter LedgerTransactionType The type to query for
---@return number
function Transactions.GetAveragePrice(itemString, timeFilter, typeFilter)
	local query = private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", typeFilter)
		:If(timeFilter ~= nil)
			:GreaterThan("time", LibTSMService.GetTime() - (timeFilter or 0))
		:End()
	local avgPrice = 0
	local totalQuantity = 0
	for _, price, quantity in query:Iterator("price", "quantity") do
		avgPrice = avgPrice + price * quantity
		totalQuantity = totalQuantity + quantity
	end
	return Math.Round(avgPrice / totalQuantity)
end

---Gets the total price of an item.
---@param itemString string The item string
---@param timeFilter? number A time duration to filter on
---@param typeFilter LedgerTransactionType The type to query for
---@return number
function Transactions.GetTotalPrice(itemString, timeFilter, typeFilter)
	return private.GetItemAutoReleaseQuery(itemString)
		:Equal("type", typeFilter)
		:If(timeFilter ~= nil)
			:GreaterThan("time", LibTSMService.GetTime() - (timeFilter or 0))
		:End()
		:SumOfProduct("price", "quantity")
end

---Creates a summary query.
---@return DatabaseQuery
function Transactions.CreateSummaryQuery()
	return private.dbSummary:NewOwnedQuery()
		:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

---Adds the item string smart map to the query.
---@param query DatabaseQuery
function Transactions.AddSmartMap(query)
	query:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

---Updates the item string smart map.
---@param itemStringFilter "specific"|"level"|"base" The item string filter mode
function Transactions.UpdateSmartMap(itemStringFilter)
	private.filteredItemMode = itemStringFilter
	private.filteredItemStringSmartMap:Invalidate()
end

---Updates the summary data.
---@param filteredItemMode "specific"|"level"|"base" The item string filter mode
---@param groupFilter? table<string,any> Group filters
---@param searchFilter? string A search filter
---@param typeFilter? table<string,any> Source type filters
---@param characterFilter? table<string,any> Character filters
---@param minTime? number A minimum time filter
function Transactions.UpdateSummaryData(filteredItemMode, groupFilter, searchFilter, typeFilter, characterFilter, minTime)
	private.filteredItemMode = filteredItemMode
	private.filteredItemStringSmartMap:Invalidate()

	local itemsQuery = private.db:NewAutoReleaseQuery()
		:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
	if groupFilter then
		itemsQuery:InTable("groupPath", groupFilter)
	end
	if searchFilter then
		itemsQuery:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "")
		itemsQuery:Matches("name", String.Escape(searchFilter))
	end
	if typeFilter then
		itemsQuery:InTable("source", typeFilter)
	end
	if characterFilter then
		itemsQuery:InTable("player", characterFilter)
	end
	if minTime then
		itemsQuery:GreaterThan("time", minTime)
	end

	local summaryTemp = private.summaryTemp
	for _, recordTypeInfo in pairs(summaryTemp) do
		assert(not next(recordTypeInfo.quantity) and not next(recordTypeInfo.price))
	end

	for _, itemString, price, quantity, recordType in itemsQuery:Iterator("filteredItemString", "price", "quantity", "type") do
		summaryTemp[recordType].quantity[itemString] = (summaryTemp[recordType].quantity[itemString] or 0) + quantity
		summaryTemp[recordType].price[itemString] = (summaryTemp[recordType].price[itemString] or 0) + price * quantity
	end

	private.dbSummary:TruncateAndBulkInsertStart()
	for itemString, saleQuantity in pairs(summaryTemp.sale.quantity) do
		local buyQuantity = summaryTemp.buy.quantity[itemString] or 0
		if saleQuantity > 0 and buyQuantity > 0 then
			local avgSalePrice = summaryTemp.sale.price[itemString] / saleQuantity
			local avgBuyPrice = summaryTemp.buy.price[itemString] / buyQuantity
			local profit = avgSalePrice - avgBuyPrice
			local totalProfit = profit * min(saleQuantity, buyQuantity)
			local profitPct = Math.Round(profit * 100 / avgBuyPrice)
			private.dbSummary:BulkInsertNewRow(itemString, saleQuantity, avgSalePrice, buyQuantity, avgBuyPrice, profit, totalProfit, profitPct)
		end
	end
	private.dbSummary:BulkInsertEnd()

	for _, recordTypeInfo in pairs(summaryTemp) do
		Table.WipeAndDeallocate(recordTypeInfo.quantity)
		Table.WipeAndDeallocate(recordTypeInfo.price)
	end
end

---Gets the characters which we have data for.
---@param characters string[] A table to store the result in
---@return string[]
function Transactions.GetCharacters(characters)
	private.db:NewAutoReleaseQuery()
		:Distinct("player")
		:Equal("isCurrentRealm", true)
		:AsTable(characters, "player")
	return characters
end

---Gets the player field from the DB by UUID.
---@param uuid number The UUID of the row
---@return string
function Transactions.GetPlayerByUUID(uuid)
	return private.db:GetRowFields(uuid, "player")
end

---Removes a transaction DB row by its UUID.
---@param uuid number The UUID of the row to remove
function Transactions.RemoveRowByUUID(uuid)
	local recordType = private.db:GetRowFields(uuid, "type")
	local itemString = private.db:GetRowFields(uuid, "itemString")
	local player = private.db:GetRowFields(uuid, "player")
	private.db:DeleteRow(uuid)
	if private.syncHashDayCache[player] then
		private.syncHashDayCacheIsInvalid[player] = true
	end
	private.dataChanged = true
	private.dataCallbacks:CallAll(recordType, itemString)
	private.syncDataCallbacks:CallAll()
end

---Prepares the sync hashes for a given character.
---@param player string The character name
function Transactions.PrepareSyncHashes(player)
	tinsert(private.pendingSyncHashCharacters, player)
	if not private.isSyncHashesThreadRunning then
		private.isSyncHashesThreadRunning = true
		Threading.Start(private.syncHashesThread)
	end
end

---Gets the sync hash for a given character.
---@param player string The character name
---@return number?
function Transactions.GetSyncHash(player)
	local hashesByDay = Transactions.GetSyncHashByDay(player)
	if not hashesByDay then
		return nil
	end
	return Hash.Calculate(hashesByDay)
end

---Gets the sync data hashes for a given character.
---@param player string The character name
---@return table<number,number>?
function Transactions.GetSyncHashByDay(player)
	if not private.syncHashDayCache[player] or private.syncHashDayCacheIsInvalid[player] then
		return nil
	end
	return private.syncHashDayCache[player]
end

---Gets sync data for a given character and day.
---@param player string The character name
---@param day number The day
---@param result table A table to store the result in
function Transactions.GetSyncData(player, day, result)
	local query = private.db:NewAutoReleaseQuery()
		:Equal("player", player)
		:GreaterThanOrEqual("time", day * SECONDS_PER_DAY)
		:LessThan("time", (day + 1) * SECONDS_PER_DAY)
		:Equal("isCurrentRealm", true)
	assert(#SYNC_FIELDS == 9)
	for _, val1, val2, val3, val4, val5, val6, val7, val8, val9 in query:Iterator(unpack(SYNC_FIELDS)) do
		Table.InsertMultiple(result, val1, val2, val3, val4, val5, val6, val7, val8, val9)
	end
end

---Removes data for a given character and day.
---@param player string The character name
---@param day number The day
function Transactions.RemovePlayerDay(player, day)
	private.dataChanged = true
	local maxChangedTime = private.RemovePlayerDay(player, day)
	private.dataCallbacks:CallAll("sale", nil, maxChangedTime)
	private.dataCallbacks:CallAll("buy", nil, maxChangedTime)
end

---Handles data synced from another account.
---@param player string The character name
---@param day number The day
---@param data table The data
function Transactions.HandleSyncedData(player, day, data)
	assert(#data % 9 == 0)
	private.dataChanged = true
	local maxChangedTime = 0
	for _ in private.db:WithQueryUpdatesPaused() do
		-- Remove any prior data for the day
		maxChangedTime = private.RemovePlayerDay(player, day)

		-- Insert the new data
		private.db:BulkInsertStart()
		for i = 1, #data, 9 do
			local recordType, itemString, stackSize, quantity, price, otherPlayer, timestamp, source, saveTime = unpack(data, i, i + 8)
			maxChangedTime = max(maxChangedTime, private.GetRecordChangeTime(timestamp, saveTime))
			private.BulkInsertNewRowHelper(player, recordType, itemString, stackSize, quantity, price, otherPlayer, timestamp, source, saveTime, true)
		end
		private.db:BulkInsertEnd()
	end
	private.dataCallbacks:CallAll("sale", nil, maxChangedTime)
	private.dataCallbacks:CallAll("buy", nil, maxChangedTime)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData(data, truncatedRealms)
	-- Load the current realm first
	local currentRealm = SessionInfo.GetRealmName()
	private.db:BulkInsertStart()
	for _, recordType, csvRecords, csvSaveTimes, realm in Table.StrideIterator(data, 4) do
		if realm == currentRealm then
			private.LoadCSVData(recordType, csvRecords, csvSaveTimes, realm)
		end
	end
	private.db:BulkInsertEnd()

	-- Load other realms as long as they aren't too big
	private.db:BulkInsertStart()
	assert(not next(private.realmsTemp))
	for _, _, csvRecords, _, realm in Table.StrideIterator(data, 4) do
		if realm ~= currentRealm then
			if not private.realmsTemp[realm] then
				tinsert(private.realmsTemp, realm)
				private.realmsTemp[realm] = 0
			end
			private.realmsTemp[realm] = private.realmsTemp[realm] + #csvRecords
		end
	end
	for _, realm in ipairs(private.realmsTemp) do
		local isLimited = private.realmsTemp[realm] > ALT_REALM_CSV_LENGTH
		if isLimited then
			tinsert(truncatedRealms, realm)
		end
	end
	for _, recordType, csvRecords, csvSaveTimes, realm in Table.StrideIterator(data, 4) do
		if realm ~= currentRealm then
			private.LoadCSVData(recordType, csvRecords, csvSaveTimes, realm, private.realmsTemp[realm] > ALT_REALM_CSV_LENGTH)
		end
	end
	Table.WipeAndDeallocate(private.realmsTemp)
	private.db:BulkInsertEnd()

	private.dataCallbacks:CallAll("sale")
	private.dataCallbacks:CallAll("buy")
end

---@param recordType "buy"|"sale"
function private.LoadCSVData(recordType, csvStr, csvSaveTimes, realm, isLimited)
	local isCurrentRealm = realm == SessionInfo.GetRealmName()
	local decodeContext = CSV.DecodeStart(csvStr, OLD_CSV_KEYS[recordType]) or CSV.DecodeStart(csvStr, CSV_KEYS)
	if not decodeContext then
		Log.Err("Failed to load %s data context for %s", recordType, realm)
		if isCurrentRealm then
			private.dataChanged = true
		end
		return
	end

	local minTime = isLimited and (LibTSMService.GetTime() - 180 * 24 * 60 * 60) or 0
	local saveTimes = String.SafeSplit(csvSaveTimes, ",")
	local saveTimeIndex = 1
	for itemString, stackSize, quantity, price, otherPlayer, player, timestamp, source in CSV.DecodeIterator(decodeContext) do
		if (tonumber(timestamp) or 0) >= minTime then
			local saveTime = 0
			if source == "Auction" then
				saveTime = tonumber(saveTimes[saveTimeIndex])
				saveTimeIndex = saveTimeIndex + 1
			end
			private.BulkInsertNewRowHelper(player, recordType, itemString, stackSize, quantity, price, otherPlayer, timestamp, source, saveTime, isCurrentRealm)
		end
	end

	if not CSV.DecodeEnd(decodeContext) then
		Log.Err("Failed to decode some %s records for %s", recordType, realm)
		if isCurrentRealm then
			private.dataChanged = true
		end
	end
end

function private.BulkInsertNewRowHelper(player, recordType, itemString, stackSize, quantity, price, otherPlayer, timestamp, source, saveTime, isCurrentRealm)
	itemString = ItemString.Get(itemString)
	local baseItemString = itemString and ItemString.GetBaseFast(itemString)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
	stackSize = tonumber(stackSize)
	quantity = tonumber(quantity)
	price = tonumber(price)
	timestamp = tonumber(timestamp)
	if itemString and stackSize and quantity and price and otherPlayer and player and timestamp and source then
		local newTimestamp = floor(timestamp)
		if newTimestamp ~= timestamp then
			-- make sure all timestamps are stored as integers
			if isCurrentRealm then
				private.dataChanged = true
			end
			timestamp = newTimestamp
		end
		local newPrice = floor(price)
		if newPrice ~= price then
			-- make sure all prices are stored as integers
			if isCurrentRealm then
				private.dataChanged = true
			end
			price = newPrice
		end
		private.db:BulkInsertNewRowFast13(baseItemString, recordType, itemString, levelItemString, stackSize, quantity, price, otherPlayer, player, timestamp, source, saveTime, isCurrentRealm)
	else
		private.dataChanged = true
	end
end

function private.SaveData(recordType)
	local numRecords = private.db:NewAutoReleaseQuery()
		:Equal("type", recordType)
		:Equal("isCurrentRealm", true)
		:Count()
	if numRecords > MAX_CSV_RECORDS then
		local query = private.db:NewOwnedQuery()
			:Equal("type", recordType)
			:Equal("isCurrentRealm", true)
			:OrderBy("time", false)
		local count = 0
		local saveTimes = {}
		local shouldTrim = query:Count() > MAX_CSV_RECORDS
		local lastTime = nil
		local encodeContext = CSV.EncodeStart(CSV_KEYS)
		local iter = query:Iterator("itemString", "stackSize", "quantity", "price", "otherPlayer", "player", "time", "source", "saveTime")
		for _, itemString, stackSize, quantity, price, otherPlayer, player, timestamp, source, saveTime in iter do
			if not shouldTrim or count <= TRIMMED_CSV_RECORDS then
				-- Add the save time
				saveTime = saveTime ~= 0 and saveTime or floor(LibTSMService.GetTime())
				if source == "Auction" then
					tinsert(saveTimes, saveTime)
				end
				-- Update the time we're trimming to
				if shouldTrim then
					lastTime = timestamp
				end
				-- Add to our list of CSV lines
				CSV.EncodeAddRowDataRaw(encodeContext, itemString, stackSize, quantity, price, otherPlayer, player, timestamp, source)
			end
			count = count + 1
			if shouldTrim and count > TRIMMED_CSV_RECORDS then
				iter:Release()
				break
			end
		end
		query:Release()
		return CSV.EncodeEnd(encodeContext), table.concat(saveTimes, ","), lastTime
	else
		local saveTimes = {}
		local encodeContext = CSV.EncodeStart(CSV_KEYS)
		for _, _, rowRecordType, itemString, _, stackSize, quantity, price, otherPlayer, player, timestamp, source, saveTime, isCurrentRealm in private.db:RawIterator() do
			if rowRecordType == recordType and isCurrentRealm then
				-- add the save time
				if source == "Auction" then
					tinsert(saveTimes, saveTime ~= 0 and saveTime or floor(LibTSMService.GetTime()))
				end
				-- add to our list of CSV lines
				CSV.EncodeAddRowDataRaw(encodeContext, itemString, stackSize, quantity, price, otherPlayer, player, timestamp, source)
			end
		end
		return CSV.EncodeEnd(encodeContext), table.concat(saveTimes, ","), nil
	end
end

function private.InsertRecord(recordType, itemString, source, stackSize, price, otherPlayer, timestamp)
	private.dataChanged = true
	assert(itemString and source and stackSize and price and otherPlayer and timestamp)
	timestamp = floor(timestamp)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local levelItemString = ItemString.ToLevel(itemString)
	local player = SessionInfo.GetCharacterName()
	local uuid, prevQuantity = private.db:NewAutoReleaseQuery()
		:Equal("type", recordType)
		:Equal("itemString", itemString)
		:Equal("baseItemString", baseItemString)
		:Equal("levelItemString", levelItemString)
		:Equal("stackSize", stackSize)
		:Equal("source", source)
		:Equal("price", price)
		:Equal("player", player)
		:Equal("otherPlayer", otherPlayer)
		:GreaterThan("time", timestamp - COMBINE_TIME_THRESHOLD)
		:LessThan("time", timestamp + COMBINE_TIME_THRESHOLD)
		:Equal("saveTime", 0)
		:Equal("isCurrentRealm", true)
		:GetFirstResultWithUUID("quantity")
	if uuid then
		private.db:UpdateRow(uuid, "quantity", prevQuantity + stackSize)
	else
		private.db:InsertRow(baseItemString, recordType, itemString, levelItemString, stackSize, stackSize, price, otherPlayer, player, timestamp, source, 0, true)
	end
	if private.syncHashDayCache[player] then
		private.syncHashDayCacheIsInvalid[player] = true
	end

	private.dataCallbacks:CallAll(recordType, itemString)
	private.syncDataCallbacks:CallAll()
end

function private.SyncHashesThread(otherPlayer)
	private.CalculateSyncHashesThreaded(SessionInfo.GetCharacterName())
	while #private.pendingSyncHashCharacters > 0 do
		local player = tremove(private.pendingSyncHashCharacters, 1)
		private.CalculateSyncHashesThreaded(player)
	end
	private.isSyncHashesThreadRunning = false
end

function private.CalculateSyncHashesThreaded(player)
	if private.syncHashDayCache[player] and not private.syncHashDayCacheIsInvalid[player] then
		Log.Info("Sync hashes for player (%s) are already up to date", player)
		return
	end
	private.syncHashDayCache[player] = private.syncHashDayCache[player] or {}
	local result = private.syncHashDayCache[player]
	wipe(result)
	private.syncHashDayCacheIsInvalid[player] = true
	while true do
		local aborted = false
		local query = private.db:NewAutoReleaseQuery()
			:Equal("player", player)
			:Equal("isCurrentRealm", true)
			:VirtualHashField("hash", SYNC_FIELDS)
			:OrderBy("time", false)
			:OrderBy("itemString", true)
		local iter = query:AbortableIterator("hash", "time")
		Threading.GuardIterator(iter --[[@as IteratorObject]])
		for _, rowHash, rowTime in iter do
			local day = floor(rowTime / SECONDS_PER_DAY)
			result[day] = Hash.Calculate(rowHash, result[day])
			Threading.Yield()
			if query:IsIteratorAborted() then
				Log.Warn("Iterator was aborted for player (%s), will retry", player)
				aborted = true
			end
		end
		Threading.UnguardIterator(iter --[[@as IteratorObject]])
		if not aborted then
			break
		end
	end
	private.syncHashDayCacheIsInvalid[player] = nil
	Log.Info("Updated sync hashes for player (%s)", player)
end

function private.GetItemAutoReleaseQuery(itemString)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local levelItemString = ItemString.ToLevel(itemString)
	local query = private.db:NewAutoReleaseQuery()
		:Equal("baseItemString", baseItemString)
	if itemString == baseItemString then
		return query
	elseif itemString == levelItemString then
		return query:Equal("levelItemString", levelItemString)
	else
		return query:Equal("itemString", itemString)
	end
end

function private.FilteredItemStringLookup(itemString)
	if private.filteredItemMode == "level" then
		return ItemString.ToLevel(itemString)
	elseif private.filteredItemMode == "base" then
		return ItemString.GetBaseFast(itemString)
	elseif private.filteredItemMode == "specific" then
		return itemString
	else
		error("Invalid item mode: "..tostring(private.filteredItemMode))
	end
end

function private.GetRecordChangeTime(timestamp, saveTime)
	return saveTime == 0 and math.huge or max(timestamp, saveTime)
end

function private.RemovePlayerDay(player, day)
	local maxChangedTime = 0
	for _ in private.db:WithQueryUpdatesPaused() do
		local query = private.db:NewOwnedQuery()
			:Equal("player", player)
			:GreaterThanOrEqual("time", day * SECONDS_PER_DAY)
			:LessThan("time", (day + 1) * SECONDS_PER_DAY)
			:Equal("isCurrentRealm", true)
		for _, timestamp, saveTime in query:Iterator("time", "saveTime") do
			maxChangedTime = max(maxChangedTime, private.GetRecordChangeTime(timestamp, saveTime))
		end
		query:Delete()
		query:Release()
		if private.syncHashDayCache[player] then
			private.syncHashDayCacheIsInvalid[player] = true
		end
	end
	return maxChangedTime
end

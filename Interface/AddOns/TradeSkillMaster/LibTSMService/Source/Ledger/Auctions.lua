-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Auctions = LibTSMService:Init("Ledger.Auctions")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local CSV = LibTSMService:From("LibTSMUtil"):Include("Format.CSV")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local SmartMap = LibTSMService:From("LibTSMUtil"):IncludeClassType("SmartMap")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local Group = LibTSMService:From("LibTSMTypes"):Include("Group")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local private = {
	db = nil,
	dataCallbacks = CallbackRegistry.NewList(),
	numExpiresQuery = nil,
	dataChanged = false,
	statsQuery = nil,
	statsTemp = {},
	filteredItemStringSmartMap = nil,
	filteredItemMode = "specific",
}
local COMBINE_TIME_THRESHOLD = 300 -- group expenses within 5 minutes together
local REMOVE_OLD_THRESHOLD = 180 * 24 * 60 * 60 -- remove records over 6 months old
local SECONDS_PER_DAY = 24 * 60 * 60
local CSV_KEYS = { "itemString", "stackSize", "quantity", "player", "time" }



-- ============================================================================
-- Module Loading
-- ============================================================================

Auctions:OnModuleLoad(function()
	private.db = Database.NewSchema("ACCOUNTING_AUCTIONS")
		:AddStringField("baseItemString")
		:AddStringField("type")
		:AddStringField("itemString")
		:AddNumberField("stackSize")
		:AddNumberField("quantity")
		:AddStringField("player")
		:AddNumberField("time")
		:AddNumberField("saveTime")
		:AddBooleanField("isCurrentRealm")
		:AddIndex("baseItemString")
		:AddIndex("time")
		:AddIndex("saveTime")
		:Commit()
	private.numExpiresQuery = private.db:NewOwnedQuery()
		:Equal("type", "expire")
		:Equal("baseItemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())
	private.statsQuery = private.db:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())
	private.filteredItemStringSmartMap = SmartMap.New("string", "string", private.FilteredItemStringLookup)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for when the auctions data changes.
---@param callback fun() Callback function for when data changes
function Auctions.RegisterCallback(callback)
	private.dataCallbacks:Add(callback)
end

---Loads auctions data.
---@param data table The data as a flattened table with fields: `recordType, `csvRecords`, `csvSaveTimes`, `isCurrentRealm`
function Auctions.LoadData(data)
	private.db:BulkInsertStart()
	for _, recordType, csvRecords, csvSaveTimes, isCurrentRealm in Table.StrideIterator(data, 4) do
		private.LoadData(recordType, csvRecords, csvSaveTimes, isCurrentRealm)
	end
	private.db:BulkInsertEnd()
	CustomString.InvalidateCache("NumExpires")
end

---Returns whether or not the data has changed.
---@return boolean
function Auctions.DataDidChange()
	return private.dataChanged
end

---Saves the data.
---@return string csvSales
---@return string csvCancelSaveTimes
---@return string csvExpires
---@return string csvExpireSaveTimes
function Auctions.SaveData()
	local cancelSaveTimes, expireSaveTimes = {}, {}
	local cancelEncodeContext = CSV.EncodeStart(CSV_KEYS)
	local expireEncodeContext = CSV.EncodeStart(CSV_KEYS)
	-- Order by time to speed up loading
	local query = private.db:NewAutoReleaseQuery()
		:OrderBy("time", true)
		:Equal("isCurrentRealm", true)
	for _, recordType, itemString, stackSize, quantity, player, timestamp, saveTime in query:Iterator("type", "itemString", "stackSize", "quantity", "player", "time", "saveTime") do
		local saveTimes, encodeContext = nil, nil
		if recordType == "cancel" then
			saveTimes = cancelSaveTimes
			encodeContext = cancelEncodeContext
		elseif recordType == "expire" then
			saveTimes = expireSaveTimes
			encodeContext = expireEncodeContext
		else
			error("Invalid recordType: "..tostring(recordType))
		end
		-- Add the save time
		tinsert(saveTimes, saveTime ~= 0 and saveTime or floor(LibTSMService.GetTime()))
		-- Add to our list of CSV lines
		CSV.EncodeAddRowDataRaw(encodeContext, itemString, stackSize, quantity, player, timestamp)
	end
	return CSV.EncodeEnd(cancelEncodeContext), table.concat(cancelSaveTimes, ","), CSV.EncodeEnd(expireEncodeContext), table.concat(expireSaveTimes, ",")
end

---Inserts a new cancel record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param timestamp number The timestamp
function Auctions.InsertCancel(itemString, stackSize, timestamp)
	private.InsertRecord("cancel", itemString, stackSize, timestamp)
end

---Inserts a new expire record.
---@param itemString string The item string
---@param stackSize number The stack size
---@param timestamp number The timestamp
function Auctions.InsertExpire(itemString, stackSize, timestamp)
	private.InsertRecord("expire", itemString, stackSize, timestamp)
end

---Gets auction stats for an item.
---@param itemString string The item string
---@param minTime? number The minimum time
---@return number cancel
---@return number expire
---@return number total
function Auctions.GetStats(itemString, minTime)
	private.statsQuery:BindParams(ItemString.GetBaseFast(itemString), minTime or 0)
	wipe(private.statsTemp)
	private.statsQuery:GroupedSum("type", "quantity", private.statsTemp)
	local cancel = private.statsTemp.cancel or 0
	local expire = private.statsTemp.expire or 0
	local total = cancel + expire
	return cancel, expire, total
end

---Gets the number of times an item has expired.
---@param itemString string The item string
---@param minTime? number The minimum time
---@return number
function Auctions.GetNumExpires(itemString, minTime)
	private.numExpiresQuery:BindParams(ItemString.GetBaseFast(itemString), minTime or 0)
	local num = 0
	for _, quantity in private.numExpiresQuery:Iterator("quantity") do
		num = num + quantity
	end
	return num
end

---Creates a DB query.
---@return DatabaseQuery
function Auctions.CreateQuery()
	return private.db:NewOwnedQuery()
		:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

---Creates a raw DB query.
---@return DatabaseQuery
function Auctions.CreateRawQuery()
	return private.db:NewOwnedQuery()
end

---Adds the item string smart map to the query.
---@param query DatabaseQuery
function Auctions.AddSmartMap(query)
	query:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

---Updates the item string smart map.
---@param itemStringFilter "specific"|"level"|"base" The item string filter mode
function Auctions.UpdateSmartMap(itemStringFilter)
	private.filteredItemMode = itemStringFilter
	private.filteredItemStringSmartMap:Invalidate()
end

---Removes old auctions data and returns the number of records removed.
---@param days number The max age in days
---@return number
function Auctions.RemoveOldData(days)
	private.dataChanged = true
	local numRecords = private.db:NewAutoReleaseQuery()
		:LessThan("time", LibTSMService.GetTime() - days * SECONDS_PER_DAY)
		:Equal("isCurrentRealm", true)
		:Delete()
	CustomString.InvalidateCache("NumExpires")
	private.dataCallbacks:CallAll()
	return numRecords
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData(recordType, csvRecords, csvSaveTimes, isCurrentRealm)
	local saveTimes = String.SafeSplit(csvSaveTimes, ",")
	local decodeContext = CSV.DecodeStart(csvRecords, CSV_KEYS)
	if not decodeContext then
		Log.Err("Failed to decode %s records", recordType)
		private.dataChanged = true
		return
	end

	local removeTime = floor(LibTSMService.GetTime()) - REMOVE_OLD_THRESHOLD
	local index = 1
	local prevTimestamp = 0
	for itemString, stackSize, quantity, player, timestamp in CSV.DecodeIterator(decodeContext) do
		itemString = ItemString.Get(itemString)
		local baseItemString = itemString and ItemString.GetBaseFast(itemString)
		local saveTime = tonumber(saveTimes[index])
		stackSize = tonumber(stackSize)
		quantity = tonumber(quantity)
		timestamp = tonumber(timestamp)
		if itemString and baseItemString and stackSize and quantity and timestamp and saveTime and timestamp > removeTime then
			local newTimestamp = floor(timestamp)
			if newTimestamp ~= timestamp then
				-- make sure all timestamps are stored as integers
				private.dataChanged = true
				timestamp = newTimestamp
			end
			if timestamp < prevTimestamp then
				-- not ordered by timestamp
				private.dataChanged = true
			end
			prevTimestamp = timestamp
			private.db:BulkInsertNewRowFast9(baseItemString, recordType, itemString, stackSize, quantity, player, timestamp, saveTime, isCurrentRealm)
		else
			private.dataChanged = true
		end
		index = index + 1
	end

	if not CSV.DecodeEnd(decodeContext) then
		Log.Err("Failed to decode %s records", recordType)
		private.dataChanged = true
	end
end

function private.InsertRecord(recordType, itemString, stackSize, timestamp)
	private.dataChanged = true
	assert(itemString and stackSize and stackSize > 0 and timestamp)
	timestamp = floor(timestamp)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local uuid, prevQuantity = private.db:NewAutoReleaseQuery()
		:Equal("type", recordType)
		:Equal("baseItemString", baseItemString)
		:Equal("itemString", itemString)
		:Equal("stackSize", stackSize)
		:Equal("player", SessionInfo.GetCharacterName())
		:GreaterThan("time", timestamp - COMBINE_TIME_THRESHOLD)
		:LessThan("time", timestamp + COMBINE_TIME_THRESHOLD)
		:Equal("saveTime", 0)
		:Equal("isCurrentRealm", true)
		:GetFirstResultWithUUID("quantity")
	if uuid then
		private.db:UpdateRow(uuid, "quantity", prevQuantity + stackSize)
	else
		private.db:InsertRow(baseItemString, recordType, itemString, stackSize, stackSize, SessionInfo.GetCharacterName(), timestamp, 0, true)
	end

	if recordType == "expire" then
		CustomString.InvalidateCache("NumExpires", itemString)
	end
	private.dataCallbacks:CallAll()
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

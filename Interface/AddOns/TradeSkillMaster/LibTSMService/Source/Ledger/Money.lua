-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Money = LibTSMService:Init("Ledger.Money")
local CSV = LibTSMService:From("LibTSMUtil"):Include("Format.CSV")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	db = nil,
	dataChanged = false,
}
local CSV_KEYS = { "type", "amount", "otherPlayer", "player", "time" }
local COMBINE_TIME_THRESHOLD = 300 -- Group expenses within 5 minutes together
local SECONDS_PER_DAY = 24 * 60 * 60



-- ============================================================================
-- Module Loading
-- ============================================================================

Money:OnModuleLoad(function()
	private.db = Database.NewSchema("ACCOUNTING_MONEY")
		:AddStringField("recordType")
		:AddStringField("type")
		:AddNumberField("amount")
		:AddStringField("otherPlayer")
		:AddStringField("player")
		:AddNumberField("time")
		:AddBooleanField("isCurrentRealm")
		:AddIndex("recordType")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads money data.
---@param data table The data as a flattened table with fields: `recordType, `csvRecords`, `csvSaveTimes`, `isCurrentRealm`
function Money.LoadData(data)
	private.db:BulkInsertStart()
	for _, recordType, csvRecords, isCurrentRealm in Table.StrideIterator(data, 3) do
		private.LoadData(recordType, csvRecords, isCurrentRealm)
	end
	private.db:BulkInsertEnd()
end

---Returns whether or not the data has changed.
---@return boolean
function Money.DataDidChange()
	return private.dataChanged
end

---Saves the data.
function Money.SaveData()
	return private.SaveData("expense"), private.SaveData("income")
end

---Inserts a money transfer expense record.
---@param amount number The amount
---@param destination string The destination
function Money.InsertMoneyTransferExpense(amount, destination)
	private.InsertRecord("expense", "Money Transfer", amount, destination, floor(LibTSMService.GetTime()))
end

---Inserts a postage expense record.
---@param amount number The amount
---@param destination string The destination
function Money.InsertPostageExpense(amount, destination)
	private.InsertRecord("expense", "Postage", amount, destination, floor(LibTSMService.GetTime()))
end

---Inserts a money transfer income record.
---@param amount number The amount
---@param source string The source
---@param timestamp number The time of the transfer
function Money.InsertMoneyTransferIncome(amount, source, timestamp)
	private.InsertRecord("income", "Money Transfer", amount, source, timestamp)
end

---Inserts a repair bill expense record.
---@param amount number The amount
function Money.InsertRepairBillExpense(amount)
	private.InsertRecord("expense", "Repair Bill", amount, "Merchant", floor(LibTSMService.GetTime()))
end

---Inserts a crafting order expense record.
---@param amount number The amount
---@param seller string The name of the seller
---@param timestamp number The time of the purchase
function Money.InsertCraftingOrderExpense(amount, seller, timestamp)
	private.InsertRecord("expense", "Crafting Order", amount, seller, timestamp)
end

---Inserts a crafting order income record.
---@param amount number The amount
---@param buyer string The name of the buyer
---@param timestamp number The time of the sale
function Money.InsertCraftingOrderIncome(amount, buyer, timestamp)
	private.InsertRecord("income", "Crafting Order", amount, buyer, timestamp)
end

---Inserts a garrison income record.
---@param amount number The amount
function Money.InsertGarrisonIncome(amount)
	private.InsertRecord("income", "Garrison", amount, "Mission", floor(LibTSMService.GetTime()))
end

---Creates a query.
---@return DatabaseQuery
function Money.CreateQuery()
	return private.db:NewOwnedQuery()
end

---Iterates over the characters with money records.
---@param recordType "expense"|"income" The type of the record
---@return IteratorObject<fun(): number, string> @Iterator with fields: `index`, `character`
function Money.CharacterIterator(recordType)
	return private.db:NewAutoReleaseQuery()
		:Equal("recordType", recordType)
		:Distinct("player")
		:Iterator("player")
end

---Removes old money data and returns the number of records removed.
---@param days number The max age in days
---@return number
function Money.RemoveOldData(days)
	private.dataChanged = true
	local numRecords = private.db:NewAutoReleaseQuery()
		:LessThan("time", LibTSMService.GetTime() - days * SECONDS_PER_DAY)
		:Equal("isCurrentRealm", true)
		:Delete()
	return numRecords
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData(recordType, csvRecords, isCurrentRealm)
	local decodeContext = CSV.DecodeStart(csvRecords, CSV_KEYS)
	if not decodeContext then
		if isCurrentRealm then
			Log.Err("Failed to decode %s records (%d)", recordType, #csvRecords)
		end
		private.dataChanged = isCurrentRealm
		return
	end

	for type, amount, otherPlayer, player, timestamp in CSV.DecodeIterator(decodeContext) do
		amount = tonumber(amount)
		timestamp = tonumber(timestamp)
		if amount and timestamp then
			local newTimestamp = floor(timestamp)
			if newTimestamp ~= timestamp then
				-- Make sure all timestamps are stored as integers
				timestamp = newTimestamp
				private.dataChanged = isCurrentRealm
			end
			private.db:BulkInsertNewRowFast7(recordType, type, amount, otherPlayer, player, timestamp, isCurrentRealm)
		else
			private.dataChanged = isCurrentRealm
		end
	end

	if not CSV.DecodeEnd(decodeContext) then
		if isCurrentRealm then
			Log.Err("Failed to decode %s records", recordType)
		end
		private.dataChanged = isCurrentRealm
	end
end

function private.SaveData(recordType)
	local encodeContext = CSV.EncodeStart(CSV_KEYS)
	local query = private.db:NewAutoReleaseQuery()
		:Equal("recordType", recordType)
		:Equal("isCurrentRealm", true)
	for _, type, amount, otherPlayer, player, timestamp in query:Iterator("type", "amount", "otherPlayer", "player", "time") do
		CSV.EncodeAddRowDataRaw(encodeContext, type, amount, otherPlayer, player, timestamp)
	end
	return CSV.EncodeEnd(encodeContext)
end

function private.InsertRecord(recordType, type, amount, otherPlayer, timestamp)
	private.dataChanged = true
	assert(type and amount and amount > 0 and otherPlayer and timestamp)
	timestamp = floor(timestamp)
	local uuid, prevAmount = private.db:NewAutoReleaseQuery()
		:Equal("recordType", recordType)
		:Equal("type", type)
		:Equal("otherPlayer", otherPlayer)
		:Equal("player", SessionInfo.GetCharacterName())
		:GreaterThan("time", timestamp - COMBINE_TIME_THRESHOLD)
		:LessThan("time", timestamp + COMBINE_TIME_THRESHOLD)
		:Equal("isCurrentRealm", true)
		:GetFirstResultWithUUID("amount")
	if uuid then
		private.db:UpdateRow(uuid, "amount", prevAmount + amount)
	else
		private.db:InsertRow(recordType, type, amount, otherPlayer, SessionInfo.GetCharacterName(), timestamp, true)
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Activity = LibTSMService:Init("Ledger.Activity")
local Auctions = LibTSMService:Include("Ledger.Auctions")
local Transactions = LibTSMService:Include("Ledger.Transactions")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local TimeUtil = LibTSMService:From("LibTSMWoW"):Include("UI.TimeUtil")
local private = {
	db = nil,
	lineDB = nil,
	isDirty = true,
	openSessionTime = 0,
	cutoffTime = nil,
	activityTemp = {
		num = 0,
		player = {},
		time = {},
		isCurrentSession = {},
		quantity = {},
		amount = {},
	},
	sessionIndexLookupTemp = {},
}
local LINE = EnumType.New("ACTIVITY_LINE", {
	EXPIRED = EnumType.NewValue(),
	CANCELLED = EnumType.NewValue(),
	PURCHASED = EnumType.NewValue(),
	SOLD = EnumType.NewValue(),
})
Activity.LINE = LINE
local LINE_TYPES = { LINE.EXPIRED, LINE.CANCELLED, LINE.PURCHASED, LINE.SOLD }
local LINE_VALUE_INDEX = {
	[LINE.EXPIRED] = 1,
	[LINE.CANCELLED] = 2,
	[LINE.PURCHASED] = 3,
	[LINE.SOLD] = 4,
}
local NUM_LINES = #LINE_TYPES
local SECONDS_PER_DAY = 24 * 60 * 60
local MAX_ACTIVITY_AGE = 7 * SECONDS_PER_DAY



-- ============================================================================
-- Module Loading
-- ============================================================================

Activity:OnModuleLoad(function()
	private.openSessionTime = floor(LibTSMService.GetTime())
	private.cutoffTime = private.openSessionTime - MAX_ACTIVITY_AGE
	private.db = Database.NewSchema("ACTIVITY_LOG")
		:AddUniqueNumberField("id")
		:AddStringField("player")
		:AddNumberField("time")
		:AddNumberField("dayStart")
		:AddBooleanField("isCurrentSession")
		:AddNumberField("net")
		:AddIndex("time")
		:Commit()
	private.lineDB = Database.NewSchema("ACTIVITY_LOG_LINE")
		:AddNumberField("activityId")
		:AddEnumField("kind", LINE)
		:AddNumberField("order")
		:AddNumberField("quantity")
		:AddNumberField("amount")
		:AddIndex("activityId")
		:Commit()
	Transactions.RegisterCallback(private.HandleTransactionsChanged)
	Auctions.RegisterCallback(private.Invalidate)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a query over the activity records.
---@return DatabaseQuery
function Activity.CreateQuery()
	private.UpdateIfNeeded()
	return private.db:NewOwnedQuery()
		:OrderBy("time", false)
end

---Creates a query over the lines which make up a single activity, with the activity id as a bound parameter.
---@return DatabaseQuery
function Activity.CreateLineQuery()
	private.UpdateIfNeeded()
	return private.lineDB:NewOwnedQuery()
		:Equal("activityId", Database.BoundQueryParam())
		:OrderBy("order", true)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleTransactionsChanged(_, _, maxChangedTime)
	if (maxChangedTime or math.huge) < LibTSMService.GetTime() - MAX_ACTIVITY_AGE then
		return
	end
	private.Invalidate()
end

function private.Invalidate()
	private.isDirty = true
end

function private.UpdateIfNeeded()
	if not private.isDirty then
		return
	end
	private.Rebuild()
end

function private.Rebuild()
	assert(private.activityTemp.num == 0)
	private.isDirty = false
	private.AddAuctionActivities()
	private.EmitActivities()
	Table.WipeAndDeallocate(private.activityTemp.player)
	Table.WipeAndDeallocate(private.activityTemp.time)
	Table.WipeAndDeallocate(private.activityTemp.isCurrentSession)
	Table.WipeAndDeallocate(private.activityTemp.quantity)
	Table.WipeAndDeallocate(private.activityTemp.amount)
	private.activityTemp.num = 0
end

function private.AddAuctionActivities()
	assert(not next(private.sessionIndexLookupTemp))
	local transactionsQuery = Transactions.CreateRawQuery()
		:AutoRelease()
		:Equal("isCurrentRealm", true)
		:Equal("source", "Auction")
		:Or()
			:Equal("saveTime", 0)
			:GreaterThanOrEqual("saveTime", private.cutoffTime)
		:End()
		:OrderBy("time", true)
	for _, recordType, player, quantity, price, timestamp, saveTime in transactionsQuery:Iterator("type", "player", "quantity", "price", "time", "saveTime") do
		local index = private.GetSessionActivity(player, timestamp, saveTime)
		if recordType == "sale" then
			private.AddActivityLine(index, LINE.SOLD, quantity, quantity * price)
		else
			private.AddActivityLine(index, LINE.PURCHASED, quantity, -quantity * price)
		end
	end
	local auctionsQuery = Auctions.CreateRawQuery()
		:AutoRelease()
		:Equal("isCurrentRealm", true)
		:Or()
			:Equal("saveTime", 0)
			:GreaterThanOrEqual("saveTime", private.cutoffTime)
		:End()
		:OrderBy("time", true)
	for _, recordType, player, quantity, timestamp, saveTime in auctionsQuery:Iterator("type", "player", "quantity", "time", "saveTime") do
		local index = private.GetSessionActivity(player, timestamp, saveTime)
		private.AddActivityLine(index, recordType == "expire" and LINE.EXPIRED or LINE.CANCELLED, quantity, 0)
	end
	wipe(private.sessionIndexLookupTemp)
end

function private.GetSessionActivity(player, timestamp, saveTime)
	local key = player.."\0"..saveTime
	local index = private.sessionIndexLookupTemp[key]
	if index then
		private.activityTemp.time[index] = max(private.activityTemp.time[index], timestamp)
		return index
	end
	index = private.activityTemp.num + 1
	private.activityTemp.num = index
	private.activityTemp.player[index] = player
	private.activityTemp.time[index] = timestamp
	private.activityTemp.isCurrentSession[index] = saveTime == 0
	for i = 1, NUM_LINES do
		private.activityTemp.quantity[(index - 1) * NUM_LINES + i] = 0
		private.activityTemp.amount[(index - 1) * NUM_LINES + i] = 0
	end
	private.sessionIndexLookupTemp[key] = index
	return index
end

function private.AddActivityLine(index, lineType, quantity, amount)
	local offset = (index - 1) * NUM_LINES + LINE_VALUE_INDEX[lineType]
	private.activityTemp.quantity[offset] = private.activityTemp.quantity[offset] + quantity
	private.activityTemp.amount[offset] = private.activityTemp.amount[offset] + amount
end

function private.EmitActivities()
	private.db:TruncateAndBulkInsertStart()
	private.lineDB:TruncateAndBulkInsertStart()
	for index = 1, private.activityTemp.num do
		local net = 0
		for i, lineType in ipairs(LINE_TYPES) do
			local offset = (index - 1) * NUM_LINES + i
			local quantity = private.activityTemp.quantity[offset]
			if quantity > 0 then
				local amount = private.activityTemp.amount[offset]
				net = net + amount
				private.lineDB:BulkInsertNewRow(index, lineType, i, quantity, amount)
			end
		end
		local timestamp = private.activityTemp.time[index]
		private.db:BulkInsertNewRow(index, private.activityTemp.player[index], timestamp, TimeUtil.Floor(timestamp, "DAY"), private.activityTemp.isCurrentSession[index], net)
	end
	private.lineDB:BulkInsertEnd()
	private.db:BulkInsertEnd()
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local MyAuctions = LibTSMApp:Init("MyAuctions")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local Reactive = LibTSMApp:From("LibTSMReactive"):Include("Reactive")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local AuctionHouseWrapper = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local DefaultUI = LibTSMApp:From("LibTSMWoW"):Include("UI.DefaultUI")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	state = nil,
	db = nil,
	expectedCounts = {},
	updateTemp = {
		numByHash = {},
		numUsed = {},
		minPendingIndexByHash = {},
	},
}
local DB_HASH_FIELDS = {
	"itemLink",
	"itemTexture",
	"itemName",
	"itemQuality",
	"duration",
	"highBidder",
	"currentBid",
	"buyout",
	"stackSize",
	"isSold",
}
local STATE_SCHEMA = Reactive.CreateStateSchema("MyAuctionsState")
	:AddOptionalClassField("pendingFuture", "Future")
	:AddOptionalNumberField("pendingHash")
	:Commit()



-- ===========================================================================
-- Module Loading
-- ============================================================================
MyAuctions:OnModuleLoad(function()
	private.state = STATE_SCHEMA:CreateState()
	private.db = Database.NewSchema("MY_AUCTIONS")
		:AddUniqueNumberField("index")
		:AddNumberField("hash")
		:AddBooleanField("isPending")
		:AddNumberField("pendingAuctionId")
		:AddIndex("index")
		:Commit()
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.AuctionHouseClosed, false)
	Auction.RegisterIndexCallback(private.OnAuctionsUpdated)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets a query of all posted auctions.
---@return DatabaseQuery
function MyAuctions.CreateQuery()
	local query = Auction.NewIndexQuery()
		:LeftJoin(private.db, "index")
		:VirtualField("group", "string", Group.GetPathByItem, "itemString", "")
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		query:OrderBy("index", false)
	else
		query:OrderBy("isSold", false)
		query:OrderBy("itemName", true)
		query:OrderBy("auctionId", true)
	end
	return query
end

---Gets a publisher for the number of pending cancels.
---@return ReactivePublisherSchema
function MyAuctions.IsPendingPublisher()
	return private.state:Publisher("pendingFuture")
		:ToBooleanNotEquals(nil)
end

---Cancels an auction.
---@param auctionId number The ID of the auction to cancel
function MyAuctions.CancelAuction(auctionId)
	assert(not private.state.pendingFuture)
	local uuid, hash, isPending = private.db:NewAutoReleaseQuery()
		:Equal("pendingAuctionId", auctionId)
		:GetFirstResultWithUUID("hash", "isPending")
	assert(uuid)

	Log.Info("Canceling (auctionId=%d, hash=%d)", auctionId, hash)
	private.state.pendingFuture = AuctionHouseWrapper.CancelAuction(auctionId)
	if not private.state.pendingFuture then
		ChatMessage.PrintUser(L["Failed to cancel auction due to the auction house being busy. Ensure no other addons are scanning the AH and try again."])
		return
	end
	private.state.pendingFuture:SetScript("OnDone", private.PendingFutureOnDone)

	if private.expectedCounts[hash] and private.expectedCounts[hash] > 0 then
		private.expectedCounts[hash] = private.expectedCounts[hash] - 1
	else
		private.expectedCounts[hash] = private.GetNumRowsByHash(hash) - 1
	end
	assert(private.expectedCounts[hash] >= 0)
	assert(not isPending)
	private.db:UpdateRow(uuid, "isPending", true)

	assert(not private.state.pendingHash)
	private.state.pendingHash = hash
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AuctionHouseClosed()
	if not private.state.pendingFuture then
		return
	end
	private.state.pendingFuture:Cancel()
	private.state.pendingFuture = nil
end

function private.PendingFutureOnDone()
	assert(private.state.pendingFuture)
	local result = private.state.pendingFuture:GetValue()
	private.state.pendingFuture = nil
	local hash = private.state.pendingHash
	private.state.pendingHash = nil
	assert(hash)
	if result then
		Log.Info("Confirmed (hash=%d)", hash)
	else
		Log.Info("Failed to cancel (hash=%d)", hash)
		if private.expectedCounts[hash] then
			private.expectedCounts[hash] = private.expectedCounts[hash] + 1
		end
		private.OnAuctionsUpdated()
		AuctionHouseWrapper.AutoQueryOwnedAuctions()
	end
end

function private.GetNumRowsByHash(hash)
	return private.db:NewAutoReleaseQuery()
		:Equal("hash", hash)
		:Count()
end

function private.OnAuctionsUpdated()
	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end
	local query = Auction.NewIndexQuery()
		:VirtualHashField("hash", DB_HASH_FIELDS)
		:OrderBy("index", true)
	for _, index, hash in query:Iterator("index", "hash") do
		updateTemp.numByHash[hash] = (updateTemp.numByHash[hash] or 0) + 1
		if not updateTemp.minPendingIndexByHash[hash] and private.db:HasUniqueRow("index", index) then
			if private.db:GetRowFields(private.db:GetUniqueRow("index", index), "isPending") then
				updateTemp.minPendingIndexByHash[hash] = index
			end
		end
	end
	private.db:TruncateAndBulkInsertStart()
	for _, hash, index, auctionId in query:Iterator("hash", "index", "auctionId") do
		assert(updateTemp.numByHash[hash] > 0)
		local expectedCount = private.expectedCounts[hash]
		local isPending = nil
		if not expectedCount then
			-- This was never pending
			isPending = false
		elseif updateTemp.numByHash[hash] <= expectedCount then
			-- This is no longer pending
			isPending = false
			private.expectedCounts[hash] = nil
		elseif index >= (updateTemp.minPendingIndexByHash[hash] or math.huge) then
			local numPending = updateTemp.numByHash[hash] - expectedCount
			assert(numPending > 0)
			updateTemp.numUsed[hash] = (updateTemp.numUsed[hash] or 0) + 1
			isPending = updateTemp.numUsed[hash] <= numPending
		else
			-- It's a later auction which is pending
			isPending = false
		end
		private.db:BulkInsertNewRow(index, hash, isPending, auctionId)
	end
	private.db:BulkInsertEnd()

	for _, tbl in pairs(updateTemp) do
		Table.WipeAndDeallocate(tbl)
	end
	query:Release()
end

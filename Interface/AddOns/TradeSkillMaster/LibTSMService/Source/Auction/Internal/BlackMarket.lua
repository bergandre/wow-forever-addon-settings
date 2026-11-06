-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local BlackMarket = LibTSMService:InitInternal("Auction.BlackMarket")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local private = {
	data = nil,
	time = nil,
	itemsTemp = {},
}
local COPPER_PER_GOLD = 100 * 100



-- ============================================================================
-- Module Functions
-- ============================================================================

---Start the black market code.
function BlackMarket.Start()
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		return
	end
	Event.Register("BLACK_MARKET_ITEM_UPDATE", private.ScanBMAH)
end

---Gets the most recent black market scan data.
---@return (string scanData, number scanTime)|(nil, nil)
function BlackMarket.GetScanData()
	return private.data, private.time
end



-- ============================================================================
-- Private Helper Features
-- ============================================================================

function private.ScanBMAH()
	local numItems = AuctionHouse.GetNumBlackMarketAuctions()
	if not numItems then
		return
	end
	local now = floor(LibTSMService.GetTime())
	assert(not next(private.itemsTemp))
	for i = 1, numItems do
		local quantity, minBid, minIncr, currBid, numBids, timeLeft, itemLink, bmId = AuctionHouse.GetBlackMarketItemInfo(i)
		local itemString = ItemString.Get(itemLink)
		local itemId = itemString and ItemString.IsItem(itemString) and ItemString.ToId(itemString)
		if itemId then
			minBid = floor(minBid / COPPER_PER_GOLD)
			minIncr = floor(minIncr / COPPER_PER_GOLD)
			currBid = floor(currBid / COPPER_PER_GOLD)
			tinsert(private.itemsTemp, "[" .. strjoin(",", bmId, itemId, quantity, timeLeft, minBid, minIncr, currBid, numBids, now) .. "]")
		end
	end
	private.data = "[" .. table.concat(private.itemsTemp, ",") .. "]"
	wipe(private.itemsTemp)
	private.time = now
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionPostContext = LibTSMService:DefineClassType("AuctionPostContext")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local DEFAULT_LINKED_ITEM_PRICE_STRING = "first(dbmarket, 100g)"



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new auction post context object.
---@return AuctionPostContext
function AuctionPostContext.__static.New()
	return AuctionPostContext()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function AuctionPostContext.__private:__init()
	self._baseItemString = nil ---@type string!
	self._itemString = nil ---@type string!
	self._ownerStr = nil ---@type string!
	self._currentBid = nil ---@type number!
	self._displayedBid = nil ---@type number!
	self._itemDisplayedBid = nil ---@type number!
	self._buyout = nil ---@type number!
	self._itemBuyout = nil ---@type number!
	self._quantity = nil ---@type number!
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Wipes the post context.
function AuctionPostContext:Wipe()
	self._itemString = nil
	self._ownerStr = nil
	self._currentBid = nil
	self._displayedBid = nil
	self._itemDisplayedBid = nil
	self._buyout = nil
	self._itemBuyout = nil
	self._quantity = nil
end

---Populates the post context for an item.
---@param itemString string The item string
function AuctionPostContext:PopulateForItem(itemString)
	self:Wipe()
	self._itemString = itemString
	self._ownerStr = SessionInfo.GetCharacterName()
	self._currentBid = 0
	self._quantity = 1
	local price = CustomString.GetValue(DEFAULT_LINKED_ITEM_PRICE_STRING, itemString)
	self._displayedBid = price
	self._itemDisplayedBid = price
	self._buyout = price
	self._itemBuyout = price
end

---Populates the post context for an auction result row.
---@param row AuctionSubRow The auction row
function AuctionPostContext:PopulateForRow(row)
	self:Wipe()
	if not row:HasRawData() then
		return
	end
	self._itemString = row:GetItemString()
	self._ownerStr = row:GetOwnerInfo()
	local _, _, currentBid = row:GetBidInfo()
	self._currentBid = currentBid
	self._displayedBid, self._itemDisplayedBid = row:GetDisplayedBids()
	self._buyout, self._itemBuyout = row:GetBuyouts()
	self._quantity = row:GetQuantities()
end

---Updates the post context from the results of an auction scan.
---@param auctionScan AuctionScanManager The auction scan
function AuctionPostContext:UpdateFromScan(auctionScan)
	assert(self._itemString)
	for _, query in auctionScan:QueryIterator() do
		for _, subRow in query:ItemSubRowIterator(self._itemString) do
			local buyout, itemBuyout = subRow:GetBuyouts()
			if itemBuyout > 0 and itemBuyout < self._itemBuyout then
				self._ownerStr = subRow:GetOwnerInfo()
				local _, _, currentBid = subRow:GetBidInfo()
				self._currentBid = currentBid
				self._displayedBid, self._itemDisplayedBid = subRow:GetDisplayedBids()
				self._buyout = buyout
				self._itemBuyout = itemBuyout
			end
		end
	end
end

---Checks if this context can be posted.
---@return boolean
function AuctionPostContext:CanPost()
	if not self._itemString then
		return false
	end
	local numBags = BagTracking.CreateQueryBagsItemAuctionable(ItemString.GetBaseFast(self._itemString))
		:AutoRelease()
		:Sum("quantity")
	return numBags > 0
end

---Gets info for posting.
---@return (string? itemString, number? itemDisplayedBid, number? itemBuyout, number? quantity, string? ownerStr)
function AuctionPostContext:GetInfo()
	assert(self._itemString)
	local itemString = nil
	local hasExactItem = BagTracking.CreateQueryBagsAuctionable()
		:AutoRelease()
		:Equal("itemString", self._itemString)
		:IsNotEmpty()
	if hasExactItem then
		itemString = self._itemString
	else
		itemString = BagTracking.CreateQueryBagsAuctionable()
			:AutoRelease()
			:OrderBy("slotId", true)
			:Equal("baseItemString", ItemString.GetBaseFast(self._itemString))
			:GetFirstResult("itemString")
		if not itemString then
			return nil, nil, nil, nil, nil
		end
	end
	return itemString, self._itemDisplayedBid, self._itemBuyout, self._quantity, self._ownerStr
end

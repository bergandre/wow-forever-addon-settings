-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionSubRow = LibTSMService:DefineInternalClassType("AuctionSubRow")
local Util = LibTSMService:Include("AuctionScan.Util")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local private = {
	objectPool = ObjectPool.New("AUCTION_SCAN_RESULT_SUB_ROW", AuctionSubRow),
	ownersTemp = {},
}
local COPPER_PER_SILVER = 100

--TODO: Remove this
---@diagnostic disable: return-mismatch, need-check-nil



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets a new auction sub row object.
---@param row AuctionRow
---@return AuctionSubRow
function AuctionSubRow.__static.Get(row)
	local subRow = private.objectPool:Get()
	subRow:_Acquire(row)
	return subRow
end



-- ============================================================================
-- AuctionSubRow - Meta Class Methods
-- ============================================================================

function AuctionSubRow:__init()
	self._resultRow = nil ---@type AuctionRow!
	self._itemLink = nil ---@type string!
	self._buyout = nil ---@type number!
	self._minBid = nil ---@type number!
	self._currentBid = nil ---@type number!
	self._minIncrement = nil ---@type number!
	self._isHighBidder = nil ---@type boolean!
	self._quantity = nil ---@type number!
	self._timeLeft = nil ---@type number!
	self._ownerStr = nil ---@type string!
	self._hasOwners = false
	self._numOwnerItems = nil ---@type number!
	self._auctionId = nil ---@type number!
	self._hash = nil ---@type string!
	self._hashNoSeller = nil ---@type string!
	self._browseId = nil ---@type number!
	self._numAuctions = 1
end

function AuctionSubRow:_Acquire(resultRow)
	self._resultRow = resultRow
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Merges another sub row into this one.
---@param other AuctionSubRow
function AuctionSubRow:Merge(other)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		self._numAuctions = self._numAuctions + other._numAuctions
	else
		if self:IsCommodity() then
			self._quantity = self._quantity + other._quantity
			self._numOwnerItems = self._numOwnerItems + other._numOwnerItems
		else
			self._numAuctions = self._numAuctions + other._numAuctions
		end
	end
end

---Releases the sub row.
function AuctionSubRow:Release()
	self._resultRow = nil
	self._numAuctions = 1
	self:_SetRawData(nil)
	private.objectPool:Recycle(self)
end

---Checks if this is a sub row.
---@return true
function AuctionSubRow:IsSubRow()
	return true
end

---Checks if raw data has been set.
---@return boolean
function AuctionSubRow:HasRawData()
	return self._timeLeft and true or false
end

---Checks if owner info is available.
---@return boolean
function AuctionSubRow:HasOwners()
	return self._hasOwners
end

---Checks whether or not the item string is available with cached item info.
---@return boolean
function AuctionSubRow:HasItemString()
	assert(self:HasRawData())
	local itemString = ItemString.Get(self._itemLink)
	assert(itemString)
	if not Util.HasItemInfo(itemString) then
		return false
	end
	return true
end

---Checks if this is a commodity item.
---@return boolean
function AuctionSubRow:IsCommodity()
	return self._resultRow:IsCommodity()
end

---Gets the parent row.
---@return AuctionRow
function AuctionSubRow:GetResultRow()
	return self._resultRow
end

---Gets the base item string.
---@return string
function AuctionSubRow:GetBaseItemString()
	return self._resultRow:GetBaseItemString()
end

---Gets the item string.
---@return string?
function AuctionSubRow:GetItemString()
	assert(self:HasRawData())
	local itemString = ItemString.Get(self._itemLink)
	return itemString or self._resultRow:GetItemString()
end

---Get the item info.
---@return string name
---@return number quality
---@return number itemLevel
function AuctionSubRow:GetItemInfo()
	assert(self:HasItemString())
	local itemString = ItemString.Get(self._itemLink)
	assert(itemString)
	local itemName = ItemInfo.GetName(itemString)
	local quality = ItemInfo.GetQuality(itemString)
	local itemLevel = ItemInfo.GetItemLevel(itemString)
	assert(itemName and quality and itemLevel)
	return itemName, quality, itemLevel
end

---Gets the buyouts.
---@return number buyout
---@return number itemBuyout
---@return nil minPrice
function AuctionSubRow:GetBuyouts()
	assert(self:HasRawData())
	return self._buyout, floor(self._buyout / self._quantity), nil
end

---Gets the bid info
---@return number minBid
---@return number itemMinBid
---@return number currentBid
---@return boolean isHighBidder
---@return number minIncrement
function AuctionSubRow:GetBidInfo()
	assert(self:HasRawData())
	local itemMinBid = Math.Floor(self._minBid / self._quantity, LibTSMService.IsRetail() and COPPER_PER_SILVER or 1)
	return self._minBid, itemMinBid, self._currentBid, self._isHighBidder, self._minIncrement
end

---Gets the required bid.
---@return number
function AuctionSubRow:GetRequiredBid()
	local requiredBid = nil
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		requiredBid = self._currentBid == 0 and self._minBid or (self._currentBid + self._minIncrement)
	else
		requiredBid = self._minBid
	end
	assert(requiredBid)
	return requiredBid
end

---Gets the displayed bids.
---@return number displayedBid
---@return number itemDisplayedBid
function AuctionSubRow:GetDisplayedBids()
	local displayedBid = self._currentBid == 0 and self._minBid or self._currentBid
	local itemDisplayedBid = Math.Floor(displayedBid / self._quantity, LibTSMService.IsRetail() and COPPER_PER_SILVER or 1)
	assert(displayedBid)
	return displayedBid, itemDisplayedBid
end

---Gets the item links.
---@return string itemLink
---@return string rawLink
function AuctionSubRow:GetLinks()
	assert(self:HasRawData())
	local rawLink = self._itemLink
	local itemLink = ItemInfo.GeneralizeLink(rawLink)
	return itemLink, rawLink
end

---Gets the listing info.
---@return number timeLeft
---@return number auctionId
---@return number browseId
function AuctionSubRow:GetListingInfo()
	assert(self:HasRawData())
	return self._timeLeft, self._auctionId, self._browseId
end

---Gets the quantities.
---@return number quantity
---@return number numAuctions
function AuctionSubRow:GetQuantities()
	assert(self:HasRawData())
	return self._quantity, self._numAuctions
end

---Gets the owner info.
---@return string ownerStr
---@return number numOwnerItems
function AuctionSubRow:GetOwnerInfo()
	assert(self:HasRawData())
	return self._ownerStr, self._numOwnerItems
end

---Gets the hashes for the sub row fields.
---@return string hash
---@return string hashNoSeller
function AuctionSubRow:GetHashes()
	if not self._hash then
		assert(self:HasRawData())
		if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
			self._hash = strjoin("~", tostringall(self._itemLink, self._minBid, self._minIncrement, self._buyout, self._currentBid, self._ownerStr, self._timeLeft, self._quantity, self._isHighBidder))
			self._hashNoSeller = strjoin("~", tostringall(self._itemLink, self._minBid, self._minIncrement, self._buyout, self._currentBid, self._timeLeft, self._quantity, self._isHighBidder))
		else
			local baseItemString = self:GetBaseItemString()
			local itemMinBid = Math.Floor(self._minBid / self._quantity, LibTSMService.IsRetail() and COPPER_PER_SILVER or 1)
			local itemBuyout = floor(self._buyout / self._quantity)
			local itemKeyId, itemKeySpeciesId = nil, nil
			if ItemString.IsPet(baseItemString) then
				itemKeyId = ItemString.ToId(ItemString.GetPetCage())
				itemKeySpeciesId = ItemString.ToId(baseItemString)
			elseif ItemString.IsItem(baseItemString) then
				itemKeyId = ItemString.ToId(baseItemString)
				itemKeySpeciesId = 0
			else
				error("Invalid baseItemString: "..tostring(baseItemString))
			end
			if self:IsCommodity() then
				self._hash = strjoin("~", tostringall(itemKeyId, itemBuyout, self._auctionId, self._ownerStr))
				self._hashNoSeller = strjoin("~", tostringall(itemKeyId, itemBuyout, self._auctionId))
			else
				self._hash = strjoin("~", tostringall(itemKeyId, itemKeySpeciesId, self._itemLink, itemMinBid, itemBuyout, self._currentBid, self._quantity, self._isHighBidder, self._ownerStr, self._auctionId))
				self._hashNoSeller = strjoin("~", tostringall(itemKeyId, itemKeySpeciesId, self._itemLink, itemMinBid, itemBuyout, self._currentBid, self._quantity, self._isHighBidder, self._auctionId))
			end
		end
	end
	return self._hash, self._hashNoSeller
end

---Checks if the row is equal to the specified index.
---@param index number The auction index
---@param noSeller boolean Don't check the seller name
---@return boolean
function AuctionSubRow:EqualsIndex(index, noSeller)
	assert(LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic())
	local _, itemLink, stackSize, timeLeft, buyout, seller, minIncrement, minBid, bid, isHighBidder = AuctionHouse.GetBrowseResult(index)
	seller = seller or "?"
	if minBid ~= self._minBid or minIncrement ~= self._minIncrement or buyout ~= self._buyout or bid ~= self._currentBid or stackSize ~= self._quantity or isHighBidder ~= self._isHighBidder then
		return false
	elseif not noSeller and seller ~= self._ownerStr then
		return false
	elseif itemLink ~= self._itemLink then
		return false
	elseif timeLeft ~= self._timeLeft then
		return false
	end
	return true
end

---Decrements the quantity of the row's item.
---@param amount number The amount to decrement by
function AuctionSubRow:DecrementQuantity(amount)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		assert(amount == self._quantity)
		self._numAuctions = self._numAuctions - 1
		if self._numAuctions == 0 then
			self._resultRow:RemoveSubRow(self)
		end
	else
		if self:IsCommodity() then
			self._resultRow:DecrementQuantity(amount)
		else
			assert(amount == 1 and amount == self._quantity)
			self._numAuctions = self._numAuctions - 1
			assert(self._numOwnerItems <= self._numAuctions)
			if self._numAuctions == 0 then
				self._resultRow:RemoveSubRow(self)
			end
		end
	end
end

---Processes a bid on this sub row.
function AuctionSubRow:ProcessBid()
	self._isHighBidder = true
end

---Updates the result info.
---@param newAuctionId number The auction ID
---@param newResultInfo? ExtendedItemSearchResultInfo|CommoditySearchResultInfo The new result info
function AuctionSubRow:UpdateResultInfo(newAuctionId, newResultInfo)
	if newResultInfo then
		self:_SetRawData(newResultInfo, self._browseId)
	else
		self._auctionId = newAuctionId
		self._hash = nil
		self._hashNoSeller = nil
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AuctionSubRow:_SetRawData(data, browseId, itemLink)
	self._hash = nil
	self._hashNoSeller = nil
	self._browseId = browseId
	if data then
		if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
			local _, _, stackSize, timeLeft, buyout, seller, minIncrement, minBid, bid, isHighBidder = AuctionHouse.GetBrowseResult(data)
			self._itemLink = itemLink
			self._buyout = buyout
			self._minBid = minBid
			self._currentBid = bid
			self._minIncrement = minIncrement
			self._isHighBidder = isHighBidder
			self._quantity = stackSize
			self._timeLeft = timeLeft
			self._ownerStr = seller or "?"
			self._hasOwners = seller and true or false
			self._numOwnerItems = 0
			self._auctionId = 0
		else
			if self._resultRow:IsCommodity() then
				local baseItemString = self._resultRow:GetBaseItemString()
				self._itemLink = ItemInfo.GetLink(baseItemString)
			else
				self._itemLink = data.itemLink
			end

			if self:IsCommodity() then
				self._quantity = data.quantity
				self._buyout = data.unitPrice * data.quantity
				self._minBid = self._buyout
				self._currentBid = 0
				self._minIncrement = 0
				self._isHighBidder = false
				self._numOwnerItems = data.numOwnerItems or 0
				-- Convert the timeLeftSeconds to regular timeLeft
				if data.timeLeftSeconds < 60 * 60 then
					self._timeLeft = 1
				elseif data.timeLeftSeconds < 2 * 60 * 60 then
					self._timeLeft = 2
				elseif data.timeLeftSeconds < 12 * 60 * 60 then
					self._timeLeft = 3
				else
					self._timeLeft = 4
				end
			else
				self._quantity = 1
				self._numAuctions = data.quantity
				self._buyout = data.buyoutAmount or 0
				self._minBid = data.minBid or data.buyoutAmount
				self._currentBid = data.bidAmount or 0
				self._minIncrement = 0
				self._isHighBidder = data.isHighBidder
				self._numOwnerItems = data.containsAccountItem and data.quantity or 0
				self._timeLeft = data.timeLeft + 1
			end

			self._hasOwners = #data.owners > 0
			assert(#private.ownersTemp == 0)
			for _, owner in ipairs(data.owners) do
				if owner == "?" then
					self._hasOwners = false
				end
				tinsert(private.ownersTemp, owner)
			end
			self._ownerStr = table.concat(private.ownersTemp, ",")
			wipe(private.ownersTemp)
			self._auctionId = data.auctionID
		end
		assert(self._itemLink and self._quantity and self._buyout and self._minBid and self._currentBid and self._numOwnerItems and self._timeLeft and self._ownerStr and self._auctionId)
	else
		self._itemLink = nil
		self._buyout = nil
		self._minBid = nil
		self._currentBid = nil
		self._minIncrement = nil
		self._isHighBidder = nil
		self._quantity = nil
		self._timeLeft = nil
		self._ownerStr = nil
		self._hasOwners = false
		self._numOwnerItems = nil
		self._auctionId = nil
	end
end

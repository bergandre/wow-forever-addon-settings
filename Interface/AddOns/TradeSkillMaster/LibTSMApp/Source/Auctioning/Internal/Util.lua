-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Util = LibTSMApp:InitInternal("Auctioning.Util")
local PlayerInfo = LibTSMApp:Include("Service.PlayerInfo")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	lowestAuctionTemp1 = {}, ---@type AuctioningOperationLowestAuction
	lowestAuctionTemp2 = {}, ---@type AuctioningOperationLowestAuction
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the lowest auction and returns if one was found or not.
---@param subRows AuctionSubRow[] The scanned auction sub rows
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param resultTbl AuctioningOperationLowestAuction The result table to store the lowest auction
---@return boolean
function Util.GetLowestAuction(subRows, itemString, operationSettings, resultTbl)
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		local lowestItemBuyout = nil
		local lowestAuction = nil
		for _, subRow in ipairs(subRows) do
			local _, itemBuyout = subRow:GetBuyouts()
			local quantity = subRow:GetQuantities()
			local timeLeft = subRow:GetListingInfo()
			if not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
				assert(itemBuyout > 0)
				lowestItemBuyout = lowestItemBuyout or itemBuyout
				if itemBuyout == lowestItemBuyout then
					local ownerStr = subRow:GetOwnerInfo()
					local _, auctionId = subRow:GetListingInfo()
					local _, itemMinBid = subRow:GetBidInfo()
					assert(not next(private.lowestAuctionTemp2))
					local temp = private.lowestAuctionTemp2
					temp.buyout = itemBuyout
					temp.bid = itemMinBid
					temp.seller = ownerStr
					temp.auctionId = auctionId
					temp.isPlayer = PlayerInfo.IsPlayer(ownerStr, true, true, true)
					if not lowestAuction then
						assert(not next(private.lowestAuctionTemp1))
						lowestAuction = private.lowestAuctionTemp1
						for k, v in pairs(temp) do
							lowestAuction[k] = v
						end
					elseif private.LowestAuctionCompare(temp, lowestAuction) then
						wipe(lowestAuction)
						for k, v in pairs(temp) do
							lowestAuction[k] = v
						end
					end
					wipe(temp)
				end
			end
		end
		if not lowestAuction then
			return false
		end
		for k, v in pairs(lowestAuction) do
			resultTbl[k] = v
		end
		wipe(lowestAuction)
		resultTbl.hasInvalidSeller = resultTbl.seller == "?"
		return true
	else
		local foundLowest = false
		for _, subRow in ipairs(subRows) do
			local _, itemBuyout = subRow:GetBuyouts()
			local quantity = subRow:GetQuantities()
			local timeLeft = subRow:GetListingInfo()
			if not foundLowest and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
				local ownerStr, numOwnerAuctions = subRow:GetOwnerInfo()
				local _, auctionId = subRow:GetListingInfo()
				local _, itemMinBid = subRow:GetBidInfo()
				local firstSeller = (ownerStr ~= "" and strsplit(",", ownerStr)) or (numOwnerAuctions > 0 and SessionInfo.GetCharacterName()) or "?"
				resultTbl.buyout = itemBuyout
				resultTbl.bid = itemMinBid
				resultTbl.seller = firstSeller
				resultTbl.auctionId = auctionId
				resultTbl.isPlayer = numOwnerAuctions > 0
				resultTbl.hasInvalidSeller = false
				foundLowest = true
			end
		end
		return foundLowest
	end
end

---Gets the cancel scan result.
---@param subRows AuctionSubRow[] The scanned auction sub rows
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param lowestAuction? AuctioningOperationLowestAuction The lowest auction
---@param resultTbl AuctioningOperationCancelScanResult The result table
function Util.GetCancelScanResult(subRows, itemString, operationSettings, lowestAuction, resultTbl)
	resultTbl.isPlayerOnlySeller = true
	if #subRows == 0 then
		return
	end
	assert(lowestAuction)
	for _, subRow in ipairs(subRows) do
		local _, itemBuyout = subRow:GetBuyouts()
		local quantity = subRow:GetQuantities()
		local timeLeft, auctionId = subRow:GetListingInfo()
		if not resultTbl.playerLowestItemBuyout and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and private.GetPlayerAuctionCount(subRow) > 0 then
			resultTbl.playerLowestItemBuyout = itemBuyout
			resultTbl.playerLowestAuctionId = auctionId
		end
		local isHigher = itemBuyout > lowestAuction.buyout or (itemBuyout == lowestAuction.buyout and auctionId < lowestAuction.auctionId)
		if not resultTbl.secondLowestBuyout and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and isHigher then
			resultTbl.secondLowestBuyout = itemBuyout
		end
		if resultTbl.isPlayerOnlySeller and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and private.GetPlayerAuctionCount(subRow) < ((LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and quantity or 1) then
			resultTbl.isPlayerOnlySeller = false
		end
	end
	if not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic() and resultTbl.playerLowestItemBuyout then
		for _, subRow in ipairs(subRows) do
			local _, itemBuyout = subRow:GetBuyouts()
			local quantity = subRow:GetQuantities()
			local timeLeft, auctionId = subRow:GetListingInfo()
			if not resultTbl.nonPlayerLowestAuctionId and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and private.GetPlayerAuctionCount(subRow) == 0 and itemBuyout == resultTbl.playerLowestItemBuyout then
				resultTbl.nonPlayerLowestAuctionId = auctionId
			end
		end
	end
end

---Gets the count of player auctions at a given price point.
---@param subRows AuctionSubRow[] The scanned auction sub rows
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param findBid number The bid amount
---@param findBuyout number The buyout amount
---@param findStackSize number The stack size (if applicable)
---@return number
function Util.GetPlayerAuctionCount(subRows, itemString, operationSettings, findBid, findBuyout, findStackSize)
	local playerQuantity = 0
	for _, subRow in ipairs(subRows) do
		local _, itemBuyout = subRow:GetBuyouts()
		local quantity = subRow:GetQuantities()
		local timeLeft = subRow:GetListingInfo()
		if not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
			local _, itemMinBid = subRow:GetBidInfo()
			if itemMinBid == findBid and itemBuyout == findBuyout and ((not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic()) or quantity == findStackSize) then
				local count = private.GetPlayerAuctionCount(subRow)
				if (LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and count == 0 and playerQuantity > 0 then
					-- There's another player's auction after ours, so stop counting
					break
				end
				playerQuantity = playerQuantity + count
			end
		end
	end
	return playerQuantity
end

---Gets the queue status for a scan query.
---@param query DatabaseQuery
---@return number numProcessed
---@return number numConfirmed
---@return number numFailed
---@return number numStacks
function Util.GetQueueStatus(query)
	return query:Sum("numProcessed"), query:Sum("numConfirmed"), query:Sum("numFailed"), query:Sum("numStacks")
end

---Gets the filtered sub rows from an auction query.
---@param query AuctionQuery The auction query
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param result AuctionSubRow[] The result table
function Util.GetFilteredSubRows(query, itemString, operationSettings, result)
	for _, subRow in query:ItemSubRowIterator(itemString) do
		local _, itemBuyout = subRow:GetBuyouts()
		local quantity = subRow:GetQuantities()
		local timeLeft = subRow:GetListingInfo()
		if not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
			tinsert(result, subRow)
		end
	end
	sort(result, private.SubRowSortHelper)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param a AuctionSubRow
---@param b AuctionSubRow
function private.SubRowSortHelper(a, b)
	local _, aItemBuyout = a:GetBuyouts()
	local _, bItemBuyout = b:GetBuyouts()
	if aItemBuyout ~= bItemBuyout then
		return aItemBuyout < bItemBuyout
	end
	local _, aAuctionId = a:GetListingInfo()
	local _, bAuctionId = b:GetListingInfo()
	return aAuctionId > bAuctionId
end

---@param a AuctioningOperationLowestAuction
---@param b AuctioningOperationLowestAuction
function private.LowestAuctionCompare(a, b)
	if a.auctionId ~= b.auctionId then
		return a.auctionId > b.auctionId
	end
	if a.isPlayer ~= b.isPlayer then
		return b.isPlayer
	end
	return tostring(a) < tostring(b)
end

---@param subRow AuctionSubRow
function private.GetPlayerAuctionCount(subRow)
	local ownerStr, numOwnerItems = subRow:GetOwnerInfo()
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		return PlayerInfo.IsPlayer(ownerStr, true, true, true) and select(2, subRow:GetQuantities()) or 0
	else
		return numOwnerItems
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Bid = LibTSMApp:InitInternal("Sniper.Bid")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local SniperOperation = LibTSMApp:From("LibTSMSystem"):Include("SniperOperation")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Prepares an auction query for a bid sniper search.
---@param query AuctionQuery
function Bid.PrepareQuery(query)
	assert(LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic())
	query:AddCustomFilter(private.QueryFilter)
	query:SetPage("FIRST")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param subRow AuctionRow|AuctionSubRow
function private.QueryFilter(_, subRow)
	local itemString = subRow:GetItemString()
	if not itemString or not subRow:IsSubRow() or not subRow:HasRawData() then
		-- can only filter complete subRows
		return false
	end
	local maxPrice = SniperOperation.GetMaxPrice(Group.TranslateItemString(itemString)) or nil
	if not maxPrice then
		-- no Shopping operation applies to this item, so filter it out
		return true
	end

	local _, itemDisplayedBid = subRow:GetDisplayedBids()
	return itemDisplayedBid > maxPrice
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Buyout = LibTSMApp:InitInternal("Sniper.Buyout")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local SniperOperation = LibTSMApp:From("LibTSMSystem"):Include("SniperOperation")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Prepares an auction query for a buyout sniper search.
---@param query AuctionQuery
function Buyout.PrepareQuery(query)
	query:AddCustomFilter(private.QueryFilter)
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		query:SetPage("LAST")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param subRow AuctionRow|AuctionSubRow
function private.QueryFilter(_, subRow)
	local baseItemString = subRow:GetBaseItemString()
	local itemString = subRow:GetItemString()
	local maxPrice = itemString and SniperOperation.GetMaxPrice(Group.TranslateItemString(itemString)) or nil
	if itemString and not maxPrice then
		-- No Sniper operation applies to this item, so filter it out
		return true
	end
	local auctionBuyout, itemBuyout, minItemBuyout = subRow:GetBuyouts()
	itemBuyout = itemBuyout or minItemBuyout
	if not itemBuyout then
		-- Don't have buyout info yet, so don't filter
		return false
	elseif auctionBuyout == 0 then
		-- No buyout, so filter it out
		return true
	elseif itemString then
		-- Filter if the buyout is too high
		return itemBuyout > maxPrice
	elseif (not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic()) or not ItemInfo.CanHaveVariations(baseItemString) then
		-- Check the buyout against the base item
		maxPrice = SniperOperation.GetMaxPrice(baseItemString) or 0
		return itemBuyout > maxPrice
	end

	-- Check if any variant of this item is in a group and could potentially be worth scanning
	local hasPotentialItem = false
	local iter = Group.ItemByBaseItemStringIterator(baseItemString)
	for _, groupItemString in iter do
		if itemBuyout < (SniperOperation.GetMaxPrice(groupItemString) or 0) then
			hasPotentialItem = true
			iter:Release()
			break
		end
	end
	if hasPotentialItem then
		return false
	elseif not SniperOperation.HasOperation(baseItemString) then
		-- No potential other variants we care about
		return true
	end
	return false
end

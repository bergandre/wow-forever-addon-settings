-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local AuctionSearchContext = LibTSMApp:From("LibTSMService"):IncludeClassType("AuctionSearchContext")
local VendorSearchContext = LibTSMApp:DefineInternalClassType("VendorSearchContext", AuctionSearchContext)



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the max quantity of an item which can be bought.
---@param itemString string The item
---@return number?
function VendorSearchContext:GetMaxCanBuy(itemString)
	-- Buy everything that's below the vendor cost
	return math.huge
end

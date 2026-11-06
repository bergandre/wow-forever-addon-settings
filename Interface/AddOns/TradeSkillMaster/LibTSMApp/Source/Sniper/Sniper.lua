-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Sniper = LibTSMApp:Init("Sniper")
local Bid = LibTSMApp:Include("Sniper.Bid")
local Buyout = LibTSMApp:Include("Sniper.Buyout")
local Util = LibTSMApp:Include("Sniper.Util")
local private = {
	bidSearchContext = nil,
	buyoutSearchContext = nil,
}
local BUYOUT_RESCAN_DELAY = (LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and 0 or 30



-- ============================================================================
-- Module Loading
-- ============================================================================

Sniper:OnModuleLoad(function()
	private.bidSearchContext = Util.CreateSearchContext("SNIPER_BID_SEARCH", Bid.PrepareQuery, 0)
	private.buyoutSearchContext = Util.CreateSearchContext("SNIPER_BUYOUT_SEARCH", Buyout.PrepareQuery, BUYOUT_RESCAN_DELAY)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the auction search context for a bid sniper search.
---@return AuctionSearchContext
function Sniper.GetBidSearchContext()
	return private.bidSearchContext
end

---Gets the auction search context for a buyout sniper search.
---@return AuctionSearchContext
function Sniper.GetBuyoutSearchContext()
	return private.buyoutSearchContext
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Operations = LibTSMApp:Init("Price.Operations")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local ShoppingOperation = LibTSMApp:From("LibTSMSystem"):Include("ShoppingOperation")
local SniperOperation = LibTSMApp:From("LibTSMSystem"):Include("SniperOperation")



-- ============================================================================
-- Module Loading
-- ============================================================================

Operations:OnModuleLoad(function()
	CustomString.RegisterSource("Operations", "AuctioningOpMin", L["First Auctioning Operation Min Price"], AuctioningOperation.GetItemMinPrice, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "AuctioningOpMax", L["First Auctioning Operation Max Price"], AuctioningOperation.GetItemMaxPrice, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "AuctioningOpNormal", L["First Auctioning Operation Normal Price"], AuctioningOperation.GetItemNormalPrice, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "ShoppingOpMax", L["Shopping Operation Max Price"], ShoppingOperation.GetMaxPrice, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "SniperOpMax", L["Sniper Operation Max Price"], SniperOperation.GetMaxPrice, CustomString.SOURCE_TYPE.VOLATILE)
end)

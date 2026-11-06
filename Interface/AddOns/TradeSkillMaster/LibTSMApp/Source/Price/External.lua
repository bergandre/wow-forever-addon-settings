-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local External = LibTSMApp:Init("Price.External")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local Addon = LibTSMApp:From("LibTSMWoW"):Include("API.Addon")
local Hook = LibTSMApp:From("LibTSMWoW"):Include("Util.Hook")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
	registeredAuctioneerSources = {},
	oribosExchangeTemp = {}
}



-- ============================================================================
-- Module Loading
-- ============================================================================

External:OnModuleLoad(function()
	private.RegisterAuctioneer()
	private.RegisterAuctionator()
	private.RegisterOribosExchange()
	private.RegisterAHDB()
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RegisterAuctioneer()
	if not Addon.IsEnabled("Auc-Advanced") then
		return
	end
	local AucAdvanced = _G.AucAdvanced ---@diagnostic disable-line: undefined-field
	if not AucAdvanced then
		return
	end

	Hook.SecurePost(AucAdvanced, "SendProcessorMessage", function(msg)
		if msg == "scanfinish" then
			for _, source in ipairs(private.registeredAuctioneerSources) do
				CustomString.InvalidateCache(source)
			end
		end
	end)
	if AucAdvanced.Modules.Util.Appraiser and AucAdvanced.Modules.Util.Appraiser.GetPrice then
		local function PriceFunc(itemString)
			local itemLink = ItemInfo.GetLink(itemString)
			return AucAdvanced.Modules.Util.Appraiser.GetPrice(itemLink)
		end
		CustomString.RegisterSource("External", "AucAppraiser", L["Auctioneer - Appraiser"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		tinsert(private.registeredAuctioneerSources, "AucAppraiser")
	end
	if AucAdvanced.Modules.Util.SimpleAuction and AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems then
		local function PriceFunc(itemString)
			local itemLink = ItemInfo.GetLink(itemString)
			return select(6, AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems(itemLink)) or nil
		end
		CustomString.RegisterSource("External", "AucMinBuyout", L["Auctioneer - Minimum Buyout"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		tinsert(private.registeredAuctioneerSources, "AucMinBuyout")
	end
	if AucAdvanced.API.GetMarketValue then
		local function PriceFunc(itemString)
			local itemLink = ItemInfo.GetLink(itemString)
			return AucAdvanced.API.GetMarketValue(itemLink)
		end
		CustomString.RegisterSource("External", "AucMarket", L["Auctioneer - Market Value"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		tinsert(private.registeredAuctioneerSources, "AucMarket")
	end
end

function private.RegisterAuctionator()
	if not Addon.IsEnabled("Auctionator") then
		return
	end

	---@diagnostic disable: undefined-field
	local Auctionator = _G.Auctionator
	local Atr_GetAuctionBuyout = _G.Atr_GetAuctionBuyout
	local Atr_RegisterFor_DBupdated = _G.Atr_RegisterFor_DBupdated
	---@diagnostic enable: undefined-field

	local function HandleDBUpdate()
		CustomString.InvalidateCache("AtrValue")
	end

	local PriceFunc = nil
	if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.RegisterForDBUpdate then
		-- Retail version
		local ok = pcall(function()
			Auctionator.API.v1.RegisterForDBUpdate("TradeSkillMaster", HandleDBUpdate)
		end)
		if not ok then
			return
		end
		PriceFunc = function(itemString)
			local itemLink = ItemInfo.GetLink(itemString)
			return Auctionator.API.v1.GetAuctionPriceByItemLink("TradeSkillMaster", itemLink)
		end
	elseif Atr_GetAuctionBuyout and Atr_RegisterFor_DBupdated then
		-- Classic version
		Atr_RegisterFor_DBupdated(HandleDBUpdate)
		PriceFunc = function(itemString)
			local itemLink = ItemInfo.GetLink(itemString)
			return Atr_GetAuctionBuyout(itemLink)
		end
	else
		return
	end

	CustomString.RegisterSource("External", "AtrValue", L["Auctionator - Auction Value"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
end

function private.RegisterOribosExchange()
	if not Addon.IsEnabled("OribosExchange") then
		return
	end
	local OEMarketInfo = _G.OEMarketInfo ---@diagnostic disable-line: undefined-field
	if not OEMarketInfo then
		return
	end

	local function PriceFuncHelper(itemString, key)
		local itemLink = ItemInfo.GetLink(itemString)
		local data = OEMarketInfo(itemLink, private.oribosExchangeTemp)
		return data and data[key] or nil
	end

	local function RealmPriceFunc(itemString)
		return PriceFuncHelper(itemString, "market")
	end
	CustomString.RegisterSource("External", "OERealm", L["Oribos Exchange Realm Price"], RealmPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)

	local function RegionPriceFunc(itemString)
		return PriceFuncHelper(itemString, "region")
	end
	CustomString.RegisterSource("External", "OERegion", L["Oribos Exchange Region Price"], RegionPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
end

function private.RegisterAHDB()
	if not Addon.IsEnabled("AuctionDB") then
		return
	end
	local AHDB = _G.AuctionDB ---@diagnostic disable-line: undefined-field
	if not AHDB or not AHDB.AHendOfScanCB or not AHDB.AHGetAuctionInfoByLink then
		return
	end

	Hook.SecurePost(AHDB, "AHendOfScanCB", function()
		CustomString.InvalidateCache("AHDBMinBuyout")
		CustomString.InvalidateCache("AHDBMinBid")
	end)

	local function PriceFuncHelper(itemString, key)
		local itemLink = ItemInfo.GetLink(itemString)
		local info = AHDB:AHGetAuctionInfoByLink(itemLink)
		return info and info[key] or nil
	end

	local function MinBuyoutPriceFunc(itemString)
		return PriceFuncHelper(itemString, "minBuyout")
	end
	CustomString.RegisterSource("External", "AHDBMinBuyout", L["AHDB Minimum Buyout"], MinBuyoutPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)

	local function MinBidPriceFunc(itemString)
		return PriceFuncHelper(itemString, "minBid")
	end
	CustomString.RegisterSource("External", "AHDBMinBid", L["AHDB Minimum Bid"], MinBidPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AuctionDBConfig = LibTSMApp:Init("Config.AuctionDBConfig")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local AuctionDB = LibTSMApp:From("LibTSMService"):Include("AuctionDB")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local private = {}



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctionDBConfig:OnModuleLoad(function()
	AuctionDB.Configure(private.HandleDataLoaded)
	local function RegisterSource(key, label, dataFunc, dataKey)
		local function PriceFunc(itemString)
			return dataFunc(dataKey, itemString)
		end
		CustomString.RegisterSource("AuctionDB", key, label, PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
	end
	local function RegisterNumberSource(key, label, dataFunc, dataKey)
		local function PriceFunc(itemString)
			local result = dataFunc(dataKey, itemString)
			return result and (result / 1000) or nil
		end
		CustomString.RegisterSource("AuctionDB", key, label, PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		CustomStringFormat.SetFormat(key, CustomStringFormat.FORMAT.NUMBER)
	end
	RegisterSource("DBMarket", L["AuctionDB - Market Value"], AuctionDB.GetRealmData, "marketValue")
	RegisterSource("DBMinBuyout", L["AuctionDB - Minimum Buyout"], AuctionDB.GetRealmData, "minBuyout")
	RegisterSource("DBRecent", L["AuctionDB - Recent Value"], AuctionDB.GetRealmData, "marketValueRecent")
	RegisterSource("DBHistorical", L["AuctionDB - Historical Price"], AuctionDB.GetRealmData, "historical")
	RegisterSource("DBNumAuctions", L["AuctionDB - Number of Auctions"], AuctionDB.GetRealmData, "numAuctions")
	if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
		RegisterSource("DBAltMarket", L["AuctionDB - Alt Realm Market Value"], AuctionDB.GetAltRealmData, "marketValue")
		RegisterSource("DBAltMinBuyout", L["AuctionDB - Alt Realm Minimum Buyout"], AuctionDB.GetAltRealmData, "minBuyout")
		RegisterSource("DBAltRecent", L["AuctionDB - Alt Realm Recent Value"], AuctionDB.GetAltRealmData, "marketValueRecent")
		RegisterSource("DBAltHistorical", L["AuctionDB - Alt Realm Historical Price"], AuctionDB.GetAltRealmData, "historical")
		RegisterSource("DBAltNumAuctions", L["AuctionDB - Alt Realm Number of Auctions"], AuctionDB.GetAltRealmData, "numAuctions")
	end
	RegisterSource("DBRegionMarketAvg", L["AuctionDB - Region Market Value Average"], AuctionDB.GetRegionData, "regionMarketValue")
	RegisterSource("DBRegionHistorical", L["AuctionDB - Region Historical Price"], AuctionDB.GetRegionData, "regionHistorical")
	RegisterSource("DBRegionSaleAvg", L["AuctionDB - Region Sale Average"], AuctionDB.GetRegionData, "regionSale")
	RegisterNumberSource("DBRegionSaleRate", L["AuctionDB - Region Sale Rate"], AuctionDB.GetRegionData, "regionSalePercent")
	RegisterNumberSource("DBRegionSoldPerDay", L["AuctionDB - Region Sold Per Day"], AuctionDB.GetRegionData, "regionSoldPerDay")
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleDataLoaded()
	if AuctionDB.GetAppDataUpdateTimes() == 0 then
		ChatMessage.PrintfUser(L["TSM doesn't currently have any AuctionDB pricing data for your realm. We recommend you download the TSM Desktop Application from %s to automatically update your AuctionDB data (and auto-backup your TSM settings)."], ChatMessage.ColorUserAccentText("https://tradeskillmaster.com"))
	end
	CustomString.InvalidateCache("DBMarket")
	CustomString.InvalidateCache("DBMinBuyout")
	CustomString.InvalidateCache("DBHistorical")
	CustomString.InvalidateCache("DBRecent")
	CustomString.InvalidateCache("DBRegionMarketAvg")
	CustomString.InvalidateCache("DBRegionHistorical")
	CustomString.InvalidateCache("DBRegionSaleAvg")
	CustomString.InvalidateCache("DBRegionSaleRate")
	CustomString.InvalidateCache("DBRegionSoldPerDay")
end

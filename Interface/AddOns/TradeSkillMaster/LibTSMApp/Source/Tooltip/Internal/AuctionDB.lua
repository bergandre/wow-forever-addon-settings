-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AuctionDB = LibTSMApp:InitInternal("Tooltip.AuctionDB")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local TimeFormat = LibTSMApp:From("LibTSMWoW"):Include("UI.TimeFormat")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMApp:From("LibTSMService"):Include("UI.TextureAtlas")
local AuctionDBService = LibTSMApp:From("LibTSMService"):Include("AuctionDB")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(AuctionDB, function(db)
	private.settings = db:NewView("AuctionDBSettings")
		:AddKey("realm", "coreOptions", "auctionDBAltRealm")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function AuctionDB.Register()
	local tooltipInfo = TooltipInfo()
		:SetHeadings(L["TSM AuctionDB"], private.PopulateRightText)
		:SetSettingsModule("AuctionDB")
		:AddSettingEntry("minBuyout", true, private.PopulateMinBuyoutLine)
		:AddSettingEntry("marketValueRecent", false, private.PopulateRecentValueLine)
		:AddSettingValueEntry("marketValue", "noTrend", "none", "withTrend", private.PopulateMarketValueLine, false)
		:AddSettingValueEntry("marketValue", "withTrend", "none", "withTrend", private.PopulateMarketValueLine, true)
		:AddSettingEntry("historical", false, private.PopulateHistoricalLine)
	if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
		tooltipInfo
			:AddSettingEntry("altMinBuyout", false, private.PopulateAltMinBuyoutLine)
			:AddSettingEntry("altMarketValueRecent", false, private.PopulateAltRecentValueLine)
			:AddSettingValueEntry("altMarketValue", "noTrend", "none", "none", private.PopulateAltMarketValueLine, false)
			:AddSettingValueEntry("altMarketValue", "withTrend", "none", "none", private.PopulateAltMarketValueLine, true)
			:AddSettingEntry("altHistorical", false, private.PopulateAltHistoricalLine)
	end
	tooltipInfo
		:AddSettingValueEntry("regionMarketValue", "noTrend", "none", "withTrend", private.PopulateRegionMarketValueLine, false)
		:AddSettingValueEntry("regionMarketValue", "withTrend", "none", "withTrend", private.PopulateRegionMarketValueLine, true)
		:AddSettingEntry("regionHistorical", false, private.PopulateRegionHistoricalLine)
		:AddSettingEntry("regionSale", true, private.PopulateRegionSaleAvgLine)
		:AddSettingEntry("regionSalePercent", true, private.PopulateRegionSaleRateLine)
		:AddSettingEntry("regionSoldPerDay", true, private.PopulateRegionDailySoldLine)
	Registry.Add(tooltipInfo)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateMinBuyoutLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, L["Min Buyout"], "DBMinBuyout")
end

---@param tooltip TooltipBuilder
function private.PopulateRecentValueLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, L["Recent Value"], "DBRecent")
end

---@param tooltip TooltipBuilder
function private.PopulateMarketValueLine(tooltip, itemString, withTrend)
	private.AddPriceLine(tooltip, itemString, L["Market Value"], "DBMarket", withTrend and "DBHistorical" or nil)
end

---@param tooltip TooltipBuilder
function private.PopulateHistoricalLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, L["Historical Price"], "DBHistorical")
end

---@param tooltip TooltipBuilder
function private.PopulateAltMinBuyoutLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, private.settings.auctionDBAltRealm.." - "..L["Min Buyout"], "DBAltMinBuyout")
end

---@param tooltip TooltipBuilder
function private.PopulateAltRecentValueLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, private.settings.auctionDBAltRealm.." - "..L["Recent Value"], "DBAltRecent")
end

---@param tooltip TooltipBuilder
function private.PopulateAltMarketValueLine(tooltip, itemString, withTrend)
	private.AddPriceLine(tooltip, itemString, private.settings.auctionDBAltRealm.." - "..L["Market Value"], "DBAltMarket", withTrend and "DBAltHistorical" or nil)
end

---@param tooltip TooltipBuilder
function private.PopulateAltHistoricalLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, private.settings.auctionDBAltRealm.." - "..L["Historical Price"], "DBAltHistorical")
end

---@param tooltip TooltipBuilder
function private.PopulateRegionMarketValueLine(tooltip, itemString, withTrend)
	private.AddPriceLine(tooltip, itemString, L["Region Market Value Avg"], "DBRegionMarketAvg", withTrend and "DBRegionHistorical" or nil)
end

---@param tooltip TooltipBuilder
function private.PopulateRegionHistoricalLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, L["Region Historical Price"], "DBRegionHistorical")
end

---@param tooltip TooltipBuilder
function private.PopulateRegionSaleAvgLine(tooltip, itemString)
	private.AddPriceLine(tooltip, itemString, L["Region Sale Avg"], "DBRegionSaleAvg")
end

---@param tooltip TooltipBuilder
function private.PopulateRegionSaleRateLine(tooltip, itemString)
	private.AddDecimalLine(tooltip, itemString, L["Region Sale Rate"], "DBRegionSaleRate * 1000")
end

---@param tooltip TooltipBuilder
function private.PopulateRegionDailySoldLine(tooltip, itemString)
	private.AddDecimalLine(tooltip, itemString, L["Region Avg Daily Sold"], "DBRegionSoldPerDay * 1000")
end

---@param tooltip TooltipBuilder
function private.AddPriceLine(tooltip, itemString, label, priceString, trendPriceString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddItemValueLine(label, 11, trendPriceString and private.FormatTrend(0) or nil)
		return
	end
	local value = CustomString.GetValue(priceString, itemString)
	if not value then
		return
	end
	local trendStr = nil
	if trendPriceString then
		local referenceValue = CustomString.GetValue(trendPriceString, itemString)
		local trend = referenceValue and Math.Round((value - referenceValue) * 100 / referenceValue)
		trendStr = trend and private.FormatTrend(trend) or "[---]"
	end
	tooltip:AddItemValueLine(label, value, trendStr)
end

---@param tooltip TooltipBuilder
function private.AddDecimalLine(tooltip, itemString, label, priceString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(label, "0.011")
		return
	end
	local value = CustomString.GetValue(priceString, itemString)
	if not value then
		return
	end
	tooltip:AddTextLine(label, format("%0.3f", value / 1000))
end

function private.FormatTrend(trend)
	local color = trend >= 0 and "positive/main" or "error/main"
	local iconTextureKey = trend >= 0 and TextureAtlas.GetFlippedVerticallyKey("iconPack.12x12/Caret/Down") or "iconPack.12x12/Caret/Down"
	local iconTextureStr = TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey(iconTextureKey, color))
	return "["..iconTextureStr..Theme.GetColor(color):ColorText(abs(trend).."%").."]"
end

---@param tooltip TooltipBuilder
function private.PopulateRightText(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		local ageStr = Theme.GetColor("positive/main"):ColorText(format(L["%s ago"], TimeFormat.Duration(120)))
		return tooltip:ApplyValueColor(format(L["%d auctions"], 5)).." ("..ageStr..")"
	end

	local lastScan = AuctionDBService.GetAppDataUpdateTimes()
	if lastScan == 0 then
		return tooltip:ApplyValueColor(L["Not Scanned"])
	end

	local numAuctions = CustomString.GetValue("DBNumAuctions", itemString) or 0
	local timeColor = AuctionDBService.IsLastScanRecent() and Theme.GetColor("positive/main") or Theme.GetColor("error/main")
	local timeDiff = TimeFormat.Duration(LibTSMApp.GetTime() - lastScan)
	return tooltip:ApplyValueColor(format(L["%d auctions"], numAuctions)).." ("..timeColor:ColorText(format(L["%s ago"], timeDiff))..")"
end

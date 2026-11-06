-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Accounting = LibTSMApp:InitInternal("Tooltip.Accounting")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local TimeFormat = LibTSMApp:From("LibTSMWoW"):Include("UI.TimeFormat")
local Auctions = LibTSMApp:From("LibTSMService"):Include("Ledger.Auctions")
local Transactions = LibTSMApp:From("LibTSMService"):Include("Ledger.Transactions")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Accounting.Register()
	Registry.Add(TooltipInfo()
		:SetHeadings(L["TSM Accounting"])
		:SetSettingsModule("Accounting")
		:AddSettingEntry("purchase", true, private.PopulatePurchaseLines)
		:AddSettingEntry("sale", true, private.PopulateSaleLines)
		:AddSettingEntry("saleRate", false, private.PopulateSaleRateLine)
		:AddSettingEntry("expiredAuctions", false, private.PopulateExpireLine)
		:AddSettingEntry("cancelledAuctions", false, private.PopulateCancelLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateSaleLines(tooltip, itemString, _, showStackValues)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddQuantityValueLine(L["Sold (Min/Avg/Max Price)"], 5, 10, 20, 50)
		tooltip:AddTextLine(L["Last Sold"], format(L["%s ago"], TimeFormat.Duration(60)))
		return
	end

	local totalPrice, totalSaleNum = Transactions.GetSaleStats(itemString)
	if not totalSaleNum then
		return
	end

	local avgSalePrice = Math.Round(totalPrice / totalSaleNum)
	local lastSaleTime = Transactions.GetLastSaleTime(itemString)
	assert(lastSaleTime)
	if showStackValues then
		tooltip:AddQuantityValueLine(L["Sold (Total Price)"], totalSaleNum, avgSalePrice * totalSaleNum)
	else
		local minSellPrice = CustomString.GetSourceValue("MinSell", itemString) or 0
		local maxSellPrice = CustomString.GetSourceValue("MaxSell", itemString) or 0
		tooltip:AddQuantityValueLine(L["Sold (Min/Avg/Max Price)"], totalSaleNum, minSellPrice, avgSalePrice, maxSellPrice)
	end
	tooltip:AddTextLine(L["Last Sold"], format(L["%s ago"], TimeFormat.Duration(LibTSMApp.GetTime() - lastSaleTime)))
end

---@param tooltip TooltipBuilder
function private.PopulateExpireLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(L["Expired Since Last Sale"], 2)
		return
	end

	local _, expiredNum = Auctions.GetStats(itemString, Transactions.GetLastSaleTime(itemString))
	if expiredNum == 0 then
		return
	end
	tooltip:AddTextLine(L["Expired Since Last Sale"], expiredNum)
end

---@param tooltip TooltipBuilder
function private.PopulateCancelLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(L["Cancelled Since Last Sale"], 2)
		return
	end

	local cancelledNum = Auctions.GetStats(itemString, Transactions.GetLastSaleTime(itemString))
	if cancelledNum == 0 then
		return
	end
	tooltip:AddTextLine(L["Cancelled Since Last Sale"], cancelledNum)
end

---@param tooltip TooltipBuilder
function private.PopulateSaleRateLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(L["Sale Rate"], 0.7)
		return
	end

	local saleRate = CustomString.GetSourceValue("SaleRate", itemString)
	if not saleRate then
		return
	end
	tooltip:AddTextLine(L["Sale Rate"], saleRate)
end

---@param tooltip TooltipBuilder
function private.PopulatePurchaseLines(tooltip, itemString, _, showStackValues)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddQuantityValueLine(L["Purchased (Min/Avg/Max Price)"], 3, 15, Math.Round(78 / 3), 55)
		tooltip:AddItemValueLine(L["Smart Avg Buy Price"], 25)
		tooltip:AddTextLine(L["Last Purchased"], format(L["%s ago"], TimeFormat.Duration(3600)))
		return
	end

	local totalPrice, totalNum = Transactions.GetBuyStats(itemString)
	if not totalPrice or not totalNum then
		return
	end

	local lastBuyTime = Transactions.GetLastBuyTime(itemString)
	assert(lastBuyTime)
	if showStackValues then
		tooltip:AddQuantityValueLine(L["Purchased (Total Price)"], totalNum, totalPrice)
	else
		local minPrice = CustomString.GetSourceValue("MinBuy", itemString) or 0
		local maxPrice = CustomString.GetSourceValue("MaxBuy", itemString) or 0
		tooltip:AddQuantityValueLine(L["Purchased (Min/Avg/Max Price)"], totalNum, minPrice, Math.Round(totalPrice / totalNum), maxPrice)
	end
	tooltip:AddItemValueLine(L["Smart Avg Buy Price"], CustomString.GetSourceValue("SmartAvgBuy", itemString))
	tooltip:AddTextLine(L["Last Purchased"], format(L["%s ago"], TimeFormat.Duration(LibTSMApp.GetTime() - lastBuyTime)))
end

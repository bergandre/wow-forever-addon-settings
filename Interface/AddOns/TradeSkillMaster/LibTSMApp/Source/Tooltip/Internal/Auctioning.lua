-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Auctioning = LibTSMApp:InitInternal("Tooltip.Auctioning")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Auctioning.Register()
	Registry.Add(TooltipInfo()
		:SetHeadings(L["TSM Auctioning"])
		:SetSettingsModule("Auctioning")
		:AddSettingEntry("postQuantity", false, private.PopulatePostQuantityLine)
		:AddSettingEntry("operationPrices", false, private.PopulatePricesLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulatePostQuantityLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
			tooltip:AddTextLine(L["Post Quantity"], "5x200")
		else
			tooltip:AddTextLine(L["Post Quantity"], 5)
		end
		return
	elseif ItemInfo.IsSoulbound(itemString) then
		return
	end

	itemString = Group.TranslateItemString(itemString)
	local operationSettings = AuctioningOperation.GetFirstByItem(itemString)
	if not operationSettings then
		return
	end

	local _, stackSize, postCap = AuctioningOperation.GetPostQuantities(itemString, operationSettings, math.huge)
	if not stackSize or not postCap then
		tooltip:AddTextLine(L["Post Quantity"], "---")
		return
	end

	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		tooltip:AddTextLine(L["Post Quantity"], postCap.."x"..stackSize)
	else
		tooltip:AddTextLine(L["Post Quantity"], postCap)
	end
end

---@param tooltip TooltipBuilder
function private.PopulatePricesLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		tooltip:AddItemValuesLine(L["Min/Normal/Max Prices"], 20, 24, 29)
		return
	elseif ItemInfo.IsSoulbound(itemString) then
		return
	end

	itemString = Group.TranslateItemString(itemString)
	local operationSettings = AuctioningOperation.GetFirstByItem(itemString)
	if not operationSettings then
		return
	end

	local minPrice = AuctioningOperation.GetItemMinPrice(itemString, operationSettings)
	local normalPrice = AuctioningOperation.GetItemNormalPrice(itemString, operationSettings)
	local maxPrice = AuctioningOperation.GetItemMaxPrice(itemString, operationSettings)
	tooltip:AddItemValuesLine(L["Min/Normal/Max Prices"], minPrice, normalPrice, maxPrice)
end

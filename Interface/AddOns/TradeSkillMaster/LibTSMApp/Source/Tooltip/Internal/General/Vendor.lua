-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Vendor = LibTSMApp:InitInternal("Tooltip.General.Vendor")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local VendorBuy = LibTSMApp:From("LibTSMService"):Include("Item.VendorBuy")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds tooltip entries.
---@param tooltipInfo TooltipInfo
function Vendor.AddEntries(tooltipInfo)
	tooltipInfo:AddSettingEntry("vendorBuyTooltip", nil, private.PopulateVendorBuyLine)
	tooltipInfo:AddSettingEntry("vendorSellTooltip", nil, private.PopulateVendorSellLine)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateVendorBuyLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example item
		tooltip:AddItemValueLine(L["Vendor Buy Price"], 50)
		return
	end

	local value = VendorBuy.Get(itemString) or 0
	if value == 0 then
		return
	end
	tooltip:AddItemValueLine(L["Vendor Buy Price"], value)
end

---@param tooltip TooltipBuilder
function private.PopulateVendorSellLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example item
		tooltip:AddItemValueLine(L["Vendor Sell Price"], 8)
		return
	end

	local value = ItemInfo.GetVendorSell(itemString) or 0
	if value == 0 then
		return
	end
	tooltip:AddItemValueLine(L["Vendor Sell Price"], value)
end

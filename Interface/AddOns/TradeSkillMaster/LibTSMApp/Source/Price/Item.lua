-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Item = LibTSMApp:Init("Price.Item")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local VendorBuy = LibTSMApp:From("LibTSMService"):Include("Item.VendorBuy")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local private = {
	itemInfoPublisher = nil, ---@diagnostic disable-line: tsm-private
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Item:OnModuleLoad(function()
	private.itemInfoPublisher = ItemInfo.GetPublisher()
		:CallFunction(private.HandleItemInfoUpdate)
		:Stored()
	CustomString.RegisterSource("Item", "VendorBuy", L["Buy from Vendor"], VendorBuy.Get, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "VendorSell", L["Sell to Vendor"], ItemInfo.GetVendorSell, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "ItemQuality", L["Item Quality"], ItemInfo.GetQuality, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "ItemLevel", L["Item Level"], ItemInfo.GetItemLevel, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "RequiredLevel", L["Required Level"], ItemInfo.GetMinLevel, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "MaxStack", L["Maximum Stack Size"], ItemInfo.GetMaxStack, CustomString.SOURCE_TYPE.NORMAL)
	CustomStringFormat.SetFormat("ItemQuality", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("ItemLevel", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("RequiredLevel", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("MaxStack", CustomStringFormat.FORMAT.NUMBER)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleItemInfoUpdate(itemString)
	CustomString.InvalidateCache("VendorBuy", itemString)
	CustomString.InvalidateCache("VendorSell", itemString)
	CustomString.InvalidateCache("ItemQuality", itemString)
	CustomString.InvalidateCache("ItemLevel", itemString)
	CustomString.InvalidateCache("RequiredLevel", itemString)
end

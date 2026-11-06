-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local VendorSearch = LibTSMApp:DefineInternalClassType("VendorSearch")
local VendorSearchContext = LibTSMApp:IncludeClassType("VendorSearchContext")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local AuctionDB = LibTSMApp:From("LibTSMService"):Include("AuctionDB")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	created = false,
}



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function VendorSearch:__init()
	-- This is a singleton class since it contains a thread
	assert(not private.created)
	private.created = true
	self._scanThreadId = Threading.New("SHOPPING_VENDOR_SEARCH", self:__closure("_ScanThread"))
	self._searchContext = VendorSearchContext(self._scanThreadId, private.MarketValueFunction)
	self._itemListTemp = {}
end



-- ============================================================================
-- Public Class Functions
-- ============================================================================

---Gets the search context for the vendor search.
---@return VendorSearchContext
function VendorSearch:GetSearchContext()
	return self._searchContext:SetScanContext(L["Vendor Search"], nil, nil, L["Vendor Sell Price"])
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param auctionScan AuctionScanManager
function VendorSearch.__private:_ScanThread(auctionScan)
	if not AuctionDB.IsLastScanRecent() then
		ChatMessage.PrintUser(L["No recent AuctionDB scan data found."])
		return false
	end

	-- Create the list of items
	wipe(self._itemListTemp)
	AuctionDB.GetLastScanItemsThreaded(private.ShouldFilter, self._itemListTemp)

	-- Run the scan
	for _, query in auctionScan:AddItemListQueriesThreaded(self._itemListTemp) do
		query:AddCustomFilter(private.QueryFilter)
	end
	Table.WipeAndDeallocate(self._itemListTemp)
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
	return true
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ShouldFilter(itemString, minBuyout)
	local vendorSell = ItemInfo.GetVendorSell(itemString) or 0
	return minBuyout >= vendorSell
end

---@param row AuctionRow|AuctionSubRow
function private.QueryFilter(_, row)
	local itemString = row:GetItemString()
	if not itemString then
		return false
	end
	local _, itemBuyout = row:GetBuyouts()
	if not itemBuyout then
		return false
	end
	local vendorSell = ItemInfo.GetVendorSell(itemString)
	return not vendorSell or itemBuyout == 0 or itemBuyout >= vendorSell
end

---@param row AuctionSubRow
function private.MarketValueFunction(row)
	return ItemInfo.GetVendorSell(row:GetItemString() or row:GetBaseItemString())
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local DisenchantSearch = LibTSMApp:DefineInternalClassType("DisenchantSearch")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local AuctionDB = LibTSMApp:From("LibTSMService"):Include("AuctionDB")
local AuctionSearchContext = LibTSMApp:From("LibTSMService"):IncludeClassType("AuctionSearchContext")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settings = nil,
	created = false,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(DisenchantSearch, function(db)
	private.settings = db:NewView("DisenchantSearchSettings")
		:AddKey("global", "shoppingOptions", "minDeSearchLvl")
		:AddKey("global", "shoppingOptions", "maxDeSearchLvl")
		:AddKey("global", "shoppingOptions", "maxDeSearchPercent")
		:Commit()
end)



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DisenchantSearch:__init()
	-- This is a singleton class since it contains a thread
	assert(not private.created)
	private.created = true
	self._scanThreadId = Threading.New("SHOPPING_DISENCHANT_SEARCH", self:__closure("_ScanThread"))
	self._searchContext = AuctionSearchContext(self._scanThreadId, private.MarketValueFunction)
	self._itemListTemp = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the search context for the disenchant search.
---@return AuctionSearchContext
function DisenchantSearch:GetSearchContext()
	return self._searchContext:SetScanContext(L["Disenchant Search"], nil, nil, L["Disenchant Value"])
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DisenchantSearch.__private:_ScanThread(auctionScan)
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
	if not ItemInfo.IsDisenchantable(itemString) then
		return true
	end

	local itemLevel = ItemInfo.GetItemLevel(itemString) or -1
	if itemLevel < private.settings.minDeSearchLvl or itemLevel > private.settings.maxDeSearchLvl then
		return true
	end

	return private.IsItemBuyoutTooHigh(itemString, minBuyout)
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
	return private.IsItemBuyoutTooHigh(itemString, itemBuyout)
end

function private.IsItemBuyoutTooHigh(itemString, itemBuyout)
	local disenchantValue = CustomString.GetSourceValue("Destroy", itemString)
	return not disenchantValue or itemBuyout > private.settings.maxDeSearchPercent / 100 * disenchantValue
end

function private.MarketValueFunction(row)
	return CustomString.GetSourceValue("Destroy", row:GetItemString() or row:GetBaseItemString())
end

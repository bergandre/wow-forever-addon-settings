-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local BuyScanner = LibTSMService:InitInternal("Vendor.BuyScanner")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local Merchant = LibTSMService:From("LibTSMWoW"):Include("API.Merchant")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	db = nil,
	updateTimer = nil,
	rescanTimer = nil,
	costItemTemp = {},
	costQuantityTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

BuyScanner:OnModuleLoad(function()
	private.db = Database.NewSchema("VENDOR_ITEMS")
		:AddUniqueNumberField("index")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddNumberField("price")
		:AddStringListField("costItems")
		:AddNumberListField("costQuantities")
		:AddNumberField("stackSize")
		:AddNumberField("numAvailable")
		:Commit()
	private.updateTimer = DelayTimer.New("VENDOR_BUY_UPDATE_DB", private.UpdateMerchantDB)
	private.rescanTimer = DelayTimer.New("VENDOR_BUY_RESCAN", private.UpdateMerchantDB)
	DefaultUI.RegisterMerchantVisibleCallback(private.MerchantVisibilityHandler)
	Event.Register("MERCHANT_UPDATE", private.MerchantUpdateEventHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new query for the scanner DB.
---@return DatabaseQuery
function BuyScanner.NewQuery()
	return private.db:NewOwnedQuery()
end

---Gets the first index of the specified item (or nil if it doesn't exist).
---@param itemString string The item string or base item string to search for
---@return number?
function BuyScanner.GetFirstIndex(itemString)
	local index = private.db:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:OrderBy("index", true)
		:GetFirstResult("index")
	if not index and ItemString.GetBaseFast(itemString) == itemString then
		index = private.db:NewAutoReleaseQuery()
			:Equal("baseItemString", itemString)
			:OrderBy("index", true)
			:GetFirstResult("index")
	end
	return index
end

---Iterates over the additional cost items and quantities.
---@param index number The index of the row to iterate over
---@return fun(): number, string, number @Iterator with fields: `index`, `itemString`, `quantity`
function BuyScanner.AdditionalCostIterator(index)
	assert(#private.costItemTemp == 0 and #private.costQuantityTemp == 0)
	if private.db:HasUniqueRow("index", index) then
		local itemsIter, quantitiesIter = private.db:GetRowFields(private.db:GetUniqueRow("index", index), "costItems", "costQuantities")
		Table.InsertFromIterator(private.costItemTemp, itemsIter)
		Table.InsertFromIterator(private.costQuantityTemp, quantitiesIter)
		assert(#private.costItemTemp == #private.costQuantityTemp)
	end
	return private.AdditionalCostIterator
end

---Gets the max number of an item that can be afforded.
---@param index number The index of the item
---@return number
function BuyScanner.GetNumCanAfford(index)
	if not private.db:HasUniqueRow("index", index) then
		return 0
	end

	local price, stackSize, itemsIter, quantitiesIter = private.db:GetRowFields(private.db:GetUniqueRow("index", index), "price", "stackSize", "costItems", "costQuantities")
	local maxCanAfford = math.huge

	-- Check the price
	if price > 0 then
		maxCanAfford = min(floor(Currency.GetMoney() / price), maxCanAfford)
	end

	-- Check the additional cost
	assert(#private.costItemTemp == 0 and #private.costQuantityTemp == 0)
	Table.InsertFromIterator(private.costItemTemp, itemsIter)
	Table.InsertFromIterator(private.costQuantityTemp, quantitiesIter)
	for i = 1, #private.costItemTemp do
		local itemString = private.costItemTemp[i]
		local quantity = private.costQuantityTemp[i]
		local currencyId = strmatch(itemString, "currency:(%d+)")
		currencyId = currencyId and tonumber(currencyId) or nil
		local currencyQuantity = currencyId and select(3, Currency.GetInfo(currencyId)) or nil
		local numHave = currencyQuantity or Container.GetItemCount(ItemString.ToId(itemString))
		maxCanAfford = min(floor(numHave / quantity), maxCanAfford)
	end
	wipe(private.costItemTemp)
	wipe(private.costQuantityTemp)

	return maxCanAfford * stackSize
end

---Gets the total cost for a given quantity of an item.
---@param index number The index of the item
---@param quantity number The index of the item
---@return number price
---@return number numStacks
function BuyScanner.GetTotalCost(index, quantity)
	local price, stackSize = private.db:NewAutoReleaseQuery()
		:Equal("index", index)
		:GetFirstResult("price", "stackSize")
	if not price then
		return 0, 0
	end
	local numStacks = quantity / stackSize
	return price * numStacks, numStacks
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MerchantVisibilityHandler(visible)
	if visible then
		private.updateTimer:RunForFrames(1)
	else
		private.updateTimer:Cancel()
		private.rescanTimer:Cancel()
		private.db:Truncate()
	end
end

function private.MerchantUpdateEventHandler()
	private.updateTimer:RunForFrames(1)
end

function private.UpdateMerchantDB()
	local needsRetry = false
	private.db:TruncateAndBulkInsertStart()
	for i = 1, Merchant.GetNumItems() do
		local link = Merchant.GetItemLink(i)
		local itemString = link and ItemString.Get(link)
		if itemString then
			local price, stackSize, numAvailable = Merchant.GetItemInfo(i)
			assert(#private.costItemTemp == 0 and #private.costQuantityTemp == 0)
			for j = 1, Merchant.GetNumCostItems(i) do
				local costItemLink, costNum = Merchant.GetCostItemInfo(i, j)
				if not costItemLink then
					needsRetry = true
				else
					local costItemString = ItemString.Get(costItemLink) or strmatch(costItemLink, "currency:%d+")
					assert(costItemString)
					tinsert(private.costItemTemp, costItemString)
					tinsert(private.costQuantityTemp, costNum)
				end
			end
			private.db:BulkInsertNewRow(i, itemString, price, private.costItemTemp, private.costQuantityTemp, stackSize, numAvailable)
			wipe(private.costItemTemp)
			wipe(private.costQuantityTemp)
		end
	end
	private.db:BulkInsertEnd()

	if needsRetry then
		Log.Err("Failed to scan merchant")
		private.rescanTimer:RunForTime(0.2)
	else
		private.rescanTimer:Cancel()
	end
end

function private.AdditionalCostIterator(_, index)
	index = (index or 0) + 1
	local item = private.costItemTemp[index]
	local quantity = private.costQuantityTemp[index]
	if not item and not quantity then
		wipe(private.costItemTemp)
		wipe(private.costQuantityTemp)
		return
	end
	return index, item, quantity
end

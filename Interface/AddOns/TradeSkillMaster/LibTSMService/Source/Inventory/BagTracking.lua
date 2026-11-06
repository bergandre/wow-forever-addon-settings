-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local BagTracking = LibTSMService:Init("Inventory.BagTracking")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Lifecycle = LibTSMService:Include("Util.Lifecycle")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Item = LibTSMService:From("LibTSMWoW"):Include("API.Item")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local TooltipScanning = LibTSMService:From("LibTSMWoW"):Include("Service.TooltipScanning")
local SlotId = LibTSMService:From("LibTSMWoW"):Include("Type.SlotId")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	slotDB = nil,
	quantityDB = nil,
	storage = {
		bagQuantity = nil, ---@type table<string,number?>
		bankQuantity = nil, ---@type table<string,number?>
	},
	bagUpdates = {
		pending = {},
		bagList = {},
		bankList = {},
	},
	bankSlotUpdates = {
		pending = {},
		list = {},
	},
	isFirstBankOpen = true,
	baseItemQuantityQuery = nil,
	callbackQuery = nil, ---@diagnostic disable-line: tsm-private
	quantityCallbackQuery = nil, ---@diagnostic disable-line: tsm-private
	callbacks = CallbackRegistry.NewList(),
	quantityCallbacks = CallbackRegistry.NewList(),
	bagUpdateTimer = nil,
	bagUpdateDelayedTimer = nil,
	bankSlotUpdateTimer = nil,
	bagTrackingCallbackTimer = nil,
	bagTrackingQuantityCallbackTimer = nil,
	updateTemp = {
		newQuantities = {},
		items = {},
	},
	prevQuantities = {},
	updatesTemp = {},
}
local TOTAL_QUANTITY_ARG_FIELDS = { "bagQuantity", "bankQuantity" }



-- ============================================================================
-- Module Loading
-- ============================================================================

BagTracking:OnModuleLoad(function()
	private.slotDB = Database.NewSchema("BAG_TRACKING_SLOTS")
		:AddUniqueNumberField("slotId")
		:AddStringField("itemLink")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("itemTexture")
		:AddNumberField("quantity")
		:AddBooleanField("isBound")
		:AddBooleanField("isWarBound")
		:AddIndex("slotId")
		:AddIndex("itemString")
		:AddIndex("baseItemString")
		:AddIndex("levelItemString")
		:Commit()
	private.quantityDB = Database.NewSchema("BAG_TRACKING_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("bagQuantity")
		:AddNumberField("bankQuantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
	private.callbackQuery = private.slotDB:NewOwnedQuery()
		:SetUpdateCallback(private.OnCallbackQueryUpdated)
	private.quantityCallbackQuery = private.quantityDB:NewOwnedQuery()
		:SetUpdateCallback(private.OnQuantityCallbackQueryUpdated)
	private.bagUpdateTimer = DelayTimer.New("BAG_TRACKING_BAG_UPDATE", private.BagUpdateDelayedHandler)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		private.bankSlotUpdateTimer = DelayTimer.New("BAG_TRACKING_BANK_SLOT_UPDATE", private.BankSlotUpdateDelayed)
	end
	private.bagTrackingCallbackTimer = DelayTimer.New("BAG_TRACKING_CALLBACK", private.DelayedBagTrackingCallback)
	private.bagTrackingQuantityCallbackTimer = DelayTimer.New("BAG_TRACKING_QUANTITY_CALLBACK", private.DelayedBagTrackingQuantityCallback)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param bagQuantityData table<string,number> Bag item quantities
---@param bankQuantityData table<string,number> Bank item quantities
function BagTracking.Load(bagQuantityData, bankQuantityData)
	private.storage.bagQuantity = bagQuantityData
	private.storage.bankQuantity = bankQuantityData
	Table.Filter(private.storage.bagQuantity, private.FilterNonItemLevelStrings)
	Table.Filter(private.storage.bankQuantity, private.FilterNonItemLevelStrings)
	local items = {}
	for levelItemString in pairs(private.storage.bagQuantity) do
		items[levelItemString] = true
	end
	for levelItemString in pairs(private.storage.bankQuantity) do
		items[levelItemString] = true
	end
	private.quantityDB:BulkInsertStart()
	for levelItemString in pairs(items) do
		local bagQuantity = private.storage.bagQuantity[levelItemString] or 0
		local bankQuantity = private.storage.bankQuantity[levelItemString] or 0
		if (bagQuantity + bankQuantity) > 0 then
			private.quantityDB:BulkInsertNewRow(levelItemString, bagQuantity, bankQuantity)
		end
	end
	private.quantityDB:BulkInsertEnd()
end

---Starts running the bag tracking code.
function BagTracking.Start()
	Event.Register("BAG_UPDATE", private.BagUpdateHandler)
	if LibTSMService.IsMistsClassic() or LibTSMService.IsRetail() or LibTSMService.IsForever() then
		-- In Cata 4.4.0 and in Retail 10.0.5, BAG_UPDATE_DELAYED doesn't fire for non-backpack slots, so emulate it
		private.bagUpdateDelayedTimer = DelayTimer.New("BAG_TRACKING_BAG_UPDATE_DELAYED", private.BagUpdateDelayedHandler)
		Event.Register("BAG_UPDATE", function() private.bagUpdateDelayedTimer:RunForFrames(0) end)
	else
		Event.Register("BAG_UPDATE_DELAYED", private.BagUpdateDelayedHandler)
	end
	DefaultUI.RegisterBankVisibleCallback(private.BankVisible, true)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		Event.Register("PLAYERBANKSLOTS_CHANGED", private.BankSlotChangedHandler)
	end
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		Event.Register("BAG_UPDATE", private.HandleLogin)
	else
		Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
	end
end

---Registers a callback for when the bags change.
---@param callback fun() The callback function
function BagTracking.RegisterCallback(callback)
	private.callbacks:Add(callback)
end

---Registers a callback for when the bag quantities change.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function BagTracking.RegisterQuantityCallback(callback)
	private.quantityCallbacks:Add(callback)
end

---Iterates over the bag quantities.
---@return IteratorObject<fun(): number, string, number, number> @Iterator with fields: `index`, `levelItemString`, `bagQuantity`, `bankQuantity`
function BagTracking.QuantityIterator()
	return private.quantityDB:NewAutoReleaseQuery()
		:Iterator("levelItemString", "bagQuantity", "bankQuantity")
end

---Adds a filter to a DB query to restrict it to just the bags.
---@param query DatabaseQuery the query
---@return DatabaseQuery
function BagTracking.FilterQueryBags(query)
	return query
		:GreaterThanOrEqual("slotId", SlotId.Join(0, 1))
		:LessThanOrEqual("slotId", SlotId.Join(Container.GetNumBags() + 1, 0))
end

---Creates a new query for just the bags.
---@return DatabaseQuery
function BagTracking.CreateQueryBags()
	return BagTracking.FilterQueryBags(private.slotDB:NewOwnedQuery())
end

---Creates a new query for the bags and bank.
---@return DatabaseQuery
function BagTracking.CreateQueryBagsBank()
	return private.slotDB:NewOwnedQuery()
end

---Creates a new query of auctionable items in the bags.
---@return DatabaseQuery
function BagTracking.CreateQueryBagsAuctionable()
	return BagTracking.CreateQueryBags()
		:Equal("isBound", false)
		:Function("slotId", private.IsAuctionableQueryFilter)
end

---Creates a new query of mailable items in the bags.
---@return DatabaseQuery
function BagTracking.CreateQueryBagsMailable()
	return BagTracking.CreateQueryBags()
		:Or()
			:Equal("isBound", false)
			:Equal("isWarBound", true)
		:End()
end

---Creates a query of bag slots with the specified item.
---@param itemString string The item string
---@return DatabaseQuery
function BagTracking.CreateQueryBagsItem(itemString)
	return BagTracking.CreateQueryBags()
		:Equal(private.GetItemStringField(itemString), itemString)
end

---Creates a query of bag slots with the specified item that are auctionable.
---@param itemString string The item string
---@return DatabaseQuery
function BagTracking.CreateQueryBagsItemAuctionable(itemString)
	return BagTracking.CreateQueryBagsItem(itemString)
		:Equal("isBound", false)
		:Function("slotId", private.IsAuctionableQueryFilter)
end

---Creates a query of the bank.
---@return DatabaseQuery
function BagTracking.CreateQueryBank()
	return private.slotDB:NewOwnedQuery()
		:Function("slotId", private.IsWithinBank)
end

---Creates a query of the bank for the specified item.
---@param itemString string The item string
---@return DatabaseQuery
function BagTracking.CreateQueryBankItem(itemString)
	return BagTracking.CreateQueryBank()
		:Equal(private.GetItemStringField(itemString), itemString)
end

---Forces a deduction in the item quantity.
---@param itemString string The item string
---@param quantity number The amount to deduct
function BagTracking.ForceBankQuantityDeduction(itemString, quantity)
	if DefaultUI.IsBankVisible() then
		return
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if private.isFirstBankOpen then
		-- Haven't scanned yet, so just deduct the quantity
		local bankQuantity = private.storage.bankQuantity[levelItemString] or -math.huge
		if bankQuantity >= quantity then
			local bag = (LibTSMService.IsRetail() or LibTSMService.IsForever()) and Container.GetFirstBankTabIndex() or Container.GetBankContainer()
			private.ChangeBagItemTotal(bag, levelItemString, -quantity)
		end
		return
	end
	local iter = private.slotDB:NewAutoReleaseQuery()
		:AutoPauseDBQueryUpdates()
		:Equal("itemString", itemString)
		:Function("slotId", private.IsWithinBank)
		:Iterator("slotId", "quantity")
	for uuid, slotId, rowQuantity in iter do
		if quantity <= 0 then
			iter:Release()
			break
		end
		local bag = SlotId.Split(slotId)
		if rowQuantity <= quantity then
			private.ChangeBagItemTotal(bag, levelItemString, -rowQuantity)
			private.slotDB:DeleteRow(uuid)
			quantity = quantity - rowQuantity
		else
			private.slotDB:UpdateRow(uuid, "quantity", rowQuantity - quantity)
			private.ChangeBagItemTotal(bag, levelItemString, -quantity)
			quantity = 0
		end
	end
end

---Gets the stack size in a given slot.
---@param slotId number The slot ID
---@return number
function BagTracking.GetQuantityBySlotId(slotId)
	return private.slotDB:GetRowFields(private.slotDB:GetUniqueRow("slotId", slotId), "quantity") or 0
end

---Gets the number of an item in the bags.
---@param itemString string The item string
---@return number
function BagTracking.GetBagQuantity(itemString)
	return private.GetQuantityDBField(itemString, "bagQuantity")
end

---Gets the number of an item in the bank.
---@param itemString string The item string
---@return number
function BagTracking.GetBankQuantity(itemString)
	return private.GetQuantityDBField(itemString, "bankQuantity")
end

---Gets the bag / bank quantities for the specified item.
---@param itemString string The item string
---@return number bagQuantity
---@return number bankQuantity
function BagTracking.GetQuantities(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		private.baseItemQuantityQuery:BindParams(itemString)
		return private.baseItemQuantityQuery:Sum("bagQuantity"), private.baseItemQuantityQuery:Sum("bankQuantity")
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0, 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), "bagQuantity", "bankQuantity")
end

---Gets the total quantity for the specified item.
---@param itemString string The item string
---@return number
function BagTracking.GetTotalQuantity(itemString)
	local bagQuantity, bankQuantity = BagTracking.GetQuantities(itemString)
	return bagQuantity + bankQuantity
end

---Gets the available crafting mat quantity for the specified item.
---@param itemString string The item string
---@return number
function BagTracking.GetCraftingMatQuantity(itemString)
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		return BagTracking.GetTotalQuantity(itemString)
	else
		return BagTracking.GetBagQuantity(itemString)
	end
end

---Check if an item will go in a bag.
---@param itemString string The item string
---@param bag number The bag index
---@return boolean
function BagTracking.ItemWillGoInBag(itemString, bag)
	if bag == Container.GetBackpackContainer() or Container.IsWarbankBag(bag) then
		return true
	elseif (not LibTSMService.IsRetail() and not LibTSMService.IsForever()) and bag == Container.GetBankContainer() then
		return true
	end
	local link = ItemInfo.GetLink(itemString)
	local itemFamily = Item.GetFamily(link, ItemInfo.GetClassId(itemString) or -1)
	local _, bagFamily = Container.GetNumFreeSlots(bag)
	if not bagFamily then
		return false
	end
	return bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0
end



-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.HandleLogin()
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		Event.Unregister("BAG_UPDATE", private.HandleLogin)
	end
	-- We'll scan all the bags right away, so wipe the existing quantities
	wipe(private.storage.bagQuantity)
	local query = private.quantityDB:NewAutoReleaseQuery()
		:AutoPauseDBQueryUpdates()
	for uuid, levelItemString, oldBagQuantity, oldBankQuantity in query:Iterator("levelItemString", "bagQuantity", "bankQuantity") do
		local oldTotalBankQuantity = oldBankQuantity
		if oldTotalBankQuantity == 0 then
			-- Remove this row
			assert(oldBagQuantity > 0)
			private.quantityDB:DeleteRow(uuid)
		else
			local updated = false
			if (LibTSMService.IsRetail() or LibTSMService.IsForever()) and oldTotalBankQuantity > 0 then
				-- Update commodity quantities using GetItemCount()
				if levelItemString == ItemString.GetBaseFast(levelItemString) and ItemInfo.IsCommodity(levelItemString) then
					local itemId = ItemString.ToId(levelItemString)
					local _, bankQuantity = Container.GetItemCount(itemId)
					if bankQuantity ~= oldBankQuantity then
						updated = true
						if bankQuantity == 0 then
							private.quantityDB:DeleteRow(uuid)
						else
							assert(not next(private.updatesTemp))
							private.updatesTemp.bagQuantity = 0
							private.updatesTemp.bankQuantity = bankQuantity
							private.quantityDB:UpdateRow(uuid, private.updatesTemp)
							wipe(private.updatesTemp)
						end
					end
				end
			end
			if not updated and oldBagQuantity ~= 0 then
				-- Update this row
				private.quantityDB:UpdateRow(uuid, "bagQuantity", 0)
			end
		end
	end

	-- WoW does not fire an update event for the backpack when you log in, so trigger one
	private.BagUpdateHandler(nil, 0)
	private.BagUpdateDelayedHandler()
	return true
end

function private.BankVisible()
	if private.isFirstBankOpen then
		private.isFirstBankOpen = false
		-- this is the first time opening the bank so we'll scan all the items so wipe our existing quantities
		wipe(private.storage.bankQuantity)
		local query = private.quantityDB:NewAutoReleaseQuery()
			:AutoPauseDBQueryUpdates()
		for uuid, bagQuantity, bankQuantity in query:Iterator("bagQuantity", "bankQuantity") do
			local oldValue = bankQuantity
			if bagQuantity == 0 then
				-- Remove this row
				assert(oldValue > 0)
				private.quantityDB:DeleteRow(uuid)
			elseif oldValue ~= 0 then
				-- Update this row
				assert(not next(private.updatesTemp))
				private.updatesTemp.bankQuantity = 0
				private.quantityDB:UpdateRow(uuid, private.updatesTemp)
				wipe(private.updatesTemp)
			end
		end
	end
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		private.BagUpdateHandler(nil, Container.GetBankContainer())
	end
	for bag in Container.BankBagIterator() do
		private.BagUpdateHandler(nil, bag)
	end
	private.BagUpdateDelayedHandler()
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		private.BankSlotUpdateDelayed()
	end
end

function private.BagUpdateHandler(_, bag)
	if private.bagUpdates.pending[bag] or Container.IsWarbankBag(bag) then
		return
	end
	private.bagUpdates.pending[bag] = true
	if Container.IsBag(bag) then
		tinsert(private.bagUpdates.bagList, bag)
	elseif Container.IsBank(bag) then
		tinsert(private.bagUpdates.bankList, bag)
	elseif bag ~= Container.GetKeyringContainer() then
		error("Unexpected bag: "..tostring(bag))
	end
end

function private.BagUpdateDelayedHandler()
	for _ in private.slotDB:WithQueryUpdatesPaused() do
		-- Scan any pending bags
		for i, bag in Table.ReverseIPairs(private.bagUpdates.bagList) do
			if private.ScanBagOrBank(bag) then
				private.bagUpdates.pending[bag] = nil
				tremove(private.bagUpdates.bagList, i)
			end
		end
		if #private.bagUpdates.bagList > 0 then
			-- Some failed to scan so try again
			private.bagUpdateTimer:RunForFrames(2)
		end

		if DefaultUI.IsBankVisible() then
			-- Scan any pending bank bags
			for i, bag in Table.ReverseIPairs(private.bagUpdates.bankList) do
				if private.ScanBagOrBank(bag) then
					private.bagUpdates.pending[bag] = nil
					tremove(private.bagUpdates.bankList, i)
				end
			end
			if #private.bagUpdates.bankList > 0 then
				-- Some failed to scan so try again
				private.bagUpdateTimer:RunForFrames(2)
			end
		end
	end
end

function private.BankSlotChangedHandler(_, slot)
	local bag = Container.GetBankContainer()
	local numBankContainerSlots = Container.GetNumSlots(bag)
	if slot > numBankContainerSlots then
		private.BagUpdateHandler(nil, slot - numBankContainerSlots)
		return
	end
	local slotId = SlotId.Join(bag, slot)
	if private.bankSlotUpdates.pending[slotId] then
		return
	end
	private.bankSlotUpdates.pending[slotId] = true
	tinsert(private.bankSlotUpdates.list, slotId)
	private.bankSlotUpdateTimer:RunForFrames(2)
end

-- This is not a WoW event, but we fake it based on a delay from private.BankSlotChangedHandler
function private.BankSlotUpdateDelayed()
	if not DefaultUI.IsBankVisible() then
		return
	end

	for _ in private.slotDB:WithQueryUpdatesPaused() do
		-- Scan any pending slots
		for i, slotId in Table.ReverseIPairs(private.bankSlotUpdates.list) do
			if private.ScanBagSlot(slotId) then
				private.bankSlotUpdates.pending[slotId] = nil
				tremove(private.bankSlotUpdates.list, i)
			end
		end
		if #private.bankSlotUpdates.list > 0 then
			-- Some failed to scan so try again
			private.bankSlotUpdateTimer:RunForFrames(2)
		end
	end
end



-- ============================================================================
-- Scanning Functions
-- ============================================================================

function private.ScanBagOrBank(bag)
	private.RemoveExtraSlots(bag, Container.GetNumSlots(bag))
	local result = true
	for slotId in Container.SlotIdIterator(bag) do
		if not private.ScanBagSlot(slotId) then
			result = false
		end
	end
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsAuctionableQueryFilter(slotId)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		return not TooltipScanning.HasUsedCharges(slotId)
	else
		return AuctionHouse.IsSellable(slotId)
	end
end

function private.RemoveExtraSlots(bag, numSlots)
	-- The number of slots of this bag may have changed, in which case we should remove any higher ones from our DB
	local query = private.slotDB:NewOwnedQuery()
		:GreaterThan("slotId", SlotId.Join(bag, numSlots))
		:LessThan("slotId", SlotId.Join(bag + 1, 0))
	for _, levelItemString, quantity in query:Iterator("levelItemString", "quantity") do
		private.ChangeBagItemTotal(bag, levelItemString, -quantity)
	end
	query:Delete()
	query:Release()
end

function private.ScanBagSlot(slotId)
	local texture, quantity, _, link, itemId, isBound = Container.GetItemInfo(slotId)
	if quantity and not itemId then
		-- We are pending item info for this slot so try again later to scan it
		return false
	elseif quantity == 0 then
		-- This item is going away, so try again later to scan it
		return false
	end
	local itemString = link and ItemString.Get(link)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
	local bag = SlotId.Split(slotId)
	if levelItemString then
		texture = texture or (link and ItemInfo.GetTexture(link))
		if not texture then
			return false
		end
		assert(quantity)
		local isWarBound = isBound and Container.CanDepositIntoWarbank(slotId)
		if private.slotDB:HasUniqueRow("slotId", slotId) then
			local uuid = private.slotDB:GetUniqueRow("slotId", slotId)
			local oldItemLink, oldLevelItemString, oldQuantity = private.slotDB:GetRowFields(uuid, "itemLink", "levelItemString", "quantity")
			assert(not next(private.updatesTemp))
			if oldItemLink ~= link then
				private.updatesTemp.itemLink = link
				private.updatesTemp.itemString = itemString
				private.updatesTemp.itemTexture = texture
				private.updatesTemp.isBound = isBound
				private.updatesTemp.isWarBound = isWarBound
			end
			if levelItemString ~= oldLevelItemString then
				-- Remove the old item and add the new one
				private.ChangeBagItemTotal(bag, oldLevelItemString, -oldQuantity)
				private.ChangeBagItemTotal(bag, levelItemString, quantity)
				private.updatesTemp.quantity = quantity
			elseif quantity ~= oldQuantity then
				-- Update the quantity
				private.ChangeBagItemTotal(bag, levelItemString, quantity - oldQuantity)
				private.updatesTemp.quantity = quantity
			end
			private.slotDB:UpdateRow(uuid, private.updatesTemp)
			wipe(private.updatesTemp)
		else
			-- There was nothing here previously so create a new row
			private.slotDB:InsertRow(slotId, link, itemString, texture, quantity, isBound, isWarBound)
			-- Add to the item totals
			private.ChangeBagItemTotal(bag, levelItemString, quantity)
		end
	elseif private.slotDB:HasUniqueRow("slotId", slotId) then
		-- Nothing here now so delete the row and remove from the item totals
		local uuid = private.slotDB:GetUniqueRow("slotId", slotId)
		local oldLevelItemString, oldQuantity = private.slotDB:GetRowFields(uuid, "levelItemString", "quantity")
		private.ChangeBagItemTotal(bag, oldLevelItemString, -oldQuantity)
		private.slotDB:DeleteRow(uuid)
	end
	return true
end

function private.DelayedBagTrackingCallback()
	private.callbacks:CallAll()
end

function private.DelayedBagTrackingQuantityCallback()
	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end
	private.quantityDB:NewAutoReleaseQuery()
		:VirtualField("totalQuantity", "number", private.TotalQuantityVirtualField, TOTAL_QUANTITY_ARG_FIELDS)
		:AsTable(updateTemp.newQuantities, "levelItemString", "totalQuantity")
	Table.GetChangedKeys(private.prevQuantities, updateTemp.newQuantities, updateTemp.items)
	if next(updateTemp.items) then
		-- Add the base items
		ItemString.AddBaseItemStringKeys(updateTemp.items)
		wipe(private.prevQuantities)
		Table.CopyFrom(private.prevQuantities, updateTemp.newQuantities)
		private.quantityCallbacks:CallAll(updateTemp.items)
	end
	for _, tbl in pairs(updateTemp) do
		Table.WipeAndDeallocate(tbl)
	end
end

function private.OnCallbackQueryUpdated()
	private.bagTrackingCallbackTimer:RunForFrames(2)
end

function private.OnQuantityCallbackQueryUpdated(...)
	private.bagTrackingQuantityCallbackTimer:RunForFrames(2)
end

function private.ChangeBagItemTotal(bag, levelItemString, changeQuantity)
	assert(changeQuantity ~= 0)
	local totalsTable = nil
	local field = nil
	if Container.IsBag(bag) then
		totalsTable = private.storage.bagQuantity
		field = "bagQuantity"
	elseif Container.IsBank(bag) then
		totalsTable = private.storage.bankQuantity
		field = "bankQuantity"
	else
		error("Unexpected bag: "..tostring(bag))
	end
	totalsTable[levelItemString] = (totalsTable[levelItemString] or 0) + changeQuantity

	if private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		local uuid = private.quantityDB:GetUniqueRow("levelItemString", levelItemString)
		local bagQuantity, bankQuantity, oldValue = private.quantityDB:GetRowFields(uuid, "bagQuantity", "bankQuantity", field)
		local oldTotalQuantity = bagQuantity + bankQuantity
		local newValue = oldValue + changeQuantity
		assert(newValue >= 0)
		if newValue == 0 and oldTotalQuantity == oldValue then
			-- Remove this row
			private.quantityDB:DeleteRow(uuid)
		else
			-- Update this row
			private.quantityDB:UpdateRow(uuid, field, oldValue + changeQuantity)
		end
	else
		-- Create a new row
		assert(changeQuantity > 0)
		local bagQuantity, bankQuantity = 0, 0
		if Container.IsBag(bag) then
			bagQuantity = changeQuantity
		elseif Container.IsBank(bag) then
			bankQuantity = changeQuantity
		else
			error("Unexpected bag: "..tostring(bag))
		end
		private.quantityDB:InsertRow(levelItemString, bagQuantity, bankQuantity)
	end

	assert((totalsTable[levelItemString] or 0) >= 0)
	if totalsTable[levelItemString] == 0 then
		totalsTable[levelItemString] = nil
	end
end

function private.FilterNonItemLevelStrings(levelItemString)
	return levelItemString ~= ItemString.ToLevel(levelItemString)
end

function private.TotalQuantityVirtualField(bagQuantity, bankQuantity)
	return bagQuantity + bankQuantity
end

function private.GetItemStringField(itemString)
	if itemString == ItemString.GetBaseFast(itemString) then
		return "baseItemString"
	elseif ItemString.IsLevel(itemString) then
		return "levelItemString"
	else
		return "itemString"
	end
end

function private.IsWithinBank(slotId)
	local bag = SlotId.Split(slotId)
	return Container.IsBank(bag)
end

function private.GetQuantityDBField(itemString, field)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum(field)
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), field)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local WarbankTracking = LibTSMService:Init("Inventory.WarbankTracking")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	slotDB = nil,
	quantityDB = nil,
	quantityStorage = nil,
	updates = {
		pending = {},
		bagList = {},
	},
	isFirstBankOpen = true,
	baseItemQuantityQuery = nil,
	quantityCallbackQuery = nil, ---@diagnostic disable-line: tsm-private
	quantityCallbacks = CallbackRegistry.NewList(),
	bagUpdateTimer = nil,
	quantityCallbackTimer = nil,
	updateTemp = {
		newQuantities = {},
		items = {},
	},
	prevQuantities = {},
	updatesTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

WarbankTracking:OnModuleLoad(function()
	private.slotDB = Database.NewSchema("WARBANK_TRACKING_SLOTS")
		:AddUniqueNumberField("slotId")
		:AddStringField("itemLink")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("quantity")
		:AddIndex("slotId")
		:Commit()
	private.quantityDB = Database.NewSchema("WARBANK_TRACKING_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("quantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
	private.quantityCallbackQuery = private.quantityDB:NewOwnedQuery()
		:SetUpdateCallback(private.OnQuantityCallbackQueryUpdated)
	private.bagUpdateTimer = DelayTimer.New("WARBANK_TRACKING_BAG_UPDATE", private.UpdateDelayedHandler)
	private.quantityCallbackTimer = DelayTimer.New("WARBANK_TRACKING_QUANTITY_CALLBACK", private.DelayedBagTrackingQuantityCallback)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Warbank item quantities
function WarbankTracking.Load(quantityData)
	if not LibTSMService.IsRetail() then
		wipe(quantityData)
		return
	end
	-- Sanitize the storage table
	for levelItemString, quantity in pairs(quantityData) do
		if quantity <= 0 then
			quantityData[levelItemString] = nil
		end
	end
	private.quantityStorage = quantityData
	-- Build the DB
	private.quantityDB:BulkInsertStart()
	for levelItemString, quantity in pairs(quantityData) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
end

---Starts running the bag tracking code.
function WarbankTracking.Start()
	if not LibTSMService.IsRetail() then
		return
	end
	Event.Register("BAG_UPDATE", private.BagUpdateHandler)
	Event.Register("BAG_UPDATE_DELAYED", private.UpdateDelayedHandler)
	DefaultUI.RegisterBankVisibleCallback(private.BankVisible, true)
	DefaultUI.RegisterAccountBankVisibleCallback(private.BankVisible, true)
end

---Registers a callback for when the bag quantities change.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function WarbankTracking.RegisterQuantityCallback(callback)
	private.quantityCallbacks:Add(callback)
end

---Creates a query of the account warbank.
---@return DatabaseQuery
function WarbankTracking.CreateQuerySlot()
	return private.slotDB:NewOwnedQuery()
end

---Creates a query of warbank slots with the specified item.
---@return DatabaseQuery
function WarbankTracking.CreateQuerySlotItem(itemString)
	return private.slotDB:NewOwnedQuery()
		:Equal(private.GetItemStringField(itemString), itemString)
end

---Iterates over the bag quantities.
---@return IteratorObject<fun(): number, string, number> @Iterator with fields: `index`, `levelItemString`, `quantity`
function WarbankTracking.QuantityIterator()
	return private.quantityDB:NewAutoReleaseQuery()
		:Iterator("levelItemString", "quantity")
end

---Gets the number of an item.
---@param itemString string The item string
---@return number
function WarbankTracking.GetQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("quantity")
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), "quantity")
end

---Forces a deduction in the item quantity.
---@param itemString string The item string
---@param quantity number The amount to deduct
function WarbankTracking.ForceQuantityDeduction(itemString, quantity)
	if DefaultUI.IsBankVisible() or DefaultUI.IsAccountBankVisible() then
		return
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if private.isFirstBankOpen then
		-- Haven't scanned yet, so just deduct the quantity
		if (private.quantityStorage[levelItemString] or -math.huge) >= quantity then
			private.ChangeItemTotal(levelItemString, -quantity)
		end
		return
	end
	local iter = private.slotDB:NewAutoReleaseQuery()
		:AutoPauseDBQueryUpdates()
		:Equal("itemString", itemString)
		:Iterator("quantity")
	for uuid, rowQuantity in iter do
		if quantity <= 0 then
			iter:Release()
			break
		end
		if rowQuantity <= quantity then
			private.ChangeItemTotal(levelItemString, -rowQuantity)
			private.slotDB:DeleteRow(uuid)
			quantity = quantity - rowQuantity
		else
			private.slotDB:UpdateRow(uuid, "quantity", rowQuantity - quantity)
			private.ChangeItemTotal(levelItemString, -quantity)
			quantity = 0
		end
	end
end



-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.BankVisible()
	if not Container.CanAccessWarbank() then
		return
	end
	for _ in private.quantityDB:WithQueryUpdatesPaused() do
		if private.isFirstBankOpen then
			private.isFirstBankOpen = false
			-- This is the first time opening the bank so we'll scan all the items so wipe our existing quantities
			wipe(private.quantityStorage)
			private.quantityDB:Truncate()
		end
		for bag in Container.WarbankBagIterator() do
			private.BagUpdateHandler(nil, bag)
		end
		private.UpdateDelayedHandler()
	end
end

function private.BagUpdateHandler(_, bag)
	if private.updates.pending[bag] or not Container.IsWarbankBag(bag) or not Container.CanAccessWarbank() then
		return
	end
	private.updates.pending[bag] = true
	tinsert(private.updates.bagList, bag)
end

function private.UpdateDelayedHandler()
	if (not DefaultUI.IsBankVisible() and not DefaultUI.IsAccountBankVisible()) or not Container.CanAccessWarbank() then
		return
	end

	for _ in private.slotDB:WithQueryUpdatesPaused() do
		-- Scan any pending bank bags
		for i, bag in Table.ReverseIPairs(private.updates.bagList) do
			local result = true
			for slotId in Container.SlotIdIterator(bag) do
				if not private.ScanSlot(slotId) then
					result = false
				end
			end
			if result then
				private.updates.pending[bag] = nil
				tremove(private.updates.bagList, i)
			end
		end
		if #private.updates.bagList > 0 then
			-- Some failed to scan so try again
			private.bagUpdateTimer:RunForFrames(2)
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ScanSlot(slotId)
	local _, quantity, _, link, itemId = Container.GetItemInfo(slotId)
	if quantity and not itemId then
		-- We are pending item info for this slot so try again later to scan it
		return false
	elseif quantity == 0 then
		-- This item is going away, so try again later to scan it
		return false
	end
	local itemString = link and ItemString.Get(link)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
	if levelItemString then
		assert(quantity)
		if private.slotDB:HasUniqueRow("slotId", slotId) then
			local uuid = private.slotDB:GetUniqueRow("slotId", slotId)
			assert(not next(private.updatesTemp))
			local oldLevelItemString, oldQuantity, oldItemLink = private.slotDB:GetRowFields(uuid, "levelItemString", "quantity", "itemLink")
			if oldItemLink ~= link then
				private.updatesTemp.itemLink = link
				private.updatesTemp.itemString = itemString
			end
			if levelItemString ~= oldLevelItemString then
				-- Remove the old item and add the new one
				private.ChangeItemTotal(oldLevelItemString, -oldQuantity)
				private.ChangeItemTotal(levelItemString, quantity)
				private.updatesTemp.quantity = quantity
			elseif quantity ~= oldQuantity then
				-- Update the quantity
				private.ChangeItemTotal(levelItemString, quantity - oldQuantity)
				private.updatesTemp.quantity = quantity
			end
			private.slotDB:UpdateRow(uuid, private.updatesTemp)
			wipe(private.updatesTemp)
		else
			-- There was nothing here previously so create a new row
			private.slotDB:InsertRow(slotId, link, itemString, quantity)
			-- Add to the item totals
			private.ChangeItemTotal(levelItemString, quantity)
		end
	elseif private.slotDB:HasUniqueRow("slotId", slotId) then
		-- Nothing here now so delete the row and remove from the item totals
		local uuid = private.slotDB:GetUniqueRow("slotId", slotId)
		local oldLevelItemString, oldQuantity = private.slotDB:GetRowFields(uuid, "levelItemString", "quantity")
		private.ChangeItemTotal(oldLevelItemString, -oldQuantity)
		private.slotDB:DeleteRow(uuid)
	end
	return true
end

function private.DelayedBagTrackingQuantityCallback()
	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end
	private.quantityDB:NewAutoReleaseQuery()
		:AsTable(updateTemp.newQuantities, "levelItemString", "quantity")
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

function private.OnQuantityCallbackQueryUpdated(...)
	private.quantityCallbackTimer:RunForFrames(2)
end

function private.ChangeItemTotal(levelItemString, changeQuantity)
	assert(changeQuantity ~= 0)
	private.quantityStorage[levelItemString] = (private.quantityStorage[levelItemString] or 0) + changeQuantity

	if private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		local uuid = private.quantityDB:GetUniqueRow("levelItemString", levelItemString)
		local newValue = private.quantityDB:GetRowFields(uuid, "quantity") + changeQuantity
		assert(newValue >= 0)
		if newValue == 0 then
			-- Remove this row
			private.quantityDB:DeleteRow(uuid)
		else
			-- Update this row
			private.quantityDB:UpdateRow(uuid, "quantity", newValue)
		end
	else
		-- Create a new row
		assert(changeQuantity > 0)
		private.quantityDB:InsertRow(levelItemString, changeQuantity)
	end

	assert(private.quantityStorage[levelItemString] >= 0)
	if private.quantityStorage[levelItemString] == 0 then
		private.quantityStorage[levelItemString] = nil
	end
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

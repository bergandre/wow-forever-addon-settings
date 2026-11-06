-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Container = LibTSMWoW:Init("API.Container")
local Event = LibTSMWoW:Include("Service.Event")
local SlotId = LibTSMWoW:Include("Type.SlotId")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Range = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("Range")
local private = {
	bagRange = nil,
	bankBagRange = nil,
	warbankBagRange = nil,
	slotIdLocked = {},
	bankFrameOpen = false,
	bankFrameCallbacks = CallbackRegistry.NewList(),
}
local MAX_BANK_SLOTS_PER_TAB = 98



-- ============================================================================
-- Module Loading
-- ============================================================================

Container:OnModuleLoad(function()
	local numBags = NUM_BAG_SLOTS + ((LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and Constants.InventoryConstants.NumReagentBagSlots or 0)
	private.bagRange = Range.StaticStartEnd(BACKPACK_CONTAINER, numBags)
	local NUM_BANK_BAGS = (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and Constants.InventoryConstants.NumCharacterBankSlots or NUM_BANKBAGSLOTS
	private.bankBagRange = Range.StaticStartEnd(private.bagRange:GetEnd() + 1, private.bagRange:GetEnd() + NUM_BANK_BAGS)
	if LibTSMWoW.IsRetail() then
		private.warbankBagRange = Range.StaticStartEnd(private.bankBagRange:GetEnd() + 1, private.bankBagRange:GetEnd() + Constants.InventoryConstants.NumAccountBankSlots)
	end
	Event.Register("ITEM_LOCKED", private.ItemLockedHandler)
	Event.Register("ITEM_UNLOCKED", private.ItemUnlockedHandler)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		hooksecurefunc(BankFrame.BankPanel, "SetBankType", private.BankFrameShowHook) ---@diagnostic disable-line: undefined-field
		Event.Register("BANKFRAME_OPENED", private.BankFrameOpened)
		Event.Register("BANKFRAME_CLOSED", private.BankFrameClosed)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the item family for items that can fit in the specified bag.
---@param bag number The bag
---@return number
function Container.GetBagItemFamily(bag)
	if bag == BACKPACK_CONTAINER or bag == BANK_CONTAINER then
		return 0
	end
	local inventoryId = C_Container.ContainerIDToInventoryID(bag)
	local inventoryLink = GetInventoryItemLink("player", inventoryId)
	return inventoryLink and C_Item.GetItemFamily(inventoryLink) or 0
end

---Gets a list of empty slotIds and their sort values.
---@param bag number The bag to check
---@param itemFamily number The item family to check for
---@param emptySlotIds number[] A table to store the list of empty slotIds in
---@param sortvalue table<number,number> A table to store the sort values in
function Container.GenerateSortedEmptyFamilySlots(bag, itemFamily, emptySlotIds, sortvalue)
	local bagFamily = Container.GetBagItemFamily(bag)
	if bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0 then
		for slotId in Container.SlotIdIterator(bag) do
			if not Container.GetItemLink(slotId) then
				tinsert(emptySlotIds, slotId)
				sortvalue[slotId] = slotId + (bagFamily > 0 and 0 or 100000)
			end
		end
	end
end

---Returns the total number of bag slots.
---@return number
function Container.GetNumBags()
	return private.bagRange:GetEnd()
end

---Returns whether or not the specified bag index is a character bag.
---@param bag number The bag to check
---@return boolean
function Container.IsBag(bag)
	return private.bagRange:Includes(bag)
end

---Returns whether or not the specified bag index is a bank bag (or base container).
---@param bag number The bag to check
---@return boolean
function Container.IsBank(bag)
	return bag == BANK_CONTAINER or private.bankBagRange:Includes(bag)
end

---Returns whether or not the specified bag index is a warbank container.
---@param bag number The bag to check
---@return boolean
function Container.IsWarbankBag(bag)
	if not LibTSMWoW.IsRetail() then
		return false
	end
	return private.warbankBagRange:Includes(bag)
end

---Returns whether or not the warbank is accessible.
---@return boolean
function Container.CanAccessWarbank()
	if not LibTSMWoW.IsRetail() then
		return false
	end
	return C_PlayerInfo.HasAccountInventoryLock()
end

---Iterates over the bags.
---@return fun(): number @Iterator with fields: `bag`
---@return number
---@return number
function Container.BagIterator()
	return private.bagRange:Iterator()
end

---Iterates over the bank bags / tabs.
---@return fun(): number @Iterator with fields: `bag`
---@return number
---@return number
function Container.BankBagIterator()
	return private.bankBagRange:Iterator()
end

---Iterates over the warbank bags.
---@return fun(): number @Iterator with fields: `bag`
---@return number
---@return number
function Container.WarbankBagIterator()
	return private.warbankBagRange:Iterator()
end

---Gets the keyring container index.
---@return number
function Container.GetKeyringContainer()
	return KEYRING_CONTAINER
end

---Gets the backpack container index.
---@return number
function Container.GetBackpackContainer()
	return BACKPACK_CONTAINER
end

---Gets the bank container index.
---@return number
function Container.GetBankContainer()
	assert(not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever())
	return BANK_CONTAINER
end

---Gets the first bank tab index.
---@return number
function Container.GetFirstBankTabIndex()
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	return private.bankBagRange:GetStart()
end

---Returns the total number of slots in the bag specified by the index.
---@param bag number The index of the bag
---@return number
function Container.GetNumSlots(bag)
	if LibTSMWoW.IsRetail() and private.bankBagRange:Includes(bag) then
		return MAX_BANK_SLOTS_PER_TAB
	elseif (not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever()) and bag == BANK_CONTAINER then
		return NUM_BANKGENERIC_SLOTS
	end
	return C_Container.GetContainerNumSlots(bag)
end

---Iterate over all the slot IDs within a bag.
---@param bag number The index of the bag
---@return fun(): number @Iterator with fields: `slotId`
---@return number
---@return number
function Container.SlotIdIterator(bag)
	return private.SlotIdIterator, SlotId.Join(bag, Container.GetNumSlots(bag)), SlotId.Join(bag, 0)
end

---Returns the number of free slots in a bag.
---@param bag number The index of the bag
---@return number numFreeSlots
---@return number? bagFamily
function Container.GetNumFreeSlots(bag)
	return C_Container.GetContainerNumFreeSlots(bag)
end

---Returns the item ID in a container slot.
---@param slotId number The slot ID
---@return number?
function Container.GetItemId(slotId)
	return C_Container.GetContainerItemID(SlotId.Split(slotId))
end

---Returns info for an item in a container slot.
---@param slotId number The slot ID
---@return (number iconFileID, number stackCount, number? quality, string link, number itemId, boolean isBound)
---|       (nil, nil, nil, nil, nil, nil)
function Container.GetItemInfo(slotId)
	local info = C_Container.GetContainerItemInfo(SlotId.Split(slotId)) --[[@as ContainerItemInfo?]]
	if not info then
		return nil, nil, nil, nil, nil, nil
	end
	return info.iconFileID, info.stackCount, info.quality, info.hyperlink, info.itemID, info.isBound
end

---Returns the size of the stack in a container slot.
---@param slotId number The slot ID
---@return number?
function Container.GetStackCount(slotId)
	local _, stackCount = Container.GetItemInfo(slotId)
	return stackCount
end

---Returns a link of the object located in the specified slot of a specified bag.
---@param slotId number The slot ID
---@return string?
function Container.GetItemLink(slotId)
	return C_Container.GetContainerItemLink(SlotId.Split(slotId))
end

---Uses an item from given bag slot.
---@param slotId number The slot ID
function Container.UseItem(slotId)
	C_Container.UseContainerItem(SlotId.Split(slotId))
end

---Pick up an item from given bag slot.
---@param slotId number The slot ID
function Container.PickupItem(slotId)
	C_Container.PickupContainerItem(SlotId.Split(slotId))
end

---Places part of a stack of items from a container onto the cursor.
---@param slotId number The slot ID
---@param count number The quantity to split
function Container.SplitItem(slotId, count)
	local bag, slot = SlotId.Split(slotId)
	C_Container.SplitContainerItem(bag, slot, count)
end

---Places the item from the cursor into a bag slot.
---@param slotId number The slot ID
function Container.PlaceItemFromCursor(slotId)
	if GetCursorInfo() == "item" then
		Container.PickupItem(slotId)
	end
	ClearCursor()
end

---Register a secure hook function for when a container item is used (and not on the player).
---@param func function The hook function
function Container.SecureHookUseItem(func)
	hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot, onSelf)
		if onSelf then
			return
		end
		bag = tonumber(bag)
		slot = tonumber(slot)
		assert(bag and slot)
		func(SlotId.Join(bag, slot))
	end)
end

---Queries the game for how many of an item the character owns.
---@param itemId number The item ID
---@return number bagQuantity
---@return number bankQuantity
function Container.GetItemCount(itemId)
	-- GetItemCount() is a bit buggy and not all combinations of arguments work, so carefully call it to calculate the quantities
	local bagQuantity = C_Item.GetItemCount(itemId, false, false, false, false)
	local bankQuantity = C_Item.GetItemCount(itemId, true, false, true, false) - bagQuantity
	return bagQuantity, bankQuantity
end

---Returns if a bag slot is locked.
---@param slotId number The slot ID
---@return boolean
function Container.IsBagSlotLocked(slotId)
	return private.slotIdLocked[slotId] or false
end

---Returns the slotId of a currently locked bag slot, or nil if none is locked.
---@return number?
function Container.GetLockedBagSlotId()
	local slotId = next(private.slotIdLocked)
	return slotId
end

---Gets the total number of free bag slots.
---@return number
function Container.GetTotalFreeBagSlots()
	return C_Container.CalculateTotalNumberOfFreeBagSlots()
end

---Returns whether or not an item can be deposited into the warbank.
---@param slotId number The slot ID
---@return boolean
function Container.CanDepositIntoWarbank(slotId)
	if not LibTSMWoW.IsRetail() then
		return false
	end
	local itemLocation = SlotId.AcquireItemLocation(slotId)
	local canDeposit = C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation)
	SlotId.ReleaseItemLocation(itemLocation)
	return canDeposit
end

---Returns the amount of money in the warbank.
---@return number
function Container.GetWarbankMoney()
	return C_Bank.FetchDepositedMoney(Enum.BankType.Account)
end

---Registers a callback when the bank frame is shown or hidden.
---@param callback fun(isOpen: boolean) The callback function
function Container.RegisterBankFrameCallback(callback)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	private.bankFrameCallbacks:Add(callback)
end

---Returns whether or not the warbank is open.
---@return boolean
function Container.IsWarbankOpen()
	return Container.CanAccessWarbank() and BankFrame:GetActiveBankType() == Enum.BankType.Account
end

---Opens all bags.
function Container.OpenAllBags()
	OpenAllBags()
end

---Auto deposit reagent items into the bank.
function Container.AutoDepositReagentBank()
	C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Character)
end

---Auto deposit items into the warbank.
function Container.AutoDepositWarbank()
	C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.BagSlotIterator(_, slotId)
	local bag, slot = SlotId.Split(slotId)
	while private.bagRange:Includes(bag) do
		slot = slot + 1
		if slot <= Container.GetNumSlots(bag) then
			return SlotId.Join(bag, slot)
		end
		bag = bag + 1
		slot = 0
	end
end

function private.SlotIdIterator(maxSlotId, slotId)
	slotId = slotId + 1
	if slotId > maxSlotId then
		return
	end
	return slotId
end

function private.ItemLockedHandler(_, bag, slot)
	if not slot then
		return
	end
	private.slotIdLocked[SlotId.Join(bag, slot)] = true
end

function private.ItemUnlockedHandler(_, bag, slot)
	if not slot then
		return
	end
	private.slotIdLocked[SlotId.Join(bag, slot)] = nil
end

function private.BankFrameShowHook()
	private.bankFrameCallbacks:CallAll(true)
end

function private.BankFrameOpened()
	if private.bankFrameOpen then
		return
	end
	private.bankFrameOpen = true
	Event.Register("GLOBAL_MOUSE_UP", private.GlobalMouseUp)
end

function private.BankFrameClosed()
	if not private.bankFrameOpen then
		return
	end
	private.bankFrameOpen = false
	Event.Unregister("GLOBAL_MOUSE_UP", private.GlobalMouseUp)
end

function private.GlobalMouseUp(_, button)
	if button ~= "LeftButton" then
		return
	end
	private.bankFrameCallbacks:CallAll(BankFrame:IsShown() and true or false)
end

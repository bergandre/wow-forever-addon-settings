-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local SlotId = LibTSMWoW:Init("Type.SlotId")
local ObjectPool = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local SLOT_ID_MULTIPLIER = 1000
local private = {
	itemLocationPool = ObjectPool.New("SLOT_ID_ITEM_LOCATION", function() return ItemLocation:CreateEmpty() end), ---@type ObjectPool<ItemLocation>
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Combines a bag and slot into a slotId.
---@param bag number The bag
---@param slot number The slot
---@return number
function SlotId.Join(bag, slot)
	if slot >= SLOT_ID_MULTIPLIER or slot < 0 then
		error("Invalid slot: "..slot)
	end
	return bag * SLOT_ID_MULTIPLIER + slot
end

---Splits a slotId into a bag and slot
---@param slotId number The slotId
---@return number bag
---@return number slot
function SlotId.Split(slotId)
	local bag = floor(slotId / SLOT_ID_MULTIPLIER)
	local slot = slotId % SLOT_ID_MULTIPLIER
	return bag, slot
end

---Gets a slot ID from an item location.
---@param itemLocation ItemLocation The item location
---@return number
function SlotId.GetFromItemLocation(itemLocation)
	return SlotId.Join(itemLocation:GetBagAndSlot())
end

---Acquires an item location for a given slot ID.
---@param slotId number The slot ID
---@return ItemLocation
function SlotId.AcquireItemLocation(slotId)
	local itemLocation = private.itemLocationPool:Get()
	itemLocation:SetBagAndSlot(SlotId.Split(slotId))
	return itemLocation
end

---Releases a previously acquired item location.
---@param itemLocation ItemLocation The item location acquired via `SlotId.AcquireItemLocation`
function SlotId.ReleaseItemLocation(itemLocation)
	private.itemLocationPool:Recycle(itemLocation)
end

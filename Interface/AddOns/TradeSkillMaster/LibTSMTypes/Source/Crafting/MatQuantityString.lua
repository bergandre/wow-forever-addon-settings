-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local MatQuantityString = LibTSMTypes:Init("Crafting.MatQuantityString")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local Iterator = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.Iterator")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	partsTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a mat quantity string.
---@param mats table<string,number> The mats table (key is `itemString`, value is `quantity`)
---@return string
function MatQuantityString.Get(mats)
	assert(not next(private.partsTemp))
	for itemString, quantity in pairs(mats) do
		assert(ItemString.IsItem(itemString))
		local itemId = ItemString.ToId(itemString)
		local part = itemId.."x"..quantity
		tinsert(private.partsTemp, part)
		private.partsTemp[part] = itemId
	end
	Table.SortWithValueLookup(private.partsTemp, private.partsTemp)
	local result = table.concat(private.partsTemp, ",")
	Table.WipeAndDeallocate(private.partsTemp)
	return result
end

---Gets a mat quantity string for a single item.
---@param itemString string The itemString
---@param quantity number The quantity
---@return string
function MatQuantityString.GetForSingleItem(itemString, quantity)
	assert(ItemString.IsItem(itemString))
	local itemId = ItemString.ToId(itemString)
	return itemId.."x"..quantity
end

---Returns whether or not a string is a mat quantity string.
---@param str string The string to check
---@return boolean
function MatQuantityString.IsString(str)
	return strmatch(str, "^%d+x%d+") and true or false
end

---Iterates over the mats in the mat quantity string.
---@param matQuantityString string The mat quantity string
---@return IteratorObject<fun(): string, string, number> @Iterator with fields: `key`, `itemString`, `quantity`
function MatQuantityString.Iterator(matQuantityString)
	return Iterator.Acquire(String.SplitIterator(matQuantityString, ","))
		:SetMapFunc(private.IteratorMap)
end

---Gets the quantity of a given item.
---@param matQuantityString string The mat quantity string
---@param itemString string The item string
---@return number
function MatQuantityString.GetQuantity(matQuantityString, itemString)
	local iter = MatQuantityString.Iterator(matQuantityString)
	for _, matItemString, quantity in iter do
		if matItemString == itemString then
			iter:Release()
			return quantity
		end
	end
	return 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IteratorMap(part)
	local itemId, quantity = strsplit("x", part)
	itemId = itemId and tonumber(itemId)
	quantity = quantity and tonumber(quantity)
	assert(itemId and quantity)
	return ItemString.FromItemId(itemId), quantity
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local Util = LibTSMSystem:Init("Operation.Util")
local Iterator = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.Iterator")
local Group = LibTSMSystem:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMSystem:From("LibTSMTypes"):Include("GroupOperation")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local private = {
	frameTimeFunc = nil,
	itemPriceFunc = {},
	priceCache = {},
	operationTypeIteratorFilterFunc = {},
	operationTypeIteratorMapFunc = {},
}
local INVALID_PRICE = newproxy(false)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the function to call to get the current frame time for caching.
---@param frameTimeFunc fun(): number Function to call
function Util.SetFrameTimeFunc(frameTimeFunc)
	private.frameTimeFunc = frameTimeFunc
end

---Gets the first operation assigned to the group the item is in.
---@param operationType string The operation type
---@param itemString string The item string
---@return (OperationSettings settings, string name)|(nil, nil)
function Util.GetFirstOperationByItem(operationType, itemString)
	return select(2, Util.OperationIteratorByItem(operationType, itemString):GetValueAndRelease()) ---@diagnostic disable-line: grouped-return-mismatch
end

---Iterates over the operations for an item.
---@param operationType string The operation type
---@param itemString string The item string
---@return IteratorObject<fun(): number, OperationSettings, string> @Iterator with fields: `index`, `operationSettings`, `operationName`
function Util.OperationIteratorByItem(operationType, itemString)
	return Util.OperationIteratorByGroup(operationType, Group.GetPathByItem(itemString))
end

---Iterates over the operations for an item.
---@param operationType string The operation type
---@param groupPath GroupPathValue The group path
---@return IteratorObject<fun(): number, OperationSettings, string> @Iterator with fields: `index`, `operationSettings`, `operationName`
function Util.OperationIteratorByGroup(operationType, groupPath)
	return private.OperationIterator(operationType, groupPath)
end

---Configures the item prices for a given operation type.
---@param operationType string The operation type
---@param func fun(itemString: string, operationSettings: OperationSettings, key: string): number? A function to look up an item price
function Util.ConfigureItemPrices(operationType, func)
	private.itemPriceFunc[operationType] = func
end

---Gets the value of a price setting for a given item and (optionally) operation.
---@param operationType string The operation type
---@param itemString string The item string
---@param key string The setting key
---@param operationSettings? OperationSettings The operation settings to use (otherwise looks up the first one for the item)
---@return number?
function Util.GetItemPrice(operationType, itemString, key, operationSettings)
	operationSettings = operationSettings or Util.GetFirstOperationByItem(operationType, itemString)
	if not operationSettings then
		return nil
	end
	local cacheKey = key..tostring(operationSettings)..itemString
	if private.priceCache.updateTime ~= private.frameTimeFunc() then
		wipe(private.priceCache)
		private.priceCache.updateTime = private.frameTimeFunc()
	end
	if not private.priceCache[cacheKey] then
		private.priceCache[cacheKey] = private.itemPriceFunc[operationType](itemString, operationSettings, key) or INVALID_PRICE
	end
	if private.priceCache[cacheKey] == INVALID_PRICE then
		return nil
	end
	return private.priceCache[cacheKey]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OperationIterator(operationType, groupPath)
	if not private.operationTypeIteratorFilterFunc[operationType] then
		private.operationTypeIteratorFilterFunc[operationType] = function(_, operationName)
			Operation.UpdateFromRelationships(operationType, operationName)
			return not Operation.IsIgnored(operationType, operationName)
		end
	end
	if not private.operationTypeIteratorMapFunc[operationType] then
		private.operationTypeIteratorMapFunc[operationType] = function(_, operationName)
			return Operation.GetSettings(operationType, operationName), operationName
		end
	end
	return Iterator.Acquire(GroupOperation.Iterator(groupPath, operationType))
		:Filter(private.operationTypeIteratorFilterFunc[operationType])
		:SetMapFunc(private.operationTypeIteratorMapFunc[operationType])
end

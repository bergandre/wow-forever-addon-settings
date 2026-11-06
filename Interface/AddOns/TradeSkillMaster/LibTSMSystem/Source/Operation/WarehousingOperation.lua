-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local WarehousingOperation = LibTSMSystem:Init("WarehousingOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local Math = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Math")
local Range = LibTSMSystem:From("LibTSMUtil"):IncludeClassType("Range")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local private = {
	bagQuantityFunc = nil,
}
local OPERATION_TYPE = "Warehousing"
local VALUE_RANGES = { ---@type table<WarehousingOperationRangeKeys,Range>
	moveQuantity = Range.StaticStartEnd(0, 50000),
	keepBagQuantity = Range.StaticStartEnd(0, 50000),
	keepBankQuantity = Range.StaticStartEnd(0, 50000),
	restockQuantity = Range.StaticStartEnd(0, 50000),
	stackSize = Range.StaticStartEnd(0, 200),
	restockKeepBankQuantity = Range.StaticStartEnd(0, 50000),
	restockStackSize = Range.StaticStartEnd(0, 200),
}

---@class WarehousingOperationSettings: OperationSettings
---@field moveQuantity string
---@field keepBagQuantity string
---@field keepBankQuantity string
---@field restockQuantity string
---@field stackSize string
---@field restockKeepBankQuantity string
---@field restockStackSize string

---@alias WarehousingOperationRangeKeys
---| "moveQuantity"
---| "keepBagQuantity"
---| "keepBankQuantity"
---| "restockQuantity"
---| "stackSize"
---| "restockKeepBankQuantity"
---| "restockStackSize"



-- ============================================================================
-- Module Loading
-- ============================================================================

WarehousingOperation:OnModuleLoad(function()
	Util.ConfigureItemPrices(OPERATION_TYPE, function(itemString, operationSettings, key)
		local value = CustomString.GetValue(operationSettings[key] --[[@as string]], itemString, true)
		if value and not VALUE_RANGES[key]:Includes(value) then
			value = nil
		end
		return value
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Warehousing operation code.
---@param localizedName string The localized operation type name
---@param bagQuantityFunc fun(itemString: string): number A function to get the quantity of an item in the bags
function WarehousingOperation.Load(localizedName, bagQuantityFunc)
	private.bagQuantityFunc = bagQuantityFunc
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 12)
		:ExcludeDefaultFromBaseGroup()
		:AddCustomStringSetting("moveQuantity", "0")
		:AddCustomStringSetting("keepBagQuantity", "0")
		:AddCustomStringSetting("keepBankQuantity", "0")
		:AddCustomStringSetting("restockQuantity", "0")
		:AddCustomStringSetting("stackSize", "0")
		:AddCustomStringSetting("restockKeepBankQuantity", "0")
		:AddCustomStringSetting("restockStackSize", "0")
	Operation.RegisterType(operationType)
end

---Gets the (static) range of valid values for a setting.
---@param key WarehousingOperationRangeKeys The setting key
---@return Range
function WarehousingOperation.GetSettingRange(key)
	local range = VALUE_RANGES[key]
	assert(range)
	return range
end

---Gets the number of an item to move to the bank.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function WarehousingOperation.GetNumToMoveToBank(itemString, numHave)
	local numToMove, numKeep = 0, 0
	local iter = Util.OperationIteratorByItem(OPERATION_TYPE, itemString)
	for _, operationSettings in iter do
		---@cast operationSettings WarehousingOperationSettings
		local keepBagQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepBagQuantity", operationSettings)
		local moveQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "moveQuantity", operationSettings)
		if not keepBagQuantity or not moveQuantity then
			-- This operation isn't valid
			iter:Release()
			return 0
		end
		numKeep = max(numKeep, keepBagQuantity)
		local quantity = max(numHave - numToMove - numKeep, 0)
		if moveQuantity ~= 0 then
			quantity = min(quantity, moveQuantity)
		end
		numToMove = numToMove + quantity
	end
	return numToMove
end

---Gets the number of an item to move to bags.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function WarehousingOperation.GetNumToMoveToBags(itemString, numHave)
	local numToMove, numKeep = 0, 0
	local iter = Util.OperationIteratorByItem(OPERATION_TYPE, itemString)
	for _, operationSettings in iter do
		---@cast operationSettings WarehousingOperationSettings
		local keepBankQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepBankQuantity", operationSettings)
		local moveQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "moveQuantity", operationSettings)
		local stackSize = Util.GetItemPrice(OPERATION_TYPE, itemString, "stackSize", operationSettings)
		if not keepBankQuantity or not moveQuantity or not stackSize then
			-- This operation isn't valid
			iter:Release()
			return 0
		end
		numKeep = max(numKeep, keepBankQuantity)
		local quantity = max(numHave - numToMove - numKeep, 0)
		if moveQuantity ~= 0 then
			quantity = min(quantity, moveQuantity)
		end
		numToMove = numToMove + Math.Floor(quantity, stackSize ~= 0 and stackSize or 1)
	end
	return numToMove
end

---Gets the number of an item to move for restocking.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function WarehousingOperation.GetNumToMoveRestock(itemString, numHave)
	local numInBags = private.bagQuantityFunc(itemString)
	local numToMove, numKeep = 0, 0
	local iter = Util.OperationIteratorByItem(OPERATION_TYPE, itemString)
	for _, operationSettings in iter do
		---@cast operationSettings WarehousingOperationSettings
		local restockQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockQuantity", operationSettings)
		local restockKeepBankQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockKeepBankQuantity", operationSettings)
		local restockStackSize = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockStackSize", operationSettings)
		if not restockQuantity or not restockKeepBankQuantity or not restockStackSize then
			-- This operation isn't valid
			iter:Release()
			return 0
		end
		if restockQuantity ~= 0 then
			numKeep = max(numKeep, restockKeepBankQuantity)
			local numCovered = min(numInBags, restockQuantity)
			numInBags = numInBags - numCovered
			local quantity = min(max(numHave - numToMove - numKeep, 0), restockQuantity - numCovered)
			numToMove = numToMove + Math.Floor(quantity, restockStackSize ~= 0 and restockStackSize or 1)
		end
	end
	return numToMove
end

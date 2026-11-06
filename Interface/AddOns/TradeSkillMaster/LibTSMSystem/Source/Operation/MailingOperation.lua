-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local MailingOperation = LibTSMSystem:Init("MailingOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local TempTable = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Table")
local Range = LibTSMSystem:From("LibTSMUtil"):IncludeClassType("Range")
local Group = LibTSMSystem:From("LibTSMTypes"):Include("Group")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local private = {
	quantityFunc = nil, ---@type MailingOperationQuantityFunc!
	isPlayerFunc = nil, ---@type MailingOperationIsPlayerFunc!
	bagQuantityFunc = nil, ---@type MailingOperationBagQuantityFunc!
}
local OPERATION_TYPE = "Mailing"
local VALUE_RANGES = { ---@type table<MailingOperationRangeKeys,Range>
	maxQty = Range.StaticStartEnd(1, 50000),
	keepQty = Range.StaticStartEnd(0, 50000),
}

---@class MailingOperationSettings: OperationSettings
---@field maxQtyEnabled boolean
---@field maxQty string
---@field target string
---@field restock boolean
---@field restockSources table<"guild"|"bank",boolean>
---@field keepQty string

---@alias MailingOperationRangeKeys
---| "keepQty"
---| "maxQty"

---@alias MailingOperationQuantityFunc fun(characterName: string, itemString: string, includeGuild: boolean, includeBank: boolean): number
---@alias MailingOperationIsPlayerFunc fun(characterName: string): boolean
---@alias MailingOperationBagQuantityFunc fun(itemString: string): number



-- ============================================================================
-- Module Loading
-- ============================================================================

MailingOperation:OnModuleLoad(function()
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

---Loads the Mailing operation code.
---@param localizedName string The localized operation type name
---@param quantityFunc MailingOperationQuantityFunc Function which gets character item quantity
---@param isPlayerFunc MailingOperationIsPlayerFunc Function which checks if a character belongs to the player
---@param bagQuantityFunc MailingOperationBagQuantityFunc Function which gets the mailable quantity of an item in the bags
function MailingOperation.Load(localizedName, quantityFunc, isPlayerFunc, bagQuantityFunc)
	private.quantityFunc = quantityFunc
	private.isPlayerFunc = isPlayerFunc
	private.bagQuantityFunc = bagQuantityFunc
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 50)
		:ExcludeDefaultFromBaseGroup()
		:AddBooleanSetting("maxQtyEnabled")
		:AddCustomStringSetting("maxQty", "10")
		:AddStringSetting("target")
		:AddBooleanSetting("restock")
		:AddTableSetting("restockSources", { guild = false, bank = false })
		:AddCustomStringSetting("keepQty", "0")
	Operation.RegisterType(operationType)
end

---Gets the settings for a given operation.
---@param operationName string The operation name
---@return MailingOperationSettings
function MailingOperation.GetSettings(operationName)
	return Operation.GetSettings(OPERATION_TYPE, operationName) --[[@as MailingOperationSettings]]
end

---Gets the (static) range of valid values for a setting.
---@param key MailingOperationRangeKeys The setting key
---@return Range
function MailingOperation.GetSettingRange(key)
	local range = VALUE_RANGES[key]
	assert(range)
	return range
end

---Gets the shortfall quantity to move to bags.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function MailingOperation.TargetShortfallGetNumToBags(itemString, numHave)
	local isInvalid = false
	local numToSend, numKeep, numForPlayer = 0, 0, 0
	for _, operationSettings in private.EnabledOperationIterator(Group.GetPathByItem(itemString)) do
		---@cast operationSettings MailingOperationSettings
		local keepQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepQty", operationSettings)
		local quantity = private.GetNumNeededForOperation(itemString, operationSettings)
		if keepQty and quantity then
			numKeep = max(numKeep, keepQty)
			if private.isPlayerFunc(operationSettings.target) then
				numForPlayer = max(numForPlayer, quantity)
			else
				numToSend = numToSend + quantity
			end
		else
			-- This operation isn't valid
			isInvalid = true
		end
	end
	if isInvalid or numToSend + numForPlayer == 0 then
		return 0
	end
	return min(max(numToSend + max(numKeep, numForPlayer) - private.bagQuantityFunc(itemString), 0), numHave)
end

---Iterates over the targets to send a given item to.
---@param itemString string The item string
---@param availableQuantity number The available quantity to be sent
---@return fun(): number, string, number @Iterator with fields: `index`, `target`, `quantity`
---@return table
---@return number
function MailingOperation.SendTargetIterator(itemString, availableQuantity)
	local groupPath = Group.GetPathByItem(itemString)
	local numUsed, numKeep = 0, 0
	local result = TempTable.Acquire()
	for _, operationSettings in private.EnabledOperationIterator(groupPath) do
		---@cast operationSettings MailingOperationSettings
		local target = operationSettings.target
		local maxQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "maxQty", operationSettings)
		local keepQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepQty", operationSettings)
		if (maxQty or not operationSettings.maxQtyEnabled) and keepQty then
			numKeep = max(numKeep, keepQty)
			local numAvailable = availableQuantity - numUsed - numKeep
			local quantity = private.GetNumToSend(itemString, operationSettings, numAvailable, maxQty)
			assert(quantity >= 0)
			if private.isPlayerFunc(target) then
				numKeep = max(numKeep, quantity)
			else
				numUsed = numUsed + quantity
				if quantity > 0 then
					Table.InsertMultiple(result, target, quantity)
				end
			end
		end

	end
	return TempTable.Iterator(result, 2)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.EnabledOperationIterator(groupPath)
	-- TODO: This iterator has a map set internally, so our filter needs to operate on the initial set of values - find a better way to do this
	return Util.OperationIteratorByGroup(OPERATION_TYPE, groupPath)
		:Filter(private.EnabledOperationIteratorFilter)
end

function private.EnabledOperationIteratorFilter(_, operationName)
	return MailingOperation.GetSettings(operationName).target ~= ""
end

---@param operationSettings MailingOperationSettings
function private.GetNumToSend(itemString, operationSettings, numAvailable, maxQty)
	if numAvailable <= 0 then
		return 0
	end
	local numToSend = 0
	local isTargetPlayer = private.isPlayerFunc(operationSettings.target)
	if operationSettings.maxQtyEnabled then
		if operationSettings.restock then
			local targetQty = private.quantityFunc(operationSettings.target, itemString, operationSettings.restockSources.guild, operationSettings.restockSources.bank)
			if isTargetPlayer and targetQty <= maxQty then
				numToSend = numAvailable
			elseif isTargetPlayer then
				numToSend = numAvailable - (targetQty - maxQty)
			else
				numToSend = min(numAvailable, maxQty - targetQty)
			end

		else
			numToSend = min(numAvailable, maxQty)
		end
	elseif not isTargetPlayer then
		numToSend = numAvailable
	end
	return max(numToSend, 0)
end

---@param operationSettings MailingOperationSettings
function private.GetNumNeededForOperation(itemString, operationSettings)
	if not operationSettings.maxQtyEnabled then
		return math.huge
	end
	local maxQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "maxQty", operationSettings)
	if not maxQty then
		-- This operation isn't valid
		return nil
	end
	if not operationSettings.restock then
		return maxQty
	end
	local isTargetPlayer = private.isPlayerFunc(operationSettings.target)
	local includeGuild = operationSettings.restockSources.guild and not isTargetPlayer
	local includeBank = operationSettings.restockSources.bank and not isTargetPlayer
	local targetQty = private.quantityFunc(operationSettings.target, itemString, includeGuild, includeBank)
	if isTargetPlayer then
		targetQty = targetQty - private.bagQuantityFunc(itemString)
	end
	return max(maxQty - targetQty, 0)
end

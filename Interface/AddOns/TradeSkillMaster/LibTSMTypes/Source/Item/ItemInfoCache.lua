-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local ItemInfoCache = LibTSMTypes:DefineClassType("ItemInfoCache")
local ItemInfoSerializer = LibTSMTypes:Include("Item.ItemInfoSerializer")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local Reactive = LibTSMTypes:From("LibTSMReactive"):Include("Reactive")
local Database = LibTSMTypes:From("LibTSMDatabase"):Include("Database")
local private = {
	updatesTemp = {},
}

---@class SavedItemInfoCache
---@field versionStr string!
---@field data (table|string)!



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new ItemInfoCache.
---@return ItemInfoCache
function ItemInfoCache.__static.New()
	return ItemInfoCache()
end

---Asserts that a value is valid for the specified field.
---@param key string They key of the field
---@param value number The value
function ItemInfoCache.__static.CheckFieldValue(key, value)
	ItemInfoSerializer.CheckFieldValue(key, value)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ItemInfoCache.__private:__init()
	self._hasChanged = false
	self._db = Database.NewSchema("ITEM_INFO")
		:AddUniqueStringField("itemString")
		:AddStringField("name")
		:AddNumberField("itemLevel")
		:AddNumberField("minLevel")
		:AddNumberField("maxStack")
		:AddNumberField("vendorSell")
		:AddNumberField("invSlotId")
		:AddNumberField("texture")
		:AddNumberField("classId")
		:AddNumberField("subClassId")
		:AddNumberField("quality")
		:AddNumberField("isBOP")
		:AddNumberField("isCraftingReagent")
		:AddNumberField("expansionId")
		:AddNumberField("craftedQuality")
		:AddTrigramIndex("name")
		:Commit()
	self._stream = Reactive.GetStream(function() return nil end) ---@type ReactiveStream<string?>
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Loads the DB and returns whether or not it was valid.
---@param saved SavedItemInfoCache The persistent DB to load
---@param versionStr string The version string
---@return boolean
function ItemInfoCache:Load(saved, versionStr)
	assert(type(saved) == "table" and type(versionStr) == "string")
	local isValid = nil
	if saved.versionStr ~= versionStr then
		Log.Err("Version changed from '%s' to '%s'", tostring(saved.versionStr), versionStr)
		isValid = false
	elseif not saved.data then
		isValid = false
	else
		local function RowHandler(...)
			self._db:BulkInsertNewRowFast15(...)
		end
		self._db:BulkInsertStart()
		local hasChanged = nil
		isValid, hasChanged = ItemInfoSerializer.DecodeData(saved.data, RowHandler)
		self._hasChanged = self._hasChanged or hasChanged
		self._db:BulkInsertEnd()
	end
	if not isValid then
		wipe(saved)
		self._hasChanged = true
	end
	self._stream:Send(nil)
	return isValid
end

---Saves the DB.
---@param saved SavedItemInfoCache The persistent DB to save into
---@param versionStr string The version string
function ItemInfoCache:Save(saved, versionStr)
	if not self._hasChanged then
		-- Nothing changed since loading, so don't need to do anything
		return
	end
	local data = ItemInfoSerializer.EncodeData(self._db:GetRawData(), self._db:GetNumRows())
	if not data then
		Log.Err("Failed to save data")
		wipe(saved)
		return
	end
	saved.data = data
	saved.versionStr = versionStr
end

---Creates a new database query which is automatically released after execution.
---@return DatabaseQuery
function ItemInfoCache:NewAutoReleaseQuery()
	return self._db:NewAutoReleaseQuery()
end

---Creates a new database query which is owned by the caller.
---@return DatabaseQuery
function ItemInfoCache:NewOwnedQuery()
	return self._db:NewOwnedQuery()
end

---Creates a publisher for item info changes.
---@return ReactivePublisherSchema<string?>
function ItemInfoCache:Publisher()
	return self._stream:Publisher()
end

---Checks whether or not we have info for a given item
---@param itemString string The item string
---@return boolean
function ItemInfoCache:HaveInfo(itemString)
	if not self._db:HasUniqueRow("itemString", itemString) then
		return false
	end
	local name, quality, itemLevel = self._db:GetRowFields(self._db:GetUniqueRow("itemString", itemString), "name", "quality", "itemLevel")
	return name and name ~= "" and quality and quality >= 0 and itemLevel and itemLevel >= 0 or false
end

---Gets the value of a field for an item.
---@param itemString string The item string
---@param key string The field key
---@return number|string|nil
function ItemInfoCache:GetField(itemString, key)
	if not self._db:HasUniqueRow("itemString", itemString) then
		return nil
	end
	local value = self._db:GetRowFields(self._db:GetUniqueRow("itemString", itemString), key)
	if value == -1 or value == "" then
		return nil
	end
	return value
end

---Updates the value of a field for an item.
---@param itemString string The item string
---@param key string The field key
---@param value number|string
function ItemInfoCache:UpdateField(itemString, key, value)
	self:_PrepareRow(itemString)
	local uuid = self._db:GetUniqueRow("itemString", itemString)
	if self._db:GetRowFields(uuid, key) == value then
		return
	end
	self._db:UpdateRow(uuid, key, value)
	self:StreamSend(itemString)
	self._hasChanged = true
end

---Bulk prepares item cache rows for insertion / modification.
---@param itemStrings table<string,any> Table with item strings as keys
---@param includeBaseItems? boolean Whether or not to prepare base items
function ItemInfoCache:BulkPrepareRows(itemStrings, includeBaseItems)
	self._db:BulkInsertStart()
	for itemString in pairs(itemStrings) do
		self:_PrepareRow(itemString, true)
		if includeBaseItems then
			local baseItemString = ItemString.GetBaseFast(itemString)
			if baseItemString ~= itemString then
				self:_PrepareRow(baseItemString, true)
			end
		end
	end
	self._db:BulkInsertEnd()
end

---Returns an iterator which executes to completion with cache DB query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function ItemInfoCache:WithQueryUpdatesPaused(func, obj, key)
	return self._db:WithQueryUpdatesPaused(func, obj, key)
end

---Sets fields for an item which are preloaded by the game.
---@param itemString string The item string
---@param texture number The texture ID
---@param classId number The class ID
---@param subClassId number The subclass ID
---@param invSlotId number The inventory slot ID
function ItemInfoCache:SetPreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	self:_PrepareRow(itemString)
	self:_UpdatePreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	self:StreamSend(itemString)
	local baseItemString = ItemString.GetBaseFast(itemString)
	if baseItemString ~= itemString then
		-- Also set the base item
		self:_PrepareRow(baseItemString)
		self:_UpdatePreloadedFields(baseItemString, texture, classId, subClassId, invSlotId)
		self:StreamSend(baseItemString)
	end
	self._hasChanged = true
end

---Sets fields for an item which are queried from the game.
---@param itemString string The item string
---@param name string The name
---@param minLevel number The minimum required level
---@param itemLevel number The item level
---@param maxStack number The max stack size
---@param vendorSell number The vendor sell price
---@param quality number The quality
---@param isBOP number Whether or not the item is bind on pickup
---@param isCraftingReagent number Whether or not the item is a crafting reagent
---@param expansionId number The expansion ID
---@param craftedQuality number The crafted quality
function ItemInfoCache:SetQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:_PrepareRow(itemString)
	self:_UpdateQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:StreamSend(itemString)
	self._hasChanged = true
end

---Sets all fields for an item.
---@param itemString string The item string
---@param texture number The texture ID
---@param classId number The class ID
---@param subClassId number The subclass ID
---@param invSlotId number The inventory slot ID
---@param name string The name
---@param minLevel number The minimum required level
---@param itemLevel number The item level
---@param maxStack number The max stack size
---@param vendorSell number The vendor sell price
---@param quality number The quality
---@param isBOP number Whether or not the item is bind on pickup
---@param isCraftingReagent number Whether or not the item is a crafting reagent
---@param expansionId number The expansion ID
---@param craftedQuality number The crafted quality
function ItemInfoCache:SetAllFields(itemString, texture, classId, subClassId, invSlotId, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:_PrepareRow(itemString)
	self:_UpdatePreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	self:_UpdateQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:StreamSend(itemString)
	self._hasChanged = true
end

---Sends an item string to the cache's stream to notify consumers of an update.
---@param itemString string
function ItemInfoCache:StreamSend(itemString)
	self._stream:Send(itemString)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ItemInfoCache.__private:_PrepareRow(itemString, isBulkInsert)
	if self._db:HasUniqueRow("itemString", itemString) then
		return
	end
	if isBulkInsert then
		self._db:BulkInsertNewRow(itemString, "", -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1)
	else
		self._db:InsertRow(itemString, "", -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1)
	end
	self._hasChanged = true
end

function ItemInfoCache.__private:_UpdatePreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	ItemInfoSerializer.CheckFieldValue("texture", texture)
	ItemInfoSerializer.CheckFieldValue("classId", classId)
	ItemInfoSerializer.CheckFieldValue("subClassId", subClassId)
	ItemInfoSerializer.CheckFieldValue("invSlotId", invSlotId)
	assert(not next(private.updatesTemp))
	private.updatesTemp.texture = texture
	private.updatesTemp.classId = classId
	private.updatesTemp.subClassId = subClassId
	private.updatesTemp.invSlotId = invSlotId
	self._db:UpdateRow(self._db:GetUniqueRow("itemString", itemString), private.updatesTemp)
	wipe(private.updatesTemp)
end

function ItemInfoCache.__private:_UpdateQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	ItemInfoSerializer.CheckFieldValue("minLevel", minLevel)
	ItemInfoSerializer.CheckFieldValue("itemLevel", itemLevel)
	ItemInfoSerializer.CheckFieldValue("maxStack", maxStack)
	ItemInfoSerializer.CheckFieldValue("vendorSell", vendorSell)
	ItemInfoSerializer.CheckFieldValue("quality", quality)
	ItemInfoSerializer.CheckFieldValue("isBOP", isBOP)
	ItemInfoSerializer.CheckFieldValue("isCraftingReagent", isCraftingReagent)
	ItemInfoSerializer.CheckFieldValue("expansionId", expansionId)
	ItemInfoSerializer.CheckFieldValue("craftedQuality", craftedQuality)
	assert(not next(private.updatesTemp))
	private.updatesTemp.name = name
	private.updatesTemp.minLevel = minLevel
	private.updatesTemp.itemLevel = itemLevel
	private.updatesTemp.maxStack = maxStack
	private.updatesTemp.vendorSell = vendorSell
	private.updatesTemp.quality = quality
	private.updatesTemp.isBOP = isBOP
	private.updatesTemp.isCraftingReagent = isCraftingReagent
	private.updatesTemp.expansionId = expansionId
	private.updatesTemp.craftedQuality = craftedQuality
	self._db:UpdateRow(self._db:GetUniqueRow("itemString", itemString), private.updatesTemp)
	wipe(private.updatesTemp)
end

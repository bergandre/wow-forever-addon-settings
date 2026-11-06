-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local ItemInfoSerializer = LibTSMTypes:InitInternal("Item.ItemInfoSerializer")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local LongString = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.LongString")
local Encoder = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("Encoder")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local private = {
	encoder = nil,
}
local SEP_CHAR = "\002"
local ENCODING_NUM_BITS = 6
local ENCODING_NUM_VALUES = 2 ^ ENCODING_NUM_BITS
local ENCODING_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
assert(#ENCODING_ALPHABET == ENCODING_NUM_VALUES)
local ENCODING_TABLE = {} ---@type table<number,number>
local ENCODING_TABLE_2 = {} ---@type table<number,number>
local DECODING_TABLE = {} ---@type table<number,number>
local DECODING_TABLE_1 = {} ---@type table<number,number>
local DECODED_NIL_VALUE = ENCODING_NUM_VALUES - 1
local ENCODED_NIL_CHAR = nil
local RECORD_DATA_LENGTH_CHARS = 24
local RECORD_DATA_NUM_FIELDS = 15
---@diagnostic disable: missing-fields
local FIELD_INFO = { ---@type table<string,ItemInfoSerializer.FieldInfo>
	itemLevel = { numBits = 12 },
	minLevel = { numBits = 12 },
	vendorSell = { numBits = 30 },
	maxStack = { numBits = 12 },
	invSlotId = { numBits = 6 },
	texture = { numBits = 30 },
	classId = { numBits = 6 },
	subClassId = { numBits = 6 },
	quality = { numBits = 6 },
	isBOP = { numBits = 6 },
	isCraftingReagent = { numBits = 6 },
	expansionId = { numBits = 6 },
	craftedQuality = { numBits = 6 },
}
---@diagnostic enable: missing-fields

---@class ItemInfoSerializer.FieldInfo
---@field numBits number
---@field numChars number
---@field nilValue number
---@field maxValue number



-- ============================================================================
-- Constants Initialization
-- ============================================================================

do
	for i = 0, ENCODING_NUM_VALUES - 1 do
		local encodedValue = strbyte(ENCODING_ALPHABET, i + 1, i + 1)
		ENCODING_TABLE[i] = encodedValue
		DECODING_TABLE[encodedValue] = i
		if i == DECODED_NIL_VALUE then
			DECODING_TABLE_1[encodedValue] = -1
		else
			DECODING_TABLE_1[encodedValue] = i
		end
	end
	ENCODED_NIL_CHAR = ENCODING_TABLE[DECODED_NIL_VALUE]
	for i = 0, ENCODING_NUM_VALUES ^ 2 - 1 do
		local value = i
		local charValue0 = value % 2 ^ ENCODING_NUM_BITS
		value = (value - charValue0) / 2 ^ ENCODING_NUM_BITS
		local charValue1 = value % 2 ^ ENCODING_NUM_BITS
		value = (value - charValue1) / 2 ^ ENCODING_NUM_BITS
		ENCODING_TABLE_2[i] = { ENCODING_TABLE[charValue0], ENCODING_TABLE[charValue1] }
		assert(value == 0)
	end
	local totalLengthChars = 0
	for _, info in pairs(FIELD_INFO) do
		assert(info.numBits % ENCODING_NUM_BITS == 0)
		info.numChars = info.numBits / ENCODING_NUM_BITS
		totalLengthChars = totalLengthChars + info.numChars
		info.nilValue = 2 ^ info.numBits - 1
		info.maxValue = 2 ^ info.numBits - 2
	end
	assert(totalLengthChars == RECORD_DATA_LENGTH_CHARS)
end



-- ============================================================================
-- Module Loading
-- ============================================================================

ItemInfoSerializer:OnModuleLoad(function()
	private.encoder = Encoder.Create()
		:SetEncodingType("BASE64")
		:SetSerializationType("CBOR")
end)


-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not encoded data is valid.
---@param data string
function ItemInfoSerializer.IsEncodedDataValue(data)
	return #data % RECORD_DATA_LENGTH_CHARS == 0
end

---Decodes serialized data.
---@param saved table|string The serialized data
---@param handler function Handler which is passed each row of decoded data
---@return boolean success
---@return boolean needsEncoding
function ItemInfoSerializer.DecodeData(saved, handler)
	if type(saved) == "string" then
		if not private.encoder then
			Log.Err("Unexpected saved data type")
			return false, false
		end
		local success, result = private.encoder:Deserialize(saved)
		if not success then
			Log.Err("Failed to deserialize data (%s)", tostring(result))
			return false, false
		elseif type(result) ~= "table" then
			Log.Err("Invalid data (%s)", result)
			return false, false
		elseif #result % RECORD_DATA_NUM_FIELDS ~= 0 then
			Log.Err("Invalid data size (%d)", #result)
			return false, false
		end
		for i = 1, #result, RECORD_DATA_NUM_FIELDS do
			handler(unpack(result, i, i + RECORD_DATA_NUM_FIELDS - 1))
		end
		Log.Info("Imported %d items worth of data", #result / RECORD_DATA_NUM_FIELDS)
		return true, false
	end

	if not saved.names or not saved.itemStrings then
		Log.Err("Missing names / itemStrings")
		return false, false
	end
	local names = String.SafeSplit(LongString.Decode(saved.names), SEP_CHAR)
	local itemStrings = String.SafeSplit(LongString.Decode(saved.itemStrings), SEP_CHAR)
	if #names ~= #itemStrings then
		Log.Err("Mismatched names / itemStrings (%d, %d)", #names, #itemStrings)
		return false, false
	end

	local data = LongString.Decode(saved.data)
	if not ItemInfoSerializer.IsEncodedDataValue(data) then
		Log.Err("Encoded data is not valid")
		return false, false
	end

	-- The following code for loading data is highly optimized as we're processing a ton of data here
	local numItemsLoaded = #names
	local needsEncoding = false
	local prevSortName = nil
	for i = 1, numItemsLoaded do
		local itemString = itemStrings[i]
		-- Check the itemString
		if ItemString.Get(itemString) == itemString then
			-- Load all the fields from the data string
			local dataOffset = (i - 1) * RECORD_DATA_LENGTH_CHARS + 1
			local b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, bExtra = strbyte(data, dataOffset, dataOffset + RECORD_DATA_LENGTH_CHARS - 1)
			if not b23 or bExtra then
				error("Invalid data")
			end

			-- Load the fields
			local itemLevel = (b0 == ENCODED_NIL_CHAR and b1 == ENCODED_NIL_CHAR) and -1 or (DECODING_TABLE[b0] + DECODING_TABLE[b1] * 2 ^ ENCODING_NUM_BITS)
			local minLevel = (b2 == ENCODED_NIL_CHAR and b3 == ENCODED_NIL_CHAR) and -1 or (DECODING_TABLE[b2] + DECODING_TABLE[b3] * 2 ^ ENCODING_NUM_BITS)
			local vendorSell = nil
			if b4 == ENCODED_NIL_CHAR and b5 == ENCODED_NIL_CHAR and b6 == ENCODED_NIL_CHAR and b7 == ENCODED_NIL_CHAR and b8 == ENCODED_NIL_CHAR then
				vendorSell = -1
			else
				vendorSell = DECODING_TABLE[b4] + DECODING_TABLE[b5] * 2 ^ ENCODING_NUM_BITS + DECODING_TABLE[b6] * 2 ^ (ENCODING_NUM_BITS * 2) + DECODING_TABLE[b7] * 2 ^ (ENCODING_NUM_BITS * 3) + DECODING_TABLE[b8] * 2 ^ (ENCODING_NUM_BITS * 4)
			end
			local maxStack = (b9 == ENCODED_NIL_CHAR and b10 == ENCODED_NIL_CHAR) and -1 or (DECODING_TABLE[b9] + DECODING_TABLE[b10] * 2 ^ ENCODING_NUM_BITS)
			local invSlotId = DECODING_TABLE_1[b11]
			local texture = nil
			if b12 == ENCODED_NIL_CHAR and b13 == ENCODED_NIL_CHAR and b14 == ENCODED_NIL_CHAR and b15 == ENCODED_NIL_CHAR and b16 == ENCODED_NIL_CHAR then
				texture = -1
			else
				texture = DECODING_TABLE[b12] + DECODING_TABLE[b13] * 2 ^ ENCODING_NUM_BITS + DECODING_TABLE[b14] * 2 ^ (ENCODING_NUM_BITS * 2) + DECODING_TABLE[b15] * 2 ^ (ENCODING_NUM_BITS * 3) + DECODING_TABLE[b16] * 2 ^ (ENCODING_NUM_BITS * 4)
			end
			local classId = DECODING_TABLE_1[b17]
			local subClassId = DECODING_TABLE_1[b18]
			local quality = DECODING_TABLE_1[b19]
			local isBOP = DECODING_TABLE_1[b20]
			local isCraftingReagent = DECODING_TABLE_1[b21]
			local expansionId = DECODING_TABLE_1[b22]
			local craftedQuality = DECODING_TABLE_1[b23]

			-- Call the handler
			local name = names[i]
			handler(itemString, name, itemLevel, minLevel, maxStack, vendorSell, invSlotId, texture, classId, subClassId, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)

			-- Check if the names are not sorted
			local sortName = strlower(name)
			if prevSortName and sortName < prevSortName then
				needsEncoding = true
			end
			prevSortName = sortName
		else
			needsEncoding = true
		end
	end

	Log.Info("Imported %d items worth of data", #names)
	return true, needsEncoding
end

---Encodes data.
---@param rawData table The raw decoded data
---@param numRows number The number of rows
---@return table|string|nil
function ItemInfoSerializer.EncodeData(rawData, numRows)
	if private.encoder then
		-- Ensure the data is sorted by name
		local lowerNames = {}
		local sortedIndexes = {}
		for i = 1, numRows do
			local name = rawData[(i - 1) * RECORD_DATA_NUM_FIELDS + 2]
			tinsert(sortedIndexes, i)
			lowerNames[i] = strlower(name)
		end
		local sortedData = nil
		if Table.IsSorted(lowerNames) then
			sortedData = rawData
		else
			Table.SortWithValueLookup(sortedIndexes, lowerNames)
			sortedData = {}
			for i, oldIndex in ipairs(sortedIndexes) do
				for j = 1, RECORD_DATA_NUM_FIELDS do
					sortedData[(i - 1) * RECORD_DATA_NUM_FIELDS + j] = rawData[(oldIndex - 1) * RECORD_DATA_NUM_FIELDS + j]
				end
			end
			rawData = sortedData
		end
		return private.encoder:Serialize(sortedData)
	end

	local names = {}
	local itemStrings = {}
	local dataParts = {}
	local isSorted, prevSortName = true, nil
	for i = 1, numRows do
		local startOffset = (i - 1) * RECORD_DATA_NUM_FIELDS + 1
		local itemString, name, itemLevel, minLevel, maxStack, vendorSell, invSlotId, texture, classId, subClassId, quality, isBOP, isCraftingReagent, expansionId, craftedQuality = unpack(rawData, startOffset, startOffset + RECORD_DATA_NUM_FIELDS - 1)
		local b0, b1, b2, b3, b4, b5, b6, b7, b8, b9 = ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR
		local b10, b11, b12, b13, b14, b15, b16, b17, b18, b19 = ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR
		local b20, b21, b22, b23 = ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR, ENCODED_NIL_CHAR
		if itemLevel ~= -1 then
			local chars = ENCODING_TABLE_2[itemLevel]
			b0 = chars[1]
			b1 = chars[2]
		end
		if minLevel ~= -1 then
			local chars = ENCODING_TABLE_2[minLevel]
			b2 = chars[1]
			b3 = chars[2]
		end
		if vendorSell ~= -1 then
			local charValue0 = vendorSell % 2 ^ ENCODING_NUM_BITS
			vendorSell = (vendorSell - charValue0) / 2 ^ ENCODING_NUM_BITS
			local charValue1 = vendorSell % 2 ^ ENCODING_NUM_BITS
			vendorSell = (vendorSell - charValue1) / 2 ^ ENCODING_NUM_BITS
			local charValue2 = vendorSell % 2 ^ ENCODING_NUM_BITS
			vendorSell = (vendorSell - charValue2) / 2 ^ ENCODING_NUM_BITS
			local charValue3 = vendorSell % 2 ^ ENCODING_NUM_BITS
			vendorSell = (vendorSell - charValue3) / 2 ^ ENCODING_NUM_BITS
			local charValue4 = vendorSell % 2 ^ ENCODING_NUM_BITS
			vendorSell = (vendorSell - charValue4) / 2 ^ ENCODING_NUM_BITS
			if vendorSell ~= 0 then
				error("Invalid remainder")
			end
			b4 = ENCODING_TABLE[charValue0]
			b5 = ENCODING_TABLE[charValue1]
			b6 = ENCODING_TABLE[charValue2]
			b7 = ENCODING_TABLE[charValue3]
			b8 = ENCODING_TABLE[charValue4]
		end
		if maxStack ~= -1 then
			local chars = ENCODING_TABLE_2[maxStack]
			b9 = chars[1]
			b10 = chars[2]
		end
		if invSlotId ~= -1 then
			b11 = ENCODING_TABLE[invSlotId]
		end
		if texture ~= -1 then
			local charValue0 = texture % 2 ^ ENCODING_NUM_BITS
			texture = (texture - charValue0) / 2 ^ ENCODING_NUM_BITS
			local charValue1 = texture % 2 ^ ENCODING_NUM_BITS
			texture = (texture - charValue1) / 2 ^ ENCODING_NUM_BITS
			local charValue2 = texture % 2 ^ ENCODING_NUM_BITS
			texture = (texture - charValue2) / 2 ^ ENCODING_NUM_BITS
			local charValue3 = texture % 2 ^ ENCODING_NUM_BITS
			texture = (texture - charValue3) / 2 ^ ENCODING_NUM_BITS
			local charValue4 = texture % 2 ^ ENCODING_NUM_BITS
			texture = (texture - charValue4) / 2 ^ ENCODING_NUM_BITS
			if texture ~= 0 then
				error("Invalid remainder")
			end
			b12 = ENCODING_TABLE[charValue0]
			b13 = ENCODING_TABLE[charValue1]
			b14 = ENCODING_TABLE[charValue2]
			b15 = ENCODING_TABLE[charValue3]
			b16 = ENCODING_TABLE[charValue4]
		end
		if classId ~= -1 then
			b17 = ENCODING_TABLE[classId]
		end
		if subClassId ~= -1 then
			b18 = ENCODING_TABLE[subClassId]
		end
		if quality ~= -1 then
			b19 = ENCODING_TABLE[quality]
		end
		if isBOP ~= -1 then
			b20 = ENCODING_TABLE[isBOP]
		end
		if isCraftingReagent ~= -1 then
			b21 = ENCODING_TABLE[isCraftingReagent]
		end
		if expansionId ~= -1 then
			b22 = ENCODING_TABLE[expansionId]
		end
		if craftedQuality ~= -1 then
			b23 = ENCODING_TABLE[craftedQuality]
		end

		local sortName = strlower(name)
		if prevSortName and sortName < prevSortName then
			isSorted = false
		end
		prevSortName = sortName
		names[i] = name
		itemStrings[i] = itemString
		dataParts[i] = strchar(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23)

		if #dataParts[i] ~= RECORD_DATA_LENGTH_CHARS then
			names[i] = nil
			itemStrings[i] = nil
			dataParts[i] = nil
		end
	end


	-- We'll sort our data on save to make filtering it a bit more efficient
	if not isSorted then
		local lowerNames = {}
		local sortedIndexes = {}
		for i = 1, #names do
			if names[i] ~= nil then
				tinsert(sortedIndexes, i)
				lowerNames[i] = strlower(names[i])
			end
		end
		Table.SortWithValueLookup(sortedIndexes, lowerNames)
		local sortedNames = {}
		local sortedItemStrings = {}
		local sortedDataParts = {}
		for i, oldIndex in ipairs(sortedIndexes) do
			sortedNames[i] = names[oldIndex]
			sortedItemStrings[i] = itemStrings[oldIndex]
			sortedDataParts[i] = dataParts[oldIndex]
		end
		names = sortedNames
		itemStrings = sortedItemStrings
		dataParts = sortedDataParts
	end

	local data = table.concat(dataParts)
	if not ItemInfoSerializer.IsEncodedDataValue(data) then
		return nil
	end

	return {
		names = #names > 0 and LongString.Encode(table.concat(names, SEP_CHAR)) or nil,
		itemStrings = #itemStrings > 0 and LongString.Encode(table.concat(itemStrings, SEP_CHAR)) or nil,
		data = LongString.Encode(data)
	}
end

---Asserts that a value is valid for the specified field.
---@param key string They key of the field
---@param value number The value
function ItemInfoSerializer.CheckFieldValue(key, value)
	if value == -1 then
		return
	end
	assert(value >= 0 and value <= FIELD_INFO[key].maxValue)
end

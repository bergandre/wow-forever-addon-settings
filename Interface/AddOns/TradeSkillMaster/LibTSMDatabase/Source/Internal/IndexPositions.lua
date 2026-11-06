-- ------------------------------------------------------------------------------ --
--                                 LibTSMDatabase                                 --
--               https://github.com/TradeSkillMaster/LibTSMDatabase               --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMDatabase = select(2, ...).LibTSMDatabase
local DatabaseIndexPositions = LibTSMDatabase:DefineInternalClassType("DatabaseIndexPositions")
local Table = LibTSMDatabase:From("LibTSMUtil"):Include("Lua.Table")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new set of index list position ranges.
---@return DatabaseIndexPositions
function DatabaseIndexPositions.__static.New()
	return DatabaseIndexPositions()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DatabaseIndexPositions.__private:__init()
	self._numRanges = 0
	self._firstIndex = {} ---@type table<number,number>
	self._lastIndex = {} ---@type table<number,number>
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the number of ranges.
---@return number
function DatabaseIndexPositions:GetNumRanges()
	return self._numRanges
end

---Wipes the ranges.
function DatabaseIndexPositions:Wipe()
	Table.WipeAndDeallocate(self._firstIndex)
	Table.WipeAndDeallocate(self._lastIndex)
	self._numRanges = 0
end

---Adds a range of positions within the index list.
---@param firstIndex number The first position (inclusive)
---@param lastIndex number The last position (inclusive)
function DatabaseIndexPositions:AddRange(firstIndex, lastIndex)
	assert(lastIndex >= firstIndex)
	self._numRanges = self._numRanges + 1
	local index = self._numRanges
	self._firstIndex[index] = firstIndex
	self._lastIndex[index] = lastIndex
end

---Removes all ranges which were added since the specified number of ranges.
---@param numRanges number The previous number of ranges
function DatabaseIndexPositions:TruncateTo(numRanges)
	for i = self._numRanges, numRanges + 1, -1 do
		self._firstIndex[i] = nil
		self._lastIndex[i] = nil
	end
	self._numRanges = numRanges
end

---Replaces the ranges with those of another set.
---@param positions DatabaseIndexPositions The set to copy from
function DatabaseIndexPositions:CopyFrom(positions)
	self:Wipe()
	for i = 1, positions._numRanges do
		self:AddRange(positions._firstIndex[i], positions._lastIndex[i])
	end
end

---Sorts the ranges and merges any which overlap or are adjacent.
function DatabaseIndexPositions:SortAndMerge()
	if self._numRanges <= 1 then
		return
	end
	-- Insertion sort the ranges by their first position
	for i = 2, self._numRanges do
		local firstIndex, lastIndex = self._firstIndex[i], self._lastIndex[i]
		local j = i - 1
		while j >= 1 and self._firstIndex[j] > firstIndex do
			self._firstIndex[j + 1] = self._firstIndex[j]
			self._lastIndex[j + 1] = self._lastIndex[j]
			j = j - 1
		end
		self._firstIndex[j + 1] = firstIndex
		self._lastIndex[j + 1] = lastIndex
	end
	-- Merge each range into the previous one where they overlap or are adjacent
	local numRanges = 1
	for i = 2, self._numRanges do
		if self._firstIndex[i] <= self._lastIndex[numRanges] + 1 then
			if self._lastIndex[i] > self._lastIndex[numRanges] then
				self._lastIndex[numRanges] = self._lastIndex[i]
			end
		else
			numRanges = numRanges + 1
			self._firstIndex[numRanges] = self._firstIndex[i]
			self._lastIndex[numRanges] = self._lastIndex[i]
		end
	end
	self:TruncateTo(numRanges)
end

---Gets the total number of positions spanned by all the ranges.
---@return number
function DatabaseIndexPositions:GetNumPositions()
	local numPositions = 0
	for i = 1, self._numRanges do
		numPositions = numPositions + self._lastIndex[i] - self._firstIndex[i]
	end
	return numPositions
end

---Gets the specified range.
---@param index number The range index
---@return number firstIndex
---@return number lastIndex
function DatabaseIndexPositions:GetRange(index)
	assert(index <= self._numRanges)
	return self._firstIndex[index], self._lastIndex[index]
end

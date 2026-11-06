-- ------------------------------------------------------------------------------ --
--                                 LibTSMDatabase                                 --
--               https://github.com/TradeSkillMaster/LibTSMDatabase               --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMDatabase = select(2, ...).LibTSMDatabase
local DatabaseIndexRanges = LibTSMDatabase:DefineInternalClassType("DatabaseIndexRanges")
local Table = LibTSMDatabase:From("LibTSMUtil"):Include("Lua.Table")
local private = {}

---@class DatabaseIndexRanges<T>



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new set of index ranges.
---@return DatabaseIndexRanges
function DatabaseIndexRanges.__static.New()
	return DatabaseIndexRanges()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DatabaseIndexRanges.__private:__init()
	self._numRanges = 0
	self._lowerBound = {} ---@type table<number,T>
	self._upperBound = {} ---@type table<number,T>
	self._lowerIsExclusive = {} ---@type table<number,boolean>
	self._upperIsExclusive = {} ---@type table<number,boolean>
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the number of ranges.
---@return number
function DatabaseIndexRanges:GetNumRanges()
	return self._numRanges
end

---Wipes the index ranges object.
function DatabaseIndexRanges:Wipe()
	Table.WipeAndDeallocate(self._lowerBound)
	Table.WipeAndDeallocate(self._upperBound)
	Table.WipeAndDeallocate(self._lowerIsExclusive)
	Table.WipeAndDeallocate(self._upperIsExclusive)
	self._numRanges = 0
end

---Adds a range, where a nil bound is unbounded in that direction.
---@param lowerBound? T The lower bound
---@param upperBound? T The upper bound
---@param isLowerExclusive boolean Whether the lower bound excludes the value itself
---@param isUpperExclusive boolean Whether the upper bound excludes the value itself
function DatabaseIndexRanges:AddBound(lowerBound, upperBound, isLowerExclusive, isUpperExclusive)
	assert(lowerBound ~= nil or upperBound ~= nil)
	self._numRanges = self._numRanges + 1
	local index = self._numRanges
	self._lowerBound[index] = lowerBound
	self._lowerIsExclusive[index] = isLowerExclusive
	self._upperBound[index] = upperBound
	self._upperIsExclusive[index] = isUpperExclusive
end

---Removes all ranges which were added since the specified number of ranges.
---@param numRanges number The previous number of ranges
function DatabaseIndexRanges:TruncateTo(numRanges)
	for i = self._numRanges, numRanges + 1, -1 do
		self._lowerBound[i] = nil
		self._upperBound[i] = nil
		self._lowerIsExclusive[i] = nil
		self._upperIsExclusive[i] = nil
	end
	self._numRanges = numRanges
end

---Replaces the ranges after the start marker with the intersection of those on either side of the split marker.
---@param startMark number The number of ranges to leave untouched
---@param splitMark number The number of ranges before the second set being intersected
function DatabaseIndexRanges:IntersectFrom(startMark, splitMark)
	-- Append the intersection so the ranges it's built from can be read while doing so
	local numRanges = self._numRanges
	for i = startMark + 1, splitMark do
		for j = splitMark + 1, numRanges do
			local lowerBound, isLowerExclusive = self:_IntersectLowerBounds(i, j)
			local upperBound, isUpperExclusive = self:_IntersectUpperBounds(i, j)
			if private.IsNonEmpty(lowerBound, upperBound, isLowerExclusive, isUpperExclusive) then
				self:AddBound(lowerBound, upperBound, isLowerExclusive, isUpperExclusive)
			end
		end
	end
	-- Move the intersection down over those ranges
	local numResults = self._numRanges - numRanges
	for i = 1, numResults do
		local srcIndex = numRanges + i
		local dstIndex = startMark + i
		self._lowerBound[dstIndex] = self._lowerBound[srcIndex]
		self._lowerIsExclusive[dstIndex] = self._lowerIsExclusive[srcIndex]
		self._upperBound[dstIndex] = self._upperBound[srcIndex]
		self._upperIsExclusive[dstIndex] = self._upperIsExclusive[srcIndex]
	end
	self:TruncateTo(startMark + numResults)
end

---Iterates over the ranges, where a nil bound is unbounded in that direction.
---@return fun(): number, T?, T?, boolean, boolean @Iterator with fields: `index`, `lowerBound`, `upperBound`, `isLowerExclusive`, `isUpperExclusive`
---@return self
---@return number
function DatabaseIndexRanges:Iterator()
	return private.RangeIterator, self, 0
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DatabaseIndexRanges.__private:_IntersectLowerBounds(i, j)
	local a, aIsExclusive = self._lowerBound[i], self._lowerIsExclusive[i]
	local b, bIsExclusive = self._lowerBound[j], self._lowerIsExclusive[j]
	if a == nil then
		return b, bIsExclusive
	elseif b == nil then
		return a, aIsExclusive
	elseif a > b then
		return a, aIsExclusive
	elseif b > a then
		return b, bIsExclusive
	else
		return a, aIsExclusive or bIsExclusive
	end
end

function DatabaseIndexRanges.__private:_IntersectUpperBounds(i, j)
	local a, aIsExclusive = self._upperBound[i], self._upperIsExclusive[i]
	local b, bIsExclusive = self._upperBound[j], self._upperIsExclusive[j]
	if a == nil then
		return b, bIsExclusive
	elseif b == nil then
		return a, aIsExclusive
	elseif a < b then
		return a, aIsExclusive
	elseif b < a then
		return b, bIsExclusive
	else
		return a, aIsExclusive or bIsExclusive
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RangeIterator(self, index)
	index = index + 1
	if index > self._numRanges then
		return
	end
	return index, self._lowerBound[index], self._upperBound[index], self._lowerIsExclusive[index], self._upperIsExclusive[index]
end

function private.IsNonEmpty(lowerBound, upperBound, isLowerExclusive, isUpperExclusive)
	if lowerBound == nil or upperBound == nil then
		return true
	elseif lowerBound < upperBound then
		return true
	elseif lowerBound > upperBound then
		return false
	end
	return not isLowerExclusive and not isUpperExclusive
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local QualitySolver = LibTSMService:DefineInternalClassType("QualitySolver")
local OptionalMatData = LibTSMService:From("LibTSMData"):Include("OptionalMat")
local OrderedTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.OrderedTable")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

function QualitySolver.__static.Create()
	return QualitySolver()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function QualitySolver.__private:__init()
	self._acquired = false
	self._mixedQualityThreshold = nil
	self._totalWeight = nil
	self._minAddedWeight = nil
	self._maxAddedWeight = nil
	self._qualityMats = {} ---@type OrderedTable.Table<string,number>
	self._matCost = {}
	self._matWeight = {}
	self._matNumQualities = {}
	self._optionCost = {}
	self._optionNonMixedCost = {}
	self._optionUniqueMats = {}
	self._weightMultiples = {}
	self._nonMixedWeightMultiples = {}
	self._solution = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Acquires the solver (returns false if some mat prices are missing).
---@param mats table<string,number> the materials for the current recipe
---@param neededSkill number The minimum amount of skill needed from quality mats
---@param maxAddedSkill number The maximum amount of skill which can be added by quality mats
---@param maxQualityMatSkill number The max skill which can be added to the recipe by quality mats
---@param mixedQualityThreshold number The threshold for using mixed quality materials as a percent
---@return boolean
function QualitySolver:Acquire(mats, neededSkill, maxAddedSkill, maxQualityMatSkill, mixedQualityThreshold)
	assert(not self._acquired)
	self._acquired = true
	self._mixedQualityThreshold = mixedQualityThreshold
	local totalWeight = 0
	for matString, quantity in pairs(mats) do
		if MatString.GetType(matString) == MatString.TYPE.QUALITY then
			OrderedTable.Insert(self._qualityMats, matString, quantity)
			local numQualities = MatString.GetNumQualities(matString)
			self._matNumQualities[matString] = numQualities
			local itemStringQ1 = MatString.GetQualityItem(matString, 1)
			local itemStringQ2 = MatString.GetQualityItem(matString, 2)
			local matCostQ1 = CustomString.GetSourceValue("MatPrice", itemStringQ1)
			local matCostQ2 = CustomString.GetSourceValue("MatPrice", itemStringQ2)
			if not matCostQ1 or not matCostQ2 then
				self:Release()
				return false
			end
			self._matCost[itemStringQ1] = matCostQ1
			self._matCost[itemStringQ2] = matCostQ2
			if numQualities >= 3 then
				local itemStringQ3 = MatString.GetQualityItem(matString, 3)
				local matCostQ3 = CustomString.GetSourceValue("MatPrice", itemStringQ3)
				if not matCostQ3 then
					self:Release()
					return false
				end
				self._matCost[itemStringQ3] = matCostQ3
			end
			local matWeight = OptionalMatData.QualityWeight[itemStringQ1]
			self._matWeight[matString] = matWeight
			totalWeight = totalWeight + matWeight * quantity
		end
	end
	-- Sort by quantity in increasing order
	OrderedTable.SortByValues(self._qualityMats)
	assert(#self._qualityMats > 0)
	self._totalWeight = totalWeight
	self._minAddedWeight = totalWeight * neededSkill / maxQualityMatSkill
	self._maxAddedWeight = totalWeight * maxAddedSkill / maxQualityMatSkill
	return true
end

function QualitySolver:Release()
	assert(self._acquired)
	self._totalWeight = nil
	self._minAddedWeight = nil
	self._maxAddedWeight = nil
	wipe(self._qualityMats)
	wipe(self._matWeight)
	wipe(self._matNumQualities)
	wipe(self._optionCost)
	wipe(self._optionNonMixedCost)
	wipe(self._optionUniqueMats)
	wipe(self._weightMultiples)
	wipe(self._nonMixedWeightMultiples)
	wipe(self._solution)
	self._acquired = false
end

---Runs the solver and returns whether or not a solution was found.
---@return boolean
function QualitySolver:Solve()
	self:_CalculateMatOptions()
	local optimalCost = self:_FindOptimalWeightMultiples(self._optionCost, self._weightMultiples)
	if not optimalCost then
		return false
	end
	local optimalNonMixedCost = self:_FindOptimalWeightMultiples(self._optionNonMixedCost, self._nonMixedWeightMultiples)
	assert(not optimalNonMixedCost or optimalNonMixedCost >= optimalCost)
	local mixedSavingsPct = optimalNonMixedCost and (optimalNonMixedCost - optimalCost) * 100 / optimalNonMixedCost or math.huge
	local useMixedMats = mixedSavingsPct >= self._mixedQualityThreshold
	self:_PopulateSolution(useMixedMats and self._weightMultiples or self._nonMixedWeightMultiples, useMixedMats)
	return true
end

---Iterates over the solution.
---@return fun(): string, string @Iterator with fields: `matString`, `qualityMatString`
---@return table
function QualitySolver:SolutionIterator()
	assert(next(self._solution))
	return pairs(self._solution)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function QualitySolver.__private:_CalculateMatOptions()
	assert(not next(self._optionCost))
	for index, matString, matQuantity in OrderedTable.Iterator(self._qualityMats) do
		local optionOffset = self:_GetMatOptionOffset(index)
		local weightStep = self._matNumQualities[matString] == 2 and 2 or 1
		for weightMultiple = 0, matQuantity * 2, weightStep do
			local cost, numQ2, numQ3, nonMixedCost = self:_OptimizeMat(matString, weightMultiple)
			local numQ1 = matQuantity - numQ2 - numQ3
			local optionIndex = optionOffset + weightMultiple
			self._optionCost[optionIndex] = cost
			self._optionNonMixedCost[optionIndex] = nonMixedCost
			self._optionUniqueMats[optionIndex] = (numQ1 > 0 and 1 or 0) + (numQ2 > 0 and 1 or 0) + (numQ3 > 0 and 1 or 0)
		end
	end
end

function QualitySolver.__private:_GetMatOptionOffset(index)
	local _, maxQuantity = OrderedTable.GetByIndex(self._qualityMats, #self._qualityMats)
	return (index - 1) * (maxQuantity * 2 + 1)
end

function QualitySolver.__private:_GetMaxWeight(throughIndex)
	local weight = 0
	for i, matString, matQuantity in OrderedTable.Iterator(self._qualityMats) do
		if i > throughIndex then
			break
		end
		weight = weight + self._matWeight[matString] * matQuantity
	end
	return weight
end

function QualitySolver.__private:_FindOptimalWeightMultiples(optionCost, weightMultiples)
	local optionUniqueMats = self._optionUniqueMats
	local totalWeight, minAddedWeight, maxAddedWeight = self._totalWeight, self._minAddedWeight, self._maxAddedWeight
	assert(totalWeight and minAddedWeight and maxAddedWeight)
	local minHalfWeight = minAddedWeight * 2
	local maxHalfWeight = floor(min(maxAddedWeight, totalWeight) * 2)
	local numHalfWeights = maxHalfWeight + 1
	local costs = TempTable.Acquire()
	local uniqueMats = TempTable.Acquire()
	local nextCosts = TempTable.Acquire()
	local nextUniqueMats = TempTable.Acquire()
	local choices = TempTable.Acquire()
	costs[0] = 0
	uniqueMats[0] = 0
	for index = #self._qualityMats, 1, -1 do
		local matString, matQuantity = OrderedTable.GetByIndex(self._qualityMats, index)
		local matWeight = self._matWeight[matString]
		local minHalfWeightWithMat = minHalfWeight - self:_GetMaxWeight(index - 1) * 2
		local optionOffset = self:_GetMatOptionOffset(index)
		local choiceOffset = (index - 1) * numHalfWeights
		for halfWeight = 0, maxHalfWeight do
			local cost = costs[halfWeight]
			if cost then
				local minWeightMultiple = max(ceil((minHalfWeightWithMat - halfWeight) / matWeight), 0)
				local maxWeightMultiple = min(floor((maxHalfWeight - halfWeight) / matWeight), matQuantity * 2)
				for weightMultiple = minWeightMultiple, maxWeightMultiple do
					local optionIndex = optionOffset + weightMultiple
					local matCost = optionCost[optionIndex]
					if matCost then
						local nextHalfWeight = halfWeight + weightMultiple * matWeight
						local nextCost = cost + matCost
						local nextNumUniqueMats = uniqueMats[halfWeight] + optionUniqueMats[optionIndex]
						local prevCost = nextCosts[nextHalfWeight]
						-- Order first by cost and second by the number of unique mats
						if not prevCost or nextCost < prevCost or (nextCost == prevCost and nextNumUniqueMats < nextUniqueMats[nextHalfWeight]) then
							nextCosts[nextHalfWeight] = nextCost
							nextUniqueMats[nextHalfWeight] = nextNumUniqueMats
							choices[choiceOffset + nextHalfWeight] = weightMultiple
						end
					end
				end
			end
		end
		costs, nextCosts = nextCosts, costs
		uniqueMats, nextUniqueMats = nextUniqueMats, uniqueMats
		wipe(nextCosts)
		wipe(nextUniqueMats)
	end
	local optimalHalfWeight, optimalCost, optimalUniqueMats = nil, nil, nil
	for halfWeight = 0, maxHalfWeight do
		local cost = costs[halfWeight]
		if cost and (not optimalCost or cost < optimalCost or (cost == optimalCost and uniqueMats[halfWeight] < optimalUniqueMats)) then
			optimalHalfWeight = halfWeight
			optimalCost = cost
			optimalUniqueMats = uniqueMats[halfWeight]
		end
	end
	if optimalHalfWeight then
		local halfWeight = optimalHalfWeight
		for index, matString in OrderedTable.Iterator(self._qualityMats) do
			local weightMultiple = choices[(index - 1) * numHalfWeights + halfWeight]
			weightMultiples[matString] = weightMultiple
			halfWeight = halfWeight - weightMultiple * self._matWeight[matString]
		end
	end
	TempTable.Release(costs)
	TempTable.Release(uniqueMats)
	TempTable.Release(nextCosts)
	TempTable.Release(nextUniqueMats)
	TempTable.Release(choices)
	return optimalCost
end

function QualitySolver.__private:_PopulateSolution(weightMultiples, useMixedMats)
	assert(not next(self._solution))
	local matsTemp = TempTable.Acquire()
	for _, matString, matQuantity in OrderedTable.Iterator(self._qualityMats) do
		local _, numQ2, numQ3, _, nonMixedQuality = self:_OptimizeMat(matString, weightMultiples[matString])
		local numQ1 = matQuantity - numQ2 - numQ3
		-- FIXME: Can this be simplified?
		if useMixedMats then
			assert(not next(matsTemp))
			if numQ1 > 0 then
				matsTemp[MatString.GetQualityItem(matString, 1)] = numQ1
			end
			if numQ2 > 0 then
				matsTemp[MatString.GetQualityItem(matString, 2)] = numQ2
			end
			if numQ3 > 0 then
				matsTemp[MatString.GetQualityItem(matString, 3)] = numQ3
			end
			self._solution[matString] = MatQuantityString.Get(matsTemp)
			wipe(matsTemp)
		else
			assert(nonMixedQuality)
			self._solution[matString] = MatQuantityString.GetForSingleItem(MatString.GetQualityItem(matString, nonMixedQuality), matQuantity)
		end
	end
	TempTable.Release(matsTemp)
end

function QualitySolver.__private:_OptimizeMat(matString, weightMultiple)
	local matQuantity = self._qualityMats[matString]
	local numQualities = self._matNumQualities[matString]
	local itemStringQ1 = MatString.GetQualityItem(matString, 1)
	local itemStringQ2 = MatString.GetQualityItem(matString, 2)
	local costQ1 = self._matCost[itemStringQ1]
	local costQ2 = self._matCost[itemStringQ2]
	local optimalCost, optimalNumQ2, optimalNumQ3 = nil, nil, nil
	local optimalNonMixedCost, optimalNonMixedQuality = nil, nil
	if numQualities == 2 then
		local numQ2 = weightMultiple / 2
		local numQ1 = matQuantity - numQ2
		optimalCost = numQ1 * costQ1 + numQ2 * costQ2
		optimalNumQ2 = numQ2
		optimalNumQ3 = 0
		if numQ1 == 0 or numQ2 == 0 then
			optimalNonMixedCost = optimalCost
			optimalNonMixedQuality = numQ1 > 0 and 1 or 2
		end
	else
		local costQ3 = self._matCost[MatString.GetQualityItem(matString, 3)]
		for numQ3 = 0, floor(weightMultiple / 2) do
			local numQ2 = weightMultiple - numQ3 * 2
			local numQ1 = matQuantity - numQ3 - numQ2
			if numQ1 >= 0 then
				local cost = numQ1 * costQ1 + numQ2 * costQ2 + numQ3 * costQ3
				if not optimalCost or cost < optimalCost then
					optimalCost = cost
					optimalNumQ2 = numQ2
					optimalNumQ3 = numQ3
				end
				local isMixed = ((numQ1 > 0 and 1 or 0) + (numQ2 > 0 and 1 or 0) + (numQ3 > 0 and 1 or 0)) > 1
				if not isMixed and (not optimalNonMixedCost or cost < optimalNonMixedCost) then
					optimalNonMixedCost = cost
					optimalNonMixedQuality = (numQ1 > 0 and 1) or (numQ2 > 0 and 2) or (numQ3 > 0 and 3)
				end
			end
		end
	end
	assert(optimalCost and optimalNumQ2 and optimalNumQ3 and (not optimalNonMixedCost or optimalNonMixedQuality))
	return optimalCost, optimalNumQ2, optimalNumQ3, optimalNonMixedCost, optimalNonMixedQuality
end

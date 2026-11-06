-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Quality = LibTSMService:InitInternal("Crafting.Quality")
local Profession = LibTSMService:Include("Profession")
local ProfessionQuality = LibTSMService:Include("Profession.Quality")
local QualitySolver = LibTSMService:IncludeClassType("QualitySolver")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local Conversion = LibTSMService:From("LibTSMTypes"):Include("Item.Conversion")
local private = {
	solvers = {}, ---@type QualitySolver[]
	craftSettingsTable = nil,
	mixedQualityThreshold = nil,
}
local DRAGON_ISLES_SALVAGE_CRAFTSTRINGS = {
	[Conversion.METHOD.MILL] = "c:382981",
	[Conversion.METHOD.PROSPECT] = "c:374627",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the craft info settings table.
---@param crafts table<string,CraftInfo?> The craft info settings table
---@param mixedQualityThreshold number The threshold for using mixed quality mats
function Quality.Load(crafts, mixedQualityThreshold)
	private.craftSettingsTable = crafts
	private.mixedQualityThreshold = mixedQualityThreshold
end

---Returns whether or not a craft is a quality craft.
---@param craftString string The craft string
---@return boolean
function Quality.IsQualityCraft(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		return false
	elseif CraftString.GetQuality(craftString) then
		return true
	else
		return Quality.GetInfo(craftString) and true or false
	end
end

---Gets the quality info for a given craft.
---@param craftString string The craft string
---@param character? string The character to get the info for (return the highest base quality if not specified)
---@return (number baseRecipeDifficulty, number baseRecipeQuality, number maxRecipeQuality)|(nil, nil, nil)
function Quality.GetInfo(craftString, character)
	local craftInfo = private.craftSettingsTable[craftString]
	if not craftInfo or (not LibTSMService.IsRetail() and not LibTSMService.IsForever()) then
		return nil, nil, nil
	end
	local baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality = nil, nil, nil
	if character then
		local info = craftInfo.players[character]
		if type(info) == "table" and info.baseRecipeQuality then
			baseRecipeDifficulty = info.baseRecipeDifficulty
			baseRecipeQuality = info.baseRecipeQuality
			maxRecipeQuality = info.maxRecipeQuality
		end
	else
		for _, info in pairs(craftInfo.players) do
			if type(info) == "table" and info.baseRecipeQuality and (not baseRecipeQuality or info.baseRecipeQuality > baseRecipeQuality) then
				baseRecipeDifficulty = info.baseRecipeDifficulty
				baseRecipeQuality = info.baseRecipeQuality
				maxRecipeQuality = info.maxRecipeQuality
			end
		end
	end
	if not baseRecipeDifficulty or maxRecipeQuality == 1 then
		return nil, nil, nil
	end
	return baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality
end

---Gets the quality mats for a given craft, which are the cheapest ones if the craft has no result quality.
---@param craftString string The craft string
---@param mats table<string,number> The base materials being used
---@param qualityMats table<string,string> The resulting quality mats (key is the matQuantityString, value is the matString)
---@return boolean canCraft
---@return number? concentration
function Quality.GetMats(craftString, mats, qualityMats)
	if not Quality.IsQualityCraft(craftString) then
		return private.GetCheapestMats(mats, qualityMats), nil
	end
	local recipeDifficulty, recipeQuality, recipeMaxQuality = Quality.GetInfo(craftString)
	if not recipeDifficulty or not recipeQuality or not recipeMaxQuality then
		return false, nil
	end
	local hasQualityMats = false
	for _ in private.QualityMatIterator(mats) do
		hasQualityMats = true
		break
	end
	local targetQuality = CraftString.GetQuality(craftString)
	if not targetQuality then
		return false, nil
	end
	local rootCategoryId = private.GetRootCategoryId(craftString)
	if not rootCategoryId then
		return false, nil
	end
	local maxMatContribution = ProfessionQuality.GetMaxMatContribution(rootCategoryId)
	local neededSkill, maxAddedSkill, maxQualityMatSkill, concentration = Profession.GetNeededSkill(targetQuality, recipeDifficulty, recipeQuality, recipeMaxQuality, hasQualityMats, maxMatContribution)
	if not neededSkill then
		return false, nil
	end

	-- Handle crafts with no quality mats
	if not hasQualityMats then
		return neededSkill == 0, concentration
	end

	-- Run the solver
	local solver = private.AcquireSolver(mats, neededSkill, maxAddedSkill, maxQualityMatSkill)
	if not solver then
		return false, nil
	end
	if not solver:Solve() then
		private.ReleaseSolver(solver)
		return false, nil
	end
	for matString, matQuantityString in solver:SolutionIterator() do
		qualityMats[matQuantityString] = matString
	end
	private.ReleaseSolver(solver)
	return true, concentration
end

---Gets the expected salvage result quality.
---@param method EnumValue The salvage method
---@param sourceQuality number The source item quality
---@return number
function Quality.GetExpectedSalvageResult(method, sourceQuality)
	local craftString = DRAGON_ISLES_SALVAGE_CRAFTSTRINGS[method]
	assert(craftString)
	local baseRecipeDifficulty, baseRecipeQuality = Quality.GetInfo(craftString)
	-- Show quality 1 results when Dragon Isles Milling/Prospecting is not learned
	if not baseRecipeDifficulty or not baseRecipeQuality then
		return 1
	end

	local quality = 1
	local rootCategoryId = private.GetRootCategoryId(craftString)
	if not rootCategoryId then
		return 1
	end
	local matContribution = ProfessionQuality.GetMatContributionForQuality(rootCategoryId, sourceQuality)
	local sourceMatSkill = baseRecipeDifficulty * matContribution
	for i = 2, 3 do
		local neededSkill, _, _, concentration = Profession.GetNeededSkill(i, baseRecipeDifficulty, baseRecipeQuality, 3, true, matContribution)
		-- TODO: Handle concentration
		if concentration == 0 and neededSkill and neededSkill >= sourceMatSkill then
			quality = i
		end
	end
	return quality
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetRootCategoryId(craftString)
	local craftInfo = private.craftSettingsTable[craftString]
	return craftInfo and craftInfo.rootCategoryId or nil
end

function private.QualityMatIterator(mats)
	return private.QualityMatIteratorHelper, mats, nil
end

function private.QualityMatIteratorHelper(mats, matString)
	while true do
		matString = next(mats, matString)
		if not matString then
			return
		end
		if MatString.GetType(matString) == MatString.TYPE.QUALITY then
			return matString
		end
	end
end

function private.GetCheapestMats(mats, qualityMats)
	for matString in private.QualityMatIterator(mats) do
		local cheapestItemString, cheapestCost = nil, nil
		for itemString in MatString.ItemIterator(matString) do
			local cost = CustomString.GetSourceValue("MatPrice", itemString)
			if cost and (not cheapestCost or cost < cheapestCost) then
				cheapestItemString = itemString
				cheapestCost = cost
			end
		end
		if not cheapestItemString then
			return false
		end
		qualityMats[MatQuantityString.GetForSingleItem(cheapestItemString, mats[matString])] = matString
	end
	return true
end

function private.AcquireSolver(mats, neededSkill, maxAddedSkill, maxQualityMatSkill)
	assert(private.mixedQualityThreshold)
	local solver = tremove(private.solvers) --[[@as QualitySolver?]] or QualitySolver.Create()
	if not solver:Acquire(mats, neededSkill, maxAddedSkill, maxQualityMatSkill, private.mixedQualityThreshold) then
		tinsert(private.solvers, solver)
		return nil
	end
	return solver
end

function private.ReleaseSolver(solver)
	solver:Release()
	tinsert(private.solvers, solver)
end

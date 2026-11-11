-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Quality = LibTSMService:InitInternal("Profession.Quality")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local DF_MAX_QUALITY_MAT_DIFFICULTY_RATIO = 0.25
local MIDNIGHT_TWW_MAX_QUALITY_MAT_DIFFICULTY_RATIO = 0.4
local SKILL_PRECISION = 0.01
local SKILL_PER_TARGET_QUALITY = {
	[2] = {
		0,
		1.0,
	},
	[3] = {
		0,
		0.5,
		1.0,
	},
	[5] = {
		0,
		0.2,
		0.5,
		0.8,
		1.0,
	},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns the maximum material contribution value for a given recipe based on expansion.
---@param rootCategoryId number The root category ID
---@return number
function Quality.GetMaxMatContribution(rootCategoryId)
	local dragonFlightRecipe = rootCategoryId <= 1897
	return dragonFlightRecipe and DF_MAX_QUALITY_MAT_DIFFICULTY_RATIO or MIDNIGHT_TWW_MAX_QUALITY_MAT_DIFFICULTY_RATIO
end

---Returns the material contribution value for a given recipe based on the quality and expansion.
---@param rootCategoryId number The root category ID
---@param sourceQuality number The quality of the material
---@return number
function Quality.GetMatContributionForQuality(rootCategoryId, sourceQuality)
	if not rootCategoryId or sourceQuality == 1 then
		return 0
	end
	local maxMatContribution = Quality.GetMaxMatContribution(rootCategoryId)
	return sourceQuality == 3 and maxMatContribution or maxMatContribution / 2
end

---Gets the needed skill to craft a specific quality of a recipe.
---@param targetQuality number The target quality
---@param recipeDifficulty number The base recipe difficulty
---@param recipeQuality number The base recipe quality
---@param recipeMaxQuality number The max number of qualities for the recipe
---@param hasQualityMats boolean Whether or not the recipe has quality mats
---@param maxMatContribution number The max material contribution
---@param usingConcentration? boolean Whether or not concentration is being used
---@return (number neededSkill, number maxAddedSkill, number maxQualityMatSkill, number concentration)|(nil, nil, nil, nil)
function Quality.GetNeededSkill(targetQuality, recipeDifficulty, recipeQuality, recipeMaxQuality, hasQualityMats, maxMatContribution, usingConcentration)
	if recipeMaxQuality == 1 then
		-- This recipe has quality mats, but doesn't produce a quality item
		return 0, math.huge, 0, 0
	end
	-- Calculate how much skill we need to add in order to craft the target item
	local neededSkill, maxAddedSkill = 0, 0
	local minQuality = floor(recipeQuality)
	local skillPerTargetQuality = SKILL_PER_TARGET_QUALITY[recipeMaxQuality]
	if targetQuality < minQuality then
		-- We can't craft this low of a quality anymore
		return nil, nil, nil, nil
	end

	local currentLowerBound = skillPerTargetQuality[minQuality] * recipeDifficulty
	local currentUpperBound = skillPerTargetQuality[min(minQuality + 1, recipeMaxQuality)] * recipeDifficulty
	local currentQualityRatio = recipeQuality - minQuality
	local currentSkill = currentLowerBound + currentQualityRatio * (currentUpperBound - currentLowerBound)
	local targetLowerBound = skillPerTargetQuality[targetQuality] * recipeDifficulty
	local targetUpperBound = skillPerTargetQuality[min(targetQuality + 1, recipeMaxQuality)] * recipeDifficulty
	neededSkill = max(Math.Round(targetLowerBound - currentSkill, SKILL_PRECISION), 0)
	maxAddedSkill = targetQuality == recipeMaxQuality and math.huge or (targetUpperBound - currentSkill)
	assert(neededSkill >= 0 and maxAddedSkill > 0)
	local maxQualityMatSkill = hasQualityMats and recipeDifficulty * maxMatContribution or 0
	local concentration = 0
	if neededSkill > maxQualityMatSkill then
		if usingConcentration then
			return nil, nil, nil, nil
		end
		-- Retry with concentration (add 1 to the base recipe quality)
		neededSkill, maxAddedSkill, maxQualityMatSkill = Quality.GetNeededSkill(targetQuality - 1, recipeDifficulty, recipeQuality, recipeMaxQuality, hasQualityMats, maxMatContribution, true)
		if not neededSkill then
			return nil, nil, nil, nil
		end
		concentration = 1 -- TODO: Calculate amount of concentration
	end
	return neededSkill, maxAddedSkill, maxQualityMatSkill, concentration
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Procs = LibTSMService:InitInternal("Crafting.Procs")
local CraftingStat = LibTSMService:From("LibTSMData"):Include("CraftingStat")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local private = {
	craftSettingsTable = nil,
	resourcefulnessBonuses = {},
	multicraftBonuses = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the craft info settings table.
---@param crafts table<string,CraftInfo?> The craft info settings table
function Procs.Load(crafts)
	private.craftSettingsTable = crafts
end

---Clears the cached specialization perk bonuses.
function Procs.ClearPerkBonuses()
	wipe(private.resourcefulnessBonuses)
	wipe(private.multicraftBonuses)
end

---Calculates the expected proc rates of a recipe for the current character.
---@param spellId number The recipe spell ID
---@param resourcefulnessChance? number The chance of a Resourcefulness proc
---@param multicraftChance? number The chance of a Multicraft proc
---@return number? expectedRefund
---@return number? expectedExtraYield
function Procs.CalculateRates(spellId, resourcefulnessChance, multicraftChance)
	if not LibTSMService.IsRetail() then
		return nil, nil
	end
	resourcefulnessChance = resourcefulnessChance or 0
	multicraftChance = multicraftChance or 0
	if resourcefulnessChance == 0 and multicraftChance == 0 then
		return nil, nil
	end
	local skillLine, rootSkillLine = TradeSkill.GetRecipeSkillLines(spellId)
	local baseEffects = rootSkillLine and CraftingStat.BaseEffects[rootSkillLine] or nil
	if not baseEffects then
		return nil, nil
	end
	local resourcefulnessBonus, multicraftBonus = private.GetPerkBonuses(spellId, skillLine)
	local expectedRefund = resourcefulnessChance * (baseEffects.resourcefulnessMin + baseEffects.resourcefulnessMax) / 200 * (1 + resourcefulnessBonus / 100)
	local expectedExtraYield = multicraftChance * (baseEffects.multicraftMin + baseEffects.multicraftMax) / 200 * (1 + multicraftBonus / 100)
	return expectedRefund > 0 and min(expectedRefund, 1) or nil, expectedExtraYield > 0 and expectedExtraYield or nil
end

---Gets the expected proc rates to use for a craft's costs.
---@param craftString string The craft string
---@return number expectedRefund
---@return number expectedExtraYield
function Procs.GetExpectedRates(craftString)
	local craftInfo = private.craftSettingsTable[craftString]
	if not craftInfo then
		return 0, 0
	end
	local bestQuality, bestCostFactor, bestRefund, bestExtraYield = nil, math.huge, 0, 0
	for _, info in pairs(craftInfo.players) do
		if type(info) == "table" then
			local quality = info.baseRecipeQuality or 0
			local expectedRefund = info.expectedRefund or 0
			local expectedExtraYield = info.expectedExtraYield or 0
			local costFactor = (1 - expectedRefund) / (1 + expectedExtraYield)
			if not bestQuality or quality > bestQuality or (quality == bestQuality and costFactor < bestCostFactor) then
				bestQuality = quality
				bestCostFactor = costFactor
				bestRefund = expectedRefund
				bestExtraYield = expectedExtraYield
			end
		end
	end
	return bestRefund, bestExtraYield
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetPerkBonuses(spellId, skillLine)
	local groupIndex = CraftingStat.Recipes[spellId]
	if not groupIndex or not skillLine then
		return 0, 0
	end
	if not private.resourcefulnessBonuses[groupIndex] then
		local group = CraftingStat.PerkGroups[groupIndex]
		private.resourcefulnessBonuses[groupIndex] = private.SumPerkBonuses(group.resourcefulness, skillLine)
		private.multicraftBonuses[groupIndex] = private.SumPerkBonuses(group.multicraft, skillLine)
	end
	return private.resourcefulnessBonuses[groupIndex], private.multicraftBonuses[groupIndex]
end

function private.SumPerkBonuses(perks, skillLine)
	local result = 0
	if not perks then
		return result
	end
	for nodeId, amount in pairs(perks) do
		result = result + amount * TradeSkill.GetSpecializationNodeRank(skillLine, nodeId)
	end
	return result
end

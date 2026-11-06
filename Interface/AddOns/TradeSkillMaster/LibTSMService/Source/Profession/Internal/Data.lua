-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Data = LibTSMService:InitInternal("Profession.Data")
local EnchantData = LibTSMService:From("LibTSMData"):Include("Enchant")
local Professions = LibTSMService:From("LibTSMData"):Include("Professions")
local SalvageData = LibTSMService:From("LibTSMData"):Include("Salvage")
local Spell = LibTSMService:From("LibTSMWoW"):Include("API.Spell")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the result of an indirect craft.
---@param spellId number The recipe spell ID
---@return string|string[]|nil
function Data.GetIndirectCraftResult(spellId)
	return EnchantData.Recipes[spellId] or SalvageData.MassMill[spellId] or EnchantData.QualityRecipes[spellId] or nil
end

---Checks if a profession is ignored.
---@param name string The name of the profession
---@param skillId? number The profession skill ID
---@return boolean
function Data.IsIgnored(name, skillId)
	if Professions.IgnoredNames[name] then
		return true
	elseif skillId and Professions.IgnoredSpellIds[skillId] then
		return true
	end
	for i in pairs(Professions.IgnoredSpellIds) do
		if Spell.GetInfo(i) == name then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CraftInfo = LibTSMService:InitInternal("Profession.CraftInfo")
local Scanner = LibTSMService:Include("Profession.Scanner")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = LibTSMService:Include("Inventory.WarbankTracking")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the number of mats for a recipe.
---@param craftString string The craft string for the recipe
---@return number
function CraftInfo.GetNumMats(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	return TradeSkill.GetNumMats(spellId, CraftString.GetLevel(craftString))
end

---Returns whether or not all mats are available for a craft.
---@param craftString string The craft string
---@return boolean
function CraftInfo.HasMaterials(craftString)
	for i = 1, CraftInfo.GetNumMats(craftString) do
		local itemString, quantity = Scanner.GetMatInfo(craftString, i)
		if not itemString or not quantity then
			return false
		end
		if floor(private.GetMatQuantity(itemString) / quantity) == 0 then
			return false
		end
	end
	return true
end

---Gets the number of a craft that can be crafted.
---@param craftString string The craft string
---@return number num
---@return number numAll
function CraftInfo.GetNumCraftable(craftString)
	local num, numAll = math.huge, math.huge
	for i = 1, CraftInfo.GetNumMats(craftString) do
		local itemString, quantity = Scanner.GetMatInfo(craftString, i)
		local totalQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
		if not quantity or totalQuantity == 0 then
			return 0, 0
		end
		num = min(num, floor(private.GetMatQuantity(itemString) / quantity))
		numAll = min(numAll, floor(totalQuantity / quantity))
	end
	if num == math.huge or numAll == math.huge then
		return 0, 0
	end
	return num, numAll
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetMatQuantity(itemString)
	return BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
end

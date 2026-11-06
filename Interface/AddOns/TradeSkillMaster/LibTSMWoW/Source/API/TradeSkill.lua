-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local TradeSkill = LibTSMWoW:Init("API.TradeSkill")
local Spell = LibTSMWoW:Include("API.Spell")
local Currency = LibTSMWoW:Include("API.Currency")
local SlotId = LibTSMWoW:Include("Type.SlotId")
local Event = LibTSMWoW:Include("Service.Event")
local Item = LibTSMWoW:Include("API.Item")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local private = {
	buggedQuantityRangeSpells = {},
	categoryRootCache = {
		lastUpdate = 0,
	},
	categorySkillLevelCache = {
		lastUpdate = 0,
	},
	iteratorContext = {},
	categoryInfoTemp = {},
	craftingOrderFulfilledCallbacks = CallbackRegistry.NewList(),
}
local TYPE = EnumType.New("TRADE_SKILL_TYPE", {
	PLAYER = EnumType.NewValue(),
	NPC = EnumType.NewValue(),
	GUILD = EnumType.NewValue(),
	LINKED = EnumType.NewValue(),
})
TradeSkill.TYPE = TYPE
local RECIPE_TYPE = EnumType.New("TRADE_SKILL_RECIPE_TYPE", {
	ITEM = EnumType.NewValue(),
	ENCHANT = EnumType.NewValue(),
	SALVAGE = EnumType.NewValue(),
	UNKNOWN = EnumType.NewValue()
})
TradeSkill.RECIPE_TYPE = RECIPE_TYPE
local RECIPE_DIFFICULTY = EnumType.New("TRADE_SKILL_RECIPE_DIFFICULTY", {
	OPTIMAL = EnumType.NewValue(),
	MEDIUM = EnumType.NewValue(),
	EASY = EnumType.NewValue(),
	TRIVIAL = EnumType.NewValue(),
})
TradeSkill.RECIPE_DIFFICULTY = RECIPE_DIFFICULTY
local MAT_TYPE = EnumType.New("TRADE_SKILL_MAT_TYPE", {
	REQUIRED = EnumType.NewValue(),
	QUALITY = EnumType.NewValue(),
	OPTIONAL = EnumType.NewValue(),
	FINISHING = EnumType.NewValue(),
})
TradeSkill.MAT_TYPE = MAT_TYPE
local NAMES = {
	ENCHANTING = Spell.GetInfo(7411) --[[@as string]],
	MINING = Spell.GetInfo(2575) --[[@as string]],
	SMELTING = Spell.GetInfo(2656) --[[@as string]],
	POISONS = Spell.GetInfo(2842) --[[@as string]],
}
TradeSkill.NAMES = NAMES
local EMPTY_TABLE = {}
local PROFESSION_NAME_MAP = {
	["Costura"] = "Sastrería",
	["Marroquinería"] = "Peletería",
	["Ingénierie"] = "Ingénieur",
	["Secourisme"] = "Premiers soins",
}
local CLASSIC_SUB_NAMES = {
	[APPRENTICE] = true,
	[JOURNEYMAN] = true,
	[EXPERT] = true,
	[ARTISAN] = true,
	[MASTER] = true,
	[GRAND_MASTER] = true,
	[ILLUSTRIOUS] = true,
	[ZEN_MASTER] = true,
	["大师级"] = true, -- zhCN ARTISAN
	["Мастеровой"] = true, -- ruRU ARTISAN
}
local BUGGED_QUANTITY_RANGE_SPELLS = {
	[169092] = {1, 1}, -- Temporal Crystal
	[210116] = {4, 4}, -- Yseralline
	[209664] = {42, 42}, -- Felwort (amount is variable but the values are conservative)
	[247861] = {4, 4}, -- Astral Glory (amount is variable but the values are conservative)
}
local CONCENTRATION_ICON = "Interface\\ICONS\\UI_Concentration"



-- ============================================================================
-- Module Loading
-- ============================================================================

TradeSkill:OnModuleLoad(function()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		Event.Register("CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG", private.HandleCraftingOrderFulfilled)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not a name is a classic trade skill sub name.
---@param name string The name
---@return boolean
function TradeSkill.IsClassicSubName(name)
	return CLASSIC_SUB_NAMES[name] or false
end

---Adds bugged quantity info.
---@param spellId number The spell ID
---@param minQuantity number The minimum quantity created by the craft
---@param maxQuantity number The maximum quantity created by the craft
function TradeSkill.AddBuggedQuantityInfo(spellId, minQuantity, maxQuantity)
	assert(type(spellId) == "number" and minQuantity <= maxQuantity)
	private.buggedQuantityRangeSpells[spellId] = { minQuantity, maxQuantity }
end

---Loads the Blizzard Craft UI addon.
function TradeSkill.LoadBlizzardCraftUI()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() or C_AddOns.IsAddOnLoaded("Blizzard_CraftUI") then
		return
	end
	C_AddOns.LoadAddOn("Blizzard_CraftUI")
end


---Opens a trade skill.
---@param profession string|Enum.Profession The name of the profession (classic) or the profession enum value (retail)
function TradeSkill.OpenUI(profession)
	assert(not LibTSMWoW.IsForever())
	if LibTSMWoW.IsRetail() then
		assert(type(profession) == "number")
		C_TradeSkillUI.OpenTradeSkill(profession)
	else
		assert(type(profession) == "string")
		CastSpellByName(private.GetProfessionSpellName(profession))
	end
end

---Gets the name of the spell which a secure action button needs to cast to open a trade skill.
---@param profession string The name of the profession
---@return string
function TradeSkill.GetOpenUISpellName(profession)
	assert(LibTSMWoW.IsForever())
	return private.GetProfessionSpellName(profession)
end

---Close the open trade skill.
---@param closeBoth boolean Whether to close both the craft and tradeskill on classic
function TradeSkill.CloseUI(closeBoth)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		C_TradeSkillUI.CloseTradeSkill()
		C_Garrison.CloseGarrisonTradeskillNPC()
	elseif closeBoth then
		CloseCraft()
		CloseTradeSkill()
	elseif TradeSkill.IsClassicCrafting() then
		CloseCraft()
	else
		CloseTradeSkill()
	end
end

---Gets the type of the current open trade skill.
---@return EnumValue
function TradeSkill.GetType()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		if C_TradeSkillUI.IsNPCCrafting() and C_TradeSkillUI.GetBaseProfessionInfo().profession then
			return TYPE.NPC
		elseif C_TradeSkillUI.IsTradeSkillGuild() then
			return TYPE.GUILD
		elseif C_TradeSkillUI.IsTradeSkillLinked() then
			return TYPE.LINKED
		end
	elseif not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() and IsTradeSkillLinked() then
		return TYPE.LINKED
	end
	return TYPE.PLAYER
end

--Gets the crafting quality index table for a given recipe.
---@param spellId number The recipe spell to check.
---@return number[]?
function TradeSkill.GetQualitiesForRecipe(spellId)
	if not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
		return nil
	end
	return C_TradeSkillUI.GetQualitiesForRecipe(spellId)
end

---Gets the maximum crafting quality for a given recipe.
---@param spellId number The recipe spell to check.
---@return number?
function TradeSkill.GetMaxQualityForRecipe(spellId)
	local qualityIDs = TradeSkill.GetQualitiesForRecipe(spellId)
	return qualityIDs and #qualityIDs or nil
end

---Gets whether the recipe belongs to the Midnight expansion.
---@param spellId number The recipe spell to check.
---@return boolean
function TradeSkill.IsMidnightRecipe(spellId)
	local qualityIDs = TradeSkill.GetQualitiesForRecipe(spellId)
	return qualityIDs and #qualityIDs == 2 or false
end

---Returns whether or not the current trade skill is classic crafting.
function TradeSkill.IsClassicCrafting()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		return false
	end
	local name, _, maxLevel = GetTradeSkillLine()
	if name == "UNKNOWN" or maxLevel == 0 then
		return true
	else
		return false
	end
end

---Gets the name of the player who linked the current trade skill (for TYPE.LINKED).
---@return string?
function TradeSkill.GetLinkedPlayer()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() or LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		return nil
	end
	local _, playerName = IsTradeSkillLinked()
	return playerName
end

---Returns whether or not the trade skill data is ready.
---@return boolean
function TradeSkill.IsDataReady()
	if not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
		return true
	end
	return C_TradeSkillUI.IsTradeSkillReady() and not C_TradeSkillUI.IsDataSourceChanging()
end

---Gets the current trade skill's link.
---@return string?
function TradeSkill.GetLink()
	if not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
		return nil
	end
	return C_TradeSkillUI.GetTradeSkillListLink()
end

---Gets the name of the current profession (and the skillId on retail).
---@return string name
---@return Enum.Profession? skillId
function TradeSkill.GetName()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local info = C_TradeSkillUI.GetBaseProfessionInfo()
		return info.parentProfessionName or info.professionName, info.profession
	else
		local name = TradeSkill.IsClassicCrafting() and GetCraftSkillLine(1) or GetTradeSkillLine()
		return name
	end
end

---Clears all trade skill filters and returns whether or not filters were previously set.
---@return boolean
function TradeSkill.ClearFilters()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local hadFilter = false
		if C_TradeSkillUI.GetShowUnlearned() then
			C_TradeSkillUI.SetShowLearned(true)
			C_TradeSkillUI.SetShowUnlearned(false)
			hadFilter = true
		end
		if C_TradeSkillUI.GetOnlyShowMakeableRecipes() then
			C_TradeSkillUI.SetOnlyShowMakeableRecipes(false)
			hadFilter = true
		end
		if C_TradeSkillUI.GetOnlyShowSkillUpRecipes() then
			C_TradeSkillUI.SetOnlyShowSkillUpRecipes(false) ---@diagnostic disable-line: redundant-parameter
			hadFilter = true
		end
		if C_TradeSkillUI.AnyRecipeCategoriesFiltered() then
			C_TradeSkillUI.ClearRecipeCategoryFilter()
			hadFilter = true
		end
		if C_TradeSkillUI.AreAnyInventorySlotsFiltered() then
			C_TradeSkillUI.ClearInventorySlotFilter()
			hadFilter = true
		end
		for i = 1, C_PetJournal.GetNumPetSources() do
			if C_TradeSkillUI.IsAnyRecipeFromSource(i) and C_TradeSkillUI.IsRecipeSourceTypeFiltered(i) then
				C_TradeSkillUI.ClearRecipeSourceTypeFilter()
				hadFilter = true
				break
			end
		end
		if C_TradeSkillUI.GetRecipeItemNameFilter() ~= "" then
			C_TradeSkillUI.SetRecipeItemNameFilter(nil) ---@diagnostic disable-line: redundant-parameter
			hadFilter = true
		end
		local minItemLevel, maxItemLevel = C_TradeSkillUI.GetRecipeItemLevelFilter()
		if minItemLevel ~= 0 or maxItemLevel ~= 0 then
			C_TradeSkillUI.SetRecipeItemLevelFilter(0, 0)
			hadFilter = true
		end
		return hadFilter
	else
		-- TODO
		return false
	end
end

---Sets the default filter values.
function TradeSkill.SetDefaultFilters()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		Professions.SetDefaultFilters()
	else
		ExpandTradeSkillSubClass(0)
		SetTradeSkillInvSlotFilter(0, 1, 0)
		SetTradeSkillSubClassFilter(0, 1, 0)
		if LibTSMWoW.IsMistsClassic() then
			SetTradeSkillItemNameFilter(nil)
			SetTradeSkillItemLevelFilter(0, 0)
			TradeSkillOnlyShowSkillUps(false)
			TradeSkillOnlyShowMakeable(false)
		end
	end
end

---Gets the result item(s) of a recipe.
---@param spellId number The recipe spell ID
---@return string|number[] items
---@return number? indirectSpellId
---@return number? indirectResultId
function TradeSkill.GetResult(spellId)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		return C_TradeSkillUI.GetRecipeQualityItemIDs(spellId) or C_TradeSkillUI.GetRecipeItemLink(spellId)
	else
		local itemLink = TradeSkill.IsClassicCrafting() and GetCraftItemLink(spellId) or GetTradeSkillItemLink(spellId) --[[@as string?]]
		local indirectResultId = nil
		-- Filter out invalid item links
		itemLink = not strfind(itemLink or "", "item::") and itemLink or nil
		if LibTSMWoW.IsMistsClassic() then
			itemLink = itemLink or GetTradeSkillRecipeLink(spellId)
		end
		assert(itemLink)
		local indirectSpellId = strmatch(itemLink, "enchant:(%d+)")
		if not indirectSpellId then
			indirectResultId = strmatch(itemLink, "item:(%d+)") or strmatch(itemLink, "spell:(%d+)")
		end
		indirectSpellId = indirectSpellId and tonumber(indirectSpellId)
		indirectResultId = indirectResultId and tonumber(indirectResultId)
		return itemLink, indirectSpellId, indirectSpellId or indirectResultId
	end
end

---Returns whether or not a recipe is an enchant.
---@param spellId number The recipe spell ID
---@return boolean
function TradeSkill.IsEnchant(spellId)
	if TradeSkill.GetName() ~= NAMES.ENCHANTING then
		return false
	end
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		if not strfind(C_TradeSkillUI.GetRecipeItemLink(spellId), "enchant:") then
			return false
		end
		local info = C_TradeSkillUI.GetRecipeInfo(spellId)
		assert(info)
		return info.isEnchantingRecipe and true or false
	else
		local _, indirectSpellId = TradeSkill.GetResult(spellId)
		return indirectSpellId and true or false
	end
end

---Selects the recipe to craft based on the craft index.
---@param index number The index of the craft
function TradeSkill.SelectCraft(index)
	SelectCraft(index)
end

---Gets cooldown info for a recipe.
---@param spellId number The recipe spell ID
---@return boolean isDailyCooldown
---@return number? remainingCooldown
function TradeSkill.GetCooldownInfo(spellId)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local cooldown, isDailyCooldown, charges, maxCharges = C_TradeSkillUI.GetRecipeCooldown(spellId)
		---@cast isDailyCooldown boolean
		if (maxCharges or 0) > 0 and charges and (charges > 0 or not cooldown) then
			return isDailyCooldown, nil
		end
		return isDailyCooldown, cooldown and floor(cooldown) or nil
	else
		local cooldown = GetTradeSkillCooldown(spellId)
		return cooldown and true or false, cooldown and floor(cooldown) or nil
	end
end

---Gets the icon texture for a recipe (classic-only).
---@param index number The recipe index
---@return number
function TradeSkill.GetIcon(index)
	assert(not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever())
	if TradeSkill.IsClassicCrafting() then
		return GetCraftIcon(index) --[[@as number]]
	else
		return GetTradeSkillIcon(index) --[[@as number]]
	end
end

---Gets the crafted quality of an item.
---@param itemId number The item ID
---@return number?
function TradeSkill.GetItemCraftedQuality(itemId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	return C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemId) or C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemId)
end

---Gets the chat icon for a given crafted quality.
---@param craftedQuality number? The crafted quality
---@param useMidnightIcon boolean? The expansion check to get which atlas to apply
---@param large? boolean Get the large version of the icon
---@return string
function TradeSkill.GetCraftedQualityChatIcon(craftedQuality, useMidnightIcon, large)
	if not craftedQuality then
		return ""
	end
	local atlas = format(useMidnightIcon and "Professions-ChatIcon-Quality-12-Tier%d" or "Professions-ChatIcon-Quality-Tier%d", craftedQuality)
	return CreateAtlasMarkupWithAtlasSize(atlas, nil, large and 1 or 0, nil, nil, nil, large and 0.5 or 0.4)
end

---Gets the item level bonuses produced by different qualities of the recipe.
---@param spellId number The recipe spell ID
---@return number[]? qualityIlvlBonuses
function TradeSkill.GetItemLevelBonuses(spellId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	local info = C_TradeSkillUI.GetRecipeInfo(spellId)
	assert(info)
	local bonusTable = info.qualityIlvlBonuses
	return bonusTable and #bonusTable >= 2 and bonusTable or nil
end

---Gets the range of quantities crafted by a recipe.
---@param spellId number The recipe spell ID
---@return number
---@return number
function TradeSkill.GetNumMade(spellId)
	if TradeSkill.IsEnchant(spellId) then
		return 1, 1
	elseif BUGGED_QUANTITY_RANGE_SPELLS[spellId] then
		return unpack(BUGGED_QUANTITY_RANGE_SPELLS[spellId])
	elseif private.buggedQuantityRangeSpells[spellId] then
		return unpack(private.buggedQuantityRangeSpells[spellId])
	elseif LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local info = C_TradeSkillUI.GetRecipeSchematic(spellId, false)
		return info.quantityMin, info.quantityMax
	elseif TradeSkill.IsClassicCrafting() then
		return 1, 1
	else
		return GetTradeSkillNumMade(spellId)
	end
end

---Iterates over the available trade skill recipes (must be run to completion).
---@return fun(): number, string?, number?, EnumValue?, TradeSkillRecipeInfo? @Iterator with fields: `index`, `name`, `categoryId`, `difficulty`, `info`
---@return table
---@return number
function TradeSkill.RecipeIterator()
	assert(not next(private.iteratorContext))
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		assert(C_TradeSkillUI.GetFilteredRecipeIDs(private.iteratorContext) == private.iteratorContext) ---@diagnostic disable-line: redundant-parameter
	else
		private.iteratorContext.lastHeaderIndex = 0
	end
	return private.RecipeIterator, private.iteratorContext, 0
end

---Extracts fields from the `info` value of `TradeSkill.RecipeInfo`.
---@param info TradeSkillRecipeInfo
---@return number numSkillUps
---@return EnumValue difficulty
function TradeSkill.ExtractInfo(info)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	local numSkillUps = info.relativeDifficulty == Enum.TradeskillRelativeDifficulty.Optimal and info.numSkillUps or 1
	local difficulty = private.MapDifficulty(info.relativeDifficulty)
	return numSkillUps, difficulty
end

---Gets the description for a recipe.
---@param spellId number The recipe spell ID
---@return string
function TradeSkill.GetRecipeDescription(spellId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	return C_TradeSkillUI.GetRecipeDescription(spellId, EMPTY_TABLE)
end

---Returns the recipe type.
---@param spellId number The recipe spell ID
---@return EnumValue recipeType
function TradeSkill.GetRecipeType(spellId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	return private.MapRecipeType(C_TradeSkillUI.GetRecipeSchematic(spellId, false).recipeType)
end

---Gets salvage recipe info.
---@param spellId number The recipe spell ID
---@param level? number The recipe level
---@return number[]? itemIds
---@return number? quantityMin
function TradeSkill.GetSalvageInfo(spellId, level)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	local info = C_TradeSkillUI.GetRecipeSchematic(spellId, false, level)
	if private.MapRecipeType(info.recipeType) ~= RECIPE_TYPE.SALVAGE then
		return nil, nil
	end
	return C_TradeSkillUI.GetSalvagableItemIDs(spellId), info.quantityMin
end

---Gets quality info for a recipe.
---@param spellId number The recipe spell ID
---@return number? baseDifficulty
---@return number? quality
---@return boolean? hasQualityMats
---@return number? resourcefulnessChance
---@return number? multicraftChance
function TradeSkill.GetRecipeQualityInfo(spellId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	local info = C_TradeSkillUI.GetRecipeSchematic(spellId, false, 1)
	local recipeType = private.MapRecipeType(info.recipeType)
	if not info.hasCraftingOperationInfo then
		return nil, nil, nil, nil, nil
	elseif recipeType == RECIPE_TYPE.UNKNOWN then
		return nil, nil, nil, nil, nil
	elseif recipeType == RECIPE_TYPE.ITEM and not info.outputItemID then
		return nil, nil, nil, nil, nil
	end
	local operationInfo = C_TradeSkillUI.GetCraftingOperationInfo(spellId, EMPTY_TABLE, nil, false)
	if not operationInfo then
		return nil, nil, nil, nil, nil
	end
	local hasQualityMats = false
	for _, data in ipairs(info.reagentSlotSchematics) do
		if data.reagentType == Enum.CraftingReagentType.Basic and data.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent then
			hasQualityMats = true
			break
		end
	end
	local resourcefulnessChance, multicraftChance = 0, 0
	if LibTSMWoW.IsRetail() then
		for _, statInfo in ipairs(operationInfo.bonusStats) do
			if statInfo.bonusStatName == ITEM_MOD_RESOURCEFULNESS_SHORT then
				resourcefulnessChance = statInfo.ratingPct / 100
			elseif statInfo.bonusStatName == ITEM_MOD_MULTICRAFT_SHORT then
				multicraftChance = statInfo.ratingPct / 100
			end
		end
	end
	return operationInfo.baseDifficulty, operationInfo.quality, hasQualityMats, resourcefulnessChance, multicraftChance
end

---Gets the skill lines of a recipe.
---@param spellId number The recipe spell ID
---@return number? skillLine
---@return number? rootSkillLine
function TradeSkill.GetRecipeSkillLines(spellId)
	assert(LibTSMWoW.IsRetail())
	local skillLine, _, rootSkillLine = C_TradeSkillUI.GetTradeSkillLineForRecipe(spellId)
	return skillLine, rootSkillLine
end

---Gets the rank the current character has in a specialization node.
---@param skillLine number The skill line of the specialization
---@param nodeId number The specialization node ID
---@return number
function TradeSkill.GetSpecializationNodeRank(skillLine, nodeId)
	assert(LibTSMWoW.IsRetail())
	local configId = C_ProfSpecs.GetConfigIDForSkillLine(skillLine)
	if not configId or configId == 0 then
		return 0
	end
	local nodeInfo = C_Traits.GetNodeInfo(configId, nodeId)
	if nodeInfo.maxRanks > 1 then
		local unlockEntryInfo = C_Traits.GetEntryInfo(configId, C_ProfSpecs.GetUnlockEntryForPath(nodeId))
		return max(nodeInfo.currentRank - unlockEntryInfo.maxRanks, 0)
	end
	return C_ProfSpecs.GetStateForPerk(nodeId, configId) == Enum.ProfessionsSpecPerkState.Earned and 1 or 0
end

---Gets the concentration cost of a craft and the amount of concentration the player has.
---@param spellId number The recipe spell ID
---@param reagents CraftingReagentInfo[] The reagents being used
---@return number? cost
---@return number? available
---@return number? currencyId
function TradeSkill.GetConcentrationInfo(spellId, reagents)
	if not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
		return nil, nil, nil
	end
	local operationInfo = C_TradeSkillUI.GetCraftingOperationInfo(spellId, reagents, nil, true)
	if not operationInfo or operationInfo.concentrationCurrencyID == 0 or operationInfo.concentrationCost <= 0 then
		return nil, nil, nil
	end
	local _, _, quantity = Currency.GetInfo(operationInfo.concentrationCurrencyID)
	if not quantity then
		return nil, nil, nil
	end
	return operationInfo.concentrationCost, quantity, operationInfo.concentrationCurrencyID
end

---Get information on a trade skill category.
---@param categoryId number The category ID
---@return string? name
---@return number numIndents
---@return number? parentCategoryId
---@return number? skillLevel
---@return number? maxSkillLevel
function TradeSkill.CategoryInfo(categoryId)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		C_TradeSkillUI.GetCategoryInfo(categoryId, private.categoryInfoTemp)
		local name = private.categoryInfoTemp.name
		local parentCategoryId = private.categoryInfoTemp.numIndents ~= 0 and private.categoryInfoTemp.parentCategoryID or nil
		local currentSkillLevel = private.categoryInfoTemp.skillLineCurrentLevel
		local maxSkillLevel = private.categoryInfoTemp.skillLineMaxLevel
		local numIndents = 0
		if parentCategoryId then
			C_TradeSkillUI.GetCategoryInfo(parentCategoryId, private.categoryInfoTemp)
			if private.categoryInfoTemp.type == "subheader" then
				numIndents = parentCategoryId == private.categoryInfoTemp.parentCategoryID and 0 or 1
			end
		else
			numIndents = 0
		end
		wipe(private.categoryInfoTemp)
		return name, numIndents, parentCategoryId, currentSkillLevel, maxSkillLevel
	else
		if categoryId ~= 0 then
			local name, skillType, _, _, _, _, numIndents = GetTradeSkillInfo(categoryId)
			---@cast name string?
			if skillType == "subheader" then
				local parentCategoryId = private.GetParentCategory(categoryId)
				return name, numIndents, parentCategoryId, nil, nil
			else
				return name or GetTradeSkillLine(), 0, nil, nil, nil
			end
		else
			local name = TradeSkill.IsClassicCrafting() and GetCraftDisplaySkillLine() or GetTradeSkillLine()
			return name, 0, nil, nil, nil
		end
	end
end

---Gets the root category of a category.
---@param categoryId number The category ID
---@return number
function TradeSkill.GetRootCategoryId(categoryId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	if private.categoryRootCache.lastUpdate ~= GetTime() then
		wipe(private.categoryRootCache)
		private.categoryRootCache.lastUpdate = GetTime()
	end
	if not private.categoryRootCache[categoryId] then
		private.GetRootCategoryInfo(categoryId, private.categoryInfoTemp)
		private.categoryRootCache[categoryId] = private.categoryInfoTemp.categoryID or -1
		wipe(private.categoryInfoTemp)
	end
	return private.categoryRootCache[categoryId]
end

---Gets the current skill level of a category.
---@param categoryId number The category ID
---@return number
function TradeSkill.GetCurrentCategorySkillLevel(categoryId)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	if private.categorySkillLevelCache.lastUpdate ~= GetTime() then
		wipe(private.categorySkillLevelCache)
		private.categorySkillLevelCache.lastUpdate = GetTime()
	end
	if not private.categorySkillLevelCache[categoryId] then
		private.GetRootCategoryInfo(categoryId, private.categoryInfoTemp)
		private.categorySkillLevelCache[categoryId] = private.categoryInfoTemp.skillLineCurrentLevel or 0
		wipe(private.categoryInfoTemp)
	end
	return private.categorySkillLevelCache[categoryId]
end

---Gets the name of the required tool for the recipe.
---@param spellId number The recipe spell ID
---@return string?
function TradeSkill.GetRequiredTool(spellId)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		for _, requirement in ipairs(C_TradeSkillUI.GetRecipeRequirements(spellId)) do
			if requirement.type == Enum.RecipeRequirementType.Totem and not requirement.met then
				return requirement.name
			end
		end
		return nil
	elseif TradeSkill.IsClassicCrafting() then
		return private.GetMissingClassicTools(GetCraftSpellFocus(spellId))
	else
		return private.GetMissingClassicTools(GetTradeSkillTools(spellId))
	end
end

---Gets the number of materials for a recipe.
---@param spellId number The recipe spell ID
---@param level? number The recipe level
---@return number
function TradeSkill.GetNumMats(spellId, level)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local num = 0
		for _, data in ipairs(C_TradeSkillUI.GetRecipeSchematic(spellId, false, level).reagentSlotSchematics) do
			if private.IsRegularMat(data) then
				num = num + 1
			end
		end
		return num
	elseif TradeSkill.IsClassicCrafting() then
		return GetCraftNumReagents(spellId)
	else
		return GetTradeSkillNumReagents(spellId)
	end
end

---Gets info on a material by its data slot index.
---@param spellId number The recipe spell ID
---@param dataSlotIndex number The material data slot index
---@return number? quantityRequired
---@return string? itemLink
function TradeSkill.GetMatInfoByDataSlotId(spellId, dataSlotIndex)
	local info = C_TradeSkillUI.GetRecipeSchematic(spellId, false, nil)
	for _, reagentSlotInfo in ipairs(info.reagentSlotSchematics) do
		if reagentSlotInfo.dataSlotIndex == dataSlotIndex then
			if not reagentSlotInfo.reagents[1].itemID then
				return nil, nil
			end
			local _, itemLink = Item.GetInfo(reagentSlotInfo.reagents[1].itemID)
			return reagentSlotInfo.quantityRequired, itemLink
		end
	end
end

---Gets info on a trade skill recipe material.
---@param spellId number The recipe spell ID
---@param level? number The recipe level
---@param index number The material index.
---@return string|number item
---@return string? name
---@return number quantity
---@return boolean isModifiedReagent
function TradeSkill.GetMatInfo(spellId, level, index)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local info = C_TradeSkillUI.GetRecipeSchematic(spellId, false, level)
		local reagentSlotInfo = nil
		local reagentOffset = index - 1
		for _, data in ipairs(info.reagentSlotSchematics) do
			if private.IsRegularMat(data) then
				if reagentOffset == 0 then
					reagentSlotInfo = data
					break
				else
					reagentOffset = reagentOffset - 1
				end
			end
		end
		assert(reagentSlotInfo)
		local item, isModifiedReagent = nil, nil
		if reagentSlotInfo.reagentType == Enum.CraftingReagentType.Modifying and reagentSlotInfo.required then
			item = C_TradeSkillUI.GetRecipeQualityReagentLink(spellId, reagentSlotInfo.dataSlotIndex, 1)
			isModifiedReagent = true
		elseif reagentSlotInfo.reagentType == Enum.CraftingReagentType.Basic and reagentSlotInfo.dataSlotType == Enum.TradeskillSlotDataType.Reagent then
			if not reagentSlotInfo.reagents[1].itemID then
				-- FIXME: handle currencies
				return ---@diagnostic disable-line: missing-return-value
			end
			local _, itemLink = Item.GetInfo(reagentSlotInfo.reagents[1].itemID)
			item = itemLink or reagentSlotInfo.reagents[1].itemID
			isModifiedReagent = false
		elseif reagentSlotInfo.reagentType == Enum.CraftingReagentType.Basic and reagentSlotInfo.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent then
			if not reagentSlotInfo.reagents[1].itemID then
				-- FIXME: handle currencies
				return ---@diagnostic disable-line: missing-return-value
			end
			item = C_TradeSkillUI.GetRecipeQualityReagentLink(spellId, reagentSlotInfo.dataSlotIndex, 1)
			-- NOTE: For some reason, the above API doesn't always work (i.e. with 'Handful of Serevite Bolts')
			item = item or reagentSlotInfo.reagents[1].itemID
			isModifiedReagent = true
		else
			error(format("Invalid mat: %s, %s", tostring(spellId), tostring(index)))
		end
		return item, nil, reagentSlotInfo.quantityRequired, isModifiedReagent
	elseif TradeSkill.IsClassicCrafting() then
		local itemLink = GetCraftReagentItemLink(spellId, index)
		local name, _, quantity = GetCraftReagentInfo(spellId, index)
		return itemLink, name, quantity, false
	else
		local itemLink = GetTradeSkillReagentItemLink(spellId, index)
		local name, _, quantity = GetTradeSkillReagentInfo(spellId, index)
		return itemLink, name, quantity, false
	end
end

---Iterates over special recipe materials.
---@param spellId number The recipe spell ID
---@param level? number The recipe level
---@param categorySkillLevel number The category skill level for filtering mats with required skill
---@return fun(): number, EnumValue, number, number, string|number, CraftingReagent[] @Iterator with fields: `index`, `matType`, `quantityRequired`, `dataSlotIndex`, `slotTextOrId`, `reagents`
---@return table
---@return number
function TradeSkill.SpecialMatIterator(spellId, level, categorySkillLevel)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	local info = C_TradeSkillUI.GetRecipeSchematic(spellId, false, level)
	local mats = info.reagentSlotSchematics
	mats.categorySkillLevel = categorySkillLevel
	return private.SpecialMatIterator, mats, 0
end

---Gets basic info on a recipe from its spell ID.
---@param spellId number The recipe spell ID
---@return string name
---@return number icon
function TradeSkill.GetBasicInfo(spellId)
	if TradeSkill.IsClassicCrafting() then
		local name = GetCraftInfo(spellId)
		local icon = GetCraftIcon(spellId) --[[@as number]]
		return name, icon
	else
		local name, icon = Spell.GetInfo(spellId)
		assert(name and icon)
		return name, icon
	end
end

---Crafts a recipe.
---@param spellId number The recipe spell ID
---@param quantity number The quantity to craft
---@param optionalMats CraftingReagentInfo[]? Optional material information
---@param level? number The recipe level
---@param enchantSlotId? number The slotId of the item to enchant
---@param salvageSlotId? number The slotId of the item to salvage
---@param applyConcentration? boolean Whether or not to apply concentration
function TradeSkill.Craft(spellId, quantity, optionalMats, level, enchantSlotId, salvageSlotId, applyConcentration)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		if enchantSlotId then
			assert(not level and not salvageSlotId)
			local itemLocation = SlotId.AcquireItemLocation(enchantSlotId)
			C_TradeSkillUI.CraftEnchant(spellId, quantity, optionalMats, itemLocation, applyConcentration)
			SlotId.ReleaseItemLocation(itemLocation)
		elseif salvageSlotId then
			assert(not level)
			local itemLocation = SlotId.AcquireItemLocation(salvageSlotId)
			if private.IsValidMatItemLocation(itemLocation) then
				C_TradeSkillUI.CraftSalvage(spellId, quantity, itemLocation, optionalMats, applyConcentration)
			end
			SlotId.ReleaseItemLocation(itemLocation)
		else
			C_TradeSkillUI.CraftRecipe(spellId, quantity, optionalMats, level, nil, applyConcentration)
		end
	else
		assert(not level and not optionalMats and not enchantSlotId and not salvageSlotId)
		if TradeSkill.IsClassicCrafting() then
			assert(quantity == 1)
			DoCraft(spellId)
		else
			DoTradeSkill(spellId, quantity)
		end
	end
end

---Gets the name of a recipe on classic.
---@param index number The recipe index
---@return string?
function TradeSkill.GetClassicCraftName(index)
	assert(not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever())
	local name = nil
	if TradeSkill.IsClassicCrafting() then
		name = GetCraftInfo(index)
	else
		name = GetTradeSkillInfo(index)
	end
	return name
end

---Checks if the specified slot ID Is a valid salvage target.
---@param slotId number
---@return boolean
function TradeSkill.IsValidMatSlotId(slotId)
	local itemLocation = SlotId.AcquireItemLocation(slotId)
	local success = private.IsValidMatItemLocation(itemLocation)
	SlotId.ReleaseItemLocation(itemLocation)
	return success
end

---Securely hook the CraftSalvage API.
---@param func fun(spellId: number, slotId: number) The function to call
function TradeSkill.SecureHookCraftSalvage(func)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	hooksecurefunc(C_TradeSkillUI, "CraftSalvage", function(spellId, _, itemLocation)
		func(spellId, SlotId.GetFromItemLocation(itemLocation))
	end)
end

---Links a recipe into the chat window.
---@param spellId number The recipe spell ID
function TradeSkill.LinkRecipe(spellId)
	local link = nil
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		link = C_TradeSkillUI.GetRecipeLink(spellId)
	else
		if TradeSkill.IsClassicCrafting() then
			link = GetCraftRecipeLink(spellId)
		else
			link = GetTradeSkillRecipeLink(spellId)
		end
	end
	ChatEdit_InsertLink(link)
end

---Register a callback for when crafting orders are fulfilled.
---@param callback fun(tipAmount: number, character: string) The callback function
function TradeSkill.RegisterCraftingOrderFulfilledCallback(callback)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	private.craftingOrderFulfilledCallbacks:Add(callback)
end

---Gets the constants used to represent concentration in the UI.
---@return string localizedStr
---@return string iconLink
---@return string icon
function TradeSkill.GetConcentrationUIConstants()
	return PROFESSIONS_CRAFTING_STAT_CONCENTRATION, "|T"..CONCENTRATION_ICON..":0|t", CONCENTRATION_ICON
end

---Gets the visible default UI frame.
---@param isCraft boolean Whether or not a crafting profession is open (i.e. Enchanting on Classic Era)
---@return Frame
function TradeSkill.GetVisibleDefaultFrame(isCraft)
	if isCraft then
		return CraftFrame
	elseif LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		return ProfessionsFrame
	else
		return TradeSkillFrame
	end
end

---Registers a callback for when the default trade skill frame is shown.
---@param callback fun()
function TradeSkill.RegisterDefaultFrameShowCallback(callback)
	assert(LibTSMWoW.IsForever())
	TradeSkill.GetVisibleDefaultFrame(false):HookScript("OnShow", callback)
end

---Returns whether or not the default UI is showing the professions book page.
---@return boolean
function TradeSkill.IsDefaultUIBookPageShown()
	assert(LibTSMWoW.IsForever())
	return ProfessionsFrame.BookPage:IsShown() ---@diagnostic disable-line: undefined-field
end

---Registers a callback for when the default UI's professions book page is shown or hidden.
---@param callback fun()
function TradeSkill.RegisterDefaultUIBookPageCallback(callback)
	assert(LibTSMWoW.IsForever())
	local bookPage = ProfessionsFrame.BookPage ---@diagnostic disable-line: undefined-field
	bookPage:HookScript("OnShow", callback)
	bookPage:HookScript("OnHide", callback)
end

---Shows or hides the default UI's craft button as based on the current crafting state.
function TradeSkill.ShowOrHideDefaultUICraftButton()
	if not CraftCreateButton then
		return
	end
	if TradeSkill.IsClassicCrafting() then
		CraftCreateButton:Show()
	else
		CraftCreateButton:Hide()
	end
end

---Updates the position of the default UI's craft button.
function TradeSkill.UpdateDefaultUICraftButton()
	if not CraftFrame or not CraftCreateButton then
		return
	end
	CraftCreateButton:SetParent(CraftFrame)
	CraftCreateButton:ClearAllPoints()
	CraftCreateButton:SetPoint("CENTER", CraftFrame, "TOPLEFT", 224, -422)
	CraftCreateButton:SetFrameLevel(2)
	CraftCreateButton:EnableDrawLayer("BACKGROUND")
	CraftCreateButton:EnableDrawLayer("ARTWORK")
end

---Closes the default trade skill UI.
function TradeSkill.CloseDefaultUI()
	CloseTradeSkill()
end

---Closes the crafting trade skill UI.
function TradeSkill.CloseDefaultCraftUI()
	if not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
		CloseCraft()
	end
end

---Loads the default UI addon.
function TradeSkill.LoadAddon()
	if not C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
		C_AddOns.LoadAddOn("Blizzard_Professions")
	end
	if (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and not C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsBook") then
		C_AddOns.LoadAddOn("Blizzard_ProfessionsBook")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleCraftingOrderFulfilled(_, _, _, character, tipAmount)
	private.craftingOrderFulfilledCallbacks:CallAll(tipAmount, character)
end

function private.GetProfessionSpellName(profession)
	-- Mining needs to be opened as smelting
	if profession == NAMES.MINING then
		profession = NAMES.SMELTING
	end
	return PROFESSION_NAME_MAP[profession] or profession
end

function private.MapRecipeType(recipeType)
	if recipeType == Enum.TradeskillRecipeType.Item then
		return RECIPE_TYPE.ITEM
	elseif recipeType == Enum.TradeskillRecipeType.Enchant then
		return RECIPE_TYPE.ENCHANT
	elseif recipeType == Enum.TradeskillRecipeType.Salvage then
		return RECIPE_TYPE.SALVAGE
	else
		return RECIPE_TYPE.UNKNOWN
	end
end

function private.IsRegularMat(data)
	if data.reagentType == Enum.CraftingReagentType.Modifying and data.required then
		return true
	end
	if data.reagentType ~= Enum.CraftingReagentType.Basic then
		return false
	end
	return data.dataSlotType == Enum.TradeskillSlotDataType.Reagent or data.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
end

function private.GetParentCategory(categoryId)
	for i = categoryId - 1, 1, -1 do
		local name, skillType = GetTradeSkillInfo(i)
		---@cast name string?
		if name and name ~= "" and skillType == "header" then
			return i
		end
	end
end

function private.RecipeIterator(context, index)
	while true do
		index = index + 1
		if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
			if index > #context then
				wipe(context)
				return
			end
			local spellId = context[index]
			local info = C_TradeSkillUI.GetRecipeInfo(spellId)
			assert(info and info.recipeID == spellId)
			return index, nil, nil, nil, info
		else
			local name, skillType = nil, nil
			if TradeSkill.IsClassicCrafting() then
				if index > GetNumCrafts() then
					wipe(context)
					return
				end
				local _
				name, _, skillType = GetCraftInfo(index)
			else
				if index > GetNumTradeSkills() then
					wipe(context)
					return
				end
				name, skillType = GetTradeSkillInfo(index)
			end
			if skillType == "header" or skillType == "subheader" then
				-- Ignore categories with no name as they are bugged (i.e. Tinkers in Mists)
				if name ~= "" then
					context.lastHeaderIndex = index
				end
			elseif type(name) == "string" and name ~= "" then
				return index, name, context.lastHeaderIndex, private.MapDifficulty(skillType)
			end
		end
	end
end

function private.SpecialMatIterator(mats, index)
	while true do
		index = index + 1
		if index > #mats then
			return
		end
		local data = mats[index] ---@type CraftingReagentSlotSchematic
		if private.IsValidSpecialMat(data, mats.categorySkillLevel) then
			local matType, slotText = nil, nil
			if data.reagentType == Enum.CraftingReagentType.Basic and data.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent then
				matType = MAT_TYPE.QUALITY
				slotText = data.reagents[1].itemID
			elseif data.reagentType == Enum.CraftingReagentType.Modifying then
				assert(data.slotInfo)
				if data.required then
					matType = MAT_TYPE.REQUIRED
					slotText = data.slotInfo.slotText or REQUIRED_REAGENT_TOOLTIP_CLICK_TO_ADD
				else
					matType = MAT_TYPE.OPTIONAL
					slotText = data.slotInfo.slotText or OPTIONAL_REAGENT_POSTFIX
				end
			elseif data.reagentType == Enum.CraftingReagentType.Finishing then
				assert(data.slotInfo)
				matType = MAT_TYPE.FINISHING
				slotText = data.slotInfo.slotText or OPTIONAL_REAGENT_POSTFIX
			else
				error("Unexpected optional mat type: "..tostring(data.reagentType)..", "..tostring(data.dataSlotType))
			end
			return index, matType, data.quantityRequired, data.dataSlotIndex, slotText, data.reagents
		end
	end
end

function private.IsValidSpecialMat(data, categorySkillLevel)
	if data.reagentType == Enum.CraftingReagentType.Modifying and data.required then
		return true
	end
	if data.reagentType == Enum.CraftingReagentType.Basic and data.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent then
		-- Pass
	elseif data.reagentType == Enum.CraftingReagentType.Modifying or data.reagentType == Enum.CraftingReagentType.Finishing then
		-- Pass
	else
		return false
	end
	return data.slotInfo.requiredSkillRank <= categorySkillLevel
end

function private.MapDifficulty(value)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		if value == Enum.TradeskillRelativeDifficulty.Optimal then
			return RECIPE_DIFFICULTY.OPTIMAL
		elseif value == Enum.TradeskillRelativeDifficulty.Medium then
			return RECIPE_DIFFICULTY.MEDIUM
		elseif value == Enum.TradeskillRelativeDifficulty.Easy then
			return RECIPE_DIFFICULTY.EASY
		elseif value == Enum.TradeskillRelativeDifficulty.Trivial then
			return RECIPE_DIFFICULTY.TRIVIAL
		else
			error("Unknown difficulty: "..tostring(value))
		end
	else
		if value == "optimal" then
			return RECIPE_DIFFICULTY.OPTIMAL
		elseif value == "medium" then
			return RECIPE_DIFFICULTY.MEDIUM
		elseif value == "easy" then
			return RECIPE_DIFFICULTY.EASY
		elseif value == "trivial" then
			return RECIPE_DIFFICULTY.TRIVIAL
		else
			error("Unknown difficulty: "..tostring(value))
		end
	end
end

function private.GetRootCategoryInfo(categoryId, resultTbl)
	C_TradeSkillUI.GetCategoryInfo(categoryId, resultTbl)
	while not resultTbl.skillLineCurrentLevel and resultTbl.parentCategoryID do
		local parentCategoryId = resultTbl.parentCategoryID
		wipe(resultTbl)
		C_TradeSkillUI.GetCategoryInfo(parentCategoryId, resultTbl)
	end
end

function private.IsValidMatItemLocation(itemLocation)
	local success = pcall(C_Item.DoesItemExist, itemLocation)
	return success
end

function private.GetMissingClassicTools(...)
	local missingTools = nil
	for i = 1, select("#", ...), 2 do
		local name, hasTool = select(i, ...)
		if not hasTool then
			missingTools = missingTools and (missingTools..", "..name) or name
		end
	end
	return missingTools
end

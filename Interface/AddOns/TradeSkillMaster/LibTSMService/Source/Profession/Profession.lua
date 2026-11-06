-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Profession = LibTSMService:Init("Profession")
local CategoryCache = LibTSMService:Include("Profession.CategoryCache")
local CraftInfo = LibTSMService:Include("Profession.CraftInfo")
local Data = LibTSMService:Include("Profession.Data")
local PlayerProfessions = LibTSMService:Include("Profession.PlayerProfessions")
local Quality = LibTSMService:Include("Profession.Quality")
local Scanner = LibTSMService:Include("Profession.Scanner")
local State = LibTSMService:Include("Profession.State")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local EngineeringData = LibTSMService:From("LibTSMData"):Include("Engineering")
local OptionalMat = LibTSMService:From("LibTSMData"):Include("OptionalMat")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMService:From("LibTSMTypes"):Include("Crafting.RecipeString")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Register a callback for when the profession state changes.
---@param callback fun() The callback function
function Profession.RegisterStateCallback(callback)
	State.RegisterCallback(callback)
end

---Registers scanner hook functions.
---@param scanFunc function
---@param inactiveFunc function
function Profession.SetScanHookFuncs(scanFunc, inactiveFunc)
	Scanner.SetHookFuncs(scanFunc, inactiveFunc)
end

---Returns whether or not the profession is closed.
---@return boolean
function Profession.IsClosed()
	return State.IsClosed()
end

---Sets whether the classic crafting UI is open.
---@param open boolean
---TODO: Better way to handle this
function Profession.SetClassicCraftingOpen(open)
	State.SetClassicCraftingOpen(open)
end

---Gets the current stable and open profession info.
---@return string? name
---@return number? skillId
function Profession.GetCurrentProfession()
	return State.GetCurrentProfession()
end

---Gets whether or not a recipe has a cooldown.
---@param craftString string The craft string for the recipe
---@return boolean
function Profession.HasCooldown(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	local hasCooldown = TradeSkill.GetCooldownInfo(spellId)
	return hasCooldown
end

---Gets the remaining cooldown for a recipe.
---@param craftString string The craft string for the recipe
---@return number?
function Profession.GetRemainingCooldown(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	local _, cooldown = TradeSkill.GetCooldownInfo(spellId)
	return cooldown
end

---Gets the range of quantities which the recipe crafts.
---@param craftString string The craft string for the recipe
---@return number lowerBound
---@return number upperBound
function Profession.GetCraftedQuantityRange(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	return TradeSkill.GetNumMade(spellId)
end

---Gets the result of a recipe.
---@param craftString string The craft string for the recipe
---@return string|string[]|nil
---@return number?
function Profession.GetResultItem(craftString)
	return Scanner.GetResultItem(craftString)
end

---Gets the vellum item string to use with a recipe.
---@param craftString string The craft string for the recipe
---@return string
function Profession.GetVellumItemString(craftString)
	return Scanner.GetVellumItemString(craftString)
end

---Gets the number of different result items of a recipe.
---@param craftString string The craft string for the recipe
---@return number
function Profession.GetNumResultItems(craftString)
	return Scanner.GetNumResultItems(craftString)
end

---Gets the result info for a recipe.
---@param craftString string The craft string for the recipe
---@return string? itemString
---@return number? texture
---@return string? name
function Profession.GetResultInfo(craftString)
	-- Get the links
	local resultItem = Profession.GetResultItem(craftString)
	if not resultItem then
		return nil, nil, nil
	end
	if type(resultItem) == "table" then
		local itemLink = resultItem[CraftString.GetQuality(craftString) or 1]
		return ItemString.Get(itemLink), ItemInfo.GetTexture(itemLink), ItemInfo.GetName(itemLink)
	elseif strfind(resultItem, "enchant:") then
		-- Result of craft is not an item
		local spellId = CraftString.GetSpellId(craftString)
		local indirectSpellId = nil
		if LibTSMService.IsMistsClassic() then
			indirectSpellId = strmatch(resultItem, "enchant:(%d+)")
			indirectSpellId = indirectSpellId and tonumber(indirectSpellId)
			if not indirectSpellId then
				return nil, nil, nil
			end
		else
			indirectSpellId = spellId
		end
		local itemString = Data.GetIndirectCraftResult(indirectSpellId)
		if type(itemString) == "table" then
			itemString = itemString[CraftString.GetQuality(craftString) or 1]
		end
		if itemString and not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() then
			return itemString, ItemInfo.GetTexture(itemString), ItemInfo.GetName(itemString)
		elseif EngineeringData.Tinkers[spellId] then
			local name, icon = TradeSkill.GetBasicInfo(spellId)
			return nil, icon, name
		elseif LibTSMService.IsMistsClassic() then
			local name, icon = TradeSkill.GetBasicInfo(indirectSpellId)
			return nil, icon, name
		elseif TradeSkill.IsClassicCrafting() then
			local name, icon = TradeSkill.GetBasicInfo(Scanner.GetClassicSpellId(spellId))
			return nil, icon, name
		else
			local name, icon = TradeSkill.GetBasicInfo(spellId)
			return nil, icon, name
		end
	elseif strfind(resultItem, "item:") then
		-- Result of craft is an item
		return ItemString.Get(resultItem), ItemInfo.GetTexture(resultItem), ItemInfo.GetName(resultItem)
	else
		error("Invalid craft: "..craftString)
	end
end

---Returns whether or not a recipe is an enchant.
---@param craftString string The craft string for the recipe
---@return boolean
function Profession.IsEnchant(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	return TradeSkill.IsEnchant(spellId)
end

---Returns whether or not a recipe is a salvage.
---@param craftString string The craft string for the recipe
---@return boolean
function Profession.IsSalvage(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		return false
	end
	return Scanner.GetRecipeTypeByCraftString(craftString) == TradeSkill.RECIPE_TYPE.SALVAGE
end

---Returns whether or not a recipe is a tinker.
---@param craftString string The craft string for the recipe
---@return boolean
function Profession.IsTinker(craftString)
	return EngineeringData.Tinkers[CraftString.GetSpellId(craftString)]
end

---Gets the needed tools string for a recipe.
---@param craftString string The craft string for the recipe
---@return string?
function Profession.NeededTools(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	return TradeSkill.GetRequiredTool(spellId)
end

---Gets the description for a recipe.
---@param craftString string The craft string for the recipe
---@return string
function Profession.GetRecipeDescription(craftString)
	if not craftString or (not LibTSMService.IsRetail() and not LibTSMService.IsForever()) then
		return ""
	end
	return TradeSkill.GetRecipeDescription(CraftString.GetSpellId(craftString))
end

---Links a recipe into chat.
---@param craftString string The craft string for the recipe
function Profession.LinkRecipe(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = Scanner.GetClassicSpellId(spellId)
	end
	return TradeSkill.LinkRecipe(spellId)
end

---Gets the number of mats for a recipe.
---@param craftString string The craft string for the recipe
---@return number
function Profession.GetNumMats(craftString)
	return CraftInfo.GetNumMats(craftString)
end

---Gets information on a material.
---@param craftString string The craft string for the recipe
---@param index number The index of the material
---@return string? itemString
---@return number? quantity
---@return string? name
---@return boolean? isQualityMat
function Profession.GetMatInfo(craftString, index)
	return Scanner.GetMatInfo(craftString, index)
end

---Returns whether or not the character has all the materials needed for a recipe.
---@param craftString string The craft string
---@return boolean
function Profession.HasMaterials(craftString)
	return CraftInfo.HasMaterials(craftString)
end

---Gets the number of a craft that can be crafted.
---@param craftString string The craft string
---@return number num
---@return number numAll
function Profession.GetNumCraftable(craftString)
	return CraftInfo.GetNumCraftable(craftString)
end

---Returns whether or not the character has the required vellum for enchant crafts.
---@param recipeString string The recipe string
---@return boolean
function Profession.HasVellum(recipeString)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		return false
	end
	local craftString = CraftString.FromRecipeString(recipeString)
	if not Profession.IsEnchant(craftString) then
		return false
	end
	return BagTracking.GetBagQuantity(Scanner.GetVellumItemString(craftString)) > 0
end

---Gets quality info for a quality recipe.
---@param craftString string The craft string for the recipe
---@return number? baseDifficulty
---@return number? quality
---@return boolean? hasQualityMats
---@return number? resourcefulnessChance
---@return number? multicraftChance
function Profession.GetRecipeQualityInfo(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		return nil, nil, nil, nil, nil
	end
	local spellId = CraftString.GetSpellId(craftString)
	return TradeSkill.GetRecipeQualityInfo(spellId)
end

---Sets whether or not the scanner is disabled.
---@param disabled boolean
function Profession.SetScannerDisabled(disabled)
	Scanner.SetDisabled(disabled)
end

---Gets whether or not the profession has been scanned.
---@return boolean
function Profession.HasScanned()
	return Scanner.HasScanned()
end

---Gets whether or not there are skills.
---@return boolean
function Profession.ScannerHasSkills()
	return Scanner.HasSkills()
end

---Registers a callback when the profession is scanned.
---@param callback function
function Profession.RegisterHasScannedCallback(callback)
	Scanner.RegisterHasScannedCallback(callback)
end

---Ignores the next profession update for scanning purposes.
function Profession.IgnoreNextProfessionUpdates()
	Scanner.IgnoreNextProfessionUpdates()
end

---Creates a query for crafts.
---@return DatabaseQuery
function Profession.CreateScannerQuery()
	return Scanner.CreateQuery()
end

---Gets the item string for a craft string.
---@param craftString string
---@return string?
function Profession.GetItemStringByCraftString(craftString)
	return Scanner.GetItemStringByCraftString(craftString)
end

---Gets the index for a craft string.
---@param craftString string
---@return number?
function Profession.GetIndexByCraftString(craftString)
	return Scanner.GetIndexByCraftString(craftString)
end

---Gets the category ID for a craft string.
---@param craftString string
---@return number?
function Profession.GetCategoryIdByCraftString(craftString)
	return Scanner.GetCategoryIdByCraftString(craftString)
end

---Gets the name for a craft string.
---@param craftString string
---@return string?
function Profession.GetNameByCraftString(craftString)
	return Scanner.GetNameByCraftString(craftString)
end

---Gets the craft name for a craft string.
---@param craftString string
---@return string?
function Profession.GetCraftNameByCraftString(craftString)
	return Scanner.GetCraftNameByCraftString(craftString)
end

---Gets the current experience for a craft string.
---@param craftString string
---@return number?
function Profession.GetCurrentExpByCraftString(craftString)
	return Scanner.GetCurrentExpByCraftString(craftString)
end

---Gets the next experience for a craft string.
---@param craftString string
---@return number?
function Profession.GetNextExpByCraftString(craftString)
	return Scanner.GetNextExpByCraftString(craftString)
end

---Gets the difficulty for a craft string.
---@param craftString string
---@return EnumValue?
function Profession.GetDifficultyByCraftString(craftString)
	return Scanner.GetDifficultyByCraftString(craftString)
end

---Checks whether or not a craft string exists.
---@param craftString string
---@return boolean
function Profession.HasCraftString(craftString)
	return Scanner.HasCraftString(craftString)
end

---Returns an iterator for materials of a craft string.
---@param craftString string
---@return IteratorObject<fun(): number, string, number, string> @Iterator with fields: `index`, `matString`, `quantity`, `slotText`
function Profession.MatIterator(craftString)
	return Scanner.MatIterator(craftString)
end

---Gets the mat string for a specified slot id.
---@param craftString string
---@param slotId number
---@return string?
function Profession.GetOptionalMatString(craftString, slotId)
	return Scanner.GetOptionalMatString(craftString, slotId)
end

---Gets the number of optional mats of a given type.
---@param craftString string The craft string
---@param matType table The mat type
---@return number
function Profession.GetNumOptionalMats(craftString, matType)
	return Scanner.GetNumOptionalMats(craftString, matType)
end

---Gets the slot text for a mat within the current profession.
---@param craftString string
---@param matString string
---@return string
function Profession.GetMatSlotText(craftString, matString)
	return Scanner.GetMatSlotText(craftString, matString)
end

---Gets the needed skill to craft a specific quality of a recipe.
---@param targetQuality number The target quality
---@param recipeDifficulty number The base recipe difficulty
---@param recipeQuality number The base recipe quality
---@param recipeMaxQuality number The max number of qualities for the recipe
---@param hasQualityMats boolean Whether or not the recipe has quality mats
---@param maxMatContribution number The max material contribution
---@return (number neededSkill, number maxAddedSkill, number maxQualityMatSkill, number concentration)|(nil, nil, nil, nil)
function Profession.GetNeededSkill(targetQuality, recipeDifficulty, recipeQuality, recipeMaxQuality, hasQualityMats, maxMatContribution)
	return Quality.GetNeededSkill(targetQuality, recipeDifficulty, recipeQuality, recipeMaxQuality, hasQualityMats, maxMatContribution)
end

---Generates an item string from a recipe string.
---@param recipeString string The recipe string
---@param itemString string The base result item string
---@return string
function Profession.GenerateResultItemString(recipeString, itemString)
	local absItemLevel = nil
	for _, _, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
		for _, matItemString in MatQuantityString.Iterator(matQuantityString) do
			local matInfo = OptionalMat.Info[matItemString]
			if matInfo then
				absItemLevel = absItemLevel or matInfo.absItemLevel
			end
		end
	end
	if absItemLevel then
		local baseItemString = ItemString.GetBaseFast(itemString)
		return baseItemString.."::i"..absItemLevel
	else
		return itemString
	end
end

---Check if an optional mat is valid for a given craft and slot.
---@param craftString string The craft string
---@param slotId number The optional mat slot ID
---@param matQuantityString string The matQuantityString to check
---@return boolean
function Profession.IsValidOptionalMat(craftString, slotId, matQuantityString)
	local matString = Profession.GetOptionalMatString(craftString, slotId)
	if not matString then
		return false
	end
	local iter = MatQuantityString.Iterator(matQuantityString)
	for _, itemString in iter do
		if not MatString.ContainsItem(matString, itemString) then
			iter:Release()
			return false
		end
	end
	return true
end

---Gets the parent category ID.
---@param categoryId number The category ID
---@return number?
function Profession.GetParentCategoryId(categoryId)
	return CategoryCache.GetParent(categoryId)
end

---Gets the number of indents for the category.
---@param categoryId number The category ID
---@return number
function Profession.GetCategoryNumIndents(categoryId)
	return CategoryCache.GetNumIndents(categoryId)
end

---Gets the name of the category
---@param categoryId number The category ID
---@return string?
function Profession.GetCategoryName(categoryId)
	return CategoryCache.GetName(categoryId)
end

---Gets the skill level info for the category.
---@param categoryId number The category ID
---@return number? currentSkillLevel
---@return number? maxSkillLevel
function Profession.GetCategorySkillLevel(categoryId)
	return CategoryCache.GetSkillLevel(categoryId)
end

---Checks if a profession is ignored due to it not being a primary profession.
---@param name string The name of the profession
---@param skillId? number The profession skill ID
---@return boolean
function Profession.IsIgnored(name, skillId)
	return Data.IsIgnored(name, skillId)
end

---Loads the player professions settings.
---@param settings PlayerProfessionsSettings The settings object
function Profession.LoadPlayerProfessions(settings)
	PlayerProfessions.Load(settings)
end

---Iterates over the player profession info.
---@return IteratorObject<fun(): number, string, string, number, number, number> @Iterator with fields: `index`, `player`, `profession`, `skillId`, `level`, `maxLevel`
function Profession.PlayerProfessionsIterator()
	return PlayerProfessions.Iterator()
end

---Creates a query for the player professions.
---@return DatabaseQuery
function Profession.CreatePlayerProfessionsQuery()
	return PlayerProfessions.CreateQuery()
end

---Gets the current skill level for a given profession.
---@param profession string The profession name
---@return number?
function Profession.GetSkill(profession)
	return PlayerProfessions.GetSkill(profession)
end

---Returns whether or not the specified character has the specified profession.
---@param character string The character name
---@param profession string The profession name
function Profession.HasProfession(character, profession)
	return PlayerProfessions.HasProfession(character, profession)
end

---Updates the current profession's link.
function Profession.UpdateProfessionLink()
	PlayerProfessions.UpdateLink()
end

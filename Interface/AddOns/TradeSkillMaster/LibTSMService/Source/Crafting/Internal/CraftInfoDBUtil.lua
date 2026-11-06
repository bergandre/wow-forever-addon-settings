-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CraftInfoDBUtil = LibTSMService:InitInternal("Crafting.CraftInfoDBUtil")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = LibTSMService:Include("Inventory.WarbankTracking")
local Profession = LibTSMService:Include("Profession")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMService:From("LibTSMTypes"):Include("Crafting.RecipeString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local private = {
	matDBMatNamesQuery = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CraftInfoDBUtil:OnModuleLoad(function()
	private.matDBMatNamesQuery = CraftInfoDB.NewMatQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "matString", "?")
		:Equal("craftString", Database.BoundQueryParam())
		:GreaterThan("quantity", 0)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not the craft DB has a given item.
---@param itemString string The item string
---@return boolean
function CraftInfoDBUtil.HasCraftedItem(itemString)
	return CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:Equal("itemString", itemString)
		:IsNotEmpty()
end

---Gets the level item string produced by a recipe string.
---@param recipeString string The recipe string
---@return string?
function CraftInfoDBUtil.GetResultLevelItemString(recipeString)
	local craftString = CraftString.FromRecipeString(recipeString)
	if not CraftInfoDB.HasCraftString(craftString) then
		return nil
	end
	return Profession.GenerateResultItemString(recipeString, CraftInfoDB.GetItemString(craftString))
end

---Iterates over the optional mats for a given craft.
---@param craftString string The craft string
---@return IteratorObject<fun(): number, string, number> @Iterator with fields: `index`, `matString`, `slotId`
function CraftInfoDBUtil.OptionalMatIterator(craftString)
	return CraftInfoDB.NewMatQuery()
		:AutoRelease()
		:VirtualField("slotId", "number", MatString.GetSlotId, "matString")
		:Equal("craftString", craftString)
		:Matches("matString", "^[qofr]:")
		:OrderBy("slotId", true)
		:Iterator("matString", "slotId")
end

---Gets the required quantity of an optional material.
---@param craftString string The craft string
---@param itemString string The item string of the material
---@return number
function CraftInfoDBUtil.GetOptionalMatQuantity(craftString, itemString)
	return CraftInfoDB.NewMatQuery()
		:AutoRelease()
		:Equal("craftString", craftString)
		:Matches("matString", "^[qofr]:.*"..ItemString.ToId(itemString))
		:GetFirstResult("quantity")
end

---Iterates over all known craft strings.
---@return IteratorObject<fun(): number, string> @Iterator with fields: `index`, `craftString`
function CraftInfoDBUtil.CraftStringIterator()
	return CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:Iterator("craftString")
end

---Iterates over the mats for a given craft.
---@param craftString string The craft string
---@return IteratorObject<fun(): number, string, number> @Iterator with fields: `index`, `matString`, `quantity`
function CraftInfoDBUtil.MatIterator(craftString)
	return CraftInfoDB.NewMatQuery()
		:AutoRelease()
		:Equal("craftString", craftString)
		:StartsWith("matString", "i:")
		:Iterator("matString", "quantity")
end

---Gets the mat names for a craft as a joined string for each searching.
---@param craftString string The craft string
---@return string
function CraftInfoDBUtil.GetMatNames(craftString)
	return private.matDBMatNamesQuery:BindParams(craftString)
		:JoinedString("name", "")
end

---Iterates over the mats for a recipe string.
---@param recipeString string The recipe string
---@return fun(): number, string, number @Iterator with fields: `index`, `itemString`, `quantity`
---@return table
---@return number
function CraftInfoDBUtil.MatIteratorByRecipeString(recipeString)
	local craftString = CraftString.FromRecipeString(recipeString)
	local result = TempTable.Acquire()
	for _, itemString, quantity in CraftInfoDBUtil.MatIterator(craftString) do
		Table.InsertMultiple(result, itemString, quantity)
	end
	for _, _, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
		for _, itemString, quantity in MatQuantityString.Iterator(matQuantityString) do
			Table.InsertMultiple(result, itemString, quantity)
		end
	end
	return TempTable.Iterator(result, 2)
end

---Acquires the list of crafting reagents for a recipe string.
---@param recipeString string The recipe string
---@return CraftingReagentInfo[]
function CraftInfoDBUtil.AcquireReagents(recipeString)
	local reagents = TempTable.Acquire()
	for _, slotId, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
		for _, itemString, matQuantity in MatQuantityString.Iterator(matQuantityString) do
			local info = TempTable.Acquire()
			info.reagent = info.reagent or {}
			info.reagent.itemID = ItemString.ToId(itemString)
			info.dataSlotIndex = slotId
			info.quantity = matQuantity
			tinsert(reagents, info)
		end
	end
	return reagents
end

---Releases a list of crafting reagents.
---@param reagents CraftingReagentInfo[] The reagents acquired with `CraftInfoDBUtil.AcquireReagents()`
function CraftInfoDBUtil.ReleaseReagents(reagents)
	for _, info in ipairs(reagents) do
		TempTable.Release(info)
	end
	TempTable.Release(reagents)
end

---Gets the concentration cost of a recipe string in the open profession and the amount of concentration the player has.
---@param recipeString string The recipe string
---@return number? cost
---@return number? available
---@return number? currencyId
function CraftInfoDBUtil.GetConcentrationInfo(recipeString)
	if not RecipeString.GetConcentration(recipeString) or not Profession.HasCraftString(CraftString.FromRecipeString(recipeString)) then
		return nil, nil, nil
	end
	local reagents = CraftInfoDBUtil.AcquireReagents(recipeString)
	local cost, available, currencyId = TradeSkill.GetConcentrationInfo(RecipeString.GetSpellId(recipeString), reagents)
	CraftInfoDBUtil.ReleaseReagents(reagents)
	return cost, available, currencyId
end

---Gets the number of a craft that can be crafted.
---@param recipeString string The recipe string
---@return number num
---@return number numAll
function CraftInfoDBUtil.GetNumCraftableRecipeString(recipeString)
	local num, numAll = math.huge, math.huge
	local craftString = CraftString.FromRecipeString(recipeString)
	for i = 1, Profession.GetNumMats(craftString) do
		local itemString, quantity, _, isQuality = Profession.GetMatInfo(craftString, i)
		if not isQuality then
			local totalQuantity = itemString and CustomString.GetSourceValue("NumInventory", itemString) or 0
			if not itemString or not quantity or totalQuantity == 0 then
				return 0, 0
			end
			local bagQuantity = private.GetMatQuantity(itemString)
			num = min(num, floor(bagQuantity / quantity))
			numAll = min(numAll, floor(totalQuantity / quantity))
		end
	end
	for _, _, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
		for _, itemString, quantity in MatQuantityString.Iterator(matQuantityString) do
			local totalQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
			if totalQuantity == 0 then
				return 0, 0
			end
			local bagQuantity = private.GetMatQuantity(itemString)
			num = min(num, floor(bagQuantity / quantity))
			numAll = min(numAll, floor(totalQuantity / quantity))
		end
	end
	if num == math.huge or numAll == math.huge then
		return 0, 0
	end
	return num, numAll
end

---Gets the number which can be crafted based on inventory tracking data.
---@param craftString string The craft string
---@return number
function CraftInfoDBUtil.GetNumCraftableFromDB(craftString)
	local num = math.huge
	for _, itemString, quantity in CraftInfoDBUtil.MatIterator(craftString) do
		num = min(num, floor(private.GetMatQuantity(itemString) / quantity))
	end
	return num == math.huge and 0 or num
end

---Gets the number which can be crafted based on inventory tracking data.
---@param recipeString string The recipe string
---@return number
function CraftInfoDBUtil.GetNumCraftableFromDBRecipeString(recipeString)
	local num = math.huge
	for _, itemString, quantity in CraftInfoDBUtil.MatIteratorByRecipeString(recipeString) do
		num = min(num, floor(private.GetMatQuantity(itemString) / quantity))
	end
	return num == math.huge and 0 or num
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetMatQuantity(itemString)
	return BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
end

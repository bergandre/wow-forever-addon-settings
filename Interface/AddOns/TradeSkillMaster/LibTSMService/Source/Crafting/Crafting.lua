-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Crafting = LibTSMService:Init("Crafting")
local Cost = LibTSMService:Include("Crafting.Cost")
local Craft = LibTSMService:Include("Crafting.Craft")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local CraftInfoDBUtil = LibTSMService:Include("Crafting.CraftInfoDBUtil")
local CraftingSync = LibTSMService:Include("Crafting.CraftingSync")
local IgnoredCooldowns = LibTSMService:Include("Crafting.IgnoredCooldowns")
local Procs = LibTSMService:Include("Crafting.Procs")
local Quality = LibTSMService:Include("Crafting.Quality")
local Queue = LibTSMService:Include("Crafting.Queue")
local Conversions = LibTSMService:Include("Item.Conversions")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMService:From("LibTSMTypes"):Include("Crafting.RecipeString")
local Conversion = LibTSMService:From("LibTSMTypes"):Include("Item.Conversion")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local private = {}
Crafting.SYNC_STATUS = CraftingSync.STATUS
local INDIRECT_RESULT_MATERIALS = {
	["i:194545"] = true -- Prismatic Ore
}

---@class CraftInfo
---@field mats table<string,number>
---@field players table<string,QualityCraftInfo|boolean>
---@field itemString string
---@field name string
---@field profession string
---@field rootCategoryId number
---@field numResult number
---@field hasCD boolean?

---@class QualityCraftInfo
---@field baseRecipeDifficulty number?
---@field baseRecipeQuality number?
---@field maxRecipeQuality number
---@field expectedRefund number?
---@field expectedExtraYield number?

---@class MatInfo
---@field customValue string?



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the crafting module.
---@param craftPriceMethodFunc fun(itemString: string): string A function to get the craft price method for an item
function Crafting.Configure(craftPriceMethodFunc)
	Cost.Configure(craftPriceMethodFunc)
end

---Loads the settings tables.
---@param crafts table<string,CraftInfo> The craft info settings table
---@param mats table<string,MatInfo> The mat info settings table
---@param favoriteCrafts table<string,boolean> The favorite craft info settings table
---@param queue table<string,number> The queue settings table
---@param ignored table<string,true> The ignored cooldowns settings table
---@param mixedQualityThreshold number The threshold for mixed quality mats
function Crafting.Load(crafts, mats, favoriteCrafts, queue, ignored, mixedQualityThreshold)
	CraftInfoDB.Load(crafts, mats, favoriteCrafts)
	Quality.Load(crafts, mixedQualityThreshold)
	Procs.Load(crafts)
	Cost.Load(mats)
	CraftingSync.Load(crafts)
	Queue.Load(crafts, queue)
	IgnoredCooldowns.Load(ignored)
end

---Sets the default mat price method.
---@param matPriceMethod string The mat price method
function Crafting.SetDefaultMatPriceMethod(matPriceMethod)
	Cost.SetDefaultMatPriceMethod(matPriceMethod)
end

---Gets the expected proc rates used for a craft's costs.
---@param craftString string The craft string
---@return number expectedRefund
---@return number expectedExtraYield
function Crafting.GetExpectedProcRates(craftString)
	return Procs.GetExpectedRates(craftString)
end

---Gets the sync status for an account.
---@param account string The account
---@return EnumValue?
function Crafting.GetSyncStatus(account)
	return CraftingSync.GetStatus(account)
end

---Returns whether or not the craft info DB has a given item.
---@param itemString string The item string
---@return boolean
function Crafting.HasCraftedItem(itemString)
	local levelItemString = ItemString.ToLevel(itemString)
	return CraftInfoDBUtil.HasCraftedItem(levelItemString)
end

---Gets the item string for a given craft.
---@param craftString string The craft string
---@return string
function Crafting.GetItemString(craftString)
	return CraftInfoDB.GetItemString(craftString)
end

---Gets the name of a given craft.
---@param craftString string The craft string
---@return string
function Crafting.GetName(craftString)
	return CraftInfoDB.GetName(craftString)
end

---Gets the profession for a given craft.
---@param craftString string The craft string
---@return string
function Crafting.GetProfession(craftString)
	return CraftInfoDB.GetProfession(craftString)
end

---Gets the result quantity for a given craft.
---@param craftString string The craft string
---@return number
function Crafting.GetNumResult(craftString)
	return CraftInfoDB.GetNumResult(craftString)
end

---Iterates over the mats for a given craft.
---@param craftString string The craft string
---@return IteratorObject<fun(): number, string, number> @Iterator with fields: `index`, `itemString`, `quantity`
function Crafting.MatIterator(craftString)
	return CraftInfoDBUtil.MatIterator(craftString)
end

---Iterates over the optional mats for a given craft.
---@param craftString string The craft string
---@return IteratorObject<fun(): number, string, number> @Iterator with fields: `index`, `itemString`, `slotId`
function Crafting.OptionalMatIterator(craftString)
	return CraftInfoDBUtil.OptionalMatIterator(craftString)
end

---Gets the required quantity of an optional material.
---@param craftString string The craft string
---@param itemString string The item string of the material
---@return number
function Crafting.GetOptionalMatQuantity(craftString, itemString)
	return CraftInfoDBUtil.GetOptionalMatQuantity(craftString, itemString)
end

---Sets the custom value of a material.
---@param itemString string The item string
---@param value? string The custom value
function Crafting.SetMatCustomValue(itemString, value)
	CraftInfoDB.SetMatCustomValue(itemString, value)
end

---Creates a mat item query.
---@return DatabaseQuery
function Crafting.CreateMatItemQuery()
	return CraftInfoDB.NewMatItemQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:VirtualField("matCost", "number", private.GetMatCost, "itemString")
		:VirtualField("totalQuantity", "number", private.GetTotalQuantity, "itemString")
end

---Creates a query for crafts which are on cooldown for a given character.
---@param character string The character name
---@return DatabaseQuery
function Crafting.CreateCooldownCraftsQuery(character)
	return CraftInfoDB.NewCraftQuery()
		:Equal("hasCD", true)
		:ListContains("characters", character)
end

---Creates a query for queued crafts.
---@param full? boolean Set the full set of fields (adds `profit` and `levelItemString`)
function Crafting.CreateQueuedCraftsQuery(full)
	local query = Queue.CreateQuery()
		:InnerJoin(CraftInfoDB.GetCraftDBForJoin(), "craftString")
	if full then
		query:VirtualField("profit", "number", private.RecipeStringProfitVirtualField, "recipeString", Math.GetNan())
		query:VirtualField("levelItemString", "string", CraftInfoDBUtil.GetResultLevelItemString, "recipeString", "")
	end
	return query
end

---Creates a query for all crafts.
---@return DatabaseQuery
function Crafting.CreateCraftsQuery()
	return CraftInfoDB.NewCraftQuery()
		:AggregateJoinSummed(Queue.GetDBForJoin(), "craftString", "num")
		:VirtualField("craftingCost", "number", Cost.GetCraftingCostByCraftString, "craftString", Math.GetNan())
		:VirtualField("itemValue", "number", Cost.GetCraftedItemValue, "itemString", Math.GetNan())
		:VirtualField("profit", "number", private.CraftStringProfitVirtualField, "craftString", Math.GetNan())
		:VirtualField("profitPct", "number", private.ProfitPctVirtualField, "craftString")
		:VirtualField("saleRate", "number", private.SaleRateVirtualField, "itemString")
end

---Gets the mat names for a craft as a joined string for each searching.
---@param craftString string The craft string
---@return string
function Crafting.GetMatNames(craftString)
	return CraftInfoDBUtil.GetMatNames(craftString)
end

---Iterates over the mats for a recipe string.
---@param recipeString string The recipe string
---@return fun(): number, string, number @Iterator with fields: `index`, `itemString`, `quantity`
---@return table
---@return number
function Crafting.MatIteratorByRecipeString(recipeString)
	return CraftInfoDBUtil.MatIteratorByRecipeString(recipeString)
end

---Gets the most profitable craft string for an item which doesn't need concentration.
---@param itemString string The item string
---@param character? string An optional character name to filter on
---@param noCD? boolean Don't include crafts with a CD
---@return string? craftString
---@return number? profit
---@return number? craftingCost
function Crafting.GetMostProfitableCraftStringByItem(itemString, character, noCD)
	character = character or ""
	noCD = noCD or false
	local bestCraftString, bestCraftingCost, bestProfit, bestHasCD = nil, nil, nil, nil
	local query = CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:Equal("itemString", itemString)
		:If(character ~= "")
			:ListContains("characters", character)
		:End()
		:If(noCD)
			:Equal("hasCD", false)
		:End()
	for _, craftString, hasCD in query:Iterator("craftString", "hasCD") do
		local craftingCost, _, profit, concentration = Cost.GetCostsByCraftString(craftString)
		if (concentration or 0) == 0 and (not bestCraftString or private.IsCraftStringHigherProfit(craftingCost, profit, hasCD, bestCraftingCost, bestProfit, bestHasCD)) then
			bestCraftString = craftString
			bestCraftingCost = craftingCost
			bestProfit = profit
			bestHasCD = hasCD
		end
	end
	return bestCraftString, bestProfit, bestCraftingCost
end

---Gets the conversion value for an item.
---@param itemString string The item string.
---@param customPrice? string The custom price
---@param method? EnumValue The conversion method
---@return (number value, EnumValue method)|(nil, EnumValue?)
function Crafting.GetConversionsValue(itemString, customPrice, method)
	if not customPrice then
		return nil, nil
	end

	-- Calculate disenchant value first
	if (not method or method == Conversion.METHOD.DISENCHANT) and ItemInfo.IsDisenchantable(itemString) then
		local classId = ItemInfo.GetClassId(itemString)
		local quality = ItemInfo.GetQuality(itemString)
		local itemLevel = LibTSMService.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBaseFast(itemString))
		local expansion = LibTSMService.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
		local value = 0
		if quality and itemLevel and classId then
			for targetItemString in Conversion.DisenchantTargetItemIterator() do
				local amountOfMats = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
				if amountOfMats then
					local matValue = CustomString.GetValue(customPrice, targetItemString)
					if not matValue or matValue == 0 then
						return
					end
					value = value + matValue * amountOfMats
				end
			end
		end

		value = floor(value)
		if value > 0 then
			return value, Conversion.METHOD.DISENCHANT
		end
	end

	-- Calculate other conversion values
	local value = 0
	for targetItemString, rate, _, _, _, targetQuality, sourceQuality, _, targetItemMethod in Conversion.TargetItemsByMethodIterator(itemString, method) do
		method = method or targetItemMethod
		local quality = sourceQuality and Quality.GetExpectedSalvageResult(method, sourceQuality)
		if not targetQuality or targetQuality == quality then
			local matValue = INDIRECT_RESULT_MATERIALS[targetItemString] and Crafting.GetConversionsValue(targetItemString, customPrice, method) or CustomString.GetValue(customPrice, targetItemString)
			value = value + (matValue or 0) * rate
		end
	end

	value = Math.Round(value)
	return value > 0 and value or nil, method
end

---Gets the expected salvage result quality.
---@param method EnumValue The salvage method
---@param sourceQuality number The source item quality
---@return number
function Crafting.GetExpectedSalvageResult(method, sourceQuality)
	return Quality.GetExpectedSalvageResult(method, sourceQuality)
end

---Gets the number of a craft that can be crafted.
---@param recipeString string The recipe string
---@return number num
---@return number numAll
function Crafting.GetNumCraftableRecipeString(recipeString)
	return CraftInfoDBUtil.GetNumCraftableRecipeString(recipeString)
end

---Gets the number which can be crafted based on inventory tracking data.
---@param craftString string The craft string
---@return number
function Crafting.GetNumCraftableFromDB(craftString)
	return CraftInfoDBUtil.GetNumCraftableFromDB(craftString)
end

---Gets the number which can be crafted based on inventory tracking data.
---@param recipeString string The recipe string
---@return number
function Crafting.GetNumCraftableFromDBRecipeString(recipeString)
	return CraftInfoDBUtil.GetNumCraftableFromDBRecipeString(recipeString)
end

---Gets the concentration cost of a recipe string in the open profession and the amount of concentration the player has.
---@param recipeString string The recipe string
---@return number? cost
---@return number? available
---@return number? currencyId
function Crafting.GetConcentrationInfo(recipeString)
	return CraftInfoDBUtil.GetConcentrationInfo(recipeString)
end

---Gets the recipe string for a craft which uses its cheapest quality mats.
---@param craftString string The craft string
---@return string
function Crafting.GetCheapestRecipeString(craftString)
	local mats = TempTable.Acquire()
	local qualityMats = TempTable.Acquire()
	local slotMats = TempTable.Acquire()
	CraftInfoDB.NewMatQuery()
		:Equal("craftString", craftString)
		:AsTable(mats, "matString", "quantity")
		:Release()
	local canCraft, concentration = Quality.GetMats(craftString, mats, qualityMats)
	if not canCraft then
		wipe(qualityMats)
		concentration = nil
	end
	for matString, quantity in pairs(mats) do
		if MatString.GetType(matString) == MatString.TYPE.QUALITY then
			slotMats[MatString.GetSlotId(matString)] = Table.KeyByValue(qualityMats, matString) or MatQuantityString.GetForSingleItem(MatString.GetQualityItem(matString, 1), quantity)
		end
	end
	local recipeString = RecipeString.FromCraftString(craftString, slotMats, concentration)
	TempTable.Release(mats)
	TempTable.Release(qualityMats)
	TempTable.Release(slotMats)
	return recipeString
end

---Gets the quality mats for a given craft quality.
---@param craftString string The craft string
---@param mats table<string,number> The base materials being used
---@param qualityMats table<string,string> The resulting quality mats (key is the matQuantityString, value is the matString)
---@return boolean canCraft
---@return number? concentration
function Crafting.GetQualityMats(craftString, mats, qualityMats)
	return Quality.GetMats(craftString, mats, qualityMats)
end

---Prepares to start a craft.
---@param recipeString string The recipe string
---@param quantity number The desired quantity to craft
---@param salvageSlotId? number The target slot ID to salvage
function Crafting.PrepareCraft(recipeString, quantity, salvageSlotId)
	Craft.Prepare(recipeString, quantity, salvageSlotId)
end

---Executes the specified craft and returns the quantity being crafted.
---@param recipeString string The recipe string
---@param quantity number The desired quantity to craft
---@param useVellum boolean Whether or not to use a vellum
---@param salvageSlotId? number The target slot ID to salvage
---@param callback fun(result: boolean, isDone: boolean) The callback for the craft
---@return number
function Crafting.ExecuteCraft(recipeString, quantity, useVellum, salvageSlotId, callback)
	return Craft.Execute(recipeString, quantity, useVellum, salvageSlotId, callback)
end

---Creates a query against the queue DB.
---@return DatabaseQuery
function Crafting.CreateQueueQuery()
	return Queue.CreateQuery()
end

---Sets the number queued.
---@param recipeString string The recipe string
---@param num number The number to set.
function Crafting.SetNumQueued(recipeString, num)
	Queue.SetNum(recipeString, num)
end

---Gets the number queued.
---@param recipeString string The recipe string
---@return number
function Crafting.GetNumQueued(recipeString)
	return Queue.GetNum(recipeString)
end

---Adjusts the number which are queued.
---@param recipeString string The recipe string
---@param amount number The relative amount
function Crafting.AdjustNumQueued(recipeString, amount)
	Queue.SetNum(recipeString, Queue.GetNum(recipeString) + amount)
end

---Clears the queue.
function Crafting.ClearQueue()
	Queue.Clear()
end

---Gets the queue totals.
---@return number? totalCost
---@return number? totalProfit
---@return number? totalCastTime
function Crafting.GetQueueTotals()
	return Queue.GetTotals()
end

---Returns an iterator which executes to completion with queue DB query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function Crafting.WithQueryUpdatesPaused(func, obj, key)
	return Queue.WithQueryUpdatesPaused(func, obj, key)
end

---Gets the cost of a material.
---@param itemString string The item string
---@return number?
function Crafting.GetMatCost(itemString)
	return Cost.GetMatCost(itemString)
end

---Gets the value of a crafted item.
---@param itemString string The item string
---@return number?
function Crafting.GetCraftedItemValue(itemString)
	return Cost.GetCraftedItemValue(itemString)
end

---Gets the cost info of a craft.
---@param craftString string The craft string
---@return number? craftingCost
---@return number? craftedItemValue
---@return number? profit
---@return number? concentration
function Crafting.GetCostsByCraftString(craftString)
	return Cost.GetCostsByCraftString(craftString)
end

---Gets the cost info of a craft.
---@param recipeString string The recipe string
---@return number? craftingCost
---@return number? craftedItemValue
---@return number? profit
function Crafting.GetCostsByRecipeString(recipeString)
	return Cost.GetCostsByRecipeString(recipeString)
end

---Gets the sale rate of a craft.
---@param craftString string The craft string
---@return number?
function Crafting.GetSaleRateByCraftString(craftString)
	return Cost.GetSaleRateByCraftString(craftString)
end

---Gets the lowest cost for an item.
---@param itemString string The item string
---@param optionalMats? string[] Populated with optional mats that are used
---@param qualityMats? table<string,string> Populated with quality mats that are used
---@return number? cost
---@return string? craftString
---@return number? concentration
function Crafting.GetLowestCostByItem(itemString, optionalMats, qualityMats)
	return Cost.GetLowestCostByItem(itemString, optionalMats, qualityMats)
end

---Creates an ignored cooldowns query.
---@return DatabaseQuery
function Crafting.CreateIgnoredCooldownsQuery()
	return IgnoredCooldowns.CreateQuery()
end

---Returns whether or not a craft is ignored for the current character.
---@param craftString string The craft string
---@return boolean
function Crafting.IsCooldownIgnored(craftString)
	return IgnoredCooldowns.IsIgnored(craftString)
end

---Adds an ignored cooldown for the current character.
---@param craftString string The craft string
function Crafting.AddIgnoredCooldown(craftString)
	IgnoredCooldowns.Add(craftString)
end

---Removes an ignored cooldown.
---@param characterKey string The character key
---@param craftString string The craft string
function Crafting.RemoveIgnoredCooldown(characterKey, craftString)
	IgnoredCooldowns.Remove(characterKey, craftString)
end




-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetTotalQuantity(itemString)
	return CustomString.GetSourceValue("NumInventory", itemString) or 0
end

function private.GetMatCost(itemString)
	return CustomString.GetSourceValue("MatPrice", itemString) or Math.GetNan()
end

function private.ProfitPctVirtualField(craftString)
	local craftingCost, _, profit = Cost.GetCostsByCraftString(craftString)
	return (craftingCost and profit) and floor(profit * 100 / craftingCost) or Math.GetNan()
end

function private.SaleRateVirtualField(itemString)
	return (CustomString.GetValue("DBRegionSaleRate * 1000", itemString) or Math.GetNan()) / 1000
end

function private.RecipeStringProfitVirtualField(recipeString)
	local _, _, profit = Cost.GetCostsByRecipeString(recipeString)
	return profit
end

function private.CraftStringProfitVirtualField(craftString)
	local _, _, profit = Cost.GetCostsByCraftString(craftString)
	return profit
end

function private.IsCraftStringHigherProfit(craftingCost, profit, hasCD, bestCraftingCost, bestProfit, bestHasCD)
	-- No CD is always better than a CD
	if not hasCD and bestHasCD then
		return true
	elseif hasCD and not bestHasCD then
		return false
	end
	-- Order by profit
	if not profit and bestProfit then
		return false
	elseif profit and not bestProfit then
		return true
	elseif profit and bestProfit then
		return profit > bestProfit
	end
	-- Order by crafting cost
	if not craftingCost and bestCraftingCost then
		return false
	elseif craftingCost and not bestCraftingCost then
		return true
	elseif craftingCost and bestCraftingCost then
		return craftingCost < bestCraftingCost
	end
	-- Stick with what we have
	return false
end

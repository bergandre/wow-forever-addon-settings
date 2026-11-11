-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Cost = LibTSMService:InitInternal("Crafting.Cost")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local CraftInfoDBUtil = LibTSMService:Include("Crafting.CraftInfoDBUtil")
local Procs = LibTSMService:Include("Crafting.Procs")
local Quality = LibTSMService:Include("Crafting.Quality")
local OptionalMatData = LibTSMService:From("LibTSMData"):Include("OptionalMat")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local RecipeString = LibTSMService:From("LibTSMTypes"):Include("Crafting.RecipeString")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local private = {
	matSettingsTable = nil,
	matPriceMethod = nil, ---@type string
	craftPriceMethodFunc = nil,
	matDBAllMatsQuery = nil,
	matsVisited = {},
	matsTemp = {},
	matsTempInUse = false,
	currentMatProfession = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Cost:OnModuleLoad(function()
	private.matDBAllMatsQuery = CraftInfoDB.NewMatQuery()
		:Equal("craftString", Database.BoundQueryParam())
end)


-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the cost settings tables.
---@param mats table<string,MatInfo> The mat info settings table
function Cost.Load(mats)
	private.matSettingsTable = mats
end

---Configures the cost module.
---@param craftPriceMethodFunc fun(itemString: string): string A function to get the craft price method for an item
function Cost.Configure(craftPriceMethodFunc)
	private.craftPriceMethodFunc = craftPriceMethodFunc
end

---Sets the default mat price method.
---@param matPriceMethod string The mat price method
function Cost.SetDefaultMatPriceMethod(matPriceMethod)
	private.matPriceMethod = matPriceMethod
end

---Gets the cost of a material.
---@param itemString string The item string
---@return number?
function Cost.GetMatCost(itemString)
	itemString = ItemString.GetBaseFast(itemString)
	if not private.matSettingsTable[itemString] then
		return
	end
	if private.matsVisited[itemString] then
		-- There's a loop in the mat cost, so bail
		return
	end
	private.matsVisited[itemString] = true
	local priceStr = private.matSettingsTable[itemString].customValue or private.matPriceMethod
	local result = CustomString.GetValue(priceStr, itemString)
	private.matsVisited[itemString] = nil
	return result
end

---Gets the crafting cost of a craft.
---@param craftString string The craft string
---@param optionalMats? string[] Optional mats being used
---@param qualityMats? string[]|table<string,number> Quality mats being used
---@return number? cost
---@return number? concentration
function Cost.GetCraftingCostByCraftString(craftString, optionalMats, qualityMats)
	local releaseQualityMats = false
	if not qualityMats then
		qualityMats = TempTable.Acquire()
		releaseQualityMats = true
	end
	local cost, concentration = private.GetCraftingCostHelper(craftString, nil, optionalMats, qualityMats)
	if releaseQualityMats then
		TempTable.Release(qualityMats)
	end
	return cost, concentration
end

---Gets the value of a crafted item.
---@param itemString string The item string
---@return number?
function Cost.GetCraftedItemValue(itemString)
	local value = CustomString.GetValue(private.craftPriceMethodFunc(itemString), itemString)
	return value
end

---Gets the cost info of a craft.
---@param craftString string The craft string
---@return number? craftingCost
---@return number? craftedItemValue
---@return number? profit
---@return number? concentration
function Cost.GetCostsByCraftString(craftString)
	if not CraftInfoDB.HasCraftString(craftString) then
		return nil, nil, nil, nil
	end
	local craftingCost, concentration = Cost.GetCraftingCostByCraftString(craftString)
	local itemString = CraftInfoDB.GetItemString(craftString)
	local craftedItemValue = Cost.GetCraftedItemValue(itemString) or nil
	return craftingCost, craftedItemValue, craftingCost and craftedItemValue and (craftedItemValue - craftingCost) or nil, concentration
end

---Gets the cost info of a craft.
---@param recipeString string The recipe string
---@return number? craftingCost
---@return number? craftedItemValue
---@return number? profit
function Cost.GetCostsByRecipeString(recipeString)
	local craftString = CraftString.FromRecipeString(recipeString)
	local craftingCost = private.GetCraftingCostHelper(craftString, recipeString)
	local itemString = CraftInfoDBUtil.GetResultLevelItemString(recipeString)
	local craftedItemValue = itemString and Cost.GetCraftedItemValue(itemString) or nil
	return craftingCost, craftedItemValue, craftingCost and craftedItemValue and (craftedItemValue - craftingCost) or nil
end

---Gets the sale rate of a craft.
---@param craftString string The craft string
---@return number?
function Cost.GetSaleRateByCraftString(craftString)
	if not CraftInfoDB.HasCraftString(craftString) then
		return nil
	end
	return CustomString.GetSourceValue("DBRegionSaleRate", CraftInfoDB.GetItemString(craftString))
end

---Gets the lowest cost for an item.
---@param itemString string The item string
---@param optionalMats? string[] Populated with optional mats that are used
---@param qualityMats? table<string,string> Populated with quality mats that are used
---@return number? cost
---@return string? craftString
---@return number? concentration
function Cost.GetLowestCostByItem(itemString, optionalMats, qualityMats)
	local levelItemString = ItemString.ToLevel(itemString)
	local craftedItemString, levelMatItemString = CraftInfoDBUtil.GetCraftedItemString(levelItemString)
	local shouldReleaseOptionalMats = false
	if not optionalMats then
		shouldReleaseOptionalMats = true
		optionalMats = TempTable.Acquire()
	end
	private.GetOptionalMats(itemString, optionalMats)
	local lowestCost, lowestCraftString, lowestConcentration = nil, nil, nil
	local cdCost, cdSpellId, cdConcentration = nil, nil, nil
	local numSpells = 0
	local singleCraftString = nil
	local tempQualityMats = TempTable.Acquire()
	local cdQualityMats = TempTable.Acquire()
	for _, craftString, hasCD, profession in private.CraftStringByItemIterator(craftedItemString) do
		if not private.currentMatProfession or not OptionalMatData.Info[levelItemString] or private.currentMatProfession == profession then
			if not CraftString.GetLevel(craftString) and (not levelMatItemString or CraftInfoDBUtil.HasOptionalMat(craftString, levelMatItemString)) then
				if not hasCD then
					if singleCraftString == nil then
						singleCraftString = craftString
					elseif singleCraftString then
						singleCraftString = 0
					end
				end
				numSpells = numSpells + 1
				wipe(tempQualityMats)
				local cost, concentration = Cost.GetCraftingCostByCraftString(craftString, optionalMats, tempQualityMats)
				if cost and (not lowestCost or cost < lowestCost) then
					-- Exclude spells with cooldown if option to ignore is enabled and there is more than one way to craft
					if hasCD then
						cdCost = cost
						cdSpellId = craftString
						cdConcentration = concentration
						wipe(cdQualityMats)
						Table.CopyFrom(cdQualityMats, tempQualityMats)
					else
						if qualityMats then
							wipe(qualityMats)
							Table.CopyFrom(qualityMats, tempQualityMats)
						end
						lowestCost = cost
						lowestCraftString = craftString
						lowestConcentration = concentration
					end
				end
			end
		end
	end
	TempTable.Release(tempQualityMats)
	if shouldReleaseOptionalMats then
		TempTable.Release(optionalMats)
	end
	if singleCraftString == 0 then
		singleCraftString = nil
	end
	if numSpells == 1 and not lowestCost and cdCost then
		-- Only way to craft it is with a CD craft, so use that
		if qualityMats then
			wipe(qualityMats)
			Table.CopyFrom(qualityMats, cdQualityMats)
		end
		lowestCost = cdCost
		lowestCraftString = cdSpellId
		lowestConcentration = cdConcentration
	end
	TempTable.Release(cdQualityMats)
	return lowestCost, lowestCraftString or singleCraftString --[[@as string?]], lowestConcentration
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CraftStringByItemIterator(itemString)
	return CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:Equal("itemString", itemString)
		:Iterator("craftString", "hasCD", "profession")
end

function private.GetOptionalMats(itemString, resultTbl)
	-- Get the state modifiers and temporarily store in the result table before mapping into matQuantityStrings
	ItemString.GetStatModifiers(itemString, true, resultTbl)
	for i = #resultTbl, 1, -1 do
		local statOptionalMat = nil
		for optionalMatItemString, info in pairs(OptionalMatData.Info) do
			if info.statModifier == resultTbl[i] then
				statOptionalMat = optionalMatItemString
				break
			end
		end
		if statOptionalMat then
			resultTbl[i] = MatQuantityString.GetForSingleItem(statOptionalMat, 1)
		else
			tremove(resultTbl, i)
		end
	end
	local itemLevel = ItemString.GetItemLevel(itemString)
	if itemLevel then
		for optionalMatItemString, info in pairs(OptionalMatData.Info) do
			if info.absItemLevel == itemLevel then
				tinsert(resultTbl, MatQuantityString.GetForSingleItem(optionalMatItemString, 1))
				break
			end
		end
	end
end

function private.GetCraftingCostHelper(craftString, recipeString, optionalMats, qualityMats)
	if not CraftInfoDB.HasCraftString(craftString) then
		return nil, nil
	end
	local cost = 0
	local nonRefundableCost = 0
	local nonRefundableMats = nil
	local hasMats = false
	local mats = nil
	if private.matsTempInUse then
		mats = TempTable.Acquire()
	else
		mats = private.matsTemp
		private.matsTempInUse = true
		wipe(mats)
	end
	private.GetMatsAsTable(craftString, mats)
	local concentration = 0
	if recipeString then
		assert(not optionalMats)
		for _, _, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
			for _, matItemString, matQuantity in MatQuantityString.Iterator(matQuantityString) do
				local optionalMatItemId = ItemString.ToId(matItemString)
				local matchStr1 = "[:,]"..optionalMatItemId.."$"
				local matchStr2 = "[:,]"..optionalMatItemId..","
				for itemString in pairs(mats) do
					if (strmatch(itemString, matchStr1) or strmatch(itemString, matchStr2)) then
						mats[matItemString] = (mats[matItemString] or 0) + matQuantity
						nonRefundableMats = private.AddNonRefundableMat(nonRefundableMats, itemString, matItemString)
						break
					end
				end
			end
		end
	else
		local canCraft, craftConcentration = Quality.GetMats(craftString, mats, qualityMats)
		if not canCraft then
			if mats == private.matsTemp then
				private.matsTempInUse = false
			else
				TempTable.Release(mats)
			end
			return nil, nil
		end
		concentration = craftConcentration or 0
		if optionalMats and not Quality.IsQualityCraft(craftString) then
			for _, matQuantityString in pairs(optionalMats) do
				for _, optionalMatItemString in MatQuantityString.Iterator(matQuantityString) do
					local optionalMatItemId = ItemString.ToId(optionalMatItemString)
					local matchStr1 = "[:,]"..optionalMatItemId.."$"
					local matchStr2 = "[:,]"..optionalMatItemId..","
					for itemString, quantity in pairs(mats) do
						if (strmatch(itemString, matchStr1) or strmatch(itemString, matchStr2)) then
							mats[optionalMatItemString] = ((mats[optionalMatItemString] or 0) + 1) * quantity
							nonRefundableMats = private.AddNonRefundableMat(nonRefundableMats, itemString, optionalMatItemString)
							break
						end
					end
				end
			end
		end
		for itemString in pairs(qualityMats) do
			assert(MatQuantityString.IsString(itemString))
			for _, matItemString, quantity in MatQuantityString.Iterator(itemString) do
				mats[matItemString] = quantity
			end
		end
	end
	local didSetProfession = false
	if not private.currentMatProfession then
		private.currentMatProfession = CraftInfoDB.GetProfession(craftString)
		didSetProfession = true
	end
	for itemString, quantity in pairs(mats) do
		if MatString.GetType(itemString) == MatString.TYPE.NORMAL then
			hasMats = true
			local matCost = CustomString.GetSourceValue("MatPrice", itemString)
			if not matCost then
				cost = nil
			elseif cost then
				if nonRefundableMats and nonRefundableMats[itemString] then
					nonRefundableCost = nonRefundableCost + matCost * quantity
				else
					cost = cost + matCost * quantity
				end
			end
		end
	end
	if didSetProfession then
		private.currentMatProfession = nil
	end
	if mats == private.matsTemp then
		private.matsTempInUse = false
	else
		TempTable.Release(mats)
	end
	if nonRefundableMats then
		TempTable.Release(nonRefundableMats)
	end
	if not cost or not hasMats then
		return nil, concentration
	end
	local expectedRefund, expectedExtraYield = Procs.GetExpectedRates(craftString)
	cost = Math.Round((cost * (1 - expectedRefund) + nonRefundableCost) / (CraftInfoDB.GetNumResult(craftString) * (1 + expectedExtraYield)))
	return cost > 0 and cost or nil, concentration
end

function private.AddNonRefundableMat(nonRefundableMats, matString, matItemString)
	local matType = MatString.GetType(matString)
	if matType ~= MatString.TYPE.OPTIONAL and matType ~= MatString.TYPE.FINISHING then
		return nonRefundableMats
	end
	nonRefundableMats = nonRefundableMats or TempTable.Acquire()
	nonRefundableMats[matItemString] = true
	return nonRefundableMats
end

function private.GetMatsAsTable(craftString, mats)
	private.matDBAllMatsQuery
		:BindParams(craftString)
		:AsTable(mats, "matString", "quantity")
end

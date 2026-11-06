-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local RecipeString = LibTSMTypes:Init("Crafting.RecipeString")
local MatQuantityString = LibTSMTypes:Include("Crafting.MatQuantityString")
local OrderedTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.OrderedTable")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	partsTemp = {}, ---@type OrderedTable.Table<string,number>
	iterTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a recipe string from a craft string.
---@param craftString string The recipe string
---@param optionalMats? table<number,string> The optional materials (slotId -> matQuantityString table)
---@param concentration? number The amount of concentration to use
---@return string
function RecipeString.FromCraftString(craftString, optionalMats, concentration)
	local spellId = strmatch(craftString, "^c:(%d+)")
	spellId = spellId and tonumber(spellId) or nil
	assert(spellId)
	local rank = strmatch(craftString, ":r(%d)$")
	rank = rank and tonumber(rank) or nil
	local level = strmatch(craftString, ":l(%d)$")
	level = level and tonumber(level) or nil
	local quality = strmatch(craftString, ":q(%d)$")
	quality = quality and tonumber(quality) or nil
	return private.Create(spellId, optionalMats, rank, level, quality, concentration)
end

---Gets the spell ID from the recipe string.
---@param recipeString string The recipe string
---@return number
function RecipeString.GetSpellId(recipeString)
	local spellId = tonumber(strmatch(recipeString, "^r:(%d+)"))
	assert(spellId)
	return spellId
end

---Gets the rank from the recipe string.
---@param recipeString string The recipe string
---@return number?
function RecipeString.GetRank(recipeString)
	local rank = strmatch(recipeString, ":r(%d)$")
	return tonumber(rank)
end

---Gets the level from the recipe string.
---@param recipeString string The recipe string
---@return number?
function RecipeString.GetLevel(recipeString)
	local level = strmatch(recipeString, ":l(%d)$")
	return tonumber(level)
end

---Gets the quality from the recipe string.
---@param recipeString string The recipe string
---@return number?
function RecipeString.GetQuality(recipeString)
	local quality = strmatch(recipeString, ":q(%d)$")
	return tonumber(quality)
end

---Gets the quality from the recipe string.
---@param recipeString string The recipe string
---@return number?
function RecipeString.GetConcentration(recipeString)
	local _, concentration = private.ParseOptionalMats(recipeString)
	return concentration
end

---Iterates over the optional mats within the recipe string.
---@param recipeString string The recipe string
---@return fun():number, number, string @Iterator with fields: `index`, `slotId`, `matQuantityString`
---@return table
---@return number
function RecipeString.OptionalMatIterator(recipeString)
	local optionalMatsStr = private.ParseOptionalMats(recipeString)
	wipe(private.iterTemp)
	local nextIsSlotId = true
	for partStr in String.SplitIterator(optionalMatsStr, ":") do
		if nextIsSlotId then
			local slotId = tonumber(partStr)
			assert(slotId)
			tinsert(private.iterTemp, slotId)
		else
			tinsert(private.iterTemp, partStr)
		end
		nextIsSlotId = not nextIsSlotId
	end
	assert(nextIsSlotId)
	return Table.StrideIterator(private.iterTemp, 2)
end

---Returns whether or not the recipe string includes optional materials.
---@param recipeString string The recipe string
---@return boolean
function RecipeString.HasOptionalMats(recipeString)
	return private.ParseOptionalMats(recipeString) ~= ""
end

---Returns the optional mat's matQuantityString for the specified slotId.
---@param recipeString string The recipe string
---@param slotId number The slotId
---@return string?
function RecipeString.GetOptionalMat(recipeString, slotId)
	for _, matSlotId, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
		if matSlotId == slotId then
			return matQuantityString
		end
	end
	return nil
end

---Gets a new recipe string with the specified optional mats.
---@param recipeString string The recipe string
---@param optionalMats table<number,string> The optional materials (slotId -> matQuantityString table)
function RecipeString.SetOptionalMats(recipeString, optionalMats)
	local spellId = RecipeString.GetSpellId(recipeString)
	local level = RecipeString.GetLevel(recipeString)
	local rank = RecipeString.GetRank(recipeString)
	local quality = RecipeString.GetQuality(recipeString)
	local concentration = RecipeString.GetConcentration(recipeString)
	return private.Create(spellId, optionalMats, rank, level, quality, concentration)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param spellId number
---@param optionalMats? table<number,string>
---@param rank? number
---@param level? number
---@param quality? number
---@param concentration? number
---@return string
function private.Create(spellId, optionalMats, rank, level, quality, concentration)
	local recipeString = "r:"..spellId
	local suffix = ""
	if rank then
		assert(not level and not quality)
		suffix = ":r"..rank
	end
	if level then
		assert(not rank and not quality)
		suffix = ":l"..level
	end
	if quality then
		assert(not rank and not level)
		suffix = ":q"..quality
	end
	if (concentration or 0) > 0 then
		suffix = ":c"..concentration..suffix
	end
	if optionalMats and next(optionalMats) then
		assert(not next(private.partsTemp))
		for slotId, matQuantityString in pairs(optionalMats) do
			assert(MatQuantityString.IsString(matQuantityString))
			local part = slotId..":"..matQuantityString
			OrderedTable.Insert(private.partsTemp, part, slotId)
		end
		OrderedTable.SortByValues(private.partsTemp)
		suffix = ":"..OrderedTable.ConcatKeys(private.partsTemp, ":")..suffix
		Table.WipeAndDeallocate(private.partsTemp)
	end
	return recipeString..suffix
end

function private.ParseOptionalMats(recipeString)
	local concentration = nil
	if strfind(recipeString, ":c%d+$") or strfind(recipeString, ":c%d+:") then
		recipeString, concentration = strmatch(recipeString, "^(.+):c(%d+)")
		concentration = tonumber(concentration)
		assert(recipeString and concentration and concentration > 0)
	end
	recipeString = gsub(recipeString, ":[lrq]%d$", "")
	local optionalMatsStr = strmatch(recipeString, "^r:%d+:?(.*)")
	assert(optionalMatsStr)
	return optionalMatsStr, concentration
end

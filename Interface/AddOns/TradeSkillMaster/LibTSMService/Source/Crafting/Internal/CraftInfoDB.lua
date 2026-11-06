-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CraftInfoDB = LibTSMService:InitInternal("Crafting.CraftInfoDB")
local Salvage = LibTSMService:From("LibTSMData"):Include("Salvage")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local CustomString = LibTSMService:From("LibTSMTypes"):Include("CustomString")
local Conversion = LibTSMService:From("LibTSMTypes"):Include("Item.Conversion")
local private = {
	craftDB = nil,
	matDB = nil,
	matItemDB = nil,
	matDBSpellIdQuery = nil,
	craftSettingsTable = nil,
	matSettingsTable = nil,
	favoriteCraftSettingsTable = nil,
	numMatDBRows = {},
	numCraftsBySpellId = {},
	characterTemp = {},
	removeTemp = {},
	professionTemp = {},
	usedMatsTemp = {},
	updatesTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CraftInfoDB:OnModuleLoad(function()
	private.craftDB = Database.NewSchema("CRAFTING_CRAFTS")
		:AddUniqueStringField("craftString")
		:AddStringField("itemString")
		:AddStringField("name")
		:AddStringField("profession")
		:AddNumberField("numResult")
		:AddStringListField("characters")
		:AddBooleanField("hasCD")
		:AddIndex("itemString")
		:AddIndex("profession")
		:Commit()
	private.matDB = Database.NewSchema("CRAFTING_MATS")
		:AddStringField("craftString")
		:AddStringField("matString")
		:AddNumberField("quantity")
		:AddIndex("craftString")
		:AddIndex("matString")
		:Commit()
	private.matItemDB = Database.NewSchema("CRAFTING_MAT_ITEMS")
		:AddUniqueStringField("itemString")
		:AddStringListField("professions")
		:AddStringField("customValue")
		:Commit()

	private.matDBSpellIdQuery = private.matDB:NewOwnedQuery()
		:Equal("craftString", Database.BoundQueryParam())
end)


-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the craft info DB from the settings tables.
---@param crafts table<string,CraftInfo> The craft info settings table
---@param mats table<string,MatInfo> The mat info settings table
---@param favoriteCrafts table<string,boolean> The favorite craft info settings table
function CraftInfoDB.Load(crafts, mats, favoriteCrafts)
	private.craftSettingsTable = crafts
	private.matSettingsTable = mats
	private.favoriteCraftSettingsTable = favoriteCrafts
	private.SanitizeSettingsTables()
	private.LoadData()
end

---Upserts a craft in the DB.
---@param craftString string The craft string
---@param itemString string The item string
---@param profession string The profession name
---@param rootCategoryId number The root category ID
---@param name string The craft name
---@param numResult number The result quantity
---@param character string The character name
---@param hasCD boolean Whether or not the craft has a CD
---@param baseRecipeDifficulty? number The base recipe difficulty
---@param baseRecipeQuality? number The base recipe quality
---@param maxRecipeQuality number The max recipe quality
function CraftInfoDB.Upsert(craftString, itemString, profession, rootCategoryId, name, numResult, character, hasCD, baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality)
	local craftInfo = private.craftSettingsTable[craftString]
	if craftInfo then
		CraftInfoDB.UpsertCharacter(craftString, character, baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality)
		assert(not next(private.updatesTemp))
		if itemString ~= craftInfo.itemString then
			craftInfo.itemString = itemString
			private.updatesTemp.itemString = itemString
		end
		if profession ~= craftInfo.profession then
			craftInfo.profession = profession
			private.updatesTemp.profession = profession
		end
		craftInfo.rootCategoryId = rootCategoryId
		if name ~= craftInfo.name then
			craftInfo.name = name
			private.updatesTemp.name = name
		end
		if numResult ~= craftInfo.numResult then
			craftInfo.numResult = numResult
			private.updatesTemp.numResult = numResult
		end
		if (hasCD or nil) ~= craftInfo.hasCD then
			craftInfo.hasCD = hasCD or nil
			private.updatesTemp.hasCD = hasCD
		end
		if next(private.updatesTemp) then
			private.craftDB:UpdateRow(private.craftDB:GetUniqueRow("craftString", craftString), private.updatesTemp)
		end
		wipe(private.updatesTemp)
		local baseCraftString = CraftString.Get(CraftString.GetSpellId(craftString))
		if craftString ~= baseCraftString and private.craftDB:HasUniqueRow("craftString", baseCraftString) then
			private.craftDB:DeleteRow(private.craftDB:GetUniqueRow("craftString", baseCraftString))
			assert(private.craftSettingsTable[baseCraftString])
			private.craftSettingsTable[baseCraftString] = nil
			private.HandleCraftStringRemoved(baseCraftString)
		end
	else
		private.craftSettingsTable[craftString] = {
			mats = {},
			players = {
				[character] = (LibTSMService.IsRetail() or LibTSMService.IsForever()) and {
					baseRecipeDifficulty = baseRecipeDifficulty,
					baseRecipeQuality = baseRecipeQuality,
					maxRecipeQuality = maxRecipeQuality,
				} or true,
			},
			itemString = itemString,
			name = name,
			profession = profession,
			rootCategoryId = rootCategoryId,
			numResult = numResult,
			hasCD = hasCD,
		}
		private.HandleCraftStringAdded(craftString)
		assert(not next(private.characterTemp))
		tinsert(private.characterTemp, character)
		private.craftDB:InsertRow(craftString, itemString, name, profession, numResult, private.characterTemp, hasCD)
		wipe(private.characterTemp)
	end
end

---Upserts character data for a given craft.
---@param craftString string The craft string
---@param character string The character name
---@param baseRecipeDifficulty? number The base difficulty
---@param baseRecipeQuality? number The base quality
---@param maxRecipeQuality? number The max quality
function CraftInfoDB.UpsertCharacter(craftString, character, baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality)
	local craftInfo = private.craftSettingsTable[craftString]
	if not craftInfo.players[character] then
		assert(not next(private.characterTemp))
		Table.InsertFromIterator(private.characterTemp, CraftInfoDB.CharacterIterator(craftString))
		assert(not tContains(private.characterTemp, character))
		assert(#private.characterTemp > 0)
		tinsert(private.characterTemp, character)
		private.craftDB:UpdateRow(private.craftDB:GetUniqueRow("craftString", craftString), "characters", private.characterTemp)
		wipe(private.characterTemp)
	end
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		-- Update the quality info
		craftInfo.players[character] = type(craftInfo.players[character]) == "table" and craftInfo.players[character] or {}
		craftInfo.players[character].baseRecipeDifficulty = baseRecipeDifficulty
		craftInfo.players[character].baseRecipeQuality = baseRecipeQuality
		craftInfo.players[character].maxRecipeQuality = maxRecipeQuality
	else
		craftInfo.players[character] = true
	end
end

---Sets the expected proc rates of a character for a given craft.
---@param craftString string The craft string
---@param character string The character name
---@param expectedRefund? number The expected fraction of required mats refunded per craft
---@param expectedExtraYield? number The expected fraction of extra items created per craft
function CraftInfoDB.SetExpectedProcRates(craftString, character, expectedRefund, expectedExtraYield)
	local info = private.craftSettingsTable[craftString].players[character]
	if type(info) ~= "table" then
		return
	end
	info.expectedRefund = expectedRefund
	info.expectedExtraYield = expectedExtraYield
end

---Gets the expected proc rates of a character for a given craft.
---@param craftString string The craft string
---@param character string The character name
---@return number? expectedRefund
---@return number? expectedExtraYield
function CraftInfoDB.GetExpectedProcRates(craftString, character)
	local craftInfo = private.craftSettingsTable[craftString]
	local info = craftInfo and craftInfo.players[character] or nil
	if type(info) ~= "table" then
		return nil, nil
	end
	return info.expectedRefund, info.expectedExtraYield
end

---Sets the mats for a given craft.
---@param craftString string The craft string
---@param matQuantities table<string,number> The mats and their quantities
function CraftInfoDB.SetMats(craftString, matQuantities)
	if Table.Equal(private.craftSettingsTable[craftString].mats, matQuantities) then
		-- Nothing changed
		return
	end

	for matString in pairs(matQuantities) do
		local matType = MatString.GetType(matString)
		if matType == MatString.TYPE.NORMAL then
			private.matSettingsTable[matString] = private.matSettingsTable[matString] or {}
		else
			for matItemString in MatString.ItemIterator(matString) do
				private.matSettingsTable[matItemString] = private.matSettingsTable[matItemString] or {}
			end
		end
	end

	wipe(private.craftSettingsTable[craftString].mats)
	for matString, quantity in pairs(matQuantities) do
		private.craftSettingsTable[craftString].mats[matString] = quantity
	end

	for _ in private.matDB:WithQueryUpdatesPaused() do
		assert(not next(private.usedMatsTemp))
		private.matDBSpellIdQuery:BindParams(craftString)
		for uuid, matString in private.matDBSpellIdQuery:Iterator("matString") do
			local quantity = matQuantities[matString]
			if not quantity then
				-- Remove this row
				private.matDB:DeleteRow(uuid)
				private.HandleMatDBDeleteRow(matString)
			else
				private.usedMatsTemp[matString] = true
				private.matDB:UpdateRow(uuid, "quantity", quantity)
			end
		end
		local profession = CraftInfoDB.GetProfession(craftString)
		for matString, quantity in pairs(matQuantities) do
			if not private.usedMatsTemp[matString] then
				private.matDB:InsertRow(craftString, matString, quantity)
				private.HandleMatDBAddRow(matString)
				for itemString in MatString.ItemIterator(matString) do
					private.MatItemDBUpdateOrInsert(itemString, profession)
				end
			end
		end
		Table.WipeAndDeallocate(private.usedMatsTemp)
	end
end

---Removes a list of characters from a given craft.
---@param craftString string The craft string
---@param charactersToRemove table<string,true> The characters to remove
function CraftInfoDB.RemoveCraftCharacters(craftString, charactersToRemove)
	assert(not next(private.characterTemp))
	Table.InsertFromIterator(private.characterTemp, CraftInfoDB.CharacterIterator(craftString))
	for i, character in Table.ReverseIPairs(private.characterTemp) do
		if charactersToRemove[character] then
			private.craftSettingsTable[craftString].players[character] = nil
			tremove(private.characterTemp, i)
		end
	end
	local uuid = private.craftDB:GetUniqueRow("craftString", craftString)
	if #private.characterTemp > 0 then
		private.craftDB:UpdateRow(uuid, "characters", private.characterTemp)
		wipe(private.characterTemp)
	else
		-- No more players so remove this spell and all its mats
		wipe(private.characterTemp)
		private.craftDB:DeleteRow(uuid)
		assert(private.craftSettingsTable[craftString])
		private.craftSettingsTable[craftString] = nil
		private.HandleCraftStringRemoved(craftString)
		private.MatDBDeleteCraftStrings(craftString)
	end
end

---Removes a list of crafts for a given character.
---@param character string The character name
---@param craftStrings string[] The craft strings to remove
function CraftInfoDB.RemoveCharacterCrafts(character, craftStrings)
	local query = private.craftDB:NewOwnedQuery()
		:AutoPauseDBQueryUpdates()
		:InTable("craftString", craftStrings)
		:ListContains("characters", character)
	local numCrafts = query:Count()
	if numCrafts == 0 then
		query:Release()
		return
	end
	Log.Info("Removing %d crafts", numCrafts)
	assert(not next(private.removeTemp))
	for uuid, craftString, charactersIter in query:Iterator("craftString", "characters") do
		assert(not next(private.characterTemp))
		Table.InsertFromIterator(private.characterTemp, charactersIter)
		if #private.characterTemp == 1 then
			-- The current player was the only player, so we'll delete the entire row and all its mats
			private.removeTemp[craftString] = true
			tinsert(private.removeTemp, uuid)
			private.craftSettingsTable[craftString] = nil
			private.HandleCraftStringRemoved(craftString)
		else
			-- Remove this player from the row
			assert(Table.RemoveByValue(private.characterTemp, character) == 1)
			private.craftDB:UpdateRow(uuid, "characters", private.characterTemp)
			private.craftSettingsTable[craftString].players[character] = nil
		end
		wipe(private.characterTemp)
	end
	private.craftDB:DeleteRow(private.removeTemp)
	query:Release()

	private.MatDBDeleteCraftStrings(private.removeTemp)
	Table.WipeAndDeallocate(private.removeTemp)
end

---Returns an iterator which executes to completion with craft DB query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function CraftInfoDB.WithCraftDBQueryUpdatesPaused(func, obj, key)
	return private.craftDB:WithQueryUpdatesPaused(func, obj, key)
end

---Returns whether or not the craft DB has a given craft string.
---@param craftString string The craft string
---@return boolean
function CraftInfoDB.HasCraftString(craftString)
	return private.craftDB:HasUniqueRow("craftString", craftString)
end

---Gets the item string for a given craft.
---@param craftString string The craft string
---@return string
function CraftInfoDB.GetItemString(craftString)
	return private.GetCraftDBField(craftString, "itemString")
end

---Gets the name of a given craft.
---@param craftString string The craft string
---@return string
function CraftInfoDB.GetName(craftString)
	return private.GetCraftDBField(craftString, "name")
end

---Gets the profession for a given craft.
---@param craftString string The craft string
---@return string
function CraftInfoDB.GetProfession(craftString)
	return private.GetCraftDBField(craftString, "profession")
end

---Gets the result quantity for a given craft.
---@param craftString string The craft string
---@return number
function CraftInfoDB.GetNumResult(craftString)
	return private.GetCraftDBField(craftString, "numResult")
end

---Iterates over the characters for a given craft.
---@param craftString string The craft string
---@return IteratorObject<fun(): number, string> @Iterator with fields: `index`, `character`
function CraftInfoDB.CharacterIterator(craftString)
	return private.GetCraftDBField(craftString, "characters")
end

---Sets the custom value of a material.
---@param itemString string The item string
---@param value? string The custom value
function CraftInfoDB.SetMatCustomValue(itemString, value)
	private.matSettingsTable[itemString].customValue = value
	private.matItemDB:UpdateRow(private.matItemDB:GetUniqueRow("itemString", itemString), "customValue", value or "")
end

---Returns a new query for the spell DB.
---@return DatabaseQuery
function CraftInfoDB.NewCraftQuery()
	return private.craftDB:NewOwnedQuery()
end

---Returns a new query for the mat DB.
---@return DatabaseQuery
function CraftInfoDB.NewMatQuery()
	return private.matDB:NewOwnedQuery()
end

---Returns a new query for the mat item DB.
---@return DatabaseQuery
function CraftInfoDB.NewMatItemQuery()
	return private.matItemDB:NewOwnedQuery()
end

---Gets the craft DB for use in a join.
---@return DatabaseTable
function CraftInfoDB.GetCraftDBForJoin()
	return private.craftDB
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizeSettingsTables()
	local usedMats = {}
	wipe(private.numCraftsBySpellId)
	for craftString, craftInfo in pairs(private.craftSettingsTable) do
		if next(craftInfo.players) then
			for matString in pairs(craftInfo.mats) do
				for itemString in MatString.ItemIterator(matString) do
					usedMats[itemString] = true
					private.matSettingsTable[itemString] = private.matSettingsTable[itemString] or {}
					-- Remove old keys
					private.matSettingsTable[itemString].name = nil
				end
			end
			private.HandleCraftStringAdded(craftString)
		else
			private.craftSettingsTable[craftString] = nil
		end
	end
	for spellId, isFavorite in pairs(private.favoriteCraftSettingsTable) do
		if not isFavorite or not private.numCraftsBySpellId[spellId] then
			private.favoriteCraftSettingsTable[spellId] = nil
		end
	end
	Table.FilterKeyNotInTable(private.matSettingsTable, usedMats)
end

function private.LoadData()
	local professionItems = {}
	local matCountByCraft = {}
	local matFirstItemString = {}
	local matFirstQuantity = {}
	private.matDB:BulkInsertStart()
	private.craftDB:BulkInsertStart()
	for craftString, craftInfo in pairs(private.craftSettingsTable) do
		assert(not next(private.characterTemp))
		Table.GetKeys(craftInfo.players, private.characterTemp)
		assert(#private.characterTemp > 0)
		sort(private.characterTemp)
		private.craftDB:BulkInsertNewRow(craftString, craftInfo.itemString, (craftInfo.name --[[@as string?]]) or "", craftInfo.profession, craftInfo.numResult, private.characterTemp, craftInfo.hasCD and true or false)

		for matString, matQuantity in pairs(craftInfo.mats) do
			private.matDB:BulkInsertNewRow(craftString, matString, matQuantity)
			private.HandleMatDBAddRow(matString)
			professionItems[craftInfo.profession] = professionItems[craftInfo.profession] or {}
			matCountByCraft[craftString] = (matCountByCraft[craftString] or 0) + 1
			if matQuantity > 0 and MatString.GetType(matString) == MatString.TYPE.NORMAL then
				matFirstItemString[craftString] = matString
				matFirstQuantity[craftString] = matQuantity
			end
			for itemString in MatString.ItemIterator(matString) do
				professionItems[craftInfo.profession][itemString] = true
			end
		end
		wipe(private.characterTemp)
	end
	private.craftDB:BulkInsertEnd()
	private.matDB:BulkInsertEnd()

	private.matItemDB:BulkInsertStart()
	local professionsTemp = {}
	for itemString, info in pairs(private.matSettingsTable) do
		wipe(professionsTemp)
		for profession, items in pairs(professionItems) do
			if items[itemString] then
				tinsert(professionsTemp, profession)
			end
		end
		sort(professionsTemp)
		private.matItemDB:BulkInsertNewRow(itemString, professionsTemp, info.customValue or "")
	end
	private.matItemDB:BulkInsertEnd()

	-- Register 1:1 crafting conversions
	local addedConversion = false
	local query = private.craftDB:NewAutoReleaseQuery()
		:Equal("hasCD", false)
	for _, craftString, itemString, numResult in query:Iterator("craftString", "itemString", "numResult") do
		local spellId = CraftString.GetSpellId(craftString)
		if not Salvage.MassMill[spellId] and matCountByCraft[craftString] == 1 and matFirstItemString[craftString] then
			Conversion.AddCraft(itemString, matFirstItemString[craftString], numResult / matFirstQuantity[craftString])
			addedConversion = true
		end
	end
	if addedConversion then
		CustomString.InvalidateCache("Destroy")
	end
end

function private.HandleCraftStringAdded(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	private.numCraftsBySpellId[spellId] = (private.numCraftsBySpellId[spellId] or 0) + 1
end

function private.HandleCraftStringRemoved(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	private.numCraftsBySpellId[spellId] = private.numCraftsBySpellId[spellId] - 1
	if private.numCraftsBySpellId[spellId] == 0 then
		private.numCraftsBySpellId[spellId] = nil
		private.favoriteCraftSettingsTable[spellId] = nil
	end
end

function private.HandleMatDBAddRow(matString)
	for itemString in MatString.ItemIterator(matString) do
		private.numMatDBRows[itemString] = (private.numMatDBRows[itemString] or 0) + 1
	end
end

function private.HandleMatDBDeleteRow(matString)
	for itemString in MatString.ItemIterator(matString) do
		private.numMatDBRows[itemString] = private.numMatDBRows[itemString] - 1
		if private.numMatDBRows[itemString] == 0 then
			private.numMatDBRows[itemString] = nil
			if private.matItemDB:HasUniqueRow("itemString", itemString) then
				private.matItemDB:DeleteRow(private.matItemDB:GetUniqueRow("itemString", itemString))
			end
		end
	end
end

function private.MatItemDBUpdateOrInsert(itemString, profession)
	assert(not next(private.professionTemp))
	if private.matItemDB:HasUniqueRow("itemString", itemString) then
		local uuid = private.matItemDB:GetUniqueRow("itemString", itemString)
		-- Update the professions if necessary
		local hasProfession = false
		for _, existingProfession in private.matItemDB:GetRowFields(uuid, "professions") do
			tinsert(private.professionTemp, existingProfession)
			if existingProfession == profession then
				hasProfession = true
			end
		end
		if hasProfession then
			wipe(private.professionTemp)
			return
		end
		tinsert(private.professionTemp, profession)
		sort(private.professionTemp)
		private.matItemDB:UpdateRow(uuid, "professions", private.professionTemp)
	else
		tinsert(private.professionTemp, profession)
		local customValue = private.matSettingsTable[itemString].customValue or ""
		private.matItemDB:InsertRow(itemString, private.professionTemp, customValue)
	end
	wipe(private.professionTemp)
end

function private.MatDBDeleteCraftStrings(craftStrings)
	assert(type(craftStrings) == "table" or type(craftStrings) == "string")
	for _ in private.matItemDB:WithQueryUpdatesPaused() do
		local query = private.matDB:NewOwnedQuery()
			:AutoPauseDBQueryUpdates()
			:If(type(craftStrings) == "table")
				:InTable("craftString", craftStrings)
			:ElseIf(type(craftStrings) == "string")
				:Equal("craftString", craftStrings)
			:End()
		for _, matString in query:Iterator("matString") do
			private.HandleMatDBDeleteRow(matString)
		end
		query:Delete()
		query:Release()
	end
end

function private.GetCraftDBField(craftString, field)
	return private.craftDB:GetRowFields(private.craftDB:GetUniqueRow("craftString", craftString), field)
end

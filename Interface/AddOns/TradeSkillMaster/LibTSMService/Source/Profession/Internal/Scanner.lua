-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:InitInternal("Profession.Scanner")
local Data = LibTSMService:Include("Profession.Data")
local State = LibTSMService:Include("Profession.State")
local Quality = LibTSMService:Include("Profession.Quality")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local EnchantData = LibTSMService:From("LibTSMData"):Include("Enchant")
local SalvageData = LibTSMService:From("LibTSMData"):Include("Salvage")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Hash = LibTSMService:From("LibTSMUtil"):Include("Util.Hash")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatString")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local CombatLockdown = LibTSMService:From("LibTSMWoW"):Include("Service.CombatLockdown")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local private = {
	db = nil,
	matDB = nil,
	dbPopulated = false,
	hasScanned = false,
	callbacks = CallbackRegistry.NewList(),
	disabled = false,
	ignoreUpdatesUntil = 0,
	recipeInfoCache = {}, ---@type table<string|number,TradeSkillRecipeInfoExtended>
	prevScannedHash = nil,
	scanTimer = nil,
	resultQualityTemp = {},
	classicSpellIdLookup = {},
	scanHookFunc = nil, ---@type Scanner.ScanHookFunc!
	inactiveFunc = nil, ---@type Scanner.InactiveFunc!
	matStringItemsTemp = {},
	matQuantitiesTemp = {},
	matIteratorQuery = nil,
	scanTemp = {
		prevRecipeIds = {},
		nextRecipeIds = {},
		recipes = {},
		inactiveCraftStrings = {},
	},
	craftStringsTemp = {},
}
-- Don't want to scan a bunch of times when the profession first loads so add a 10 frame debounce to update events
local SCAN_DEBOUNCE_FRAMES = 10
local MAX_CRAFT_LEVEL = 4
local MAT_STRING_OPTIONAL_MATCH_STR = {
	[MatString.TYPE.OPTIONAL] = "^o:",
	[MatString.TYPE.FINISHING] = "^f:",
}
local SCAN_HASH_INFO_FIELDS = {
	"index",
	"previousRecipeID",
	"nextRecipeID",
	"categoryID",
	"learned",
	"unlockedRecipeLevel",
	"relativeDifficulty",
	"numSkillUps",
	"name",
	"currentRecipeExperience",
	"nextLevelRecipeExperience",
	"qualityIlvlBonuses",
}

---@alias Scanner.ScanHookFunc fun(professionName: string, craftStrings: string[]): boolean, boolean
---@alias Scanner.InactiveFunc fun(craftStrings: table<string,true>)

---@class TradeSkillRecipeInfoExtended: TradeSkillRecipeInfo
---@field index number!



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	for spellId in pairs(SalvageData.MassMill) do
		-- Workaround for incorrect values returned for new mass milling recipes
		TradeSkill.AddBuggedQuantityInfo(spellId, 8, 8.8)
	end
	private.db = Database.NewSchema("CRAFTING_RECIPES")
		:AddUniqueStringField("craftString")
		:AddStringField("itemString")
		:AddNumberField("index")
		:AddStringField("name")
		:AddStringField("craftName")
		:AddNumberField("categoryId")
		:AddEnumField("difficulty", TradeSkill.RECIPE_DIFFICULTY)
		:AddNumberField("rank")
		:AddNumberField("numSkillUps")
		:AddNumberField("level")
		:AddNumberField("currentExp")
		:AddNumberField("nextExp")
		:AddEnumField("recipeType", TradeSkill.RECIPE_TYPE)
		:Commit()
	private.matDB = Database.NewSchema("CRAFTING_RECIPE_MATS")
		:AddStringField("craftString")
		:AddStringField("matString")
		:AddNumberField("quantity")
		:AddStringField("slotText")
		:AddIndex("craftString")
		:AddIndex("matString")
		:Commit()
	private.matIteratorQuery = private.matDB:NewOwnedQuery()
		:Equal("craftString", Database.BoundQueryParam())
	private.scanTimer = DelayTimer.New("PROFESSION_SCAN", private.ScanProfession)
	State.RegisterCallback(private.ProfessionStateUpdate)
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		Event.Register("TRADE_SKILL_LIST_UPDATE", private.OnTradeSkillUpdateEvent)
	else
		Event.Register("CRAFT_UPDATE", private.OnTradeSkillUpdateEvent)
		Event.Register("TRADE_SKILL_UPDATE", private.OnTradeSkillUpdateEvent)
	end
	Event.Register("CHAT_MSG_SKILL", private.ChatMsgSkillEventHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the hook functions
---@param scanFunc Scanner.ScanHookFunc Function to call with scan results
---@param inactiveFunc Scanner.InactiveFunc Function to call with inactive recipes
function Scanner.SetHookFuncs(scanFunc, inactiveFunc)
	assert(not private.scanHookFunc and not private.inactiveFunc)
	private.scanHookFunc = scanFunc
	private.inactiveFunc = inactiveFunc
end

---Sets whether the scanner is disabled.
---@param disabled boolean Whether or not to disable the scanner
function Scanner.SetDisabled(disabled)
	if private.disabled == disabled then
		return
	end
	private.disabled = disabled
	if not disabled then
		private.ScanProfession()
	end
end

---Gets whether or not the profession was scanned.
---@return boolean
function Scanner.HasScanned()
	return private.hasScanned
end

---Gets whether or not the DB is populated.
---@return boolean
function Scanner.HasSkills()
	return private.hasScanned and private.db:GetNumRows() > 0
end

---Registers a callback for when the scan finishes.
---@param callback fun()
function Scanner.RegisterHasScannedCallback(callback)
	private.callbacks:Add(callback)
end

---Ignores the next profession update
function Scanner.IgnoreNextProfessionUpdates()
	private.ignoreUpdatesUntil = LibTSMService.GetTime() + 1
end

---Creates a query against the DB.
---@return DatabaseQuery
function Scanner.CreateQuery()
	return private.db:NewOwnedQuery()
end

---Gets the item string of a craft.
---@param craftString string The craft string
---@return string?
function Scanner.GetItemStringByCraftString(craftString)
	assert(private.dbPopulated)
	local itemString = private.GetDBField(craftString, "itemString")
	return itemString ~= "" and itemString or nil
end

---Gets the index of a craft.
---@param craftString string The craft string
---@return number?
function Scanner.GetIndexByCraftString(craftString)
	assert((not LibTSMService.IsRetail() and not LibTSMService.IsForever()) or private.dbPopulated)
	return private.GetDBField(craftString, "index")
end

---Gets the category ID of a craft.
---@param craftString string The craft string
---@return number?
function Scanner.GetCategoryIdByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "categoryId")
end

---Gets the name of a craft.
---@param craftString string The craft string
---@return string?
function Scanner.GetNameByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "name")
end

---Gets the craft name of a craft.
---@param craftString string The craft string
---@return string?
function Scanner.GetCraftNameByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "craftName")
end

---Gets the current experience level of a craft.
---@param craftString string The craft string
---@return number?
function Scanner.GetCurrentExpByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "currentExp")
end

---Gets the next experience level of a craft.
---@param craftString string The craft string
---@return number?
function Scanner.GetNextExpByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "nextExp")
end

---Gets the recipe type of a craft.
---@param craftString string The craft string
---@return EnumValue?
function Scanner.GetRecipeTypeByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "recipeType")
end

---Gets the difficulty of a craft.
---@param craftString string The craft string
---@return EnumValue?
function Scanner.GetDifficultyByCraftString(craftString)
	assert(private.dbPopulated)
	return private.GetDBField(craftString, "difficulty")
end

---Returns whether or not a craft is in the DB.
---@param craftString string The craft string
---@return boolean
function Scanner.HasCraftString(craftString)
	return private.dbPopulated and private.db:HasUniqueRow("craftString", craftString)
end

---Iterates over the mats for a craft.
---@param craftString string The craft string
---@return IteratorObject<fun(): number, string, number, string> @Iterator with fields: `index`, `matString`, `quantity`, `slotText`
function Scanner.MatIterator(craftString)
	return private.matIteratorQuery:BindParams(craftString)
		:Iterator("matString", "quantity", "slotText")
end

---Gets the optional mat string for a craft and slot ID.
---@param craftString string The craft string
---@param slotId number The slot ID
---@return string?
function Scanner.GetOptionalMatString(craftString, slotId)
	return private.matDB:NewAutoReleaseQuery()
		:Equal("craftString", craftString)
		:Matches("matString", "^[qofr]:")
		:Contains("matString", ":"..slotId..":")
		:GetSingleResult("matString")
end

---Gets the number of optional mats.
---@param craftString string The craft string
---@param matType EnumValue The optional mat type
---@return number
function Scanner.GetNumOptionalMats(craftString, matType)
	local matchStr = MAT_STRING_OPTIONAL_MATCH_STR[matType]
	assert(matchStr)
	return private.matDB:NewAutoReleaseQuery()
		:Equal("craftString", craftString)
		:Matches("matString", matchStr)
		:Count()
end

---Gets the slot text of a mat.
---@param craftString string The craft string
---@param matString string The mat string
---@return string
function Scanner.GetMatSlotText(craftString, matString)
	return private.matDB:NewAutoReleaseQuery()
		:Equal("craftString", craftString)
		:Equal("matString", matString)
		:GetSingleResult("slotText")
end

---Gets the result item from a craft.
---@param craftString string The craft string
---@return string|string[]|nil resultItem
---@return number? indirectSpellId
function Scanner.GetResultItem(craftString)
	local spellId = CraftString.GetSpellId(craftString)
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		local indirectResult = Data.GetIndirectCraftResult(spellId)
		if type(indirectResult) == "table" then
			for i = 1, #indirectResult do
				local link = ItemInfo.GetLink(indirectResult[i])
				if not link then
					return nil, nil
				end
				indirectResult[i] = link
			end
			return indirectResult, spellId
		elseif indirectResult then
			indirectResult = ItemInfo.GetLink(indirectResult)
			return indirectResult, spellId
		end
		local result = TradeSkill.GetResult(spellId)
		if type(result) == "string" then
			local baseItemString = ItemString.GetBase(result)
			if not baseItemString then
				return result, nil
			end
			local ilvlBonuses = TradeSkill.GetItemLevelBonuses(spellId)
			if not ilvlBonuses then
				return result, nil
			end
			local baseLevel = ItemInfo.GetItemLevel(result)
			if not baseLevel then
				return nil, nil
			end
			result = ilvlBonuses
			wipe(private.resultQualityTemp)
			for i = 1, #result do
				local relLevel = result[i]
				assert(relLevel >= 0)
				local itemString = baseItemString.."::i"..(baseLevel + relLevel)
				result[i] = baseItemString.."::i"..(baseLevel + relLevel)
				private.resultQualityTemp[itemString] = relLevel
			end
		else
			wipe(private.resultQualityTemp)
			for i = 1, #result do
				local itemId = result[i]
				local itemString = ItemString.FromItemId(itemId)
				result[i] = itemString
				local quality = TradeSkill.GetItemCraftedQuality(itemId) or ItemInfo.GetCraftedQuality(itemString)
				if not quality then
					return nil, nil
				end
				private.resultQualityTemp[itemString] = quality
			end
		end
		---@cast result string[]
		Table.SortWithValueLookup(result, private.resultQualityTemp)
		for i = 1, #result do
			local link = ItemInfo.GetLink(result[i])
			if not link then
				return nil, nil
			end
			result[i] = link
		end
		return result
	else
		spellId = private.classicSpellIdLookup[spellId] or spellId
		local itemLink, indirectSpellId = TradeSkill.GetResult(spellId)
		---@cast itemLink string
		if LibTSMService.IsMistsClassic() then
			local itemString = indirectSpellId and Data.GetIndirectCraftResult(indirectSpellId) --[[@as string?]]
			itemLink = itemString and ItemInfo.GetLink(itemString) or itemLink
		end
		return itemLink, indirectSpellId
	end
end

---Gets the item string of the vellum to use with a craft.
---@param craftString string The craft string
---@return string
function Scanner.GetVellumItemString(craftString)
	return EnchantData.VellumItemString
end

---Gets the number of result items for a craft.
---@param craftString string The craft string
---@return number
function Scanner.GetNumResultItems(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		return 1
	elseif not CraftString.GetQuality(craftString) then
		return 1
	end
	local spellId = CraftString.GetSpellId(craftString)
	local indirectResult = Data.GetIndirectCraftResult(spellId)
	if indirectResult then
		return type(indirectResult) == "table" and #indirectResult or 1
	end
	local result = TradeSkill.GetResult(spellId)
	if type(result) == "table" then
		return #result
	else
		local ilvlBonuses = TradeSkill.GetItemLevelBonuses(spellId)
		return ilvlBonuses and #ilvlBonuses or 1
	end
end

---Gets info on a material.
---@param craftString string The craft string
---@param index number The index of the mat
---@return string itemstring
---@return number quantity
---@return string? name
---@return boolean isModifiedReagent
function Scanner.GetMatInfo(craftString, index)
	local spellId = CraftString.GetSpellId(craftString)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		spellId = private.classicSpellIdLookup[spellId] or spellId
	end
	local item, name, quantity, isModifiedReagent = TradeSkill.GetMatInfo(spellId, CraftString.GetLevel(craftString), index)
	local itemString = nil
	if type(item) == "number" then
		itemString = ItemString.FromItemId(item)
		name = name or ItemInfo.GetName(itemString)
	else
		itemString = ItemString.Get(item)
		name = name or ItemInfo.GetName(item)
		assert(itemString)
	end
	return itemString, quantity, name, isModifiedReagent
end

---Maps a spell ID to a value that can be passed to a TradeSkill.*() API on classic.
---@param spellId number The spell ID
---@return number
function Scanner.GetClassicSpellId(spellId)
	return private.classicSpellIdLookup[spellId] or spellId
end



-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.ProfessionStateUpdate()
	private.hasScanned = false
	private.dbPopulated = false
	private.callbacks:CallAll()
	if State.GetCurrentProfession() then
		private.db:Truncate()
		private.prevScannedHash = nil
		private.OnTradeSkillUpdateEvent()
	else
		private.scanTimer:Cancel()
	end
end

function private.OnTradeSkillUpdateEvent()
	private.scanTimer:Cancel()
	private.QueueProfessionScan()
end

function private.ChatMsgSkillEventHandler(_, msg)
	local professionName = State.GetCurrentProfession()
	if not professionName or not strmatch(msg, professionName) then
		return
	end
	private.ignoreUpdatesUntil = 0
	private.QueueProfessionScan()
end



-- ============================================================================
-- Profession Scanning
-- ============================================================================

function private.QueueProfessionScan()
	private.scanTimer:RunForFrames(SCAN_DEBOUNCE_FRAMES)
end

function private.ScanProfession()
	if CombatLockdown.IsActive() then
		-- We are in combat, so try again in a bit
		private.QueueProfessionScan()
		return
	elseif private.disabled then
		return
	elseif LibTSMService.GetTime() < private.ignoreUpdatesUntil then
		return
	end

	local professionName = State.GetCurrentProfession()
	if not professionName or not TradeSkill.IsDataReady() then
		-- Profession hasn't fully opened yet
		private.QueueProfessionScan()
		return
	end

	if TradeSkill.ClearFilters() then
		-- An update event will be triggered
		return
	end

	local scannedHash = nil
	local haveInvalidRecipes = false
	local haveInvalidMats = false
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		wipe(private.recipeInfoCache)
		local scanTemp = private.scanTemp
		for _, tbl in pairs(scanTemp) do
			assert(not next(tbl))
		end
		for index, _, _, _, info in TradeSkill.RecipeIterator() do
			assert(info)
			local spellId = info.recipeID
			-- There's a Blizzard bug where First Aid duplicates spellIds, so check that we haven't seen this before
			if not private.recipeInfoCache[spellId] then
				tinsert(scanTemp.recipes, spellId)
				---@cast info TradeSkillRecipeInfoExtended
				assert(not info.index)
				info.index = index
				if info.previousRecipeID then
					scanTemp.prevRecipeIds[spellId] = info.previousRecipeID
					scanTemp.nextRecipeIds[info.previousRecipeID] = spellId
				end
				if info.nextRecipeID then
					scanTemp.nextRecipeIds[spellId] = info.nextRecipeID
					scanTemp.prevRecipeIds[info.nextRecipeID] = spellId
				end
				private.recipeInfoCache[spellId] = info
				scannedHash = Hash.Calculate(spellId, scannedHash)
				for _, hashField in ipairs(SCAN_HASH_INFO_FIELDS) do
					scannedHash = Hash.Calculate(info[hashField], scannedHash)
				end
			end
		end
		if scannedHash == private.prevScannedHash then
			Log.Info("Hash hasn't changed, so not scanning")
			private.dbPopulated = true
			for _, tbl in pairs(scanTemp) do
				Table.WipeAndDeallocate(tbl)
			end
			private.DoneScanning(scannedHash)
			return
		end
		private.db:TruncateAndBulkInsertStart()
		private.matDB:TruncateAndBulkInsertStart()
		for _, spellId in ipairs(scanTemp.recipes) do
			local info = private.recipeInfoCache[spellId]
			local nextSpellId = scanTemp.nextRecipeIds[spellId]
			local hasHigherRank = nextSpellId and private.recipeInfoCache[nextSpellId] and private.recipeInfoCache[nextSpellId].learned
			local rank = -1
			if scanTemp.prevRecipeIds[spellId] or nextSpellId then
				rank = 1
				local tempSpellId = spellId
				while scanTemp.prevRecipeIds[tempSpellId] do
					rank = rank + 1
					tempSpellId = scanTemp.prevRecipeIds[tempSpellId]
				end
			end
			-- TODO: Show unlearned recipes in the TSM UI
			if info.learned and not hasHigherRank then
				local unlockedLevel = info.unlockedRecipeLevel
				local numSkillUps, difficulty = TradeSkill.ExtractInfo(info)
				local recipeType = TradeSkill.GetRecipeType(spellId)
				if unlockedLevel then
					for level = 1, MAX_CRAFT_LEVEL do
						local craftString = CraftString.Get(spellId, rank, level)
						-- Remove any old version of the spell without a level
						scanTemp.inactiveCraftStrings[CraftString.Get(spellId)] = true
						if level <= unlockedLevel then
							local recipeScanResult, matScanResult = private.BulkInsertRecipe(craftString, info.index, info.name, info.categoryID, difficulty, rank, numSkillUps, level, info.currentRecipeExperience or -1, info.nextLevelRecipeExperience or -1, recipeType)
							haveInvalidRecipes = haveInvalidRecipes or not recipeScanResult
							haveInvalidMats = haveInvalidMats or not matScanResult
						else
							-- This level isn't unlocked yet
							scanTemp.inactiveCraftStrings[craftString] = true
						end
					end
				else
					local craftString = CraftString.Get(spellId, rank)
					local numResultItems = nil
					local indirectResult = Data.GetIndirectCraftResult(spellId)
					if type(indirectResult) == "table" then
						numResultItems = #indirectResult
					elseif indirectResult then
						numResultItems = 1
					else
						local result = TradeSkill.GetResult(spellId)
						if type(result) == "table" then
							numResultItems = #result
						elseif ItemString.GetBase(result) then
							local ilvlBonuses = info.qualityIlvlBonuses
							if ilvlBonuses and #ilvlBonuses > 1 then
								numResultItems = #ilvlBonuses
							else
								numResultItems = 1
							end
						else
							numResultItems = 1
						end
					end
					if not info.supportsQualities or info.isSalvageRecipe then
						assert(numResultItems == 1)
						local recipeScanResult, matScanResult = private.BulkInsertRecipe(craftString, info.index, info.name, info.categoryID, difficulty, rank, numSkillUps, 1, info.currentRecipeExperience or -1, info.nextLevelRecipeExperience or -1, recipeType)
						haveInvalidRecipes = haveInvalidRecipes or not recipeScanResult
						haveInvalidMats = haveInvalidMats or not matScanResult
					elseif numResultItems == 1 then
						-- Just ignore this craft for now - this can happen with alchemy experimentation for example
						Log.Warn("Unexpected single result item (%s, %s)", tostring(professionName), tostring(craftString))
					else
						assert(numResultItems > 1)
						-- This is a quality craft
						local recipeDifficulty, baseRecipeQuality, hasQualityMats = TradeSkill.GetRecipeQualityInfo(spellId)
						if baseRecipeQuality and recipeDifficulty and hasQualityMats ~= nil then
							local rootCategoryId = TradeSkill.GetRootCategoryId(info.categoryID)
							local maxMatContribution = Quality.GetMaxMatContribution(rootCategoryId)
							for i = 1, numResultItems do
								local qualityCraftString = CraftString.Get(spellId, rank, nil, i)
								if Quality.GetNeededSkill(i, recipeDifficulty, baseRecipeQuality, numResultItems, hasQualityMats, maxMatContribution) then
									local recipeScanResult, matScanResult = private.BulkInsertRecipe(qualityCraftString, info.index, info.name, info.categoryID, difficulty, rank, numSkillUps, 1, info.currentRecipeExperience or -1, info.nextLevelRecipeExperience or -1, recipeType)
									haveInvalidRecipes = haveInvalidRecipes or not recipeScanResult
									haveInvalidMats = haveInvalidMats or not matScanResult
								else
									-- We can no longer craft this quality
									scanTemp.inactiveCraftStrings[qualityCraftString] = true
								end
							end
						else
							-- Just ignore this craft for now
							Log.Warn("Could not look up base quality (%s, %s)", tostring(professionName), tostring(craftString))
						end
					end
				end
			end
		end
		private.matDB:BulkInsertEnd()
		private.db:BulkInsertEnd()
		private.dbPopulated = true
		if next(scanTemp.inactiveCraftStrings) then
			private.inactiveFunc(scanTemp.inactiveCraftStrings)
		end
		for _, tbl in pairs(scanTemp) do
			Table.WipeAndDeallocate(tbl)
		end
	else
		private.PopulateClassicSpellIdLookup()
		private.db:TruncateAndBulkInsertStart()
		private.matDB:TruncateAndBulkInsertStart()
		for i, name, categoryId, difficulty in TradeSkill.RecipeIterator() do
			local craftString = CraftString.Get(private.classicSpellIdLookup[-i])
			local recipeScanResult, matScanResult = private.BulkInsertRecipe(craftString, i, name, categoryId, difficulty, -1, 1, 1, -1, -1, TradeSkill.RECIPE_TYPE.UNKNOWN)
			haveInvalidRecipes = haveInvalidRecipes or not recipeScanResult
			haveInvalidMats = haveInvalidMats or not matScanResult
		end
		private.matDB:BulkInsertEnd()
		private.db:BulkInsertEnd()
		private.dbPopulated = true
	end
	if haveInvalidRecipes or haveInvalidMats then
		-- We'll try again
		private.QueueProfessionScan()
		return
	elseif TradeSkill.GetType() ~= TradeSkill.TYPE.PLAYER then
		-- We don't want to store this profession in our application DB, so we're done
		private.DoneScanning(scannedHash)
		return
	end

	assert(not next(private.craftStringsTemp))
	private.db:NewAutoReleaseQuery()
		:NotEqual("itemString", "")
		:AsTable(private.craftStringsTemp, "craftString")
	local done, rescan = private.scanHookFunc(professionName, private.craftStringsTemp)
	wipe(private.craftStringsTemp)
	if rescan then
		private.QueueProfessionScan()
	end
	if done then
		private.DoneScanning(scannedHash)
	end

	wipe(private.recipeInfoCache)
end

function private.BulkInsertRecipe(craftString, index, name, categoryId, relativeDifficulty, rank, numSkillUps, level, currentRecipeExperience, nextLevelRecipeExperience, recipeType)
	local itemString, craftName = private.GetItemStringAndCraftName(craftString)
	if not itemString or not craftName then
		return false, false
	end
	private.db:BulkInsertNewRow(craftString, itemString, index, name, craftName, categoryId, relativeDifficulty, rank, numSkillUps, level, currentRecipeExperience, nextLevelRecipeExperience, recipeType)
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		local spellId = CraftString.GetSpellId(craftString)
		private.recipeInfoCache[craftString] = private.recipeInfoCache[spellId]
	end
	local matScanResult = private.BulkInsertMats(craftString)
	return true, matScanResult
end

function private.GetItemStringAndCraftName(craftString)
	-- Get the links
	local spellId = CraftString.GetSpellId(craftString)
	local quality = CraftString.GetQuality(craftString)
	local resultItem, indirectSpellId = Scanner.GetResultItem(craftString)
	if not resultItem then
		return nil, nil
	end

	-- Get the itemString and craft name
	local itemString, craftName = nil, nil
	if quality then
		if type(resultItem) == "table" then
			assert(resultItem[quality])
			itemString = ItemString.Get(resultItem[quality])
			itemString = itemString and ItemString.ToLevel(itemString)
		else
			assert(resultItem)
			itemString = ItemString.Get(resultItem)
		end
		craftName = itemString and ItemInfo.GetName(itemString)
	else
		---@cast resultItem string
		if strfind(resultItem, "enchant:") then
			itemString = ""
			craftName = TradeSkill.GetBasicInfo(TradeSkill.IsClassicCrafting() and Scanner.GetClassicSpellId(spellId) or (indirectSpellId or spellId))
		elseif strfind(resultItem, "item:") then
			-- Result of craft is item
			local level = CraftString.GetLevel(craftString)
			if level and level > 0 then
				local baseItemString = ItemString.GetBase(resultItem)
				local baseItemLevel = baseItemString and ItemInfo.GetItemLevel(baseItemString) or nil
				if not baseItemLevel then
					return nil, nil
				end
				itemString = baseItemString.."::i"..abs(baseItemLevel + level)
			else
				itemString = ItemString.GetBase(resultItem)
			end
			craftName = ItemInfo.GetName(resultItem)
			-- Blizzard broke Brilliant Scarlet Ruby in 8.3, so just hard-code a workaround
			if spellId == 53946 and not itemString and not craftName then
				itemString = "i:39998"
				craftName = TradeSkill.GetBasicInfo(spellId)
			end
		else
			error("Invalid craft: "..tostring(craftString))
		end
	end
	if not itemString or not craftName then
		Log.Warn("No itemString (%s) or craftName (%s) found (%s)", tostring(itemString), tostring(craftName), tostring(craftString))
		return nil, nil
	end

	return itemString, craftName
end

function private.BulkInsertMats(craftString)
	wipe(private.matQuantitiesTemp)
	local spellId = CraftString.GetSpellId(craftString)
	local quality = CraftString.GetLevel(craftString)
	local spellIdOrIndex = nil
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		spellIdOrIndex = spellId
	else
		spellIdOrIndex = private.classicSpellIdLookup[spellId] or spellId
	end
	local haveInvalidMats = false
	for i = 1, TradeSkill.GetNumMats(spellIdOrIndex, quality) do
		local matItemString, quantity, name, isQualityMat = Scanner.GetMatInfo(craftString, i)
		if not matItemString then
			local professionName = State.GetCurrentProfession()
			Log.Warn("Failed to get itemString for mat %d (%s, %s)", i, tostring(professionName), tostring(craftString))
			haveInvalidMats = true
			break
		end
		if not name or not quantity then
			local professionName = State.GetCurrentProfession()
			Log.Warn("Failed to get name (%s) or quantity (%s) for mat (%s, %s, %d)", tostring(name), tostring(quantity), tostring(professionName), tostring(craftString), i)
			haveInvalidMats = true
			break
		end
		if not isQualityMat then
			ItemInfo.StoreItemName(matItemString, name)
			private.matQuantitiesTemp[matItemString] = quantity
		end
	end

	if LibTSMService.IsMistsClassic() and TradeSkill.IsEnchant(spellIdOrIndex) then
		-- Add a vellum to the list of mats
		private.matQuantitiesTemp[Scanner.GetVellumItemString(craftString)] = 1
	end

	if haveInvalidMats then
		return false
	end

	for matString, quantity in pairs(private.matQuantitiesTemp) do
		private.matDB:BulkInsertNewRow(craftString, matString, quantity, "")
	end
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		local categorySkillLevel = TradeSkill.GetCurrentCategorySkillLevel(private.recipeInfoCache[craftString].categoryID)
		local level = CraftString.GetLevel(craftString)
		local salvageItems, salvageQuantityMin = TradeSkill.GetSalvageInfo(spellId, level)
		if salvageItems then
			for i = 1, #salvageItems do
				salvageItems[i] = ItemString.FromItemId(salvageItems[i])
			end
			---@cast salvageItems string[]
			local matString = MatString.Create(MatString.TYPE.REQUIRED, 1, salvageItems)
			private.matDB:BulkInsertNewRow(craftString, matString, salvageQuantityMin, "")
		end
		for _, matType, quantityRequired, dataSlotIndex, slotTextOrId, reagents in TradeSkill.SpecialMatIterator(spellId, level, categorySkillLevel) do
			local matStringType = nil
			if matType == TradeSkill.MAT_TYPE.REQUIRED then
				matStringType = MatString.TYPE.REQUIRED
			elseif matType == TradeSkill.MAT_TYPE.QUALITY then
				matStringType = MatString.TYPE.QUALITY
			elseif matType == TradeSkill.MAT_TYPE.OPTIONAL then
				matStringType = MatString.TYPE.OPTIONAL
			elseif matType == TradeSkill.MAT_TYPE.FINISHING then
				matStringType = MatString.TYPE.FINISHING
			else
				error("Unexpected mat type: "..tostring(matType))
			end
			if type(slotTextOrId) == "number" then
				slotTextOrId = ItemInfo.GetName(ItemString.FromItemId(slotTextOrId)) or ""
			end
			if salvageItems then
				dataSlotIndex = dataSlotIndex + 1
			end
			assert(not next(private.matStringItemsTemp))
			for _, craftingReagent in ipairs(reagents) do
				if craftingReagent.itemID and craftingReagent.itemID ~= 0 then
					tinsert(private.matStringItemsTemp, ItemString.FromItemId(craftingReagent.itemID))
				end
			end
			local matString = MatString.Create(matStringType, dataSlotIndex, private.matStringItemsTemp)
			wipe(private.matStringItemsTemp)
			private.matDB:BulkInsertNewRow(craftString, matString, quantityRequired, slotTextOrId)
		end
	end

	return true
end

function private.DoneScanning(scannedHash)
	private.prevScannedHash = scannedHash
	if not private.hasScanned then
		private.hasScanned = true
		private.callbacks:CallAll()
	end
end

function private.PopulateClassicSpellIdLookup()
	assert(not LibTSMService.IsRetail() and not LibTSMService.IsForever())
	assert(State.GetCurrentProfession() and TradeSkill.IsDataReady())
	wipe(private.classicSpellIdLookup)
	for i, name in TradeSkill.RecipeIterator() do
		local hash = Hash.Calculate(name)
		local _, _, id = TradeSkill.GetResult(i)
		hash = Hash.Calculate(id, hash)
		hash = Hash.Calculate(TradeSkill.GetIcon(i), hash)
		for j = 1, TradeSkill.GetNumMats(i) do
			local itemLink, _, quantity = TradeSkill.GetMatInfo(i, nil, j)
			hash = Hash.Calculate(ItemString.Get(itemLink), hash)
			hash = Hash.Calculate(quantity, hash)
		end
		if private.classicSpellIdLookup[hash] then
			local itemString, craftName = private.GetItemStringAndCraftName(CraftString.Get(hash))
			local spellId = Scanner.GetClassicSpellId(hash)
			local itemLink, indirectSpellId = TradeSkill.GetResult(spellId)
			Log.Err("Hash already exists %d, %d, %d, %s, %s, %s, %s", hash, spellId, TradeSkill.GetIcon(spellId), craftName or "", tostring(itemLink), tostring(indirectSpellId), itemString or "")
			for j = 1, TradeSkill.GetNumMats(spellId) do
				local link, _, quantity = TradeSkill.GetMatInfo(spellId, nil, j)
				Log.Err("Material %d: %s, %s, %d", j, link, tostring(ItemString.Get(link)), quantity)
			end
		end
		assert(hash >= 0 and not private.classicSpellIdLookup[hash] and not private.classicSpellIdLookup[-i])
		private.classicSpellIdLookup[hash] = i
		private.classicSpellIdLookup[-i] = hash
	end
end

function private.GetDBField(craftString, field)
	if not private.db:HasUniqueRow("craftString", craftString) then
		return
	end
	return private.db:GetRowFields(private.db:GetUniqueRow("craftString", craftString), field)
end

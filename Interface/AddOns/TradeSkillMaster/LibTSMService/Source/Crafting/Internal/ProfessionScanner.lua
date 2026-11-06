-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local ProfessionScanner = LibTSMService:InitInternal("Crafting.ProfessionScanner")
local Profession = LibTSMService:Include("Profession")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local CraftInfoDBUtil = LibTSMService:Include("Crafting.CraftInfoDBUtil")
local Procs = LibTSMService:Include("Crafting.Procs")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	cleanupThread = nil,
	cleanupQuery = nil, ---@diagnostic disable-line: tsm-private
	matQuantitiesTemp = {},
	removeCharactersTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ProfessionScanner:OnModuleLoad(function()
	Profession.SetScanHookFuncs(private.ScanHook, private.HandleInactiveRecipes)
	private.cleanupThread = Threading.New("PLAYER_PROFESSIONS_CLEANUP", private.CleanupThread)
	private.cleanupQuery = Profession.CreatePlayerProfessionsQuery()
		:SetUpdateCallback(private.StartCleanupThread)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ScanHook(professionName, craftStrings)
	if not Profession.HasProfession(SessionInfo.GetCharacterName(), professionName) then
		-- We are in combat or the player's professions haven't been scanned yet by PlayerProfessions.lua, so will try again in a bit
		return false, true
	end

	-- Update the link for this profession
	Profession.UpdateProfessionLink()

	-- Scan all the recipes
	Procs.ClearPerkBonuses()
	local numFailed = 0
	for _, craftString in CraftInfoDB.WithCraftDBQueryUpdatesPaused(ipairs(craftStrings)) do
		private.ScanRecipe(professionName, craftString)
	end

	Log.Info("Scanned %s (failed to scan %d)", professionName, numFailed)
	return numFailed == 0, false
end

function private.ScanRecipe(professionName, craftString)
	local itemString = Profession.GetItemStringByCraftString(craftString)
	local craftName = Profession.GetCraftNameByCraftString(craftString)
	assert(itemString and craftName and craftName ~= "")

	local lNum, hNum = Profession.GetCraftedQuantityRange(craftString)
	local numResult = floor((lNum + hNum) / 2)

	local numResultItems = Profession.GetNumResultItems(craftString)
	local hasCD = Profession.HasCooldown(craftString)
	local recipeDifficulty, baseRecipeQuality, _, resourcefulnessChance, multicraftChance = Profession.GetRecipeQualityInfo(craftString)
	local categoryId = (LibTSMService.IsRetail() or LibTSMService.IsForever()) and Profession.GetCategoryIdByCraftString(craftString) or nil
	local rootCategoryId = categoryId and TradeSkill.GetRootCategoryId(categoryId) or -1
	local character = SessionInfo.GetCharacterName()

	CraftInfoDB.Upsert(craftString, itemString, professionName, rootCategoryId, craftName, numResult, character, hasCD, recipeDifficulty, baseRecipeQuality, numResultItems)
	CraftInfoDB.SetExpectedProcRates(craftString, character, Procs.CalculateRates(CraftString.GetSpellId(craftString), resourcefulnessChance, multicraftChance))

	assert(not next(private.matQuantitiesTemp))
	for _, matString, quantity in Profession.MatIterator(craftString) do
		private.matQuantitiesTemp[matString] = quantity
	end
	if next(private.matQuantitiesTemp) then
		CraftInfoDB.SetMats(craftString, private.matQuantitiesTemp)
	end
	wipe(private.matQuantitiesTemp)
end

function private.HandleInactiveRecipes(craftStrings)
	CraftInfoDB.RemoveCharacterCrafts(SessionInfo.GetCharacterName(), craftStrings)
end

function private.StartCleanupThread()
	Threading.Kill(private.cleanupThread)
	Threading.Start(private.cleanupThread)
end

function private.CleanupThread()
	-- Clean up crafts which are no longer known
	local craftStrings = Threading.AcquireSafeTempTable()
	for _, craftString in CraftInfoDBUtil.CraftStringIterator() do
		tinsert(craftStrings, craftString)
	end
	for _, craftString in ipairs(craftStrings) do
		assert(not next(private.removeCharactersTemp))
		for _, character in CraftInfoDB.CharacterIterator(craftString) do
			-- Check if the player still exists and still has this profession
			if not Profession.HasProfession(character, CraftInfoDB.GetProfession(craftString)) then
				private.removeCharactersTemp[character] = true
			end
		end
		if next(private.removeCharactersTemp) then
			CraftInfoDB.RemoveCraftCharacters(craftString, private.removeCharactersTemp)
		end
		wipe(private.removeCharactersTemp)
		Threading.Yield()
	end
	TempTable.Release(craftStrings)
end

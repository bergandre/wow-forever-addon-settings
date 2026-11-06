-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CraftingSync = LibTSMService:InitInternal("Crafting.CraftingSync")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local Quality = LibTSMService:Include("Crafting.Quality")
local Sync = LibTSMService:Include("Sync")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Hash = LibTSMService:From("LibTSMUtil"):Include("Util.Hash")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	retryTimer = nil,
	craftSettingsTable = nil,
	hashesTemp = {},
	craftStrings = {},
	craftInfoTemp = {
		craftStrings = {},
		mats = {},
		itemStrings = {},
		names = {},
		numResults = {},
		hasCDs = {},
		baseRecipeDifficulties = {},
		baseRecipeQualities = {},
		maxRecipeQualities = {},
		expectedRefunds = {},
		expectedExtraYields = {},
		rootCategoryId = {},
	},
	accountLookup = {},
	accountStatus = {},
	removeTemp = {},
	missingCraftsTemp = {},
}
local STATUS = EnumType.New("CRAFTING_SYNC_STATUS", {
	UPDATING = EnumType.NewValue(),
	RETRY = EnumType.NewValue(),
	SYNCED = EnumType.NewValue(),
})
CraftingSync.STATUS = STATUS
local RETRY_DELAY = 5
local QUALITY_INFO_SEP = ","



-- ============================================================================
-- Module Loading
-- ============================================================================

CraftingSync:OnModuleLoad(function()
	private.retryTimer = DelayTimer.New("CRAFTING_SYNC_RETRY", private.RetryGetHashesRPC)
	Sync.RegisterConnectionChangedCallback(private.ConnectionChangedHandler)
	Sync.RegisterRPC("CRAFTING_GET_HASHES", private.RPCGetHashes)
	Sync.RegisterRPC("CRAFTING_GET_CRAFTS", private.RPCGetCrafts)
	Sync.RegisterRPC("CRAFTING_GET_CRAFT_INFO", private.RPCGetCraftInfo)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the craft info settings table.
---@param crafts table<string,CraftInfo> The craft info settings table
function CraftingSync.Load(crafts)
	private.craftSettingsTable = crafts
end

---Gets the sync status for an account.
---@param account string The account
---@return EnumValue?
function CraftingSync.GetStatus(account)
	return private.accountStatus[account]
end



-- ============================================================================
-- RPC Functions and Result Handlers
-- ============================================================================

function private.RPCGetHashes()
	wipe(private.hashesTemp)
	local character = SessionInfo.GetCharacterName()
	private.GetPlayerProfessionHashes(character, private.hashesTemp)
	return private.hashesTemp
end

function private.RPCGetHashesResultHandler(success, character, data)
	local account = private.HandleRPCResult("GET_HASHES", success, character)
	if not account then
		return
	end

	wipe(private.hashesTemp)
	private.GetPlayerProfessionHashes(character, private.hashesTemp)
	local requestProfession = nil
	for profession, hash in pairs(data) do
		if hash == private.hashesTemp[profession] then
			Log.Info("%s data for %s already up to date", profession, character)
		else
			Log.Info("Need updated %s data from %s (%s, %s)", profession, character, hash, tostring(private.hashesTemp[profession]))
			requestProfession = profession
		end
	end
	wipe(private.hashesTemp)

	if requestProfession then
		private.accountStatus[account] = STATUS.UPDATING
		Sync.CallRPC("CRAFTING_GET_CRAFTS", character, private.RPCGetCraftsResultHandler, requestProfession)
	else
		private.accountStatus[account] = STATUS.SYNCED
	end
end

function private.RPCGetCrafts(profession)
	wipe(private.craftStrings)
	local character = SessionInfo.GetCharacterName()
	local query = CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:Equal("profession", profession)
		:ListContains("characters", character)
		:OrderBy("craftString", true)
	for _, craftString, itemString in query:Iterator("craftString", "itemString") do
		local hash = private.GetCraftHash(craftString, character, itemString)
		local baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality = Quality.GetInfo(craftString, character)
		local expectedRefund, expectedExtraYield = CraftInfoDB.GetExpectedProcRates(craftString, character)
		if baseRecipeQuality or expectedRefund or expectedExtraYield then
			private.craftStrings[craftString] = strjoin(QUALITY_INFO_SEP, hash, baseRecipeDifficulty or "", baseRecipeQuality or "", maxRecipeQuality or "", expectedRefund or "", expectedExtraYield or "")
		else
			private.craftStrings[craftString] = private.GetCraftHash(craftString, character, itemString)
		end
	end
	return profession, private.craftStrings
end

function private.RPCGetCraftsResultHandler(success, character, profession, craftStrings)
	local account = private.HandleRPCResult("GET_CRAFTS", success, character)
	if not account then
		return
	end

	-- Remove any crafts which the character no longer knows
	assert(not next(private.removeTemp))
	CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:Equal("profession", profession)
		:ListContains("characters", character)
		:NotInTable("craftString", craftStrings)
		:AsTable(private.removeTemp, "craftString", "profession")
	if next(private.removeTemp) then
		Log.Info("Removing %d crafts (%s, %s)", Table.Count(private.removeTemp), profession, character)
		CraftInfoDB.RemoveCharacterCrafts(character, private.removeTemp)
	end
	Table.WipeAndDeallocate(private.removeTemp)

	assert(not next(private.missingCraftsTemp))
	for craftString, info in CraftInfoDB.WithCraftDBQueryUpdatesPaused(pairs(craftStrings)) do
		if CraftInfoDB.HasCraftString(craftString) then
			-- Already have this craft so make sure this character is added / updated
			local hash = nil
			if type(info) == "string" then
				local hashStr, baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality, expectedRefund, expectedExtraYield = strsplit(QUALITY_INFO_SEP, info)
				hash = tonumber(hashStr)
				CraftInfoDB.UpsertCharacter(craftString, character, tonumber(baseRecipeDifficulty), tonumber(baseRecipeQuality), tonumber(maxRecipeQuality))
				CraftInfoDB.SetExpectedProcRates(craftString, character, tonumber(expectedRefund), tonumber(expectedExtraYield))
			else
				hash = info
				CraftInfoDB.UpsertCharacter(craftString, character)
				CraftInfoDB.SetExpectedProcRates(craftString, character, nil, nil)
			end
			-- Check if the hash changed in which case we need to re-sync the craft
			if hash ~= private.GetCraftHash(craftString, character, CraftInfoDB.GetItemString(craftString)) then
				tinsert(private.missingCraftsTemp, craftString)
			end
		else
			tinsert(private.missingCraftsTemp, craftString)
		end
	end
	if #private.missingCraftsTemp == 0 then
		Log.Info("Crafts up to date for %s / %s", character, profession)
		-- Restart the process to check if we need to get info for any other professions
		private.RestartForAccount(account)
	else
		Log.Info("Requesting %d crafts from %s for %s", #private.missingCraftsTemp, character, profession)
		Sync.CallRPC("CRAFTING_GET_CRAFT_INFO", character, private.RPCGetCraftInfoResultHandler, profession, private.missingCraftsTemp)
	end
	wipe(private.missingCraftsTemp)
end

function private.RPCGetCraftInfo(profession, craftStrings)
	for _, tbl in pairs(private.craftInfoTemp) do
		wipe(tbl)
	end
	local character = SessionInfo.GetCharacterName()
	for i, craftString in ipairs(craftStrings) do
		local craftInfo = private.craftSettingsTable[craftString]
		private.craftInfoTemp.craftStrings[i] = craftString
		private.craftInfoTemp.mats[i] = craftInfo.mats
		private.craftInfoTemp.itemStrings[i] = craftInfo.itemString
		private.craftInfoTemp.names[i] = craftInfo.name
		private.craftInfoTemp.numResults[i] = craftInfo.numResult
		private.craftInfoTemp.hasCDs[i] = craftInfo.hasCD
		private.craftInfoTemp.rootCategoryId[i] = craftInfo.rootCategoryId
		if (LibTSMService.IsRetail() or LibTSMService.IsForever()) and type(craftInfo.players[character]) == "table" then
			private.craftInfoTemp.baseRecipeDifficulties[i] = craftInfo.players[character].baseRecipeDifficulty
			private.craftInfoTemp.baseRecipeQualities[i] = craftInfo.players[character].baseRecipeQuality
			private.craftInfoTemp.maxRecipeQualities[i] = craftInfo.players[character].maxRecipeQuality
			private.craftInfoTemp.expectedRefunds[i] = craftInfo.players[character].expectedRefund
			private.craftInfoTemp.expectedExtraYields[i] = craftInfo.players[character].expectedExtraYield
		end
	end
	Log.Info("Sent %d crafts for %s", #private.craftInfoTemp.craftStrings, profession)
	return profession, private.craftInfoTemp
end

function private.RPCGetCraftInfoResultHandler(success, character, profession, info)
	local account = private.HandleRPCResult("GET_CRAFT_INFO", success, character)
	if not account then
		return
	end

	for i, craftString in CraftInfoDB.WithCraftDBQueryUpdatesPaused(ipairs(info.craftStrings)) do
		CraftInfoDB.Upsert(craftString, info.itemStrings[i], profession, info.rootCategoryId[i], info.names[i], info.numResults[i], character, info.hasCDs[i] and true or false, info.baseRecipeDifficulties[i], info.baseRecipeQualities[i], info.maxRecipeQualities[i])
		CraftInfoDB.SetExpectedProcRates(craftString, character, info.expectedRefunds[i], info.expectedExtraYields[i])
		CraftInfoDB.SetMats(craftString, info.mats[i])
	end
	Log.Info("Added %d crafts from %s for %s", #info.craftStrings, character, profession)
	-- Restart the process to check if we need to get info for any other professions
	private.RestartForAccount(account)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ConnectionChangedHandler(account, character, connected)
	if connected then
		private.accountLookup[character] = account
		private.accountStatus[account] = STATUS.UPDATING
		-- Issue a request for profession info
		Sync.CallRPC("CRAFTING_GET_HASHES", character, private.RPCGetHashesResultHandler)
	else
		private.accountLookup[character] = nil
		private.accountStatus[account] = nil
	end
end

function private.RetryGetHashesRPC()
	for character, account in pairs(private.accountLookup) do
		if private.accountStatus[account] == STATUS.RETRY then
			private.accountStatus[account] = STATUS.UPDATING
			Sync.CallRPC("CRAFTING_GET_HASHES", character, private.RPCGetHashesResultHandler)
		end
	end
end

function private.GetPlayerProfessionHashes(character, resultTbl)
	local query = CraftInfoDB.NewCraftQuery()
		:AutoRelease()
		:ListContains("characters", character)
		:OrderBy("craftString", true)
	for _, craftString, profession, itemString in query:Iterator("craftString", "profession", "itemString") do
		resultTbl[profession] = Hash.Calculate(private.GetCraftHash(craftString, character, itemString), resultTbl[profession])
	end
end

function private.GetCraftHash(craftString, character, itemString)
	local hash = Hash.Calculate(craftString)
	hash = Hash.Calculate(itemString, hash)
	local baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality = Quality.GetInfo(craftString, character)
	if baseRecipeQuality then
		hash = Hash.Calculate(floor(baseRecipeDifficulty * 1000000 + 0.5), hash)
		hash = Hash.Calculate(floor(baseRecipeQuality * 1000 + 0.5), hash)
		hash = Hash.Calculate(floor(maxRecipeQuality + 0.5), hash)
	end
	local expectedRefund, expectedExtraYield = CraftInfoDB.GetExpectedProcRates(craftString, character)
	if expectedRefund or expectedExtraYield then
		hash = Hash.Calculate(floor((expectedRefund or 0) * 100000 + 0.5), hash)
		hash = Hash.Calculate(floor((expectedExtraYield or 0) * 100000 + 0.5), hash)
	end
	return hash
end

function private.HandleRPCResult(tag, success, character)
	local account = private.accountLookup[character]
	if not account then
		if success then
			Log.Warn("Got RPC (%s) response but character (%s) is no longer connected", tag, character)
		else
			Log.Info("RPC (%s) failed and character (%s) is no longer connected", tag, character)
		end
		return nil
	elseif not success then
		-- Request timed out, so try again from the start
		Log.Warn("RPC (%s) timed out (%s)", tag, character)
		private.RestartForAccount(account)
		return nil
	end
	return account
end

function private.RestartForAccount(account)
	private.accountStatus[account] = STATUS.RETRY
	private.retryTimer:RunForTime(RETRY_DELAY)
end

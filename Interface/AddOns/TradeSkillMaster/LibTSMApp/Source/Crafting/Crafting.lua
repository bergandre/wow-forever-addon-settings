-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Crafting = LibTSMApp:Init("Crafting")
local Gathering = LibTSMApp:Include("Crafting.Gathering")
local Restock = LibTSMApp:Include("Crafting.Restock")
local CustomPrice = LibTSMApp:Include("Price.CustomPrice")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local CraftingOperation = LibTSMApp:From("LibTSMSystem"):Include("CraftingOperation")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local Addon = LibTSMApp:From("LibTSMWoW"):Include("API.Addon")
local CraftingService = LibTSMApp:From("LibTSMService"):Include("Crafting")
local Profession = LibTSMApp:From("LibTSMService"):Include("Profession")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settings = nil,
}
local BAD_CRAFTING_PRICE_SOURCES = {
	crafting = true,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Crafting, function(db)
	private.settings = db:NewView("CraftingSettings")
		:AddKey("sync", "internalData", "playerProfessions")
		:AddKey("factionrealm", "internalData", "crafts")
		:AddKey("factionrealm", "internalData", "craftingQueue")
		:AddKey("factionrealm", "internalData", "mats")
		:AddKey("factionrealm", "internalData", "isCraftFavorite")
		:AddKey("factionrealm", "userData", "craftingCooldownIgnore")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
		:AddKey("global", "craftingOptions", "defaultMatCostMethod")
		:AddKey("global", "craftingOptions", "mixedQualityThreshold")
		:Commit()
		:RegisterCallback("destroyValueSource", function() CustomString.InvalidateCache("Destroy") end)

	-- Initialize the player professions code
	Profession.LoadPlayerProfessions(private.settings --[[@as PlayerProfessionsSettings]])

	-- Make sure the default craft price method is valid
	local isValid, err = CustomPrice.Validate(private.settings.defaultCraftPriceMethod, BAD_CRAFTING_PRICE_SOURCES)
	if not isValid then
		ChatMessage.PrintfUser(L["Your default craft value method was invalid so it has been returned to the default. Details: %s"], err)
		private.settings.defaultCraftPriceMethod = private.settings:GetDefaultReadOnly("defaultCraftPriceMethod")
	end

	-- Initialize the crafting service
	local function GetCraftPriceMethod(itemString)
		return CraftingOperation.GetCraftPriceMethod(itemString) or private.settings.defaultCraftPriceMethod
	end
	CraftingService.Load(private.settings.crafts, private.settings.mats, private.settings.isCraftFavorite, private.settings.craftingQueue, private.settings.craftingCooldownIgnore, private.settings.mixedQualityThreshold)
	CraftingService.Configure(GetCraftPriceMethod)
	CraftingService.SetDefaultMatPriceMethod(private.settings.defaultMatCostMethod)
	private.settings:RegisterCallback("defaultMatCostMethod", function()
		CraftingService.SetDefaultMatPriceMethod(private.settings.defaultMatCostMethod)
	end)

	-- Register custom string sources
	local function GetDestroyValue(itemString)
		return CraftingService.GetConversionsValue(itemString, private.settings.destroyValueSource)
	end
	CustomString.RegisterSource("Crafting", "Destroy", L["Destroy Value"], GetDestroyValue, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Crafting", "Crafting", L["Crafting Cost"], CraftingService.GetLowestCostByItem, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Crafting", "MatPrice", L["Crafting Material Cost"], CraftingService.GetMatCost, CustomString.SOURCE_TYPE.VOLATILE)

	-- Register debug command
	SlashCommands.RegisterDebug("clearcraftdb", private.ClearCraftDB)
	SlashCommands.RegisterDebug("clearcraftqueue", private.ClearCraftQueue)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Restocks the specified groups.
---@param groups GroupPathValue[] The groups to restock
function Crafting.RestockGroups(groups)
	Restock.RestockGroups(groups)
end

---Sets the callback which is called when the gathering context changes.
---@param callback fun() The callback function
function Crafting.SetGatheringContextChangedCallback(callback)
	Gathering.SetContextChangedCallback(callback)
end

---Creates a gathering query.
---@return DatabaseQuery
function Crafting.CreateGatheringQuery()
	return Gathering.CreateQuery()
end

---Sets the crafter to gather for.
---@param crafter string The name of the crafter
function Crafting.SetGatheringCrafter(crafter)
	Gathering.SetCrafter(crafter)
end

---Sets the professions to gather for.
---@param professions string[] The profession names
function Crafting.SetGatheringProfessions(professions)
	Gathering.SetProfessions(professions)
end

---Gets the available crafters to gather for.
---@return string[]
function Crafting.GetGatheringCrafterList()
	return Gathering.GetCrafterList()
end

---Gets the available professions to gather for.
---@return string[]|table<string,true>
function Crafting.GetGatheringProfessionList()
	return Gathering.GetProfessionList()
end

---Gets the current crafter.
---@return string?
function Crafting.GetGatheringCrafter()
	return Gathering.GetCrafter()
end

---Gets the current set of professions being gathered for.
---@return table<string,true>
function Crafting.GetGatheringProfessions()
	return Gathering.GetProfessions()
end

---Extracts a sources string from a DB row into tables.
---@param sourcesStr string The string value from the DB
---@param info table<string,number> The result table populated with quantities by source
---@param alts table<string,true> The result table populated with alts being used
function Crafting.GatheringSourcesStrToTable(sourcesStr, info, alts)
	return Gathering.SourcesStrToTable(sourcesStr, info, alts)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ClearCraftDB()
	private.settings.crafts = {}
	Addon.ReloadUI()
end

function private.ClearCraftQueue()
	CraftingService.ClearQueue()
	ChatMessage.PrintUser(L["Crafting queue cleared."])
end

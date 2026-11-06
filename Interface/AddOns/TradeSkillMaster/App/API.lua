-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --
---@diagnostic disable: unused-function
local App = select(2, ...).App
local API = App:Init("API")
local AuctionUI = App:Include("AuctionUI")
local CraftingUI = App:Include("CraftingUI")
local MailingUI = App:Include("MailingUI")
local VendoringUI = App:Include("VendoringUI")
local CallbackRegistry = App:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local Group = App:From("LibTSMTypes"):Include("Group")
local GroupOperation = App:From("LibTSMTypes"):Include("GroupOperation")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local Auction = App:From("LibTSMService"):Include("Auction")
local Guild = App:From("LibTSMService"):Include("Guild")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = App:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Mail = App:From("LibTSMService"):Include("Mail")
local CustomPrice = App:From("LibTSMApp"):Include("Price.CustomPrice")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local AltTracking = App:From("LibTSMApp"):Include("Service.AltTracking")
---@class TSM_API
TSM_API = {}
local private = {
	settingsDB = nil,
	settings = nil,
	groupItemQuery = nil,
	groupItemCallbacks = CallbackRegistry.NewWithKeys("API function (%s)"),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(API, function(db)
	private.settingsDB = db
	private.settings = db:NewView("APISettings")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()
end)



-- ============================================================================
-- UI
-- ============================================================================

---Checks if a TSM UI is currently visible.
---@param uiName "AUCTION"|"CRAFTING"|"MAILING"|"VENDORING" The UI to check
---@return boolean
function TSM_API.IsUIVisible(uiName)
	private.CheckCallMethod(uiName)
	if uiName == "AUCTION" then
		return AuctionUI.IsVisible()
	elseif uiName == "CRAFTING" then
		return CraftingUI.IsVisible()
	elseif uiName == "MAILING" then
		return MailingUI.IsVisible()
	elseif uiName == "VENDORING" then
		return VendoringUI.IsVisible()
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end

---Registers a callback function to be called when a TSM UI is shown or hidden.
---
---The callback is passed `false` when the UI is hidden, and `true, frame` when it is shown.
---@param uiName "CRAFTING" The UI to register the callback for (currently only "CRAFTING" is supported)
---@param addonTag string An arbitrary string which uniquely identifies the addon making this call and its usage (i.e. "MyAddon:CraftingButton")
---@param func fun(shown: boolean, frame?: Frame) The function to call
function TSM_API.RegisterUICallback(uiName, addonTag, func)
	private.CheckCallMethod(uiName)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(func, "function", "func")
	if uiName == "CRAFTING" then
		CraftingUI.RegisterApiCallback(addonTag, func)
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end



-- ============================================================================
-- Groups
-- ============================================================================

---Gets a current list of TSM group paths.
---@param result string[] A table to store the result in
---@return string[] result @The passed table, populated with group paths
function TSM_API.GetGroupPaths(result)
	private.CheckCallMethod(result)
	private.ValidateArgumentType(result, "table", "result")
	for _, groupPath in GroupOperation.GroupIterator() do
		tinsert(result, groupPath)
	end
	return result
end

---Formats a TSM group path into a human-readable form.
---@param path string The group path to be formatted
---@return string
function TSM_API.FormatGroupPath(path)
	private.CheckCallMethod(path)
	private.ValidateGroupPath(path)
	return Group.FormatPath(path)
end

---Splits a TSM group path into its parent path and group name components.
---@param path string The group path to be split
---@return string? parentPath @The path of the parent group, or nil if the specified path has no parent
---@return string groupName @The name of the group
function TSM_API.SplitGroupPath(path)
	private.CheckCallMethod(path)
	private.ValidateGroupPath(path)
	local parentPath, groupName = Group.SplitPath(path)
	if parentPath == Group.GetRootPath() then
		parentPath = nil
	end
	return parentPath, groupName
end

---Gets the path to the group which a specific item is in, or nil if it's not in a group.
---@param itemString string The TSM item string to get the group path of
---@return string?
function TSM_API.GetGroupPathByItem(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	local path = Group.GetPathByItem(itemString)
	return path ~= Group.GetRootPath() and path or nil
end

---Gets all the items within a group.
---@param path string The group path to get the items for
---@param includeSubGroups boolean Whether or not to include items in subgroups
---@param result string[] A table to store the result in
---@return string[] result @The passed table, populated with item strings
function TSM_API.GetGroupItems(path, includeSubGroups, result)
	private.CheckCallMethod(path)
	private.ValidateGroupPath(path)
	private.ValidateArgumentType(includeSubGroups, "boolean", "includeSubGroups")
	private.ValidateArgumentType(result, "table", "result")
	for _, itemString in Group.ItemIterator(path, includeSubGroups) do
		tinsert(result, itemString)
	end
	return result
end

---Registers a callback function to be called when the items within any group changes.
---@param addonTag string An arbitrary string which uniquely identifies the addon making this call and its usage (i.e. "MyAddon:CraftingButton")
---@param func fun() The function to call
function TSM_API.RegisterGroupItemCallback(addonTag, func)
	private.CheckCallMethod(addonTag)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(func, "function", "func")
	if private.groupItemCallbacks:HasCallback(addonTag) then
		error("Callback already registered for addonTag: "..tostring(addonTag), 3)
	end
	private.groupItemQuery = private.groupItemQuery or Group.CreateItemsQuery()
		:SetUpdateCallback(private.GroupsUpdated)
	private.groupItemCallbacks:Add(func, addonTag)
end



-- ============================================================================
-- Profiles
-- ============================================================================

---Gets a current list of TSM profiles.
---@param result string[] A table to store the result in
---@return string[] result @The passed table, populated with profile names
function TSM_API.GetProfiles(result)
	private.CheckCallMethod(result)
	for _, profileName in private.settingsDB:ScopeKeyIterator("profile") do
		tinsert(result, profileName)
	end
	return result
end

---Gets the active TSM profile.
---@return string
function TSM_API.GetActiveProfile()
	return private.settingsDB:GetCurrentProfile()
end

---Sets the active TSM profile.
---@param profile string The name of the profile to make active
function TSM_API.SetActiveProfile(profile)
	private.CheckCallMethod(profile)
	if type(profile) ~= "string" then ---@diagnostic disable-line: redundant-condition
		error("Invalid 'profile' argument type (must be a string): "..tostring(profile), 2)
	elseif not private.settingsDB:ProfileExists(profile) then
		error("Profile does not exist: "..profile, 2)
	elseif profile == private.settingsDB:GetCurrentProfile() then
		error("Profile is already active: "..profile, 2)
	end
	return private.settingsDB:SetProfile(profile)
end



-- ============================================================================
-- Prices
-- ============================================================================

---Gets a list of price source keys which can be used in TSM custom prices.
---@param result string[] A table to store the result in
---@return string[] result @The passed table, populated with price source keys
function TSM_API.GetPriceSourceKeys(result)
	private.CheckCallMethod(result)
	private.ValidateArgumentType(result, "table", "result")
	for _, key in CustomString.SourceIterator() do
		tinsert(result, key)
	end
	return result
end

---Gets the localized description of a given price source key.
---@param key string The price source key
---@return string
function TSM_API.GetPriceSourceDescription(key)
	private.CheckCallMethod(key)
	private.ValidateArgumentType(key, "string", "key")
	local _, label = CustomString.GetSourceInfo(key)
	if not label then
		error("Unknown price source key: "..tostring(key), 2)
	end
	return label
end

---Gets whether or not a custom price string is valid.
---@param customPriceStr string The custom price string
---@return (true isValid, nil)|(false, string errMessage)
function TSM_API.IsCustomPriceValid(customPriceStr)
	private.CheckCallMethod(customPriceStr)
	private.ValidateArgumentType(customPriceStr, "string", "customPriceStr")
	return CustomPrice.Validate(customPriceStr)
end

---Evaluates a custom price string or price source key for a given item.
---@param customPriceStr string The custom price string or price source key to get the value of
---@param itemString string The TSM item string to get the value for
---@return (number value)|(nil, string errMessage)
function TSM_API.GetCustomPriceValue(customPriceStr, itemString)
	private.CheckCallMethod(customPriceStr)
	private.ValidateArgumentType(customPriceStr, "string", "customPriceStr")
	itemString = private.ValidateTSMItemString(itemString)
	return CustomPrice.GetValue(customPriceStr, itemString)
end



-- ============================================================================
-- Money
-- ============================================================================

---Converts a money value to a formatted, human-readable string.
---@param value number The money value in copper to be converted
---@return string
function TSM_API.FormatMoneyString(value)
	private.CheckCallMethod(value)
	private.ValidateArgumentType(value, "number", "value")
	local result = Money.ToStringExact(value)
	assert(result)
	return result
end

---Converts a formatted, human-readable money string to a value.
---@param str string The formatted money string
---@return number value @The money value in copper
function TSM_API.ParseMoneyString(str)
	private.CheckCallMethod(str)
	private.ValidateArgumentType(str, "string", "str")
	local result = Money.FromString(str)
	assert(result)
	return result
end



-- ============================================================================
-- Item
-- ============================================================================

---Converts an item to a TSM item string.
---@param item string Either an item link, TSM item string, or WoW item string
---@return string? itemString @The TSM item string, or nil if the specified item could not be converted
function TSM_API.ToItemString(item)
	private.CheckCallMethod(item)
	private.ValidateArgumentType(item, "string", "item")
	return ItemString.Get(item)
end

---Gets an item's name from a given TSM item string.
---@param itemString string The TSM item string
---@return string? name @The item name, or nil if it couldn't be determined
function TSM_API.GetItemName(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	return ItemInfo.GetName(itemString)
end

---Gets an item link from a given TSM item string.
---@param itemString string The TSM item string
---@return string link @The item link, or an "[Unknown Item]" link
function TSM_API.GetItemLink(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	local result = ItemInfo.GetLink(itemString)
	assert(result)
	return result
end



-- ============================================================================
-- Inventory
-- ============================================================================

---Gets the quantity of an item in a character's bags.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@param character? string The character to get data for (defaults to the current character if not set)
---@param factionrealm? string The factionrealm to get data for (defaults to the current factionrealm if not set)
---@return number
function TSM_API.GetBagQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return BagTracking.GetBagQuantity(itemString)
	else
		return AltTracking.GetBagQuantity(itemString, character, factionrealm)
	end
end

---Gets the quantity of an item in a character's bank.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@param character? string The character to get data for (defaults to the current character if not set)
---@param factionrealm? string The factionrealm to get data for (defaults to the current factionrealm if not set)
---@return number
function TSM_API.GetBankQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return BagTracking.GetBankQuantity(itemString)
	else
		return AltTracking.GetBankQuantity(itemString, character, factionrealm)
	end
end

---Gets the quantity of an item posted to the auction house by a character.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@param character? string The character to get data for (defaults to the current character if not set)
---@param factionrealm? string The factionrealm to get data for (defaults to the current factionrealm if not set)
---@return number
function TSM_API.GetAuctionQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return Auction.GetQuantity(itemString)
	else
		return AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
	end
end

---Gets the quantity of an item in a character's mailbox.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@param character? string The character to get data for (defaults to the current character if not set)
---@param factionrealm? string The factionrealm to get data for (defaults to the current factionrealm if not set)
---@return number
function TSM_API.GetMailQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return Mail.GetQuantity(itemString)
	else
		return AltTracking.GetMailQuantity(itemString, character, factionrealm)
	end
end

---Gets the quantity of an item in a guild's bank.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@param guild? string The guild to get data for (defaults to the current character's guild if not set)
---@return number
function TSM_API.GetGuildQuantity(itemString, guild)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(guild == nil or type(guild) == "string")
	if not guild then
		return Guild.GetQuantity(itemString)
	else
		return AltTracking.GetGuildQuantity(itemString, guild)
	end
end

---Gets the quantity of an item in the warbank.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@return number
function TSM_API.GetWarbankQuantity(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	return WarbankTracking.GetQuantity(itemString)
end

---Gets some total quantities for an item.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@return number numPlayer @The total quantity the current player has (bags, bank, and mail)
---@return number numAlts @The total quantity alt characters have (bags, bank, and mail)
---@return number numAuctions @The total quantity the current player has on the auction house
---@return number numAltAuctions @The total quantity alt characters have on the auction house
function TSM_API.GetPlayerTotals(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	local numPlayer, numAlts, numAuctions, numAltAuctions = 0, 0, 0, 0
	numPlayer = numPlayer + BagTracking.GetBagQuantity(itemString)
	numPlayer = numPlayer + BagTracking.GetBankQuantity(itemString)
	numPlayer = numPlayer + Mail.GetQuantity(itemString)
	numAuctions = numAuctions + Auction.GetQuantity(itemString)
	for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
		for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
			numAlts = numAlts + AltTracking.GetBagQuantity(itemString, character, factionrealm)
			numAlts = numAlts + AltTracking.GetBankQuantity(itemString, character, factionrealm)
			numAlts = numAlts + AltTracking.GetMailQuantity(itemString, character, factionrealm)
			numAltAuctions = numAltAuctions + AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
		end
	end
	return numPlayer, numAlts, numAuctions, numAltAuctions
end

---Gets the total number of items in all tracked guild banks.
---@param itemString string The TSM item string (inventory is tracked by either levelItemString or baseItemString)
---@return number
function TSM_API.GetGuildTotal(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	return AltTracking.GetTotalGuildQuantity(itemString)
end



-- ============================================================================
-- Crafting
-- ============================================================================

---Iterates over all items in the crafting queue.
---@return fun(tbl: table, index: number): number, string, string, number @Iterator with fields: `index`, `recipeString`, `itemString`, `num`
---@return table
---@return number
function TSM_API.CraftingQueueIterator()
	local result = {}
	local query = Crafting.CreateQueueQuery()
	for _, recipeString, craftString, num in query:Iterator("recipeString", "craftString", "num") do
		local itemString = Crafting.GetItemString(craftString)
		tinsert(result, recipeString)
		tinsert(result, itemString)
		tinsert(result, num)
	end
	query:Release()
	return private.CraftingQueueIteratorHelper, result, 0
end

---Gets the materials needed for a specific queued recipe.
---@param recipeString string The recipe string from the crafting queue iterator
---@param result table<string, number> A table to populate with materials, where keys are item strings and values are quantities
function TSM_API.GetCraftingQueueItemMaterials(recipeString, result)
	private.CheckCallMethod(recipeString)
	private.ValidateArgumentType(recipeString, "string", "recipeString")
	if not strmatch(recipeString, "^r:%d+") then
		error("Invalid 'recipeString' argument (must be a valid recipe string): "..tostring(recipeString), 2)
	end
	private.ValidateArgumentType(result, "table", "result")
	for _, itemString, quantity in Crafting.MatIteratorByRecipeString(recipeString) do
		result[itemString] = quantity
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateArgumentType(val, expectedType, name)
	if type(val) ~= expectedType then
		error("Invalid '"..name.."' argument type (must be a "..expectedType.."): "..tostring(val), 3)
	end
end

function private.ValidateTSMItemString(itemString)
	if type(itemString) ~= "string" or not strmatch(itemString, "^[ip]:%d+") then
		error("Invalid 'itemString' argument type (must be a TSM item string): "..tostring(itemString), 3)
	end
	local newItemString = ItemString.Get(itemString)
	if not newItemString then
		error("Invalid TSM itemString: "..itemString, 3)
	end
	return newItemString
end

function private.ValidateGroupPath(path)
	if type(path) ~= "string" then
		error("Invalid 'path' argument type (must be a string): "..tostring(path), 3)
	elseif path == "" then
		error("Invalid 'path' argument (empty string)", 3)
	end
end

function private.CheckCallMethod(firstArg)
	if firstArg == TSM_API then
		error("Invalid usage of colon operator to call TSM_API function", 3)
	end
end

function private.CraftingQueueIteratorHelper(tbl, index)
	index = index + 3
	if index > #tbl then
		return
	end
	return index, tbl[index - 2], tbl[index - 1], tbl[index]
end

function private.GroupsUpdated()
	private.groupItemCallbacks:CallAll()
end

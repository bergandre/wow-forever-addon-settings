-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local AltTracking = LibTSMApp:Init("Service.AltTracking")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local PlayerInfo = LibTSMApp:Include("Service.PlayerInfo")
local Iterator = LibTSMApp:From("LibTSMUtil"):Include("BaseType.Iterator")
local OrderedTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.OrderedTable")
local CallbackRegistry = LibTSMApp:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMApp:From("LibTSMUtil"):Include("Lua.Vararg")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Sync = LibTSMApp:From("LibTSMService"):Include("Sync")
local private = {
	settings = nil,
	quantityDB = nil,
	baseItemQuantityQuery = nil,
	characterFactionrealmCache = {}, ---@type OrderedTable.Table<string,true>
	quantityCallbacks = CallbackRegistry.NewList(), ---@type CallbackRegistry<AltTrackingQuantityCallbackFunc>
	guildIterTemp = {}, ---@type OrderedTable.Table<string,number>
	updateTemp = {
		total = {},
		auction = {},
		prevQuantity = {},
		items = {},
	},
}
local CACHE_SEP = "\001"
local MIRROR_SETTING_KEYS = {
	bagQuantity = true,
	bankQuantity = true,
	auctionQuantity = true,
	mailQuantity = true,
}

---@alias AltTrackingQuantityCallbackFunc fun(items: table<string,number>)



-- ============================================================================
-- Module Loading
-- ============================================================================

AltTracking:OnModuleLoad(function()
	private.quantityDB = Database.NewSchema("INVENTORY_ALT_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("total")
		:AddNumberField("inventory")
		:AddNumberField("auctions")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
end)

AddonSettings.RegisterOnLoad(AltTracking, function(db)
	private.settings = db:NewView("AltTrackingSettings")
		:AddKey("factionrealm", "internalData", "pendingMail")
		:AddKey("factionrealm", "internalData", "guildVaults")
		:AddKey("factionrealm", "coreOptions", "ignoreGuilds")
		:AddKey("sync", "internalData", "bagQuantity")
		:AddKey("sync", "internalData", "bankQuantity")
		:AddKey("sync", "internalData", "auctionQuantity")
		:AddKey("sync", "internalData", "mailQuantity")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()

	private.UpdateDB()
	Sync.RegisterMirrorCallback(function(settingKey)
		if MIRROR_SETTING_KEYS[settingKey] then
			private.UpdateDB()
		end
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback when the alt item quantity changes.
---@param callback AltTrackingQuantityCallbackFunc The callback function
function AltTracking.RegisterQuantityCallback(callback)
	private.quantityCallbacks:Add(callback)
end

function AltTracking.QuantityIterator()
	return private.quantityDB:NewAutoReleaseQuery()
		:Iterator("levelItemString", "total")
end

function AltTracking.GetTotalQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		private.baseItemQuantityQuery:BindParams(itemString)
		return private.baseItemQuantityQuery:Sum("total")
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), "total")
end

function AltTracking.GetTotalGuildQuantity(itemString)
	local total = 0
	for _, guildName, factionrealm in PlayerInfo.GuildIterator() do
		total = total + AltTracking.GetGuildQuantity(itemString, guildName, factionrealm)
	end
	return total
end

function AltTracking.GetQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		private.baseItemQuantityQuery:BindParams(itemString)
		return private.baseItemQuantityQuery:Sum("inventory"), private.baseItemQuantityQuery:Sum("auctions")
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0, 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), "inventory", "auctions")
end

function AltTracking.GetBagQuantity(itemString, character, factionrealm)
	return private.GetInventoryValue(itemString, "bagQuantity", character, factionrealm)
end

function AltTracking.GetBankQuantity(itemString, character, factionrealm)
	return private.GetInventoryValue(itemString, "bankQuantity", character, factionrealm)
end

function AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
	return private.GetInventoryValue(itemString, "auctionQuantity", character, factionrealm)
end

function AltTracking.GetMailQuantity(itemString, character, factionrealm)
	local pendingQuantity = private.GetPendingMailQuantity(itemString, character, factionrealm)
	return private.GetInventoryValue(itemString, "mailQuantity", character, factionrealm) + pendingQuantity
end

function AltTracking.GuildItemIterator()
	assert(not next(private.guildIterTemp))
	for _, guildName, factionrealm in PlayerInfo.GuildIterator() do
		local guildItems = private.settings:GetForScopeKey("guildVaults", factionrealm)[guildName]
		if guildItems then
			for levelItemString, quantity in pairs(guildItems) do
				OrderedTable.InsertIfNotSet(private.guildIterTemp, levelItemString, 0)
				private.guildIterTemp[levelItemString] = private.guildIterTemp[levelItemString] + quantity
			end
		end
	end
	return Iterator.Acquire(OrderedTable.Iterator(private.guildIterTemp))
		:SetCleanupFunc(Table.WipeAndDeallocate)
end

function AltTracking.GetGuildQuantity(itemString, guild, factionrealm)
	assert(guild)
	local ignoreGuilds = private.settings:GetForScopeKey("ignoreGuilds", factionrealm)
	local guildVaults = private.settings:GetForScopeKey("guildVaults", factionrealm)
	if not ignoreGuilds or not guildVaults or ignoreGuilds[guild] then
		return 0
	end
	return private.GetItemQuantityFromSettingsTable(guildVaults[guild], itemString)
end

function AltTracking.CharacterIterator()
	return Iterator.Acquire(OrderedTable.Iterator(private.characterFactionrealmCache))
		:SetMapFunc(private.CharacterIteratorMap)
end

function AltTracking.GuildQuantityIterator(itemString)
	assert(not next(private.guildIterTemp))
	for _, guildName, factionrealm in PlayerInfo.GuildIterator() do
		local quantity = AltTracking.GetGuildQuantity(itemString, guildName, factionrealm)
		if quantity > 0 then
			Table.InsertMultiple(private.guildIterTemp, guildName, quantity)
		end
	end
	return Iterator.Acquire(Table.StrideIterator(private.guildIterTemp, 2))
		:SetCleanupFunc(Table.WipeAndDeallocate)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateDB()
	-- Grab our temp tables
	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end

	wipe(private.characterFactionrealmCache)
	for _, key in Vararg.Iterator("bagQuantity", "bankQuantity", "auctionQuantity", "mailQuantity") do
		for _, data, character, factionrealm in private.settings:AccessibleValueIterator(key) do
			if not SessionInfo.IsPlayer(character, factionrealm) then
				local cacheKey = character..CACHE_SEP..factionrealm
				OrderedTable.InsertIfNotSet(private.characterFactionrealmCache, cacheKey, true)
				for levelItemString, quantity in pairs(data) do
					if quantity <= 0 then
						data[levelItemString] = nil
					else
						if key == "auctionQuantity" then
							updateTemp.auction[levelItemString] = (updateTemp.auction[levelItemString] or 0) + quantity
						end
						updateTemp.total[levelItemString] = (updateTemp.total[levelItemString] or 0) + quantity
					end
				end
			end
		end
	end
	for _, data, factionrealm in private.settings:AccessibleValueIterator("pendingMail") do
		for character, pendingQuantity in pairs(data) do
			local isValid = true
			for levelItemString, quantity in pairs(pendingQuantity) do
				if type(quantity) ~= "number" or quantity < 0 then
					isValid = false
					break
				end
				if not SessionInfo.IsPlayer(character, factionrealm) then
					updateTemp.total[levelItemString] = (updateTemp.total[levelItemString] or 0) + quantity
				end
			end
			if not isValid then
				data[character] = nil
			end
		end
	end
	OrderedTable.SortByKeys(private.characterFactionrealmCache)
	private.quantityDB:NewAutoReleaseQuery()
		:AsTable(private.updateTemp.prevQuantity, "levelItemString", "total")
	private.quantityDB:TruncateAndBulkInsertStart()
	for levelItemString, quantity in pairs(updateTemp.total) do
		local auction = (updateTemp.auction[levelItemString] or 0)
		assert(quantity >= auction)
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity, quantity - auction, auction)
	end
	private.quantityDB:BulkInsertEnd()
	Table.GetChangedKeys(updateTemp.prevQuantity, updateTemp.total, updateTemp.items)
	if next(updateTemp.items) then
		-- Add the base items
		ItemString.AddBaseItemStringKeys(updateTemp.items)
		private.quantityCallbacks:CallAll(updateTemp.items)
	end

	-- Wipe our temp tables
	for _, tbl in pairs(updateTemp) do
		Table.WipeAndDeallocate(tbl)
	end
end

function private.GetInventoryValue(itemString, settingKey, character, factionrealm)
	local tbl = nil
	if character then
		tbl = private.settings:GetForScopeKey(settingKey, character, factionrealm)
	else
		tbl = private.settings:GetForScopeKey(settingKey, nil)
	end
	return private.GetItemQuantityFromSettingsTable(tbl, itemString)
end

function private.GetPendingMailQuantity(itemString, character, factionrealm)
	character = character or SessionInfo.GetCharacterName()
	-- TODO: Figure out how to track pendingMail across accounts
	-- TODO: Update this code to support pendingMail across connected realms
	if factionrealm and factionrealm ~= SessionInfo.GetFactionrealmName() then
		return 0
	end
	return private.GetItemQuantityFromSettingsTable(private.settings.pendingMail[character], itemString)
end

function private.GetItemQuantityFromSettingsTable(tbl, itemString)
	if not tbl then
		return 0
	end

	-- If we got passed a non-base item, return the quantity for the item level version
	if itemString ~= ItemString.GetBaseFast(itemString) then
		local levelItemString = ItemString.ToLevel(itemString)
		return tbl[levelItemString] or 0
	end

	-- If there is a value within the table for this item, then there aren't any non-base versions of it
	if tbl[itemString] then
		return tbl[itemString]
	end

	-- Get the sum of all the item level versions of the base item we're looking up
	local totalQuantity = 0
	for entryItemString, quantity in pairs(tbl) do
		if ItemString.GetBaseFast(entryItemString) == itemString then
			totalQuantity = totalQuantity + quantity
		end
	end

	return totalQuantity
end

function private.CharacterIteratorMap(_, cacheKey)
	local character, factionrealm = strsplit(CACHE_SEP, cacheKey)
	return character, factionrealm
end

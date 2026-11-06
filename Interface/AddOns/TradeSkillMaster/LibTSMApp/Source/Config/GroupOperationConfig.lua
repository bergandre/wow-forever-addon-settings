-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local GroupOperationConfig = LibTSMApp:Init("Config.GroupOperationConfig")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local CustomPrice = LibTSMApp:Include("Price.CustomPrice")
local PlayerInfo = LibTSMApp:Include("Service.PlayerInfo")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMApp:From("LibTSMTypes"):Include("GroupOperation")
local Operation = LibTSMApp:From("LibTSMTypes"):Include("Operation")
local OperationUtil = LibTSMApp:From("LibTSMSystem"):Include("Operation.Util")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local CraftingOperation = LibTSMApp:From("LibTSMSystem"):Include("CraftingOperation")
local MailingOperation = LibTSMApp:From("LibTSMSystem"):Include("MailingOperation")
local ShoppingOperation = LibTSMApp:From("LibTSMSystem"):Include("ShoppingOperation")
local SniperOperation = LibTSMApp:From("LibTSMSystem"):Include("SniperOperation")
local VendoringOperation = LibTSMApp:From("LibTSMSystem"):Include("VendoringOperation")
local WarehousingOperation = LibTSMApp:From("LibTSMSystem"):Include("WarehousingOperation")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settingsDB = nil,
	settings = nil,
	connectedCharacterCache = {},
}
local BAD_CRAFTING_PRICE_SOURCES = {
	crafting = true,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

-- Split this out to a local so we can call it from the unit test
AddonSettings.RegisterOnLoad(GroupOperationConfig, function(db)
	local factionrealm = SessionInfo.GetFactionrealmName()
	local characterKey = SessionInfo.GetCharacterName().." - "..factionrealm
	Operation.SetPlayerInfo(characterKey, factionrealm)
	private.settingsDB = db
	private.settings = db:NewView("GroupOperationConfigSettings")
		:AddKey("global", "coreOptions", "globalOperations")
		:AddKey("global", "userData", "sharedOperations")
		:AddKey("profile", "userData", "operations")
		:AddKey("profile", "userData", "groups")
		:AddKey("profile", "userData", "items")
		:AddKey("profile", "internalData", "createdDefaultOperations")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()
		:RegisterCallback("operations", GroupOperationConfig.Reload)
	if private.settings.globalOperations then
		Operation.Load(private.settings.sharedOperations)
	else
		Operation.Load(private.settings.operations)
	end
	Operation.SetShouldCreateDefault(not private.settings.createdDefaultOperations)
	private.settings.createdDefaultOperations = true

	OperationUtil.SetFrameTimeFunc(ClientInfo.GetFrameNumber)
	AuctioningOperation.Load(L["Auctioning"], (not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic()), (LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and ItemInfo.GetMaxStack or nil)
	CraftingOperation.Load(L["Crafting"], private.ValidateCraftingCraftPriceMethod)
	MailingOperation.Load(L["Mailing"], private.GetMailingTargetQuantity, PlayerInfo.IsPlayer, private.GetMailingBagQuantity)
	ShoppingOperation.Load(L["Shopping"], private.GetShoppingInventoryNum)
	SniperOperation.Load(L["Sniper"])
	VendoringOperation.Load(L["Vendoring"], private.GetVendoringInventoryNum)
	WarehousingOperation.Load(L["Warehousing"], private.GetWarehousingBagQuantity)

	GroupOperation.Configure()
	GroupOperationConfig.Reload()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function GroupOperationConfig.Reload()
	if private.settings.globalOperations then
		Operation.Load(private.settings.sharedOperations)
	else
		Operation.Load(private.settings.operations)
	end
	GroupOperation.Load(private.settings.groups, private.settings.items)
end

function GroupOperationConfig.SetOperationsStoredGlobally(storeGlobally)
	private.settings.globalOperations = storeGlobally
	if storeGlobally then
		-- Move the current profile operations to global
		private.settings.sharedOperations = CopyTable(private.settings.operations)
		-- Clear out old profile operations
		for _, profile in private.settingsDB:ScopeKeyIterator("profile") do
			private.settings:SetForScopeKey("operations", nil, profile)
		end
	else
		-- Copy global operations to all profiles
		for _, profile in private.settingsDB:ScopeKeyIterator("profile") do
			private.settings:SetForScopeKey("operations", CopyTable(private.settings.sharedOperations), profile)
		end
		-- Clear out old global operations
		private.settings.sharedOperations = nil
	end
	GroupOperationConfig.Reload()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateCraftingCraftPriceMethod(value, operationName)
	local isValid, err = CustomPrice.Validate(value, BAD_CRAFTING_PRICE_SOURCES)
	if not isValid then
		ChatMessage.PrintfUser(L["Your craft value method for '%s' was invalid so it has been returned to the default."].." "..err, operationName)
		return false
	end
	return true
end

function private.GetMailingBagQuantity(itemString)
	return BagTracking.CreateQueryBagsMailable()
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Sum("quantity")
end

function private.GetMailingTargetQuantity(player, itemString, includeGuild, includeBank)
	if player then
		-- TODO: Support targets on connected realms
		player = strmatch(player, "^[^-]+")
		assert(player)
		player = strtrim(player)
	end
	local num = AltTracking.GetBagQuantity(itemString, player) + AltTracking.GetMailQuantity(itemString, player) + AltTracking.GetAuctionQuantity(itemString, player)
	if includeGuild then
		assert(player)
		local guild = PlayerInfo.GetPlayerGuild(player, SessionInfo.GetFactionrealmName())
		if guild then
			num = num + AltTracking.GetGuildQuantity(itemString, guild)
		end
	end
	if includeBank then
		num = num + AltTracking.GetBankQuantity(itemString, player)
	end
	return num
end

function private.GetShoppingInventoryNum(itemString, includeBank, includeAuctions, includeAlts, includeGuild)
	-- Check the total inventory as an optimization
	if (CustomString.GetSourceValue("NumInventory", itemString) or 0) == 0 then
		return 0
	end

	local numHave = Mail.GetQuantity(itemString)
	if includeBank then
		numHave = numHave + BagTracking.GetTotalQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
	else
		numHave = numHave + BagTracking.GetBagQuantity(itemString)
	end
	if includeGuild then
		numHave = numHave + Guild.GetQuantity(itemString)
	end
	if includeAlts or includeAuctions then
		if includeAuctions then
			numHave = numHave + Auction.GetQuantity(itemString)
		end
		if private.connectedCharacterCache.time ~= ClientInfo.GetFrameNumber() then
			wipe(private.connectedCharacterCache)
			for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
				for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
					tinsert(private.connectedCharacterCache, factionrealm)
					tinsert(private.connectedCharacterCache, character)
				end
			end
			private.connectedCharacterCache.time = ClientInfo.GetFrameNumber()
		end
		for _, factionrealm, character in Table.StrideIterator(private.connectedCharacterCache, 2) do
			if includeAlts then
				numHave = numHave + AltTracking.GetBagQuantity(itemString, character, factionrealm)
				numHave = numHave + AltTracking.GetBankQuantity(itemString, character, factionrealm)
				numHave = numHave + AltTracking.GetMailQuantity(itemString, character, factionrealm)
			end
			if includeAuctions then
				numHave = numHave + AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
			end
		end
	end
	return numHave
end

function private.GetVendoringInventoryNum(itemString, includeBank, includeGuild, includeAuctions, includeMail, includeAlts, includeAltAuctions)
	-- TODO: Need to look into why we're doing this complex query for bags, but not for anything else
	local numHave = BagTracking.CreateQueryBagsItem(itemString)
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Sum("quantity")
	if includeBank then
		local _, bankQuantity = BagTracking.GetQuantities(itemString)
		numHave = numHave + bankQuantity + WarbankTracking.GetQuantity(itemString)
	end
	if includeGuild then
		numHave = numHave + Guild.GetQuantity(itemString)
	end
	if includeAuctions then
		numHave = numHave + Auction.GetQuantity(itemString)
	end
	if includeMail then
		numHave = numHave + Mail.GetQuantity(itemString)
	end
	if includeAlts or includeAltAuctions then
		local numAlts, numAltAuctions = AltTracking.GetQuantity(itemString)
		numHave = numHave + (includeAlts and numAlts or 0) + (includeAltAuctions and numAltAuctions or 0)
	end
	return numHave
end

function private.GetWarehousingBagQuantity(itemString)
	return BagTracking.CreateQueryBagsItem(itemString)
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Sum("quantity")
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Inventory = LibTSMApp:Init("Service.Inventory")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.WarbankTracking")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local private = {
	sources = {},
	settingsDB = nil,
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Inventory:OnModuleLoad(function()
	CustomString.RegisterSource("Item", "NumInventory", L["Total Inventory Quantity"], Inventory.GetTotalQuantity, CustomString.SOURCE_TYPE.NORMAL)
	CustomStringFormat.SetFormat("NumInventory", CustomStringFormat.FORMAT.NUMBER)
	tinsert(private.sources, "NumInventory")
end)

AddonSettings.RegisterOnLoad(Inventory, function(db)
	private.settingsDB = db
	private.settings = db:NewView("InventorySettings")
		:AddKey("sync", "internalData", "bagQuantity")
		:AddKey("sync", "internalData", "bankQuantity")
		:AddKey("char", "internalData", "auctionSaleHints")
		:AddKey("factionrealm", "internalData", "expiringAuction")
		:AddKey("sync", "internalData", "auctionQuantity")
		:AddKey("factionrealm", "internalData", "pendingMail")
		:AddKey("factionrealm", "internalData", "expiringMail")
		:AddKey("sync", "internalData", "mailQuantity")
		:AddKey("factionrealm", "internalData", "guildVaults")
		:AddKey("global", "mailingOptions", "recentlyMailedList")
		:AddKey("global", "internalData", "warbankQuantity")
		:Commit()

	-- Bag tracking
	BagTracking.Load(private.settings.bagQuantity, private.settings.bankQuantity)
	BagTracking.Start()
	BagTracking.RegisterQuantityCallback(private.QuantityChangedCallback)

	-- Warbank tracking
	WarbankTracking.Load(private.settings.warbankQuantity)
	WarbankTracking.Start()
	WarbankTracking.RegisterQuantityCallback(private.QuantityChangedCallback)

	-- Auction tracking
	Auction.Load(private.settings.auctionQuantity, private.settings.auctionSaleHints, private.settings.expiringAuction)
	Auction.Start()
	Auction.RegisterQuantityCallback(private.QuantityChangedCallback)

	-- Mail Tracking
	private.SanitizePendingMail()
	Mail.Load(private.settings.mailQuantity, private.settings.pendingMail, private.settings.expiringMail, db, private.settings.recentlyMailedList, private.ValidateMailCharacter, L["TSM Mailing"])
	Mail.Start()
	Mail.RegisterQuantityCallback(private.QuantityChangedCallback)

	-- Guild Tracking
	Guild.Load(private.settings.guildVaults)
	Guild.Start()

	AltTracking.RegisterQuantityCallback(private.QuantityChangedCallback)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a custom source which depends on the inventory quantity.
---@param source string The custom source
function Inventory.RegisterDependentCustomSource(source)
	tinsert(private.sources, source)
end

---Gets the total inventory quantity for an item.
---@param itemString string The item string
---@return number
function Inventory.GetTotalQuantity(itemString)
	local total = 0
	total = total + BagTracking.GetBagQuantity(itemString)
	total = total + BagTracking.GetBankQuantity(itemString)
	total = total + WarbankTracking.GetQuantity(itemString)
	total = total + Mail.GetQuantity(itemString)
	total = total + Auction.GetQuantity(itemString)
	total = total + AltTracking.GetTotalQuantity(itemString)
	total = total + AltTracking.GetTotalGuildQuantity(itemString)
	return total
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizePendingMail()
	-- Remove pending mail data for characters we don't own
	for character in pairs(private.settings.pendingMail) do
		if private.settingsDB:GetOwnerSyncAccountKey(character) ~= private.settingsDB:GetLocalSyncAccountKey() then
			Log.Info("Removed pending mail data for %s", character)
			private.settings.pendingMail[character] = nil
		end
	end
end

function private.ValidateMailCharacter(character)
	if not character then
		return nil
	end
	local characterName, realm = strsplit("-", strlower(character))
	---@cast realm string?
	-- We only care to track mails with characters on this realm
	if realm and realm ~= strlower(SessionInfo.GetRealmName()) then
		return nil
	end
	-- We only care to track mails with characters on this account
	local iter = private.settingsDB:AccessibleCharacterIterator(private.settingsDB:GetLocalSyncAccountKey())
	for _, name in iter do
		if strlower(name) == characterName then
			iter:Release()
			return name
		end
	end
	return nil
end

function private.QuantityChangedCallback(updatedItems)
	for _, source in ipairs(private.sources) do
		for itemString in pairs(updatedItems) do
			CustomString.InvalidateCache(source, itemString)
		end
	end
end

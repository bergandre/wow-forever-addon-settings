-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Inventory = LibTSMApp:InitInternal("Tooltip.General.Inventory")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local InventoryService = LibTSMApp:Include("Service.Inventory")
local Vararg = LibTSMApp:From("LibTSMUtil"):Include("Lua.Vararg")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local CharacterInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.CharacterInfo")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.WarbankTracking")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local private = {
	settings = nil,
	partsTemp = {},
}
local IGNORE_INVENTORY_ITEMS = {
	["i:6948"] = true, -- Hearthstone
	["i:110560"] = true, -- Garrison Hearthstone
	["i:140192"] = true, -- Dalaran Hearthstone
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Inventory, function(db)
	private.settings = db:NewView("InventorySettings")
		:AddKey("sync", "internalData", "classKey")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds tooltip entries.
---@param tooltipInfo TooltipInfo
function Inventory.AddEntries(tooltipInfo)
	tooltipInfo:AddSettingValueEntry("inventoryTooltipFormat", "full", "none", nil, private.PopulateFullInventoryLines)
	tooltipInfo:AddSettingValueEntry("inventoryTooltipFormat", "simple", "none", nil, private.PopulateSimpleInventoryLine)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateFullInventoryLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		local bag, bank, auction, mail, guild = 5, 4, 4, 9, 1
		local warbank = LibTSMApp.IsRetail() and 2 or 0
		local total = bag + bank + auction + mail + guild + warbank
		tooltip:StartSection(L["Inventory"], format(L["%s total"], tooltip:ApplyValueColor(total)))
		private.AddFullLine(tooltip, nil, nil, bag, bank, auction, mail)
		tooltip:AddLine(L["Example"], format(L["%s in guild vault"], tooltip:ApplyValueColor(guild)))
		if warbank > 0 then
			tooltip:AddLine(L["Warbank"], tooltip:ApplyValueColor(warbank))
		end
		tooltip:EndSection()
		return
	elseif IGNORE_INVENTORY_ITEMS[itemString] then
		return
	end

	-- Calculate the total number
	local total = InventoryService.GetTotalQuantity(itemString)
	tooltip:StartSection(L["Inventory"], format(L["%s total"], tooltip:ApplyValueColor(total)))

	-- Add a line for the current character
	private.AddFullLine(tooltip, nil, nil, private.GetCurrentCharacterQuantities(itemString))

	-- Add lines for alts
	for _, character, factionrealm in AltTracking.CharacterIterator() do
		private.AddFullLine(tooltip, character, factionrealm, private.GetAltQuantities(itemString, character, factionrealm))
	end

	-- Add lines for guilds
	for _, guildName, guildQuantity in AltTracking.GuildQuantityIterator(itemString) do
		tooltip:AddLine(guildName, tooltip:ApplyValueColor(guildQuantity))
	end

	-- Add line for the warbank
	local warbankQuantity = WarbankTracking.GetQuantity(itemString)
	if warbankQuantity > 0 then
		tooltip:AddLine(L["Warbank"], tooltip:ApplyValueColor(warbankQuantity))
	end

	tooltip:EndSection()
end

function private.GetCurrentCharacterQuantities(itemString)
	local bag = BagTracking.GetBagQuantity(itemString)
	local bank = BagTracking.GetBankQuantity(itemString)
	local auction = Auction.GetQuantity(itemString)
	local mail = Mail.GetQuantity(itemString)
	return bag, bank, auction, mail
end

function private.GetAltQuantities(itemString, character, factionrealm)
	local bag = AltTracking.GetBagQuantity(itemString, character, factionrealm)
	local bank = AltTracking.GetBankQuantity(itemString, character, factionrealm)
	local auction = AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
	local mail = AltTracking.GetMailQuantity(itemString, character, factionrealm)
	return bag, bank, auction, mail
end

---@param tooltip TooltipBuilder
function private.AddFullLine(tooltip, character, factionrealm, bag, bank, auction, mail)
	local total = bag + bank + auction + mail
	if total == 0 then
		return
	end
	local characterStr = character and SessionInfo.FormatCharacterName(character, factionrealm) or SessionInfo.GetCharacterName()
	local classKey = private.settings:GetForScopeKey("classKey", character or SessionInfo.GetCharacterName(), factionrealm)
	local classColor = CharacterInfo.GetClassRaidColorString(classKey)
	characterStr = classColor and "|c"..classColor..characterStr.."|r" or characterStr
	local rightText = private.RightTextFormatHelper(tooltip, L["%s (%s bags, %s bank, %s AH, %s mail)"], total, bag, bank, auction, mail)
	tooltip:AddLine(characterStr, rightText)
end

---@param tooltip TooltipBuilder
function private.PopulateSimpleInventoryLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		private.AddSimpleLine(tooltip, 18, 0, 1, 4, 2)
		return
	elseif IGNORE_INVENTORY_ITEMS[itemString] then
		return
	end

	local alt, altAuction = AltTracking.GetQuantity(itemString)
	local player = BagTracking.GetBagQuantity(itemString) + BagTracking.GetBankQuantity(itemString) + Mail.GetQuantity(itemString)
	local auction = Auction.GetQuantity(itemString) + altAuction
	local guild = AltTracking.GetTotalGuildQuantity(itemString)
	local warbank = WarbankTracking.GetQuantity(itemString)
	private.AddSimpleLine(tooltip, player, alt, guild, warbank, auction)
end

---@param tooltip TooltipBuilder
function private.AddSimpleLine(tooltip, player, alt, guild, warbank, auction)
	local total = player + alt + guild + auction + warbank
	if total == 0 then
		return
	end
	local rightText = nil
	if LibTSMApp.IsRetail() then
		rightText = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s guild, %s warbank, %s AH)"], total, player, alt, guild, warbank, auction)
	elseif LibTSMApp.IsMistsClassic() or LibTSMApp.IsForever() then
		rightText = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s guild, %s AH)"], total, player, alt, guild, auction)
	else
		rightText = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s AH)"], total, player, alt, auction)
	end
	tooltip:AddLine(L["Inventory"], rightText)
end

---@param tooltip TooltipBuilder
function private.RightTextFormatHelper(tooltip, fmtStr, ...)
	assert(#private.partsTemp == 0)
	Vararg.IntoTable(private.partsTemp, ...)
	for i = 1, #private.partsTemp do
		private.partsTemp[i] = tooltip:ApplyValueColor(private.partsTemp[i])
	end
	local result = format(fmtStr, unpack(private.partsTemp))
	wipe(private.partsTemp)
	return result
end

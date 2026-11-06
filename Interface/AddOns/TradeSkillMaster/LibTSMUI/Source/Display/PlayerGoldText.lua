-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local UISettings = LibTSMUI:Include("Util.UISettings")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local SessionInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auction = LibTSMUI:From("LibTSMService"):Include("Auction")
local private = {
	tooltipTemp = {},
}

---@class PlayerGoldTextSettings: SettingsView
---@field money number
---@field showTotalMoney boolean
---@field regionWide boolean
---@field warbankMoney number



-- ============================================================================
-- Element Definition / Static Class Functions
-- ============================================================================

local PlayerGoldText = ComponentRegistry.Define("PlayerGoldText", "BaseButton")
PlayerGoldText._STATE_SCHEMA = PlayerGoldText._STATE_SCHEMA:Extend("PlayerGoldTextState")
	:UpdateFieldDefault("justifyH", "RIGHT")
	:UpdateFieldDefault("font", "TABLE_XSMALL")
	:Commit()
UISettings.RegisterKeys("money", "showTotalMoney", "regionWide", "warbankMoney")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PlayerGoldText:__init()
	self.__super:__init()
	self._uiSettings = UISettings.Get() --[[@as PlayerGoldTextSettings]]
end

function PlayerGoldText:Acquire()
	self.__super:Acquire()
	self:SetTooltip(self:__closure("_GetTooltip"))
	self:SetText(self._uiSettings:PublisherForKeys("money", "showTotalMoney", "regionWide", "warbankMoney"):Map(private.SettingsToText))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function PlayerGoldText.__private:_GetTooltip()
	assert(not next(private.tooltipTemp))
	local playerMoney = self._uiSettings.money
	local total = playerMoney
	tinsert(private.tooltipTemp, private.GetTooltipLine(SessionInfo.GetCharacterName(), playerMoney))
	local numPosted, numSold, postedGold, soldGold = Auction.GetSummaryInfo()
	if numPosted then
		tinsert(private.tooltipTemp, private.GetTooltipLine(format("  "..L["%s Sold Auctions"], numSold), soldGold))
		tinsert(private.tooltipTemp, private.GetTooltipLine(format("  "..L["%s Posted Auctions"], numPosted), postedGold))
	end
	for _, money, character, factionrealm in self._uiSettings:AccessibleValueIterator("money") do
		if money > 0 and not SessionInfo.IsPlayer(character, factionrealm) then
			character = SessionInfo.FormatCharacterName(character, factionrealm)
			tinsert(private.tooltipTemp, private.GetTooltipLine(character, money))
			total = total + money
		end
	end
	if LibTSMUI.IsRetail() then
		local warbankMoney = self._uiSettings.warbankMoney
		tinsert(private.tooltipTemp, private.GetTooltipLine(L["Warbank"], warbankMoney))
		total = total + warbankMoney
	end
	tinsert(private.tooltipTemp, 1, private.GetTooltipLine(L["Total Gold"], total))
	local result = table.concat(private.tooltipTemp, "\n")
	wipe(private.tooltipTemp)
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param settings PlayerGoldTextSettings
function private.SettingsToText(settings)
	local amount = settings.money
	if settings.showTotalMoney then
		for _, money, character, factionrealm in settings:AccessibleValueIterator("money") do
			if money > 0 and not SessionInfo.IsPlayer(character, factionrealm) then
				amount = amount + money
			end
		end
		amount = amount + settings.warbankMoney
	end
	return Money.ToStringForUI(amount)
end

function private.GetTooltipLine(label, value)
	return strjoin(TooltipUI.GetSepChar(), label..":", Money.ToStringForUI(value))
end

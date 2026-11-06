-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local Guild = App:From("LibTSMWoW"):Include("API.Guild")
local Merchant = App:From("LibTSMWoW"):Include("API.Merchant")
local SoundAlert = App:From("LibTSMWoW"):Include("UI.SoundAlert")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Vendor = App:From("LibTSMService"):Include("Vendor")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local TooltipUI = App:From("LibTSMUI"):Include("TooltipUI")
local private = {
	tooltipTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorRepairButton = UIElements.Define("VendorRepairButton", "MediumPrimaryActionButton")
VendorRepairButton._STATE_SCHEMA = VendorRepairButton._STATE_SCHEMA:Extend("VendorRepairButtonState")
	:AddBooleanField("repairDisabled", true)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorRepairButton:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function VendorRepairButton:Acquire()
	self.__super:Acquire()
	self:SetManager(self._childManager)
	self:SetText(L["Repair"])
	self:SetModifierText(L["Repair from Guild Bank"], "ALT")
	self:SetTooltip(self:__closure("_GetTooltip"))
	for _ in self._state:WithAutoStorePaused() do
		self:SetDisabled(self._state:Publisher("repairDisabled"))
	end
	self:AddCancellable(Vendor.NeedsRepairPublisher():InvertBoolean():AssignToTableKey(self._state, "repairDisabled"))
	self:SetAction("OnClick", "ACTION_REPAIR")
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<VendorRepairButtonState>
---@param state VendorRepairButtonState
function VendorRepairButton.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_REPAIR" then
		if IsAltKeyDown() then
			if not Vendor.CanGuildRepair() then
				ChatMessage.PrintfUser(L["Cannot repair from the guild bank!"])
				return
			end
			Vendor.DoGuildRepair()
		else
			Vendor.DoRepair()
		end
		SoundAlert.Play("Repair", true)
	else
		error("Unknown action: "..tostring(action))
	end
end

function VendorRepairButton.__private:_GetTooltip()
	local repairAllCost, canRepair = Merchant.GetRepairAllCost()
	if not canRepair or repairAllCost <= 0 then
		return ""
	end

	assert(not next(private.tooltipTemp))
	tinsert(private.tooltipTemp, REPAIR_ALL_ITEMS..TooltipUI.GetSepChar()..Money.ToStringForUI(repairAllCost))
	if IsAltKeyDown() then
		local amount = Guild.GetWithdrawMoney()
		local guildBankMoney = Guild.GetMoney()
		if amount == -1 then
			amount = guildBankMoney
		else
			amount = min(amount, guildBankMoney)
		end
		tinsert(private.tooltipTemp, GUILDBANK_REPAIR..TooltipUI.GetSepChar()..Money.ToStringForUI(amount))
		if repairAllCost > amount then
			local personalAmount = repairAllCost - amount
			local personalMoney = Currency.GetMoney()
			if personalMoney >= personalAmount then
				tinsert(private.tooltipTemp, GUILDBANK_REPAIR_PERSONAL..TooltipUI.GetSepChar()..Money.ToStringForUI(personalAmount))
			else
				tinsert(private.tooltipTemp, Theme.GetColor("error/main"):ColorText(GUILDBANK_REPAIR_INSUFFICIENT_FUNDS))
			end
		end
	else
		local personalMoney = Currency.GetMoney()
		if repairAllCost > personalMoney then
			tinsert(private.tooltipTemp, Theme.GetColor("error/main"):ColorText(GUILDBANK_REPAIR_INSUFFICIENT_FUNDS))
		end
		tinsert(private.tooltipTemp, L["Hold ALT to repair from the guild bank."])
	end
	local result = table.concat(private.tooltipTemp, "\n")
	wipe(private.tooltipTemp)
	return result
end

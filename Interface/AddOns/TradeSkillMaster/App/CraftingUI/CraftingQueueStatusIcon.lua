-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local TooltipUI = App:From("LibTSMUI"):Include("TooltipUI")
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingQueueStatusIcon = UIElements.Define("CraftingQueueStatusIcon", "BaseButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftingQueueStatusIcon:Acquire()
	self.__super:Acquire()
	self:SetBackgroundAndSize("iconPack.12x12/Attention")
	self:SetTooltip(self:__closure("_GetTooltip"))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftingQueueStatusIcon.__private:_GetTooltip()
	local totalCost, totalProfit, totalCastTime = Crafting.GetQueueTotals()
	local totalCostStr = totalCost and Money.ToStringForUI(totalCost) or "---"
	local totalProfitStr = totalProfit and Money.ToStringForUI(totalProfit, Theme.GetColor(totalProfit >= 0 and "positive/main" or "error/main"):GetTextColorPrefix()) or "---"
	local totalCastTimeStr = totalCastTime and TimeFormat.Duration(totalCastTime) or "---"
	local tooltipStr = strjoin("\n",
		Theme.GetColor("accent/main"):ColorText(L["Queue Summary"]),
		L["Crafting Cost"]..":"..TooltipUI.GetSepChar()..totalCostStr,
		L["Estimated Profit"]..":"..TooltipUI.GetSepChar()..totalProfitStr,
		L["Estimated Time"]..":"..TooltipUI.GetSepChar()..totalCastTimeStr
	)
	return tooltipStr, true, 16
end

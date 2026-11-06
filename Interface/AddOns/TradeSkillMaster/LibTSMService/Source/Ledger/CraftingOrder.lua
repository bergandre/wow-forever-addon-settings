-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CraftingOrder = LibTSMService:Init("Ledger.CraftingOrder")
local Money = LibTSMService:Include("Ledger.Money")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")



-- ============================================================================
-- Module Loading
-- ============================================================================

CraftingOrder:OnModuleLoad(function()
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		return
	end
	TradeSkill.RegisterCraftingOrderFulfilledCallback(function(tipAmount, character)
		Money.InsertCraftingOrderIncome(tipAmount, character, floor(LibTSMService.GetTime()))
	end)
end)

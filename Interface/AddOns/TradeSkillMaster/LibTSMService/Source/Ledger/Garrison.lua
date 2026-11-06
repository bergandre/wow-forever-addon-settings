-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Garrison = LibTSMService:Init("Ledger.Garrison")
local Money = LibTSMService:Include("Ledger.Money")
local GarrisonAPI = LibTSMService:From("LibTSMWoW"):Include("API.Garrison")



-- ============================================================================
-- Module Loading
-- ============================================================================

Garrison:OnModuleLoad(function()
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		GarrisonAPI.RegisterMoneyAwardCallback(Money.InsertGarrisonIncome)
	end
end)

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMCore = select(2, ...).LibTSMCore
local private = {
	startSystemTime = GetTimePreciseSec(),
	startTime = time(),
}



-- ============================================================================
-- Initialization Code
-- ============================================================================

do
	-- Configure LibTSMCore with a WoW-based time function
	LibTSMCore.SetTimeFunction(function()
		return private.startTime + GetTimePreciseSec() - private.startSystemTime
	end)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

-- Only create the TSMDEV table if we're in a dev or test environment
local ADDON_TABLE = select(2, ...)
local LibTSMDev = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMDev")
if LibTSMDev.IsDevVersion() or LibTSMDev.IsTestVersion() then
	TSMDEV = {} ---@class TSMDEV
	TSMDEV.TSM = ADDON_TABLE
end

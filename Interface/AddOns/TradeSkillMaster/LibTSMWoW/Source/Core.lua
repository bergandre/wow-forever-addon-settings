-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMWoW = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMWoW")
	:AddDependency("LibTSMReactive")
	:AddDependency("LibTSMUtil")

if not rawget(_G, "CASTING_BAR_ALPHA_STEP") then
	rawset(_G, "CASTING_BAR_ALPHA_STEP", 0.05)
end

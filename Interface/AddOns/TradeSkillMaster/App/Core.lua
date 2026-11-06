-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.App = ADDON_TABLE.LibTSMCore.NewComponent("App")
	:AddDependency("LibTSMApp")
	:AddDependency("LibTSMUI")
	:AddDependency("LibTSMService")
	:AddDependency("LibTSMSystem")
	:AddDependency("LibTSMWoW")
	:AddDependency("LibTSMTypes")
	:AddDependency("LibTSMDatabase")
	:AddDependency("LibTSMReactive")
	:AddDependency("LibTSMUtil")
	:AddDependency("LibTSMData")
assert(ADDON_TABLE.Locale)
ADDON_TABLE.App.Locale = ADDON_TABLE.Locale

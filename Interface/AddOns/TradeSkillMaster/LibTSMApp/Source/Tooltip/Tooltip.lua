-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local TooltipApp = LibTSMApp:Init("TooltipApp")
local Config = LibTSMApp:Include("Tooltip.Config")
local Accounting = LibTSMApp:Include("Tooltip.Accounting")
local AuctionDB = LibTSMApp:Include("Tooltip.AuctionDB")
local Auctioning = LibTSMApp:Include("Tooltip.Auctioning")
local Crafting = LibTSMApp:Include("Tooltip.Crafting")
local General = LibTSMApp:Include("Tooltip.General")
local Shopping = LibTSMApp:Include("Tooltip.Shopping")
local Sniper = LibTSMApp:Include("Tooltip.Sniper")
local Lifecycle = LibTSMApp:From("LibTSMService"):Include("Util.Lifecycle")
local private = {}



-- ============================================================================
-- Module Loading
-- ============================================================================

TooltipApp:OnModuleLoad(function()
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over all the setting lines.
---@return fun(): number @Iterator with fields: `index`, `leftText`, `rightText`, `lineColor`
function TooltipApp.SettingsLineIterator()
	return Config.SettingsLineIterator()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	General.Register()
	Accounting.Register()
	AuctionDB.Register()
	Auctioning.Register()
	Crafting.Register()
	Shopping.Register()
	Sniper.Register()
	return true
end

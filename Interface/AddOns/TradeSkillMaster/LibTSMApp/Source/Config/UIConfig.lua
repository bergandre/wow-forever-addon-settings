-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local UIConfig = LibTSMApp:Init("Config.UIConfig")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local UISettings = LibTSMApp:From("LibTSMUI"):Include("Util.UISettings")



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(UIConfig, function(db)
	local settings = db:NewView("UIConfigSettings")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("sync", "internalData", "money")
		:Commit()
	UISettings.Set(settings --[[@as UISettingsView]])
end)

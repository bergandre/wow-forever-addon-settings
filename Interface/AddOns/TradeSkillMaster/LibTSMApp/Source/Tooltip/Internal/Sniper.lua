-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Sniper = LibTSMApp:InitInternal("Tooltip.Sniper")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local SniperOperation = LibTSMApp:From("LibTSMSystem"):Include("SniperOperation")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sniper.Register()
	Registry.Add(TooltipInfo()
		:SetHeadings(L["TSM Sniper"])
		:SetSettingsModule("Sniper")
		:AddSettingEntry("belowPrice", false, private.PopulateBelowPriceLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateBelowPriceLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddItemValueLine(L["Sniper Max Price"], 35)
		return
	end
	local maxPrice = SniperOperation.GetMaxPrice(Group.TranslateItemString(itemString))
	if not maxPrice then
		return
	end
	tooltip:AddItemValueLine(L["Sniper Max Price"], maxPrice)
end

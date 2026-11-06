-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Shopping = LibTSMApp:InitInternal("Tooltip.Shopping")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local ShoppingOperation = LibTSMApp:From("LibTSMSystem"):Include("ShoppingOperation")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Shopping.Register()
	Registry.Add(TooltipInfo()
		:SetHeadings(L["TSM Shopping"])
		:SetSettingsModule("Shopping")
		:AddSettingEntry("maxPrice", false, private.PopulateMaxPriceLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateMaxPriceLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddItemValueLine(L["Max Shopping Price"], 37)
		return
	end
	local maxPrice = ShoppingOperation.GetMaxPrice(Group.TranslateItemString(itemString))
	if not maxPrice then
		return
	end
	tooltip:AddItemValueLine(L["Max Shopping Price"], maxPrice)
end

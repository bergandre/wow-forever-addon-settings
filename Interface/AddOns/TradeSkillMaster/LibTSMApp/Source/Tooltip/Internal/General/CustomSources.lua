-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local CustomSources = LibTSMApp:InitInternal("Tooltip.General.CustomSources")
local CustomPrice = LibTSMApp:Include("Price.CustomPrice")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local private = {
	settings = nil,
	tooltipInfo = nil,
	funcs = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(CustomSources, function(db)
	private.settings = db:NewView("CustomSourcesSettings")
		:AddKey("global", "userData", "customPriceSources")
		:AddKey("global", "userData", "customPriceSourceFormat")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds the custom source entries and monitors for changes to custom sources.
---@param tooltipInfo TooltipInfo
function CustomSources.AddEntries(tooltipInfo)
	assert(not private.tooltipInfo)
	private.tooltipInfo = tooltipInfo
	private.UpdateEntries()
	CustomString.RegisterCustomSourceCallback(private.UpdateEntries)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateEntries()
	private.tooltipInfo:DeleteSettingsByKeyMatch("^customPriceTooltips%.")
	for _, name in CustomPrice.CustomSourceIterator() do
		if not private.funcs[name] then
			private.funcs[name] = function(tooltip, itemString)
				private.PopulateCustomSourceLine(tooltip, itemString, name)
			end
		end
		private.tooltipInfo:AddSettingEntry("customPriceTooltips."..name, false, private.funcs[name])
	end
end

---@param tooltip TooltipBuilder
function private.PopulateCustomSourceLine(tooltip, itemString, name)
	assert(name)
	if not private.settings.customPriceSourceFormat[name] or not private.settings.customPriceSources[name] then
		-- This custom price source has been removed (ideally shouldn't get here)
		return
	elseif itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		private.AddFormattedCustomSourceLine(tooltip, name, 10)
		return
	end

	local value = CustomString.GetValue(name, itemString) or 0
	if value == 0 then
		return
	end
	private.AddFormattedCustomSourceLine(tooltip, name, value)
end

---@param tooltip TooltipBuilder
function private.AddFormattedCustomSourceLine(tooltip, name, value)
	local format = private.settings.customPriceSourceFormat[name]
	if format == "gold" then
		tooltip:AddItemValueLine(L["Custom Source"].." ("..name..")", value)
	elseif format == "number" then
		tooltip:AddLine(L["Custom Source"].." ("..name..")", tooltip:ApplyValueColor(CustomStringFormat.Get(name, value)))
	elseif format == "pct" then
		tooltip:AddLine(L["Custom Source"].." ("..name..")", CustomStringFormat.Get(name, value))
	end
end

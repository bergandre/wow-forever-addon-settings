-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Convert = LibTSMApp:InitInternal("Tooltip.General.Convert")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local OrderedTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.OrderedTable")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Conversion = LibTSMApp:From("LibTSMTypes"):Include("Item.Conversion")
local private = {
	settings = nil,
	sourcesTemp = {}, ---@type OrderedTable.Table<string,number>
}
local METHODS = {
	[Conversion.METHOD.MILL] = L["Mill"],
	[Conversion.METHOD.PROSPECT] = L["Prospect"],
	[Conversion.METHOD.TRANSFORM] = L["Transform"],
	[Conversion.METHOD.VENDOR_TRADE] = L["Vendor Trade"],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Convert, function(db)
	private.settings = db:NewView("ConvertSettings")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds tooltip entries.
---@param tooltipInfo TooltipInfo
function Convert.AddEntries(tooltipInfo)
	tooltipInfo:AddSettingValueEntry("convertTooltipFormat", "full", "none", private.PopulateFullConvertLines)
	tooltipInfo:AddSettingValueEntry("convertTooltipFormat", "simple", "none", private.PopulateSimpleConvertLines)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateFullConvertLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(format(L["Convert Value (%s)"], L["Transform"]), 55)
		tooltip:StartSection()
		tooltip:AddSubItemValueLine(ItemString.GetPlaceholder(), 55, 1)
		tooltip:EndSection()
		return
	end

	assert(not next(private.sourcesTemp))
	local minValue, methodStr = private.GetConvertTooltipInfo(itemString, private.sourcesTemp)
	if not minValue then
		return
	end

	tooltip:AddItemValueLine(format(L["Convert Value (%s)"], methodStr), minValue)
	tooltip:StartSection()
	for _, sourceItemString, price in OrderedTable.Iterator(private.sourcesTemp) do
		tooltip:AddSubItemValueLine(sourceItemString, price, 1 / Conversion.GetRate(sourceItemString, itemString))
	end
	wipe(private.sourcesTemp)
	tooltip:EndSection()
end

---@param tooltip TooltipBuilder
function private.PopulateSimpleConvertLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(format(L["Convert Value (%s)"], L["Transform"]), 55)
		return
	end

	local minValue, methodStr = private.GetConvertTooltipInfo(itemString)
	if not minValue then
		return
	end
	tooltip:AddItemValueLine(format(L["Convert Value (%s)"], methodStr), minValue)
end

function private.GetConvertTooltipInfo(itemString, sourcesResultTbl)
	for method, label in pairs(METHODS) do
		local minValue = nil
		for sourceItemString, rate in Conversion.SourceItemsByMethodIterator(itemString, method) do
			local value = CustomString.GetSourceValue(private.settings.destroyValueSource, sourceItemString)
			if value then
				if sourcesResultTbl then
					OrderedTable.Insert(sourcesResultTbl, sourceItemString, value)
				end
				minValue = min(minValue or math.huge, value / rate)
			end
		end
		if minValue then
			return minValue, label
		end
	end
	return nil, nil
end

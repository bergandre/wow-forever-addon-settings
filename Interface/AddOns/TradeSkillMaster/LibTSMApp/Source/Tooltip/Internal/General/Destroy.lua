-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Destroy = LibTSMApp:InitInternal("Tooltip.General.Destroy")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Conversion = LibTSMApp:From("LibTSMTypes"):Include("Item.Conversion")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local Conversions = LibTSMApp:From("LibTSMService"):Include("Item.Conversions")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
	settings = nil,
}
local METHOD_LABEL = {
	[Conversion.METHOD.DISENCHANT] = L["Disenchant Value"],
	[Conversion.METHOD.MILL] = L["Mill Value"],
	[Conversion.METHOD.PROSPECT] = L["Prospect Value"],
	[Conversion.METHOD.TRANSFORM] = L["Transform Value"],
	[Conversion.METHOD.VENDOR_TRADE] = L["Vendor Trade Value"],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Destroy, function(db)
	private.settings = db:NewView("DestroySettings")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds tooltip entries.
---@param tooltipInfo TooltipInfo
function Destroy.AddEntries(tooltipInfo)
	tooltipInfo:AddSettingValueEntry("destroyTooltipFormat", "full", "none", private.PopulateFullDestroyLines)
	tooltipInfo:AddSettingValueEntry("destroyTooltipFormat", "simple", "none", private.PopulateSimpleDestroyLines)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateFullDestroyLines(tooltip, itemString)
	private.PopulateSimpleDestroyLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:StartSection()
		tooltip:AddSubItemValueLine(ItemString.GetPlaceholder(), 2, 10, 1, 1, 20)
		tooltip:EndSection()
		return
	end

	local value, method = Crafting.GetConversionsValue(itemString, private.settings.destroyValueSource)
	if not value then
		return nil, nil
	end

	tooltip:StartSection()
	if method == Conversion.METHOD.DISENCHANT then
		local classId = ItemInfo.GetClassId(itemString)
		local quality = ItemInfo.GetQuality(itemString)
		local itemLevel = LibTSMApp.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBaseFast(itemString))
		local expansion = LibTSMApp.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
		for targetItemString in Conversion.DisenchantTargetItemIterator() do
			assert(classId and quality and itemLevel)
			local amountOfMats, matRate, minAmount, maxAmount = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
			if amountOfMats then
				local matValue = CustomString.GetSourceValue(private.settings.destroyValueSource, targetItemString) or 0
				if matValue > 0 then
					tooltip:AddSubItemValueLine(targetItemString, matValue, amountOfMats, matRate, minAmount, maxAmount)
				end
			end
		end
	else
		for targetItemString, amountOfMats, matRate, minAmount, maxAmount, targetQuality, sourceQuality in Conversion.TargetItemsByMethodIterator(itemString, method) do
			local matValue = CustomString.GetSourceValue(private.settings.destroyValueSource, targetItemString) or Crafting.GetConversionsValue(targetItemString, private.settings.destroyValueSource) or 0
			if matValue > 0 then
				local quality = sourceQuality and method and Crafting.GetExpectedSalvageResult(method, sourceQuality)
				if not targetQuality or targetQuality == quality then
					tooltip:AddSubItemValueLine(targetItemString, matValue, amountOfMats, matRate, minAmount, maxAmount)
				end
			end
		end
	end
	tooltip:EndSection()
end

---@param tooltip TooltipBuilder
function private.PopulateSimpleDestroyLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddItemValueLine(L["Prospect Value"], 20)
		return
	end

	local value, method = Crafting.GetConversionsValue(itemString, private.settings.destroyValueSource)
	if not value then
		return
	end
	local label = METHOD_LABEL[method]
	assert(label)
	tooltip:AddItemValueLine(label, value)
end

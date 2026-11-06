-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Crafting = LibTSMApp:InitInternal("Tooltip.Crafting")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local MatQuantityString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.RecipeString")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local TradeSkill = LibTSMApp:From("LibTSMWoW"):Include("API.TradeSkill")
local CraftingService = LibTSMApp:From("LibTSMService"):Include("Crafting")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local private = {
	optionalMatsTemp = {},
	qualityMatsTemp = {},
	hasOptionalMatTemp = {},
	slotMatsTemp = {},
	sortTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Crafting.Register()
	Registry.Add(TooltipInfo()
		:SetHeadings(L["TSM Crafting"])
		:SetSettingsModule("Crafting")
		:AddSettingEntry("craftingCost", true, private.PopulateCostLine)
		:AddSettingEntry("detailedMats", false, private.PopulateDetailedMatsLines)
		:AddSettingEntry("matPrice", false, private.PopulateMatPriceLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateCostLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddLine(L["Crafting Cost"], format(L["%s (%s profit)"], tooltip:FormatMoney(25), tooltip:FormatMoney(20, Theme.GetColor("positive/main"))))
		return
	elseif not CraftingService.HasCraftedItem(itemString) then
		return
	end

	local cost = CraftingService.GetLowestCostByItem(itemString)
	local buyout = cost and CraftingService.GetCraftedItemValue(itemString) or nil
	local profit = buyout and (buyout - cost) or nil
	local costText = tooltip:FormatMoney(cost)
	local profitText = tooltip:FormatMoney(profit, profit and Theme.GetColor(profit >= 0 and "positive/main" or "error/main") or nil)
	tooltip:AddLine(L["Crafting Cost"], format(L["%s (%s profit)"], costText, profitText))
end

---@param tooltip TooltipBuilder
function private.PopulateDetailedMatsLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:StartSection()
		tooltip:AddSubItemValueLine(ItemString.GetPlaceholder(), 11, 5)
		tooltip:EndSection()
		return
	elseif not CraftingService.HasCraftedItem(itemString) then
		return
	end

	assert(not next(private.optionalMatsTemp) and not next(private.qualityMatsTemp))
	local craftString, concentration, concentrationCost = private.GetCraftInfo(itemString, private.optionalMatsTemp, private.qualityMatsTemp)
	if not craftString then
		wipe(private.optionalMatsTemp)
		wipe(private.qualityMatsTemp)
		return
	end

	if next(private.qualityMatsTemp) then
		-- Sort the quality mats by their mat string
		assert(not next(private.sortTemp))
		for matItemString, matString in pairs(private.qualityMatsTemp) do
			tinsert(private.sortTemp, matItemString)
			private.sortTemp[matItemString] = matString
		end
		sort(private.sortTemp)
		Table.SortWithValueLookup(private.sortTemp, private.sortTemp)
		wipe(private.qualityMatsTemp)
		Table.CopyFrom(private.qualityMatsTemp, private.sortTemp)
		Table.WipeAndDeallocate(private.sortTemp)
	end

	tooltip:StartSection()
	local expectedRefund, expectedExtraYield = CraftingService.GetExpectedProcRates(craftString)
	local numResult = CraftingService.GetNumResult(craftString) * (1 + expectedExtraYield)
	for _, matItemString, matQuantity in CraftingService.MatIterator(craftString) do
		tooltip:AddSubItemValueLine(matItemString, CustomString.GetSourceValue("MatPrice", matItemString), matQuantity * (1 - expectedRefund) / numResult)
	end
	for _, matQuantityString in ipairs(private.qualityMatsTemp) do
		for _, matItemString, matQuantity in MatQuantityString.Iterator(matQuantityString) do
			tooltip:AddSubItemValueLine(matItemString, CustomString.GetSourceValue("MatPrice", matItemString), matQuantity * (1 - expectedRefund) / numResult)
		end
	end
	for _, matQuantityString in ipairs(private.optionalMatsTemp) do
		for _, matItemString in MatQuantityString.Iterator(matQuantityString) do
			local matQuantity = CraftingService.GetOptionalMatQuantity(craftString, matItemString)
			tooltip:AddSubItemValueLine(matItemString, CustomString.GetSourceValue("MatPrice", matItemString), matQuantity / numResult)
		end
	end
	if (concentration or 0) > 0 then
		local text, iconLink = TradeSkill.GetConcentrationUIConstants()
		if concentrationCost then
			tooltip:AddQuantityLine(iconLink.." "..text, concentrationCost / numResult)
		else
			tooltip:AddLine(iconLink.." "..tooltip:ApplyValueColor(text))
		end
	end
	wipe(private.optionalMatsTemp)
	wipe(private.qualityMatsTemp)
	tooltip:EndSection()
end

---@param tooltip TooltipBuilder
function private.PopulateMatPriceLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddItemValueLine(L["Material Cost"], 17)
		return
	end

	itemString = ItemString.GetBaseFast(itemString)
	local matCost = CustomString.GetSourceValue("MatPrice", itemString)
	if not matCost then
		return
	end
	tooltip:AddItemValueLine(L["Material Cost"], matCost)
end

function private.GetCraftInfo(itemString, optionalMats, qualityMats)
	local _, craftString, concentration = CraftingService.GetLowestCostByItem(itemString, optionalMats, qualityMats)
	if not craftString then
		return nil, nil, nil
	end

	-- Only include optional mats which actually belong to the spell
	assert(not next(private.hasOptionalMatTemp) and not next(private.slotMatsTemp))
	for _, matString, slotId in CraftingService.OptionalMatIterator(craftString) do
		for _, matQuantityString in ipairs(optionalMats) do
			for _, optionalMatItemString in MatQuantityString.Iterator(matQuantityString) do
				if MatString.ContainsItem(matString, optionalMatItemString) then
					private.hasOptionalMatTemp[matQuantityString] = true
					private.slotMatsTemp[slotId] = matQuantityString
				end
			end
		end
	end
	for i = #optionalMats, 1, -1 do
		if not private.hasOptionalMatTemp[optionalMats[i]] then
			tremove(optionalMats, i)
		end
	end
	wipe(private.hasOptionalMatTemp)

	local concentrationCost = nil
	if (concentration or 0) > 0 then
		for matQuantityString, matString in pairs(qualityMats) do
			private.slotMatsTemp[MatString.GetSlotId(matString)] = matQuantityString
		end
		concentrationCost = CraftingService.GetConcentrationInfo(RecipeString.FromCraftString(craftString, private.slotMatsTemp, concentration))
	end
	wipe(private.slotMatsTemp)

	return craftString, concentration, concentrationCost
end

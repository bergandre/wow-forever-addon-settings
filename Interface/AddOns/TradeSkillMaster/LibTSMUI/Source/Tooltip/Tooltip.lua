-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local TooltipUI = LibTSMUI:Init("TooltipUI")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local RecipeString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.RecipeString")
local Event = LibTSMUI:From("LibTSMWoW"):Include("Service.Event")
local Currency = LibTSMUI:From("LibTSMWoW"):Include("API.Currency")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local private = {
	currentParent = nil,
	registeredEvent = false,
	optionalMatTable = {},
	unusedOptionalMatTempTables = {},
	splitTemp = {},
}
local SEP_CHAR = "\001"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the character used as a separator between left and right text in a tooltip line
---@return string
function TooltipUI.GetSepChar()
	return SEP_CHAR
end

---Shows a tooltip which is anchored to the frame.
---@param parent Frame The parent and anchor frame for the tooltip
---@param data number|string|function|nil The tooltip information
---@param noWrapping? boolean Disables wrapping of text lines
---@param xOffset? number An extra x offset to apply to the anchor of the tooltip
function TooltipUI.Show(parent, data, noWrapping, xOffset)
	if not data then
		return
	elseif type(data) == "function" then
		local funcNoWrapping, funcXOffset = false, 0
		data, funcNoWrapping, funcXOffset = data()
		noWrapping = noWrapping or funcNoWrapping
		xOffset = xOffset or funcXOffset
	end
	local showCompare = false
	GameTooltip:SetOwner(parent, "ANCHOR_PRESERVE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("LEFT", parent, "RIGHT", xOffset or 0, 0)
	if type(data) == "number" then
		GameTooltip:SetHyperlink("item:"..data)
		showCompare = true
	elseif type(data) == "string" and strfind(data, "^craft:") then
		data = strmatch(data, "craft:(%d+)")
		GameTooltip:SetCraftSpell(tonumber(data)) ---@diagnostic disable-line: undefined-field
	elseif type(data) == "string" and data == "arena" then
		GameTooltip:SetText(ARENA_POINTS, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddLine(TOOLTIP_ARENA_POINTS, nil, nil, nil, true)
	elseif type(data) == "string" and data == "honor" then
		GameTooltip:SetText(HONOR_POINTS, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddLine(TOOLTIP_HONOR_POINTS, nil, nil, nil, true)
	elseif (LibTSMUI.IsMistsClassic() or LibTSMUI.IsBCClassic()) and type(data) == "string" and strfind(data, "^currency:") then
		local currencyId = tonumber(strmatch(data, "currency:(%d+)"))
		if currencyId == 390 then
			GameTooltip:SetText(PVP_CONQUEST, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			GameTooltip:AddLine(PVP_ARENA_EXPLANATION, nil, nil, nil, true)
		elseif currencyId == 1900 then
			GameTooltip:SetText(ARENA_POINTS, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			GameTooltip:AddLine(TOOLTIP_ARENA_POINTS, nil, nil, nil, true)
		elseif currencyId == 1901 then
			GameTooltip:SetText(HONOR_POINTS, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			GameTooltip:AddLine(TOOLTIP_HONOR_POINTS, nil, nil, nil, true)
		end
	elseif (LibTSMUI.IsRetail() or LibTSMUI.IsForever()) and type(data) == "string" and strfind(data, "^concentration:") then
		local currencyId = tonumber(strmatch(data, "concentration:(%d+)"))
		assert(currencyId)
		local name, _, quantity, maxQuantity = Currency.GetInfo(currencyId)
		assert(name)
		GameTooltip:AddDoubleLine(name, format(PROFESSIONS_CRAFTING_CURRENCY_TOOLTIP_FORMAT, quantity, maxQuantity), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		if quantity == maxQuantity then
			GameTooltip:AddLine(PROFESSIONS_CRAFTING_CONCENTRATION_CURRENCY_TOOLTIP_WARNING, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		end
		GameTooltip:AddLine(PROFESSIONS_CRAFTING_CONCENTRATION_CURRENCY_TOOLTIP, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	elseif (LibTSMUI.IsRetail() or LibTSMUI.IsForever()) and type(data) == "string" and strfind(data, "^currency:") then
		GameTooltip:SetCurrencyByID(strmatch(data, "currency:(%d+)"))
	elseif type(data) == "string" and strfind(data, "^r:") then
		local spellId = RecipeString.GetSpellId(data)
		if LibTSMUI.IsRetail() or LibTSMUI.IsForever() then
			-- Release the previous tables
			for _, tbl in ipairs(private.optionalMatTable) do
				tinsert(private.unusedOptionalMatTempTables, tbl)
			end
			wipe(private.optionalMatTable)
			local level = RecipeString.GetLevel(data)
			-- BUG: Optional materials that would increase the item's level does not seem to properly update the tooltip to the correct level via `optionalMatTable`
			for _, slotId, matQuantityString in RecipeString.OptionalMatIterator(data) do
				for _, itemString, quantity in MatQuantityString.Iterator(matQuantityString) do
					local info = tremove(private.unusedOptionalMatTempTables) or {}
					info.reagent = info.reagent or {}
					info.reagent.itemID = ItemString.ToId(itemString)
					info.dataSlotIndex = slotId
					info.quantity = quantity
					tinsert(private.optionalMatTable, info)
				end
			end
			local qualityIDs = TradeSkill.GetQualitiesForRecipe(spellId)
			local quality = RecipeString.GetQuality(data)
			-- BUG: The level field is completely ignored and always shows ranked items as level 1 (12.1.0)
			GameTooltip:SetRecipeResultItem(spellId, private.optionalMatTable, nil, level, qualityIDs and quality and qualityIDs[quality]) ---@diagnostic disable-line: redundant-parameter
		else
			local index = Profession.GetIndexByCraftString(CraftString.Get(spellId))
			if index then
				GameTooltip:SetTradeSkillItem(index) ---@diagnostic disable-line: undefined-field
			end
		end
	elseif type(data) == "string" and (strfind(data, "^\124c[^\124]+\124Hitem:") or ItemString.IsItem(data)) then
		GameTooltip:SetHyperlink(ItemInfo.GetLink(data))
		showCompare = true
	elseif type(data) == "string" and (strfind(data, "^\124c[^\124]+\124Hbattlepet:") or ItemString.IsPet(data)) then
		if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() then
			return
		end
		if strmatch(data, "p:") then
			data = ItemInfo.GetLink(data)
			assert(data)
		end
		local _, speciesID, level, breedQuality, maxHealth, power, speed = strsplit(":", data)
		BattlePetToolTip_Show(tonumber(speciesID), tonumber(level) or 0, tonumber(breedQuality) or 0, tonumber(maxHealth) or 0, tonumber(power) or 0, tonumber(speed) or 0, gsub(gsub(data, "^(.*)%[", ""), "%](.*)$", ""))
	else
		assert(#private.splitTemp == 0)
		String.SafeSplit(data, "\n", private.splitTemp)
		for _, line in ipairs(private.splitTemp) do
			local textLeft, textRight = strsplit(SEP_CHAR, line)
			if textRight then
				GameTooltip:AddDoubleLine(textLeft, textRight, 1, 1, 1, 1, 1, 1)
			else
				GameTooltip:AddLine(textLeft, 1, 1, 1, not noWrapping)
			end
		end
		wipe(private.splitTemp)
	end
	GameTooltip:Show()
	private.currentParent = parent
	if showCompare then
		assert(not private.registeredEvent)
		private.registeredEvent = true
		Event.Register("MODIFIER_STATE_CHANGED", private.UpdateCompareState)
		private.UpdateCompareState()
	end
end

---Hides the current tooltip.
function TooltipUI.Hide()
	if private.registeredEvent then
		Event.Unregister("MODIFIER_STATE_CHANGED", private.UpdateCompareState)
		private.registeredEvent = false
	end
	private.currentParent = nil
	GameTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("CENTER")
	GameTooltip:Hide()
	if not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() then
		BattlePetTooltip:ClearAllPoints()
		BattlePetTooltip:SetPoint("CENTER")
		BattlePetTooltip:Hide()
	end
end

---Checks if the tooltip is visible.
---@param frame? table An optional parent frame to check against
---@return boolean
function TooltipUI.IsVisible(frame)
	if frame then
		return private.currentParent == frame
	else
		return private.currentParent and true or false
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateCompareState()
	if private.currentParent and GameTooltip:IsVisible() and IsShiftKeyDown() then
		GameTooltip_ShowCompareItem(GameTooltip)
	else
		GameTooltip_HideShoppingTooltips(GameTooltip)
	end
end

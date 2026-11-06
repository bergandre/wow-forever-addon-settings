-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Config = LibTSMApp:InitInternal("Tooltip.Config")
local Registry = LibTSMApp:Include("Tooltip.Registry")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local TooltipBuilder = LibTSMApp:From("LibTSMService"):IncludeClassType("TooltipBuilder")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local Item = LibTSMApp:From("LibTSMWoW"):Include("API.Item")
local TooltipWrapper = LibTSMApp:From("LibTSMWoW"):Include("TooltipWrapper")
local Hook = LibTSMApp:From("LibTSMWoW"):Include("Util.Hook")
local private = {
	settings = nil,
	settingsBuilder = nil,
	cancellables = {},
	builder = nil,
}
local ITER_INDEX_PART_MULTIPLE = 1000



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Config, function(db)
	TooltipBuilder.SetInCombatPlaceholder(L["Can't load TSM tooltip while in combat"])
	private.settings = db:NewView("ConfigSettings")
		:AddKey("global", "tooltipOptions", "embeddedTooltip")
		:AddKey("global", "tooltipOptions", "enabled")
		:AddKey("global", "tooltipOptions", "tooltipShowModifier")
		:AddKey("global", "tooltipOptions", "tooltipPriceFormat")
		:Commit()
	private.settingsBuilder = TooltipBuilder.New()
	private.settings:PublisherForKey("tooltipPriceFormat")
		:ToBooleanEquals("icon")
		:CallFunction(TooltipBuilder.SetMoneyUseIcon)
		:StoreIn(private.cancellables)
	private.settings:PublisherForKey("embeddedTooltip")
		:CallFunction(TooltipWrapper.SetEmbedTooltip)
		:StoreIn(private.cancellables)
	private.builder = TooltipBuilder.New()
	TooltipWrapper.Load(private.PrepareItemTooltip, private.PopulateItemTooltip)

	if ArkInventory and ArkInventory.API and ArkInventory.API.CustomBattlePetTooltipReady then
		Hook.SecurePost(ArkInventory.API, "CustomBattlePetTooltipReady", function(tooltip, link)
			local itemString = ItemString.Get(link)
			link = itemString and ItemInfo.GetLink(itemString)
			if not link then
				return
			end
			TooltipWrapper.SetTooltipItem(tooltip, link)
		end)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over all the setting lines.
---@return fun(): number @Iterator with fields: `index`, `leftText`, `rightText`, `lineColor`
function Config.SettingsLineIterator()
	assert(not private.settingsBuilder:_Prepare(ItemString.GetPlaceholder(), 1)) ---@diagnostic disable-line: invisible
	return private.SettingsLineIteratorHelper
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PrepareItemTooltip(link, quantity, shiftKeyDown, controlKeyDown, altKeyDown)
	local itemString = ItemString.Get(link)
	if not itemString then
		return false
	elseif not private.settings.enabled then
		return false
	elseif private.settings.tooltipShowModifier == "alt" and not altKeyDown then
		return false
	elseif private.settings.tooltipShowModifier == "ctrl" and not controlKeyDown then
		return false
	end

	local isCached = private.builder:_Prepare(itemString, quantity) ---@diagnostic disable-line: invisible
	if not isCached then
		-- Populate all the lines
		for _, info in Registry.Iterator() do
			info:Populate(private.builder, itemString, shiftKeyDown)
		end
	end
	if private.builder:_IsEmpty() then ---@diagnostic disable-line: invisible
		return false
	end

	return true
end

---@param targetTip GameTooltip|ExtraTooltip
function private.PopulateItemTooltip(link, targetTip, addItemName)
	if addItemName then
		local r, g, b = Item.GetQualityColorRGB(ItemInfo.GetQuality(link) or 0)
		targetTip:AddLine(ItemInfo.GetName(link) or "?", r, g, b)
	end
	targetTip:AddLine(" ")
	for _, left, right, lineColor in private.builder:_LineIterator() do ---@diagnostic disable-line: invisible
		local r, g, b = Theme.GetColor(lineColor):GetFractionalRGBA()
		if right then
			targetTip:AddDoubleLine(left, right, r, g, b, r, g, b)
		else
			targetTip:AddLine(left, r, g, b)
		end
	end
end

function private.SettingsLineIteratorHelper(_, index)
	index = index or 0
	local infoIndex = floor(index / (ITER_INDEX_PART_MULTIPLE ^ 2))
	local entryIndex = floor(index / ITER_INDEX_PART_MULTIPLE) % ITER_INDEX_PART_MULTIPLE
	local lineIndex = index % ITER_INDEX_PART_MULTIPLE
	local info, entry = nil, nil
	while lineIndex >= private.settingsBuilder:GetNumLines() do
		-- Move to the next entry
		info = Registry.Get(infoIndex)
		entryIndex = entryIndex + 1
		entry = info and info:_GetEntry(entryIndex) ---@diagnostic disable-line: invisible
		if entry then
			private.settingsBuilder:SetDisabled(not entry:IsEnabled())
			entry:Populate(private.settingsBuilder, ItemString.GetPlaceholder(), false)
			private.settingsBuilder:SetDisabled(false)
		else
			-- Move to the next info
			if infoIndex > 0 then
				private.settingsBuilder:EndSection()
			end
			infoIndex = infoIndex + 1
			info = Registry.Get(infoIndex)
			if info then
				private.settingsBuilder:StartSection(info._headingLeft) ---@diagnostic disable-line: invisible
				entryIndex = 0
			else
				return
			end
		end
	end
	lineIndex = lineIndex + 1
	index = infoIndex * ITER_INDEX_PART_MULTIPLE ^ 2 + entryIndex * ITER_INDEX_PART_MULTIPLE + lineIndex
	local leftText, rightText, lineColor = private.settingsBuilder:GetLine(lineIndex)
	assert(infoIndex < ITER_INDEX_PART_MULTIPLE and entryIndex < ITER_INDEX_PART_MULTIPLE and lineIndex < ITER_INDEX_PART_MULTIPLE)
	return index, leftText, rightText, lineColor
end

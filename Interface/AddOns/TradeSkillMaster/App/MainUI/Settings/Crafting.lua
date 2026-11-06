-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Crafting = App:Init("MainUI.Settings.Crafting")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local private = {
	settings = nil,
	altCharacters = {},
	altGuilds = {},
}
local BAD_MAT_PRICE_SOURCES = {
	matprice = true,
}
local BAD_CRAFT_VALUE_PRICE_SOURCES = {
	crafting = true,
}
local SETTING_TOOLTIPS = {
	ignoreCharacters = L["Select characters which Crafting should ignore the inventory of for materials and crafted items."],
	ignoreGuilds = L["Select guilds which Crafting should ignore the inventory of for materials and crafted items."],
	defaultMatCostMethod = L["A custom string which defines how TSM determines the cost of acquiring a material by default. This can be overridden on a per-material basis within the 'Crafting Reports' tab of the Crafting UI."],
	defaultCraftPriceMethod = L["A custom string which defines how TSM determines the value of a crafted item. This can be overridden within a Crafting operation."],
	mixedQualityThreshold = L["When determining the cheapest way to craft a recipe with quality materials, only use mixed qualities of a single material if the cost savings is at least this threshold. Note that the cost savings is calculated across all quality mats, but does not include the cost of non-quality mats."],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Crafting, function(db)
	private.settings = db:NewView("CraftingSettings")
		:AddKey("global", "craftingOptions", "defaultMatCostMethod")
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
		:AddKey("global", "craftingOptions", "mixedQualityThreshold")
		:AddKey("global", "craftingOptions", "ignoreCharacters")
		:AddKey("global", "craftingOptions", "ignoreGuilds")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the crafting settings frame.
---@return BaseScrollFrame
function Crafting.GetFrame()
	return private.GetCraftingSettingsFrame()
end



-- ============================================================================
-- Crafting Settings UI
-- ============================================================================

function private.GetCraftingSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "crafting")
	wipe(private.altCharacters)
	Table.InsertFromIterator(private.altCharacters, PlayerInfo.CharacterIterator(true))
	Table.Sort(private.altCharacters)
	wipe(private.altGuilds)
	Table.InsertFromIterator(private.altGuilds, PlayerInfo.GuildIterator())
	Table.Sort(private.altGuilds)
	return UIElements.New("BaseScrollFrame", "craftingSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "inventory")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Inventory Options"], L["Some inventory related Crafting options are below."])
			:AddChild(UIElements.New("BaseFrame", "inventoryOptions")
				:SetLayout("HORIZONTAL")
				:SetHeight(46)
				:AddChild(UIElements.New("SettingsField", "characters")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Ignore Characters"])
					:AddChild(UIElements.New("MultiselectionDropdown", "charDropdown")
						:SetHeight(24)
						:SetItems(private.altCharacters, private.altCharacters)
						:SetSettingInfo(private.settings, "ignoreCharacters")
						:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
						:SetHintText(L["Select characters"])
						:SetTooltip(SETTING_TOOLTIPS.ignoreCharacters)
					)
				)
				:AddChild(UIElements.New("SettingsField", "guilds")
					:SetLabel(L["Ignore Guilds"])
					:AddChild(UIElements.New("MultiselectionDropdown", "guildDropdown")
						:SetHeight(24)
						:SetItems(private.altGuilds, private.altGuilds)
						:SetSettingInfo(private.settings, "ignoreGuilds")
						:SetSelectionText(L["No Guilds"], L["%d Guilds"], L["All Guilds"])
						:SetHintText(L["Select guilds"])
						:SetTooltip(SETTING_TOOLTIPS.ignoreGuilds)
					)
				)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "price")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Price Options"], L["The settings below control the default custom strings used when calculating Crafting prices."])
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "matCost")
				:ConfigureText(L["Default material cost method"], SETTING_TOOLTIPS.defaultMatCostMethod)
				:SetBadSources(BAD_MAT_PRICE_SOURCES)
				:SetSettingInfo(private.settings, "defaultMatCostMethod")
			)
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "craftValue")
				:SetMargin(0, 0, 12, 0)
				:ConfigureText(L["Default craft value method"], SETTING_TOOLTIPS.defaultCraftPriceMethod)
				:SetBadSources(BAD_CRAFT_VALUE_PRICE_SOURCES)
				:SetSettingInfo(private.settings, "defaultCraftPriceMethod")
			)
			:AddChildIf(App.IsRetail() or App.IsForever(), UIElements.New("SettingsField", "mixedQualityThreshold")
				:SetMargin(0, 0, 12, 0)
				:SetLabel(L["Mixed material quality threshold percent (requires reload)"])
				:AddChild(UIElements.New("BaseFrame", "pctInput")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:AddChild(UIElements.New("NumberInput", "input")
						:SetMargin(0, 8, 0, 0)
						:SetValidRange(0, 100)
						:SetSettingInfo(private.settings, "mixedQualityThreshold")
						:SetTooltip(SETTING_TOOLTIPS.mixedQualityThreshold, true)
					)
					:AddChild(UIElements.New("Text", "rangeText")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(format(L["(minimum 0 - maximum %d)"], 100))
					)
				)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "cooldowns")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Ignored Cooldowns"], L["Click on a cooldown below to unignore it for display in the Task List UI."])
			:AddChild(UIElements.New("IgnoredCooldownList", "items")
				:SetHeight(106)
			)
		)
end

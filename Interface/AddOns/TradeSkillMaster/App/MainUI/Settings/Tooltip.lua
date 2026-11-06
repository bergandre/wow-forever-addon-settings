-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Tooltip = App:Init("MainUI.Settings.Tooltip")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Operation = App:From("LibTSMTypes"):Include("Operation")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local CustomPrice = App:From("LibTSMApp"):Include("Price.CustomPrice")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local TooltipApp = App:From("LibTSMApp"):Include("TooltipApp")
local private = {
	settings = nil,
	manager = nil,
	operationModules = {},
	operationModuleNames = {},
}
local GROUPS_OPS_SETTINGS_INFO = {
	{ label = L["Group name"], settingKey = "groupNameTooltip" },
	{ label = L["Auctioning operation"], settingTbl = "operationTooltips", settingKey = "Auctioning" },
	{ label = L["Crafting operation"], settingTbl = "operationTooltips", settingKey = "Crafting" },
	{ label = L["Mailing operation"], settingTbl = "operationTooltips", settingKey = "Mailing" },
	{ label = L["Shopping operation"], settingTbl = "operationTooltips", settingKey = "Shopping" },
	{ label = L["Sniper operation"], settingTbl = "operationTooltips", settingKey = "Sniper" },
	{ label = L["Vendoring operation"], settingTbl = "operationTooltips", settingKey = "Vendoring" },
	{ label = L["Warehousing operation"], settingTbl = "operationTooltips", settingKey = "Warehousing" },
}
local VALUES_SETTINGS_INFO = {
	{ label = L["Full destroy tooltip"], settingKey = "destroyTooltipFormat", setValue = "full", clearValue = "none" },
	{ label = L["Simple destroy tooltip"], settingKey = "destroyTooltipFormat", setValue = "simple", clearValue = "none" },
	{ label = L["Full convert tooltip"], settingKey = "convertTooltipFormat", setValue = "full", clearValue = "none" },
	{ label = L["Simple convert tooltip"], settingKey = "convertTooltipFormat", setValue = "simple", clearValue = "none" },
	{ label = L["Vendor buy price"], settingKey = "vendorBuyTooltip" },
	{ label = L["Vendor sell price"], settingKey = "vendorSellTooltip" },
}
local INVENTORY_SETTINGS_INFO = {
	{ label = L["Full inventory"], settingKey = "inventoryTooltipFormat", setValue = "full", clearValue = "none" },
	{ label = L["Simple inventory"], settingKey = "inventoryTooltipFormat", setValue = "simple", clearValue = "none" },
}
local ACCOUNTING_SETTINGS_INFO = {
	{ label = L["Purchase information"], settingModule = "Accounting", settingKey = "purchase" },
	{ label = L["Sale information"], settingModule = "Accounting", settingKey = "sale" },
	{ label = L["Sale rate"], settingModule = "Accounting", settingKey = "saleRate" },
	{ label = L["Expired information"], settingModule = "Accounting", settingKey = "expiredAuctions" },
	{ label = L["Cancelled information"], settingModule = "Accounting", settingKey = "cancelledAuctions" },
}
local AUCTIONDB_SETTINGS_INFO = (App.IsRetail() or App.IsForever()) and {
	{ label = L["Min buyout"], settingModule = "AuctionDB", settingKey = "minBuyout" },
	{ label = L["Recent value"], settingModule = "AuctionDB", settingKey = "marketValueRecent" },
	{ label = L["Market value"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Market value and trend"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Historical price"], settingModule = "AuctionDB", settingKey = "historical" },
	{ label = L["Alt realm min buyout"], settingModule = "AuctionDB", settingKey = "altMinBuyout" },
	{ label = L["Alt realm recent value"], settingModule = "AuctionDB", settingKey = "altMarketValueRecent" },
	{ label = L["Alt realm market value"], settingModule = "AuctionDB", settingKey = "altMarketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Alt realm market value and trend"], settingModule = "AuctionDB", settingKey = "altMarketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Alt realm historical price"], settingModule = "AuctionDB", settingKey = "altHistorical" },
	{ label = L["Region market value"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Region market value and trend"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Region historical price"], settingModule = "AuctionDB", settingKey = "regionHistorical" },
	{ label = L["Region sale avg"], settingModule = "AuctionDB", settingKey = "regionSale" },
	{ label = L["Region sale rate"], settingModule = "AuctionDB", settingKey = "regionSalePercent" },
	{ label = L["Region avg daily sold"], settingModule = "AuctionDB", settingKey = "regionSoldPerDay" },
} or {
	{ label = L["Min buyout"], settingModule = "AuctionDB", settingKey = "minBuyout" },
	{ label = L["Recent value"], settingModule = "AuctionDB", settingKey = "marketValueRecent" },
	{ label = L["Market value"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Market value and trend"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Historical price"], settingModule = "AuctionDB", settingKey = "historical" },
	{ label = L["Region market value"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Region market value and trend"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Region historical price"], settingModule = "AuctionDB", settingKey = "regionHistorical" },
	{ label = L["Region sale avg"], settingModule = "AuctionDB", settingKey = "regionSale" },
	{ label = L["Region sale rate"], settingModule = "AuctionDB", settingKey = "regionSalePercent" },
	{ label = L["Region avg daily sold"], settingModule = "AuctionDB", settingKey = "regionSoldPerDay" },
}
local AUCTIONING_SETTINGS_INFO = {
	{ label = L["Post Quantity"], settingModule = "Auctioning", settingKey = "postQuantity" },
	{ label = L["Min/Normal/Max price"], settingModule = "Auctioning", settingKey = "operationPrices" },
}
local CRAFTING_SETTINGS_INFO = {
	{ label = L["Crafting cost"], settingModule = "Crafting", settingKey = "craftingCost" },
	{ label = L["Detailed crafting cost"], settingModule = "Crafting", settingKey = "detailedMats" },
	{ label = L["Mat cost"], settingModule = "Crafting", settingKey = "matPrice" },
}
local SHOPPING_SETTINGS_INFO = {
	{ label = L["Max shopping price"], settingModule = "Shopping", settingKey = "maxPrice" },
}
local SNIPER_SETTINGS_INFO = {
	{ label = L["Max sniper price"], settingModule = "Sniper", settingKey = "belowPrice" },
}
local SETTING_TOOLTIPS = {
	enabled = L["This setting allows for enabling or disabling the tooltip information provided by TSM as a whole."],
	embeddedTooltip = L["This option allows for embedding the information provided by TSM in the existing item tooltip. If disabled, the information provided by TSM will be separated in to another anchored tooltip."],
	tooltipPriceFormat = L["Selects whether TSM uses text or icons to label gold, silver, and copper values."],
	tooltipShowModifier = L["Select whether to show the information provided by TSM in tooltips all the time i.e. 'None (Always Show)', or only show the information provided by TSM when holding a modifier i.e. CTRL or ALT."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("TooltipSettingsUIState")
	:AddDeferredUIElementField("tooltipFrame", "BaseFrame")
	:AddDeferredUIElementField("settingsFrame", "BaseFrame")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Tooltip, function(db)
	private.settings = db:NewView("TooltipSettings")
		:AddKey("global", "tooltipOptions", "enabled")
		:AddKey("global", "tooltipOptions", "embeddedTooltip")
		:AddKey("global", "tooltipOptions", "tooltipPriceFormat")
		:AddKey("global", "tooltipOptions", "tooltipShowModifier")
		:AddKey("global", "tooltipOptions", "customPriceTooltips")
		:AddKey("global", "tooltipOptions", "moduleTooltips")
		:AddKey("global", "tooltipOptions", "inventoryTooltipFormat")
		:AddKey("global", "tooltipOptions", "vendorBuyTooltip")
		:AddKey("global", "tooltipOptions", "vendorSellTooltip")
		:AddKey("global", "tooltipOptions", "convertTooltipFormat")
		:AddKey("global", "tooltipOptions", "destroyTooltipFormat")
		:AddKey("global", "tooltipOptions", "groupNameTooltip")
		:AddKey("global", "tooltipOptions", "operationTooltips")
		:AddKey("global", "userData", "customPriceSources")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("TOOLTIP_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetTooltipSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the tooltip settings frame.
---@return BaseScrollFrame
function Tooltip.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Tooltip Settings UI
-- ============================================================================

---@param state TooltipSettingsUIState
function private.GetTooltipSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "tooltips", "main")
	wipe(private.operationModules)
	wipe(private.operationModuleNames)
	for _, moduleName in Operation.TypeIterator() do
		tinsert(private.operationModules, moduleName)
		tinsert(private.operationModuleNames, Operation.GetLocalizedName(moduleName))
	end
	return UIElements.New("BaseScrollFrame", "tooltipSettings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general options for the TSM tooltip information are below."])
			:AddChild(UIElements.New("SettingsField", "enable")
				:SetMargin(0, 0, 0, 12)
				:SetLabel(L["Enable TSM tooltips"])
				:AddChild(UIElements.New("ToggleYesNo", "enableToggle")
					:SetHeight(24)
					:SetSettingInfo(private.settings, "enabled")
					:SetTooltip(SETTING_TOOLTIPS.enabled)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "embedCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Embed TSM tooltip"])
					:SetSettingInfo(private.settings, "embeddedTooltip")
					:SetTooltip(SETTING_TOOLTIPS.embeddedTooltip, true)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "dropdownRow1")
				:SetLayout("HORIZONTAL")
				:SetHeight(46)
				:AddChild(UIElements.New("SettingsField", "priceFormat")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Tooltip price format"])
					:AddChild(UIElements.New("SelectionDropdown", "priceFormatDropdown")
						:SetHeight(24)
						:AddItem(format(L["Coins (%s)"], Money.ToStringForTooltip(3451267, nil, true, false)), "icon")
						:AddItem(format(L["Text (%s)"], Money.ToStringForTooltip(3451267, nil, false, false)), "text")
						:SetSettingInfo(private.settings, "tooltipPriceFormat")
						:SetHintText(L["Select format"])
						:SetAction("OnSelectionChanged", "ACTION_REBUILD_EXAMPLE_TOOLTIP")
						:SetTooltip(SETTING_TOOLTIPS.tooltipPriceFormat, true)
					)
				)
				:AddChild(UIElements.New("SettingsField", "modifier")
					:SetLabel(L["Show on modifier"])
					:AddChild(UIElements.New("SelectionDropdown", "modifierDropdown")
						:SetHeight(24)
						:AddItem(L["None (Always Show)"], "none")
						:AddItem(GlobalStrings.Get("ALT_KEY"), "alt")
						:AddItem(GlobalStrings.Get("CTRL_KEY"), "ctrl")
						:SetSettingInfo(private.settings, "tooltipShowModifier")
						:SetHintText(L["Select modifier"])
						:SetTooltip(SETTING_TOOLTIPS.tooltipShowModifier, true)
					)
				)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "options")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Tooltip Options"], L["Use the settings below to control which lines are shown in tooltips."])
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(private.GetSettingsHeight())
				:AddChild(UIElements.New("BaseFrame", "settings")
					:SetLayout("VERTICAL")
					:SetMargin(0, 8, 0, -12)
					:BindElement(state, "settingsFrame")
					:AddChild(private.CreateHeadingText("groupsOpsHeading", L["Groups & Operations"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, GROUPS_OPS_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("valuesHeading", L["Values"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, VALUES_SETTINGS_INFO)
					:AddChildrenWithFunction(private.AddCustomSourceSettings)
					:AddChild(private.CreateHeadingText("inventoryHeading", L["Inventory"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, INVENTORY_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("accountingHeading", L["Accounting"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, ACCOUNTING_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("auctiondbHeading", L["AuctionDB"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, AUCTIONDB_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("auctioningHeading", L["Auctioning"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, AUCTIONING_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("craftingHeading", L["Crafting"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, CRAFTING_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("shoppingHeading", L["Shopping"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, SHOPPING_SETTINGS_INFO)
					:AddChild(private.CreateHeadingText("sniperHeading", L["Sniper"]))
					:AddChildrenWithFunction(private.AddSettingsFromInfoTable, SNIPER_SETTINGS_INFO)
				)
				:AddChild(UIElements.New("BaseFrame", "example")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 12)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Example Tooltip"])
					)
					:AddChild(UIElements.New("BaseFrame", "tooltip")
						:SetLayout("VERTICAL")
						:SetPadding(4)
						:SetBackgroundColor("container/lowest")
						:BindElement(state, "tooltipFrame")
						:AddChildrenWithFunction(private.AddExampleTooltip)
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
		)
end

function private.GetSettingsHeight()
	-- Calculate the height of the settings and use that for the content height since the settings will always be larger than the tooltip
	local height = 0
	height = height + 32 + #GROUPS_OPS_SETTINGS_INFO * 32
	height = height + 32 + #VALUES_SETTINGS_INFO * 32 + Table.Count(private.settings.customPriceSources) * 32
	height = height + 32 + #INVENTORY_SETTINGS_INFO * 32
	height = height + 32 + #ACCOUNTING_SETTINGS_INFO * 32
	height = height + 32 + #AUCTIONDB_SETTINGS_INFO * 32
	height = height + 32 + #AUCTIONING_SETTINGS_INFO * 32
	height = height + 32 + #CRAFTING_SETTINGS_INFO * 32
	height = height + 32 + #SHOPPING_SETTINGS_INFO * 32
	height = height + 32 + #SNIPER_SETTINGS_INFO * 32
	height = height - 12
	return height
end

function private.CreateHeadingText(id, heading)
	return UIElements.New("Text", id)
		:SetHeight(20)
		:SetMargin(0, 0, 0, 12)
		:SetFont("BODY_SMALL_SEMIBOLD")
		:SetText(heading)
end

function private.GetSettingTableFromInfo(info)
	if info.settingModule then
		return private.settings.moduleTooltips[info.settingModule]
	elseif info.settingTbl then
		return private.settings[info.settingTbl]
	else
		return private.settings
	end
end

---@param frame BaseFrame
function private.AddSettingsFromInfoTable(frame, infoTbl)
	for i, info in ipairs(infoTbl) do
		local settingTbl = private.GetSettingTableFromInfo(info)
		frame:AddChild(UIElements.New("TooltipLineCheckbox", "checkbox_"..i)
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetInfo(info)
			:SetContext(info)
			:SetText(info.label)
			:SetChecked(settingTbl[info.settingKey] == (info.setValue or true))
			:SetAction("OnValueChanged", "ACTION_HANDLE_CHECKBOX_VALUE_CHANGED")
		)
	end
end

---@param frame BaseFrame
function private.AddCustomSourceSettings(frame)
	for _, name in CustomPrice.CustomSourceIterator() do
		frame:AddChild(UIElements.New("Checkbox", "checkbox_"..name)
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetText(format(L["Custom source (%s)"], name))
			:SetSettingInfo(private.settings.customPriceTooltips, name)
			:SetAction("OnValueChanged", "ACTION_REBUILD_EXAMPLE_TOOLTIP")
		)
	end
end

---@param frame BaseFrame
function private.AddExampleTooltip(frame)
	for i, left, right, lineColor in TooltipApp.SettingsLineIterator() do
		frame:AddChild(UIElements.New("BaseFrame", "row_"..i)
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:AddChild(UIElements.New("Text", "left_"..i)
				:SetWidth("AUTO")
				:SetFont("ITEM_XSMALL")
				:SetTextColor(lineColor)
				:SetText(left)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChildIf(right ~= nil, UIElements.New("Text", "right_"..i)
				:SetWidth("AUTO")
				:SetFont("ITEM_XSMALL")
				:SetTextColor(lineColor)
				:SetJustifyH("RIGHT")
				:SetText(right or "")
			)
		)
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<TooltipSettingsUIState>
---@param state TooltipSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_CHECKBOX_VALUE_CHANGED" then
		local info, isChecked = ...
		local settingTbl = private.GetSettingTableFromInfo(info)
		if isChecked then
			settingTbl[info.settingKey] = info.setValue or true
		else
			settingTbl[info.settingKey] = info.clearValue or false
		end
		for _, child in state.settingsFrame:LayoutChildrenIterator() do
			if child:GetContext() == info then
				---@cast child TooltipLineCheckbox
				child:SetChecked(settingTbl[info.settingKey] == (info.setValue or true), true)
					:Draw()
			end
		end
		private.manager:ProcessAction("ACTION_REBUILD_EXAMPLE_TOOLTIP")
	elseif action == "ACTION_REBUILD_EXAMPLE_TOOLTIP" then
		state.tooltipFrame:ReleaseAllChildren()
		state.tooltipFrame:AddChildrenWithFunction(private.AddExampleTooltip)
		state.tooltipFrame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

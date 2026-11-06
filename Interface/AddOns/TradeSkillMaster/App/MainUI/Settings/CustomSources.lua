-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CustomSources = App:Init("MainUI.Settings.CustomSources")
local Iterator = App:From("LibTSMUtil"):Include("BaseType.Iterator")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local CustomPrice = App:From("LibTSMApp"):Include("Price.CustomPrice")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("CustomSourcesSettingsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddDeferredUIElementField("list", "CustomSourcesList")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(CustomSources, function(db)
	private.settings = db:NewView("CustomSourcesSettings")
		:AddKey("global", "userData", "customPriceSources")
		:AddKey("global", "userData", "customPriceSourceFormat")
		:AddKey("global", "tooltipOptions", "customPriceTooltips")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("CUSTOM_SOURCES_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetCustomSourcesSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the custom sources settings frame.
---@return BaseScrollFrame
function CustomSources.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Custom Sources Settings UI
-- ============================================================================

---@param state CustomSourcesSettingsUIState
function private.GetCustomSourcesSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "custom_sources")
	return UIElements.New("BaseScrollFrame", "content")
		:SetPadding(8, 8, 8, 0)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Custom Sources"], format(L["Custom sources allow you to create more advanced prices for use throughout the addon. You'll be able to use these new variables in the same way you can use the built-in price sources such as %s and %s."], Theme.GetColor("accent/main"):ColorText("vendorsell"), Theme.GetColor("accent/main"):ColorText("vendorbuy")))
			:SetDescriptionHeight(60)
			:AddChild(UIElements.New("CustomSourcesList", "list")
				:SetData(Iterator.Acquire(CustomPrice.CustomSourceIterator()):SetMapFunc(private.CustomSourceIteratorMap))
				:BindElement(state, "list")
				:SetAction("OnEdit", "ACTION_EDIT")
				:SetAction("OnDelete", "ACTION_DELETE")
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "addNewBtn")
				:SetMargin(0, 0, 12, 0)
				:SetText(L["Add a new custom source"])
				:SetAction("OnClick", "ACTION_ADD")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<CustomSourcesSettingsUIState>
---@param state CustomSourcesSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_EDIT" then
		local name = ...
		local value = private.settings.customPriceSources[name]
		local formatKey = private.settings.customPriceSourceFormat[name]
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("CustomSourceEditDialog", "dialog")
			:Configure(name, CustomPrice.ValidateCustomSourceName, formatKey, value, CustomPrice.Validate)
			:SetManager(manager)
			:SetAction("OnDoneEditing", "ACTION_HANDLE_EDIT")
		)
	elseif action == "ACTION_HANDLE_EDIT" then
		local oldName, newName, formatKey, value = ...
		private.settings.customPriceSourceFormat[oldName] = formatKey
		CustomString.UpdateCustomSource(oldName, value)
		if oldName ~= newName then
			CustomString.RenameCustomSource(oldName, newName)
			private.settings.customPriceSourceFormat[newName] = private.settings.customPriceSourceFormat[oldName]
			private.settings.customPriceSourceFormat[oldName] = nil
			private.settings.customPriceTooltips[newName] = private.settings.customPriceTooltips[oldName]
			private.settings.customPriceTooltips[oldName] = nil
		end
		if oldName == newName then
			state.list:UpdateRow(oldName, formatKey, value)
		else
			state.list:RemoveRow(oldName)
			state.list:AddRow(newName, formatKey, value)
			state.frame:Draw()
		end
	elseif action == "ACTION_DELETE" then
		local name = ...
		CustomString.RemoveCustomSource(name)
		private.settings.customPriceSourceFormat[name] = nil
		private.settings.customPriceTooltips[name] = nil
		state.list:RemoveRow(name)
		state.frame:Draw()
	elseif action == "ACTION_ADD" then
		local newName = private.GetNewCustomSourceName()
		local format = "gold"
		local value = ""
		CustomString.AddCustomSource(newName, value)
		private.settings.customPriceSourceFormat[newName] = format
		state.list:AddRow(newName, format, value)
		state.frame:Draw()
		return manager:ProcessAction("ACTION_EDIT", newName)
	else
		error("Unknown action: "..tostring(action))
	end
end




-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CustomSourceIteratorMap(_, name)
	return name, private.settings.customPriceSourceFormat[name], private.settings.customPriceSources[name]
end

function private.GetNewCustomSourceName()
	local suffix = ""
	while true do
		for i = strbyte("a"), strbyte("z") do
			local newName = "customprice"..suffix..strchar(i)
			if not private.settings.customPriceSources[newName] then
				return newName
			end
		end
		suffix = suffix..strchar(random(strbyte("a"), strbyte("z")))
	end
end

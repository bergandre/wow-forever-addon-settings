-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Appearance = App:Init("MainUI.Settings.Appearance")
local TaskListUI = App:Include("TaskListUI")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local ColorPicker = App:From("LibTSMUI"):Include("Util.ColorPicker")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local ThemeColorSets = App:From("LibTSMApp"):Include("Service.ThemeColorSets")
local LibDBIcon = LibStub("LibDBIcon-1.0")
local private = {
	settings = nil,
	manager = nil,
}
local SETTING_TOOLTIPS = {
	showTotalMoney = L["If enabled, the gold amount in the top-right of TSM windows will be your total gold, rather than the gold on the current character."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("AppearanceSettingsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddDeferredUIElementField("themeFrame", "BaseFrame")
	:Commit()

---@event AppearanceSettingsAction
---| "ACTION_UPDATE_MINIMAP_ICON"
---| "ACTION_UPDATE_TASK_LIST"
---| "ACTION_SET_THEME" -> selectedKey: string
---| "ACTION_SHOW_THEME_IMPORT"
---| "ACTION_IMPORT_THEME" -> value: string
---| "ACTION_EXPORT_THEME"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Appearance, function(db)
	private.settings = db:NewView("AppearanceSettings")
		:AddKey("global", "appearanceOptions", "activeThemeKey")
		:AddKey("global", "coreOptions", "minimapIcon")
		:AddKey("global", "appearanceOptions", "taskListBackgroundLock")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("APPEARANCE_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetAppearanceSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the appearance settings frame.
---@return BaseScrollFrame
function Appearance.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Appearance Settings UI
-- ============================================================================

---@param state AppearanceSettingsUIState
function private.GetAppearanceSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "appearance")
	return UIElements.New("BaseScrollFrame", "generalSettings")
		:SetPadding(8, 8, 8, 0)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general appearance options are below."])
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "minimapCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Hide minimap icon"])
					:SetSettingInfo(private.settings.minimapIcon, "hide")
					:SetAction("OnValueChanged", "ACTION_UPDATE_MINIMAP_ICON")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "taskListLockCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Lock task list's background"])
					:SetSettingInfo(private.settings, "taskListBackgroundLock")
					:SetAction("OnValueChanged", "ACTION_UPDATE_TASK_LIST")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "showTotalMoneyCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Show total gold in header"])
					:SetSettingInfo(private.settings, "showTotalMoney")
					:SetTooltip(SETTING_TOOLTIPS.showTotalMoney)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(UIElements.New("Text", "label")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetText(L["Themes"])
		)
		:AddChild(UIElements.New("BaseFrame", "theme")
			:SetLayout("FLOW")
			:BindElement(state, "themeFrame")
			:AddChildrenWithFunction(private.CreateThemes)
		)
		:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 16, 8)
			:AddChild(UIElements.New("Text", "customLabel")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(L["Custom Theme"])
			)
			:AddChild(UIElements.New("BaseButton", "exportBtn")
				:SetWidth(24)
				:SetMargin(12, 4, 0, 0)
				:SetBackgroundAndSize("iconPack.18x18/Export")
				:SetTooltip(L["Export theme"])
				:SetAction("OnClick", "ACTION_EXPORT_THEME")
			)
			:AddChild(UIElements.New("BaseButton", "importBtn")
				:SetWidth(24)
				:SetMargin(8, 0, 0, 0)
				:SetBackground("iconPack.18x18/Import")
				:SetTooltip(L["Import Theme"])
				:SetAction("OnClick", "ACTION_SHOW_THEME_IMPORT")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "custom")
			:SetLayout("HORIZONTAL")
			:SetMargin(0, 0, 0, 24)
			:AddChild(UIElements.New("EditableRampColor", "neutral")
				:SetMargin(0, 16, 0, 0)
				:Configure("surface", L["Neutral"])
			)
			:AddChild(UIElements.New("EditableRampColor", "primary")
				:SetMargin(0, 16, 0, 0)
				:Configure("primary", L["Primary"])
			)
			:AddChild(UIElements.New("EditableRampColor", "secondary")
				:SetMargin(0, 16, 0, 0)
				:Configure("secondary", L["Secondary"])
			)
		)
		:SetScript("OnHide", ColorPicker.Hide)
end

function private.CreateThemes(frame)
	local activeThemePublisher = private.settings:PublisherForKey("activeThemeKey")
		:Share()
	local CUSTOM_COLOR_SET_KEY = ThemeColorSets.GetCustomColorSetKey()
	for _, key, name in ThemeColorSets.Iterator() do
		frame:AddChild(UIElements.New("ThemeButton", key)
			:SetMargin(0, 12, 0, 8)
			:Configure(key, name, activeThemePublisher, key == CUSTOM_COLOR_SET_KEY)
			:SetAction("OnSelected", "ACTION_SET_THEME")
		)
	end
	frame:AddCancellable(activeThemePublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<AppearanceSettingsUIState>
---@param state AppearanceSettingsUIState
---@param action AppearanceSettingsAction
---@param ... params<AppearanceSettingsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_MINIMAP_ICON" then
		if private.settings.minimapIcon.hide then
			LibDBIcon:Hide("TradeSkillMaster")
		else
			LibDBIcon:Show("TradeSkillMaster")
		end
	elseif action == "ACTION_UPDATE_TASK_LIST" then
		if TaskListUI.IsVisible() then
			TaskListUI.UpdateFrame()
		end
	elseif action == "ACTION_SET_THEME" then
		local selectedKey = ...
		ThemeColorSets.SetActive(selectedKey)
	elseif action == "ACTION_SHOW_THEME_IMPORT" then
		ColorPicker.Hide()
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("ThemeImportDialog", "frame")
			:SetManager(manager)
			:SetAction("OnImport", "ACTION_IMPORT_THEME")
		)
	elseif action == "ACTION_IMPORT_THEME" then
		local value = ...
		if not ThemeColorSets.ImportCustom(value) then
			ChatMessage.PrintUser(L["The pasted value was not valid. Ensure you are pasting the entire import string."])
			return
		end
		state.themeFrame:Draw()
	elseif action == "ACTION_EXPORT_THEME" then
		local value = ThemeColorSets.ExportCustom()
		ColorPicker.Hide()
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("ThemeExportDialog", "frame")
			:SetValue(value)
		)
	else
		error("Unknown action: "..tostring(action))
	end
end

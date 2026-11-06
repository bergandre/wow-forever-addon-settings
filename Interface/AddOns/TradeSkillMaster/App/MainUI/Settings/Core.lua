-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Settings = App:Init("MainUI.Settings")
local General = App:Include("MainUI.Settings.General")
local Tooltip = App:Include("MainUI.Settings.Tooltip")
local Accounting = App:Include("MainUI.Settings.Accounting")
local Appearance = App:Include("MainUI.Settings.Appearance")
local Auctioning = App:Include("MainUI.Settings.Auctioning")
local Destroying = App:Include("MainUI.Settings.Destroying")
local Mailing = App:Include("MainUI.Settings.Mailing")
local CustomSources = App:Include("MainUI.Settings.CustomSources")
local Crafting = App:Include("MainUI.Settings.Crafting")
local Macros = App:Include("MainUI.Settings.Macros")
local BrowseSniper = App:Include("MainUI.Settings.BrowseSniper")
local Vendoring = App:Include("MainUI.Settings.Vendoring")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	manager = nil,
	pages = {},
	isTop = {},
	callback = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("SettingsUIState")
	:AddDeferredUIElementField("contentFrame", "ViewContainer")
	:AddStringField("selectedPath", "")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Settings:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetSettingsFrame)

	private.AddTopPage(L["General Settings"], General.GetFrame)
	private.AddTopPage(L["Tooltip Settings"], Tooltip.GetFrame)
	private.AddBottomPage(L["Accounting"], Accounting.GetFrame)
	private.AddBottomPage(L["Appearance"], Appearance.GetFrame)
	private.AddBottomPage(L["Auctioning"], Auctioning.GetFrame)
	private.AddBottomPage(L["Destroying"], Destroying.GetFrame)
	private.AddBottomPage(L["Mailing"], Mailing.GetFrame)
	private.AddBottomPage(L["Custom Sources"], CustomSources.GetFrame)
	private.AddBottomPage(L["Crafting"], Crafting.GetFrame)
	private.AddBottomPage(L["Macros"], Macros.GetFrame)
	private.AddBottomPage(L["Browse / Sniper"], BrowseSniper.GetFrame)
	private.AddBottomPage(L["Vendoring"], Vendoring.GetFrame)
	state.selectedPath = private.pages[1]
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the settings frame.
---@return BaseFrame
function Settings.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Settings UI
-- ============================================================================

---@param state SettingsUIState
function private.GetSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings")
	return UIElements.New("BaseFrame", "settings")
		:SetLayout("HORIZONTAL")
		:SetPadding(8, 8, 8, 8)
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "settingNavigation")
			:SetLayout("VERTICAL")
			:SetWidth(165)
			:SetRoundedBackgroundColor("container/low")
			:SetPadding(12, 12, 9, 9)
			:AddChild(UIElements.New("BaseFrame", "top")
				:SetLayout("VERTICAL")
				:AddChildrenWithFunction(private.AddNavButtons, state, true)
			)
			:AddChild(UIElements.New("BaseFrame", "bottom")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 16, 0)
				:AddChildrenWithFunction(private.AddNavButtons, state, false)
			)
			-- Make all the navigation align to the top
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
		:AddChild(UIElements.New("BaseFrame", "contentFrame")
			:SetLayout("VERTICAL")
			:SetMargin(8, 0, 0, 0)
			:AddChild(UIElements.New("ViewContainer", "content")
				:BindElement(state, "contentFrame")
				:SetNavCallback(private.ContentNavCallback)
				:SetPathList(private.pages, state.selectedPath)
			)
		)
end

---@param frame BaseFrame
---@param state SettingsUIState
function private.AddNavButtons(frame, state, isTop)
	for _, name in ipairs(private.pages) do
		if private.isTop[name] == isTop then
			frame:AddChild(UIElements.New("SettingsNavButton", name)
				:SetHeight(20)
				:SetMargin(0, 0, 8, 0)
				:SetText(name)
				:SetSelectedPath(state:Publisher("selectedPath"))
				:SetAction("OnClick", "ACTION_SELECT_PATH")
			)
		end
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param state SettingsUIState
function private.ActionHandler(_, state, action, ...)
	if action == "ACTION_SELECT_PATH" then
		local path = ...
		state.selectedPath = path
		state.contentFrame:SetPath(path, true)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AddTopPage(name, callback)
	tinsert(private.pages, name)
	private.isTop[name] = true
	private.callback[name] = callback
end

function private.AddBottomPage(name, callback)
	tinsert(private.pages, name)
	private.isTop[name] = false
	private.callback[name] = callback
end

function private.ContentNavCallback(_, path)
	return private.callback[path]()
end

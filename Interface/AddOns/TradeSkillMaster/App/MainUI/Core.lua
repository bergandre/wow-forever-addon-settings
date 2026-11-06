-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local MainUI = App:Init("MainUI")
local Dashboard = App:Include("MainUI.Dashboard")
local Groups = App:Include("MainUI.Groups")
local Ledger = App:Include("MainUI.Ledger")
local Operations = App:Include("MainUI.Operations")
local Settings = App:Include("MainUI.Settings")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local MinimapIcon = App:From("LibTSMUI"):Include("MinimapIcon")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SlashCommands = App:From("LibTSMApp"):Include("Service.SlashCommands")
local WhatsNew = App:From("LibTSMApp"):Include("UI.WhatsNew")
local private = {
	settings = nil,
	manager = nil,
}
local MIN_FRAME_SIZE = { width = 720, height = 588 }
local STATE_SCHEMA = Reactive.CreateStateSchema("MainUIState")
	:AddDeferredUIElementField("frame", "LargeApplicationFrame")
	:Commit()

---@event MainUIAction
---| "ACTION_TOGGLE"
---| "ACTION_SHOW_FRAME"
---| "ACTION_HIDE_FRAME"
---| "ACTION_HANDLE_HIDE"
---| "ACTION_SHOW_OPERATION_SETTINGS" -> typeName: string, operationName: string
---| "ACTION_SHOW_GROUP_SETTINGS" -> groupPath: GroupPathValue



-- ============================================================================
-- Module Functions
-- ============================================================================

AddonSettings.RegisterOnLoad(MainUI, function(db)
	private.settings = db:NewView("MainUISettings")
		:AddKey("global", "coreOptions", "minimapIcon")
		:AddKey("global", "mainUIContext", "frame")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAIN_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.CreateMainFrame)

	Groups.Configure(private.manager:CallbackToProcessAction("ACTION_SHOW_OPERATION_SETTINGS"))
	Operations.Configure(private.manager:CallbackToProcessAction("ACTION_SHOW_GROUP_SETTINGS"))

	UIUtils.RegisterUIForAnalytics("main")
	SlashCommands.RegisterBase(private.manager:CallbackToProcessAction("ACTION_TOGGLE"), L["Toggles the main TSM window"])
	MinimapIcon.Configure(private.settings.minimapIcon, private.manager:CallbackToProcessAction("ACTION_TOGGLE"))
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state MainUIState
function private.CreateMainFrame(state)
	UIUtils.AnalyticsRecordPathChange("main")
	-- Always show the Dashboard first
	private.settings.frame.page = 1
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:AddPlayerGold()
		:AddAppStatusIcon()
		:BindElement(state, "frame")
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:AddNavButton(L["Dashboard"], Dashboard.GetFrame)
		:AddNavButton(L["Ledger"], Ledger.GetFrame)
		:AddNavButton(L["Groups"], Groups.GetFrame)
		:AddNavButton(L["Operations"], Operations.GetFrame)
		:AddNavButton(L["Settings"], Settings.GetFrame)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_HIDE"))
	WhatsNew.ShowDialog(frame)
	frame:Draw()
	frame:Show()
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MainUIState>
---@param state MainUIState
---@param action MainUIAction
---@param ... params<MainUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE" then
		return manager:ProcessAction(state.frame and "ACTION_HIDE_FRAME" or "ACTION_SHOW_FRAME")
	elseif action == "ACTION_SHOW_FRAME" then
		manager:BuildFrame()
	elseif action == "ACTION_HIDE_FRAME" then
		if not state.frame then
			return
		end
		state.frame:Hide()
	elseif action == "ACTION_HANDLE_HIDE" then
		UIUtils.AnalyticsRecordClose("main")
		state.frame:Release()
	elseif action == "ACTION_SHOW_OPERATION_SETTINGS" then
		local typeName, operationName = ...
		state.frame:SetSelectedNavButton(L["Operations"], true)
		Operations.SetSelectedOperation(typeName, operationName)
	elseif action == "ACTION_SHOW_GROUP_SETTINGS" then
		local groupPath = ...
		state.frame:SetSelectedNavButton(L["Groups"], true)
		Groups.SetSelectedGroup(groupPath)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogout()
	private.manager:ProcessAction("ACTION_HIDE_FRAME")
	return true
end

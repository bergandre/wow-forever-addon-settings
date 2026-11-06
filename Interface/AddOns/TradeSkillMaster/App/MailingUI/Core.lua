-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local MailingUI = App:Init("MailingUI")
local Groups = App:Include("MailingUI.Groups")
local Inbox = App:Include("MailingUI.Inbox")
local Other = App:Include("MailingUI.Other")
local Send = App:Include("MailingUI.Send")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Container = App:From("LibTSMWoW"):Include("API.Container")
local InboxAPI = App:From("LibTSMWoW"):Include("API.Inbox")
local ScriptWrapper = App:From("LibTSMWoW"):Include("API.ScriptWrapper")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local DefaultUI = App:From("LibTSMWoW"):Include("UI.DefaultUI")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
	topLevelPages = {},
	isVisible = false,
	showTimer = nil,
}
local MIN_FRAME_SIZE = { width = 575, height = 400 }
local STATE_SCHEMA = Reactive.CreateStateSchema("MailingUIState")
	:AddDeferredUIElementField("frame", "LargeApplicationFrame")
	:AddOptionalUIElementField("switchButton", "SwitchButton")
	:AddBooleanField("showDefault", false)
	:AddBooleanField("isMailOpen", false)
	:Commit()

---@event MailingUIAction
---| "ACTION_SHOW_FRAME"
---| "ACTION_HIDE_FRAME"
---| "ACTION_SHOW_DEFAULT"
---| "ACTION_HIDE_DEFAULT"
---| "ACTION_HANDLE_SHOW"
---| "ACTION_HANDLE_FRAME_HIDE"
---| "ACTION_SWITCH"
---| "ACTION_SET_SELECTED_TAB" -> tab: string



-- ============================================================================
-- Module Loading
-- ============================================================================

MailingUI:OnModuleLoad(function()
	UIUtils.RegisterUIForAnalytics("mailing")
	tinsert(private.topLevelPages, { name = L["Inbox"], callback = Inbox.GetFrame })
	tinsert(private.topLevelPages, { name = L["Send"], callback = Send.GetFrame })
	tinsert(private.topLevelPages, { name = L["Groups"], callback = Groups.GetFrame })
	tinsert(private.topLevelPages, { name = L["Other"], callback = Other.GetFrame })
	Inbox.SetReplyFunc(private.HandleReply)
end)

AddonSettings.RegisterOnLoad(MailingUI, function(db)
	private.settings = db:NewView("MailingUISettings")
		:AddKey("global", "mailingUIContext", "showDefault")
		:AddKey("global", "mailingUIContext", "frame")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING", state, private.ActionHandler)

	-- Mirror state to settings value
	private.manager:MirrorStateWithTable("showDefault", private.settings, "showDefault")

	private.isVisible = false -- Explicitly set private.isVisible at least once to appease the linter
	private.manager:AddCancellable(state:Publisher("frame")
		:ToBooleanNotEquals(nil)
		:AssignToTableKey(private, "isVisible")
	)

	-- Register for various show / hide events
	private.showTimer = DelayTimer.New("MAILING_SHOW", private.manager:CallbackToProcessAction("ACTION_HANDLE_SHOW"))
	DefaultUI.RegisterMailVisibleCallback(function(visible)
		if visible then
			private.showTimer:RunForFrames(0)
		else
			private.manager:ProcessAction("ACTION_HANDLE_FRAME_HIDE")
		end
	end)
	InboxAPI.GetMailFrame():UnregisterEvent("MAIL_SHOW")
	ScriptWrapper.Set(InboxAPI.GetMailFrame(), "OnHide", function()
		if not private.settings.showDefault then
			return
		end
		private.manager:ProcessAction("ACTION_HANDLE_FRAME_HIDE")
	end)

	-- Close the frame on logout
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not the mailing UI is visible.
---@return boolean
function MailingUI.IsVisible()
	return private.isVisible
end



-- ============================================================================
-- Main Frame / Switch Button
-- ============================================================================

function private.CreateMainFrame()
	-- Always show the inbox page first
	private.settings.frame.page = 1
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:AddSwitchButton()
		:SetManager(private.manager)
		:SetAction("OnSwitchButtonClick", "ACTION_SWITCH")
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDE"))
	for _, info in ipairs(private.topLevelPages) do
		frame:AddNavButton(info.name, info.callback)
	end
	return frame
end

function private.CreateSwitchButton()
	return UIElements.New("SwitchButton", "switchBtn")
		:SetDefaultUIParentFrame(InboxAPI.GetMailFrame())
		:SetManager(private.manager)
		:SetAction("OnClick", "ACTION_SWITCH")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MailingUIState>
---@param state MailingUIState
---@param action MailingUIAction
---@param ... params<MailingUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_FRAME" then
		if not App.IsRetail() and not App.IsForever() then
			Container.OpenAllBags()
		end
		InboxAPI.Check()
		InboxAPI.HideMailFrame()
		assert(not state.frame)
		state.frame = private.CreateMainFrame()
		state.frame:Show()
		state.frame:Draw()
		UIUtils.AnalyticsRecordPathChange("mailing")
	elseif action == "ACTION_HIDE_FRAME" then
		state.frame:SetScript("OnHide", nil)
		state.frame:Hide()
		state.frame:Release()
		state.frame = nil
		UIUtils.AnalyticsRecordClose("mailing")
	elseif action == "ACTION_SHOW_DEFAULT" then
		InboxAPI.ShowMailFrame()
		state.switchButton = state.switchButton or private.CreateSwitchButton()
		state.switchButton:Show()
		state.switchButton:Draw()
	elseif action == "ACTION_HIDE_DEFAULT" then
		InboxAPI.HideOpenMailFrame()
	elseif action == "ACTION_HANDLE_SHOW" then
		if state.isMailOpen then
			return
		end
		if state.showDefault then
			manager:ProcessAction("ACTION_SHOW_DEFAULT")
		else
			manager:ProcessAction("ACTION_SHOW_FRAME")
		end
		state.isMailOpen = true
	elseif action == "ACTION_HANDLE_FRAME_HIDE" then
		if not state.isMailOpen then
			return
		end
		state.isMailOpen = false
		if state.showDefault then
			manager:ProcessAction("ACTION_HIDE_DEFAULT")
		else
			manager:ProcessAction("ACTION_HIDE_FRAME")
		end
		InboxAPI.CloseMail()
	elseif action == "ACTION_SWITCH" then
		assert(state.isMailOpen)
		state.showDefault = not state.showDefault
		if state.showDefault then
			manager:ProcessAction("ACTION_HIDE_FRAME")
			manager:ProcessAction("ACTION_SHOW_DEFAULT")
		else
			manager:ProcessAction("ACTION_HIDE_DEFAULT")
			manager:ProcessAction("ACTION_SHOW_FRAME")
		end
	elseif action == "ACTION_SET_SELECTED_TAB" then
		local tab = ...
		state.frame:SetSelectedNavButton(tab, true)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogout()
	private.manager:ProcessAction("ACTION_HANDLE_FRAME_HIDE")
	return true
end

function private.HandleReply(sender)
	Send.SetRecipient(sender)
	private.manager:ProcessAction("ACTION_SET_SELECTED_TAB", L["Send"])
end

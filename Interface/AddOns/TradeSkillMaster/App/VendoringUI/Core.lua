-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local VendoringUI = App:Init("VendoringUI")
local Buy = App:Include("VendoringUI.Buy")
local Buyback = App:Include("VendoringUI.Buyback")
local Groups = App:Include("VendoringUI.Groups")
local Sell = App:Include("VendoringUI.Sell")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Merchant = App:From("LibTSMWoW"):Include("API.Merchant")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local DefaultUI = App:From("LibTSMWoW"):Include("UI.DefaultUI")
local Move = App:From("LibTSMWoW"):Include("Service.Move")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local TaskList = App:From("LibTSMApp"):Include("TaskList")
local private = {
	settings = nil,
	manager = nil,
	topLevelPages = {},
	isVisible = false,
	showTimer = nil,
}
local MIN_FRAME_SIZE = { width = 560, height = 500 }
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringUIState")
	:AddOptionalUIElementField("frame", "LargeApplicationFrame")
	:AddOptionalUIElementField("switchButton", "SwitchButton")
	:AddBooleanField("switching", false)
	:AddBooleanField("showDefault", false)
	:Commit()

---@event VendoringUIAction
---| "ACTION_HANDLE_MERCHANT_VISIBLE_CHANGED" -> visible: boolean
---| "ACTION_MERCHANT_SHOW_DELAYED"
---| "ACTION_SHOW_DEFAULT"
---| "ACTION_SHOW_FRAME"
---| "ACTION_HIDE_FRAME"
---| "ACTION_FRAME_HIDE"
---| "ACTION_SWITCH"



-- ============================================================================
-- Module Loading
-- ============================================================================

VendoringUI:OnModuleLoad(function()
	UIUtils.RegisterUIForAnalytics("vendoring")
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
	tinsert(private.topLevelPages, { name = L["Buy"], callback = Buy.GetFrame })
	tinsert(private.topLevelPages, { name = L["Sell"], callback = Sell.GetFrame })
	tinsert(private.topLevelPages, { name = GlobalStrings.Get("BUYBACK"), callback = Buyback.GetFrame })
	tinsert(private.topLevelPages, { name = L["Groups"], callback = Groups.GetFrame })
end)

AddonSettings.RegisterOnLoad(VendoringUI, function(db)
	private.settings = db:NewView("VendoringUISettings")
		:AddKey("global", "vendoringUIContext", "showDefault")
		:AddKey("global", "vendoringUIContext", "frame")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING", state, private.ActionHandler)

	-- Mirror state to settings value
	private.manager:MirrorStateWithTable("showDefault", private.settings, "showDefault")

	private.isVisible = false -- Explicitly set private.isVisible at least once to appease the linter
	private.manager:AddCancellable(state:Publisher("frame")
		:ToBooleanNotEquals(nil)
		:Share()
		:AssignToTableKey(private, "isVisible")
		:CallFunction(TaskList.SetVendoringTaskUIVisible)
		:EndShare()
	)

	private.showTimer = DelayTimer.New("VENDORING_SHOW", private.manager:CallbackToProcessAction("ACTION_MERCHANT_SHOW_DELAYED"))
	DefaultUI.RegisterMerchantVisibleCallback(private.manager:CallbackToProcessAction("ACTION_HANDLE_MERCHANT_VISIBLE_CHANGED"))
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function VendoringUI.IsVisible()
	return private.isVisible
end



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state VendoringUIState
function private.CreateMainFrame(state)
	UIUtils.AnalyticsRecordPathChange("vendoring")
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:BindElement(state, "frame")
		:AddSwitchButton()
		:SetManager(private.manager)
		:SetAction("OnSwitchButtonClick", "ACTION_SWITCH")
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_FRAME_HIDE"))
	for _, info in ipairs(private.topLevelPages) do
		frame:AddNavButton(info.name, info.callback)
	end
end

function private.CreateSwitchButton()
	return UIElements.New("SwitchButton", "switchBtn")
		:SetDefaultUIParentFrame(Merchant.GetDefaultUIFrame())
		:SetManager(private.manager)
		:SetAction("OnClick", "ACTION_SWITCH")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringUIState>
---@param state VendoringUIState
---@param action VendoringUIAction
---@param ... params<VendoringUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_MERCHANT_VISIBLE_CHANGED" then
		local visible = ...
		if visible then
			private.showTimer:RunForFrames(0)
		elseif state.frame then
			return manager:ProcessAction("ACTION_HIDE_FRAME")
		end
	elseif action == "ACTION_MERCHANT_SHOW_DELAYED" then
		return manager:ProcessAction(state.showDefault and "ACTION_SHOW_DEFAULT" or "ACTION_SHOW_FRAME")
	elseif action == "ACTION_SHOW_DEFAULT" then
		state.switchButton = state.switchButton or private.CreateSwitchButton()
		state.switchButton:Show()
		state.switchButton:Draw()
		Move.RestoreDefaultUI(Merchant.GetDefaultUIFrame())
		Merchant.UpdateDefaultUIFrame()
	elseif action == "ACTION_SHOW_FRAME" then
		assert(not state.frame)
		Move.SetDefaultUIOffScreen(Merchant.GetDefaultUIFrame())
		private.CreateMainFrame(state)
		assert(state.frame)
		state.frame:Show()
		state.frame:Draw()
	elseif action == "ACTION_HIDE_FRAME" then
		assert(state.frame)
		state.frame:Hide()
		state.frame:Release()
		assert(not state.frame)
	elseif action == "ACTION_FRAME_HIDE" then
		UIUtils.AnalyticsRecordClose("vendoring")
		if state.switching then
			return
		end
		Merchant.Close()
	elseif action == "ACTION_SWITCH" then
		state.showDefault = not state.showDefault
		if state.showDefault and state.frame then
			state.switching = true
			manager:ProcessAction("ACTION_HIDE_FRAME")
			state.switching = false
		end
		return manager:ProcessAction(state.showDefault and "ACTION_SHOW_DEFAULT" or "ACTION_SHOW_FRAME")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogout()
	Merchant.Close()
	return true
end

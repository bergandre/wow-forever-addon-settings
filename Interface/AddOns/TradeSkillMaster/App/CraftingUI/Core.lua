-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CraftingUI = App:Init("CraftingUI")
local CraftingProfession = App:Include("CraftingUI.CraftingProfession")
local CraftingReports = App:Include("CraftingUI.CraftingReports")
local Gathering = App:Include("CraftingUI.Gathering")
local EnumType = App:From("LibTSMUtil"):Include("BaseType.EnumType")
local CallbackRegistry = App:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local TradeSkill = App:From("LibTSMWoW"):Include("API.TradeSkill")
local CombatLockdown = App:From("LibTSMWoW"):Include("Service.CombatLockdown")
local Event = App:From("LibTSMWoW"):Include("Service.Event")
local Move = App:From("LibTSMWoW"):Include("Service.Move")
local Profession = App:From("LibTSMService"):Include("Profession")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SlashCommands = App:From("LibTSMApp"):Include("Service.SlashCommands")
local private = {
	manager = nil,
	settings = nil,
	topLevelPages = {},
	isVisible = false,
	apiCallbacks = CallbackRegistry.NewWithKeys("API function (%s)"),
}
local FRAME_STATE = EnumType.New("CRAFTING_FRAME_STATE", {
	CLOSED = EnumType.NewValue(),
	DEFAULT = EnumType.NewValue(),
	OPEN = EnumType.NewValue(),
})
local MIN_FRAME_SIZE = { width = 650, height = 587 }
local STATE_SCHEMA = Reactive.CreateStateSchema("CraftingUIState")
	:AddOptionalUIElementField("frame", "LargeApplicationFrame")
	:AddOptionalUIElementField("defaultUISwitchBtn", "SwitchButton")
	:AddEnumField("frameState", FRAME_STATE, FRAME_STATE.CLOSED)
	:AddBooleanField("craftOpen", false)
	:AddBooleanField("tradeSkillOpen", false)
	:AddBooleanField("switching", false)
	:AddBooleanField("showDefault", false)
	:AddBooleanField("switchShown", false)
	:AddBooleanField("inCombat", false)
	:AddBooleanField("bookPageShown", false)
	:AddBooleanField("defaultUIIgnored", false)
	:Commit()

---@event CraftingUIAction
---| "ACTION_SHOW_FRAME"
---| "ACTION_HIDE_FRAME"
---| "ACTION_SHOW_DEFAULT_UI" -> isIgnored: boolean
---| "ACTION_UPDATE_DEFAULT_CRAFT_BUTTON"
---| "ACTION_DEFAULT_UI_CRAFT_SHOW"
---| "ACTION_DEFAULT_UI_TRADE_SKILL_SHOW"
---| "ACTION_DEFAULT_UI_SHOW"
---| "ACTION_DEFAULT_UI_FRAME_SHOW"
---| "ACTION_DEFAULT_UI_BOOK_PAGE_CHANGED"
---| "ACTION_DEFAULT_UI_TRADE_SKILL_CLOSE"
---| "ACTION_DEFAULT_UI_CRAFT_CLOSE"
---| "ACTION_FRAME_HIDE"
---| "ACTION_CLOSE"
---| "ACTION_SWITCH"
---| "ACTION_TOGGLE"
---| "ACTION_ON_LOGOUT"



-- ============================================================================
-- Module Functions
-- ============================================================================

CraftingUI:OnModuleLoad(function()
	TradeSkill.LoadAddon()
	UIUtils.RegisterUIForAnalytics("crafting")
	tinsert(private.topLevelPages, { name = L["Crafting"], callback = CraftingProfession.GetFrame })
	tinsert(private.topLevelPages, { name = L["Gathering"], callback = Gathering.GetFrame })
	tinsert(private.topLevelPages, { name = L["Reports"], callback = CraftingReports.GetFrame })
end)

AddonSettings.RegisterOnLoad(CraftingUI, function(db)
	private.settings = db:NewView("CraftingUISettings")
		:AddKey("global", "craftingUIContext", "showDefault")
		:AddKey("global", "craftingUIContext", "frame")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("CRAFTING", state, private.ActionHandler)

	-- Register for events
	if not App.IsRetail() and not App.IsForever() then
		Event.Register("CRAFT_SHOW", private.manager:CallbackToProcessAction("ACTION_DEFAULT_UI_CRAFT_SHOW"))
		Event.Register("CRAFT_CLOSE", private.manager:CallbackToProcessAction("ACTION_DEFAULT_UI_CRAFT_CLOSE"))
	end
	Event.Register("TRADE_SKILL_SHOW", private.manager:CallbackToProcessAction("ACTION_DEFAULT_UI_TRADE_SKILL_SHOW"))
	Event.Register("TRADE_SKILL_CLOSE", private.manager:CallbackToProcessAction("ACTION_DEFAULT_UI_TRADE_SKILL_CLOSE"))
	if App.IsForever() then
		private.manager:AddCancellable(CombatLockdown.GetPublisher()
			:AssignToTableKey(state, "inCombat")
		)
		TradeSkill.RegisterDefaultFrameShowCallback(private.manager:CallbackToProcessAction("ACTION_DEFAULT_UI_FRAME_SHOW"))
		state.bookPageShown = TradeSkill.IsDefaultUIBookPageShown()
		TradeSkill.RegisterDefaultUIBookPageCallback(private.manager:CallbackToProcessAction("ACTION_DEFAULT_UI_BOOK_PAGE_CHANGED"))
	end

	-- Mirror the isVisible state
	private.isVisible = false -- Explicitly set private.isVisible at least once to appease the linter
	private.manager:AddCancellable(state:Publisher("frame")
		:ToBooleanNotEquals(nil)
		:AssignToTableKey(private, "isVisible")
	)

	-- Mirror the showDefault state to the settings
	private.manager:MirrorStateWithTable("showDefault", private.settings, "showDefault")

	-- Set up callbacks
	private.manager:AddCancellable(state:Publisher("frame")
		:CallFunction(private.CallAPICallbacks)
	)

	Profession.SetScannerDisabled(state.showDefault)
	SlashCommands.Register("crafting", private.manager:CallbackToProcessAction("ACTION_TOGGLE"), L["Toggles the TSM Crafting UI."])

	-- Close the frame on logout
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)

---Returns whether or not the crafting UI is currently visible.
---@return boolean
function CraftingUI.IsVisible()
	return private.isVisible
end

---Registers a callback for a 3rd-party addon to be notified when the UI is shown / hidden.
---@param addonTag string The tag to use to identify the 3rd-party addon
---@param func fun(isVisible: boolean, frame: Frame) The callback function
function CraftingUI.RegisterApiCallback(addonTag, func)
	if private.apiCallbacks:HasCallback(addonTag) then
		error("Callback already registered for addonTag: "..tostring(addonTag), 3)
	end
	private.apiCallbacks:Add(func, addonTag)
end



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state CraftingUIState
function private.CreateMainFrame(state)
	UIUtils.AnalyticsRecordPathChange("crafting")
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:AddPlayerGold()
		:AddAppStatusIcon()
		:BindElement(state, "frame")
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:RemoveContentBorder()
		:OverrideCloseAction("ACTION_FRAME_HIDE", private.manager)
		:AddSwitchButton()
		:SetManager(private.manager)
		:SetSwitchShown(state:Publisher("switchShown"))
		:SetSwitchDisabled(state:Publisher("inCombat"))
		:SetAction("OnSwitchButtonClick", "ACTION_SWITCH")
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_FRAME_HIDE"))
	for _, info in ipairs(private.topLevelPages) do
		frame:AddNavButton(info.name, info.callback)
	end
	state.switchShown = true
	frame:Show()
	frame:Draw()
end

function private.CreateDefaultUISwitchButton(state)
	return UIElements.New("SwitchButton", "switchBtn")
		:SetDefaultUIParentFrame(TradeSkill.GetVisibleDefaultFrame(false))
		:WipeAnchors()
		:AddAnchor("TOPRIGHT", (App.IsRetail() or App.IsForever()) and -50 or -60, (App.IsRetail() or App.IsForever()) and -4 or -16)
		:SetManager(private.manager)
		:SetAction("OnClick", "ACTION_SWITCH")
		:SetShown(state:Publisher([[not defaultUIIgnored and not bookPageShown]]))
		:SetDisabled(state:Publisher([[inCombat or not (tradeSkillOpen or craftOpen)]]))
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<CraftingUIState>
---@param state CraftingUIState
---@param action CraftingUIAction
---@param ... params<CraftingUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_FRAME" then
		assert(not state.frame)
		local visibleFrame = TradeSkill.GetVisibleDefaultFrame(state.craftOpen)
		Move.SetDefaultUIOffScreen(visibleFrame)
		private.CreateMainFrame(state)
	elseif action == "ACTION_HIDE_FRAME" then
		if not state.frame then
			return
		end
		local frame = state.frame
		frame:Hide()
		frame:Release()
		if App.IsForever() and not state.switching then
			Move.RestoreDefaultUI(TradeSkill.GetVisibleDefaultFrame(false))
		end
		if not App.IsRetail() and not App.IsForever() then
			manager:ProcessAction("ACTION_UPDATE_DEFAULT_CRAFT_BUTTON")
		end
	elseif action == "ACTION_SHOW_DEFAULT_UI" then
		local isIgnored = ...
		if state.craftOpen then
			manager:ProcessAction("ACTION_UPDATE_DEFAULT_CRAFT_BUTTON")
		end
		state.defaultUISwitchBtn = state.defaultUISwitchBtn or private.CreateDefaultUISwitchButton(state)
		local visibleFrame = TradeSkill.GetVisibleDefaultFrame(state.craftOpen)
		Move.RestoreDefaultUI(visibleFrame)
		if App.IsVanillaClassic() or App.IsBCClassic() then
			local otherFrame = TradeSkill.GetVisibleDefaultFrame(not state.craftOpen) --[[@as Frame?]]
			if otherFrame then
				Move.RestoreDefaultUI(otherFrame)
			end
		end
		state.defaultUISwitchBtn:SetDefaultUIParentFrame(visibleFrame)
		state.defaultUIIgnored = isIgnored and true or false
		if isIgnored then
			Profession.SetScannerDisabled(true)
		else
			state.defaultUISwitchBtn:Draw()
		end
	elseif action == "ACTION_UPDATE_DEFAULT_CRAFT_BUTTON" then
		if state.craftOpen then
			TradeSkill.UpdateDefaultUICraftButton()
		end
	elseif action == "ACTION_DEFAULT_UI_CRAFT_SHOW" then
		TradeSkill.CloseDefaultUI()
		state.craftOpen = true
		state.tradeSkillOpen = false
		if (App.IsVanillaClassic() or App.IsBCClassic()) and state.frame then
			local visibleFrame = TradeSkill.GetVisibleDefaultFrame(state.craftOpen)
			Move.SetDefaultUIOffScreen(visibleFrame)
		end
		Profession.SetClassicCraftingOpen(true)
		return manager:ProcessAction("ACTION_DEFAULT_UI_SHOW")
	elseif action == "ACTION_DEFAULT_UI_TRADE_SKILL_SHOW" then
		TradeSkill.CloseDefaultCraftUI()
		state.craftOpen = false
		state.tradeSkillOpen = true
		if (App.IsVanillaClassic() or App.IsBCClassic()) and state.frame then
			local visibleFrame = TradeSkill.GetVisibleDefaultFrame(state.craftOpen)
			Move.SetDefaultUIOffScreen(visibleFrame)
		end
		return manager:ProcessAction("ACTION_DEFAULT_UI_SHOW")
	elseif action == "ACTION_DEFAULT_UI_SHOW" then
		local isIgnored = Profession.IsIgnored(TradeSkill.GetName())
		local shouldOpen = not isIgnored and not state.showDefault and not private.IsDefaultUILocked()
		if state.frameState == FRAME_STATE.CLOSED then
			Profession.SetScannerDisabled(state.showDefault)
			state.frameState = shouldOpen and FRAME_STATE.OPEN or FRAME_STATE.DEFAULT
			return manager:ProcessAction(shouldOpen and "ACTION_SHOW_FRAME" or "ACTION_SHOW_DEFAULT_UI", isIgnored)
		elseif state.frameState == FRAME_STATE.DEFAULT then
			if shouldOpen then
				Profession.SetScannerDisabled(false)
			end
			state.frameState = shouldOpen and FRAME_STATE.OPEN or FRAME_STATE.DEFAULT
			return manager:ProcessAction(shouldOpen and "ACTION_SHOW_FRAME" or "ACTION_SHOW_DEFAULT_UI", isIgnored)
		elseif state.frameState == FRAME_STATE.OPEN then
			if isIgnored then
				state.switching = true
				manager:ProcessAction("ACTION_HIDE_FRAME")
				state.switching = false
				state.frameState = FRAME_STATE.DEFAULT
				manager:ProcessAction("ACTION_SHOW_DEFAULT_UI", true)
				return
			end
			state.switchShown = true
			assert(state.frame)
			state.frame:DrawTitleFrame()
		else
			error("Invalid frame state: "..tostring(state.frameState))
		end
	elseif action == "ACTION_DEFAULT_UI_FRAME_SHOW" then
		if state.frameState ~= FRAME_STATE.CLOSED then
			return
		end
		state.defaultUISwitchBtn = state.defaultUISwitchBtn or private.CreateDefaultUISwitchButton(state)
		state.defaultUIIgnored = false
		state.defaultUISwitchBtn:Draw()
	elseif action == "ACTION_DEFAULT_UI_BOOK_PAGE_CHANGED" then
		state.bookPageShown = TradeSkill.IsDefaultUIBookPageShown()
	elseif action == "ACTION_DEFAULT_UI_TRADE_SKILL_CLOSE" then
		state.tradeSkillOpen = false
		if not state.craftOpen then
			return manager:ProcessAction("ACTION_CLOSE")
		end
	elseif action == "ACTION_DEFAULT_UI_CRAFT_CLOSE" then
		state.craftOpen = false
		Profession.SetClassicCraftingOpen(false)
		if not state.tradeSkillOpen then
			return manager:ProcessAction("ACTION_CLOSE")
		end
	elseif action == "ACTION_FRAME_HIDE" then
		UIUtils.AnalyticsRecordClose("crafting")
		return manager:ProcessAction("ACTION_CLOSE")
	elseif action == "ACTION_CLOSE" then
		if state.frameState == FRAME_STATE.CLOSED or state.switching then
			return
		end
		local wasOpen = state.frameState == FRAME_STATE.OPEN
		state.frameState = FRAME_STATE.CLOSED
		TradeSkill.CloseUI(wasOpen)
		return manager:ProcessAction("ACTION_HIDE_FRAME")
	elseif action == "ACTION_SWITCH" then
		if private.IsDefaultUILocked() then
			return
		end
		state.showDefault = state.frameState == FRAME_STATE.OPEN
		if not state.showDefault then
			TradeSkill.SetDefaultFilters()
		end
		Profession.SetScannerDisabled(state.showDefault)
		state.switching = true
		assert(state.frameState == FRAME_STATE.OPEN or state.frameState == FRAME_STATE.DEFAULT)
		local wasOpen = state.frameState == FRAME_STATE.OPEN
		manager:ProcessAction("ACTION_HIDE_FRAME")
		state.frameState = wasOpen and FRAME_STATE.DEFAULT or FRAME_STATE.OPEN
		manager:ProcessAction(wasOpen and "ACTION_SHOW_DEFAULT_UI" or "ACTION_SHOW_FRAME")
		state.switching = false
	elseif action == "ACTION_TOGGLE" then
		if state.frameState == FRAME_STATE.OPEN then
			Profession.SetScannerDisabled(false)
			return manager:ProcessAction("ACTION_CLOSE")
		elseif private.IsDefaultUILocked() then
			ChatMessage.PrintUser(L["The TSM Crafting UI can't be opened while in combat."])
			return
		elseif state.frameState == FRAME_STATE.CLOSED then
			Profession.SetScannerDisabled(false)
			state.showDefault = false
			state.frameState = FRAME_STATE.OPEN
			return manager:ProcessAction("ACTION_SHOW_FRAME")
		elseif state.frameState == FRAME_STATE.DEFAULT then
			return manager:ProcessAction("ACTION_SWITCH")
		else
			error("Invalid frame state: "..tostring(state.frameState))
		end
	elseif action == "ACTION_ON_LOGOUT" then
		if state.frameState ~= FRAME_STATE.OPEN then
			return
		end
		return manager:ProcessAction("ACTION_CLOSE")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param frame? LargeApplicationFrame
function private.CallAPICallbacks(frame)
	private.apiCallbacks:CallAll(frame and true or false, frame and frame:_GetBaseFrame() or nil)
end

function private.HandleLogout()
	private.manager:ProcessAction("ACTION_ON_LOGOUT")
	return true
end

function private.IsDefaultUILocked()
	return Move.IsDefaultUILocked(TradeSkill.GetVisibleDefaultFrame(false))
end

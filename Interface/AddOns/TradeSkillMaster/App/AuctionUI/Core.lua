-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local AuctionUI = App:Init("AuctionUI")
local Auctioning = App:Include("AuctionUI.Auctioning")
local MyAuctions = App:Include("AuctionUI.MyAuctions")
local Shopping = App:Include("AuctionUI.Shopping")
local Sniper = App:Include("AuctionUI.Sniper")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local AuctionScan = App:From("LibTSMService"):Include("AuctionScan")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local AuctionHouse = App:From("LibTSMWoW"):Include("API.AuctionHouse")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local DefaultUI = App:From("LibTSMWoW"):Include("UI.DefaultUI")
local SoundAlert = App:From("LibTSMWoW"):Include("UI.SoundAlert")
local SessionInfo = App:From("LibTSMWoW"):Include("Util.SessionInfo")
local ItemLinked = App:From("LibTSMUI"):Include("Util.ItemLinked")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local TaskList = App:From("LibTSMApp"):Include("TaskList")
local WhatsNew = App:From("LibTSMApp"):Include("UI.WhatsNew")
local private = {
	settings = nil,
	manager = nil,
	isVisible = false,
	lastItemLinkedResult = nil,
}
local MIN_FRAME_SIZE = { width = 750, height = 450 }
local AH_TAB_ID = "TSM_AH_TAB"
---@type {name: string, callback: (fun(): Container), itemLinkedHandler: (fun(name: string, itemLink: string): boolean, string?)}[]
local PAGE_INFO = {
	{ name = L["Browse"], callback = Shopping.GetFrame, itemLinkedHandler = Shopping.HandleItemLinked },
	{ name = L["Auctioning"], callback = Auctioning.GetFrame, itemLinkedHandler = Auctioning.HandleItemLinked },
	{ name = L["Sniper"], callback = Sniper.GetFrame, itemLinkedHandler = Sniper.HandleItemLinked },
	{ name = L["My Auctions"], callback = MyAuctions.GetFrame, itemLinkedHandler = MyAuctions.HandleItemLinked },
}
local STATE_SCHEMA = Reactive.CreateStateSchema("AuctionUIState")
	:AddOptionalUIElementField("frame", "LargeApplicationFrame")
	:AddBooleanField("hasShown", false)
	:AddBooleanField("isSwitching", false)
	:AddBooleanField("showDefault", false)
	:Commit()

---@class DefaultUIAHFrame: Frame
---@field numTabs number
---@field SetDisplayMode fun(self: DefaultUIAHFrame, mode: any)

---@event AuctionUICoreAction
---| "ACTION_INIT_FRAME"
---| "ACTION_HANDLE_TAB_CLICK"
---| "ACTION_SHOW_FRAME"
---| "ACTION_HANDLE_AH_HIDDEN"
---| "ACTION_HIDE_FRAME"
---| "ACTION_SWITCH"
---| "ACTION_HANDLE_FRAME_HIDE"
---| "ACTION_HANDLE_LOCK_CALLBACK" -> name?: string
---| "ACTION_HANDLE_ITEM_LINKED" -> name: string, itemLink: string
---| "ACTION_ON_LOGOUT"



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctionUI:OnModuleLoad(function()
	UIUtils.RegisterUIForAnalytics("auction")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("AUCTION", state, private.ActionHandler)
		:AddFrameBuilder(private.CreateMainFrame)

	-- Mirror the isVisible state
	private.isVisible = false -- Explicitly set private.isVisible at least once to appease the linter
	private.manager:AddCancellable(state:Publisher("frame")
		:ToBooleanNotEquals(nil)
		:AssignToTableKey(private, "isVisible")
	)

	local scanLockErrorMsg = L["A scan is already in progress. Please stop that scan before starting another one."]
	AuctionScan.ConfigureLock(scanLockErrorMsg, private.manager:CallbackToProcessAction("ACTION_HANDLE_LOCK_CALLBACK"))
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)

AddonSettings.RegisterOnLoad(AuctionUI, function(db)
	private.settings = db:NewView("AuctionUISettings")
		:AddKey("global", "auctionUIContext", "showDefault")
		:AddKey("global", "auctionUIContext", "frame")
		:AddKey("global", "coreOptions", "protectAuctionHouse")
		:Commit()

	-- Mirror the showDefault state to the settings
	private.manager:MirrorStateWithTable("showDefault", private.settings, "showDefault")

	-- Register for events / UI visibility callbacks
	AuctionHouse.UnregisterDefaultShowEvent()
	AuctionHouse.UnregisterDefaultUINotificationEvents()
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.manager:CallbackToProcessAction("ACTION_INIT_FRAME"), true)
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.manager:CallbackToProcessAction("ACTION_HANDLE_AH_HIDDEN"), false)
	local function ItemLinkedHandler(name, itemLink)
		private.manager:ProcessAction("ACTION_HANDLE_ITEM_LINKED", name, itemLink)
		return private.lastItemLinkedResult
	end
	ItemLinked.RegisterCallback(ItemLinkedHandler, true)

	-- Load the Blizzard UI after a delay
	local loadTimer = DelayTimer.New("AUCTION_UI_LOAD_BLIZZ", function() AuctionHouse.LoadAddon() end)
	loadTimer:RunForTime(1)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function AuctionUI.IsVisible()
	return private.isVisible
end



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state AuctionUIState
function private.CreateMainFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction")
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:BindElement(state, "frame")
		:AddPlayerGold()
		:AddAppStatusIcon()
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetProtected((App.IsVanillaClassic() or App.IsBCClassic()) and private.settings.protectAuctionHouse)
		:AddSwitchButton()
		:SetManager(private.manager)
		:SetAction("OnSwitchButtonClick", "ACTION_SWITCH")
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDE"))
	for _, info in ipairs(PAGE_INFO) do
		frame:AddNavButton(info.name, info.callback)
	end
	WhatsNew.ShowDialog(frame)
	frame:Show()
	frame:Draw()
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<AuctionUIState>
---@param state AuctionUIState
---@param action AuctionUICoreAction
---@param ... params<AuctionUICoreAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_INIT_FRAME" then
		if SessionInfo.IsLimited() then
			return
		end
		if not state.hasShown then
			state.hasShown = true
			AuctionHouse.AddTab(AH_TAB_ID, Theme.GetColor("accent/main"):ColorText("TSM"), manager:CallbackToProcessAction("ACTION_HANDLE_TAB_CLICK"))
		end
		if state.showDefault then
			if App.IsVanillaClassic() or App.IsBCClassic() then
				AuctionHouse.ShowDefaultUI()
			end
		else
			if not App.IsVanillaClassic() and not App.IsBCClassic() then
				AuctionHouse.SetSelectedTab(AH_TAB_ID)
			end
			SoundAlert.Play("AuctionWindowOpen", true, true)
			return manager:ProcessAction("ACTION_SHOW_FRAME")
		end
	elseif action == "ACTION_HANDLE_TAB_CLICK" then
		state.showDefault = false
		return manager:ProcessAction("ACTION_SHOW_FRAME")
	elseif action == "ACTION_SHOW_FRAME" then
		if state.frame then
			return
		end
		manager:BuildFrame()
		TaskList.HandleShoppingTaskUIUpdate()
	elseif action == "ACTION_HANDLE_AH_HIDDEN" then
		if not state.frame then
			return
		end
		AuctionHouse.RestoreDefaultUI()
		return manager:ProcessAction("ACTION_HIDE_FRAME")
	elseif action == "ACTION_HIDE_FRAME" then
		if not state.frame then
			return
		end
		state.frame:Hide()
		-- For some reason, on retail the OnHide callback isn't called immediately
		if App.IsVanillaClassic() or App.IsBCClassic() then
			assert(not state.frame)
		end
		TaskList.HandleShoppingTaskUIUpdate()
	elseif action == "ACTION_SWITCH" then
		state.isSwitching = true
		state.showDefault = true
		manager:ProcessAction("ACTION_HIDE_FRAME")
		AuctionHouse.RestoreDefaultUI()
		AuctionHouse.ShowDefaultUI()
		state.isSwitching = false
	elseif action == "ACTION_HANDLE_FRAME_HIDE" then
		assert(state.frame)
		state.frame:Release()
		if not state.isSwitching then
			SoundAlert.Play("AuctionWindowClose", true, true)
			AuctionHouse.Close()
		end
		UIUtils.AnalyticsRecordClose("auction")
	elseif action == "ACTION_HANDLE_LOCK_CALLBACK" then
		local name = ...
		if state.frame then
			state.frame:SetPulsingNavButton(name)
		end
		TaskList.HandleShoppingTaskUIUpdate()
		TaskList.SetShoppingTaskIsScanning(name and true or false)
	elseif action == "ACTION_HANDLE_ITEM_LINKED" then
		local name, itemLink = ...
		if not state.frame then
			private.lastItemLinkedResult = nil
			return
		end
		local info = private.GetPageInfo(state.frame:GetSelectedNavButton())
		local handled, otherPage = info.itemLinkedHandler(name, itemLink)
		if not handled then
			private.lastItemLinkedResult = nil
			return
		end
		if otherPage then
			state.frame:SetSelectedNavButton(otherPage, true)
			info = private.GetPageInfo(otherPage)
			handled, otherPage = info.itemLinkedHandler(name, itemLink)
			assert(handled and not otherPage)
		end
		private.lastItemLinkedResult = true
	elseif action == "ACTION_ON_LOGOUT" then
		if state.frame then
			-- Hide the frame
			state.frame:Hide()
			assert(not state.frame)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogout()
	private.manager:ProcessAction("ACTION_ON_LOGOUT")
	return true
end

function private.GetPageInfo(name)
	for _, info in ipairs(PAGE_INFO) do
		if info.name == name then
			return info
		end
	end
	error("Invalid frame path")
end

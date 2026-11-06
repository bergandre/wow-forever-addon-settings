-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local BankingUI = App:Init("BankingUI")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local Group = App:From("LibTSMTypes"):Include("Group")
local GroupOperation = App:From("LibTSMTypes"):Include("GroupOperation")
local Container = App:From("LibTSMWoW"):Include("API.Container")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local Banking = App:From("LibTSMService"):Include("Banking")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local BankingApp = App:From("LibTSMApp"):Include("Banking")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SlashCommands = App:From("LibTSMApp"):Include("Service.SlashCommands")
local private = {
	settings = nil,
	manager = nil,
	autoDepositDelay = nil,
	groupsTemp = {},
}
local MIN_FRAME_SIZE = { width = 325, height = 600 }
local TAB_ORDER = {
	EnumTypes.BANKING_TAB.WAREHOUSING,
	EnumTypes.BANKING_TAB.AUCTIONING,
	EnumTypes.BANKING_TAB.MAILING,
}
local TAB_INFO = {
	[EnumTypes.BANKING_TAB.WAREHOUSING] = {
		moduleName = "Warehousing",
		text = L["Warehousing"],
		groupTreeContextKey = "warehousingGroupTree",
	},
	[EnumTypes.BANKING_TAB.AUCTIONING] = {
		moduleName = "Auctioning",
		text = L["Auctioning"],
		groupTreeContextKey = "auctioningGroupTree",
	},
	[EnumTypes.BANKING_TAB.MAILING] = {
		moduleName = "Mailing",
		text = L["Mailing"],
		groupTreeContextKey = "mailingGroupTree",
	},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("BankingUIState")
	:AddDeferredUIElementField("frame", "ApplicationFrame")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddBooleanField("isOpen", false)
	:AddOptionalEnumField("openBankFrame", Banking.FRAME)
	:AddEnumField("tab", EnumTypes.BANKING_TAB, EnumTypes.BANKING_TAB.WAREHOUSING)
	:AddBooleanField("isWarbank", false)
	:AddNumberField("progress", 0)
	:AddOptionalEnumField("activeMove", EnumTypes.BANKING_MOVE_TYPE)
	:Commit()

---@event BankingUIAction
---| "ACTION_TOGGLE"
---| "ACTION_SHOW_FRAME"
---| "ACTION_HIDE_FRAME"
---| "ACTION_HANDLE_CLOSE_CLICKED"
---| "ACTION_ON_DISABLE"
---| "ACTION_HANDLE_BANKING_FRAME_CALLBACK" -> openFrame?: EnumValue
---| "ACTION_START_MOVE" -> moveType: EnumValue
---| "ACTION_HANDLE_PROGRESS" -> progress: number
---| "ACTION_HANDLE_DONE"
---| "ACTION_HANDLE_AUTO_DEPOSIT_DONE"
---| "ACTION_GET" -> filterStr: string
---| "ACTION_PUT" -> filterStr: string



-- ============================================================================
-- Module Loading
-- ============================================================================

BankingUI:OnModuleLoad(function()
	UIUtils.RegisterUIForAnalytics("banking")
end)

AddonSettings.RegisterOnLoad(BankingUI, function(db)
	private.settings = db:NewView("BankingUISettings")
		:AddKey("global", "bankingUIContext", "frame")
		:AddKey("global", "bankingUIContext", "isOpen")
		:AddKey("global", "bankingUIContext", "tab")
		:AddKey("char", "bankingUIContext", "warehousingGroupTree")
		:AddKey("char", "bankingUIContext", "auctioningGroupTree")
		:AddKey("char", "bankingUIContext", "mailingGroupTree")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("BANKING", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_PROGRESS")

	-- Mirror isOpen / tab between the state and the settings
	private.manager:MirrorStateWithTable("isOpen", private.settings, "isOpen")
	for tab, info in pairs(TAB_INFO) do
		if info.moduleName == private.settings.tab then
			state.tab = tab
			break
		end
	end
	private.manager:AddCancellable(state:Publisher("tab")
		:Map(TAB_INFO)
		:Map("moduleName")
		:AssignToTableKey(private.settings, "tab")
	)

	-- Register banking frame callback
	Banking.RegisterFrameCallback(private.manager:CallbackToProcessAction("ACTION_HANDLE_BANKING_FRAME_CALLBACK"))
	private.manager:SetStateFromPublisher("isWarbank", state:Publisher("openBankFrame")
		:ToBooleanEquals(Banking.FRAME.CONTAINER.WARBANK)
	)

	-- Create auto deposit delay
	private.autoDepositDelay = DelayTimer.New("BANKING_AUTO_DEPOSIT", private.manager:CallbackToProcessAction("ACTION_HANDLE_AUTO_DEPOSIT_DONE"))

	-- Register slash commands
	SlashCommands.Register("bankui", private.manager:CallbackToProcessAction("ACTION_TOGGLE"), L["Toggles the TSM Banking UI if either the bank or guild bank is currently open."])
	SlashCommands.Register("get", private.manager:CallbackToProcessAction("ACTION_GET"), L["Gets items from the bank or guild bank matching the item or partial text entered."])
	SlashCommands.Register("put", private.manager:CallbackToProcessAction("ACTION_PUT"), L["Puts items matching the item or partial text entered into the bank or guild bank."])

	-- Close the frame on logout
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state BankingUIState
function private.CreateMainFrame(state)
	UIUtils.AnalyticsRecordPathChange("banking")
	local tabGroup = UIElements.New("SegmentedTabGroup", "tabs")
		:SetContext(state)
		:SetTabsDisabled(state:Publisher("activeMove"):ToBooleanNotEquals(nil):IgnoreDuplicates())
		:SetNavCallback(private.GetTabContent)
	for _, tab in ipairs(TAB_ORDER) do
		tabGroup:AddPath(TAB_INFO[tab].text, tab == state.tab)
	end
	return UIElements.New("ApplicationFrame", "base")
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetTitle(state:Publisher("isWarbank"):ReplaceBooleanWith(L["Banking"].." - "..L["Warbank"], L["Banking"].." - "..GlobalStrings.Get("BANK")))
		:OverrideCloseAction("ACTION_HANDLE_CLOSE_CLICKED", private.manager)
		:SetManager(private.manager)
		:SetContentFrame(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetPadding(4)
			:AddChild(tabGroup)
		)
end

function private.GetTabContent(tabGroup, path)
	local state = tabGroup:GetContext() ---@type BankingUIState
	for _, tab in ipairs(TAB_ORDER) do
		if TAB_INFO[tab].text == path then
			state.tab = tab
		end
	end
	local info = TAB_INFO[state.tab]
	local activeMovePublisher = state:Publisher("activeMove")
		:ToBooleanNotEquals(nil)
		:IgnoreDuplicates()
		:Share()
	return UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
			:SetTreeBackgroundColor("surface/main")
			:BindElement(state, "groupTree")
			:SetSettingsContext(private.settings, info.groupTreeContextKey)
			:SetOperationType(info.moduleName)
		)
		:AddChild(UIElements.New("ProgressBar", "progressBar")
			:SetHeight(28)
			:SetMargin(0, 0, 12, 0)
			:SetProgress(state:Publisher("progress"))
			:SetProgressIconHidden(activeMovePublisher:InvertBoolean())
			:SetText(activeMovePublisher:ReplaceBooleanWith(L["Moving"], L["Select Action"]))
		)
		:AddChild(UIElements.New("BankingButtonsFrame", "buttons")
			:SetAction("OnButtonClick", "ACTION_START_MOVE")
			:SetPath(info.moduleName)
		)
		:AddCancellable(activeMovePublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<BankingUIState>
---@param state BankingUIState
---@param action BankingUIAction
---@param ... params<BankingUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE" then
		if not state.openBankFrame then
			return
		end
		state.isOpen = not state.isOpen
		return manager:ProcessAction(state.isOpen and "ACTION_SHOW_FRAME" or "ACTION_HIDE_FRAME")
	elseif action == "ACTION_SHOW_FRAME" then
		assert(not state.frame)
		state.frame = private.CreateMainFrame(state)
		state.frame:Show()
		state.frame:Draw()
	elseif action == "ACTION_HIDE_FRAME" then
		assert(state.frame)
		UIUtils.AnalyticsRecordClose("banking")
		state.frame:Hide()
		state.frame:Release()
		state.frame = nil
		state.progress = 0
		state.activeMove = nil
	elseif action == "ACTION_HANDLE_CLOSE_CLICKED" then
		state.isOpen = false
		ChatMessage.PrintUser(L["Hiding the Banking UI. Type '/tsm bankui' to reopen it."])
		return manager:ProcessAction("ACTION_HIDE_FRAME")
	elseif action == "ACTION_ON_DISABLE" then
		if state.frame then
			return manager:ProcessAction("ACTION_HIDE_FRAME")
		end
	elseif action == "ACTION_HANDLE_BANKING_FRAME_CALLBACK" then
		local openFrame = ...
		state.openBankFrame = openFrame
		if not state.isOpen then
			return
		elseif not openFrame == not state.frame then
			-- Our frame is already shown / hidden
			return
		end
		return manager:ProcessAction(openFrame and "ACTION_SHOW_FRAME" or "ACTION_HIDE_FRAME")
	elseif action == "ACTION_START_MOVE" then
		local moveType = ...
		assert(state.groupTree)
		assert(not next(private.groupsTemp))
		for _, groupPath in state.groupTree:SelectedGroupsIterator() do
			if groupPath ~= Group.GetRootPath() or GroupOperation.HasAnyNonIgnoredOperation(groupPath, TAB_INFO[state.tab].moduleName) then
				private.groupsTemp[groupPath] = true
			end
		end
		state.activeMove = moveType
		state.progress = 0
		private.StartMove(moveType, private.groupsTemp)
		Table.WipeAndDeallocate(private.groupsTemp)
	elseif action == "ACTION_HANDLE_PROGRESS" then
		if not state.activeMove then
			return
		end
		local progress = ...
		state.progress = progress
	elseif action == "ACTION_HANDLE_DONE" then
		if not state.activeMove then
			return
		end
		if state.progress == 0 then
			ChatMessage.PrintUser(L["Nothing to move."])
		end
		state.progress = 0
		state.activeMove = nil
	elseif action == "ACTION_HANDLE_AUTO_DEPOSIT_DONE" then
		if not state.activeMove then
			return
		end
		state.progress = 1
		return manager:ProcessAction("ACTION_HANDLE_DONE")
	elseif action == "ACTION_GET" then
		local filterStr = ...
		if not state.openBankFrame then
			ChatMessage.PrintUser(L["No bank frame is open."])
			return
		end
		Banking.GetByFilter(filterStr, private.GetPutCallback)
	elseif action == "ACTION_PUT" then
		local filterStr = ...
		if not state.openBankFrame then
			ChatMessage.PrintUser(L["No bank frame is open."])
			return
		end
		Banking.PutByFilter(filterStr, private.GetPutCallback)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogout()
	private.manager:ProcessAction("ACTION_ON_DISABLE")
	return true
end

function private.StartMove(moveType, groups)
	if moveType == EnumTypes.BANKING_MOVE_TYPE.EMPTY_BAGS then
		Banking.EmptyBags(private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.RESTORE_BAGS then
		Banking.RestoreBags(private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.GROUPS_TO_BANK then
		BankingApp.MoveGroupsToBank(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.AUCTIONING_POST_CAP_TO_BAGS then
		BankingApp.MoveAuctioningPostCapToBags(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.AUCTIONING_SHORTFALL_TO_BAGS then
		BankingApp.MoveAuctioningShortfallToBags(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.AUCTIONING_MAX_EXPIRES_TO_BANK then
		BankingApp.MoveAuctioningMaxExpiresToBank(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.MAILING_NON_GROUP_TO_BANK then
		BankingApp.MoveMailingNonGroupToBank(private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.MAILING_TARGET_SHORTFALL_TO_BAGS then
		BankingApp.MoveMailingTargetShortfallToBags(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_GROUPS_TO_BANK then
		BankingApp.MoveWarehousingGroupsToBank(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_GROUPS_TO_BAGS then
		BankingApp.MoveWarehousingGroupsToBags(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_RESTOCK_BAGS then
		BankingApp.MoveWarehousingRestockBags(groups, private.MoveCallback)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_DEPOSIT_REAGENTS then
		Container.AutoDepositReagentBank()
		private.autoDepositDelay:RunForTime(1)
	elseif moveType == EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_DEPOSIT_WARBOUND then
		Container.AutoDepositWarbank()
		private.autoDepositDelay:RunForTime(1)
	else
		error("Unknown move type: "..tostring(moveType))
	end
end

function private.MoveCallback(event, ...)
	if event == "PROGRESS" then
		private.manager:ProcessAction("ACTION_HANDLE_PROGRESS", ...)
	elseif event == "DONE" then
		private.manager:ProcessAction("ACTION_HANDLE_DONE")
	elseif event == "MOVED" then
		-- Ignore this event
	else
		error("Unexpected event: "..tostring(event))
	end
end

function private.GetPutCallback(event)
	if event == "DONE" then
		ChatMessage.PrintUser(GlobalStrings.Get("DONE"))
	end
end

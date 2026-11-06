-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local DestroyingUI = App:Init("DestroyingUI")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Macro = App:From("LibTSMWoW"):Include("API.Macro")
local CombatLockdown = App:From("LibTSMWoW"):Include("Service.CombatLockdown")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Destroying = App:From("LibTSMApp"):Include("Destroying")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SlashCommands = App:From("LibTSMApp"):Include("Service.SlashCommands")
local private = {
	manager = nil,
	settings = nil, ---@type SettingsView
	query = nil, ---@type DatabaseQuery
}
local MIN_FRAME_SIZE = { width = 280, height = 280 }
local STATE_SCHEMA = Reactive.CreateStateSchema("DestroyingUIState")
	:AddDeferredUIElementField("frame", "ApplicationFrame")
	:AddDeferredUIElementField("scrollTable", "DestroyingScrollTable")
	:AddOptionalClassField("combineFuture", "Future")
	:AddOptionalClassField("destroyFuture", "Future")
	:AddOptionalStringField("itemString")
	:AddBooleanField("canCombine", false)
	:AddBooleanField("canDestroy", false)
	:AddBooleanField("autoShow", false)
	:AddBooleanField("autoCombine", false)
	:AddBooleanField("didAutoShow", false)
	:AddBooleanField("canCombineOrDestroy", false)
	:AddBooleanField("combatLockdown", false)
	:Commit()

---@event DestroyingUIAction
---| "ACTION_FRAME_SHOW"
---| "ACTION_FRAME_ON_HIDE"
---| "ACTION_COMBINE_START"
---| "ACTION_DESTROY_START" -> prepareFunc: DestroyNextButtonPrepareFunc
---| "ACTION_TOGGLE"
---| "ACTION_ON_DISABLE"
---| "ACTION_CAN_NOT_COMBINE_OR_DESTROY"
---| "ACTION_CAN_COMBINE_OR_DESTROY"
---| "ACTION_ITEM_SELECTION_CHANGED"
---| "ACTION_HIDE_ITEM" -> itemString: string, isPermanent: boolean



-- ============================================================================
-- Module Loading
-- ============================================================================

DestroyingUI:OnModuleLoad(function()
	UIUtils.RegisterUIForAnalytics("destroying")
end)

AddonSettings.RegisterOnLoad(DestroyingUI, function(db)
	private.settings = db:NewView("DestroyingUISettings")
		:AddKey("global", "destroyingUIContext", "frame")
		:AddKey("global", "destroyingUIContext", "itemsScrollingTable")
		:AddKey("global", "destroyingOptions", "autoShow")
		:AddKey("global", "destroyingOptions", "autoStack")
		:Commit()
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
end)



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state DestroyingUIState
function private.CreateMainFrame(state)
	local inCombatPublisher = state:Publisher("combatLockdown")
		:Share()
	local itemStringPublisher = state:Publisher("itemString")
		:Share()
	local isCombiningPublisher = state:Publisher("combineFuture")
		:ToBooleanNotEquals(nil)
		:IgnoreDuplicates()
		:Share()
	local isDestroyingPublisher = state:Publisher("destroyFuture")
		:ToBooleanNotEquals(nil)
		:IgnoreDuplicates()
		:Share()
	return UIElements.New("ApplicationFrame", "base")
		:SetManager(private.manager)
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetTitle(L["Destroying"])
		:SetProtected(inCombatPublisher)
		:SetCloseDisabled(inCombatPublisher)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_FRAME_ON_HIDE"))
		:SetContentFrame(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetPadding(4)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("BaseButton", "icon")
					:SetSize(16, 16)
					:SetMargin(0, 4, 0, 0)
					:SetBackground(itemStringPublisher:IgnoreNil():Map(ItemInfo.GetTexture))
					:SetTooltip(itemStringPublisher)
				)
				:AddChild(UIElements.New("Text", "name")
					:SetFont("ITEM_BODY1")
					:SetText(itemStringPublisher:MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil("?"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "results")
				:SetLayout("VERTICAL")
				:SetHeight(58)
				:SetMargin(0, 0, 8, 0)
				:SetPadding(8)
				:SetRoundedBackgroundColor("container/medium")
				:SetBorderColor("outline/variant")
				:AddChild(UIElements.New("DestroyingResultsList", "scroll")
					:SetBackgroundColor("container/medium")
					:SetItemString(state:Publisher("itemString"):IgnoreNil())
				)
			)
			:AddChild(UIElements.New("ListContainer", "items")
				:SetMargin(0, 0, 8, 0)
				:AddChild(UIElements.New("DestroyingScrollTable", "table")
					:SetSettings(private.settings, "itemsScrollingTable")
					:SetQuery(private.query)
					:BindElement(state, "scrollTable")
					:SetAction("OnSelectionChanged", "ACTION_ITEM_SELECTION_CHANGED")
					:SetAction("OnHideIconClick", "ACTION_HIDE_ITEM")
				)
			)
			:AddChildIf(not App.IsRetail() and not App.IsForever(), UIElements.New("MediumPrimaryActionButton", "combineBtn")
				:SetMargin(0, 0, 8, 0)
				:SetText(isCombiningPublisher:ReplaceBooleanWith(L["Combining..."], L["Combine Partial Stacks"]))
				:SetDisabled(state:Publisher([[(combineFuture or destroyFuture) and true or not canCombine or combatLockdown]]))
				:SetPressed(isCombiningPublisher)
				:SetAction("OnClick", "ACTION_COMBINE_START")
			)
			:AddChild(UIElements.NewNamed("DestroyNextButton", "destroyBtn", "TSMDestroyBtn")
				:SetMargin(0, 0, 8, 0)
				:SetText(isDestroyingPublisher:ReplaceBooleanWith(L["Destroying..."], L["Destroy Next"]))
				:SetPressed(isDestroyingPublisher)
				:SetDisabled(state:Publisher([[(combineFuture or destroyFuture) and true or not canDestroy or combatLockdown]]))
				:SetAction("OnStart", "ACTION_DESTROY_START")
			)
		)
		:AddCancellable(inCombatPublisher:EndShare())
		:AddCancellable(itemStringPublisher:EndShare())
		:AddCancellable(isCombiningPublisher:EndShare())
		:AddCancellable(isDestroyingPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<DestroyingUIState>
---@param state DestroyingUIState
---@param action DestroyingUIAction
---@param ... params<DestroyingUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW" then
		assert(not state.frame and state.canCombineOrDestroy)
		UIUtils.AnalyticsRecordPathChange("destroying")
		state.didAutoShow = true
		state.frame = private.CreateMainFrame(state)
		Macro.UpdateBindingClickTarget("TSMDestroyBtn")
		state.frame:Show()
		state.frame:Draw()
		manager:ProcessAction("ACTION_ITEM_SELECTION_CHANGED")
		if state.autoCombine then
			-- We should auto-combine first
			manager:ProcessAction("ACTION_COMBINE_START")
		end
	elseif action == "ACTION_FRAME_ON_HIDE" then
		UIUtils.AnalyticsRecordClose("destroying")
		if state.combineFuture then
			manager:CancelFuture("combineFuture")
		end
		if state.destroyFuture then
			manager:CancelFuture("destroyFuture")
		end
		state.frame:Hide()
		state.frame:Release()
		state.frame = nil
	elseif action == "ACTION_COMBINE_START" then
		local future = Destroying.StartCombine()
		-- Don't care about the result of the future
		manager:ManageFuture("combineFuture", future)
	elseif action == "ACTION_DESTROY_START" then
		local prepareFunc = ...
		local item, quantity = state.scrollTable:GetSelection()
		assert(item and quantity)
		local future = Destroying.StartDestroy(prepareFunc, item, quantity)
		-- Don't care about the result of the future
		manager:ManageFuture("destroyFuture", future)
	elseif action == "ACTION_TOGGLE" then
		if state.combatLockdown then
			return
		end
		if state.frame then
			state.frame:Hide()
		elseif state.canCombineOrDestroy then
			return manager:ProcessAction("ACTION_FRAME_SHOW")
		else
			ChatMessage.PrintUser(L["There is nothing in your inventory to destroy which matches your settings."])
		end
	elseif action == "ACTION_ON_DISABLE" or action == "ACTION_CAN_NOT_COMBINE_OR_DESTROY" then
		if state.frame then
			state.frame:Hide()
		end
	elseif action == "ACTION_CAN_COMBINE_OR_DESTROY" then
		if not state.frame then
			return manager:ProcessAction("ACTION_FRAME_SHOW")
		end
	elseif action == "ACTION_ITEM_SELECTION_CHANGED" then
		local itemString = state.scrollTable:GetSelection()
		if not itemString then
			-- Just select the first row
			return state.scrollTable:SelectFirstItem()
		end
		state.itemString = itemString
	elseif action == "ACTION_HIDE_ITEM" then
		local itemString, isPermanent = ...
		if isPermanent then
			ChatMessage.PrintfUser(L["Destroying will ignore %s permanently. You can remove it from the ignored list in the settings."], ItemInfo.GetName(itemString) or "?")
			Destroying.IgnoreItemPermanent(itemString)
		else
			ChatMessage.PrintfUser(L["Destroying will ignore %s until you log out."], ItemInfo.GetName(itemString) or "?")
			Destroying.IgnoreItemSession(itemString)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("DESTROYING", state, private.ActionHandler)

	-- Set up some computed state properties
	private.manager:SetStateFromExpression("canCombineOrDestroy", [[canCombine or canDestroy]])

	-- Set up publisher to set state.canCombine
	private.manager:SetStateFromPublisher("canCombine", Destroying.CanCombinePublisher())

	-- Create query and setup publisher for state.canDestroy
	private.query = Destroying.CreateBagQuery()
	private.manager:SetStateFromPublisher("canDestroy", private.query:Publisher()
		:Map("Count()")
		:ToBooleanNotEquals(0)
	)

	-- Set up publishers to set state.autoShow/autoCombine from settings
	private.manager:SetStateFromPublisher("autoCombine", private.settings:PublisherForKey("autoStack"))
	private.manager:SetStateFromPublisher("autoShow", private.settings:PublisherForKey("autoShow"))

	-- Publisher for when we have something to combine/destroy
	private.manager:ProcessActionFromPublisher("ACTION_CAN_COMBINE_OR_DESTROY", state:Publisher([[autoShow and not didAutoShow and canCombineOrDestroy]])
		:IgnoreIfNotEquals(true)
	)

	-- Publisher for when we don't have anything to combine/destroy
	private.manager:ProcessActionFromPublisher("ACTION_CAN_NOT_COMBINE_OR_DESTROY", state:Publisher("canCombineOrDestroy")
		:IgnoreIfNotEquals(false)
	)

	-- Handle combat lockdown changes
	private.manager:SetStateFromPublisher("combatLockdown", CombatLockdown.GetPublisher())

	-- Register the slash command to toggle the UI
	SlashCommands.Register("destroy", private.manager:CallbackToProcessAction("ACTION_TOGGLE"), L["Opens the Destroying frame if there are items in your bags to be destroyed."])

	-- Close the frame on logout
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)

	return true
end

function private.HandleLogout()
	private.manager:ProcessAction("ACTION_ON_DISABLE")
	return true
end

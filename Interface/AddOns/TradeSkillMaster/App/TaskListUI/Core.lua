-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local TaskListUI = App:Init("TaskListUI")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CombatLockdown = App:From("LibTSMWoW"):Include("Service.CombatLockdown")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SlashCommands = App:From("LibTSMApp"):Include("Service.SlashCommands")
local TaskList = App:From("LibTSMApp"):Include("TaskList")
local private = {
	settings = nil,
	manager = nil,
	isVisible = false,
	categoryCollapsed = {},
	taskCollapsed = {},
	categoryCountTemp = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("TaskListUIState")
	:AddDeferredUIElementField("frame", "OverlayApplicationFrame")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddBooleanField("isOpen", false)
	:AddBooleanField("backgroundLocked", false)
	:AddBooleanField("didAutoShow", false)
	:AddBooleanField("wasVisible", false)
	:Commit()

---@event TaskListUIAction
---| "ACTION_SHOW_FRAME"
---| "ACTION_HIDE_FRAME"
---| "ACTION_TOGGLE"
---| "ACTION_HANDLE_FRAME_HIDE"
---| "ACTION_HANDLE_CLOSE"
---| "ACTION_UPDATE_FRAME"
---| "ACTION_UPDATE_TASKS"
---| "ACTION_HANDLE_COMBAT_LOCKDOWN_CHANGE" -> inLockdown: boolean



-- ============================================================================
-- Module Loading
-- ============================================================================

TaskListUI:OnModuleLoad(function()
	UIUtils.RegisterUIForAnalytics("task_list")
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)

AddonSettings.RegisterOnLoad(TaskListUI, function(db)
	private.settings = db:NewView("TaskListUISettings")
		:AddKey("global", "taskListUIContext", "frame")
		:AddKey("global", "taskListUIContext", "isOpen")
		:AddKey("global", "appearanceOptions", "taskListBackgroundLock")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("TASK_LIST", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_TASKS")
		:SuppressActionLog("ACTION_UPDATE_FRAME")

	-- Set up publishers to set state.backgroundLocked from settings
	private.manager:SetStateFromPublisher("backgroundLocked", private.settings:PublisherForKey("taskListBackgroundLock"))

	-- Mirror the open state between the state and the settings
	private.manager:MirrorStateWithTable("isOpen", private.settings, "isOpen")

	private.isVisible = false -- Explicitly set private.isVisible at least once to appease the linter
	private.manager:AddCancellable(state:Publisher("frame"):ToBooleanNotEquals(nil):AssignToTableKey(private, "isVisible"))

	if not state.isOpen then
		state.didAutoShow = true
	end
	TaskList.SetUpdateCallback(private.manager:CallbackToProcessAction("ACTION_UPDATE_TASKS"))
	private.manager:ProcessAction("ACTION_UPDATE_TASKS")
	private.manager:ProcessActionFromPublisher("ACTION_HANDLE_COMBAT_LOCKDOWN_CHANGE", CombatLockdown.GetPublisher())
	SlashCommands.Register("tasklist", TaskListUI.Toggle, L["Toggles the TSM Task List UI"])
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Toggles the task list UI.
function TaskListUI.Toggle()
	private.manager:ProcessAction("ACTION_TOGGLE")
end

---Returns whether or not the task list UI is visible.
---@return boolean
function TaskListUI.IsVisible()
	return private.isVisible
end

---Gets a publisher for whether or not the task list UI is visible.
---@return ReactivePublisherSchema
function TaskListUI.IsVisiblePublisher()
	return private.manager:StatePublisherForKey("frame")
		:ToBooleanNotEquals(nil)
end

---Forces a redraw of the task list frame.
function TaskListUI.UpdateFrame()
	private.manager:ProcessAction("ACTION_UPDATE_FRAME")
end



-- ============================================================================
-- Task List UI
-- ============================================================================

---@param state TaskListUIState
function private.CreateMainFrame(state)
	UIUtils.AnalyticsRecordPathChange("task_list")
	return UIElements.New("OverlayApplicationFrame", "base")
		:SetWidth(307)
		:SetSettingsContext(private.settings, "frame")
		:SetTitle(L["TSM TASK LIST"])
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:SetBackgroundLocked(state:Publisher("backgroundLocked"))
		:SetContentFrame(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:BindElement(state, "contentFrame")
			:AddChildrenWithFunction(private.CreateTaskListElements)
		)
		:SetAction("OnClose", "ACTION_HANDLE_CLOSE")
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDE"))
end

function private.CreateTaskListElements(frame)
	-- Get all the category counts
	assert(not next(private.categoryCountTemp))
	for _, task in TaskList.Iterator() do
		local category = task:GetCategory()
		private.categoryCountTemp[category] = (private.categoryCountTemp[category] or 0) + 1
	end

	local currentCategoryFrame = nil
	local lastCategory = nil
	for _, task in TaskList.Iterator() do
		local category = task:GetCategory()
		local taskDesc = task:GetTaskDesc()
		-- Draw a category row if this is the first task for a category
		local isNewCategory = category ~= lastCategory
		if isNewCategory then
			local categoryFrame = UIElements.New("TaskListCategory", "category_"..category)
				:Configure(category, private.categoryCollapsed, private.categoryCountTemp[category])
			frame:AddChild(categoryFrame)
			currentCategoryFrame = categoryFrame
		end
		assert(currentCategoryFrame)
		lastCategory = category
		local taskElementType = (task:IsSecureMacro() and "TaskListSecureMacroTask") or (task:IsSecureSpell() and "TaskListSecureSpellTask") or "TaskListTask"
		currentCategoryFrame:AddCategoryChild(UIElements.New(taskElementType, "task_"..taskDesc)
			:Configure(task, private.taskCollapsed)
		)
	end

	wipe(private.categoryCountTemp)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<TaskListUIState>
---@param state TaskListUIState
---@param action TaskListUIAction
---@param ... params<TaskListUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_FRAME" then
		if TaskList.GetNumTasks() == 0 then
			ChatMessage.PrintUser(L["Your task list is currently empty."])
			return
		end
		state.isOpen = true
		state.frame = private.CreateMainFrame(state)
		state.frame:Show()
		state.frame:Draw()
	elseif action == "ACTION_HIDE_FRAME" then
		if not state.frame then
			return
		end
		state.frame:Hide()
		assert(not state.frame)
	elseif action == "ACTION_TOGGLE" then
		return manager:ProcessAction(state.frame and "ACTION_HIDE_FRAME" or "ACTION_SHOW_FRAME")
	elseif action == "ACTION_HANDLE_FRAME_HIDE" then
		state.frame:Release()
		UIUtils.AnalyticsRecordClose("task_list")
	elseif action == "ACTION_HANDLE_CLOSE" then
		ChatMessage.PrintUser(L["Hiding the TSM Task List UI. Type '/tsm tasklist' to reopen it."])
		state.isOpen = false
	elseif action == "ACTION_UPDATE_FRAME" then
		state.frame:Draw()
	elseif action == "ACTION_UPDATE_TASKS" then
		if state.frame then
			local numTasks = TaskList.GetNumTasks()
			if numTasks == 0 then
				state.didAutoShow = false
				return manager:ProcessAction("ACTION_HIDE_FRAME")
			end
			state.frame:SetTitle(L["TSM TASK LIST"].." ("..numTasks..")")
			-- Rebuild the content
			state.contentFrame
				:ReleaseAllChildren()
				:AddChildrenWithFunction(private.CreateTaskListElements)
			state.frame:Draw()
		elseif not state.didAutoShow and not CombatLockdown.IsActive() and TaskList.GetNumTasks() > 0 then
			state.didAutoShow = true
			return manager:ProcessAction("ACTION_SHOW_FRAME")
		end
	elseif action == "ACTION_HANDLE_COMBAT_LOCKDOWN_CHANGE" then
		local inLockdown = ...
		if inLockdown then
			state.wasVisible = state.frame ~= nil
			return manager:ProcessAction("ACTION_HIDE_FRAME")
		elseif state.wasVisible then
			return manager:ProcessAction("ACTION_SHOW_FRAME")
		else
			return manager:ProcessAction("ACTION_UPDATE_TASKS")
		end
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

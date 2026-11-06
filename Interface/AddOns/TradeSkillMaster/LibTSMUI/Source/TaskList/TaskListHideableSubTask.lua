-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Task = LibTSMUI:From("LibTSMTypes"):IncludeClassType("Task")



-- ============================================================================
-- Element Definition
-- ============================================================================

local TaskListHideableSubTask = ComponentRegistry.Define("TaskListHideableSubTask", "BaseFrame")
TaskListHideableSubTask._STATE_SCHEMA = TaskListHideableSubTask._STATE_SCHEMA:Extend("TaskListHideableSubTaskState")
	:AddDeferredClassField("task", Task)
	:AddNumberField("index", 0)
	:AddStringField("desc", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TaskListHideableSubTask:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function TaskListHideableSubTask:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseButton", "hideBtn")
			:SetManager(self._childManager)
			:SetBackgroundAndSize("iconPack.18x18/Visible")
			:SetAction("OnClick", "ACTION_HIDE")
		)
		self:AddChild(UIElements.New("Text", "text")
			:SetMargin(2, 0, 0, 0)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(self._state:Publisher("desc"))
		)
	end
end

---Configures the sub task line.
---@param task Task The task
---@param index number The sub task index
---@param desc string The sub task description
---@return self
function TaskListHideableSubTask:Configure(task, index, desc)
	assert(not self._state.task)
	self._state.task = task
	self._state.index = index
	self._state.desc = desc
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<TaskListHideableSubTaskState>
---@param state TaskListHideableSubTaskState
function TaskListHideableSubTask.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HIDE" then
		state.task:HideSubTask(state.index)
	else
		error("Unknown action: "..tostring(action))
	end
end

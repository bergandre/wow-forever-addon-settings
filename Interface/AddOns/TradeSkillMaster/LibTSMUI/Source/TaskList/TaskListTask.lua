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

local TaskListTask = ComponentRegistry.Define("TaskListTask", "BaseFrame")
TaskListTask._STATE_SCHEMA = TaskListTask._STATE_SCHEMA:Extend("TaskListTaskState")
	:AddDeferredUIElementField("childrenFrame", "BaseFrame")
	:AddDeferredClassField("task", Task)
	:AddBooleanField("expanded", true)
	:AddStringField("desc", "")
	:AddStringField("buttonText", "")
	:AddBooleanField("buttonDisabled", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TaskListTask:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function TaskListTask:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		local expandedPublisher = self._state:Publisher("expanded")
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(26)
			:SetPadding(18, 8, 0, 0)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseButton", "expanderBtn")
				:SetShown(self._state:Publisher("task"):IgnoreNil():Map("HasSubTasks()"))
				:SetBackgroundAndSize(expandedPublisher:ReplaceBooleanWith("iconPack.18x18/Caret/Down", "iconPack.18x18/Caret/Right"))
				:SetAction("OnClick", "ACTION_EXPANDER_CLICK")
			)
			:AddChild(UIElements.New("Text", "desc")
				:SetMargin(2, 4, 0, 0)
				:SetFont("ITEM_BODY1")
				:SetTextColor("accent/main")
				:SetText(self._state:Publisher("desc"))
			)
			:AddChild(self:_CreateTaskButton()
				:SetWidth(80)
				:SetText(self._state:Publisher("buttonText"))
				:SetDisabled(self._state:Publisher("buttonDisabled"))
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "children")
			:SetLayout("VERTICAL")
			:BindElement(self._state, "childrenFrame")
			:SetManager(self._childManager)
			:SetShown(expandedPublisher)
		)
		self:AddCancellable(expandedPublisher:EndShare())
	end
end

---Configures the task element.
---@param task Task The task
---@param contextTable table<string,boolean> The context table to store the collapsed state
---@return self
function TaskListTask:Configure(task, contextTable)
	assert(not self._state.task)
	local taskDesc = task:GetTaskDesc()
	local buttonEnabled, buttonText = task:GetButtonState()
	self._state.task = task
	self._state.desc = taskDesc
	self._state.buttonDisabled = not buttonEnabled
	self._state.buttonText = buttonText
	if task:HasSubTasks() then
		self._state.expanded = not contextTable[taskDesc]
		self._state:Publisher("expanded")
			:InvertBoolean()
			:AssignToTableKey(contextTable, taskDesc)
		-- Add the subtask rows
		for index, subTaskDesc in task:SubTaskIterator() do
			if task:CanHideSubTasks() then
				self._state.childrenFrame:AddChild(UIElements.New("TaskListHideableSubTask", "subTask")
					:SetHeight(20)
					:SetMargin(18, 8, 0, 2)
					:Configure(task, index, subTaskDesc)
				)
			else
				self._state.childrenFrame:AddChild(UIElements.New("Text", "text")
					:SetHeight(20)
					:SetMargin(38, 8, 0, 2)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(subTaskDesc)
				)
			end
		end
	else
		self._state.expanded = false
	end

	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@return ActionButton
function TaskListTask.__protected:_CreateTaskButton()
	return UIElements.New("SmallPrimaryActionButton", "button")
		:SetAction("OnMouseDown", "ACTION_BUTTON_MOUSE_DOWN")
		:SetAction("OnClick", "ACTION_BUTTON_CLICK")
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<TaskListTaskState>
---@param state TaskListTaskState
function TaskListTask.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_BUTTON_MOUSE_DOWN" then
		state.task:OnMouseDown()
	elseif action == "ACTION_BUTTON_CLICK" then
		state.task:OnButtonClick()
	elseif action == "ACTION_EXPANDER_CLICK" then
		state.expanded = not state.expanded
		self:DrawBaseElement()
	else
		error("Unknown action: "..tostring(action))
	end
end

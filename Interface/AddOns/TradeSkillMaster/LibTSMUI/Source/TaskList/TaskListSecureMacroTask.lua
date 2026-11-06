-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local TaskListSecureMacroTask = ComponentRegistry.Define("TaskListSecureMacroTask", "TaskListTask")
TaskListSecureMacroTask._STATE_SCHEMA = TaskListSecureMacroTask._STATE_SCHEMA:Extend("TaskListSecureMacroTaskState")
	:AddDeferredUIElementField("button", "SecureMacroActionButton")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Configures the task element.
---@param task Task The task
---@param contextTable table<string,boolean> The context table to store the collapsed state
---@return self
function TaskListSecureMacroTask:Configure(task, contextTable)
	self.__super:Configure(task, contextTable)
	self._state.button:SetMacroText(task:GetSecureMacroText())
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@return ActionButton
function TaskListSecureMacroTask.__protected:_CreateTaskButton()
	return UIElements.New("SecureMacroActionButton", "button")
		:BindElement(self._state, "button")
end

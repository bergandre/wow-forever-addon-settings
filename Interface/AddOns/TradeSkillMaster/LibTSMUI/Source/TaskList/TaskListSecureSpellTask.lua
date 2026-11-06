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

local TaskListSecureSpellTask = ComponentRegistry.Define("TaskListSecureSpellTask", "TaskListTask")
TaskListSecureSpellTask._STATE_SCHEMA = TaskListSecureSpellTask._STATE_SCHEMA:Extend("TaskListSecureSpellTaskState")
	:AddDeferredUIElementField("button", "SecureSpellActionButton")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Configures the task element.
---@param task Task The task
---@param contextTable table<string,boolean> The context table to store the collapsed state
---@return self
function TaskListSecureSpellTask:Configure(task, contextTable)
	self.__super:Configure(task, contextTable)
	self._state.button:SetSpell(task:GetSecureSpell())
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@return ActionButton
function TaskListSecureSpellTask.__protected:_CreateTaskButton()
	return UIElements.New("SecureSpellActionButton", "button")
		:BindElement(self._state, "button")
end

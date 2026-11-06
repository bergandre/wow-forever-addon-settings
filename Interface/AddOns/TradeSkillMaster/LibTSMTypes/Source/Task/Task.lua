-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Task = LibTSMTypes:DefineClassType("Task", nil, "ABSTRACT")
local private = {
	updateCallback = nil,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the task code.
---@param updateCallback fun() The update callback
function Task.__static.Configure(updateCallback)
	assert(not private.updateCallback)
	private.updateCallback = updateCallback
end


-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Task:__init()
	assert(private.updateCallback)
	self._category = nil
	self._desc = nil
	self._buttonEnabled = nil
	self._buttonText = nil
	self._doneHandler = nil
end

function Task:Acquire(doneHandler, category, desc)
	self._doneHandler = doneHandler
	self._category = category
	self._desc = desc
end

function Task:Release()
	self._category = nil
	self._desc = nil
	self._buttonEnabled = nil
	self._buttonText = nil
	self._doneHandler = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Task:GetCategory()
	return self._category
end

function Task:GetTaskDesc()
	return self._desc
end

function Task:HasSubTasks()
	return false
end

function Task:SubTaskIterator()
	error("Must be implemented by the subclass")
end

function Task:IsSecureMacro()
	return false
end

---@return string
function Task:GetSecureMacroText()
	error("Must be implemented by the subclass")
end

function Task:IsSecureSpell()
	return false
end

---@return string
function Task:GetSecureSpell()
	error("Must be implemented by the subclass")
end

function Task:GetButtonState()
	return self._buttonEnabled, self._buttonText
end

function Task:Update()
	if self:_UpdateState() then
		private.updateCallback()
	end
end

function Task:OnMouseDown()
end

function Task:OnButtonClick()
	error("Must be implemented by the subclass")
end

function Task:CanHideSubTasks()
	return false
end

function Task:HideSubTask(index)
	error("Must be implemented by the subclass")
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Task:_UpdateState()
	error("Must be implemented by the subclass")
end

function Task:_SetButtonState(buttonEnabled, buttonText)
	if buttonEnabled == self._buttonEnabled and buttonText == self._buttonText then
		-- nothing changed
		return false
	end
	self._buttonEnabled = buttonEnabled
	self._buttonText = buttonText
	return true
end

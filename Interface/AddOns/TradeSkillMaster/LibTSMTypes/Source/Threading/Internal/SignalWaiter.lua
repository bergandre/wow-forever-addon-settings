-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local SignalWaiter = LibTSMTypes:DefineInternalClassType("SignalWaiter")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local STATE = EnumType.New("SIGNAL_WAITER_STATE", {
	IDLE = EnumType.NewValue(),
	STARTED = EnumType.NewValue(),
	DONE = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new signal waiter.
---@return SignalWaiter
---@param onSetHandler fun() A function to call from the signal's OnSet handler
function SignalWaiter.__static.New(onSetHandler)
	return SignalWaiter(onSetHandler)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SignalWaiter.__private:__init(onSetHandler)
	self._state = STATE.IDLE
	self._signal = nil ---@type Signal!
	self._onSetHandler = onSetHandler
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Resets the waiter.
function SignalWaiter:Reset()
	if self._state == STATE.STARTED then
		self._signal:SetHandler(nil)
	end
	self._state = STATE.IDLE
	self._signal = nil
end

---Starts the waiter.
---@param signal Signal The signal to wait for
function SignalWaiter:Start(signal)
	assert(self._state == STATE.IDLE)
	self._signal = signal
	self._state = STATE.STARTED
	if signal:IsSet() then
		self:_OnSet(signal)
	else
		signal:SetHandler(self:__closure("_OnSet"))
	end
end

---Checks if the waiter is done.
---@return boolean
function SignalWaiter:IsDone()
	return self._state == STATE.DONE
end

---Resets the waiter upon completion.
function SignalWaiter:GetResult()
	self:Reset()
end

---Gets a debug string representation of the current state.
---@return string
function SignalWaiter:GetDebugStr()
	if self._state == STATE.STARTED then
		return format("Waiting for signal (%s)", self._signal:GetName())
	elseif self._state == STATE.DONE then
		return format("Got result from signal (%s)", self._signal:GetName())
	else
		error("Invalid state: "..tostring(self._state))
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SignalWaiter.__private:_OnSet(signal)
	if signal ~= self._signal or self._state ~= STATE.STARTED then
		return
	end
	self._signal:SetHandler(nil)
	self._signal = nil
	self._state = STATE.DONE
	self._onSetHandler()
end

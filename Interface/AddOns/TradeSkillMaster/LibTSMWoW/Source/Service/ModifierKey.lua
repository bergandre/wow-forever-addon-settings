-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ModifierKey = LibTSMWoW:Init("Service.ModifierKey")
local Event = LibTSMWoW:Include("Service.Event")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local private = {
	lastHash = 0,
	callbacks = CallbackRegistry.NewList(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ModifierKey:OnModuleLoad(function()
	Event.Register("MODIFIER_STATE_CHANGED", private.UpdateModifierState)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for when the modifier keys change.
---@param func fun() Function to call
function ModifierKey.RegisterCallback(func)
	private.callbacks:Add(func)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateModifierState()
	local hash = private.CalculateHash()
	if hash == private.lastHash then
		return
	end
	private.lastHash = hash
	private.callbacks:CallAll()
end

function private.CalculateHash()
	return (IsShiftKeyDown() and 4 or 0) + (IsAltKeyDown() and 2 or 0) + (IsControlKeyDown() and 1 or 0)
end

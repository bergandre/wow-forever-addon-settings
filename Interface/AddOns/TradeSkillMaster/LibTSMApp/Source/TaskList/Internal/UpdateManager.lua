-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local UpdateManager = LibTSMApp:InitInternal("TaskList.UpdateManager")
local Task = LibTSMApp:From("LibTSMTypes"):IncludeClassType("Task")
local private = {
	updateCallback = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

UpdateManager:OnModuleLoad(function()
	Task.Configure(UpdateManager.HandleUpdate)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the callback that's called when an update occurs.
---@param func fun() The update callback
function UpdateManager.SetCallback(func)
	assert(not private.updateCallback)
	private.updateCallback = func
end

---Handles an update event.
function UpdateManager.HandleUpdate()
	if not private.updateCallback then
		return
	end
	private.updateCallback()
end

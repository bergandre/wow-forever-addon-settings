-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local TaskList = LibTSMApp:Init("TaskList")
local Gathering = LibTSMApp:Include("TaskList.Gathering")
local TaskPool = LibTSMApp:Include("TaskList.TaskPool")
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local ShoppingTask = LibTSMApp:IncludeClassType("ShoppingTask")
local VendoringTask = LibTSMApp:IncludeClassType("VendoringTask")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the function to call to start a gathering search.
---@param func ShoppingTaskStartSearchFunc The function to start a gathering search
function TaskList.SetStartGatheringFunc(func)
	Gathering.SetStartGatheringFunc(func)
end

---Sets the function called when an active task is updated.
---@param func fun() The callback function
function TaskList.SetUpdateCallback(func)
	UpdateManager.SetCallback(func)
end

---Gets the number of active tasks.
---@return number
function TaskList.GetNumTasks()
	return TaskPool.GetNumTasks()
end

---Iterates over the active tasks.
---@return fun(): number, Task @Iterator with fields: `index`, `task`
function TaskList.Iterator()
	return TaskPool.Iterator()
end

---Sets whether or not the required UI is currently visible for the vendoring task.
---@param visible boolean Whether or not the UI is visible
function TaskList.SetVendoringTaskUIVisible(visible)
	VendoringTask.SetUIVisible(visible)
end

---Sets whether or not the required UI is currently visible for the shopping task.
---@param visible boolean Whether or not the UI is visible
function TaskList.SetShoppingTaskUIVisible(visible)
	ShoppingTask.SetUIVisible(visible)
end

---Sets whether or not a scan is in progress for the shopping task.
---@param scanInProgress boolean Whether or not a scan is in progress
function TaskList.SetShoppingTaskIsScanning(scanInProgress)
	ShoppingTask.SetIsScanning(scanInProgress)
end

---Handles the UI being updated for the shopping task.
function TaskList.HandleShoppingTaskUIUpdate()
	ShoppingTask.HandleUIUpdate()
end

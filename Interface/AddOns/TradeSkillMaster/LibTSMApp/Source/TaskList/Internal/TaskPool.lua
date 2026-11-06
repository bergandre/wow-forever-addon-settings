-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local TaskPool = LibTSMApp:InitInternal("TaskList.TaskPool")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	keys = {},
	tasks = {}, ---@type table<string,Task[]>
}
local ITER_KEY_INDEX_MULTIPLE = 1000000



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a task pool key.
---@param key string The task pool key
function TaskPool.Register(key)
	assert(not private.tasks[key])
	tinsert(private.keys, key)
	private.tasks[key] = {}
end

---Inserts a task into a task pool.
---@param key string The task pool key
---@param task Task The task
function TaskPool.Insert(key, task)
	tinsert(private.tasks[key], task)
end

---Removes a task from a task pool.
---@param key string The task pool key
---@param task Task The task
function TaskPool.Remove(key, task)
	assert(Table.RemoveByValue(private.tasks[key], task) == 1)
end

---Wipes a task pool.
---@param key string The task pool key
function TaskPool.Wipe(key)
	wipe(private.tasks[key])
end

---Gets the number of tasks.
---@return number
function TaskPool.GetNumTasks()
	local num = 0
	for _, tasks in pairs(private.tasks) do
		num = num + #tasks
	end
	return num
end

---Iterates over all tasks.
---@param filterKey? string An optional key to filter by when iterating
---@return fun(): number, Task @Iterator with fields: `index`, `task`
---@return string|nil
function TaskPool.Iterator(filterKey)
	if filterKey then
		return private.FilteredIterator, filterKey
	else
		return private.Iterator, nil
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FilteredIterator(key, index)
	index = (index or 0) + 1
	local task = private.tasks[key][index]
	if not task then
		return
	end
	return index, task
end

function private.Iterator(_, index)
	index = (index or ITER_KEY_INDEX_MULTIPLE) + 1
	local keyIndex = floor(index / ITER_KEY_INDEX_MULTIPLE)
	local taskIndex = index % ITER_KEY_INDEX_MULTIPLE
	while true do
		local key = private.keys[keyIndex]
		if not key then
			return
		end
		local task = private.tasks[key][taskIndex]
		if task then
			return keyIndex * ITER_KEY_INDEX_MULTIPLE + taskIndex, task
		else
			-- Increment the key index and try again
			keyIndex = keyIndex + 1
			taskIndex = 1
		end
	end
end

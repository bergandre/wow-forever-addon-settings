-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMCore = select(2, ...).LibTSMCore
local LibTSMService = select(2, ...).LibTSMService
local Lifecycle = LibTSMService:Init("Util.Lifecycle")
local Analytics = LibTSMService:Include("Util.Analytics")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Memory = LibTSMService:From("LibTSMUtil"):Include("Lua.Memory")
local ExecutionTime = LibTSMService:From("LibTSMUtil"):Include("Util.ExecutionTime")
local LifecycleWoW = LibTSMService:From("LibTSMWoW"):Include("Service.Lifecycle")
local private = {
	callbacks = {},
	callbackHandled = {},
	totalTime = {},
	isDone = {},
}
local EVENT = LifecycleWoW.EVENT
Lifecycle.EVENT = EVENT
local ANALYTICS_ACTION_LOOKUP = {
	[EVENT.LOADED] = "ADDON_INITIALIZE",
	[EVENT.LOGIN] = "ADDON_ENABLE",
	[EVENT.LOGOUT] = "ADDON_DISABLE",
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Lifecycle:OnModuleLoad(function()
	-- Insert our callback first for loading/unloading all modules via LibTSMCore
	assert(not next(private.callbacks))
	Lifecycle.RegisterCallback(private.LoadAllModules, EVENT.LOADED)
	Lifecycle.RegisterCallback(private.UnloadAllModules, EVENT.LOGOUT)
	LifecycleWoW.Configure(private.EventHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for lifecycle events.
---@param func fun(event: EnumValue, maxTime: number): boolean The callback function (called multiple times until it returns true)
---@param eventFilter? EnumValue An event filter (or nil to receive all events)
function Lifecycle.RegisterCallback(func, eventFilter)
	assert(not private.callbacks[func])
	tinsert(private.callbacks, func)
	if eventFilter then
		assert(EVENT:HasValue(eventFilter))
		assert(not private.isDone[eventFilter])
		private.callbacks[func] = eventFilter
	else
		private.callbacks[func] = true
	end
end

---Processes a lifecycle event for test purposes.
---@param event EnumValue The event to process
function Lifecycle.TestEvent(event)
	assert(EVENT:HasValue(event))
	assert(private.DoCallbacks(event, math.huge))
	wipe(private.callbackHandled[event])
	private.totalTime[event] = nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadAllModules()
	LibTSMCore.LoadAll()
	for _, component, path, moduleLoadTime in LibTSMCore.ModuleInfoIterator() do
		ExecutionTime.CheckElapsed(moduleLoadTime, "Loading %s->%s", component, path)
	end
	return true
end

function private.UnloadAllModules(_, maxTime)
	if not LibTSMCore.UnloadAll(maxTime) then
		return false
	end
	if maxTime == math.huge then
		return true
	end
	for _, component, path, _, moduleUnloadTime in LibTSMCore.ModuleInfoIterator() do
		ExecutionTime.CheckElapsed(moduleUnloadTime, "Unloading %s->%s", component, path)
	end
	return true
end

function private.EventHandler(lifecycleEvent, isLastFrame, maxTime)
	if lifecycleEvent == EVENT.LOADED then
		assert(not private.isDone[EVENT.LOGIN] and not private.isDone[EVENT.LOGOUT])
	elseif lifecycleEvent == EVENT.LOGIN then
		assert(private.isDone[EVENT.LOADED] and not private.isDone[EVENT.LOGOUT])
	elseif lifecycleEvent == EVENT.LOGOUT then
		assert(private.isDone[EVENT.LOADED])
		if not private.isDone[EVENT.LOGIN] then
			-- This can happen if the player exits the game during the loading screen, in which case we just ignore it
			private.isDone[lifecycleEvent] = true
		end
	end
	if private.isDone[lifecycleEvent] then
		return
	end
	if private.DoCallbacks(lifecycleEvent, LibTSMService.GetTime() + maxTime) then
		private.isDone[lifecycleEvent] = true
		Analytics.Action(ANALYTICS_ACTION_LOOKUP[lifecycleEvent], Math.Round(private.totalTime[lifecycleEvent], 0.1))
		if lifecycleEvent ~= EVENT.LOGOUT then
			-- Force a GC since loading can generate a lot of garbage
			for _ in ExecutionTime.WithMeasurement("%s (GC)", lifecycleEvent) do
				Memory.CollectGarbage()
			end
		end
	elseif isLastFrame then
		error("Ran out of event frames for "..tostring(lifecycleEvent))
	end
end

function private.DoCallbacks(event, maxTime)
	local done = true
	for _ in ExecutionTime.WithMeasurement("%s", event) do
		local startTime = LibTSMService.GetTime()
		private.callbackHandled[event] = private.callbackHandled[event] or {}
		for _, callback in ipairs(private.callbacks) do
			local filter = private.callbacks[callback]
			if not private.callbackHandled[event][callback] and (filter == true or filter == event) then
				if LibTSMService.GetTime() >= maxTime then
					done = false
					break
				end
				local result = callback(event, maxTime)
				assert(type(result) == "boolean")
				if result then
					private.callbackHandled[event][callback] = true
				else
					done = false
				end
			end
		end
		private.totalTime[event] = (private.totalTime[event] or 0) + LibTSMService.GetTime() - startTime
	end
	return done
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Event = LibTSMWoW:Init("Service.Event")
local TempTable = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.TempTable")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMWoW:From("LibTSMUtil"):Include("Lua.Table")
local ExecutionTime = LibTSMWoW:From("LibTSMUtil"):Include("Util.ExecutionTime")
local Reactive = LibTSMWoW:From("LibTSMReactive"):Include("Reactive")
local private = {
	registry = {
		event = {},
		callback = {},
	},
	registeredEventCount = {},
	eventFrame = nil,
	allEventsFrame = nil,
	temp = {},
	eventQueue = {},
	processingEvent = false,
	streams = {}, ---@type table<string,ReactiveStream>
	allEventsCallbacks = CallbackRegistry.NewList(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Event:OnModuleLoad(function()
	private.eventFrame = CreateFrame("Frame")
	private.eventFrame:SetScript("OnEvent", private.EventHandler)
	private.eventFrame:Show()
	private.allEventsFrame = CreateFrame("Frame")
	private.allEventsFrame:SetScript("OnEvent", private.AllEventsHandler)
	private.allEventsFrame:Show()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers an event callback.
---@generic E: FrameEvent
---@param event E The WoW event to register for (i.e. BAG_UPDATE)
---@param callback fun(event: E, ...params<E>) The function to be called from the event handler
function Event.Register(event, callback)
	assert(type(event) == "string" and event == strupper(event) and type(callback) == "function")
	-- make sure this event/callback isn't already registered
	for i = 1, #private.registry.event do
		assert(private.registry.event[i] ~= event or private.registry.callback[i] ~= callback)
	end
	tinsert(private.registry.event, event)
	tinsert(private.registry.callback, callback)
	private.registeredEventCount[event] = (private.registeredEventCount[event] or 0) + 1
	if private.registeredEventCount[event] == 1 and not private.streams[event] then
		private.eventFrame:RegisterEvent(event)
	end
end

---Unregisters an event callback.
---@param event string The WoW event which the callback was registered for
---@param callback function The function which was passed to @{Event.Register} for this event
function Event.Unregister(event, callback)
	assert(type(event) == "string" and event == strupper(event) and type(callback) == "function")
	local index = nil
	for i = 1, #private.registry.event do
		if private.registry.event[i] == event and private.registry.callback[i] == callback then
			assert(not index)
			index = i
		end
	end
	assert(index)
	private.registeredEventCount[event] = private.registeredEventCount[event] - 1
	assert(private.registeredEventCount[event] >= 0)
	if private.registeredEventCount[event] == 0 and not private.streams[event] then
		private.eventFrame:UnregisterEvent(event)
	end
	tremove(private.registry.event, index)
	tremove(private.registry.callback, index)
end

---Gets a publisher for the specified event.
---@param event string The WoW event
---@return ReactivePublisherSchema The publisher
function Event.GetPublisher(event)
	if not private.streams[event] then
		private.streams[event] = Reactive.GetStream(private.GetStreamInitialValue)
			:SetNoPublishersCallback(private.HandleNoStreamPublishers)
		if (private.registeredEventCount[event] or 0) == 0 then
			private.eventFrame:RegisterEvent(event)
		end
	end
	return private.streams[event]:Publisher()
		:IgnoreNil()
		:IgnoreIfNotEquals(event, 1)
end

---Registers a callback for all events (should be used with great care).
---@param callback fun(event: string, ...) The function to be called from the event handler
function Event.RegisterAllEvents(callback)
	if private.allEventsCallbacks:IsEmpty() then
		private.allEventsFrame:RegisterAllEvents()
	end
	private.allEventsCallbacks:Add(callback)
end

---Unregisters a callback for all events.
---@param callback function The function which was passed to @{Event.RegisterAllEvents}
function Event.UnregisterAllEvents(callback)
	private.allEventsCallbacks:Remove(callback)
	if private.allEventsCallbacks:IsEmpty() then
		private.allEventsFrame:UnregisterAllEvents()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ProcessEvent(context)
	local event = context[1]
	assert(type(event) == "string")
	-- NOTE: The registered events may change within the callback, so copy them to a temp table
	wipe(private.temp)
	for i = 1, #private.registry.event do
		if private.registry.event[i] == event then
			tinsert(private.temp, private.registry.callback[i])
		end
	end
	for _, callback in ipairs(private.temp) do
		for _ in ExecutionTime.WithMeasurement("Event (%s) callback", event) do
			callback(unpack(context))
		end
	end
	local stream = private.streams[event]
	if stream then
		stream:Send(context)
	end
end

function private.EventHandler(_, event, ...)
	local context = TempTable.Acquire(event, ...)
	if private.processingEvent then
		-- We are already in the middle of processing another event, so queue this one up
		tinsert(private.eventQueue, context)
		assert(#private.eventQueue < 50)
		return
	end
	private.processingEvent = true
	private.ProcessEvent(context)
	TempTable.Release(context)
	-- Process queued events
	while #private.eventQueue > 0 do
		local queuedContext = tremove(private.eventQueue, 1)
		private.ProcessEvent(queuedContext)
		TempTable.Release(queuedContext)
	end
	private.processingEvent = false
end

function private.AllEventsHandler(_, event, ...)
	private.allEventsCallbacks:CallAll(event, ...)
end

function private.HandleNoStreamPublishers(stream)
	local event = Table.KeyByValue(private.streams, stream)
	assert(event)
	private.streams[event]:Release()
	private.streams[event] = nil
	if (private.registeredEventCount[event] or 0) == 0 then
		private.eventFrame:UnregisterEvent(event)
	end
end

function private.GetStreamInitialValue()
	return nil
end

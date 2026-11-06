-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ScriptWrapper = LibTSMWoW:Init("API.ScriptWrapper")
local ExecutionTime = LibTSMWoW:From("LibTSMUtil"):Include("Util.ExecutionTime")
local private = {
	handlers = {},
	objLookup = {},
	hooks = {},
	hookObjLookup = {},
	wrappers = {},
	debugNameObj = {},
	propagateWrappers = {},
	nestedLevel = 0,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the handler for a script on a frame.
---@param frame table The frame to call SetScript() on
---@param script string The script to set
---@param handler function The handler to set
---@param obj? table The object to pass to the handler as the first parameter (instead of frame)
---@param debugNameObj? string An object which is converted to a string to represent the frame / object for debugging purposes
function ScriptWrapper.Set(frame, script, handler, obj, debugNameObj)
	assert(type(frame) == "table" and type(script) == "string" and type(handler) == "function")
	obj = obj or frame
	local key = private.GetFrameScriptKey(frame, script)
	private.handlers[key] = handler
	private.objLookup[key] = obj
	private.debugNameObj[key] = debugNameObj or obj
	frame:SetScript(script, private.GetWrapper(script))
end

---Hooks a script on a frame with a handler which is called before the one set via `ScriptWrapper.Set()` and isn't removed by `ScriptWrapper.Clear()`.
---@param frame table The frame to call SetScript() on
---@param script string The script to hook
---@param handler function The handler to call
---@param obj? table The object to pass to the handler as the first parameter (instead of frame)
---@param debugNameObj? string An object which is converted to a string to represent the frame / object for debugging purposes
function ScriptWrapper.Hook(frame, script, handler, obj, debugNameObj)
	assert(type(frame) == "table" and type(script) == "string" and type(handler) == "function")
	obj = obj or frame
	local key = private.GetFrameScriptKey(frame, script)
	assert(not private.hooks[key])
	private.hooks[key] = handler
	private.hookObjLookup[key] = obj
	private.debugNameObj[key] = debugNameObj or obj
	frame:SetScript(script, private.GetWrapper(script))
end

---Sets the script handler to simply propagate the script to the parent element.
---@param frame table The frame to call SetScript() on
---@param script string The script which should be propagated
---@param obj? table The object to pass to the handler as the first parameter (instead of frame)
function ScriptWrapper.SetPropagate(frame, script, obj)
	if not private.propagateWrappers[script] then
		private.propagateWrappers[script] = function(f, ...)
			local parentFrame = f:GetParent()
			local parentScript = parentFrame:GetScript(script)
			if not parentScript then
				return
			end
			parentScript(parentFrame, ...)
		end
	end
	ScriptWrapper.Set(frame, script, private.propagateWrappers[script], obj)
end

---Clears a previously-registered script handler.
---@param frame table The frame to clear the script on
---@param script string The script which should be cleared
function ScriptWrapper.Clear(frame, script)
	local key = private.GetFrameScriptKey(frame, script)
	private.handlers[key] = nil
	private.objLookup[key] = nil
	if private.hooks[key] then
		return
	end
	private.debugNameObj[key] = nil
	frame:SetScript(script, nil)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetFrameScriptKey(frame, script)
	return tostring(frame)..":"..script
end

function private.GetWrapper(script)
	if not private.wrappers[script] then
		private.wrappers[script] = function(...)
			private.ScriptHandlerCommon(script, ...)
		end
	end
	return private.wrappers[script]
end

function private.ScriptHandlerCommon(script, frame, ...)
	local key = private.GetFrameScriptKey(frame, script)
	local isTopLevel = private.nestedLevel == 0
	private.nestedLevel = private.nestedLevel + 1
	if isTopLevel then
		for _ in ExecutionTime.WithMeasurement("Script handler (%s) for frame (%s)", script, private.debugNameObj[key]) do
			private.CallHandlers(key, ...)
		end
	else
		private.CallHandlers(key, ...)
	end
	private.nestedLevel = private.nestedLevel - 1
end

function private.CallHandlers(key, ...)
	local hook = private.hooks[key]
	if hook then
		hook(private.hookObjLookup[key], ...)
	end
	local handler = private.handlers[key]
	if handler then
		handler(private.objLookup[key], ...)
	end
end

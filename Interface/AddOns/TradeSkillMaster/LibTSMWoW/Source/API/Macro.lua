-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Macro = LibTSMWoW:Init("API.Macro")
local Vararg = LibTSMWoW:From("LibTSMUtil"):Include("Lua.Vararg")
local CHARACTER_BINDING_SET = 2
local MAX_MACRO_NUM = (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and Constants.MacroConsts.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the macro body.
---@param name string The macro name
---@return string?
function Macro.GetBody(name)
	return GetMacroBody(name)
end

---Updates a macro.
---@param name string The macro name
---@param icon string The macro icon
---@param body string The macro body
function Macro.Update(name, icon, body)
	EditMacro(name, nil, icon, body)
end

---Creates a macro or updates it if it already exists.
---@param name string The macro name
---@param icon string The macro icon
---@param body string The macro body
function Macro.CreateOrUpdate(name, icon, body)
	if GetMacroBody(name) then
		Macro.Update(name, icon, body)
	else
		CreateMacro(name, icon, body)
	end
end

---Gets the current binding for a macro.
---@param name string The macro name
---@return boolean mouseWheelUp
---@return boolean mouseWheelDown
---@return boolean ctrlKey
---@return boolean altKey
---@return boolean shiftKey
function Macro.GetBinding(name)
	local mouseWheelUp, mouseWheelDown, ctrlKey, altKey, shiftKey = false, false, false, false, false
	for _, binding in Vararg.Iterator(GetBindingKey("MACRO "..name)) do
		mouseWheelUp = mouseWheelUp or (strfind(binding, "MOUSEWHEELUP") and true or false)
		mouseWheelDown = mouseWheelDown or (strfind(binding, "MOUSEWHEELDOWN") and true or false)
		ctrlKey = ctrlKey or (strfind(binding, "CTRL-") and true or false)
		altKey = altKey or (strfind(binding, "ALT-") and true or false)
		shiftKey = shiftKey or (strfind(binding, "SHIFT-") and true or false)
	end
	return mouseWheelUp, mouseWheelDown, ctrlKey, altKey, shiftKey
end

---Updates the current binding for a macro.
---@param name string The macro name
---@param mouseWheelUp boolean Bind to mouse wheel up
---@param mouseWheelDown boolean Bind to mouse wheel down
---@param ctrlKey boolean Ctrl key modifier
---@param altKey boolean Alt key modifier
---@param shiftKey boolean Shift key modifier
function Macro.UpdateBinding(name, mouseWheelUp, mouseWheelDown, ctrlKey, altKey, shiftKey)
	-- We want to save bindings to be per-character, so the mode should be 1 / 2 if we're currently on
	-- per-character bindings or not respectively
	local bindingMode = (GetCurrentBindingSet() == CHARACTER_BINDING_SET) and 1 or 2
	local modifierStr = strjoin("", ctrlKey and "CTRL-" or "", altKey and "ALT-" or "", shiftKey and "SHIFT-" or "")
	if mouseWheelUp then
		SetBinding(modifierStr.."MOUSEWHEELUP", nil, bindingMode)
		SetBindingMacro(modifierStr.."MOUSEWHEELUP", name) ---@diagnostic disable-line: param-type-mismatch
	end
	if mouseWheelDown then
		SetBinding(modifierStr.."MOUSEWHEELDOWN", nil, bindingMode)
		SetBindingMacro(modifierStr.."MOUSEWHEELDOWN", name) ---@diagnostic disable-line: param-type-mismatch
	end
	SaveBindings(CHARACTER_BINDING_SET)
end

---Returns whether or not a new macro can be created.
---@return boolean
function Macro.CanCreate()
	return GetNumMacros() < MAX_MACRO_NUM
end

---Updates a binding to click the specified button.
function Macro.UpdateBindingClickTarget(buttonName)
	local keybind1, keybind2 = GetBindingKey(buttonName)
	---@cast keybind1 string?
	---@cast keybind2 string?
	if keybind1 then
		SetBindingClick(keybind1, buttonName, "LeftButton")
	end
	if keybind2 then
		SetBindingClick(keybind2, buttonName, "LeftButton")
	end
end

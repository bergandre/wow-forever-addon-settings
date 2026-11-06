-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SecureMacroActionButton = ComponentRegistry.Define("SecureMacroActionButton", "SmallPrimaryActionButton")
SecureMacroActionButton:_AddActionScripts("PreClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SecureMacroActionButton:__init(name)
	self.__super:__init(name, true)
	self._frame:SetAttribute("*type1", "macro")
	self._frame:SetAttribute("*macrotext1", "")
	self._frame:TSMSetScript("PreClick", self:__closure("_HandlePreClick"))
end

function SecureMacroActionButton:Acquire()
	self.__super:Acquire()
	self._frame:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
end

function SecureMacroActionButton:Release()
	self._frame:SetAttribute("*macrotext1", "")
	self.__super:Release()
end

---Sets the macro text which clicking the button executes.
---@param text string The macro text
---@return self
function SecureMacroActionButton:SetMacroText(text)
	self._frame:SetAttribute("*macrotext1", text)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SecureMacroActionButton:_HandlePreClick()
	if not self._state.acquired then
		return
	end
	self:_SendActionScript("PreClick")
end

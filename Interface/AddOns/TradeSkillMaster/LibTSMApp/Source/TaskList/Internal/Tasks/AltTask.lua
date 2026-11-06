-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Task = LibTSMApp:From("LibTSMTypes"):IncludeClassType("Task")
local AltTask = LibTSMApp:DefineClassType("AltTask", Task)
local GlobalStrings = LibTSMApp:From("LibTSMWoW"):Include("Util.GlobalStrings")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function AltTask:Acquire(doneHandler, category, character)
	self.__super:Acquire(doneHandler, category, format(L["Switch to %s"], character))
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AltTask:IsSecureMacro()
	return true
end

function AltTask:GetSecureMacroText()
	return "/logout"
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AltTask._UpdateState(self)
	return self:_SetButtonState(true, strupper(GlobalStrings.Get("LOGOUT")))
end

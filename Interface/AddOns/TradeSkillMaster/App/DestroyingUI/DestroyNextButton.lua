-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Spell = App:From("LibTSMWoW"):Include("API.Spell")
local SlotId = App:From("LibTSMWoW"):Include("Type.SlotId")
local UIElements = App:From("LibTSMUI"):Include("UIElements")

---@alias DestroyNextButtonPrepareFunc fun(spellId: number, slotId: number)



-- ============================================================================
-- Element Definition
-- ============================================================================

local DestroyNextButton = UIElements.Define("DestroyNextButton", "MediumPrimaryActionButton")
DestroyNextButton:_AddActionScripts("OnStart")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DestroyNextButton:__init(name)
	self.__super:__init(name, true)
	self._frame:SetAttribute("*type1", "macro")
	self._frame:SetAttribute("*macrotext1", "")
	self._frame:TSMSetScript("PreClick", self:__closure("_HandlePreClick"))
	self._inPreClick = false
end

function DestroyNextButton:Acquire()
	self.__super:Acquire()
	self._frame:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
end

function DestroyNextButton:Release()
	self._inPreClick = false
	self._frame:SetAttribute("*macrotext1", "")
	self.__super:Release()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DestroyNextButton.__private:_HandlePreClick()
	if not self._state.acquired then
		return
	end
	self._inPreClick = true
	self:_SendActionScript("OnStart", self:__closure("_Prepare"))
	self._inPreClick = false
end

function DestroyNextButton.__private:_Prepare(spellId, slotId)
	assert(self._inPreClick)
	self._frame:SetAttribute("*macrotext1", format("/cast %s;\n/use %d %d", Spell.GetInfo(spellId), SlotId.Split(slotId)))
end

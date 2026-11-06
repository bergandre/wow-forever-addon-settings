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

local SecureSpellButton = ComponentRegistry.Define("SecureSpellButton", "BaseButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SecureSpellButton:__init()
	self.__super:__init(true)
end

function SecureSpellButton:Acquire()
	self.__super:Acquire()
	self._frame:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
end

function SecureSpellButton:Release()
	self:SetSpell(nil)
	self.__super:Release()
end

---Sets the spell which clicking the button casts.
---@param spell? string The name of the spell or nil to not cast anything
---@return self
function SecureSpellButton:SetSpell(spell)
	self._frame:SetAttribute("type", spell and "spell" or nil)
	self._frame:SetAttribute("spell", spell)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function SecureSpellButton.__protected:_HandleClick(_, mouseButton)
	self:_SendActionScript("OnClick", mouseButton, self:GetContext())
end

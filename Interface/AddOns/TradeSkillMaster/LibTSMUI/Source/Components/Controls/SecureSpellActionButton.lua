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

local SecureSpellActionButton = ComponentRegistry.Define("SecureSpellActionButton", "SmallPrimaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SecureSpellActionButton:__init(name)
	self.__super:__init(name, true)
end

function SecureSpellActionButton:Acquire()
	self.__super:Acquire()
	self._frame:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
end

function SecureSpellActionButton:Release()
	self:SetSpell(nil)
	self.__super:Release()
end

---Sets the spell which clicking the button casts.
---@param spell? string The name of the spell or nil to not cast anything
---@return self
function SecureSpellActionButton:SetSpell(spell)
	self._frame:SetAttribute("type", spell and "spell" or nil)
	self._frame:SetAttribute("spell", spell)
	return self
end

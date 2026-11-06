-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailReloadButton = UIElements.Define("MailReloadButton", "SmallTertiaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailReloadButton:__init(name)
	self.__super:__init(name, true)
	self._frame:SetAttribute("*type1", "macro")
	self._frame:SetAttribute("*macrotext1", "/reload")
end

function MailReloadButton:Acquire()
	self.__super:Acquire()
	self._frame:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
end

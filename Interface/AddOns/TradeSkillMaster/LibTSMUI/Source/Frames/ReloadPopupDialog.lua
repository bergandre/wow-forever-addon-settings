-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ReloadPopupDialog = ComponentRegistry.Define("ReloadPopupDialog", "PopupDialog")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ReloadPopupDialog:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self._state.buttonsFrame
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("SecureMacroActionButton", "reloadBtn")
				:SetWidth(150)
				:SetText(L["Reload"])
				:SetMacroText("/reload")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
	end
end

	-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local InfoPopupDialog = ComponentRegistry.Define("InfoPopupDialog", "PopupDialog")
InfoPopupDialog._STATE_SCHEMA = InfoPopupDialog._STATE_SCHEMA:Extend("InfoPopupDialogState")
	:AddDeferredUIElementField("confirmButton", "ActionButton")
	:AddStringField("buttonText", OKAY)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function InfoPopupDialog:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self._state.buttonsFrame
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("SmallPrimaryActionButton", "confirmBtn")
				:SetWidth(150)
				:BindElement(self._state, "confirmButton")
				:SetText(self._state:Publisher("buttonText"))
				:SetAction("OnClick", "ACTION_CLOSE")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
	end
end

---Sets the confirm button text.
---@param text string The text
---@return self
function InfoPopupDialog:SetButtonText(text)
	self._state.buttonText = text
	return self
end

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

local LedgerPrimaryNavButton = UIElements.Define("LedgerPrimaryNavButton", "BaseButton")
LedgerPrimaryNavButton._STATE_SCHEMA = LedgerPrimaryNavButton._STATE_SCHEMA:Extend("LedgerPrimaryNavButtonState")
	:UpdateFieldDefault("font", "BODY_SMALL_SEMIBOLD")
	:UpdateFieldDefault("justifyH", "LEFT")
	:AddStringField("label", "")
	:AddStringField("path", "")
	:AddBooleanField("isSelected", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerPrimaryNavButton:Acquire()
	self.__super:Acquire()
	self:SetJustifyH("LEFT")
	for _ in self._state:WithAutoStorePaused() do
		self
			:SetText(self._state:Publisher("label"))
			:SetTextColor(self._state:Publisher("isSelected"):ReplaceBooleanWith("on/surface", "on/surface/low"))
	end
end

---Configures the button.
---@param label string The label
---@param path string The path
---@return self
function LedgerPrimaryNavButton:Configure(label, path)
	self._state.label = label
	self._state.path = path
	return self
end

---Set the selected state.
---@param value boolean|ReactivePublisherSchemaBase The selected state or a publisher
---@return self
function LedgerPrimaryNavButton:SetIsSelected(value)
	if type(value) == "boolean" then
		self._state.isSelected = value
	else
		self:_MethodPublisher(value, "SetIsSelected")
	end
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function LedgerPrimaryNavButton.__protected:_HandleClick()
	self:_SendActionScript("OnClick", self._state.path)
end

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

local LedgerSecondaryNavButton = UIElements.Define("LedgerSecondaryNavButton", "BaseButton")
LedgerSecondaryNavButton._STATE_SCHEMA = LedgerSecondaryNavButton._STATE_SCHEMA:Extend("LedgerSecondaryNavButtonState")
	:UpdateFieldDefault("font", "BODY_SMALL")
	:UpdateFieldDefault("justifyH", "LEFT")
	:AddStringField("label", "")
	:AddOptionalStringField("path")
	:AddBooleanField("isSelected", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerSecondaryNavButton:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self
			:SetText(self._state:Publisher("label"))
			:SetTextColor(self._state:Publisher("isSelected"):ReplaceBooleanWith("accent/main", "on/surface"))
	end
end

---Configures the button.
---@param label string The label
---@param path string The path
---@return self
function LedgerSecondaryNavButton:Configure(label, path)
	assert(path)
	self._state.label = label
	self._state.path = path
	return self
end

---Set the selected state.
---@param value boolean|ReactivePublisherSchemaBase The selected state or a publisher
---@return self
function LedgerSecondaryNavButton:SetIsSelected(value)
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

function LedgerSecondaryNavButton.__protected:_HandleClick()
	assert(self._state.path)
	self:_SendActionScript("OnClick", self._state.path)
end

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

local SettingsNavButton = ComponentRegistry.Define("SettingsNavButton", "BaseButton")
SettingsNavButton._STATE_SCHEMA = SettingsNavButton._STATE_SCHEMA:Extend("SettingsNavButtonState")
	:AddStringField("selectedPath", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SettingsNavButton:Acquire()
	self.__super:Acquire()
	self:SetFont("BODY_SMALL_SEMIBOLD")
	self:SetJustifyH("LEFT")
	for _ in self._state:WithAutoStorePaused() do
		self:SetTextColor(self._state:Publisher([[selectedPath == textStr and "accent/main" or "on/surface/low"]]))
	end
end

---Sets the selected path.
---@param value string|ReactivePublisherSchemaBase The selected path or a publisher
---@return self
function SettingsNavButton:SetSelectedPath(value)
	if type(value) == "string" then
		self._state.selectedPath = value
	else
		self:_MethodPublisher(value, "SetSelectedPath")
	end
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function SettingsNavButton.__protected:_HandleClick()
	self:_SendActionScript("OnClick", self._state.textStr)
end

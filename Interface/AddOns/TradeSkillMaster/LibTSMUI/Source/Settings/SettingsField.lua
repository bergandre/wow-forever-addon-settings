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

local SettingsField = ComponentRegistry.Define("SettingsField", "BaseFrame")
SettingsField._STATE_SCHEMA = SettingsField._STATE_SCHEMA:Extend("SettingsFieldState")
	:AddStringField("label", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SettingsField:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("Text", "label")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 2)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(self._state:Publisher("label"))
		)
	end
end

---Sets the label which is shown above the field's control.
---@param label string The label
---@return self
function SettingsField:SetLabel(label)
	self._state.label = label
	return self
end

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

local DatabaseNavButton = ComponentRegistry.Define("DatabaseNavButton", "BaseButton")
DatabaseNavButton._STATE_SCHEMA = DatabaseNavButton._STATE_SCHEMA:Extend("DatabaseNavButtonState")
	:UpdateFieldDefault("justifyH", "LEFT")
	:UpdateFieldDefault("font", "BODY_XSMALL")
	:UpdateFieldDefault("background", "container/lowest")
	:UpdateFieldDefault("highlightColor", "container/lowest+HOVER")
	:AddOptionalStringField("tableName")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DatabaseNavButton:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self:SetText(self._state:Publisher("tableName"):CoalesceNil(""))
	end
end

---Sets the DB table name for the button.
---@param tableName string The table name
---@return self
function DatabaseNavButton:SetTableName(tableName)
	self._state.tableName = tableName
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function DatabaseNavButton.__protected:_HandleClick()
	self:_SendActionScript("OnClick", self._state.tableName)
end

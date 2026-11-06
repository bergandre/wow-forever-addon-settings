-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local BankingMoveButton = UIElements.Define("BankingMoveButton", "MediumPrimaryActionButton")
BankingMoveButton._STATE_SCHEMA = BankingMoveButton._STATE_SCHEMA:Extend("BankingMoveButtonState")
	:AddOptionalEnumField("moveType", EnumTypes.BANKING_MOVE_TYPE)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the move type for the button.
---@param moveType EnumValue The move type
---@return self
function BankingMoveButton:SetMoveType(moveType)
	self._state.moveType = moveType
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function BankingMoveButton.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		assert(self._state.moveType)
		self.__super:_SendActionScript(script, self._state.moveType)
	else
		self.__super:_SendActionScript(script, ...)
	end
end

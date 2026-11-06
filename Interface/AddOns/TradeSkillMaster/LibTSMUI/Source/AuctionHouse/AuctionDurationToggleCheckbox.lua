-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctionDurationToggleCheckbox = ComponentRegistry.Define("AuctionDurationToggleCheckbox", "Checkbox")
AuctionDurationToggleCheckbox._STATE_SCHEMA = AuctionDurationToggleCheckbox._STATE_SCHEMA:Extend("AuctionDurationToggleCheckboxState")
	:UpdateFieldDefault("theme", "RADIO")
	:AddNumberField("duration", 1)
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function AuctionDurationToggleCheckbox:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self:SetText(self._state:Publisher("duration"):Map(AuctionHouse.DURATIONS))
	end
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the duration.
---@param duration number The auction duration
---@return self
function AuctionDurationToggleCheckbox:SetDuration(duration)
	self._state.duration = duration
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function AuctionDurationToggleCheckbox.__protected:_SendActionScript(script, ...)
	assert(script == "OnValueChanged")
	self.__super:_SendActionScript(script, self._state.duration)
end

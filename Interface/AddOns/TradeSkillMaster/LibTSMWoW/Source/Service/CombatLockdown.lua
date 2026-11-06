-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local CombatLockdown = LibTSMWoW:Init("Service.CombatLockdown")
local Reactive = LibTSMWoW:From("LibTSMReactive"):Include("Reactive")
local private = {
	state = false,
	stream = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CombatLockdown:OnModuleLoad(function()
	private.state = InCombatLockdown()
	private.stream = Reactive.GetStream(CombatLockdown.IsActive)
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", private.EventHandler)
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:Show()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets a publisher for combat lockdown state changes.
---@return ReactivePublisherSchema<boolean>
function CombatLockdown.GetPublisher()
	return private.stream:Publisher()
end

---Returns whether or not the client is locked down for combat.
---@return boolean
function CombatLockdown.IsActive()
	return private.state
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.EventHandler(_, event)
	local state = event == "PLAYER_REGEN_DISABLED"
	if state == private.state then
		return
	end
	private.state = state
	private.stream:Send(state)
end

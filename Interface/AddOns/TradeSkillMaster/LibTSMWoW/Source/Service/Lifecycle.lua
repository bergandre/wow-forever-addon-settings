-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_NAME = ...
local LibTSMWoW = select(2, ...).LibTSMWoW
local Lifecycle = LibTSMWoW:Init("Service.Lifecycle")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local private = {
	eventFrames = {},
	handlerFunc = nil,
}
local EVENT = EnumType.New("LIFECYCLE_EVENT", {
	LOADED = EnumType.NewValue(),
	LOGIN = EnumType.NewValue(),
	LOGOUT = EnumType.NewValue(),
})
Lifecycle.EVENT = EVENT
-- We split the event handling across multiple frames to avoid tripping the 19 second per-script timeout
local NUM_EVENT_FRAMES = 10
local MAX_TIME_PER_EVENT = 12



-- ============================================================================
-- Module Loading
-- ============================================================================

Lifecycle:OnModuleLoad(function()
	for _ = 1, NUM_EVENT_FRAMES do
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("ADDON_LOADED")
		frame:RegisterEvent("PLAYER_LOGIN")
		frame:RegisterEvent("PLAYER_LOGOUT")
		frame:SetScript("OnEvent", private.OnEvent)
		tinsert(private.eventFrames, frame)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the lifecycle module.
---@param handlerFunc fun(event: EnumValue, isLastFrame: boolean, maxTime: number) The lifecycle event handler
function Lifecycle.Configure(handlerFunc)
	assert(not private.handlerFunc)
	private.handlerFunc = handlerFunc
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnEvent(frame, event, arg)
	local lifecycleEvent = nil
	if event == "ADDON_LOADED" and arg == ADDON_NAME then
		lifecycleEvent = EVENT.LOADED
	elseif event == "PLAYER_LOGIN" then
		lifecycleEvent = EVENT.LOGIN
	elseif event == "PLAYER_LOGOUT" then
		lifecycleEvent = EVENT.LOGOUT
	else
		return
	end
	local isLastFrame = frame == private.eventFrames[#private.eventFrames]
	private.handlerFunc(lifecycleEvent, isLastFrame, MAX_TIME_PER_EVENT)
end

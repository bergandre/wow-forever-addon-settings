-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CheckTimer = LibTSMService:InitInternal("Mail.CheckTimer")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local MAIL_REFRESH_TIME = (LibTSMService.IsRetail() or LibTSMService.IsForever()) and 15 or 60
local private = {
	timer = nil,
	lastCheck = 0,
	bypassed = 0,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CheckTimer:OnModuleLoad(function()
	private.timer = DelayTimer.New("MAILING_OPEN_CHECK_INBOX", private.Check)
	DefaultUI.RegisterMailVisibleCallback(private.FrameVisibleCallback)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the last check time.
---@return number
function CheckTimer.GetLastCheckTime()
	return private.lastCheck
end

---Sets whether or not checking the inbox should be bypassed.
---@param bypassed boolean Whether or not checking should be bypassed
function CheckTimer.SetBypassed(bypassed)
	private.bypassed = private.bypassed + (bypassed and 1 or -1)
	assert(private.bypassed >= 0)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameVisibleCallback(visible)
	if visible then
		private.Schedule()
	else
		private.timer:Cancel()
	end
end

function private.Check()
	if private.bypassed == 0 then
		Inbox.Check()
	end
	private.Schedule()
end

function private.Schedule()
	local now = LibTSMService.GetTime()
	if not private.lastCheck or now - private.lastCheck > (MAIL_REFRESH_TIME - 1) then
		private.lastCheck = now
		private.timer:RunForTime(MAIL_REFRESH_TIME)
	else
		local nextUpdate = MAIL_REFRESH_TIME - (now - private.lastCheck)
		private.timer:RunForTime(nextUpdate)
	end
end

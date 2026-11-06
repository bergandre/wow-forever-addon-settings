-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ClientInfo = LibTSMWoW:Init("Util.ClientInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets info on the current client build.
---@return string buildVersion
---@return string buildNum
function ClientInfo.GetBuildInfo()
	local buildVersion, buildNum = GetBuildInfo()
	return buildVersion, buildNum
end

---Gets the current client locale.
---@return string
function ClientInfo.GetLocale()
	return GetLocale()
end

---Gets the current frame rate.
---@return number
function ClientInfo.GetFrameRate()
	return GetFramerate()
end

---Gets a unique number for the current frame.
---@return number
function ClientInfo.GetFrameNumber()
	return GetTime()
end

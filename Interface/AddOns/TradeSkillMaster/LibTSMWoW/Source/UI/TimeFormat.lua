-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local TimeFormat = LibTSMWoW:Init("UI.TimeFormat")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Converts a duration to a formatted string.
---@param duration number The duration in seconds
---@return string
function TimeFormat.Duration(duration)
	return SecondsToTime(duration)
end

---Converts a timestamp into a date and time string.
---@param timestamp number The time value in seconds since epoch
---@return string
function TimeFormat.DateTime(timestamp)
	local result = nil
	if GetCVar("timeMgrUseMilitaryTime") == "1" then
		result = date("%H:%M %b %d, %Y", timestamp) --[[@as string]]
	else
		result = gsub(date("%I:%M %p %b %d, %Y", timestamp) --[[@as string]], "^0", "")
	end
	return result
end

---Converts a timestamp into a date string.
---@param timestamp number The time value in seconds since epoch
---@return string
function TimeFormat.Date(timestamp)
	return date("%b %d, %Y", timestamp) --[[@as string]]
end

---Gets the weekday.
---@param timestamp number The time value in seconds since epoch
---@return string
function TimeFormat.Weekday(timestamp)
	return date("%a", timestamp) --[[@as string]]
end

---Gets the month and day.
---@param timestamp number The time value in seconds since epoch
---@return string
function TimeFormat.MonthDay(timestamp)
	return date("%b %d", timestamp) --[[@as string]]
end

---Gets the month and shortened year.
---@param timestamp number The time value in seconds since epoch
---@return string
function TimeFormat.MonthAndShortYear(timestamp)
	return date("%b '%y", timestamp) --[[@as string]]
end

---Gets the time part of the timestamp.
---@param timestamp number The time value in seconds since epoch
---@return string
function TimeFormat.Time(timestamp)
	if GetCVar("timeMgrUseMilitaryTime") == "1" then
		return date("%H:%M", timestamp) --[[@as string]]
	else
		return strtrim(date("%I:%M %p", timestamp) --[[@as string]], "0")
	end
end

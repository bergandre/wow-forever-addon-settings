-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local TimeUtil = LibTSMWoW:Init("UI.TimeUtil")
local private = {
	tempTimeTable = {}, ---@type TimeParts
}
local SECONDS_PER_HOUR = 60 * 60

---@class TimeParts: osdateparam
---@field year number
---@field month number
---@field day number
---@field hour number
---@field min number
---@field sec number



-- ============================================================================
-- Module Functions
-- ============================================================================

---Rounds a timestamp up.
---@param timestamp number The time value in seconds since epoch
---@param amount number The number of units to round up to
---@param unit "MONTH"|"DAY"|"HOUR" The unit of time to use
function TimeUtil.Ceil(timestamp, amount, unit)
	local year, month, day, hour, minute, sec = strsplit(",", date("%Y,%m,%d,%H,%M,%S", timestamp) --[[@as string]])
	year = tonumber(year)
	month = tonumber(month)
	day = tonumber(day)
	hour = tonumber(hour)
	minute = tonumber(minute)
	sec = tonumber(sec)
	assert(year and month and day and hour and minute and sec)
	private.tempTimeTable.year = year
	private.tempTimeTable.month = month
	private.tempTimeTable.day = day
	private.tempTimeTable.hour = hour
	private.tempTimeTable.min = minute
	private.tempTimeTable.sec = sec
	if unit == "MONTH" then
		private.tempTimeTable.month = private.tempTimeTable.month + amount
		private.tempTimeTable.day = 1
		private.tempTimeTable.hour = 0
		private.tempTimeTable.min = 0
		private.tempTimeTable.sec = 0
	elseif unit == "DAY" then
		private.tempTimeTable.day = private.tempTimeTable.day + amount
		if private.tempTimeTable.hour == 23 then
			-- Add an extra hour to avoid DST issues
			private.tempTimeTable.hour = 1
		else
			private.tempTimeTable.hour = 0
		end
		private.tempTimeTable.min = 0
		private.tempTimeTable.sec = 0
	elseif unit == "HOUR" then
		private.tempTimeTable.hour = private.tempTimeTable.hour + amount
		private.tempTimeTable.min = 0
		private.tempTimeTable.sec = 0
	else
		error("Unknown unit: "..tostring(unit))
	end
	local result = time(private.tempTimeTable)
	assert(result > timestamp)
	wipe(private.tempTimeTable)
	return result
end

---Rounds a timestamp down.
---@param timestamp number The time value in seconds since epoch
---@param unit "MONTH"|"DAY"|"HOUR" The unit of time to use
---@return number
function TimeUtil.Floor(timestamp, unit)
	local year, month, day, hour, minute, sec = strsplit(",", date("%Y,%m,%d,%H,%M,%S", timestamp) --[[@as string]])
	year = tonumber(year)
	month = tonumber(month)
	day = tonumber(day)
	hour = tonumber(hour)
	minute = tonumber(minute)
	sec = tonumber(sec)
	assert(year and month and day and hour and minute and sec)
	private.tempTimeTable.year = year
	private.tempTimeTable.month = month
	private.tempTimeTable.day = day
	private.tempTimeTable.hour = hour
	private.tempTimeTable.min = minute
	private.tempTimeTable.sec = sec
	if unit == "MONTH" then
		private.tempTimeTable.day = 1
		private.tempTimeTable.hour = 0
		private.tempTimeTable.min = 0
		private.tempTimeTable.sec = 0
	elseif unit == "DAY" then
		private.tempTimeTable.hour = 0
		private.tempTimeTable.min = 0
		private.tempTimeTable.sec = 0
	elseif unit == "HOUR" then
		private.tempTimeTable.min = 0
		private.tempTimeTable.sec = 0
	else
		error("Unknown unit: "..tostring(unit))
	end
	local result = time(private.tempTimeTable)
	wipe(private.tempTimeTable)
	if result > timestamp then
		result = result - SECONDS_PER_HOUR
	end
	return result
end

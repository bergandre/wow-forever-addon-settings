-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local TimeUtil = App:From("LibTSMWoW"):Include("UI.TimeUtil")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}
local MAX_NEWS_AGE = 30 * 24 * 60 * 60



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardFeed = UIElements.Define("DashboardFeed", "BaseScrollFrame")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DashboardFeed:__init()
	self.__super:__init()
	self._query = nil ---@type DatabaseQuery!
	self._news = {} ---@type AppInfoNewsEntry[]
	self._nextNewsIndex = 1
	self._lastDayStart = nil ---@type number?
	self._numEntries = 0
end

function DashboardFeed:Release()
	local query = self._query
	self._query = nil
	wipe(self._news)
	self._nextNewsIndex = 1
	self._lastDayStart = nil
	self._numEntries = 0
	self.__super:Release()
	if query then
		query:Release()
	end
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the news entries to show in the feed.
---@param news? AppInfoNewsEntry[] The news entries
---@return self
function DashboardFeed:SetNews(news)
	assert(not self._query)
	wipe(self._news)
	if news then
		local minTime = App.GetTime() - MAX_NEWS_AGE
		for _, entry in ipairs(news) do
			if entry.timestamp >= minTime then
				tinsert(self._news, entry)
			end
		end
		sort(self._news, private.NewsSortComparator)
	end
	return self
end

---Sets the activity query used to populate the feed.
---@param query DatabaseQuery The query object
---@return self
function DashboardFeed:SetQuery(query)
	assert(not self._query)
	self._query = query
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DashboardFeed.__private:_HandleQueryUpdate()
	self:ReleaseAllChildren()
	self._nextNewsIndex = 1
	self._lastDayStart = nil
	self._numEntries = 0
	for _, id, player, timestamp, dayStart, net in self._query:Iterator("id", "player", "time", "dayStart", "net") do
		self:_AddNewsEntries(timestamp)
		self:_AddEntry(dayStart, UIElements.New("DashboardActivityEntry", "activity"..id)
			:Configure(id, player, timestamp, net)
		)
	end
	self:_AddNewsEntries()
	if self._numEntries == 0 then
		self:AddChild(UIElements.New("Text", "empty")
			:SetHeight(20)
			:SetFont("BODY_XSMALL")
			:SetTextColor("on/surface/low")
			:SetJustifyH("CENTER")
			:SetText(L["No recent activity"])
		)
	end
	self:Draw()
end

---@param minTime? number The minimum timestamp of news entries to add
function DashboardFeed.__private:_AddNewsEntries(minTime)
	local entry = self._news[self._nextNewsIndex]
	while entry and (not minTime or entry.timestamp >= minTime) do
		self:_AddEntry(TimeUtil.Floor(entry.timestamp, "DAY"), UIElements.New("DashboardNewsEntry", "news"..self._nextNewsIndex)
			:Configure(entry)
		)
		self._nextNewsIndex = self._nextNewsIndex + 1
		entry = self._news[self._nextNewsIndex]
	end
end

function DashboardFeed.__private:_AddEntry(dayStart, entry)
	self._numEntries = self._numEntries + 1
	if dayStart == self._lastDayStart then
		entry:SetMargin(0, 0, 8, 0)
	else
		self:AddChild(UIElements.New("Text", "day"..self._numEntries)
			:SetHeight(20)
			:SetMargin(0, 0, self._lastDayStart and 16 or 0, 4)
			:SetFont("BODY_SMALL")
			:SetText(private.GetDayText(dayStart))
		)
		self._lastDayStart = dayStart
	end
	self:AddChild(entry)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NewsSortComparator(a, b)
	return a.timestamp > b.timestamp
end

function private.GetDayText(dayStart)
	local today = TimeUtil.Floor(App.GetTime(), "DAY")
	if dayStart == today then
		return L["Today"]
	elseif dayStart == TimeUtil.Floor(today - 1, "DAY") then
		return L["Yesterday"]
	end
	return TimeFormat.Weekday(dayStart)..", "..TimeFormat.MonthDay(dayStart)
end

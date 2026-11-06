-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local SIZE = 22
local TEXT_LOOKUP = {
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_DAY] = L["1D"],
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_WEEK] = L["1W"],
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_MONTH] = L["1M"],
	[EnumTypes.DASHBOARD_TIME_RANGE.THREE_MONTH] = L["3M"],
	[EnumTypes.DASHBOARD_TIME_RANGE.SIX_MONTH] = L["6M"],
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_YEAR] = L["1Y"],
	[EnumTypes.DASHBOARD_TIME_RANGE.TWO_YEAR] = L["2Y"],
	[EnumTypes.DASHBOARD_TIME_RANGE.ALL] = GlobalStrings.Get("ALL"),
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardTimeButton = UIElements.Define("DashboardTimeButton", "BaseButton")
DashboardTimeButton._STATE_SCHEMA = DashboardTimeButton._STATE_SCHEMA:Extend("DashboardTimeButtonState")
	:AddOptionalEnumField("timeRange", EnumTypes.DASHBOARD_TIME_RANGE)
	:AddBooleanField("selected", false)
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DashboardTimeButton:__init()
	self.__super:__init()
	self._selectedBackground = self:_CreateRectangle()
	self._selectedBackground:SetCornerRadius(SIZE / 2)
	self._selectedBackground:SubscribeColor(self:_GetOneShotPublisher("accent/main"))
	self._selectedBackground:SetShown(self._state:Publisher("selected"))
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DashboardTimeButton:Acquire()
	self.__super:Acquire()
	self
		:SetFont("BODY_XSMALL")
		:SetSize(SIZE, SIZE)
	for _ in self._state:WithAutoStorePaused() do
		self
			:SetTextColor(self._state:Publisher("selected"):ReplaceBooleanWith("on/accent", "on/surface"))
			:SetText(self._state:Publisher("timeRange"):CoalesceNil(EnumTypes.DASHBOARD_TIME_RANGE.ALL):Map(TEXT_LOOKUP))
	end
end

---Configures the button.
---@param timeRange EnumValue The time range
---@param publisher ReactivePublisherSchemaBase The publisher for the selected time range
---@return DashboardTimeButton
function DashboardTimeButton:Configure(timeRange, publisher)
	assert(not self._state.timeRange)
	self._state.timeRange = timeRange
	return self:_AssignStateKeyPublisher(publisher:ToBooleanEquals(timeRange), "selected")
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function DashboardTimeButton.__protected:_HandleClick()
	assert(self._state.timeRange)
	self:_SendActionScript("OnClick", self._state.timeRange)
end

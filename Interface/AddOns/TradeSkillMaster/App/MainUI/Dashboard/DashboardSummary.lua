-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}
local GOLD_ROUNDING_VALUE = App.IsRetail() and 10000 or 1



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardSummary = UIElements.Define("DashboardSummary", "BaseFrame")
DashboardSummary._STATE_SCHEMA = DashboardSummary._STATE_SCHEMA:Extend("DashboardSummaryState")
	:AddOptionalNumberField("rangeHigh")
	:AddOptionalNumberField("rangeLow")
	:AddNumberField("dailySales", 0)
	:AddNumberField("dailyChange", 0)
	:AddNumberField("topSale", 0)
	:AddNumberField("topBuy", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DashboardSummary:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("HORIZONTAL")
		:SetPadding(8, 8, 4, 4)
	for _ in self._state:WithAutoStorePaused() do
		self
			:AddChild(UIElements.New("BaseFrame", "range")
				:SetLayout("VERTICAL")
				:SetMargin(0, 8, 0, 0)
				:SetPadding(0, 8, 0, 0)
				:AddChild(private.CreateRow("high", L["52W HIGH"], self._state:Publisher("rangeHigh"):MapNonNil(Money.ToStringForUIShort):CoalesceNil("-")))
				:AddChild(private.CreateRow("low", L["52W LOW"], self._state:Publisher("rangeLow"):MapNonNil(Money.ToStringForUIShort):CoalesceNil("-"))
					:SetMargin(0, 0, 2, 0)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "daily")
				:SetLayout("VERTICAL")
				:SetMargin(0, 8, 0, 0)
				:SetPadding(0, 8, 0, 0)
				:AddChild(private.CreateRow("sales", L["AVG DAILY SALES"], self._state:Publisher("dailySales"):Map(Math.Round, 0.1)))
				:AddChild(private.CreateRow("change", L["DAILY CHANGE"], self._state:Publisher("dailyChange"):Map(Math.Round, GOLD_ROUNDING_VALUE):Map(Money.ToStringForUIShort))
					:SetMargin(0, 0, 2, 0)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "top")
				:SetLayout("VERTICAL")
				:AddChild(private.CreateRow("sale", L["TOP SALE"], self._state:Publisher("topSale"):Map(Math.Round, GOLD_ROUNDING_VALUE):Map(Money.ToStringForUIShort)))
				:AddChild(private.CreateRow("buy", L["TOP PURCHASE"], self._state:Publisher("topBuy"):Map(Math.Round, GOLD_ROUNDING_VALUE):Map(Money.ToStringForUIShort))
					:SetMargin(0, 0, 2, 0)
				)
			)
	end
end

---Sets the 52 week range.
---@param low? number The low value of the range
---@param high? number The high value of the range
---@return self
function DashboardSummary:SetRange(low, high)
	self._state.rangeLow = low
	self._state.rangeHigh = high
	return self
end

---Sets the average number of daily sales.
---@param sales number The average number of daily sales
---@return self
function DashboardSummary:SetDailySales(sales)
	self._state.dailySales = sales
	return self
end

---Sets the change in gold over the last day.
---@param change number The change in gold
---@return self
function DashboardSummary:SetDailyChange(change)
	self._state.dailyChange = change
	return self
end

---Sets the top amounts.
---@param sale number The top sale amount
---@param buy number The top buy amount
---@return self
function DashboardSummary:SetTopValues(sale, buy)
	self._state.topSale = sale
	self._state.topBuy = buy
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param name string
---@param label string
---@param valuePublisher ReactivePublisherSchemaBase
---@return BaseFrame
function private.CreateRow(name, label, valuePublisher)
	return UIElements.New("BaseFrame", name)
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:AddChild(UIElements.New("Text", "label")
			:SetWidth("AUTO")
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(label)
		)
		:AddChild(UIElements.New("Text", "value")
			:SetMargin(8, 0, 0, 0)
			:SetFont("BODY_SMALL")
			:SetTextColor("accent/main")
			:SetJustifyH("RIGHT")
			:SetText(valuePublisher)
		)
end

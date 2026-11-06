-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Dashboard = App:Init("MainUI.Dashboard")
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local MoneyFormatter = App:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local TimeUtil = App:From("LibTSMWoW"):Include("UI.TimeUtil")
local AppHelper = App:From("LibTSMService"):Include("AppHelper")
local Activity = App:From("LibTSMService"):Include("Ledger.Activity")
local GoldTracker = App:From("LibTSMService"):Include("Ledger.GoldTracker")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Accounting = App:From("LibTSMApp"):Include("Accounting")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
	showDelayTimer = nil,
	characterGuilds = {},
	unselectedCharacterTemp = {},
	detailsInfoTemp = {
		sale = {
			total = {},
			totalAmount = 0,
			totalQuantity = 0,
			topValue = 0,
			topItem = nil,
			amountPerDay = nil, ---@type number!
		},
		buy = {
			total = {},
			totalAmount = 0,
			totalQuantity = 0,
			topValue = 0,
			topItem = nil,
			amountPerDay = nil, ---@type number!
		},
		isFree = true,
	},
}
local COPPER_PER_GOLD = 100 * 100
local SECONDS_PER_DAY = 60 * 60 * 24
local GOLD_STATS_PERIOD = SECONDS_PER_DAY * 7 * 52
local GOLD_STATS_SAMPLE_INTERVAL = 60 * 60 * 6
local MIN_GRAPH_STEP_SIZE = App.IsRetail() and (COPPER_PER_GOLD * 1000) or COPPER_PER_GOLD
local TIME_RANGE_LOOKUP = {
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_DAY] = SECONDS_PER_DAY,
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_WEEK] = SECONDS_PER_DAY * 7,
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_MONTH] = SECONDS_PER_DAY * 30,
	[EnumTypes.DASHBOARD_TIME_RANGE.THREE_MONTH] = SECONDS_PER_DAY * 91,
	[EnumTypes.DASHBOARD_TIME_RANGE.SIX_MONTH] = SECONDS_PER_DAY * 183,
	[EnumTypes.DASHBOARD_TIME_RANGE.ONE_YEAR] = SECONDS_PER_DAY * 365,
	[EnumTypes.DASHBOARD_TIME_RANGE.TWO_YEAR] = SECONDS_PER_DAY * 730,
	[EnumTypes.DASHBOARD_TIME_RANGE.ALL] = -1,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("DashboardUIState")
	:AddDeferredUIElementField("frame", "DividedContainer")
	:AddDeferredUIElementField("goldHeader", "BaseFrame")
	:AddDeferredUIElementField("goldGraph", "Graph")
	:AddDeferredUIElementField("summary", "DashboardSummary")
	:AddDeferredUIElementField("playerDropdown", "MultiselectionDropdown")
	:AddEnumField("selectedTimeRange", EnumTypes.DASHBOARD_TIME_RANGE, EnumTypes.DASHBOARD_TIME_RANGE.ALL)
	:AddBooleanField("manualZoomSet", false)
	:AddOptionalNumberField("hoverTime")
	:AddNumberField("totalSale", 0)
	:AddNumberField("avgSale", 0)
	:AddOptionalNumberField("saleChange")
	:AddOptionalStringField("topSaleItem")
	:AddNumberField("totalBuy", 0)
	:AddNumberField("avgBuy", 0)
	:AddOptionalNumberField("buyChange")
	:AddOptionalStringField("topBuyItem")
	:AddNumberField("totalProfit", 0)
	:AddNumberField("avgProfit", 0)
	:AddOptionalNumberField("profitChange")
	:Commit()

---@event DashboardAction
---| "ACTION_HANDLE_SHOW"
---| "ACTION_HANDLE_HIDE"
---| "ACTION_SET_TIME_RANGE" -> timeRange: EnumValue
---| "ACTION_RESET_ZOOM"
---| "ACTION_HANDLE_GRAPH_ZOOM_CHANGED"
---| "ACTION_HANDLE_GRAPH_HOVER_UPDATE" -> hoverTime?: number
---| "ACTION_HANDLE_PLAYERS_CHANGED"
---| "ACTION_UPDATE_GRAPH"
---| "ACTION_POPULATE_DETAILS"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Dashboard, function(db)
	private.settings = db:NewView("DashboardSettings")
		:AddKey("global", "mainUIContext", "dashboardDividedContainer")
		:AddKey("global", "mainUIContext", "dashboardUnselectedCharacters")
		:AddKey("global", "mainUIContext", "dashboardTimeRange")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("DASHBOARD", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_GRAPH_HOVER_UPDATE")
		:SuppressActionLog("ACTION_POPULATE_DETAILS")
		:SuppressActionLog("ACTION_UPDATE_GRAPH")
		:AddFrameBuilder(private.GetDashboardFrame)

	-- Mirror the time range with the settings
	state.selectedTimeRange = Table.KeyByValue(TIME_RANGE_LOOKUP, private.settings.dashboardTimeRange) or -1
	private.manager:AddCancellable(state:Publisher("selectedTimeRange")
		:Map(TIME_RANGE_LOOKUP)
		:AssignToTableKey(private.settings, "dashboardTimeRange")
	)

	private.showDelayTimer = DelayTimer.New("DASHBOARD_UPDATE_GRAPH_DELAY", private.manager:CallbackToProcessAction("ACTION_UPDATE_GRAPH"))
	private.manager:ProcessActionFromPublisher("ACTION_HANDLE_HIDE", state:Publisher("frame")
		:IgnoreIfNotEquals(nil)
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the dashboard frame.
---@return DividedContainer
function Dashboard.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Dashboard UI
-- ============================================================================

---@param state DashboardUIState
function private.GetDashboardFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "dashboard")

	state.manualZoomSet = false
	assert(not next(private.unselectedCharacterTemp))
	for characterGuild in pairs(private.settings.dashboardUnselectedCharacters) do
		private.unselectedCharacterTemp[characterGuild] = true
	end
	wipe(private.settings.dashboardUnselectedCharacters)
	wipe(private.characterGuilds)
	GoldTracker.GetCharacterGuilds(private.characterGuilds)
	for _, characterGuild in ipairs(private.characterGuilds) do
		private.settings.dashboardUnselectedCharacters[characterGuild] = private.unselectedCharacterTemp[characterGuild] or nil
	end
	wipe(private.unselectedCharacterTemp)

	local timeRangePublisher = state:Publisher("selectedTimeRange")
		:Share()
	local showTimeButtonsPublisher = state:Publisher("manualZoomSet")
		:InvertBoolean()
		:Share()
	return UIElements.New("DividedContainer", "dashboard")
		:SetSettingsContext(private.settings, "dashboardDividedContainer")
		:SetMinWidth(200, 407)
		:BindElement(state, "frame")
		:HideDivider()
		:SetManager(private.manager)
		:SetLeftChild(UIElements.New("BaseFrame", "feed")
			:SetLayout("VERTICAL")
			:SetMargin(0, 4, 0, 0)
			:SetPadding(8, 0, 8, 8)
			:SetRoundedBackgroundColor("container/medium")
			:AddChild(UIElements.New("Text", "text")
				:SetSize("AUTO", 24)
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(L["Activity Log"])
			)
			:AddChild(UIElements.New("DashboardFeed", "list")
				:SetMargin(0, 0, 16, 0)
				:SetPadding(0, 8, 0, 0)
				:SetNews(AppHelper.GetNews())
				:SetQuery(Activity.CreateQuery())
			)
		)
		:SetRightChild(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetMargin(10, 0, 0, 0)
			:SetPadding(0, 0, 16, 0)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:AddChild(UIElements.New("BaseFrame", "text")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Text", "text")
						:SetHeight(24)
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_BODY1_EXTRABOLD")
						:SetText(L["Player Gold"])
					)
					:AddChild(UIElements.New("Text", "text")
						:SetHeight(16)
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_XSMALL")
						:SetText(state:Publisher("hoverTime"):MapNonNil(TimeFormat.DateTime):CoalesceNil(TimeFormat.Date(App.GetTime())))
					)
				)
				:AddChild(UIElements.New("MultiselectionDropdown", "playerDropdown")
					:SetSize(160, 24)
					:SetMargin(0, 0, 8, 8)
					:BindElement(state, "playerDropdown")
					:SetItems(private.characterGuilds, private.characterGuilds)
					:SetUnselectedItemKeys(private.settings.dashboardUnselectedCharacters)
					:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
					:SetHintText(L["Select characters"])
					:SetAction("OnSelectionChanged", "ACTION_HANDLE_PLAYERS_CHANGED")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "goldHeader")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 20, 0)
				:SetPadding(0, 8, 0, 0)
				:BindElement(state, "goldHeader")
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("BaseFrame", "timeBtns")
					:SetLayout("HORIZONTAL")
					:AddChild(UIElements.New("DashboardTimeButton", "1d")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.ONE_DAY, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "1w")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.ONE_WEEK, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "1m")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.ONE_MONTH, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "3m")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.THREE_MONTH, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "6m")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.SIX_MONTH, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "1y")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.ONE_YEAR, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "2y")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.TWO_YEAR, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("DashboardTimeButton", "all")
						:SetMargin(6, 0, 0, 0)
						:Configure(EnumTypes.DASHBOARD_TIME_RANGE.ALL, timeRangePublisher)
						:SetAction("OnClick", "ACTION_SET_TIME_RANGE")
						:SetShown(showTimeButtonsPublisher)
					)
					:AddChild(UIElements.New("SmallTertiaryActionButton", "resetZoom")
						:SetMargin(8, 0, 0, 0)
						:SetWidth(100)
						:SetText(L["Reset Zoom"])
						:SetAction("OnClick", "ACTION_RESET_ZOOM")
						:SetShown(showTimeButtonsPublisher:InvertBoolean())
					)
				)
			)
			:AddChild(UIElements.New("Graph", "goldGraph")
				:SetMargin(0, 0, 2, 16)
				:BindElement(state, "goldGraph")
				:SetAxisStepFunctions(private.GraphXStepFunc, private.GraphYStepFunc)
				:SetXRange(GoldTracker.GetGraphTimeRange(private.settings.dashboardUnselectedCharacters))
				:SetYValueFunction(private.GetGraphYValue)
				:SetFormatFunctions(private.GraphFormatX, private.GraphFormatY)
				:SetAction("OnZoomChanged", "ACTION_HANDLE_GRAPH_ZOOM_CHANGED")
				:SetAction("OnHoverUpdate", "ACTION_HANDLE_GRAPH_HOVER_UPDATE")
			)
			:AddChild(UIElements.New("DashboardSummary", "summary")
				:SetHeight(50)
				:SetMargin(0, 0, 0, 16)
				:BindElement(state, "summary")
			)
			:AddChild(UIElements.New("BaseFrame", "details")
				:SetLayout("VERTICAL")
				:SetPadding(8)
				:SetRoundedBackgroundColor("container/medium")
				:AddChild(UIElements.New("DashboardDetailsRow", "sale")
					:SetLabels(L["SALES"], L["Total Gold Earned"], L["Average Earned per Day"])
					:SetTotalAmount(state:Publisher("totalSale"))
					:SetAverageAmount(state:Publisher("avgSale"))
					:SetChange(state:Publisher("saleChange"))
					:SetTopItem(state:Publisher("topSaleItem"))
				)
				:AddChild(UIElements.New("DashboardDetailsRow", "buy")
					:SetMargin(0, 0, 12, 0)
					:SetLabels(L["EXPENSES"], L["Total Gold Spent"], L["Average Spent per Day"])
					:SetTotalAmount(state:Publisher("totalBuy"))
					:SetAverageAmount(state:Publisher("avgBuy"))
					:SetChange(state:Publisher("buyChange"))
					:InvertChangeColors()
					:SetTopItem(state:Publisher("topBuyItem"))
				)
				:AddChild(UIElements.New("DashboardDetailsRow", "profit")
					:SetMargin(0, 0, 12, 0)
					:SetLabels(L["PROFIT"], L["Total Profit"], L["Average Profit per Day"])
					:SetTotalAmount(state:Publisher("totalProfit"))
					:SetAverageAmount(state:Publisher("avgProfit"))
					:SetChange(state:Publisher("profitChange"))
				)
			)
		)
		:AddCancellable(timeRangePublisher:EndShare())
		:AddCancellable(showTimeButtonsPublisher:EndShare())
		:WithProcessAction("ACTION_HANDLE_SHOW")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<DashboardUIState>
---@param state DashboardUIState
---@param action DashboardAction
---@param ... params<DashboardAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_SHOW" then
		private.showDelayTimer:RunForFrames(0)
	elseif action == "ACTION_HANDLE_HIDE" then
		private.showDelayTimer:Cancel()
	elseif action == "ACTION_SET_TIME_RANGE" then
		local timeRange = ...
		state.selectedTimeRange = timeRange
		state.manualZoomSet = false
		state.goldHeader:Draw()
		return manager:ProcessAction("ACTION_UPDATE_GRAPH")
	elseif action == "ACTION_RESET_ZOOM" then
		state.selectedTimeRange = EnumTypes.DASHBOARD_TIME_RANGE.ALL
		state.manualZoomSet = false
		state.goldHeader:Draw()
		return manager:ProcessAction("ACTION_UPDATE_GRAPH")
	elseif action == "ACTION_HANDLE_GRAPH_ZOOM_CHANGED" then
		state.manualZoomSet = true
		state.goldHeader:Draw()
		return manager:ProcessAction("ACTION_POPULATE_DETAILS")
	elseif action == "ACTION_HANDLE_GRAPH_HOVER_UPDATE" then
		local hoverTime = ...
		state.hoverTime = hoverTime
		state.goldHeader:Draw()
	elseif action == "ACTION_HANDLE_PLAYERS_CHANGED" then
		for _, key in ipairs(private.characterGuilds) do
			private.settings.dashboardUnselectedCharacters[key] = not state.playerDropdown:ItemIsSelectedByKey(key) or nil
		end
		return manager:ProcessAction("ACTION_UPDATE_GRAPH")
	elseif action == "ACTION_UPDATE_GRAPH" then
		local minTime, maxTime, stepInterval = GoldTracker.GetGraphTimeRange(private.settings.dashboardUnselectedCharacters)
		local zoomStart, zoomEnd = state.goldGraph:GetZoom()
		if state.selectedTimeRange == EnumTypes.DASHBOARD_TIME_RANGE.ALL then
			zoomStart = minTime
			zoomEnd = maxTime
		elseif not state.manualZoomSet then
			local now = floor(App.GetTime())
			zoomStart = max(now - TIME_RANGE_LOOKUP[state.selectedTimeRange], minTime)
			zoomEnd = now
		end
		state.goldGraph:SetXRange(minTime, maxTime, stepInterval)
			:SetZoom(zoomStart, zoomEnd)
			:Draw()
		private.UpdateGoldStats(state, minTime, maxTime)
		return manager:ProcessAction("ACTION_POPULATE_DETAILS")
	elseif action == "ACTION_POPULATE_DETAILS" then
		private.PopulateDetails(state)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GraphFormatX(timestamp, suggestedStep)
	if suggestedStep > SECONDS_PER_DAY * 14 then
		return TimeFormat.MonthAndShortYear(timestamp)
	elseif suggestedStep > SECONDS_PER_DAY * 2 then
		return TimeFormat.MonthDay(timestamp)
	elseif suggestedStep > SECONDS_PER_DAY / 6 then
		return TimeFormat.Weekday(timestamp)
	else
		return TimeFormat.Time(timestamp)
	end
end

function private.GraphFormatY(value, isTooltip)
	if isTooltip then
		return Money.ToStringForUIShort(value)
	end
	if not App.IsRetail() and value < COPPER_PER_GOLD * 1000 then
		-- "###g"
		return floor(value / COPPER_PER_GOLD)..MoneyFormatter.GetGoldText()
	elseif not App.IsRetail() and value < COPPER_PER_GOLD * 1000 * 10 then
		-- "#.##Kg"
		return format("%.2f", value / (COPPER_PER_GOLD * 1000)).."k"..MoneyFormatter.GetGoldText()
	elseif value < COPPER_PER_GOLD * 1000 * 1000 then
		-- "###Kg"
		return floor(value / (COPPER_PER_GOLD * 1000)).."k"..MoneyFormatter.GetGoldText()
	elseif value < COPPER_PER_GOLD * 1000 * 1000 * 10 then
		-- "#.##Mg"
		return format("%.2f", value / (COPPER_PER_GOLD * 1000 * 1000)).."M"..MoneyFormatter.GetGoldText()
	else
		-- "###Mg"
		return floor(value / (COPPER_PER_GOLD * 1000 * 1000)).."M"..MoneyFormatter.GetGoldText()
	end
end

function private.GetGraphYValue(xValue)
	return GoldTracker.GetGoldAtTime(xValue, private.settings.dashboardUnselectedCharacters)
end

function private.GraphXStepFunc(prevValue, suggestedStep)
	if suggestedStep > SECONDS_PER_DAY * 14 then
		return TimeUtil.Ceil(prevValue, 1, "MONTH")
	elseif suggestedStep > SECONDS_PER_DAY / 6 then
		return TimeUtil.Ceil(prevValue, 1, "DAY")
	else
		return TimeUtil.Ceil(prevValue, 2, "HOUR")
	end
end

function private.GraphYStepFunc(mode, ...)
	if mode == "RANGE" then
		local yMin, yMax, maxNumSteps = ...
		-- find the smallest 10^X step size which still looks good
		local minStep = max((yMax - yMin) / maxNumSteps / 10, yMax / 200)
		local stepSize = MIN_GRAPH_STEP_SIZE
		while stepSize < minStep do
			stepSize = stepSize * 10
		end
		yMin = Math.Floor(yMin, stepSize)
		yMax = Math.Ceil(yMax + stepSize / 3, stepSize)
		if yMin == yMax then
			yMax = yMax + stepSize
		end
		return yMin, yMax
	elseif mode == "NEXT" then
		local prevValue, yMax = ...
		local stepSize = MIN_GRAPH_STEP_SIZE
		while stepSize < yMax / 1000 do
			stepSize = stepSize * 10
		end
		return Math.Floor(prevValue, stepSize) + stepSize
	else
		error("Invalid mode")
	end
end

---@param state DashboardUIState
---@param minTime number
---@param maxTime number
function private.UpdateGoldStats(state, minTime, maxTime)
	local unselectedCharacters = private.settings.dashboardUnselectedCharacters
	local currentValue = GoldTracker.GetGoldAtTime(maxTime, unselectedCharacters)
	local low, high = currentValue, currentValue
	for timestamp = max(maxTime - GOLD_STATS_PERIOD, minTime), maxTime, GOLD_STATS_SAMPLE_INTERVAL do
		local value = GoldTracker.GetGoldAtTime(timestamp, unselectedCharacters)
		low = min(low, value)
		high = max(high, value)
	end
	state.summary
		:SetRange(low, high)
		:SetDailyChange(currentValue - GoldTracker.GetGoldAtTime(max(maxTime - SECONDS_PER_DAY, minTime), unselectedCharacters))
end

---@param state DashboardUIState
function private.PopulateDetails(state)
	-- Get the number of days visible in the gold graph
	local unselectedCharacters = next(private.settings.dashboardUnselectedCharacters) and private.settings.dashboardUnselectedCharacters or nil
	local timeFilterStart, timeFilterEnd, numDays = nil, nil, nil
	if state.manualZoomSet then
		timeFilterStart, timeFilterEnd = state.goldGraph:GetZoom()
		numDays = ceil((timeFilterEnd - timeFilterStart) / SECONDS_PER_DAY)
	elseif state.selectedTimeRange == EnumTypes.DASHBOARD_TIME_RANGE.ALL then
		local timeStart, timeEnd = state.goldGraph:GetXRange()
		numDays = ceil((timeEnd - timeStart) / SECONDS_PER_DAY)
	else
		local timeRange = TIME_RANGE_LOOKUP[state.selectedTimeRange]
		local now = floor(App.GetTime())
		timeFilterStart = now - timeRange
		timeFilterEnd = now
		numDays = ceil(timeRange / SECONDS_PER_DAY)
	end
	numDays = max(numDays, 1)

	-- Get our temp table
	assert(private.detailsInfoTemp.isFree)
	private.detailsInfoTemp.isFree = nil
	local info = private.detailsInfoTemp

	-- Collect all the sale / buy info
	for _, recordType, itemString, price, quantity in Accounting.SummaryDataIterator(timeFilterStart, timeFilterEnd, unselectedCharacters) do
		local recordTypeInfo = info[recordType]
		assert(recordTypeInfo)
		recordTypeInfo.total[itemString] = (recordTypeInfo.total[itemString] or 0) + price * quantity
		recordTypeInfo.totalAmount = recordTypeInfo.totalAmount + price * quantity
		recordTypeInfo.totalQuantity = recordTypeInfo.totalQuantity + quantity
		recordTypeInfo.topValue = max(recordTypeInfo.topValue, price)
		if not recordTypeInfo.topItem or recordTypeInfo.total[itemString] > recordTypeInfo.total[recordTypeInfo.topItem] then
			recordTypeInfo.topItem = itemString
		end
	end
	for _, recordTypeInfo in pairs(info) do
		recordTypeInfo.amountPerDay = recordTypeInfo.totalAmount / numDays
	end

	-- Calculate the change from the previous period
	local saleChange, buyChange = nil, nil
	if timeFilterStart and timeFilterEnd then
		saleChange, buyChange = info.sale.totalAmount, info.buy.totalAmount
		for _, recordType, _, price, quantity in Accounting.SummaryDataIterator(timeFilterStart - (timeFilterEnd - timeFilterStart), timeFilterStart, unselectedCharacters) do
			if recordType == "sale" then
				saleChange = saleChange - price * quantity
			else
				buyChange = buyChange - price * quantity
			end
		end
	end

	-- Update the content
	state.summary
		:SetDailySales(info.sale.totalQuantity / numDays)
		:SetTopValues(info.sale.topValue, info.buy.topValue)
	state.totalSale = info.sale.totalAmount
	state.avgSale = info.sale.amountPerDay
	state.saleChange = saleChange
	state.topSaleItem = info.sale.topItem
	state.totalBuy = info.buy.totalAmount
	state.avgBuy = info.buy.amountPerDay
	state.buyChange = buyChange
	state.topBuyItem = info.buy.topItem
	state.totalProfit = info.sale.totalAmount - info.buy.totalAmount
	state.avgProfit = info.sale.amountPerDay - info.buy.amountPerDay
	state.profitChange = saleChange and buyChange and (saleChange - buyChange) or nil

	-- Reset the temp table
	for _, recordTypeInfo in pairs(info) do
		Table.WipeAndDeallocate(recordTypeInfo.total)
		recordTypeInfo.topValue = 0
		recordTypeInfo.totalQuantity = 0
		recordTypeInfo.totalAmount = 0
		recordTypeInfo.topItem = nil
		recordTypeInfo.amountPerDay = nil
	end
	info.isFree = true
end

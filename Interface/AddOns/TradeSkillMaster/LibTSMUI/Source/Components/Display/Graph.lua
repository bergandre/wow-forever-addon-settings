-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local LINE_TEXTURE = "Interface\\AddOns\\TradeSkillMaster\\Media\\line_soft.png"
local PLOT_X_LABEL_WIDTH = 48
local PLOT_X_LABEL_HEIGHT = 16
local PLOT_X_LABEL_MARGIN = 6
local PLOT_Y_LABEL_WIDTH = 48
local PLOT_Y_LABEL_HEIGHT = 16
local PLOT_Y_LABEL_MARGIN = 4
local PLOT_HIGHLIGHT_TEXT_WIDTH = 80
local PLOT_HIGHLIGHT_TEXT_HEIGHT = 16
local PLOT_X_EXTRA_HIT_RECT = 4
local PLOT_Y_MARGIN = 4
local LINE_THICKNESS = 3
local AXIS_LINE_THICKNESS = 1
local PLOT_MIN_X_LINE_SPACING = PLOT_X_LABEL_WIDTH * 1.5 + 8
local PLOT_MIN_Y_LINE_SPACING = PLOT_Y_LABEL_HEIGHT * 1.5 + 8
local HOVER_LINE_THICKNESS = 1
local SELECTION_ALPHA = 0.2
local MAX_PLOT_POINTS = 300

---@alias GraphXStepFunc fun(prev: number, suggestedStep: number): number
---@alias GraphYStepFunc fun(mode: "RANGE"|"NEXT", ...: any): number, number?
---@alias GraphYValueFunc fun(x: number): number
---@alias GraphXFormatFunc fun(x: number, suggestedStep: number): string
---@alias GraphYFormatFunc fun(y: number, isTooltip?: boolean): string



-- ============================================================================
-- Element Definition
-- ============================================================================

local Graph = ComponentRegistry.Define("Graph", "Element")
Graph._STATE_SCHEMA = Graph._STATE_SCHEMA:Extend("GraphState")
	:AddBooleanField("mouseOver", false)
	:AddOptionalNumberField("selectionStartX")
	:AddBooleanField("hovered", false)
	:Commit()
Graph:_AddActionScripts("OnZoomChanged", "OnHoverUpdate")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Graph:__init()
	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)

	self._lines = {} ---@type Line[]
	self._xAxisLabels = {}
	self._yAxisLines = {}
	self._xValuesFiltered = {}
	self._yLookup = {}
	self._xAxisValues = {}
	self._yAxisValues = {}
	self._yValueFunc = nil ---@type GraphYValueFunc!
	self._xFormatFunc = nil ---@type GraphXFormatFunc!
	self._yFormatFunc = nil ---@type GraphYFormatFunc!
	self._xStepFunc = nil ---@type GraphXStepFunc!
	self._yStepFunc = nil ---@type GraphYStepFunc!
	self._xMin = nil ---@type number!
	self._xMax = nil ---@type number!
	self._xStepInterval = nil ---@type number!
	self._yMin = nil ---@type number!
	self._yMax = nil ---@type number!
	self._zoomStart = nil ---@type number!
	self._zoomEnd = nil ---@type number!

	self._frame:TSMSubscribeBackdropColor(self:_GetOneShotPublisher("container/lowest"))

	self._plot = self:_CreateFrame()
	self._plot:SetPoint("BOTTOMLEFT", PLOT_Y_LABEL_WIDTH, PLOT_X_LABEL_HEIGHT)
	self._plot:SetPoint("TOPRIGHT", -PLOT_X_EXTRA_HIT_RECT, -PLOT_HIGHLIGHT_TEXT_HEIGHT - PLOT_Y_MARGIN)
	self._plot:SetHitRectInsets(-PLOT_X_EXTRA_HIT_RECT, -PLOT_X_EXTRA_HIT_RECT, 0, 0)
	self._plot:EnableMouse(true)
	self._plot:TSMSetScript("OnEnter", self:__closure("_HandlePlotEnter"))
	self._plot:TSMSetScript("OnLeave", self:__closure("_HandlePlotLeave"))
	self._plot:TSMSetScript("OnMouseDown", self:__closure("_HandlePlotMouseDown"))
	self._plot:TSMSetScript("OnMouseUp", self:__closure("_HandlePlotMouseUp"))

	self._plot.dot = self:_CreateTexture(self._plot, "ARTWORK", 3)
	self._plot.dot:TSMSetTextureAndSize("uiFrames.HighlightDot")

	self._plot.hoverLine = self:_CreateTexture(self._plot, "ARTWORK", 2)
	self._plot.hoverLine:SetWidth(HOVER_LINE_THICKNESS)
	self._plot.hoverLine:TSMSubscribeColorTexture(self:_GetOneShotPublisher("accent/main"))
	self._plot.hoverLine:Hide()

	self._plot.hoverText = self:_CreateFontString(self._plot)
	self._plot.hoverText:SetSize(PLOT_HIGHLIGHT_TEXT_WIDTH, PLOT_HIGHLIGHT_TEXT_HEIGHT)
	self._plot.hoverText:TSMSetFont("TABLE_XSMALL")
	self._plot.hoverText:TSMSubscribeTextColor(self:_GetOneShotPublisher("accent/main"))
	self._plot.hoverText:Hide()

	self._plot.selectionBox = self:_CreateTexture(self._plot, "ARTWORK", 2)
	self._plot.selectionBox:Hide()

	-- Computed state properties
	self._state:Publisher([[(mouseOver or selectionStartX) and true or false]])
		:AssignToTableKey(self._state, "hovered")
end

function Graph:Release()
	wipe(self._xValuesFiltered)
	wipe(self._yLookup)
	wipe(self._xAxisValues)
	wipe(self._yAxisValues)
	self._yValueFunc = nil
	self._xFormatFunc = nil
	self._yFormatFunc = nil
	self._xStepFunc = nil
	self._yStepFunc = nil
	self._xMin = nil
	self._xMax = nil
	self._xStepInterval = nil
	self._yMin = nil
	self._yMax = nil
	self._zoomStart = nil
	self._zoomEnd = nil
	self.__super:Release()
end

---Sets the step size of the axes.
---@param x GraphXStepFunc A function which gets the next x-axis step value
---@param y GraphYStepFunc A function which gets the next y-axis step value
---@return self
function Graph:SetAxisStepFunctions(x, y)
	self._xStepFunc = x
	self._yStepFunc = y
	return self
end

---Sets the visible X-axis range.
---@param xMin number The minimum x value
---@param xMax number The maximum x value
---@param stepInterval number The step interval
---@return self
function Graph:SetXRange(xMin, xMax, stepInterval)
	assert(xMin <= xMax)
	self._xMin = xMin
	self._xMax = xMax
	self._xStepInterval = stepInterval
	self._zoomStart = xMin
	self._zoomEnd = xMax
	return self
end

---Sets the current zoom window.
---@param zoomStart number The start x value
---@param zoomEnd number The end x value
---@return self
function Graph:SetZoom(zoomStart, zoomEnd)
	self._zoomStart = zoomStart
	self._zoomEnd = zoomEnd
	return self
end

---Gets the current zoom window.
---@return number zoomStart
---@return number zoomEnd
function Graph:GetZoom()
	return self._zoomStart, self._zoomEnd
end

---Gets the current X range.
---@return number xMin
---@return number xMax
function Graph:GetXRange()
	local yMin, yMax = nil, nil
	for _, x in ipairs(self._xValuesFiltered) do
		local y = self._yValueFunc(x)
		yMin = min(yMin or math.huge, y)
		yMax = max(yMax or -math.huge, y)
	end
	return self._xMin, self._xMax
end

---Gets the current Y range.
---@return number yMin
---@return number yMax
function Graph:GetYRange()
	local yMin, yMax = nil, nil
	for _, x in ipairs(self._xValuesFiltered) do
		local y = self._yValueFunc(x)
		yMin = min(yMin or math.huge, y)
		yMax = max(yMax or -math.huge, y)
	end
	return yMin, yMax
end

---Set the function used to get the y value for a given x value.
---@param func GraphYValueFunc The function
---@return self
function Graph:SetYValueFunction(func)
	self._yValueFunc = func
	return self
end

---Sets functions for formatting values.
---@param xFormatFunc GraphXFormatFunc A function which formats an x value
---@param yFormatFunc GraphYFormatFunc A function which formats a y value
---@return self
function Graph:SetFormatFunctions(xFormatFunc, yFormatFunc)
	self._xFormatFunc = xFormatFunc
	self._yFormatFunc = yFormatFunc
	return self
end

function Graph:Draw()
	self.__super:Draw()
	local plot = self._plot
	local plotWidth = plot:GetWidth()
	local plotHeight = plot:GetHeight()

	-- Compute all of our data
	if not self:_ComputeData(plotWidth, plotHeight) then
		return
	end

	-- Create Y axis lines as needed and hide any extra
	while #self._yAxisLines < #self._yAxisValues do
		tinsert(self._yAxisLines, self:_CreateAxisLine())
	end
	for i = #self._yAxisValues + 1, #self._yAxisLines do
		local line = self._yAxisLines[i]
		line:Hide()
		line.text:Hide()
	end

	-- Draw the y axis lines and labels
	for i, value in ipairs(self._yAxisValues) do
		local offset = Math.Scale(value, self._yMin, self._yMax, 0, plotHeight)
		local line = self._yAxisLines[i]
		line:Show()
		line.text:Show()
		self:_DrawYAxisLine(line, offset, value, plotWidth, plotHeight)
	end

	-- Create X axis labels as needed and hide any extra
	while #self._xAxisLabels < #self._xAxisValues do
		tinsert(self._xAxisLabels, self:_CreateAxisLabel())
	end
	for i = #self._xAxisValues + 1, #self._xAxisLabels do
		self._xAxisLabels[i]:Hide()
	end

	-- Draw the x axis labels
	local xSuggestedStep = Math.Scale(PLOT_MIN_X_LINE_SPACING, 0, plotWidth, 0, self._zoomEnd - self._zoomStart)
	for i, value in ipairs(self._xAxisValues) do
		local offset = Math.Scale(value, self._zoomStart, self._zoomEnd, 0, plotWidth)
		local label = self._xAxisLabels[i]
		label:Show()
		self:_DrawXAxisLabel(label, offset, value, plotWidth, xSuggestedStep)
	end

	-- Create slices as needed and hide any extra slices
	local numVisibleSlices = #self._xValuesFiltered - 1
	while #self._lines < numVisibleSlices do
		local line = self._plot:CreateLine(nil, "ARTWORK")
		line:SetTexture(LINE_TEXTURE)
		tinsert(self._lines, line)
	end
	for i = numVisibleSlices + 1, #self._lines do
		self._lines[i]:Hide()
	end

	-- Draw all the slices
	local color = nil
	if self._state.hovered then
		color = "accent/main"
	elseif self._yLookup[self._xValuesFiltered[1]] <= self._yLookup[self._xValuesFiltered[#self._xValuesFiltered]] then
		color = "positive/main"
	else
		color = "error/main"
	end
	local xPrev, yPrev = nil, nil
	for i, x in ipairs(self._xValuesFiltered) do
		local y = self._yLookup[x]
		local xCoord = Math.Scale(x, self._zoomStart, self._zoomEnd, 0, plotWidth)
		local yCoord = Math.Scale(y, self._yMin, self._yMax, 0, plotHeight)
		if i > 1 then
			local line = self._lines[i - 1]
			line:Show()
			line:SetThickness(LINE_THICKNESS)
			line:SetStartPoint("BOTTOMLEFT", self._plot, xPrev, yPrev)
			line:SetEndPoint("BOTTOMLEFT", self._plot, xCoord, yCoord)
			line:SetVertexColor(Theme.GetColor(color):GetFractionalRGBA())
		end
		xPrev = xCoord
		yPrev = yCoord
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Graph.__private:_ComputeData(plotWidth, plotHeight)
	wipe(self._xValuesFiltered)
	wipe(self._yLookup)
	wipe(self._xAxisValues)
	wipe(self._yAxisValues)
	self._yMin = math.huge
	self._yMax = -math.huge
	local minStep = Math.Ceil((self._zoomEnd - self._zoomStart) / min(plotWidth / 3, MAX_PLOT_POINTS), self._xStepInterval)
	local x = self._zoomStart
	assert(x)
	while x <= self._zoomEnd do
		local prevX = self._xValuesFiltered[#self._xValuesFiltered]
		if not prevX or x == self._zoomEnd or (x - prevX > minStep and self._zoomEnd - x > minStep) then
			-- this is either the first / last point or a middle point which is sufficiently far from the previous and last points
			tinsert(self._xValuesFiltered, x)
			local y = self._yValueFunc(x)
			self._yMin = min(self._yMin, y)
			self._yMax = max(self._yMax, y)
			self._yLookup[x] = y
		end
		if x == self._zoomEnd then
			break
		end
		x = min(x + minStep, self._zoomEnd)
	end

	-- Calculate the min and max y values which should be shown
	self._yMin, self._yMax = self._yStepFunc("RANGE", self._yMin, self._yMax, floor(plotHeight / PLOT_MIN_Y_LINE_SPACING))
	if Math.IsNan(self._yMax) then
		-- This happens when we're resizing the application frame
		return false
	end

	-- Calculate the Y axis values
	local prevYAxisOffset = -math.huge
	local yAxisValue = self._yMin
	while yAxisValue <= self._yMax do
		local yAxisOffset = Math.Scale(yAxisValue, self._yMin, self._yMax, 0, plotHeight)
		if not prevYAxisOffset or (yAxisOffset - prevYAxisOffset) >= PLOT_MIN_Y_LINE_SPACING then
			tinsert(self._yAxisValues, yAxisValue)
			prevYAxisOffset = yAxisOffset
		end
		yAxisValue = self._yStepFunc("NEXT", yAxisValue, self._yMax)
	end

	-- Calculate the X axis values
	local xSuggestedStep = Math.Scale(PLOT_MIN_X_LINE_SPACING, 0, plotWidth, 0, self._zoomEnd - self._zoomStart)
	local prevXAxisOffset = -math.huge
	local xAxisValue = self._xStepFunc(self._zoomStart, xSuggestedStep)
	while xAxisValue <= self._zoomEnd do
		local xAxisOffset = Math.Scale(xAxisValue, self._zoomStart, self._zoomEnd, 0, plotWidth)
		if not prevXAxisOffset or (xAxisOffset - prevXAxisOffset) > PLOT_MIN_X_LINE_SPACING then
			tinsert(self._xAxisValues, xAxisValue)
			prevXAxisOffset = xAxisOffset
		end
		xAxisValue = self._xStepFunc(xAxisValue, xSuggestedStep)
	end

	return true
end

function Graph.__private:_CreateAxisLine()
	local plot = self._plot
	local line = plot:CreateLine(nil, "BACKGROUND")
	line:SetTexture(LINE_TEXTURE)
	line:SetThickness(AXIS_LINE_THICKNESS)
	line:SetVertexColor(Theme.GetColor("outline/variant"):GetFractionalRGBA())
	line.text = self:_CreateFontString(plot) ---@diagnostic disable-line: inject-field
	line.text:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface", true))
	line.text:SetSize(PLOT_Y_LABEL_WIDTH, PLOT_Y_LABEL_HEIGHT)
	line.text:TSMSetFont("TABLE_XSMALL")
	line.text:SetJustifyH("RIGHT")
	return line
end

function Graph.__private:_CreateAxisLabel()
	local label = self:_CreateFontString(self._plot)
	label:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface", true))
	label:SetSize(PLOT_X_LABEL_WIDTH, PLOT_X_LABEL_HEIGHT)
	label:TSMSetFont("BODY_XSMALL")
	label:SetJustifyV("TOP")
	return label
end

function Graph.__private:_DrawYAxisLine(line, offset, value, plotWidth, plotHeight)
	line:SetStartPoint("BOTTOMLEFT", self._plot, 0, offset)
	line:SetEndPoint("BOTTOMLEFT", self._plot, plotWidth, offset)
	local textOffset = 0
	if PLOT_Y_LABEL_HEIGHT / 2 > offset then
		line.text:SetJustifyV("BOTTOM")
		textOffset = max(PLOT_Y_LABEL_HEIGHT / 2 - offset, 0)
	elseif offset + PLOT_Y_LABEL_HEIGHT / 2 > plotHeight then
		line.text:SetJustifyV("TOP")
		textOffset = plotHeight - offset - PLOT_Y_LABEL_HEIGHT / 2
	else
		line.text:SetJustifyV("MIDDLE")
	end
	line.text:SetPoint("RIGHT", self._plot, "BOTTOMLEFT", -PLOT_Y_LABEL_MARGIN, offset + textOffset)
	line.text:SetText(self._yFormatFunc(value))
end

function Graph.__private:_DrawXAxisLabel(label, offset, value, plotWidth, suggestedStep)
	local textOffset = 0
	if PLOT_X_LABEL_WIDTH / 2 > offset then
		label:SetJustifyH("LEFT")
		textOffset = max(PLOT_X_LABEL_WIDTH / 2 - offset, 0)
	elseif offset + PLOT_X_LABEL_WIDTH / 2 > plotWidth then
		label:SetJustifyH("RIGHT")
		textOffset = plotWidth - offset - PLOT_X_LABEL_WIDTH / 2
	else
		label:SetJustifyH("CENTER")
	end
	label:SetPoint("TOP", self._plot, "BOTTOMLEFT", offset + textOffset, -PLOT_X_LABEL_MARGIN)
	label:SetText(self._xFormatFunc(value, suggestedStep))
end

function Graph.__private:_GetCursorClosestPoint()
	local xPos = GetCursorPosition() / self._plot:GetEffectiveScale()
	local fromMin = self._plot:GetLeft()
	local fromMax = self._plot:GetRight()
	-- Convert the cursor position to be relative to the plotted x values
	xPos = Math.Scale(Math.Bound(xPos, fromMin, fromMax), fromMin, fromMax, self._zoomStart, self._zoomEnd)
	-- Find the closest point to the cursor (based on the x distance)
	local closestX, closestY = nil, nil
	for _, x in ipairs(self._xValuesFiltered) do
		local y = self._yLookup[x]
		local xDist = abs(x - xPos)
		if not closestX or xDist < abs(closestX - xPos) then
			closestX = x
			closestY = y
		end
	end
	assert(closestY)
	return closestX, closestY
end

function Graph.__private:_XValueToPlotCoord(xValue)
	return Math.Scale(xValue, self._zoomStart, self._zoomEnd, 0, self._plot:GetWidth())
end

function Graph.__private:_HandlePlotEnter()
	self._state.mouseOver = true
	self:Draw()
	self._plot:TSMSetScript("OnUpdate", self:__closure("_HandlePlotUpdate"))
end

function Graph.__private:_HandlePlotLeave()
	self._state.mouseOver = false
end

function Graph.__private:_HandlePlotMouseDown(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	assert(self._state.mouseOver)
	self._state.selectionStartX = self:_GetCursorClosestPoint()
end

function Graph.__private:_HandlePlotMouseUp(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	local currentX = self:_GetCursorClosestPoint()
	local startX = min(self._state.selectionStartX, currentX)
	local endX = max(self._state.selectionStartX, currentX)
	self._state.selectionStartX = nil
	self._plot.selectionBox:Hide()

	if startX ~= endX and (startX ~= self._zoomStart or endX ~= self._zoomEnd) then
		self._zoomStart = startX
		self._zoomEnd = endX
		self:Draw()
		self:_SendActionScript("OnZoomChanged")
	end
end

function Graph.__private:_HandlePlotUpdate()
	local plot = self._plot
	local closestX, closestY = self:_GetCursorClosestPoint()
	local xCoord = self:_XValueToPlotCoord(closestX)
	local yCoord = Math.Scale(closestY, self._yMin, self._yMax, 0, plot:GetHeight())

	if self._state.mouseOver then
		plot.dot:Show()
		plot.dot:ClearAllPoints()
		plot.dot:SetPoint("CENTER", plot, "BOTTOMLEFT", xCoord, yCoord)

		plot.hoverLine:Show()
		plot.hoverLine:ClearAllPoints()
		plot.hoverLine:SetPoint("TOP", plot, "TOPLEFT", xCoord, 0)
		plot.hoverLine:SetPoint("BOTTOM", plot, "BOTTOMLEFT", xCoord, 0)

		plot.hoverText:Show()
		plot.hoverText:SetWidth(1000)
		plot.hoverText:SetText(self._yFormatFunc(closestY, true))
		local textWidth = plot.hoverText:GetStringWidth()
		plot.hoverText:SetWidth(textWidth)
		plot.hoverText:ClearAllPoints()
		if xCoord - textWidth / 2 < 0 then
			plot.hoverText:SetPoint("BOTTOMLEFT", plot, "TOPLEFT", 0, PLOT_Y_MARGIN)
		elseif textWidth / 2 + xCoord > plot:GetWidth() then
			plot.hoverText:SetPoint("BOTTOMRIGHT", plot, "TOPRIGHT", 0, PLOT_Y_MARGIN)
		else
			plot.hoverText:SetPoint("BOTTOM", plot, "TOPLEFT", xCoord, PLOT_Y_MARGIN)
		end
	else
		plot.dot:Hide()
		plot.hoverLine:Hide()
		plot.hoverText:Hide()
	end

	if self._state.selectionStartX then
		local startXCoord = self:_XValueToPlotCoord(self._state.selectionStartX)
		local selectionMinX = min(startXCoord, xCoord)
		local selectionMaxX = max(startXCoord, xCoord)
		plot.selectionBox:Show()
		local r, g, b, a = Theme.GetColor("accent/main"):GetFractionalRGBA()
		assert(a == 1)
		plot.selectionBox:SetColorTexture(r, g, b, SELECTION_ALPHA)
		plot.selectionBox:ClearAllPoints()
		plot.selectionBox:SetPoint("TOPLEFT", plot, selectionMinX, 0)
		plot.selectionBox:SetPoint("BOTTOMRIGHT", plot, "BOTTOMLEFT", selectionMaxX, 0)
	else
		plot.selectionBox:Hide()
	end

	local isHovered = self._state.hovered
	if not isHovered then
		self:Draw()
		plot:TSMSetScript("OnUpdate", nil)
	end
	self:_SendActionScript("OnHoverUpdate", isHovered and closestX or nil)
end

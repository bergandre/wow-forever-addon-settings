-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local ListRow = LibTSMUI:IncludeClassType("ListRow")
local Range = LibTSMUI:From("LibTSMUtil"):IncludeClassType("Range")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local List = ComponentRegistry.Define("List", "Element", "ABSTRACT")
List.ROW_HEIGHT = 20
List._STATE_SCHEMA = List._STATE_SCHEMA:Extend("ListState")
	:AddStringField("backgroundColor", "container/lowest", Theme.IsValidColor)
	:AddNumberField("headerCornerRadius", 0)
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function List:__init()
	assert(type(self.ROW_HEIGHT) == "number" and self.ROW_HEIGHT > 0)

	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)

	self._rowElements = {} ---@type ListRow[]
	self._numRows = 0
	self._hScrollValue = 0
	self._vScrollValue = 0
	self._prevDataOffset = nil
	self._ignoreScrollDraw = false

	local backgroundColorPublisher = self._state:Publisher("backgroundColor")
		:Share()

	self._frame:TSMSubscribeBackdropColor(self._state:Publisher([[headerCornerRadius == 0 and backgroundColor or "TRANSPARENT"]]))

	self._hScrollFrame = self:_CreateScrollFrame()
	self._hScrollFrame:SetPoint("TOPLEFT")
	self._hScrollFrame:SetPoint("BOTTOMRIGHT")
	self._hScrollFrame:EnableMouseWheel(true)
	self._hScrollFrame:SetClipsChildren(true)
	self._hScrollFrame:TSMSetScript("OnUpdate", self:__closure("_HScrollFrameOnUpdate"))
	self._hScrollFrame:TSMSetScript("OnMouseWheel", self:__closure("_FrameOnMouseWheel"))

	self._hContent = self:_CreateFrame(self._hScrollFrame)
	self._hContent:SetPoint("TOPLEFT")
	self._hScrollFrame:SetScrollChild(self._hContent)

	self._vScrollFrame = self:_CreateScrollFrame(self._hContent)
	self._vScrollFrame:SetPoint("TOPLEFT")
	self._vScrollFrame:SetPoint("BOTTOMRIGHT")
	self._vScrollFrame:EnableMouseWheel(true)
	self._vScrollFrame:SetClipsChildren(true)
	self._vScrollFrame:TSMSetScript("OnUpdate", self:__closure("_VScrollFrameOnUpdate"))
	self._vScrollFrame:TSMSetScript("OnMouseWheel", self:__closure("_FrameOnMouseWheel"))

	self._content = self:_CreateFrame(self._vScrollFrame)
	self._content:SetPoint("TOPLEFT")
	self._vScrollFrame:SetScrollChild(self._content)

	self._hScrollbar = self:_CreateScrollbar(true)
	self._vScrollbar = self:_CreateScrollbar()

	backgroundColorPublisher:CallFunction(self:__closure("_UpdateRowBackground"))

	backgroundColorPublisher:EndShare()
end

function List:Acquire()
	assert(#self._rowElements == 0)

	self.__super:Acquire()

	self._hScrollFrame:SetHorizontalScroll(0)
	self._hScrollValue = 0
	self._vScrollValue = 0

	self._vScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnVScrollbarValueChangedNoDraw"))
	-- Don't want to cause this element to be drawn for this initial scrollbar change
	self._vScrollbar:SetValue(0)
	self._vScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnVScrollbarValueChanged"))

	self._hScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnHScrollbarValueChangedNoDraw"))
	-- Don't want to cause this element to be drawn for this initial scrollbar change
	self._hScrollbar:SetValue(0)
	self._hScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnHScrollbarValueChanged"))
end

function List:Release()
	self._prevDataOffset = nil
	self._ignoreScrollDraw = false
	for _, row in ipairs(self._rowElements) do
		row:Release()
	end
	wipe(self._rowElements)
	self._numRows = 0
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the background of the list.
---@param color ThemeColorKey The background color as a theme color key
---@return self
function List:SetBackgroundColor(color)
	self._state.backgroundColor = color
	return self
end

---Rounds the top corners of the header to match a rounded container, which then provides the top line and background.
---@param radius number The corner radius
---@return self
function List:SetHeaderCornerRadius(radius)
	self._state.headerCornerRadius = radius
	return self
end

function List:Draw()
	self.__super:Draw()

	self:_DrawHFrames()
	self:_DrawVFrames()

	-- Add/hide rows as needed
	local backgroundColor = self._state.backgroundColor
	local maxVisibleRows = self:_GetMaxVisibleRows()
	for i = #self._rowElements + 1, maxVisibleRows do
		local row = ListRow.Get(self._content, self.ROW_HEIGHT, self:__closure("_HandleRowFrameEvent"))
		row:SetOffset(i - 1)
		row:SetBackgroundColor(backgroundColor)
		self:_HandleRowAcquired(row)
		self._rowElements[i] = row
	end
	self:_HideExtraRows()

	-- Draw all the rows
	self:_DrawRows()
end



-- ============================================================================
-- List - Abstract Class Methods
-- ============================================================================

function List.__abstract:_HandleRowDraw(row)
	-- must be implemented by subclass
end



-- ============================================================================
-- List - Protected Class Methods
-- ============================================================================

function List.__protected:_SetNumRows(numRows)
	self._numRows = numRows
	return self
end

function List.__protected:_GetRow(index)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	local rowIndex = index - dataOffset
	if rowIndex < 1 or rowIndex > numVisibleRows then
		return nil
	end
	return self._rowElements[rowIndex]
end

---@param addDataRange Range
function List.__protected:_AddRows(addDataRange)
	local dataOffset = self:_GetDataOffset()
	self:_SetNumRows(self._numRows + addDataRange:GetLength())
	self:_DrawVFrames()
	local numVisibleRows = self:_GetNumVisibleRows()
	assert(dataOffset == self:_GetDataOffset())
	local firstRowIndex = addDataRange:GetStart() - dataOffset
	local lastRowIndex = addDataRange:GetEnd() - dataOffset
	firstRowIndex = max(firstRowIndex, 1)
	if firstRowIndex > numVisibleRows then
		-- Adding all the rows below the visible range, so don't need to do anything
	elseif lastRowIndex >= numVisibleRows then
		-- We're inserting enough rows that all the ones being shifted down are going off the bottom of the visible area, so just redraw them
		self:_DrawRows(firstRowIndex, numVisibleRows)
	else
		-- Update the dataIndex of all the rows which we're shifting down
		for i = firstRowIndex, numVisibleRows - addDataRange:GetLength() do
			local row = self._rowElements[i]
			row:UpdateDataIndex(row:GetDataIndex() + addDataRange:GetLength())
		end
		-- Rotate the existing rows down to just redraw the new rows
		self:_RotateRowsDown(addDataRange:GetLength(), firstRowIndex, numVisibleRows)
	end
end

---@param removeDataRange Range
function List.__protected:_RemoveRows(removeDataRange)
	local maxVisibleRows = self:_GetMaxVisibleRows()
	local dataOffset = self:_GetDataOffset()
	local numRows = self._numRows
	local newNumRows = numRows - removeDataRange:GetLength()
	local maxNewDataOffset = max(newNumRows - maxVisibleRows, 0)
	local visibleDataRange = self:_AcquireVisibleDataRange()
	local removeVisibleRangeLength = removeDataRange:IntersectionLength(visibleDataRange)

	-- Update the number of rows
	self:_SetNumRows(newNumRows)
	if removeVisibleRangeLength == 0 then
		if removeDataRange:StartsBefore(visibleDataRange) then
			-- Only removing rows above the visible range
			-- Shift the data offset
			local newDataOffset = dataOffset - removeDataRange:GetLength()
			assert(newDataOffset >= 0 and newDataOffset <= maxNewDataOffset)
			self:_UpdateDataOffsetNoDraw(newDataOffset)
		else
			-- Only removing rows below the visible range
			-- Shouldn't need to update the data offset
			assert(dataOffset <= maxNewDataOffset)
		end
		-- Don't need to redraw anything
	elseif removeDataRange:Contains(visibleDataRange) then
		-- Removing the entire visible range (and potentially some outside the visible range)
		if dataOffset > maxNewDataOffset then
			-- Update the data offset
			self:_UpdateDataOffsetNoDraw(maxNewDataOffset)
		end
		-- Draw everything
		self:_DrawRows()
	elseif removeDataRange:GetStart() <= visibleDataRange:GetStart() then
		-- Removing visible rows from the top of the visible range (and potentially also above)
		-- Calculate the ideal new data offset which leaves all remaining visible rows alone
		local idealNewDataOffset = dataOffset - removeDataRange:GetLength()
		local newDataOffset = max(idealNewDataOffset, 0)
		assert(idealNewDataOffset <= maxNewDataOffset)
		if newDataOffset ~= dataOffset then
			-- Update the data offset
			self:_UpdateDataOffsetNoDraw(newDataOffset)
		end
		if idealNewDataOffset >= 0 then
			-- Draw the rows which were shifted in from the top
			self:_DrawRows(1, removeVisibleRangeLength)
		else
			-- Rotate rows up to compensate for the new data offset
			local shiftUpStartIndex = removeDataRange:GetEnd() - dataOffset + 1 + idealNewDataOffset
			self:_RotateRowsDown(idealNewDataOffset, shiftUpStartIndex, min(numRows, maxVisibleRows))
			if shiftUpStartIndex > 1 then
				-- Draw the rows which were shifted in from the top
				self:_DrawRows(1, shiftUpStartIndex - 1)
			end
		end
	elseif removeDataRange:GetEnd() >= visibleDataRange:GetEnd() then
		-- Removing visible rows from the bottom of the visible range (and potentially also below)
		local newDataOffset = min(dataOffset, maxNewDataOffset)
		if newDataOffset ~= dataOffset then
			-- Update the data offset
			self:_UpdateDataOffsetNoDraw(newDataOffset)
		end
		if dataOffset <= maxNewDataOffset then
			if removeDataRange:GetEnd() < numRows then
				-- Draw the new rows which got shifted in from the bottom
				self:_DrawRows(removeDataRange:GetStart() - dataOffset)
			else
				assert(dataOffset == 0)
			end
		else
			local numExtraScroll = dataOffset - maxNewDataOffset
			-- Rotate rows down to compensate for the new data offset
			self:_RotateRowsDown(numExtraScroll, 1, maxVisibleRows)
			local numShiftFromBottom = removeVisibleRangeLength - numExtraScroll
			if numShiftFromBottom > 0 then
				-- Draw the rows which were shifted in from the bottom
				self:_DrawRows(maxVisibleRows - numShiftFromBottom + 1)
			end
		end
	elseif visibleDataRange:Contains(removeDataRange) then
		-- Removing rows from the middle of the visible range
		local newDataOffset = min(dataOffset, maxNewDataOffset)
		if newDataOffset ~= dataOffset then
			-- Update the data offset
			self:_UpdateDataOffsetNoDraw(newDataOffset)
		end
		if dataOffset <= maxNewDataOffset then
			-- Rotate the remaining rows up
			self:_RotateRowsDown(-removeDataRange:GetLength(), removeDataRange:GetStart() - dataOffset, min(numRows, maxVisibleRows))
		else
			local numExtraScroll = dataOffset - maxNewDataOffset
			if numExtraScroll == removeDataRange:GetLength() then
				-- Rotate rows in from the top
				self:_RotateRowsDown(numExtraScroll, 1, removeDataRange:GetEnd() - dataOffset)
			else
				local shiftUpEndIndex = removeDataRange:GetStart() - dataOffset + numExtraScroll
				-- Rotate rows in from the top
				self:_RotateRowsDown(numExtraScroll, 1, shiftUpEndIndex - 1)
				-- Rotate rows in from the bottom
				self:_RotateRowsDown(-(removeDataRange:GetLength() - numExtraScroll), shiftUpEndIndex)
			end
		end
	else
		-- Shouldn't ever get here
		error("Unexpected range")
	end
	self:_HideExtraRows()
	-- Update the dataIndex of all rows (could optimize this, but not really worth it)
	local newDataOffset = self:_GetDataOffset()
	for i = 1, self:_GetNumVisibleRows() do
		local row = self._rowElements[i]
		row:UpdateDataIndex(newDataOffset + i)
	end
	visibleDataRange:Release()
end

function List.__protected:_MoveRow(fromDataIndex, toDataIndex)
	assert(fromDataIndex ~= toDataIndex)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	local fromRowIndex = fromDataIndex - dataOffset
	local toRowIndex = toDataIndex - dataOffset
	if min(fromRowIndex, toRowIndex) > numVisibleRows or max(fromRowIndex, toRowIndex) < 1 then
		-- None of the affected rows are visible, so nothing to do
		return
	end
	local moveFromRowIndex = Math.Bound(fromRowIndex, 1, numVisibleRows)
	local moveToRowIndex = Math.Bound(toRowIndex, 1, numVisibleRows)

	-- Move the existing row
	Table.Move(self._rowElements, moveFromRowIndex, moveToRowIndex)

	-- Update all the affected rows
	for i = min(moveToRowIndex, moveFromRowIndex), max(moveToRowIndex, moveFromRowIndex) do
		local row = self._rowElements[i]
		row:UpdateDataIndex(i + dataOffset)
		row:SetOffset(i - 1)
	end

	-- Redraw the row which was moved to
	self:_DrawRows(moveToRowIndex, moveToRowIndex)
end

function List.__protected:_ScrollToRow(dataIndex)
	if not dataIndex then
		return
	end
	assert(dataIndex > 0 and dataIndex <= self._numRows)
	local firstVisibleIndex = self:_GetDataOffset() + 1
	local lastVisibleIndex = firstVisibleIndex + self:_GetNumVisibleRows() - 2
	if lastVisibleIndex > firstVisibleIndex and (dataIndex < firstVisibleIndex or dataIndex > lastVisibleIndex) then
		local vScrollOffset = min((dataIndex - 1) * self.ROW_HEIGHT, self:_GetMaxVScroll())
		if self._vScrollbar:GetValue() ~= vScrollOffset then
			self._vScrollbar:SetValue(vScrollOffset)
		end
		self._vScrollFrame:SetVerticalScroll(vScrollOffset % self.ROW_HEIGHT)
	end
end

function List.__protected:_DrawRows(startRowIndex, endRowIndex)
	local numVisibleRows = self:_GetNumVisibleRows()
	startRowIndex = startRowIndex or 1
	endRowIndex = endRowIndex or numVisibleRows
	assert(startRowIndex >= 1 and endRowIndex <= numVisibleRows)
	local dataOffset = self:_GetDataOffset()
	for i = startRowIndex, endRowIndex do
		local dataIndex = i + dataOffset
		assert(dataIndex <= self._numRows)
		local row = self._rowElements[i]
		row:SetDataIndex(dataIndex)
		self:_HandleRowDraw(row)
	end
end

function List.__protected:_DrawRowsForUpdatedData(startDataIndex, endDataIndex)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	startDataIndex = max(startDataIndex, dataOffset + 1)
	endDataIndex = min(endDataIndex, numVisibleRows + dataOffset)
	for i = startDataIndex, endDataIndex do
		self:_HandleRowDraw(self._rowElements[i - dataOffset])
	end
end

function List.__protected:_DrawHFrames()
	local totalWidth = self:_GetDimension("WIDTH")
	self._hContent:SetWidth(totalWidth)
	self._content:SetWidth(self._hContent:GetWidth())

	local visibleWidth = self._hScrollFrame:GetWidth()
	local hScrollOffset = min(self._hScrollValue, self:_GetMaxHScroll())

	self._hScrollbar:TSMUpdateThumbLength(self._hContent:GetWidth(), visibleWidth)
	self._hScrollbar:SetMinMaxValues(0, self:_GetMaxHScroll())
	self._hScrollbar:SetValue(hScrollOffset)
	self._hScrollFrame:SetHorizontalScroll(hScrollOffset)
end

function List.__protected:_GetRowVerticalOffset(dataIndex)
	return (dataIndex - 1) * self.ROW_HEIGHT - self._vScrollValue
end

function List.__protected:_HideExtraRows()
	for i = self:_GetNumVisibleRows() + 1, #self._rowElements do
		self._rowElements[i]:SetDataIndex(nil)
	end
end

function List.__protected:_HandleRowAcquired(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowEnter(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowLeave(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowClick(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowDoubleClick(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowMouseDown(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end



-- ============================================================================
-- List - Private Class Methods
-- ============================================================================

function List.__private:_UpdateRowBackground(color)
	for _, row in ipairs(self._rowElements) do
		row:SetBackgroundColor(color)
	end
end

function List.__private:_DrawVFrames()
	self._hContent:SetHeight(self._hScrollFrame:GetHeight())

	local totalHeight = self._numRows * self.ROW_HEIGHT
	local visibleHeight = self._vScrollFrame:GetHeight()
	local numVisibleRows = self:_GetNumVisibleRows()
	local maxScroll = self:_GetMaxVScroll()
	local vScrollOffset = min(self._vScrollValue, maxScroll)

	self._vScrollbar:TSMUpdateThumbLength(totalHeight, visibleHeight)
	self._vScrollbar:SetMinMaxValues(0, maxScroll)
	-- FIXME: this causes a double-draw on first show(?) and is super hacky
	if self._vScrollbar:GetValue() ~= vScrollOffset or self._numRows > 0 then
		self._vScrollbar:SetValue(vScrollOffset)
	end
	self._content:SetHeight(numVisibleRows * self.ROW_HEIGHT)
	self._vScrollFrame:SetVerticalScroll(vScrollOffset % self.ROW_HEIGHT)
end

function List.__private:_HandleRowFrameEvent(row, event, ...)
	if event == "OnEnter" then
		local focus = GetMouseFoci()[1]
		if not focus or (focus ~= row._frame and focus ~= row._frame:GetParent() and focus:GetParent() ~= row._frame) then
			-- Sometimes we get erroneous OnEnter events - just ignore them
			return
		end
		assert(select("#", ...) == 0)
		self:_HandleRowEnter(row)
	elseif event == "OnLeave" then
		assert(select("#", ...) == 0)
		self:_HandleRowLeave(row)
	elseif event == "OnClick" then
		assert(select("#", ...) == 1)
		local mouseButton = ...
		self:_HandleRowClick(row, mouseButton)
	elseif event == "OnDoubleClick" then
		assert(select("#", ...) == 1)
		local mouseButton = ...
		self:_HandleRowDoubleClick(row, mouseButton)
	elseif event == "OnMouseDown" then
		assert(select("#", ...) == 1)
		local mouseButton = ...
		self:_HandleRowMouseDown(row, mouseButton)
	else
		error("Unexpected event: "..tostring(event))
	end
end

function List.__private:_GetMaxVScroll()
	return max(self._numRows * self.ROW_HEIGHT - self._vScrollFrame:GetHeight(), 0)
end

function List.__protected:_GetMaxHScroll()
	return max(self._hContent:GetWidth() - self._hScrollFrame:GetWidth(), 0)
end

function List.__private:_GetMaxVisibleRows()
	return ceil(self._vScrollFrame:GetHeight() / self.ROW_HEIGHT)
end

function List.__private:_GetNumVisibleRows()
	return min(self:_GetMaxVisibleRows(), self._numRows)
end

function List.__private:_GetDataOffset()
	return floor(min(self._vScrollValue, self:_GetMaxVScroll()) / self.ROW_HEIGHT)
end

function List.__private:_RotateRowsDown(amount, startIndex, endIndex, noDraw)
	local numVisible = self:_GetNumVisibleRows()
	startIndex = startIndex or 1
	endIndex = endIndex or numVisible
	if not Table.RotateRight(self._rowElements, amount, startIndex, endIndex) and noDraw then
		-- Nothing changed
		return
	end
	-- Fix the points of all the rows
	for i, row in ipairs(self._rowElements) do
		row:SetOffset(i - 1)
	end
	if noDraw then
		return
	end
	-- Just draw the rows which were rotated in, not the ones which were shifted
	if amount > 0 then
		self:_DrawRows(startIndex, min(startIndex + amount - 1, endIndex))
	else
		local newRowStartIndex = endIndex + amount + 1
		if newRowStartIndex <= numVisible then
			self:_DrawRows(newRowStartIndex, min(endIndex, numVisible))
		end
	end
end

function List.__private:_AcquireVisibleDataRange()
	local dataOffset = self:_GetDataOffset()
	local maxVisibleRows = self:_GetMaxVisibleRows()
	if self._numRows < maxVisibleRows then
		assert(dataOffset == 0)
		return Range.AcquireStartLength(1, self._numRows)
	else
		assert(dataOffset + maxVisibleRows <= self._numRows)
		return Range.AcquireStartLength(dataOffset + 1, maxVisibleRows)
	end
end

function List.__private:_UpdateDataOffsetNoDraw(dataOffset)
	self._ignoreScrollDraw = true
	self:_ScrollToRow(dataOffset + 1)
	self:_DrawVFrames()
	self._ignoreScrollDraw = false
	assert(self:_GetDataOffset() == dataOffset)
end



-- ============================================================================
-- List - Private Script Handlers
-- ============================================================================

function List.__private:_FrameOnMouseWheel(frame, direction)
	local scrollAmount = -direction * Theme.GetMouseWheelScrollAmount()
	if IsShiftKeyDown() and self._hScrollbar:IsVisible() then
		-- scroll horizontally
		self._hScrollbar:SetValue(self._hScrollbar:GetValue() + scrollAmount)
	else
		self._vScrollbar:SetValue(self._vScrollbar:GetValue() + scrollAmount)
	end
end

function List.__private:_VScrollFrameOnUpdate()
	local rOffset = max(self._hContent:GetWidth() - self._hScrollFrame:GetWidth() - self._hScrollbar:GetValue(), 0)
	if (self._vScrollFrame:IsMouseOver(0, 0, 0, -rOffset) and self:_GetMaxVScroll() > 1) or self._vScrollbar.dragging then
		self._vScrollbar:Show()
	else
		self._vScrollbar:Hide()
	end
end

function List.__private:_HScrollFrameOnUpdate()
	if (self._hScrollFrame:IsMouseOver() and self:_GetMaxHScroll() > 1) or self._hScrollbar.dragging then
		self._hScrollbar:Show()
	else
		self._hScrollbar:Hide()
	end
end

function List.__private:_OnHScrollbarValueChanged(frame, value)
	self:_OnHScrollbarValueChangedNoDraw(frame, value)
	self:_DrawHFrames()
end

function List.__private:_OnVScrollbarValueChanged(frame, value)
	self:_OnVScrollbarValueChangedNoDraw(frame, value)
	self:_DrawVFrames()

	local numVisibleRows = self:_GetNumVisibleRows()
	assert(numVisibleRows >= 0)
	local dataOffset = self:_GetDataOffset()
	local scrollDiff = dataOffset - (self._prevDataOffset or 0)
	self._prevDataOffset = dataOffset
	if self._ignoreScrollDraw then
		return
	end
	if scrollDiff == 0 then
		-- Didn't actually scroll
		return
	elseif abs(scrollDiff) > numVisibleRows then
		-- All rows changed, so just redraw them all
		self:_DrawRows()
		return
	end
	-- Shift the rows to match the scrolling so we only have to update as few rows as possible
	self:_RotateRowsDown(-scrollDiff)
end

function List.__private:_OnHScrollbarValueChangedNoDraw(_, value)
	self._hScrollValue = max(min(value, self:_GetMaxHScroll()), 0)
end

function List.__private:_OnVScrollbarValueChangedNoDraw(_, value)
	self._vScrollValue = max(min(value, self:_GetMaxVScroll()), 0)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local ListRow = LibTSMUI:IncludeClassType("ListRow")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local StaticList = ComponentRegistry.Define("StaticList", "Element", "ABSTRACT")
StaticList.HEADER_HEIGHT = 0
StaticList.ROW_HEIGHT = 20
StaticList._STATE_SCHEMA = StaticList._STATE_SCHEMA:Extend("StaticListState")
	:AddStringField("backgroundColor", "container/lowest", Theme.IsValidColor)
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function StaticList:__init()
	assert(type(self.ROW_HEIGHT) == "number" and self.ROW_HEIGHT > 0)

	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)

	self._rowElements = {} ---@type ListRow[]

	local backgroundColorPublisher = self._state:Publisher("backgroundColor")
		:Share()

	self._frame:TSMSubscribeBackdropColor(backgroundColorPublisher)

	self._content = self:_CreateFrame(self._frame)
	self._content:SetPoint("TOPLEFT", 0, -self.HEADER_HEIGHT)
	self._content:SetPoint("BOTTOMRIGHT")

	backgroundColorPublisher:CallFunction(self:__closure("_UpdateRowBackground"))
	backgroundColorPublisher:EndShare()
end

function StaticList:Acquire()
	self.__super:Acquire()
	self:_UpdateHeight()
end

function StaticList:Release()
	for _, row in ipairs(self._rowElements) do
		row:Release()
	end
	wipe(self._rowElements)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the background of the list.
---@param color ThemeColorKey The background color as a theme color key
---@return self
function StaticList:SetBackgroundColor(color)
	self._state.backgroundColor = color
	return self
end

function StaticList:Draw()
	self.__super:Draw()
	-- Draw all the rows
	self:_DrawRows()
end



-- ============================================================================
-- Abstract Class Methods
-- ============================================================================

function StaticList.__abstract:_HandleRowDraw(row)
	-- Must be implemented by subclass
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function StaticList.__protected:_RecreateRows(numRows)
	-- Create new rows as needed
	while #self._rowElements < numRows do
		self:_CreateRow()
	end
	-- Remove extra rows
	while #self._rowElements > numRows do
		local row = tremove(self._rowElements) ---@type ListRow
		row:Release()
	end
	self:_UpdateHeight()
	self:_DrawRows()
end

function StaticList.__protected:_AddRow(index)
	self:_CreateRow(index)
	-- Update the offset and data index of rows that got shifted down
	for i = index + 1, #self._rowElements do
		local row = self._rowElements[i]
		row:SetOffset(i - 1)
		row:UpdateDataIndex(i)
	end
	self:_DrawRows(index, index)
end

function StaticList.__protected:_RemoveRow(index)
	local removeRow = tremove(self._rowElements, index) ---@type ListRow
	removeRow:Release()
	-- Update the data index of rows that got shifted up
	for i = index, #self._rowElements do
		local row = self._rowElements[i]
		row:SetOffset(i - 1)
		row:UpdateDataIndex(i)
	end
	self:_UpdateHeight()
end

function StaticList.__protected:_DrawRows(startRowIndex, endRowIndex)
	startRowIndex = startRowIndex or 1
	endRowIndex = endRowIndex or #self._rowElements
	for i = startRowIndex, endRowIndex do
		self:_HandleRowDraw(self._rowElements[i])
	end
end

function StaticList.__protected:_HandleRowAcquired(row)
	-- Do nothing if not implemented by the subclass
end

function StaticList.__protected:_HandleRowEnter(row)
	-- Do nothing if not implemented by the subclass
end

function StaticList.__protected:_HandleRowLeave(row)
	-- Do nothing if not implemented by the subclass
end

function StaticList.__protected:_HandleRowClick(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end

function StaticList.__protected:_HandleRowDoubleClick(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end

function StaticList.__protected:_HandleRowMouseDown(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function StaticList.__private:_CreateRow(index)
	index = index or (#self._rowElements + 1)
	local row = ListRow.Get(self._content, self.ROW_HEIGHT, self:__closure("_HandleRowFrameEvent"))
	row:SetOffset(index - 1)
	row:SetBackgroundColor(self._state.backgroundColor)
	row:SetDataIndex(index)
	tinsert(self._rowElements, index, row)
	self:_HandleRowAcquired(row)
	self:_UpdateHeight()
end

function StaticList.__private:_UpdateHeight()
	self:SetHeight(max(self.HEADER_HEIGHT + self.ROW_HEIGHT * #self._rowElements, 1))
end

function StaticList.__private:_UpdateRowBackground(color)
	for _, row in ipairs(self._rowElements) do
		row:SetBackgroundColor(color)
	end
end

function StaticList.__private:_HandleRowFrameEvent(row, event, ...)
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

function StaticList.__private:_RotateRows(rotateDown, startIndex, endIndex)
	assert(Table.RotateRight(self._rowElements, rotateDown and 1 or -1, startIndex, endIndex))
	-- Fix the points of all the rows
	for i, row in ipairs(self._rowElements) do
		row:SetOffset(i - 1)
	end
	-- Just draw the row which was rotated in
	local newRowIndex = rotateDown and startIndex or endIndex
	self:_DrawRows(newRowIndex, newRowIndex)
end

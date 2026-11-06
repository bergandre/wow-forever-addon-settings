-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SelectionGroupTree = ComponentRegistry.Define("SelectionGroupTree", "GroupTree")
SelectionGroupTree._STATE_SCHEMA = SelectionGroupTree._STATE_SCHEMA:Extend("SelectionGroupTreeState")
	:AddOptionalStringField("selectedGroup")
	:Commit()

---@class SelectionGroupTreeContextTable: GroupTreeContextTable
---@field selected table<string,true?>

---@class SelectionGroupTree
---@field _contextTable SelectionGroupTreeContextTable



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SelectionGroupTree:__init()
	self.__super:__init()
	self._firstDraw = true
end

function SelectionGroupTree:Release()
	self._firstDraw = true
	self.__super:Release()
end

---Sets the selected group path.
---@param groupPath GroupPathValue The group path to select
---@return self
function SelectionGroupTree:SetSelection(groupPath)
	assert(groupPath)
	self._state.selectedGroup = groupPath
	self:_ScrollToRow(Table.KeyByValue(self._groupPath, groupPath))
	return self
end

---Sets the context table which is used to persist the selected and collapsed state.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `selected`, `collapsed`)
---@return self
function SelectionGroupTree:SetContextTable(tbl, defaultTbl)
	assert(not self._contextTable)
	assert(type(defaultTbl.selected) == "table")
	if not tbl.selected or Table.Count(tbl.selected) > 1 then
		tbl.selected = CopyTable(defaultTbl.selected)
	end
	self.__super:SetContextTable(tbl, defaultTbl)
	local selection = next(tbl.selected)
	if selection then
		self._state.selectedGroup = selection
	end
	self._state:Publisher("selectedGroup")
		:IgnoreNil()
		:CallFunction(self:__closure("_SetSelectedGroupContext"))
	return self
end

---Sets the query used to populate the group tree.
---@param query DatabaseQuery The database query object
---@return self
function SelectionGroupTree:SetQuery(query)
	self.__super:SetQuery(query)
	return self
end

function SelectionGroupTree:Draw()
	self.__super:Draw()
	if self._state.selectedGroup then
		self:_ScrollToRow(Table.KeyByValue(self._groupPath, self._state.selectedGroup))
	end
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function SelectionGroupTree.__protected:_HandleRowClick(row, mouseButton)
	if self.__super:_HandleRowClick(row, mouseButton) then
		return
	end

	local groupPath = self._groupPath[row:GetDataIndex()]
	local prevSelectedGroup = self._state.selectedGroup
	if prevSelectedGroup == groupPath then
		return
	end
	self._state.selectedGroup = groupPath

	self:_DrawSelectedState(row)
	if prevSelectedGroup then
		local prevRow = self:_GetRowForGroupPath(prevSelectedGroup)
		if prevRow then
			self:_DrawSelectedState(prevRow)
		end
	end
end

function SelectionGroupTree.__protected:_IsSelected(groupPath)
	return groupPath == self._state.selectedGroup
end

function SelectionGroupTree.__private:_SetSelectedGroupContext(selectedGroup)
	wipe(self._contextTable.selected)
	self._contextTable.selected[selectedGroup] = true
end

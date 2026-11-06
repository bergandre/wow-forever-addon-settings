-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Iterator = LibTSMUI:From("LibTSMUtil"):Include("BaseType.Iterator")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local private = {
	selectionTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local ApplicationGroupTree = ComponentRegistry.Define("ApplicationGroupTree", "GroupTree")
ApplicationGroupTree:_AddActionScripts("OnGroupSelectionChanged")

---@class ApplicationGroupTreeContextTable: GroupTreeContextTable
---@field selected table<string,true?>?
---@field unselected table<string,true?>?

---@class ApplicationGroupTree
---@field _contextTable ApplicationGroupTreeContextTable!



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ApplicationGroupTree:__init()
	self.__super:__init()
	self._keepTopLevelSelected = false
end

function ApplicationGroupTree:Release()
	self._keepTopLevelSelected = false
	self.__super:Release()
end

---Adjusts the selection behavior to always keep the top level group selected.
---@return self
function ApplicationGroupTree:KeepTopLevelGroupSelected()
	self._keepTopLevelSelected = true
	return self
end

---Iterates through the selected groups.
---@return IteratorObject<fun(): number, GroupPathValue> @Iterator with fields: `index`, `groupPath`
function ApplicationGroupTree:SelectedGroupsIterator()
	return Iterator.Acquire(ipairs(self._allGroupPaths))
		:Filter(self:__closure("_SelectedIterFilterFunc"))
end

---Sets the context table which is used to persist the selected and collapsed state.
---@param tbl table The context table
---@param defaultTbl ApplicationGroupTreeContextTable Default values
---@return self
function ApplicationGroupTree:SetContextTable(tbl, defaultTbl)
	if defaultTbl.unselected then
		assert(type(defaultTbl.unselected) == "table" and not defaultTbl.selected)
		tbl.unselected = tbl.unselected or CopyTable(defaultTbl.unselected)
		tbl.selected = nil
	else
		assert(type(defaultTbl.selected) == "table" and not defaultTbl.unselected)
		tbl.selected = tbl.selected or CopyTable(defaultTbl.selected)
		tbl.unselected = nil
	end
	self.__super:SetContextTable(tbl, defaultTbl)
	return self
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to check
---@return boolean
function ApplicationGroupTree:IsGroupSelected(groupPath)
	return self:_IsSelected(groupPath)
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to set the selected state of
---@param selected boolean Whether or not the group should be selected
---@return self
function ApplicationGroupTree:SetGroupSelected(groupPath, selected)
	self:_SetSelected(groupPath, selected)
	return self
end

---Gets whether or not the selection is cleared.
---@return boolean
function ApplicationGroupTree:IsSelectionCleared()
	for _, groupPath in ipairs(self._searchStr == "" and self._allGroupPaths or self._groupPath) do
		if self:_IsSelected(groupPath) and (not self._keepTopLevelSelected or Group.GetParent(groupPath) ~= Group.GetRootPath()) then
			return false
		end
	end
	return true
end

---Toggle the selection state of the application group tree.
---@return self
function ApplicationGroupTree:ToggleSelectAll()
	local isCleared = self:IsSelectionCleared()
	for _, groupPath in ipairs(self._searchStr == "" and self._allGroupPaths or self._groupPath) do
		self:_SetSelectedCascading(groupPath, isCleared)
	end
	self:_SendActionScript("OnGroupSelectionChanged")
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ApplicationGroupTree.__protected:_HandleQueryUpdate()
	if not self._contextTable then
		return
	end
	self.__super:_HandleQueryUpdate()
	-- Remove data which is no longer present from _contextTable
	assert(not next(private.selectionTemp))
	for _, groupPath in self:SelectedGroupsIterator() do
		private.selectionTemp[groupPath] = true
	end
	local selectionTbl = self._contextTable.selected or self._contextTable.unselected
	assert(selectionTbl)
	wipe(selectionTbl)
	for _, groupPath in ipairs(self._allGroupPaths) do
		self:_SetSelected(groupPath, private.selectionTemp[groupPath])
	end
	Table.WipeAndDeallocate(private.selectionTemp)
end

function ApplicationGroupTree.__protected:_IsSelected(groupPath)
	if self._contextTable.unselected then
		return not self._contextTable.unselected[groupPath]
	elseif self._contextTable.selected then
		return self._contextTable.selected[groupPath] or false
	else
		error("Invalid context table")
	end
end

function ApplicationGroupTree.__private:_SetSelectedCascading(groupPath, selected)
	self:_SetSelected(groupPath, selected)
	if groupPath == Group.GetRootPath() then
		-- Don't cascade for the base group
		return
	end
	for _, childGroupPath in ipairs(self._allGroupPaths) do
		if Group.IsChild(childGroupPath, groupPath) then
			self:_SetSelected(childGroupPath, selected)
		end
	end
end

function ApplicationGroupTree.__private:_SetSelected(groupPath, selected)
	if self._keepTopLevelSelected and Group.GetParent(groupPath) == Group.GetRootPath() then
		selected = true
	end
	if self._contextTable.unselected then
		self._contextTable.unselected[groupPath] = not selected or nil
	elseif self._contextTable.selected then
		self._contextTable.selected[groupPath] = selected or nil
	else
		error("Invalid context table")
	end

	local index = Table.KeyByValue(self._groupPath, groupPath)
	local row = index and self:_GetRow(index)
	if row then
		row:SetSelected(selected or false)
		self:_DrawRowFlag(row)
	end
end

---@param row ListRow
function ApplicationGroupTree.__protected:_HandleRowClick(row, mouseButton)
	if self.__super:_HandleRowClick(row, mouseButton) then
		return
	end

	local rowGroupPath = self._groupPath[row:GetDataIndex()]
	local selected = not self:_IsSelected(rowGroupPath)
	self:_SetSelectedCascading(rowGroupPath, selected)
	self:_SendActionScript("OnGroupSelectionChanged")
end

function ApplicationGroupTree.__private:_SelectedIterFilterFunc(_, groupPath)
	return self:_IsSelected(groupPath)
end

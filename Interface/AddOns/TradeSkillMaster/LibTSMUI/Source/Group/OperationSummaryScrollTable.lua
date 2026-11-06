-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	selectedTemp = {},
}
local COL_INFO = {
	selected = {
		titleIcon = "iconPack.14x14/Checkmark/Default",
		justifyH = "CENTER",
		font = "ITEM_XSMALL",
		disableHiding = true,
	},
	name = {
		title = L["Operation"],
		justifyH = "LEFT",
		font = "TABLE_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "operationName",
	},
	groups = {
		title = L["Groups Using"],
		justifyH = "LEFT",
		font = "TABLE_XSMALL",
		sortField = "numGroups",
	},
	items = {
		title = L["Items Using"],
		justifyH = "LEFT",
		font = "TABLE_XSMALL",
		hasTooltip = true,
		sortField = "numItems",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationSummaryScrollTable = ComponentRegistry.Define("OperationSummaryScrollTable", "ScrollTable")
OperationSummaryScrollTable:_AddActionScripts("OnOperationConfigure")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationSummaryScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._data.slotId = {}
	self._query = nil ---@type DatabaseQuery!
	self._selectedOperations = {}
end

function OperationSummaryScrollTable:Release()
	local query = self._query
	self._query = nil
	wipe(self._selectedOperations)
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function OperationSummaryScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Iterates over the selected operations.
---@return fun(): string @Iterator with fields: `operationName`
---@return table
function OperationSummaryScrollTable:SelectedOperationsIterator()
	return Table.KeyIterator(self._selectedOperations)
end

---Sets the selection state.
---@param allSelected boolean Whether to set the selection to all or none
---@return self
function OperationSummaryScrollTable:SetSelectionState(allSelected)
	local changed = false
	if allSelected then
		for _, operationName in self._query:Iterator("operationName") do
			if not self._selectedOperations[operationName] then
				self._selectedOperations[operationName] = true
				changed = true
			end
		end
	else
		changed = next(self._selectedOperations) and true or false
		wipe(self._selectedOperations)
	end
	if not changed then
		return self
	end

	self:_HandleQueryUpdate()
	return self
end

---Binds state properties to the selection state.
---@param state ReactiveState The state to store the values in
---@param numSelectedKey string The state key to store the numSelected value at
---@param allSelectedKey string The state key to store the allSelected value at
---@return self
function OperationSummaryScrollTable:BindSelectionstate(state, numSelectedKey, allSelectedKey)
	self._bindings:Add("NUM_SELECTED", state, numSelectedKey)
	self._bindings:Add("ALL_SELECTED", state, allSelectedKey)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function OperationSummaryScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(not next(private.selectedTemp))
	for _, operationName, numGroups, numItems in self._query:Iterator("operationName", "numGroups", "numItems") do
		local selected = self._selectedOperations[operationName]
		private.selectedTemp[operationName] = selected
		tinsert(self._data.selected, selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or "")
		tinsert(self._data.name, operationName)
		tinsert(self._data.groups, numGroups)
		if numItems == floor(numItems) then
			tinsert(self._data.items, numItems)
			tinsert(self._data.items_tooltip, false)
		else
			tinsert(self._data.items, floor(numItems).."*")
			tinsert(self._data.items_tooltip, L["This operation is applied to the base group which includes every item not in another group."])
		end
	end
	wipe(self._selectedOperations)
	for operationName in pairs(private.selectedTemp) do
		self._selectedOperations[operationName] = true
	end
	wipe(private.selectedTemp)
	self:_HandleSelectionChanged()
	self:_SetNumRows(#self._data.name)
	self:Draw()
end

function OperationSummaryScrollTable.__private:_HandleSelectionChanged()
	local numSelected = Table.Count(self._selectedOperations)
	self._bindings:Process("NUM_SELECTED", numSelected)
	self._bindings:Process("ALL_SELECTED", numSelected == self._query:Count())
end

---@param row ListRow
function OperationSummaryScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	local configureIcon = row:AddTexture("configureIcon")
	configureIcon:TSMSetTextureAndSize("iconPack.12x12/Popout")
	configureIcon:SetPoint("RIGHT", row:GetText("name"))
	configureIcon:Hide()
end

---@param row ListRow
function OperationSummaryScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local operationName = self._query:GetNthResult(dataIndex, "operationName")
	if mouseButton == "LeftButton" then
		local selected = not self._selectedOperations[operationName] or nil
		self._selectedOperations[operationName] = selected
		self._data.selected[dataIndex] = selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or ""
		self:_HandleRowDraw(row)
		self:_HandleSelectionChanged()
	elseif mouseButton == "RightButton" then
		self:_SendActionScript("OnOperationConfigure", operationName)
	end
end

function OperationSummaryScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	local id = Table.GetDistinctKey(self._header.cells, button)
	if not COL_INFO[id].sortField then
		-- Don't allow sorting by this row
		return
	elseif not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Iterator = App:From("LibTSMUtil"):Include("BaseType.Iterator")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Group = App:From("LibTSMTypes"):Include("Group")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
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
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	operation = {
		title = L["Auctioning Operation"],
		justifyH = "LEFT",
		sortField = "firstOperation",
	},
	group = {
		title = L["Group"],
		justifyH = "LEFT",
		sortField = "groupPath",
	},
}




-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningBagScrollTable = UIElements.Define("AuctioningBagScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningBagScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._data.slotId = {}
	self._query = nil ---@type DatabaseQuery!
	self._selectedItems = {}
	self._dragDataIndex = nil
end

function AuctioningBagScrollTable:Release()
	local query = self._query
	self._query = nil
	self._dragDataIndex = nil
	wipe(self._selectedItems)
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function AuctioningBagScrollTable:SetQuery(query)
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

---Iterates over the selected items.
---@return IteratorObject<fun(): string> @Iterator with fields: `autoBaseItemString`
function AuctioningBagScrollTable:SelectedItemsIterator()
	return Iterator.Acquire(Table.KeyIterator(self._selectedItems))
end

---Sets the selection state.
---@param allSelected boolean Whether to set the selection to all or none
---@return self
function AuctioningBagScrollTable:SetSelectionState(allSelected)
	local changed = false
	if allSelected then
		for _, autoBaseItemString, firstOperation in self._query:Iterator("autoBaseItemString", "firstOperation") do
			if firstOperation and not self._selectedItems[autoBaseItemString] then
				self._selectedItems[autoBaseItemString] = true
				changed = true
			end
		end
	else
		changed = next(self._selectedItems) and true or false
		wipe(self._selectedItems)
	end
	if not changed then
		return self
	end

	self:_HandleQueryUpdate()
	self:_UpdateSelectionState()
	return self
end

---Binds state properties to the selection state.
---@param state ReactiveState The state to store the values in
---@param allSelectedKey string The state key to store the allSelected value at
---@param noneSelectedKey string The state key to store the noneSelected value at
---@return self
function AuctioningBagScrollTable:BindSelectionstate(state, allSelectedKey, noneSelectedKey)
	self._bindings:Add("ALL_SELECTED", state, allSelectedKey)
	self._bindings:Add("NONE_SELECTED", state, noneSelectedKey)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function AuctioningBagScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(not next(private.selectedTemp))
	for _, autoBaseItemString, itemTexture, firstOperation, groupPath in self._query:Iterator("autoBaseItemString", "itemTexture", "firstOperation", "groupPath") do
		local selected = self._selectedItems[autoBaseItemString]
		private.selectedTemp[autoBaseItemString] = selected
		tinsert(self._data.selected, selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or "")
		tinsert(self._data.item, "|T"..itemTexture..":0|t "..(UIUtils.GetDisplayItemName(autoBaseItemString) or "?"))
		tinsert(self._data.operation, firstOperation or Theme.GetColor("error/main"):ColorText(L["Skipped: No assigned operation"]))
		tinsert(self._data.group, Group.FormatPath(groupPath))
		tinsert(self._data.item_tooltip, autoBaseItemString)
	end
	wipe(self._selectedItems)
	for autoBaseItemString in pairs(private.selectedTemp) do
		self._selectedItems[autoBaseItemString] = true
	end
	wipe(private.selectedTemp)
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function AuctioningBagScrollTable.__protected:_HandleRowEnter(row)
	if IsMouseButtonDown("RightButton") and row:GetDataIndex() ~= self._dragDataIndex then
		self._dragDataIndex = row:GetDataIndex()
		self:_HandleRowClick(row, "LeftButton")
	end
end

---@param row ListRow
function AuctioningBagScrollTable.__protected:_HandleRowLeave(row)
	if not IsMouseButtonDown("RightButton") then
		self._dragDataIndex = nil
	end
end

---@param row ListRow
---@param mouseButton MouseButton
function AuctioningBagScrollTable.__protected:_HandleRowMouseDown(row, mouseButton)
	if mouseButton == "RightButton" then
		self._dragDataIndex = row:GetDataIndex()
		self:_HandleRowClick(row, "LeftButton")
	end
end

---@param row ListRow
---@param mouseButton MouseButton
function AuctioningBagScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton == "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local autoBaseItemString, firstOperation = self._query:GetNthResult(dataIndex, "autoBaseItemString", "firstOperation")
	if not firstOperation then
		return
	end
	local selected = not self._selectedItems[autoBaseItemString]
	self._selectedItems[autoBaseItemString] = selected or nil
	self._data.selected[dataIndex] = selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or ""
	self:_HandleRowDraw(row)
	self:_UpdateSelectionState()
end

function AuctioningBagScrollTable.__private:_UpdateSelectionState()
	local allSelected, noneSelected = true, true
	local iter = self._query:Iterator("autoBaseItemString", "firstOperation")
	for _, autoBaseItemString, firstOperation in iter do
		if firstOperation then
			local selected = self._selectedItems[autoBaseItemString]
			allSelected = allSelected and selected or false
			noneSelected = noneSelected and not selected
			if not allSelected and not noneSelected then
				iter:Release()
				break
			end
		end
	end
	self._bindings:Process("NONE_SELECTED", noneSelected)
	self._bindings:Process("ALL_SELECTED", allSelected)
end

---@param button ButtonExtended
---@param mouseButton MouseButton
function AuctioningBagScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	local id = Table.GetDistinctKey(self._header.cells, button)
	if not COL_INFO[id] or not COL_INFO[id].sortField then
		-- Don't allow sorting by this row
		return
	end
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

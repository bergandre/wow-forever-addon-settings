-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local COL_INFO = {
	order = {
		title = "#",
		justifyH = "LEFT",
		font = "TABLE_XSMALL",
		sortField = "order",
	},
	field = {
		title = "Field",
		justifyH = "LEFT",
		sortField = "field",
	},
	type = {
		title = TYPE,
		justifyH = "LEFT",
		sortField = "type",
	},
	attributes = {
		title = "Attributes",
		justifyH = "LEFT",
		sortField = "attributes",
	},
}
local DEFAULT_SETTINGS = {
	cols = {
		{ id = "order", width = 24, hidden = nil },
		{ id = "field", width = 350, hidden = nil },
		{ id = "type", width = 60, hidden = nil },
		{ id = "attributes", width = 200, hidden = nil },
	},
	sortCol = "order",
	sortAscending = true,
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DatabaseStructureScrollTable = ComponentRegistry.Define("DatabaseStructureScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DatabaseStructureScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil ---@type DatabaseQuery!
end

function DatabaseStructureScrollTable:Acquire()
	self.__super:Acquire()
	-- Since this is just a debug element, we don't care that we're generating extra garbage here
	self._settings = CopyTable(DEFAULT_SETTINGS)
	self:_DrawHeader()
end

function DatabaseStructureScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---@private
function DatabaseStructureScrollTable:SetSettings()
	error("Not supported for DatabaseStructureScrollTable")
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function DatabaseStructureScrollTable:SetQuery(query)
	assert(not self._query)
	self._query = query
	query
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function DatabaseStructureScrollTable.__protected:_GetSettingsValue()
	return self._settings
end

function DatabaseStructureScrollTable.__protected:_GetSettingsDefaultReadOnly()
	return DEFAULT_SETTINGS
end

function DatabaseStructureScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, order, field, fieldType, attributes in self._query:Iterator("order", "field", "type", "attributes") do
		tinsert(self._data.order, order)
		tinsert(self._data.field, field)
		tinsert(self._data.type, fieldType)
		tinsert(self._data.attributes, attributes)
	end
	self:_SetNumRows(#self._data.order)
	self:Draw()
end

function DatabaseStructureScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

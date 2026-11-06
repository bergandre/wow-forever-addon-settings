-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMUI:From("LibTSMUtil"):Include("Lua.Vararg")
local Database = LibTSMUI:From("LibTSMDatabase"):Include("Database")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local DEFAULT_COL_WIDTH = 100
local private = {
	fieldTemp = {},
	valueTemp = {},
	listValueTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DatabaseBrowseScrollTable = ComponentRegistry.Define("DatabaseBrowseScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DatabaseBrowseScrollTable:__init()
	self.__super:__init({})
	self._db = nil ---@type DatabaseTable!
	self._query = nil ---@type DatabaseQuery!
	self._fieldQuery = nil
	self._rawSettings = {
		cols = {},
	}
	self._defaultSettings = {
		cols = {},
	}
	self._recycledCells = {}
	self._isListField = {}
end

function DatabaseBrowseScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
end

function DatabaseBrowseScrollTable:Release()
	local query = self._query
	self._query = nil
	self._db = nil
	if self._fieldQuery then
		self._fieldQuery:Release()
		self._fieldQuery = nil
	end
	wipe(self._rawSettings.cols)
	wipe(self._defaultSettings.cols)
	for _, cell in pairs(self._header.cells) do
		cell:Hide()
		tinsert(self._recycledCells, cell)
	end
	wipe(self._header.cells)
	wipe(self._colInfo)
	wipe(self._isListField)
	self.__super:Release()
	wipe(self._data)
	if query then
		query:Release()
	end
end

---@private
function DatabaseBrowseScrollTable:SetSettings()
	error("Not supported for DatabaseBrowseScrollTable")
end

---Sets the DB table to browse.
---@param name string The name of the table
---@return self
function DatabaseBrowseScrollTable:SetTable(name)
	assert(not self._query and not self._fieldQuery)
	local db = Database.GetDBByName(name)
	local fieldQuery = Database.CreateInfoFieldQuery(name)
		:OrderBy("order", true)
	local query = db:NewOwnedQuery()
	self._db = db
	self._query = query
	self._fieldQuery = fieldQuery

	for _, field, fieldType in fieldQuery:Iterator("field", "type") do
		tinsert(self._rawSettings.cols, { id = field, width = DEFAULT_COL_WIDTH, hidden = nil })
		tinsert(self._defaultSettings.cols, { id = field, width = DEFAULT_COL_WIDTH, hidden = nil })
		local info = {
			title = field,
			justifyH = "LEFT",
			hasTooltip = true,
			disableTooltipLinking = true,
		}
		self._colInfo[field] = info
		self._isListField[field] = fieldType == "STRING_LIST" or fieldType == "NUMBER_LIST"
		local cell = tremove(self._recycledCells) or self:_CreateHeaderCell(info)
		self._header.cells[field] = cell
		cell.titleText:SetText(info.title) ---@diagnostic disable-line: undefined-field
		self._data[field] = {}
		self._data[field.."_tooltip"] = {}
	end
	self:_DrawHeader()

	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Updates the data from the query.
---@param codeStr string The code to lua and execute
function DatabaseBrowseScrollTable:UpdateQueryWithLoadedFunction(codeStr)
	local func, errStr = loadstring(codeStr)
	if not func then
		ChatMessage.PrintfUser("Failed to compile code: "..errStr)
		return
	end
	self._query:Reset()
	setfenv(func, { query = self._query })
	local ok, funcErrStr = pcall(func)
	if not ok then
		ChatMessage.PrintfUser("Failed to execute code: "..funcErrStr)
		self._query:Reset()
	end
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function DatabaseBrowseScrollTable.__protected:_GetSettingsValue()
	return self._rawSettings
end

function DatabaseBrowseScrollTable.__protected:_GetSettingsDefaultReadOnly()
	return self._defaultSettings
end

function DatabaseBrowseScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(#private.fieldTemp == 0)
	Table.GetKeys(self._colInfo, private.fieldTemp)
	for uuid in self._query:Iterator() do
		assert(#private.valueTemp == 0)
		Vararg.IntoTable(private.valueTemp, self._db:GetRowFields(uuid, unpack(private.fieldTemp)))
		for i, field in ipairs(private.fieldTemp) do
			local value = private.valueTemp[i]
			if self._isListField[field] then
				assert(#private.listValueTemp == 0)
				Table.InsertFromIterator(private.listValueTemp, value)
				value = table.concat(private.listValueTemp, ",")
				wipe(private.listValueTemp)
			else
				value = tostring(value)
			end
			tinsert(self._data[field], value)
			if not strmatch(value, ",") and (strmatch(value, "item:") or strmatch(value, "battlepet:") or strmatch(value, "[ip]:")) then
				-- This is an item string or item link
				tinsert(self._data[field.."_tooltip"], value)
			else
				tinsert(self._data[field.."_tooltip"], "Value: "..value)
			end
		end
		wipe(private.valueTemp)
	end
	wipe(private.fieldTemp)
	self:_SetNumRows(self._query:Count())
	self:Draw()
end

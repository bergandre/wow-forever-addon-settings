-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationsList = ComponentRegistry.Define("OperationsList", "List")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function OperationsList:__init()
	self.__super:__init()
	self._query = nil ---@type DatabaseQuery!
	self._typeName = nil
	self._filterText = nil
	self._name = {}
	self._selected = nil
end

function OperationsList:Release()
	local query = self._query
	self._query = nil
	self._typeName = nil
	self._filterText = nil
	wipe(self._name)
	self._selected = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the operation type for the list.
---@param value string|ReactivePublisherSchemaBase The operation type or a publisher
---@return self
function OperationsList:SetOperationType(value)
	if type(value) == "string" then
		assert(not self._typeName and not self._query)
		self._typeName = value
		self._query = Operation.NewQuery()
			:Equal("typeName", value)
			:OrderBy("operationName", true)
		if self._filterText then
			self._query:Contains("operationName", self._filterText)
		end
		self:AddCancellable(self._query:Publisher()
			:CallFunction(self:__closure("_HandleQueryUpdate"))
		)
	else
		self:_MethodPublisher(value, "SetOperationType")
	end
	return self
end

---Sets the module name filter.
---@param value string|ReactivePublisherSchemaBase The module name filter or a publisher
---@return self
function OperationsList:SetFilter(value)
	if type(value) == "string" then
		value = strlower(value)
		if value == self._filterText then
			return self
		end
		self._filterText = value
		if self._query then
			self._query:ResetFilters()
				:Equal("typeName", self._typeName)
				:Contains("operationName", value)
			self:_HandleQueryUpdate()
		end
	else
		self:_MethodPublisher(value, "SetFilter")
	end
	return self
end

---Binds a state property to the selected operation.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function OperationsList:BindSelection(state, key)
	self._bindings:Add("SELECTION", state, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function OperationsList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._name)
	for _, operationName in self._query:Iterator("operationName") do
		tinsert(self._name, operationName)
	end
	self:_SetNumRows(#self._name)
	self:Draw()
end

---@param row ListRow
function OperationsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("BODY_SMALL_SEMIBOLD")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function OperationsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local name = self._name[dataIndex]
	row:GetText("text"):SetText(name)
	row:SetSelected(name == self._selected)
end

---@param row ListRow
function OperationsList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	local prevDataIndex = self._selected and Table.KeyByValue(self._name, self._selected) or nil
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	self._selected = self._name[dataIndex]
	row:SetSelected(true)
	self._bindings:Process("SELECTION", self._selected)
end

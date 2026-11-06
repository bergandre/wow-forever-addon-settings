-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local COL_INFO = {
	type = {
		title = TYPE,
		justifyH = "LEFT",
		sortField = "type",
	},
	character = {
		title = CHARACTER,
		justifyH = "LEFT",
		sortField = "player",
	},
	otherCharacter = {
		title = L["Other Character"],
		justifyH = "LEFT",
		sortField = "otherPlayer",
	},
	amount = {
		title = L["Amount"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "amount",
	},
	time = {
		title = L["Time Frame"],
		justifyH = "RIGHT",
		sortField = "time",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerOtherScrollTable = UIElements.Define("LedgerOtherScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerOtherScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil ---@type DatabaseQuery!
end

function LedgerOtherScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function LedgerOtherScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query
		:ResetFilters()
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the filters.
---@param recordType string Record type
---@param typeFilter? table Type filter
---@param player? table Player filter
---@param timeFilter? number Time filter
---@return self
function LedgerOtherScrollTable:SetFilters(recordType, typeFilter, player, timeFilter)
	self._query:ResetFilters()
		:Equal("recordType", recordType)
	if typeFilter then
		self._query:InTable("type", typeFilter)
	end
	if player then
		self._query:InTable("player", player)
	end
	if timeFilter then
		self._query:GreaterThan("time", App.GetTime() - timeFilter)
	end
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerOtherScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, typeStr, player, otherPlayer, amount, recordTime in self._query:Iterator("typeStr", "player", "otherPlayer", "amount", "time") do
		tinsert(self._data.type, typeStr)
		tinsert(self._data.character, player)
		tinsert(self._data.otherCharacter, otherPlayer)
		tinsert(self._data.amount, Money.ToStringForUI(amount))
		tinsert(self._data.time, TimeFormat.Duration(App.GetTime() - recordTime))
	end
	self:_SetNumRows(#self._data.type)
	self:Draw()
end

function LedgerOtherScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

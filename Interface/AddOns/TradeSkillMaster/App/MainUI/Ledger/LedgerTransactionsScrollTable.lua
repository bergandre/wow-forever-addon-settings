-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local COL_INFO = {
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	player = {
		title = PLAYER,
		justifyH = "LEFT",
		sortField = "otherPlayer",
	},
	type = {
		title = TYPE,
		justifyH = "LEFT",
		sortField = "source",
	},
	stack = {
		title = L["Stack"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "stackSize",
	},
	auctions = {
		title = L["Auctions"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "auctions",
	},
	perItem = {
		title = L["Per Item"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "price",
	},
	total = {
		title = L["Total"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "total",
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

local LedgerTransactionsScrollTable = UIElements.Define("LedgerTransactionsScrollTable", "ScrollTable")
LedgerTransactionsScrollTable:_AddActionScripts("OnItemRowClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerTransactionsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
	self._createdGroupName = nil
end

function LedgerTransactionsScrollTable:Release()
	self._query = nil
	self._createdGroupName = nil
	self.__super:Release()
end

---Sets the name to assign to the group created from this table.
---@param name string The group name
---@return self
function LedgerTransactionsScrollTable:SetCreatedGroupName(name)
	assert(name)
	self._createdGroupName = name
	return self
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function LedgerTransactionsScrollTable:SetQuery(query)
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
---@param type string Type filter
---@param name? string Item name filter
---@param source? string[] Source filter
---@param quality? string[] Quality filter
---@param player? string[] Player filter
---@param minTimeFrame? number Minimum time frame
---@param group? string[] Group filter
---@return self
function LedgerTransactionsScrollTable:SetFilters(type, name, source, quality, player, minTimeFrame, group)
	self._query:ResetFilters()
		:Equal("type", type)
	if name then
		self._query:Matches("name", name)
	end
	if source then
		self._query:InTable("source", source)
	end
	if quality then
		self._query:InTable("quality", quality)
	end
	if player then
		self._query:InTable("player", player)
	end
	if minTimeFrame then
		self._query:GreaterThan("time", App.GetTime() - minTimeFrame)
	end
	if group then
		self._query:InTable("groupPath", group)
	end
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerTransactionsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(self._createdGroupName)
	wipe(self._createGroupsData)
	for _, filteredItemString in self._query:Iterator("filteredItemString") do
		self._createGroupsData[filteredItemString] = self._createdGroupName
	end
	self:_UpdateDataDeferredLoading(self._query:Count())
end

function LedgerTransactionsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local itemString, otherPlayer, source, stackSize, auctions, price, total, recordTime = self._query:GetNthResult(dataIndex, "filteredItemString", "otherPlayer", "source", "stackSize", "auctions", "price", "total", "time")
	self._data.item[dataIndex] = "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?")
	self._data.item_tooltip[dataIndex] = itemString
	self._data.player[dataIndex] = otherPlayer
	self._data.type[dataIndex] = source
	self._data.stack[dataIndex] = stackSize
	self._data.auctions[dataIndex] = auctions
	self._data.perItem[dataIndex] = Money.ToStringForUI(price)
	self._data.total[dataIndex] = Money.ToStringForUI(total)
	self._data.time[dataIndex] = TimeFormat.Duration(App.GetTime() - recordTime)
end

---@param row ListRow
function LedgerTransactionsScrollTable.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnItemRowClick", self._query:GetNthResult(dataIndex, "filteredItemString"))
end

function LedgerTransactionsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

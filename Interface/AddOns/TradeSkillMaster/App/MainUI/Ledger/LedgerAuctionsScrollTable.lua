-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
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
		title = CHARACTER,
		justifyH = "RIGHT",
		sortField = "player",
	},
	stackSize = {
		title = L["Stack"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "stackSize",
	},
	quantity = {
		title = L["Auctions"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "auctions",
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

local LedgerAuctionsScrollTable = UIElements.Define("LedgerAuctionsScrollTable", "ScrollTable")
LedgerAuctionsScrollTable:_AddActionScripts("OnItemRowClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerAuctionsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
	self._createdGroupName = nil
end

function LedgerAuctionsScrollTable:Release()
	self._query = nil
	self._createdGroupName = nil
	self.__super:Release()
end

---Sets the name to assign to the group created from this table.
---@param name string The group name
---@return self
function LedgerAuctionsScrollTable:SetCreatedGroupName(name)
	assert(name)
	self._createdGroupName = name
	return self
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function LedgerAuctionsScrollTable:SetQuery(query)
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
---@param name? string Name filter
---@param quality? table Quality filter
---@param player? table Player filter
---@param timeFilter? number Time filter
---@param group? table Group filter
---@return self
function LedgerAuctionsScrollTable:SetFilters(recordType, name, quality, player, timeFilter, group)
	self._query:ResetFilters()
		:Equal("type", recordType)
	if name then
		self._query:Matches("name", name)
	end
	if quality then
		self._query:InTable("quality", quality)
	end
	if player then
		self._query:InTable("player", player)
	end
	if timeFilter then
		self._query:GreaterThanOrEqual("time", App.GetTime() - timeFilter)
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

function LedgerAuctionsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(self._createdGroupName)
	wipe(self._createGroupsData)
	for _, itemString, player, stackSize, auctions, recordTime in self._query:Iterator("filteredItemString", "player", "stackSize", "auctions", "time") do
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.player, player)
		tinsert(self._data.stackSize, stackSize)
		tinsert(self._data.quantity, auctions)
		tinsert(self._data.time, TimeFormat.Duration(App.GetTime() - recordTime))
		self._createGroupsData[itemString] = self._createdGroupName
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function LedgerAuctionsScrollTable.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnItemRowClick", self._query:GetNthResult(dataIndex, "filteredItemString"))
end

function LedgerAuctionsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

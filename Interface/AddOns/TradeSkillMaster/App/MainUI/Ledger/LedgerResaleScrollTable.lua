-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
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
	bought = {
		title = L["Bought"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "bought",
	},
	avgBuyPrice = {
		title = L["Avg Buy Price"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "avgBuyPrice",
	},
	sold = {
		title = L["Sold"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "sold",
	},
	avgSellPrice = {
		title = L["Avg Sell Price"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "avgSellPrice",
	},
	avgProfit = {
		title = L["Avg Profit"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "avgProfit",
	},
	totalProfit = {
		title = L["Total Profit"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "totalProfit",
	},
	profitPct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "profitPct",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerResaleScrollTable = UIElements.Define("LedgerResaleScrollTable", "ScrollTable")
LedgerResaleScrollTable:_AddActionScripts("OnItemRowClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerResaleScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function LedgerResaleScrollTable:Release()
	self._query = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function LedgerResaleScrollTable:SetQuery(query)
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
---@param quality? string[] Quality filter
---@return self
function LedgerResaleScrollTable:SetFilters(quality)
	self._query:ResetFilters()
	if quality then
		self._query:InTable("quality", quality)
	end
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerResaleScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, itemString in self._query:Iterator("itemString") do
		self._createGroupsData[itemString] = L["Ledger"].." - "..L["Resale"]
	end
	self:_UpdateDataDeferredLoading(self._query:Count())
end

function LedgerResaleScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local itemString, bought, avgBuyPrice, sold, avgSellPrice, avgProfit, totalProfit, profitPct = self._query:GetNthResult(dataIndex, "itemString", "bought", "avgBuyPrice", "sold", "avgSellPrice", "avgProfit", "totalProfit", "profitPct")
	self._data.item[dataIndex] = "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?")
	self._data.item_tooltip[dataIndex] = itemString
	self._data.bought[dataIndex] = bought
	self._data.avgBuyPrice[dataIndex] = Money.ToStringForUI(avgBuyPrice)
	self._data.sold[dataIndex] = sold
	self._data.avgSellPrice[dataIndex] = Money.ToStringForUI(avgSellPrice)
	local profitColor = Theme.GetColor(avgProfit >= 0 and "positive/main" or "error/main")
	self._data.avgProfit[dataIndex] = Money.ToStringForUI(avgProfit, profitColor:GetTextColorPrefix())
	self._data.totalProfit[dataIndex] = Money.ToStringForUI(totalProfit, profitColor:GetTextColorPrefix())
	self._data.profitPct[dataIndex] = profitColor:ColorText(profitPct.."%")
end

---@param row ListRow
function LedgerResaleScrollTable.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnItemRowClick", self._query:GetNthResult(dataIndex, "itemString"))
end

function LedgerResaleScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

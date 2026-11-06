-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Group = App:From("LibTSMTypes"):Include("Group")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local COL_INFO = {
	queued = {
		titleIcon = "iconPack.18x18/Queue",
		justifyH = "CENTER",
		font = "TABLE_XSMALL",
		sortField = "num",
	},
	craftName = {
		title = NAME,
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "itemName",
	},
	operation = {
		title = L["Operation"],
		justifyH = "LEFT",
		sortField = "firstOperation",
	},
	bags = {
		title = L["Bag"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "bagQuantity",
	},
	ah = {
		title = L["AH"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "auctionQuantity",
	},
	craftingCost = {
		title = L["Crafting Cost"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "craftingCost",
	},
	itemValue = {
		title = L["Item Value"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "itemValue",
	},
	profit = {
		title = L["Profit"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "profit",
	},
	profitPct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "profitPct",
	},
	saleRate = {
		titleIcon = "iconPack.18x18/SaleRate",
		justifyH = "CENTER",
		font = "TABLE_XSMALL",
		sortField = "saleRate",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftsScrollTable = UIElements.Define("CraftsScrollTable", "ScrollTable")
CraftsScrollTable:_AddActionScripts("OnQueueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "craftName_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function CraftsScrollTable:Release()
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
function CraftsScrollTable:SetQuery(query)
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
---@param name? string Item name filter
---@param profession? string Profession filter (must be passed along with `character`)
---@param character? string Character filter (must be passed along with `profession`)
---@param craftableFilterFunc? fun(craftString: string): boolean Craftable filter function
function CraftsScrollTable:SetFilters(name, profession, character, craftableFilterFunc)
	self._query:ResetFilters()
	if name then
		self._query:Matches("itemName", name)
	end
	if profession then
		assert(character)
		self._query:Equal("profession", profession)
		self._query:ListContains("characters", character)
	else
		assert(not character)
	end
	if craftableFilterFunc then
		self._query:Function("craftString", craftableFilterFunc)
	end
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function CraftsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, num, itemString, name, firstOperation, bagQuantity, auctionQuantity, profession in self._query:Iterator("num", "itemString", "name", "firstOperation", "bagQuantity", "auctionQuantity", "profession") do
		tinsert(self._data.queued, num)
		tinsert(self._data.craftName, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or name))
		tinsert(self._data.craftName_tooltip, itemString)
		tinsert(self._data.operation, firstOperation)
		tinsert(self._data.bags, bagQuantity or "0")
		tinsert(self._data.ah, auctionQuantity or "0")
		tinsert(self._data.craftingCost, self.DEFERRED_DATA)
		tinsert(self._data.itemValue, self.DEFERRED_DATA)
		tinsert(self._data.profit, self.DEFERRED_DATA)
		tinsert(self._data.profitPct, self.DEFERRED_DATA)
		tinsert(self._data.saleRate, self.DEFERRED_DATA)
		self._createGroupsData[itemString] = Group.JoinPath(L["Crafted Items"], profession)
	end
	self:_SetNumRows(#self._data.queued)
	self:Draw()
end

function CraftsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local craftingCost, itemValue, profit, profitPct, saleRate = self._query:GetNthResult(dataIndex, "craftingCost", "itemValue", "profit", "profitPct", "saleRate")
	self._data.craftingCost[dataIndex] = Math.IsNan(craftingCost) and "" or Money.ToStringForUI(craftingCost)
	self._data.itemValue[dataIndex] = Math.IsNan(itemValue) and "" or Money.ToStringForUI(itemValue)
	self._data.profit[dataIndex] = Math.IsNan(profit) and "" or Money.ToStringForUI(profit, Theme.GetColor(profit >= 0 and "positive/main" or "error/main"):GetTextColorPrefix())
	self._data.profitPct[dataIndex] = Math.IsNan(profitPct) and "" or Theme.GetColor(profitPct >= 0 and "positive/main" or "error/main"):ColorText(profitPct.."%")
	self._data.saleRate[dataIndex] = Math.IsNan(saleRate) and "" or format("%0.2f", saleRate)
end

---@param row ListRow
function CraftsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local craftString = self._query:GetNthResult(dataIndex, "craftString")
	if mouseButton == "LeftButton" then
		self:_SendActionScript("OnQueueChanged", craftString, 1)
	elseif mouseButton == "RightButton" then
		self:_SendActionScript("OnQueueChanged", craftString, -1)
	end
end

function CraftsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

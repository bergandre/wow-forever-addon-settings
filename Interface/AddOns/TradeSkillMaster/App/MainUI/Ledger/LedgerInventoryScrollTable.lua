-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
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
	totalItems = {
		title = L["Total"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "totalQuantity",
	},
	bags = {
		title = L["Bags"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "bagQuantity",
	},
	banks = {
		title = L["Banks"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "totalBankQuantity",
	},
	mail = {
		title = L["Mail"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "mailQuantity",
	},
	alts = {
		title = L["Alts"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "altQuantity",
	},
	guildVault = {
		title = GUILD,
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "guildQuantity",
	},
	auctionHouse = {
		title = L["AH"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "auctionQuantity",
	},
	totalValue = {
		title = L["Value"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "totalValue",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerInventoryScrollTable = UIElements.Define("LedgerInventoryScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerInventoryScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function LedgerInventoryScrollTable:Release()
	self._query = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function LedgerInventoryScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query
		:ResetFilters()
		:NotEqual("name", "")
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the filters.
---@param name? string Name filter
---@param group? string[] Group filter
---@return self
function LedgerInventoryScrollTable:SetFilters(name, group)
	self._query:ResetFilters()
		:NotEqual("name", "")
	if name then
		self._query:Matches("name", name)
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

function LedgerInventoryScrollTable.__private:_HandleQueryUpdate()
	wipe(self._createGroupsData)
	for _, levelItemString in self._query:Iterator("levelItemString") do
		self._createGroupsData[levelItemString] = L["Ledger"].." - "..L["Inventory"]
	end
	self:_UpdateDataDeferredLoading(self._query:Count())
end

function LedgerInventoryScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local levelItemString, totalQuantity, bagQuantity, totalBankQuantity, mailQuantity, altQuantity, guildQuantity, auctionQuantity, totalValue = self._query:GetNthResult(dataIndex, "levelItemString", "totalQuantity", "bagQuantity", "totalBankQuantity", "mailQuantity", "altQuantity", "guildQuantity", "auctionQuantity", "totalValue")
	self._data.item[dataIndex] = "|T"..(ItemInfo.GetTexture(levelItemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(levelItemString) or "?")
	self._data.item_tooltip[dataIndex] = levelItemString
	self._data.totalItems[dataIndex] = totalQuantity
	self._data.bags[dataIndex] = bagQuantity
	self._data.banks[dataIndex] = totalBankQuantity
	self._data.mail[dataIndex] = mailQuantity
	self._data.alts[dataIndex] = altQuantity
	self._data.guildVault[dataIndex] = guildQuantity
	self._data.auctionHouse[dataIndex] = auctionQuantity
	self._data.totalValue[dataIndex] = Math.IsNan(totalValue) and "" or Money.ToStringForUI(totalValue)
end

function LedgerInventoryScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end


-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local COL_INFO = {
	qty = {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "quantity",
	},
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableTooltipLinking = true,
		disableHiding = true,
		sortField = "name",
	},
	cost = {
		title = L["Cost"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "price",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorBuybackScrollTable = UIElements.Define("VendorBuybackScrollTable", "ScrollTable")
VendorBuybackScrollTable:_AddActionScripts("OnBuyback")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorBuybackScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function VendorBuybackScrollTable:Release()
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
function VendorBuybackScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function VendorBuybackScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, quantity, itemString, price in self._query:Iterator("quantity", "itemString", "price") do
		tinsert(self._data.qty, quantity)
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.cost, Money.ToStringForUI(price))
		self._createGroupsData[itemString] = L["Vendoring"].." - "..L["Buyback"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function VendorBuybackScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnBuyback", self._query:GetNthResult(dataIndex, "index"))
end

function VendorBuybackScrollTable.__protected:_HandleRowEnter()
	SetCursor("BUY_CURSOR")
end

function VendorBuybackScrollTable.__protected:_HandleRowLeave()
	SetCursor(nil)
end

function VendorBuybackScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

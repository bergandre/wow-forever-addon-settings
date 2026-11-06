-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	index = {
		titleIcon = "iconPack.14x14/Attention",
		justifyH = "CENTER",
		hasTooltip = true,
		disableTooltipLinking = true,
		sortField = "index",
	},
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	buyout = {
		title = L["Your Buyout"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "buyout",
	},
	operation = {
		title = L["Operation"],
		justifyH = "LEFT",
		sortField = "operation",
	},
	seller = {
		title = L["Seller"],
		justifyH = "LEFT",
		sortField = "seller",
	},
	info = {
		title = INFO,
		justifyH = "LEFT",
		sortField = "reasonStr",
		hasTooltip = true,
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningLogScrollTable = ComponentRegistry.Define("AuctioningLogScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningLogScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
	self._data.rawIndex = {}
	self._selectedIndex = nil
end

function AuctioningLogScrollTable:Release()
	local query = self._query
	self._query = nil
	self._selectedIndex = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function AuctioningLogScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the selected row.
---@param value? number|ReactivePublisherSchemaBase The index to select or a publisher
---@return self
function AuctioningLogScrollTable:SetSelectedIndex(value)
	if value == nil or type(value) == "number" then
		local dataIndex = value and Table.KeyByValue(self._data.rawIndex, value) or nil
		local prevDataIndex = self._selectedIndex and Table.KeyByValue(self._data.rawIndex, self._selectedIndex) or nil
		if value == nil and self._selectedIndex == nil then
			return self
		elseif value == self._selectedIndex and dataIndex then
			self:_ScrollToRow(dataIndex)
			return self
		end
		-- NOTE: We explicitly allow setting a selected index which isn't yet part of our data
		local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
		if prevRow then
			prevRow:SetSelected(false)
		end
		self._selectedIndex = value
		if dataIndex then
			local newRow = self:_GetRow(dataIndex)
			if newRow then
				newRow:SetSelected(true)
			end
			self:_ScrollToRow(dataIndex)
		end
	else
		self:_MethodPublisher(value, "SetSelectedIndex")
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function AuctioningLogScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, indexIcon, itemString, buyout, operation, seller, infoStr, infoTooltip, index in self._query:Iterator("indexIcon", "itemString", "buyout", "operation", "seller", "infoStr", "reasonContext", "index") do
		tinsert(self._data.index, TextureAtlas.GetTextureLink(indexIcon))
		tinsert(self._data.index_tooltip, infoTooltip ~= "" and infoTooltip or infoStr)
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.buyout, buyout == 0 and "-" or Money.ToStringForAH(buyout))
		tinsert(self._data.operation, operation)
		tinsert(self._data.seller, seller)
		tinsert(self._data.info, infoStr)
		tinsert(self._data.info_tooltip, infoTooltip)
		tinsert(self._data.rawIndex, index)
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function AuctioningLogScrollTable.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	self.__super:_HandleRowDraw(row)
	row:SetSelected(self._data.rawIndex[dataIndex] == self._selectedIndex)
end

function AuctioningLogScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

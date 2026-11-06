-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local HEADER_HEIGHT = 20
local HEADER_LINE_HEIGHT = 1
local HEADER_LINE_WIDTH = 1
local QUANTITY_COL_WIDTH = 60



-- ============================================================================
-- Element Definition
-- ============================================================================

local SendItemsList = UIElements.Define("SendItemsList", "List")
SendItemsList:_AddActionScripts("OnRemoveItem")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SendItemsList:__init()
	self.__super:__init()

	self._data = {
		item = {},
		itemTooltip = {},
		quantity = {},
	}
	self._query = nil ---@type DatabaseQuery!

	local headerBgPublisher = self:_GetOneShotPublisher("container/low")
		:Share()
	local outlinePublisher = self:_GetOneShotPublisher("outline/variant")
		:Share()

	local header = self:_CreateFrame(self._hContent)
	self._header = header
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)

	local headerBackground = self:_CreateRectangle(nil, header)
	headerBackground:SetRoundedCorners("TOP")
	headerBackground:SetCornerRadius(self._state:Publisher("headerCornerRadius"))
	headerBackground:SubscribeColor(headerBgPublisher)

	local lineBottom = self:_CreateTexture(self._hContent)
	self._lineBottom = lineBottom
	lineBottom:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	lineBottom:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
	lineBottom:SetHeight(HEADER_LINE_HEIGHT)
	lineBottom:TSMSubscribeColorTexture(outlinePublisher)

	self._vScrollFrame:SetPoint("TOPLEFT", lineBottom, "BOTTOMLEFT")
	self._vScrollbar:SetPoint("TOPRIGHT", -Theme.GetScrollbarMargin(), -Theme.GetScrollbarMargin() - HEADER_HEIGHT - HEADER_LINE_HEIGHT)

	local colSpacing = Theme.GetColSpacing()

	local itemCell = self:_CreateHeaderCell(L["Items"], "LEFT")
	local quantityCell = self:_CreateHeaderCell(L["Amount"], "RIGHT")
	self._header.item = itemCell
	self._header.quantity = quantityCell
	quantityCell:SetPoint("RIGHT", -colSpacing / 2, 0)
	quantityCell:SetWidth(QUANTITY_COL_WIDTH)
	itemCell:SetPoint("LEFT", colSpacing / 2, 0)
	itemCell:SetPoint("RIGHT", quantityCell, "LEFT", -colSpacing, 0)
	quantityCell.sepIcon:Hide()

	headerBgPublisher:EndShare()
	outlinePublisher:EndShare()
end

function SendItemsList:Release()
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	self._query = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function SendItemsList:SetQuery(query)
	assert(not self._query)
	self._query = query
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SendItemsList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, itemString, quantity in self._query:Iterator("itemString", "quantity") do
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.itemTooltip, itemString)
		tinsert(self._data.quantity, quantity)
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

function SendItemsList.__private:_CreateHeaderCell(title, justifyH)
	local colSpacing = Theme.GetColSpacing()
	local cell = self:_CreateButton(self._header)
	cell:SetHeight(HEADER_HEIGHT)

	local sepIcon = self:_CreateTexture(cell, "BORDER")
	cell.sepIcon = sepIcon ---@diagnostic disable-line: inject-field
	sepIcon:SetWidth(HEADER_LINE_WIDTH)
	sepIcon:SetPoint("TOP", cell, "TOPRIGHT", colSpacing / 2, 0)
	sepIcon:SetPoint("BOTTOM", cell, "BOTTOMRIGHT", colSpacing / 2, 0)
	sepIcon:TSMSubscribeColorTexture(self:_GetOneShotPublisher("outline/variant"))

	local text = self:_CreateFontString(cell)
	cell.titleText = text ---@diagnostic disable-line: inject-field
	text:SetAllPoints(cell)
	text:TSMSetFont("BODY_XSMALL")
	text:SetJustifyH(justifyH)
	text:SetText(title)

	return cell
end

---@param row ListRow
function SendItemsList.__protected:_HandleRowAcquired(row)
	local item = row:AddText("item")
	item:SetHeight(self.ROW_HEIGHT)
	item:TSMSetFont("ITEM_XSMALL")
	item:SetJustifyH("LEFT")
	row:AddTooltipRegion("itemTooltip", item, self:__closure("_GetRowTooltip"))

	local quantity = row:AddText("quantity")
	quantity:SetHeight(self.ROW_HEIGHT)
	quantity:TSMSetFont("BODY_XSMALL")
	quantity:SetJustifyH("RIGHT")

	local colSpacing = Theme.GetColSpacing()
	quantity:SetPoint("RIGHT", -colSpacing / 2, 0)
	quantity:SetWidth(QUANTITY_COL_WIDTH)
	item:SetPoint("LEFT", colSpacing / 2, 0)
	item:SetPoint("RIGHT", quantity, "LEFT", -colSpacing, 0)
end

---@param row ListRow
function SendItemsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("item"):SetText(self._data.item[dataIndex])
	row:GetText("quantity"):SetText(self._data.quantity[dataIndex])
end

function SendItemsList.__private:_GetRowTooltip(dataIndex, key)
	if key ~= "itemTooltip" then
		error("Invalid tooltip key: "..tostring(key))
	end
	return self._data.itemTooltip[dataIndex]
end

---@param row ListRow
function SendItemsList.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnRemoveItem", self._query:GetNthResultWithUUID(dataIndex))
end

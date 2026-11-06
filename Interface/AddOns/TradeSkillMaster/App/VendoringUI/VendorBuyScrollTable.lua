-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Util = App:Include("VendoringUI.Util")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Vendor = App:From("LibTSMService"):Include("Vendor")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local COL_INFO = {
	qty = {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "stackSize",
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
	ilvl = {
		title = L["ilvl"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "itemLevel",
	},
	cost = {
		title = L["Cost"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		hasTooltip = true,
		disableTooltipLinking = true,
		sortField = "price",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorBuyScrollTable = UIElements.Define("VendorBuyScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorBuyScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function VendorBuyScrollTable:Release()
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
function VendorBuyScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query
		:ResetFilters()
		:NotEqual("numAvailable", 0)
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the filter.
---@param nameValue? string|ReactivePublisherSchemaBase The name filter or a publisher
---@return self
function VendorBuyScrollTable:SetFilters(nameValue)
	if nameValue == nil or type(nameValue) == "string" then
		---@cast nameValue string|nil
		self._query:ResetFilters()
			:NotEqual("numAvailable", 0)
		if nameValue then
			self._query:Matches("name", String.Escape(nameValue))
		end
		self:_HandleQueryUpdate()
	else
		self:_MethodPublisher(nameValue, "SetFilters")
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function VendorBuyScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, stackSize, itemString, numAvailable, itemLevel, index, costItemsIter in self._query:Iterator("stackSize", "itemString", "numAvailable", "itemLevel", "index", "costItems") do
		tinsert(self._data.qty, stackSize)
		local itemText = "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?")
		if numAvailable > 0 then
			itemText = itemText..Theme.GetColor("error/main"):ColorText(" ("..numAvailable..")")
		elseif numAvailable ~= -1 then
			error("Invalid numAvailable: "..numAvailable)
		end
		tinsert(self._data.item, itemText)
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.ilvl, itemLevel == -1 and "" or itemLevel)
		tinsert(self._data.cost, Util.GetAltCostText(index, stackSize))
		tinsert(self._data.cost_tooltip, select(2, costItemsIter:GetValueAndRelease()) or false)
		self._createGroupsData[itemString] = L["Vendoring"].." - "..L["Buy"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function VendorBuyScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	if IsShiftKeyDown() then
		local itemString, index, costItemsIter = self._query:GetNthResult(dataIndex, "itemString", "index", "costItems")
		local _, firstCostItem = costItemsIter:GetValueAndRelease()
		local dialogFrame = UIElements.New("VendorQuantityDialog", "dialog")
			:Configure(index, itemString, firstCostItem)
		self:GetBaseElement():ShowDialogFrame(dialogFrame)
		dialogFrame:SetQuantityInputFocused(true)
	elseif mouseButton == "RightButton" then
		local index, stackSize = self._query:GetNthResult(dataIndex, "index", "stackSize")
		Vendor.BuyIndex(index, stackSize)
	else
		return
	end
end

function VendorBuyScrollTable.__protected:_HandleRowEnter(row)
	local dataIndex = row:GetDataIndex()
	local index = self._query:GetNthResult(dataIndex, "index")
	if Vendor.GetNumCanAfford(index) > 0 then
		SetCursor("BUY_CURSOR")
	else
		SetCursor("BUY_ERROR_CURSOR")
	end
end

function VendorBuyScrollTable.__protected:_HandleRowLeave()
	SetCursor(nil)
end

function VendorBuyScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

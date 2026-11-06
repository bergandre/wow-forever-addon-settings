-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local String = App:From("LibTSMUtil"):Include("Lua.String")
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
		disableTooltipLinking = true,
		disableHiding = true,
		sortField = "name",
	},
	vendorSell = {
		title = L["Vendor Sell"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "vendorSell",
	},
	potential = {
		title = L["Potential"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "potentialValue",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorSellScrollTable = UIElements.Define("VendorSellScrollTable", "ScrollTable")
VendorSellScrollTable:_AddActionScripts("OnIgnoreItem", "OnSellItem")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorSellScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
	self._queryResetFiltersFunc = nil
end

function VendorSellScrollTable:Release()
	self._query = nil
	self._queryResetFiltersFunc = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@param resetFiltersFunc fun(query: DatabaseQuery) Function to reset the filters on the query
---@return self
function VendorSellScrollTable:SetQuery(query, resetFiltersFunc)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	self._queryResetFiltersFunc = resetFiltersFunc
	resetFiltersFunc(query)
	query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the filter.
---@param nameValue? string|ReactivePublisherSchemaBase The name filter or a publisher
---@return self
function VendorSellScrollTable:SetFilters(nameValue)
	if nameValue == nil or type(nameValue) == "string" then
		---@cast nameValue string|nil
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

function VendorSellScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	wipe(self._actionIcon)
	for _, itemString, vendorSell, potentialValue in self._query:Iterator("itemString", "vendorSell", "potentialValue") do
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.vendorSell, vendorSell > 0 and Money.ToStringForUI(vendorSell) or "")
		tinsert(self._data.potential, (potentialValue or 0) > 0 and Money.ToStringForUI(potentialValue) or "")
		self._createGroupsData[itemString] = L["Vendoring"].." - "..L["Sell"]
		tinsert(self._actionIcon, "iconPack.12x12/Hide")
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function VendorSellScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	row:AddMouseRegion("actionIcon_mouse", row:GetTexture("actionIcon"), self:__closure("_GetActionIconTooltip"), self:__closure("_HandleActionIconClick"))
end

---@param row ListRow
function VendorSellScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local itemString = self._query:GetNthResult(dataIndex, "itemString")
	self:_SendActionScript("OnSellItem", itemString)
end

---@param row ListRow
function VendorSellScrollTable.__protected:_HandleRowEnter(row)
	local actionIcon = row:GetButton("actionIcon_mouse")
	if actionIcon:IsMouseOver() then
		SetCursor(nil)
	else
		SetCursor("BUY_CURSOR")
	end
end

function VendorSellScrollTable.__protected:_HandleRowLeave()
	SetCursor(nil)
end

function VendorSellScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

function VendorSellScrollTable.__private:_GetActionIconTooltip()
	return L["Click to hide this item for the current session. Hold shift to hide this item permanently."]
end

function VendorSellScrollTable.__private:_HandleActionIconClick(mouseButton, dataIndex)
	if mouseButton ~= "LeftButton" then
		return
	end
	local itemString = self._query:GetNthResult(dataIndex, "itemString")
	self:_SendActionScript("OnIgnoreItem", itemString, IsShiftKeyDown())
end

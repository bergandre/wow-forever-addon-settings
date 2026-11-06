-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local COL_INFO = {
	activityType = {
		title = L["Activity Type"],
		justifyH = "LEFT",
		sortField = "type",
	},
	source = {
		title = L["Source"],
		justifyH = "LEFT",
		sortField = "source",
	},
	buyerSeller = {
		title = L["Buyer/Seller"],
		justifyH = "LEFT",
		sortField = "otherPlayer",
	},
	qty = {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "quantity",
	},
	perItem = {
		title = L["Per Item"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "price",
	},
	totalPrice = {
		title = L["Total Price"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "totalPrice",
	},
	time = {
		title = L["Time Frame"],
		justifyH = "RIGHT",
		sortField = "time",
	},
}
local ACTIVITY_TYPE_LOOKUP = { ---@type table<LedgerTransactionType,string>
	sale = L["Sale"],
	buy = L["Buy"],
}

---@alias LedgerDetailScrollTableDeleteValidateFunc fun(uuid: number): boolean
---@alias LedgerDetailScrollTableDeleteFunc fun(uuid: number)



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerDetailScrollTable = UIElements.Define("LedgerDetailScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerDetailScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil ---@type DatabaseQuery!
	self._deleteValidateFunc = nil ---@type LedgerDetailScrollTableDeleteValidateFunc!
	self._deleteFunc = nil ---@type LedgerDetailScrollTableDeleteFunc!
end

function LedgerDetailScrollTable:Release()
	local query = self._query
	self._query = nil
	self._deleteValidateFunc = nil
	self._deleteFunc = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function LedgerDetailScrollTable:SetQuery(query)
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

---Sets functions to use to delete records.
---@param validateFunc LedgerDetailScrollTableDeleteValidateFunc Function to check if a DB entry can be deleted
---@param deleteFunc LedgerDetailScrollTableDeleteFunc Function to delete a DB entry
---@return self
function LedgerDetailScrollTable:SetDeleteFunctions(validateFunc, deleteFunc)
	self._deleteValidateFunc = validateFunc
	self._deleteFunc = deleteFunc
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerDetailScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, recordType, source, otherPlayer, quantity, price, totalPrice, recordTime in self._query:Iterator("type", "source", "otherPlayer", "quantity", "price", "totalPrice", "time") do
		local activityType = ACTIVITY_TYPE_LOOKUP[recordType]
		assert(activityType)
		tinsert(self._data.activityType, activityType)
		tinsert(self._data.source, source)
		tinsert(self._data.buyerSeller, otherPlayer)
		tinsert(self._data.qty, quantity)
		tinsert(self._data.perItem, Money.ToStringForUI(price))
		tinsert(self._data.totalPrice, Money.ToStringForUI(totalPrice))
		tinsert(self._data.time, TimeFormat.Duration(App.GetTime() - recordTime))
	end
	self:_SetNumRows(#self._data.activityType)
	self:Draw()
end

---@param row ListRow
function LedgerDetailScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end

	local dataIndex = row:GetDataIndex()
	local uuid = self._query:GetNthResultWithUUID(dataIndex)
	assert(uuid)
	if not self._deleteValidateFunc(uuid) then
		ChatMessage.PrintUser(L["This record belongs to another account and can only be deleted on that account."])
		return
	end

	local subtitle = nil
	local recordType, itemString, quantity, otherPlayer, price = self._query:GetNthResult(dataIndex, "type", "itemString", "quantity", "otherPlayer", "price")
	local name = UIUtils.GetDisplayItemName(itemString) or "?"
	local amount = Money.ToStringForUI(price * quantity)
	if recordType == "sale" then
		subtitle = format(L["Sold %d of %s to %s for %s"], quantity, name, otherPlayer, amount)
	elseif recordType == "buy" then
		subtitle = format(L["Bought %d of %s from %s for %s"], quantity, name, otherPlayer, amount)
	else
		error("Unexpected Type: "..tostring(recordType))
	end
	local deleteFunc = self._deleteFunc
	assert(deleteFunc)
	self:GetBaseElement():ShowConfirmationDialog(L["Delete Record?"], subtitle, deleteFunc, uuid)
end

function LedgerDetailScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

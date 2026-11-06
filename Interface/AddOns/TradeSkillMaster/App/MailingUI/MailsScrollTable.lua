
-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Database = App:From("LibTSMDatabase"):Include("Database")
local Inbox = App:From("LibTSMWoW"):Include("API.Inbox")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Mail = App:From("LibTSMService"):Include("Mail")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AUCTION_SOLD_PATTERN_STR = String.FormatToMatchPattern(GlobalStrings.Get("AUCTION_SOLD_MAIL_SUBJECT"))
local COL_INFO = {
	items = {
		title = L["Items"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableTooltipLinking = true,
		disableHiding = true,
	},
	sender = {
		title = L["Sender"],
		justifyH = "LEFT",
	},
	expires = {
		title = L["Expires"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
	money = {
		title = L["Gold"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailsScrollTable = UIElements.Define("MailsScrollTable", "ScrollTable")
MailsScrollTable:_AddActionScripts("OnRowClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "items_tooltip"
	self._query = nil ---@type DatabaseQuery!
	self._filter = nil
	self._itemsQuery = nil ---@type DatabaseQuery!
	self._soldItemStrings = {} ---@type table<string,string>
end

function MailsScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
	self._itemsQuery = Mail.NewItemQuery()
		:Equal("index", Database.BoundQueryParam())
		:GreaterThan("itemIndex", 0)
		:OrderBy("itemIndex", true)
end

function MailsScrollTable:Release()
	self._query = nil
	self._filter = nil
	self._itemsQuery:Release()
	self._itemsQuery = nil
	wipe(self._soldItemStrings)
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function MailsScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	if self._filter then
		query
			:Or()
				:Matches("itemList", self._filter)
				:Matches("subject", self._filter)
			:End()
	end
	self._query = query
	query:ResetFilters()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the filters.
---@param value? string|ReactivePublisherSchemaBase Text filter or a publisher
---@return self
function MailsScrollTable:SetFilter(value)
	if value == nil or type(value) == "string" then
		---@cast value string?
		if value == self._filter then
			return self
		end
		self._filter = value
		if not self._query then
			return self
		end
		self._query:ResetFilters()
		if value then
			self._query
				:Or()
					:Matches("itemList", value)
					:Matches("subject", value)
				:End()
		end
		self:_HandleQueryUpdate()
	else
		self:_MethodPublisher(value, "SetFilter")
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MailsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._actionIcon)
	for _, itemString, sender, mailType in self._query:Iterator("itemString", "sender", "type") do
		tinsert(self._data.items, self.DEFERRED_DATA)
		tinsert(self._data.items_tooltip, itemString)
		tinsert(self._data.sender, sender == "" and UNKNOWN or sender)
		tinsert(self._data.expires, self.DEFERRED_DATA)
		tinsert(self._data.money, self.DEFERRED_DATA)
		if mailType == Inbox.MAIL_TYPE.SALE then
			tinsert(self._actionIcon, "iconPack.12x12/Bid")
		elseif mailType == Inbox.MAIL_TYPE.BUY then
			tinsert(self._actionIcon, "iconPack.12x12/Shopping")
		elseif mailType == Inbox.MAIL_TYPE.CANCEL then
			tinsert(self._actionIcon, "iconPack.12x12/Close/Circle")
		elseif mailType == Inbox.MAIL_TYPE.EXPIRE then
			tinsert(self._actionIcon, "iconPack.12x12/Clock")
		elseif mailType == Inbox.MAIL_TYPE.OTHER then
			tinsert(self._actionIcon, "iconPack.12x12/Mailing")
		else
			tinsert(self._actionIcon, false)
		end
	end
	self:_SetNumRows(#self._data.items)
	self:Draw()
end

function MailsScrollTable.__protected:_CreateHeaderCell(info)
	local cell = self.__super:_CreateHeaderCell(info)
	cell.titleText:TSMSetFont("BODY_XSMALL")
	cell.titleText:SetJustifyH(info.justifyH)
	return cell
end

function MailsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local index, subject, expires, money, cost = self._query:GetNthResult(dataIndex, "index", "subject", "expires", "money", "cost")
	assert(index)
	self._data.items[dataIndex] = self:_GetItemsText(index, subject)
	local expiresText, expiresColor = nil, nil
	if expires >= 1 then
		expiresText = floor(expires).." "..DAYS
		expiresColor = expires <= 5 and "warning/main" or "on/surface"
	else
		local hoursLeft = expires * 24
		expiresText = hoursLeft >= 1 and floor(hoursLeft).." "..HOURS or floor(hoursLeft * 60).." "..MINUTES
		expiresColor = "error/main"
	end
	self._data.expires[dataIndex] = TextureAtlas.GetTextureLink("iconPack.12x12/Checkmark/Circle").." "..Theme.GetColor(expiresColor):ColorText(expiresText)
	local gold = nil
	if cost > 0 then
		gold = Money.ToStringForUI(cost, Theme.GetColor("error/main"):GetTextColorPrefix())
	elseif money > 0 then
		gold = Money.ToStringForUI(money, Theme.GetColor("positive/main"):GetTextColorPrefix())
	end
	self._data.money[dataIndex] = gold or ""
end

function MailsScrollTable.__protected:_GetItemsText(index, subject)
	local items = ""
	local item = nil
	local same = true
	local qty = 0
	local iconItem = nil
	self._itemsQuery:BindParams(index)
	for _, itemLink, quantity in self._itemsQuery:Iterator("itemLink", "quantity") do
		local coloredItem = UIUtils.GetDisplayItemName(itemLink) or ""
		iconItem = iconItem or itemLink
		if not item then
			item = coloredItem
		end

		if quantity > 1 then
			items = items..coloredItem..Theme.GetColor("on/surface/low"):ColorText(" (x"..quantity..")")..", "
		else
			items = items..coloredItem..", "
		end

		if item == coloredItem then
			qty = qty + quantity
		else
			same = false
		end
	end
	items = strtrim(items, ", ")

	if same and item then
		if qty > 1 then
			items = item..Theme.GetColor("on/surface/low"):ColorText(" (x"..qty..")")
		else
			items = item
		end
	end

	if not items or items == "" then
		if subject ~= "" then
			local soldItem = strmatch(subject, AUCTION_SOLD_PATTERN_STR)
			items = soldItem or subject
			iconItem = iconItem or (soldItem and self:_GetSoldItemString(soldItem))
		else
			items = Inbox.GetHeaderInfo(index) or UNKNOWN
		end
	end

	local texture = iconItem and ItemInfo.GetTexture(iconItem)
	if texture then
		items = "|T"..texture..":12|t "..items
	end
	return items
end

function MailsScrollTable.__private:_GetSoldItemString(name)
	local itemString = self._soldItemStrings[name]
	if not itemString then
		itemString = ItemInfo.ItemNameToItemString(name)
		self._soldItemStrings[name] = itemString
	end
	return itemString
end

---@param row ListRow
function MailsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local index = self._query:GetNthResult(dataIndex, "index")
	self:_SendActionScript("OnRowClick", index)
end

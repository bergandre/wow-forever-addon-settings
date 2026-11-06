-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Util = LibTSMApp:InitInternal("Mailing.Util")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Iterator = LibTSMApp:From("LibTSMUtil"):Include("BaseType.Iterator")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local UIUtils = LibTSMApp:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	settings = nil,
	itemsQuery = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Util:OnModuleLoad(function()
	private.itemsQuery = Mail.NewItemQuery()
		:Equal("index", Database.BoundQueryParam())
end)

AddonSettings.RegisterOnLoad(Util, function(db)
	private.settings = db:NewView("UtilSettings")
		:AddKey("global", "mailingOptions", "sendMessages")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates an inbox query.
---@return DatabaseQuery
function Util.CreateInboxQuery()
	return Mail.NewMailQuery()
		:VirtualField("itemList", "string", private.GetItemListVirtualField, "index")
end

---Prints information about money / items being sent to chat.
---@param money number The amount of money being sent (negative for CoD)
---@param items? table<string,number> The items being sent
---@param recipient string The recipient name
function Util.PrintSendMessage(money, items, recipient)
	if not private.settings.sendMessages then
		return
	end
	local contents = items and private.GetItemQuantityListStr(items) or nil
	if money > 0 then
		local moneyStr = Money.ToStringExact(money)
		contents = contents and (contents..", "..moneyStr) or moneyStr
	end
	if not contents then
		return
	end
	local codStr = money < 0 and Money.ToStringExact(money, Theme.GetColor("error/main"):GetTextColorPrefix()) or nil
	if codStr then
		ChatMessage.PrintfUser(L["Sending %s to %s with a COD of %s"], contents, recipient, codStr)
	else
		ChatMessage.PrintfUser(L["Sending %s to %s"], contents, recipient)
	end
end

---Prints information about sending items as part of a dry run.
---@param items table<string,number> The items being sent
---@param recipient string The recipient name
function Util.PrintDryRunItemsSendMessage(items, recipient)
	assert(next(items))
	local itemListStr = private.GetItemQuantityListStr(items)
	ChatMessage.PrintfUser(L["Would send %s to %s"], itemListStr, recipient)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetItemQuantityListStr(items)
	return Iterator.Acquire(pairs(items))
		:SetMapFunc(private.ItemLinkQuantityStr)
		:ToJoinedValueString(", ")
end

function private.ItemLinkQuantityStr(itemString, quantity)
	return ItemInfo.GetLink(itemString).."x"..quantity
end

function private.GetItemListVirtualField(index)
	private.itemsQuery:BindParams(index)
	return private.itemsQuery:Iterator("itemLink", "quantity")
		:SetMapFunc(private.ItemNameQuantityStr)
		:ToJoinedValueString(", ")
end

function private.ItemNameQuantityStr(_, itemLink, quantity)
	local itemName = tonumber(itemLink) and "" or UIUtils.GetDisplayItemName(itemLink) or ""
	return quantity > 1 and (itemName.." (x"..quantity..")") or itemName
end

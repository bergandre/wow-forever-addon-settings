-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Open = LibTSMApp:InitInternal("Mailing.Open")
local Util = LibTSMApp:Include("Mailing.Util")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local Container = LibTSMApp:From("LibTSMWoW"):Include("API.Container")
local Inbox = LibTSMApp:From("LibTSMWoW"):Include("API.Inbox")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local private = {
	settings = nil,
	thread = nil,
	isOpening = false,
	moneyCollected = 0,
}
local MANUAL_MAIL_TYPES = {
	[Inbox.MAIL_TYPE.OTHER.GOLD_AND_ITEMS] = true,
	[Inbox.MAIL_TYPE.OTHER.ITEMS] = true,
	[Inbox.MAIL_TYPE.OTHER.GOLD] = true,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Open:OnModuleLoad(function()
	private.thread = Threading.New("MAIL_OPENING", private.OpenMailThread)
end)

AddonSettings.RegisterOnLoad(Open, function(db)
	private.settings = db:NewView("OpenSettings")
		:AddKey("global", "mailingOptions", "inboxMessages")
		:AddKey("global", "mailingOptions", "keepMailSpace")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts opening mail.
---@param callback fun() The callback for when opening is complete
---@param autoRefresh boolean Automatically refresh the inbox and keep opening
---@param keepMoney boolean Keep mail with money in the inbox
---@param filterText string Only open mail which matches the filter text
---@param filterType? EnumValue Only open mail which matches the filter type
function Open.Start(callback, autoRefresh, keepMoney, filterText, filterType)
	Threading.Kill(private.thread)

	assert(not private.isOpening)
	Mail.SetInboxCheckTimerBypassed(true)
	private.isOpening = true
	private.moneyCollected = 0

	Threading.SetCallback(private.thread, callback)
	Threading.Start(private.thread, autoRefresh, keepMoney, filterText, filterType)
end

---Stops opening mail.
function Open.Stop()
	Threading.Kill(private.thread)

	private.PrintMoneyCollected()
	if private.isOpening then
		Mail.SetInboxCheckTimerBypassed(false)
		private.isOpening = false
	end
end



-- ============================================================================
-- Mail Opening Thread
-- ============================================================================

function private.OpenMailThread(autoRefresh, keepMoney, filterText, filterType)
	while true do
		local preLeftMail, preTotalMail = Inbox.GetNumItems()
		local mails = Threading.AcquireSafeTempTable()
		Util.CreateInboxQuery()
			:ResetOrderBy()
			:OrderBy("index", false)
			:Or()
				:Matches("itemList", filterText)
				:Matches("subject", filterText)
			:End()
			:If(filterType)
				:Equal("type", filterType)
			:End()
			:AutoRelease()
			:AsTable(mails, "index")

		private.OpenMails(mails, keepMoney, filterType)
		TempTable.Release(mails)

		local postLeftMail, postTotalMail = Inbox.GetNumItems()
		if not autoRefresh or (preLeftMail == postLeftMail and preTotalMail == postTotalMail and postTotalMail == postLeftMail) then
			Threading.Sleep(1)
			break
		end

		Inbox.Check()
		Threading.Sleep(1)
	end

	private.PrintMoneyCollected()
	assert(private.isOpening)
	Mail.SetInboxCheckTimerBypassed(false)
	private.isOpening = false
end

function private.OpenMails(mails, keepMoney, filterType)
	for i = 1, #mails do
		local index = mails[i]
		Threading.WaitForFunction(Inbox.CanSendCommand)

		local mailType = Inbox.GetMailType(index)
		local matchesFilter = (not filterType and mailType) or (filterType == mailType)
		local hasBagSpace = not Mail.GetInboxItemLink(index) or Container.GetTotalFreeBagSlots() > private.settings.keepMailSpace
		if matchesFilter and hasBagSpace then
			local _, money, cod, numItems, _, _, textCreated = Inbox.GetHeaderInfo(index)
			if cod == 0 and (not keepMoney or (keepMoney and money <= 0)) then
				local message = private.settings.inboxMessages and private.GetOpenMailMessage(index) or nil
				-- Marks the mail as read
				Inbox.GetText(index)
				Inbox.AutoOpenMail(index)
				private.moneyCollected = private.moneyCollected + money

				local event = nil
				if money > 0 or numItems > 0 then
					if mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER or MANUAL_MAIL_TYPES[mailType] then
						event = "MAIL_SUCCESS"
					elseif textCreated and mailType ~= Inbox.MAIL_TYPE.OTHER.TEMP_INVOICE then
						-- Temporary invoices are not auto deleted
						event = "CLOSE_INBOX_ITEM"
					end
				end
				if event and Threading.WaitForEvent(event, "MAIL_FAILED") ~= "MAIL_FAILED" then
					if message then
						ChatMessage.PrintUser(message)
					end
					if textCreated and event == "MAIL_SUCCESS" then
						private.DeleteEmptyMail(index)
					end
				end
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PrintMoneyCollected()
	if private.settings.inboxMessages and private.moneyCollected > 0 then
		ChatMessage.PrintfUser(L["Total Gold Collected: %s"], Money.ToStringForUI(private.moneyCollected))
	end
	private.moneyCollected = 0
end

function private.GetOpenMailMessage(index)
	local mailType = Inbox.GetMailType(index)
	if mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
		local itemName, seller, bid, _, _, _, _, _, quantity = Inbox.GetInvoiceInfo(index)
		seller = Inbox.CoalesceSellerName(seller)
		local itemLink = Mail.GetInboxItemLink(index) or ("["..(itemName or "?").."]")
		return format(L["Bought %sx%d for %s from %s"], itemLink, quantity, private.FormatMoney(bid, "error/main"), seller)
	elseif mailType == Inbox.MAIL_TYPE.SALE.AUCTION then
		local itemName, buyer, bid, _, _, ahcut, _, _, quantity = Inbox.GetInvoiceInfo(index)
		buyer = Inbox.CoalesceBuyerName(buyer)
		local itemLink = "["..(itemName or "?").."]"
		return format(L["Sold %sx%d for %s to %s"], itemLink, quantity, private.FormatMoney(bid - ahcut, "positive/main"), buyer)
	elseif mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER then
		local _, commission, crafter = Inbox.GetCraftingOrderInfo(index)
		assert(commission)
		return format(L["Crafting order bought for %s from %s"], private.FormatMoney(commission, "error/main"), crafter)
	elseif mailType == Inbox.MAIL_TYPE.SALE.CRAFTING_ORDER then
		local _, commission, customer = Inbox.GetCraftingOrderInfo(index)
		assert(commission)
		return format(L["Crafting order sold for %s to %s"], private.FormatMoney(commission, "positive/main"), customer)
	elseif mailType == Inbox.MAIL_TYPE.CANCEL.AUCTION then
		local numItems, itemLink, quantity = private.GetMailItemInfo(index)
		if numItems == 1 and quantity > 0 then
			return format(L["Cancelled auction of %sx%d"], itemLink, quantity)
		end
	elseif mailType == Inbox.MAIL_TYPE.EXPIRE.AUCTION then
		local numItems, itemLink, quantity = private.GetMailItemInfo(index)
		if numItems == 1 and itemLink and quantity > 0 then
			return format(L["Your auction of %sx%s expired"], itemLink, quantity)
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD_AND_ITEMS then
		local sender, money = Inbox.GetHeaderInfo(index)
		sender = sender or "?"
		local _, itemLink, quantity = private.GetMailItemInfo(index)
		if quantity > 0 then
			return format(L["%s sent you %sx%d and %s"], sender, itemLink, quantity, private.FormatMoney(money, "positive/main"))
		elseif quantity == -1 then
			return format(L["%s sent you multiple items and %s"], sender, private.FormatMoney(money, "positive/main"))
		else
			return format(L["%s sent you %s"], sender, private.FormatMoney(money, "positive/main"))
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.ITEMS then
		local sender = Inbox.GetHeaderInfo(index)
		sender = sender or "?"
		local _, itemLink, quantity = private.GetMailItemInfo(index)
		if quantity > 0 then
			return format(L["%s sent you %sx%d"], sender, itemLink, quantity)
		elseif quantity == -1 then
			return format(L["%s sent you multiple items"], sender)
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD then
		local sender, money = Inbox.GetHeaderInfo(index)
		sender = sender or "?"
		return format(L["%s sent you %s"], sender, private.FormatMoney(money, "positive/main"))
	end
end

function private.FormatMoney(amount, color)
	return Money.ToStringExact(amount, Theme.GetColor(color):GetTextColorPrefix())
end

function private.GetMailItemInfo(index)
	local _, _, _, numItems = Inbox.GetHeaderInfo(index)
	local itemLink = nil
	local quantity = 0
	for i = 1, numItems do
		local link, count = Inbox.GetAttachment(index, i)
		itemLink = itemLink or link
		quantity = quantity + (count or 0)
		if not link or ItemString.Get(itemLink) ~= ItemString.Get(link) then
			itemLink = L["Multiple Items"]
			quantity = -1
			break
		end
	end
	if numItems == 1 then
		itemLink = Mail.GetInboxItemLink(index) or itemLink
	end
	return numItems, itemLink, quantity
end

function private.DeleteEmptyMail(index)
	local _, money, _, itemCount = Inbox.GetHeaderInfo(index)
	-- Only force delete completely empty mails
	if money == 0 and not itemCount then
		Inbox.DeleteMail(index)
	end
end

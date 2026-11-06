-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Inbox = LibTSMWoW:Init("API.Inbox")
local Container = LibTSMWoW:Include("API.Container")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local String = LibTSMWoW:From("LibTSMUtil"):Include("Lua.String")
local MAIL_TYPE = EnumType.NewNested("MAIL_TYPE", {
	SALE = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
	},
	BUY = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
	},
	CANCEL = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
		BID = EnumType.NewValue(),
	},
	EXPIRE = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
	},
	LETTER = {
		GM = EnumType.NewValue(),
		COD = EnumType.NewValue(),
		EMPTY = EnumType.NewValue(),
	},
	OTHER = {
		TEMP_INVOICE = EnumType.NewValue(),
		OUTBID = EnumType.NewValue(),
		GOLD_AND_ITEMS = EnumType.NewValue(),
		GOLD = EnumType.NewValue(),
		ITEMS = EnumType.NewValue(),
	},
})
Inbox.MAIL_TYPE = MAIL_TYPE
local EXPIRED_MATCH_TEXT = gsub(AUCTION_EXPIRED_MAIL_SUBJECT, "%%s", "")
local CANCELLED_MATCH_TEXT = gsub(AUCTION_REMOVED_MAIL_SUBJECT, "%%s", "")
local OUTBID_MATCH_TEXT = gsub(AUCTION_OUTBID_MAIL_SUBJECT, "%%s", "(.+)")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the number of inbox mail items.
---@return number numItems
---@return number totalItems
function Inbox.GetNumItems()
	return GetInboxNumItems()
end

---Gets header info.
---@param index number The mail index
---@return string? sender
---@return number money
---@return number cod
---@return number numItems
---@return string? subject
---@return number daysLeft
---@return boolean textCreated
---@return boolean isGM
---@return boolean canReply
---@return number texture
function Inbox.GetHeaderInfo(index)
	local _, texture, sender, subject, money, cod, daysLeft, numItems, _, _, textCreated, canReply, isGM = GetInboxHeaderInfo(index)
	return sender, money or 0, cod or 0, numItems or 0, subject, daysLeft, textCreated, isGM, canReply, texture --[[@as number]] ---@diagnostic disable-line: redundant-or
end

---Gets invoice info.
---@param index number The mail index
---@return string? itemName
---@return string? playerName
---@return number bid
---@return number buyout
---@return number deposit
---@return number consignment
---@return number? etaHour
---@return number? etaMin
---@return number? count
function Inbox.GetInvoiceInfo(index)
	local _, itemName, playerName, bid, buyout, deposit, consignment, _, etaHour, etaMin, count = GetInboxInvoiceInfo(index)
	return itemName, playerName, bid, buyout, deposit, consignment, etaHour, etaMin, count
end

---Coalesces a seller name from `Inbox.GetInvoiceInfo`.
---@param sellerName? string The seller name
---@return string
function Inbox.CoalesceSellerName(sellerName)
	return sellerName or AUCTION_HOUSE_MAIL_MULTIPLE_SELLERS
end

---Coalesces a seller name from `Inbox.GetInvoiceInfo`.
---@param buyerName? string The buyer name
---@return string
function Inbox.CoalesceBuyerName(buyerName)
	return buyerName or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS
end

---Gets the crafting order info for a mail.
---@param index number The mail index
---@return number? reason
---@return number? commissionPaid
---@return string? playerName
---@return string? recipeName
function Inbox.GetCraftingOrderInfo(index)
	local info = C_Mail.GetCraftingOrderMailInfo(index)
	assert(info)
	if info.reason == Enum.RcoCloseReason.Fulfill and not info.crafterName then
		return nil, nil, nil, nil
	end
	return info.reason, info.commissionPaid, info.customerName or info.crafterName, info.recipeName
end

---Gets the type of a mail.
---@param index number The mail index
---@return EnumValue
function Inbox.GetMailType(index)
	-- Check if this is auction sale / buy mail
	local invoiceType = GetInboxInvoiceInfo(index)
	if invoiceType == "seller" then
		return MAIL_TYPE.SALE.AUCTION
	elseif invoiceType == "seller_temp_invoice" then
		return MAIL_TYPE.OTHER.TEMP_INVOICE
	elseif invoiceType == "buyer" then
		return MAIL_TYPE.BUY.AUCTION
	end

	-- Check for letters
	local sender, money, cod, numItems, subject, _, _, isGM, canReply = Inbox.GetHeaderInfo(index)
	subject = subject or ""
	if isGM then
		return MAIL_TYPE.LETTER.GM
	elseif cod > 0 then
		return MAIL_TYPE.LETTER.COD
	elseif money == 0 and numItems == 0 then
		return MAIL_TYPE.LETTER.EMPTY
	end

	-- Check if this is a crafting order mail (this is deferred as much as possible since it creates a table)
	if not canReply and sender == ARTISANS_CONSORTIUM and (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) then
		local reason = Inbox.GetCraftingOrderInfo(index)
		if reason == Enum.RcoCloseReason.Cancel then
			return MAIL_TYPE.CANCEL.CRAFTING_ORDER
		elseif reason == Enum.RcoCloseReason.Expire then
			return MAIL_TYPE.EXPIRE.CRAFTING_ORDER
		elseif reason == Enum.RcoCloseReason.CrafterFulfill then
			return MAIL_TYPE.SALE.CRAFTING_ORDER
		elseif reason == Enum.RcoCloseReason.Fulfill then
			return MAIL_TYPE.BUY.CRAFTING_ORDER
		end
	end

	-- Check for other auction mail
	if strfind(subject, CANCELLED_MATCH_TEXT) then
		if money > 0 then
			return MAIL_TYPE.CANCEL.BID
		else
			return MAIL_TYPE.CANCEL.AUCTION
		end
	elseif strfind(subject, EXPIRED_MATCH_TEXT) then
		return MAIL_TYPE.EXPIRE.AUCTION
	elseif strfind(subject, OUTBID_MATCH_TEXT) then
		return MAIL_TYPE.OTHER.OUTBID
	end

	-- Check for other mail types
	if money > 0 and numItems > 0 then
		return MAIL_TYPE.OTHER.GOLD_AND_ITEMS
	elseif money > 0 then
		return MAIL_TYPE.OTHER.GOLD
	else
		assert(numItems > 0)
		return MAIL_TYPE.OTHER.ITEMS
	end
end

---Gets the text of a mail.
---@param index number The mail index
---@return string? body
---@return boolean? isTakeable
function Inbox.GetText(index)
	local body, _, _, isTakeable = GetInboxText(index)
	return body, isTakeable
end

---Gets whether or not the sender of a mail can be reported.
---@param index number The mail index
---@return boolean
function Inbox.CanReport(index)
	return CanComplainInboxItem(index) and true or false
end

---Gets whether or not a mail can be deleted.
---@param index number The mail index
---@return boolean
function Inbox.CanDelete(index)
	return InboxItemCanDelete(index)
end

---Gets the max number of attachment that can be in a received mail.
---@return number
function Inbox.GetMaxAttachments()
	return ATTACHMENTS_MAX_RECEIVE
end

---Gets info on a mail attachment.
---@param index number The mail index
---@param attachIndex number The attachment index
---@return string? itemLink
---@return number? quantity
---@return string? name
function Inbox.GetAttachment(index, attachIndex)
	local name, _, _, stackSize = GetInboxItem(index, attachIndex)
	local itemLink = GetInboxItemLink(index, attachIndex)
	return itemLink, stackSize, name
end

---Gets the max number of attachment that can be sent.
---@return number
function Inbox.GetMaxSendAttachments()
	return ATTACHMENTS_MAX_SEND
end

---Gets info on a send attachment.
---@param index number The attachment index
---@return string? itemLink
---@return number? quantity
---@return string? name
function Inbox.GetSendAttachment(index)
	local itemLink = GetSendMailItemLink(index)
	local name, _, _, quantity = GetSendMailItem(index)
	return itemLink, quantity, name
end

---Gets the gold information for the mail being sent.
---@return number moneyAmount
---@return number codAmount
---@return number mailCost
function Inbox.GetSendMailGoldInfo()
	local moneyAmount = GetSendMailMoney() --[[@as number]]
	local codAmount = GetSendMailCOD()
	local mailCost = GetSendMailPrice()
	return moneyAmount, codAmount, mailCost
end

---Register a secure hook function for when mail is sent.
---@param func fun(target: string) The function to call
function Inbox.SecureHookSendMail(func)
	hooksecurefunc("SendMail", func)
end

---Register a secure hook function for when mail is returned.
---@param func fun(index: number) The function to call
function Inbox.SecureHookReturnMail(func)
	hooksecurefunc("ReturnInboxItem", func)
end

---Hooks the loot APIs.
---@param func fun(origFunc: function, ...: any) The replacement function which is passed the original function as the first argument
function Inbox.HookLootFunctions(func)
	local origTakeInboxItem = TakeInboxItem
	TakeInboxItem = function(...) func(origTakeInboxItem, ...) end
	local origTakeInboxMoney = TakeInboxMoney
	TakeInboxMoney = function(...) func(origTakeInboxMoney, ...) end
	local origAutoLootMailItem = AutoLootMailItem
	AutoLootMailItem = function(...) func(origAutoLootMailItem, ...) end
end

---Hooks the send mail API.
---@param func fun(origFunc: function, ...: any) The replacement function which is passed the original function as the first argument
function Inbox.HookSendMail(func)
	local origSendMail = SendMail
	SendMail = function(...) func(origSendMail, ...) end
end

---Parses a CoD payment subject.
---@param subject string The subject
---@return string
function Inbox.ParseCODPayment(subject)
	local result = nil
	if GetLocale() == "deDE" then
		result = gsub(subject, gsub(COD_PAYMENT, String.Escape("%1$s"), ""), "")
	else
		result = gsub(subject, gsub(COD_PAYMENT, String.Escape("%s"), ""), "")
	end
	return result
end

---Clears any pending send mail context.
function Inbox.ClearSendMail()
	ClearSendMail()
end

---Adds an item to the mail from the player's bags.
---@param slotId number The slot ID
function Inbox.AddItemToMail(slotId)
	Container.PickupItem(slotId)
	ClickSendMailItemButton() ---@diagnostic disable-line: missing-parameter
end

---Sends the current pending mail.
---@param recipient string The recipient name
---@param subject string The subject text
---@param defaultSubject string A default subject if none is set otherwise
---@param body string The body text
---@param money number The amount of money to send or the CoD amount if negative
function Inbox.SendMail(recipient, subject, defaultSubject, body, money)
	if subject == "" then
		local text = SendMailSubjectEditBox:GetText()
		subject = text ~= "" and text or defaultSubject
	end
	if money > 0 then
		SetSendMailMoney(money)
		SetSendMailCOD(0)
	elseif money < 0 then
		SetSendMailCOD(abs(money))
		SetSendMailMoney(0)
	else
		SetSendMailMoney(0)
		SetSendMailCOD(0)
	end
	SendMail(recipient, subject, body)
end

---Checks for new mail.
function Inbox.Check()
	CheckInbox()
end

---Whether or not the inbox is available to send a command to.
---@return boolean
function Inbox.CanSendCommand()
	return not C_Mail.IsCommandPending()
end

---Automatically opens mail at the given index.
---@param index number The index
function Inbox.AutoOpenMail(index)
	AutoLootMailItem(index)
end

---Deletes mail at the given index.
---@param index number The index
function Inbox.DeleteMail(index)
	DeleteInboxItem(index)
end

---Returns mail at the given index.
---@param index number The index
function Inbox.ReturnMail(index)
	ReturnInboxItem(index)
end

---Takes the text item associated with the mail at a given index.
---@param index number The index
function Inbox.TakeTextItem(index)
	TakeInboxTextItem(index)
end

---Takes an item from a mail.
---@param mailIndex number The index of the mail
---@param itemIndex number The index of the item within the mail
function Inbox.TakeItem(mailIndex, itemIndex)
	TakeInboxItem(mailIndex, itemIndex)
end

---Takes the money associated with a mail at a given index.
---@param index number The index
function Inbox.TakeMoney(index)
	TakeInboxMoney(index)
end

---Reports a mail as spam.
---@param index number The index
function Inbox.ReportSpam(index)
	local sender = Inbox.GetHeaderInfo(index)
	local dialog = StaticPopup_Show("CONFIRM_REPORT_SPAM_MAIL", sender)
	if dialog then
		dialog.data = index
	end
end

---Processes the current cursor for sending items and returns the item and locked bag slotId from the cursor.
---@param hasMaxAttachments boolean Whether or not the mail currently has the max allowed attachments
---@return string? item
---@return number? slotId
function Inbox.ProcessSendCursor(hasMaxAttachments)
	if not CursorHasItem() then
		ClearCursor()
		return nil, nil
	elseif hasMaxAttachments then
		ClearCursor()
		Inbox.ShowMaxAttachmentError()
		return nil, nil
	end
	local _, _, item = GetCursorInfo()
	item = type(item) == "string" and item or nil
	local lockedSlotId = Container.GetLockedBagSlotId()
	ClearCursor()
	return item, lockedSlotId
end

---Shows the max attachment error message.
function Inbox.ShowMaxAttachmentError()
	UIErrorsFrame:AddMessage(ERR_MAIL_INVALID_ATTACHMENT_SLOT, 1.0, 0.1, 0.1, 1.0)
end

---Sets whether or not the send mail frame is showing.
---@param shown boolean Whether or not it's shown
function Inbox.SetSendMailShowing(shown)
	SetSendMailShowing(shown)
end

---Gets the mail frame.
---@return Frame
function Inbox.GetMailFrame()
	return MailFrame
end

---Shows the mail frame.
function Inbox.ShowMailFrame()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		ShowUIPanel(MailFrame)
	else
		MailFrame_Show()
	end
end

---Hides the mail frame.
function Inbox.HideMailFrame()
	HideUIPanel(MailFrame)
end

---Hides the open mail frame.
function Inbox.HideOpenMailFrame()
	OpenMailFrame:Hide()
end

---Closes the mail.
function Inbox.CloseMail()
	CloseAllBags()
	CloseMail()
end

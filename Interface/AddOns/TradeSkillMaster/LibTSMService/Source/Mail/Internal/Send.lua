-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Send = LibTSMService:InitInternal("Mail.Send")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Signal = LibTSMService:From("LibTSMUtil"):IncludeClassType("Signal")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local Group = LibTSMService:From("LibTSMTypes"):Include("Group")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local Item = LibTSMService:From("LibTSMWoW"):Include("API.Item")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	db = nil,
	thread = nil,
	bagUpdateSignal = Signal.New("MAIL_SEND_BAG_UPDATE"),
	defaultSubject = nil,
	sendItems = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Send:OnModuleLoad(function()
	private.db = Database.NewSchema("MAIL_SEND")
		:AddStringField("itemString")
		:AddUniqueNumberField("slotId")
		:AddNumberField("quantity")
		:AddIndex("itemString")
		:Commit()
	private.thread = Threading.New("MAIL_SEND", private.SendThread)
	BagTracking.RegisterCallback(private.bagUpdateSignal:CallbackToSet())
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the send code.
---@param defaultSubject string The default mail subject
function Send.Configure(defaultSubject)
	assert(not private.defaultSubject)
	private.defaultSubject = defaultSubject
end

---Returns whether or not a recipient is valid.
---@param recipient string The recipient name
---@return boolean
function Send.IsValidRecipient(recipient)
	return recipient ~= "" and recipient ~= SessionInfo.GetCharacterName() and recipient ~= SessionInfo.GetDisambiguatedCharacterName()
end

---Starts a single letter.
---@param recipient string The recipient name
---@param subject string The subject of the mail
---@param body string The body of the mail
---@param money number The amount of money to send (negative for CoD)
---@param items? table<string,number> The items to send
---@param callback fun() The callback function called when sending is complete
function Send.StartLetter(recipient, subject, body, money, items, callback)
	assert(items == nil or next(items))
	assert(Send.IsValidRecipient(recipient))
	Send.Stop()
	Threading.SetCallback(private.thread, callback)
	local sendItems = nil
	if items then
		for itemString, quantity in pairs(items) do
			assert(quantity > 0)
			private.sendItems[itemString] = quantity
		end
		sendItems = private.sendItems
	end
	Threading.Start(private.thread, recipient, subject, body, money, sendItems, false, false)
end

---Starts sending mail with items.
---@param items table<string,number> The items to send
---@param recipient string The recipient name
---@param subject? string The subject of the mail
---@param callback fun() The callback function called when sending is complete
function Send.StartItems(items, recipient, subject, callback)
	assert(Send.IsValidRecipient(recipient) and next(items))
	Send.Stop()
	Threading.SetCallback(private.thread, callback)
	for itemString, quantity in pairs(items) do
		assert(quantity > 0)
		private.sendItems[itemString] = quantity
	end
	Threading.Start(private.thread, recipient, subject or "", "", 0, private.sendItems, false, false)
end

---Starts sending mail with items from a group.
---@param items table<string,number> The items to send
---@param recipient string The recipient name
---@param sendIndividually boolean Whether or not to send different items in separate mails
---@param callback fun() The callback function called when sending is complete
function Send.StartGroupItems(items, recipient, sendIndividually, callback)
	assert(Send.IsValidRecipient(recipient) and next(items))
	Send.Stop()
	Threading.SetCallback(private.thread, callback)
	for itemString, quantity in pairs(items) do
		assert(quantity > 0)
		private.sendItems[itemString] = quantity
	end
	Threading.Start(private.thread, recipient, "", "", 0, private.sendItems, true, sendIndividually)
end

---Starts sending mail with gold.
---@param money number The amount to send
---@param recipient string The recipient name
---@param subject string The subject of the mail
---@param callback fun() The callback function called when sending is complete
function Send.StartGold(money, recipient, subject, callback)
	assert(Send.IsValidRecipient(recipient) and money > 0)
	Send.Stop()
	Threading.SetCallback(private.thread, callback)
	Threading.Start(private.thread, recipient, subject, "", money, nil, false, false)
end

---Stops sending.
function Send.Stop()
	Threading.Kill(private.thread)
	private.db:Truncate()
	wipe(private.sendItems)
end



-- ============================================================================
-- Thread
-- ============================================================================

function private.SendThread(recipient, subject, body, money, items, translateItems, sendIndividually)
	if not items then
		private.SendMailThreaded(recipient, subject, body, money, true)
		return
	end
	Inbox.ClearSendMail()

	-- Populate our DB based on what's in the player's bags
	local query = BagTracking.CreateQueryBags()
		:AutoRelease()
		:OrderBy("slotId", true)
		:Or()
			:Equal("isBound", false)
			:Equal("isWarBound", true)
		:End()
	private.db:BulkInsertStart()
	for _, slotId, itemString, quantity in query:Iterator("slotId", "itemString", "quantity") do
		if translateItems then
			itemString = Group.TranslateItemString(itemString)
		end
		if items[itemString] and not Container.IsBagSlotLocked(slotId) then
			private.db:BulkInsertNewRow(itemString, slotId, quantity)
		end
	end
	private.db:BulkInsertEnd()

	-- Filter out items that aren't in the player's bags
	for itemString in pairs(items) do
		local numLocations = private.db:NewAutoReleaseQuery()
			:Equal("itemString", itemString)
			:Count()
		if numLocations == 0 then
			items[itemString] = nil
		end
		Threading.Yield()
	end

	-- Send out stacks which exactly match how many we need to send first
	for itemString, sendQuantity in pairs(items) do
		local locations = private.GetLocations(itemString)
		for _, slotId in ipairs(locations) do
			local uuid = private.db:GetUniqueRow("slotId", slotId)
			if private.db:GetRowFields(uuid, "quantity") == sendQuantity then
				private.QueueToSend(slotId, recipient, subject, body, money, sendIndividually)
				private.db:DeleteRow(uuid)
				items[itemString] = nil
				break
			end
		end
		TempTable.Release(locations)
	end

	-- Send out the remaining items
	for itemString, sendQuantity in pairs(items) do
		local locations = private.GetLocations(itemString)
		if #locations > 0 then
			local itemFamily = itemString and Item.GetFamily(itemString, ItemInfo.GetClassId(itemString) or -1) or 0
			local emptySlotIds = private.GetEmptyBagSlotsThreaded(itemFamily)
			for _, slotId in ipairs(locations) do
				local uuid = private.db:GetUniqueRow("slotId", slotId)
				local slotQuantity = private.db:GetRowFields(uuid, "quantity")
				assert(slotQuantity)
				if sendQuantity < slotQuantity and #emptySlotIds > 0 then
					-- Send part of this stack and we're done
					local emptySlotId = tremove(emptySlotIds, 1)
					private.SplitStackThreaded(slotId, emptySlotId, sendQuantity)
					private.QueueToSend(emptySlotId, recipient, subject, body, money)
					private.db:UpdateRow(uuid, "quantity", slotQuantity - sendQuantity)
					break
				elseif sendQuantity == slotQuantity then
					-- Send this entire stack and we're done
					private.QueueToSend(slotId, recipient, subject, body, money)
					private.db:DeleteRow(uuid)
					break
				elseif sendQuantity > slotQuantity then
					-- Send this entire stack and keep looking for more
					private.QueueToSend(slotId, recipient, subject, body, money)
					private.db:DeleteRow(uuid)
					sendQuantity = sendQuantity - slotQuantity
				end
			end
			if sendIndividually and private.HasPendingAttachments() then
				private.SendMailThreaded(recipient, subject, body, money)
			end
			TempTable.Release(emptySlotIds)
		end
		TempTable.Release(locations)
	end

	if private.HasPendingAttachments() then
		private.SendMailThreaded(recipient, subject, body, money)
	end
end

function private.SendMailThreaded(recipient, subject, body, money, noItem)
	private.bagUpdateSignal:Clear()
	Inbox.SendMail(recipient, subject, private.defaultSubject, body, money)
	if Threading.WaitForEvent("MAIL_SUCCESS", "MAIL_FAILED") == "MAIL_SUCCESS" then
		if noItem then
			Threading.Sleep(0.5)
		else
			Threading.WaitForSignal(private.bagUpdateSignal)
		end
	else
		Threading.Sleep(0.5)
	end
end

function private.HasPendingAttachments()
	for i = 1, Inbox.GetMaxSendAttachments() do
		if Inbox.GetSendAttachment(i) then
			return true
		end
	end

	return false
end

function private.GetNumPendingAttachments()
	local totalAttached = 0
	for i = 1, Inbox.GetMaxSendAttachments() do
		if Inbox.GetSendAttachment(i) then
			totalAttached = totalAttached + 1
		end
	end

	return totalAttached
end

function private.GetLocations(itemString)
	local locations = Threading.AcquireSafeTempTable()
	private.db:NewAutoReleaseQuery()
		:Equal("itemString", itemString)
		:OrderBy("slotId", true)
		:AsTable(locations, "slotId")
	return locations
end

function private.GetEmptyBagSlotsThreaded(itemFamily)
	local emptySlotIds = Threading.AcquireSafeTempTable()
	local sortvalue = Threading.AcquireSafeTempTable()
	for bag = 0, Container.GetNumBags() do
		Container.GenerateSortedEmptyFamilySlots(bag, itemFamily, emptySlotIds, sortvalue)
		Threading.Yield()
	end
	Table.SortWithValueLookup(emptySlotIds, sortvalue)
	TempTable.Release(sortvalue)

	return emptySlotIds
end

function private.SplitStackThreaded(sourceSlotId, targetSlotId, quantity)
	Container.SplitItem(sourceSlotId, quantity)
	Container.PickupItem(targetSlotId)
	Threading.WaitForFunction(Container.GetItemLink, targetSlotId)
end

function private.QueueToSend(slotId, recipient, subject, body, money, forceSend)
	Inbox.AddItemToMail(slotId)
	if private.GetNumPendingAttachments() == Inbox.GetMaxSendAttachments() or forceSend then
		private.SendMailThreaded(recipient, subject, body, money)
	end
end

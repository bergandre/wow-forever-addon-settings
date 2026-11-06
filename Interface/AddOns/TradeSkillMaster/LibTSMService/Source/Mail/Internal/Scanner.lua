-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:InitInternal("Mail.Scanner")
local Util = LibTSMService:Include("Mail.Util")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	quantityStorage = nil,
	mailDB = nil,
	itemDB = nil,
	quantityDB = nil,
	baseItemQuantityQuery = nil,
	mailCallbacks = CallbackRegistry.NewList(),
	quantityCallbacks = CallbackRegistry.NewList(),
	scanTimer = nil,
	itemsTemp = {},
	updateTemp = {
		prevQuantities = {},
		items = {},
	},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	private.mailDB = Database.NewSchema("MAIL_TRACKING_INBOX_INFO")
		:AddUniqueNumberField("index")
		:AddEnumField("type", Inbox.MAIL_TYPE)
		:AddStringField("sender")
		:AddStringField("subject")
		:AddStringField("itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("itemCount")
		:AddNumberField("money")
		:AddNumberField("cost")
		:AddNumberField("expires")
		:AddIndex("index")
		:Commit()
	private.itemDB = Database.NewSchema("MAIL_TRACKING_INBOX_ITEMS")
		:AddNumberField("index")
		:AddNumberField("itemIndex")
		:AddStringField("itemLink")
		:AddNumberField("quantity")
		:AddIndex("index")
		:Commit()
	private.quantityDB = Database.NewSchema("MAIL_TRACKING_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("mailQuantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
	private.scanTimer = DelayTimer.New("MAIL_TRACKING_SCAN", private.MailInboxUpdateDelayed)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Mail item quantities
function Scanner.Load(quantityData)
	private.quantityStorage = quantityData
end

---Starts the scanner.
function Scanner.Start()
	Event.Register("MAIL_INBOX_UPDATE", function() private.scanTimer:RunForFrames(1) end)
end

---Registers a callback for when the mail data changes.
---@param callback fun() The callback function
function Scanner.RegisterMailCallback(callback)
	private.mailCallbacks:Add(callback)
end

---Registers a callback for when the quantity data changes.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function Scanner.RegisterQuantityCallback(callback)
	private.quantityCallbacks:Add(callback)
end

---Creates a new query against the mail DB.
---@return DatabaseQuery
function Scanner.NewMailQuery()
	return private.mailDB:NewOwnedQuery()
end

---Creates a new query against the item DB.
---@return DatabaseQuery
function Scanner.NewItemQuery()
	return private.itemDB:NewOwnedQuery()
end

---Gets the quantity of an item in the mail.
---@param itemString string The item string
---@return number
function Scanner.GetQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("mailQuantity")
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), "mailQuantity")
end

---Iterates over all known mail items and their quantity.
---@return IteratorObject<fun(): number, string, number> @Iterator with fields: `index`, `levelItemString`, `mailQuantity`
function Scanner.QuantityIterator()
	return private.quantityDB:NewAutoReleaseQuery()
		:Iterator("levelItemString", "mailQuantity")
end

---Inserts pending mail.
---@param pendingMail table<string,number> Pending mail data
function Scanner.InsertPendingMail(pendingMail)
	private.quantityDB:BulkInsertStart()
	for levelItemString, quantity in pairs(pendingMail) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
end

---Handles a pending mail quantity change.
---@param levelItemString string The level item string
---@param changeQuantity number The change quantity (positive or negative)
function Scanner.HandlePendingMailChange(levelItemString, changeQuantity)
	assert(changeQuantity ~= 0)
	local newValue = nil
	if private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		local uuid = private.quantityDB:GetUniqueRow("levelItemString", levelItemString)
		newValue = private.quantityDB:GetRowFields(uuid, "mailQuantity") + changeQuantity
		assert(newValue >= 0)
		if newValue == 0 then
			-- Remove this row
			private.quantityDB:DeleteRow(uuid)
		else
			-- Update this row
			private.quantityDB:UpdateRow(uuid, "mailQuantity", newValue)
		end
	else
		-- Create a new row
		assert(changeQuantity > 0)
		newValue = changeQuantity
		private.quantityDB:InsertRow(levelItemString, changeQuantity)
	end
	assert(not next(private.itemsTemp))
	private.itemsTemp[levelItemString] = true
	private.itemsTemp[ItemString.GetBaseFast(levelItemString)] = true
	private.quantityCallbacks:CallAll(private.itemsTemp)
	wipe(private.itemsTemp)
end



-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.MailInboxUpdateDelayed()
	if not DefaultUI.IsMailVisible() then
		return
	end

	wipe(private.quantityStorage)
	private.mailDB:TruncateAndBulkInsertStart()
	private.itemDB:TruncateAndBulkInsertStart()
	for i = 1, Inbox.GetNumItems() do
		local sender, money, cost, itemCount, subject, daysLeft = Inbox.GetHeaderInfo(i)
		sender = sender or ""
		subject = subject or ""
		if money > 0 then
			private.itemDB:BulkInsertNewRow(i, 0, tostring(money), 0)
		end

		local firstItemString = nil
		for j = 1, Inbox.GetMaxAttachments() do
			local itemLink, quantity = Util.GetAttachment(i, j)
			local itemString = itemLink and ItemString.Get(itemLink) or nil
			if itemString then
				firstItemString = firstItemString or itemString
				local levelItemString = ItemString.ToLevel(itemString)
				private.quantityStorage[levelItemString] = (private.quantityStorage[levelItemString] or 0) + quantity
				private.itemDB:BulkInsertNewRow(i, j, itemLink, quantity)
			end
		end

		local mailType = Inbox.GetMailType(i)
		if mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
			local _, _, bid = Inbox.GetInvoiceInfo(i)
			cost = bid
		end

		private.mailDB:BulkInsertNewRow(i, mailType, sender, subject, firstItemString or ItemString.GetUnknown(), itemCount, money, cost, daysLeft)
	end

	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end

	private.quantityDB:NewAutoReleaseQuery()
		:AsTable(updateTemp.prevQuantities, "levelItemString", "mailQuantity")
	private.quantityDB:TruncateAndBulkInsertStart()
	for levelItemString, quantity in pairs(private.quantityStorage) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
	Table.GetChangedKeys(updateTemp.prevQuantities, private.quantityStorage, updateTemp.items)
	private.itemDB:BulkInsertEnd()
	private.mailDB:BulkInsertEnd()

	private.mailCallbacks:CallAll()

	if next(updateTemp.items) then
		-- Add the base items
		ItemString.AddBaseItemStringKeys(updateTemp.items)
		private.quantityCallbacks:CallAll(updateTemp.items)
	end

	for _, tbl in pairs(updateTemp) do
		Table.WipeAndDeallocate(tbl)
	end
end

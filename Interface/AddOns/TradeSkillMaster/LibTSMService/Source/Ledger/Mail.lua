-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Mail = LibTSMService:Init("Ledger.Mail")
local Auctions = LibTSMService:Include("Ledger.Auctions")
local Money = LibTSMService:Include("Ledger.Money")
local Transactions = LibTSMService:Include("Ledger.Transactions")
local Auction = LibTSMService:Include("Auction")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local TooltipScanning = LibTSMService:From("LibTSMWoW"):Include("Service.TooltipScanning")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Vararg = LibTSMService:From("LibTSMUtil"):Include("Lua.Vararg")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local private = {
	sellersTimer = nil,
	rescanTimer = nil,
	rescanContext = {},
}
local SECONDS_PER_DAY = 24 * 60 * 60



-- ============================================================================
-- Module Loading
-- ============================================================================

Mail:OnModuleLoad(function()
	-- If the mail should container the seller, setup a timer to query the seller names
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		private.sellersTimer = DelayTimer.New("ACCOUNTING_MAIL_SELLERS", private.RequestSellerInfo)
		DefaultUI.RegisterMailVisibleCallback(function(visible)
			if visible then
				private.sellersTimer:RunForTime(0.1)
			else
				private.sellersTimer:Cancel()
			end
		end)
	end
	private.rescanTimer = DelayTimer.New("ACCOUNTING_MAIL_RESCAN", private.RescanHandler)
	-- Hook certain mail functions
	Inbox.HookLootFunctions(function(origFunc, ...)
		private.ScanCollectedMail(origFunc, 1, ...)
	end)
	Inbox.HookSendMail(private.CheckSendMail)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RequestSellerInfo()
	local isDone = true
	for i = 1, Inbox.GetNumItems() do
		local itemName, seller = Inbox.GetInvoiceInfo(i)
		if itemName and seller == "" then
			isDone = false
		end
	end
	if not isDone or Inbox.GetNumItems() == 0 then
		private.sellersTimer:RunForTime(0.1)
	end
end

function private.CanLootMailIndex(index, copper)
	local currentMoney = Currency.GetMoney()
	local moneyCap = Currency.GetMaxMoney()
	assert(currentMoney <= moneyCap)
	-- Check if this would put them over the gold cap
	if currentMoney + copper > moneyCap then
		return
	end
	local _, _, _, itemCount = Inbox.GetHeaderInfo(index)
	if not itemCount or itemCount == 0 then
		return true
	end
	for j = 1, Inbox.GetMaxAttachments() do
		-- TODO: prevent items that you can't loot because of internal mail error
		if Container.GetTotalFreeBagSlots() <= 0 then
			return
		end
		local link, quantity = Inbox.GetAttachment(index, j)
		local itemString = link and ItemString.Get(link)
		if not itemString then
			return
		end
		quantity = quantity or 0
		local totalQuantity = BagTracking.GetTotalQuantity(ItemString.GetBaseFast(itemString)) + quantity
		if totalQuantity > 1 then
			local maxUnique = TooltipScanning.GetInboxMaxUnique(index, j)
			-- Don't record unique items that we can't loot
			if maxUnique > 0 and maxUnique < totalQuantity then
				return
			end
		end
		for bag = 0, Container.GetNumBags() do
			if BagTracking.ItemWillGoInBag(itemString, bag) then
				for slotId in Container.SlotIdIterator(bag) do
					local bagItemLink = Container.GetItemLink(slotId)
					local bagItemString = bagItemLink and ItemString.Get(bagItemLink)
					if bagItemString == itemString then
						local stackSize = Container.GetStackCount(slotId)
						assert(stackSize)
						local maxStackSize = ItemInfo.GetMaxStack(itemString) or 1
						if (maxStackSize - stackSize) >= quantity then
							return true
						end
					elseif not bagItemString then
						return true
					end
				end
			end
		end
	end
end

-- Scans the mail that the player just attempted to collect (Pre-Hook)
function private.ScanCollectedMail(oFunc, attempt, index, subIndex)
	local _, _, _, _, subject, _, _, _, _, texture = Inbox.GetHeaderInfo(index)
	if not subject then
		return
	end
	local success, shouldRetry = private.RecordMail(index, subIndex, attempt <= 2)
	if not success and attempt <= 5 and (not texture or shouldRetry) then
		-- Try again
		wipe(private.rescanContext)
		Vararg.IntoTable(private.rescanContext, oFunc, attempt + 1, index, subIndex)
		private.rescanTimer:RunForTime(0.2)
	else
		oFunc(index, subIndex)
	end
end

function private.RecordMail(index, subIndex, resolveNames)
	local mailType = Inbox.GetMailType(index)
	local sender, money, codAmount, _, subject, daysLeft = Inbox.GetHeaderInfo(index)
	sender = (sender and sender ~= "") and sender or "?"
	subject = subject or ""
	if mailType == Inbox.MAIL_TYPE.SALE.AUCTION then
		local itemName, buyer, bid, _, _, ahcut, _, _, quantity = Inbox.GetInvoiceInfo(index)
		buyer = Inbox.CoalesceBuyerName(buyer)
		if buyer == "" and not resolveNames then
			-- Give up on resolving the buyer name
			buyer = "?"
		elseif buyer == "" then
			return false, true
		end
		if not private.CanLootMailIndex(index, bid - ahcut) then
			return false
		end
		assert(itemName and quantity)
		local itemString = ItemInfo.ItemNameToItemString(itemName)
		if not itemString or itemString == ItemString.GetUnknown() then
			itemString = Auction.GetSaleHintItemString(itemName, quantity, bid)
		end
		if itemString then
			local copper = floor((bid - ahcut) / quantity + 0.5)
			local saleTime = floor(LibTSMService.GetTime()) + (daysLeft - 30) * SECONDS_PER_DAY
			Transactions.InsertAuctionSale(itemString, quantity, copper, buyer, saleTime)
		else
			Log.Err("Failed to get itemString: %s", tostring(itemName))
		end
	elseif mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
		local _, seller, bid, _, _, _, _, _, quantity = Inbox.GetInvoiceInfo(index)
		seller = Inbox.CoalesceSellerName(seller)
		if seller == "" and not resolveNames then
			-- Give up on resolving the buyer name
			seller = "?"
		elseif seller == "" then
			return false, true
		end

		local isValid, itemString, itemQuantity = private.ValidateAuctionItemMail(index, subIndex)
		if not isValid then
			return false
		end
		assert(quantity)
		local copper = floor(bid / quantity + 0.5)
		if not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic() then
			quantity = itemQuantity
		end
		assert(itemString and quantity)
		local buyTime = floor(LibTSMService.GetTime()) + (daysLeft - 30) * SECONDS_PER_DAY
		Transactions.InsertAuctionBuy(itemString, quantity, copper, seller, buyTime)
	elseif mailType == Inbox.MAIL_TYPE.SALE.CRAFTING_ORDER then
		if not private.CanLootMailIndex(index, money) then
			return false
		end
		local _, craftingOrderCommission, craftingOrderCustomer = Inbox.GetCraftingOrderInfo(index)
		assert(craftingOrderCommission and craftingOrderCustomer)
		local saleTime = floor(LibTSMService.GetTime()) + (daysLeft - 30) * SECONDS_PER_DAY
		Money.InsertCraftingOrderIncome(craftingOrderCommission, craftingOrderCustomer, saleTime)
	elseif mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER then
		if not private.CanLootMailIndex(index, 0) then
			return false
		end
		local _, craftingOrderCommission, craftingOrderCrafter = Inbox.GetCraftingOrderInfo(index)
		assert(craftingOrderCommission and craftingOrderCrafter)
		local buyTime = floor(LibTSMService.GetTime()) + (daysLeft - 30) * SECONDS_PER_DAY
		Money.InsertCraftingOrderExpense(craftingOrderCommission, craftingOrderCrafter, buyTime)
	elseif mailType == Inbox.MAIL_TYPE.LETTER.COD then
		local link = private.GetItemLink(index, subIndex or 1)
		local itemString = link and ItemString.Get(link) or nil
		if not itemString then
			return false
		end
		-- COD Buys (only if all attachments are same item)
		local name = ItemInfo.GetName(link)
		local total = 0
		local stacks = 0
		for i = 1, Inbox.GetMaxAttachments() do
			local _, count, nameCheck = Inbox.GetAttachment(index, i)
			if count and nameCheck then
				if nameCheck == name then
					total = total + count
					stacks = stacks + 1
				else
					-- Multiple unique items, so just ignore
					return true
				end
			end
		end
		if total == 0 then
			-- No items (?), so just ignore
			return true
		end
		if not private.CanLootMailIndex(index, codAmount) then
			-- Don't bother recording
			return true
		end
		local copper = floor(codAmount / total + 0.5)
		local buyTime = floor(LibTSMService.GetTime()) + (daysLeft - 3) * SECONDS_PER_DAY
		local maxStack = ItemInfo.GetMaxStack(link) or 1
		for _ = 1, stacks do
			local stackSize = (total >= maxStack) and maxStack or total
			Transactions.InsertCODBuy(itemString, stackSize, copper, sender, buyTime)
			total = total - stackSize
			if total <= 0 then
				break
			end
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD then
		if not private.CanLootMailIndex(index, money) then
			return false
		end
		local str = Inbox.ParseCODPayment(subject)
		local saleTime = floor(LibTSMService.GetTime()) + (daysLeft - 31) * SECONDS_PER_DAY
		if strfind(str, "TSM$") then
			-- Payment for a COD the player sent
			local codName = strmatch(str, "([^%(]+)")
			assert(codName)
			codName = strtrim(codName)
			local qty = strmatch(str, "%(([0-9]+)%)")
			qty = tonumber(qty)
			assert(qty)
			local itemString = ItemInfo.ItemNameToItemString(codName)
			if itemString then
				local copper = floor(money / qty + 0.5)
				local maxStack = ItemInfo.GetMaxStack(itemString) or 1
				local stacks = ceil(qty / maxStack)

				for _ = 1, stacks do
					local stackSize = (qty >= maxStack) and maxStack or qty
					Transactions.InsertCODSale(itemString, stackSize, copper, sender, saleTime)
					qty = qty - stackSize
					if qty <= 0 then
						break
					end
				end
			end
		else
			-- Record a money transfer
			Money.InsertMoneyTransferIncome(money, sender, saleTime)
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD_AND_ITEMS then
		if not private.CanLootMailIndex(index, money) then
			return false
		end
		local saleTime = floor(LibTSMService.GetTime()) + (daysLeft - 31) * SECONDS_PER_DAY
		Money.InsertMoneyTransferIncome(money, sender, saleTime)
	elseif mailType == Inbox.MAIL_TYPE.EXPIRE.AUCTION then
		local isValid, itemString, quantity = private.ValidateAuctionItemMail(index, subIndex)
		if not isValid then
			return false
		end
		local expiredTime = floor(LibTSMService.GetTime()) + (daysLeft - 30) * SECONDS_PER_DAY
		assert(itemString and quantity)
		Auctions.InsertExpire(itemString, quantity, expiredTime)
	elseif mailType == Inbox.MAIL_TYPE.CANCEL.AUCTION then
		local isValid, itemString, quantity = private.ValidateAuctionItemMail(index, subIndex)
		if not isValid then
			return false
		end
		local cancelledTime = floor(LibTSMService.GetTime()) + (daysLeft - 30) * SECONDS_PER_DAY
		assert(itemString and quantity)
		Auctions.InsertCancel(itemString, quantity, cancelledTime)
	end
	return true
end

function private.ValidateAuctionItemMail(index, subIndex)
	if not private.CanLootMailIndex(index, 0) then
		return false
	end
	local link = private.GetItemLink(index, subIndex or 1)
	local quantity = private.GetQuantity(index, subIndex)
	local itemString = link and ItemString.Get(link)
	if not itemString then
		Log.Err("Failed to get itemString: %s, %s, %s", tostring(index), tostring(subIndex), tostring(link))
		return false
	end
	return true, itemString, quantity
end

function private.RescanHandler()
	private.ScanCollectedMail(unpack(private.rescanContext))
end

-- scans the mail that the player just attempted to send (Pre-Hook) to see if COD
function private.CheckSendMail(origFunc, destination, currentSubject, ...)
	local moneyAmount, codAmount, mailCost = Inbox.GetSendMailGoldInfo()
	local subject
	local total = 0
	local ignore = false

	if codAmount ~= 0 then
		for i = 1, Inbox.GetMaxSendAttachments() do
			local _, count, itemName = Inbox.GetSendAttachment(i)
			if itemName and count then
				if not subject then
					subject = itemName
				end

				if subject == itemName then
					total = total + count
				else
					ignore = true
				end
			end
		end
	else
		ignore = true
	end

	if moneyAmount > 0 then
		-- Add a record for the money transfer
		Money.InsertMoneyTransferExpense(moneyAmount, destination)
		mailCost = mailCost - moneyAmount
	end
	Money.InsertPostageExpense(mailCost, destination)

	if not ignore then
		origFunc(destination, subject .. " (" .. total .. ") TSM", ...)
	else
		origFunc(destination, currentSubject, ...)
	end
end

function private.GetItemLink(index, attachIndex)
	local link = nil
	if attachIndex == 1 then
		-- Find the first attachment index with an item
		local foundIndex = nil
		for i = 1, Inbox.GetMaxAttachments() do
			link = Inbox.GetAttachment(index, i)
			if link then
				foundIndex = i
				break
			end
		end
		if not foundIndex then
			error(format("Invalid attachIndex for index %s", tostring(index)))
		end
		if link and ItemString.GetBase(link) == ItemString.GetPetCage() then
			local speciesId, level, breedQuality = TooltipScanning.GetInboxBattlePetInfo(index, foundIndex)
			if speciesId and speciesId > 0 then
				link = ItemInfo.GetLink(strjoin(":", "p", speciesId, level, breedQuality))
			end
		end
	end
	return link or Inbox.GetAttachment(index, attachIndex)
end

function private.GetQuantity(index, attachIndex)
	if attachIndex or LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		local _, quantity = Inbox.GetAttachment(index, attachIndex or 1)
		return quantity or 0
	else
		local quantity = 0
		for i = 1, Inbox.GetMaxAttachments() do
			local _, count = Inbox.GetAttachment(index, i)
			quantity = quantity + (count or 0)
		end
		return quantity
	end
end

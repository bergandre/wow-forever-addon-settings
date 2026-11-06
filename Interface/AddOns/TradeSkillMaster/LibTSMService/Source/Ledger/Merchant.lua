-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Merchant = LibTSMService:Init("Ledger.Merchant")
local Money = LibTSMService:Include("Ledger.Money")
local Transactions = LibTSMService:Include("Ledger.Transactions")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local MerchantAPI = LibTSMService:From("LibTSMWoW"):Include("API.Merchant")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	repairMoney = 0,
	couldRepair = nil,
	repairCost = 0,
	pending = {
		itemString = {},
		quantity = {},
		copper = {},
		insertTime = {},
	},
	pendingBagQuantity = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Merchant:OnModuleLoad(function()
	DefaultUI.RegisterMerchantVisibleCallback(private.MerchantVisibilityHandler)
	BagTracking.RegisterCallback(private.OnMerchantUpdate)
	BagTracking.RegisterQuantityCallback(private.ProcessPending)
	Event.Register("UPDATE_INVENTORY_DURABILITY", private.AddRepairCosts)
	Container.SecureHookUseItem(private.OnMerchantSell)
	MerchantAPI.SecureHookBuyItem(private.OnMerchantBuy)
	MerchantAPI.SecureHookBuybackItem(private.OnMerchantBuyback)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MerchantVisibilityHandler(visible)
	if visible then
		private.repairMoney = Currency.GetMoney()
		private.couldRepair = MerchantAPI.CanRepair()
		-- if merchant can repair set up variables so we can track repairs
		if private.couldRepair then
			private.repairCost = MerchantAPI.GetRepairAllCost()
		end
	else
		private.couldRepair = nil
		private.repairCost = 0
	end
end

function private.OnMerchantUpdate()
	-- Could have bought something before or after repair
	private.repairMoney = Currency.GetMoney()
end

function private.AddRepairCosts()
	if private.couldRepair and private.repairCost > 0 then
		local cash = Currency.GetMoney()
		if private.repairMoney > cash then
			-- this is probably a repair bill
			local cost = private.repairMoney - cash
			Money.InsertRepairBillExpense(cost)
			-- reset money as this might have been a single item repair
			private.repairMoney = cash
			-- reset the repair cost for the next repair
			private.repairCost = MerchantAPI.GetRepairAllCost()
		end
	end
end

function private.OnMerchantSell(slotId)
	-- Check if we are trying to sell something to a vendor
	if not DefaultUI.IsMerchantVisible() then
		return
	end
	local link = Container.GetItemLink(slotId)
	local itemString = link and ItemString.Get(link)
	local stackSize = Container.GetStackCount(slotId)
	local copper = itemString and ItemInfo.GetVendorSell(itemString)
	if not itemString or not stackSize or not copper then
		return
	end
	private.AddPending(itemString, -stackSize, copper)
end

function private.OnMerchantBuy(index, quantity)
	local price, batchQuantity = MerchantAPI.GetItemInfo(index)
	local link = MerchantAPI.GetItemLink(index)
	local itemString = link and ItemString.Get(link)
	if not itemString or not price or price <= 0 then
		return
	end
	quantity = quantity or batchQuantity
	local copper = Math.Round(price / batchQuantity)
	private.AddPending(itemString, quantity, copper)
end

function private.OnMerchantBuyback(index)
	local price, quantity = MerchantAPI.GetBuybackItemInfo(index)
	local link = MerchantAPI.GetBuybackItemLink(index)
	local itemString = link and ItemString.Get(link)
	if not itemString or not price or price <= 0 then
		return
	end
	local copper = Math.Round(price / quantity)
	private.AddPending(itemString, quantity, copper)
end

function private.AddPending(itemString, quantity, copper)
	private.PrunePending()
	private.pendingBagQuantity[itemString] = private.pendingBagQuantity[itemString] or BagTracking.GetBagQuantity(itemString)
	tinsert(private.pending.itemString, itemString)
	tinsert(private.pending.quantity, quantity)
	tinsert(private.pending.copper, copper)
	tinsert(private.pending.insertTime, LibTSMService.GetTime())
end

function private.ProcessPending()
	private.PrunePending()
	for index, itemString in Table.ReverseIPairs(private.pending.itemString) do
		local quantity = private.pending.quantity[index]
		local change = BagTracking.GetBagQuantity(itemString) - private.pendingBagQuantity[itemString]
		if (quantity > 0 and quantity <= change) or (quantity < 0 and quantity >= change) then
			private.pendingBagQuantity[itemString] = private.pendingBagQuantity[itemString] + quantity
			if quantity > 0 then
				Transactions.InsertVendorBuy(itemString, quantity, private.pending.copper[index])
			else
				Transactions.InsertVendorSale(itemString, -quantity, private.pending.copper[index])
			end
			private.RemovePending(index)
		end
	end
end

function private.PrunePending()
	for index, insertTime in Table.ReverseIPairs(private.pending.insertTime) do
		if LibTSMService.GetTime() - insertTime > 5 then
			private.RemovePending(index)
		end
	end
end

function private.RemovePending(index)
	local itemString = tremove(private.pending.itemString, index)
	tremove(private.pending.quantity, index)
	tremove(private.pending.copper, index)
	tremove(private.pending.insertTime, index)
	if not Table.KeyByValue(private.pending.itemString, itemString) then
		private.pendingBagQuantity[itemString] = nil
	end
end

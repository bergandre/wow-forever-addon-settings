-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Groups = LibTSMApp:InitInternal("Vendoring.Groups")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local VendoringOperation = LibTSMApp:From("LibTSMSystem"):Include("VendoringOperation")
local Container = LibTSMApp:From("LibTSMWoW"):Include("API.Container")
local Item = LibTSMApp:From("LibTSMWoW"):Include("API.Item")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Vendor = LibTSMApp:From("LibTSMService"):Include("Vendor")
local private = {
	buyThreadId = nil,
	sellThreadId = nil,
	settings = nil,
	groups = {},
	printedBagsFullMsg = false,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Groups:OnModuleLoad(function()
	private.buyThreadId = Threading.New("VENDORING_GROUP_BUY", private.BuyThread)
	private.sellThreadId = Threading.New("VENDORING_GROUP_SELL", private.SellThread)
end)

AddonSettings.RegisterOnLoad(Groups, function(db)
	private.settings = db:NewView("GroupsSettings")
		:AddKey("global", "vendoringOptions", "displayMoneyCollected")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Buys items in the specified groups.
---@param callback fun() The callback when buying is complete
---@param groups GroupPathValue[] The groups to buy items from
---@param isDryRun boolean Whether or not this is a dry run
function Groups.Buy(callback, groups, isDryRun)
	Groups.StopBuySell()

	wipe(private.groups)
	for _, groupPath in ipairs(groups) do
		tinsert(private.groups, groupPath)
	end
	Threading.SetCallback(private.buyThreadId, callback)
	Threading.Start(private.buyThreadId, private.groups, isDryRun)
end

---Sells items in the specified groups.
---@param callback fun() The callback when selling is complete
---@param groups GroupPathValue[] The groups to sell items from
---@param isDryRun boolean Whether or not this is a dry run
function Groups.Sell(callback, groups, isDryRun)
	Groups.StopBuySell()

	wipe(private.groups)
	for _, groupPath in ipairs(groups) do
		tinsert(private.groups, groupPath)
	end
	Threading.SetCallback(private.sellThreadId, callback)
	Threading.Start(private.sellThreadId, private.groups, isDryRun)
end

---Stops any in-progress buying or selling.
function Groups.StopBuySell()
	Threading.Kill(private.buyThreadId)
	Threading.Kill(private.sellThreadId)
end



-- ============================================================================
-- Buy Thread
-- ============================================================================

function private.BuyThread(groups, isDryRun)
	for _, groupPath in ipairs(groups) do
		groups[groupPath] = true
	end

	local itemsToBuy = Threading.AcquireSafeTempTable()
	local itemBuyQuantity = Threading.AcquireSafeTempTable()
	local query = Vendor.NewScannerQuery()
		:AutoRelease()
	for _, itemString, numAvailable in query:Iterator("itemString", "numAvailable") do
		numAvailable = numAvailable == -1 and math.huge or numAvailable
		local isExactMatch = Group.TranslateItemString(itemString) == itemString
		if isExactMatch and groups[Group.GetPathByItem(itemString)] and numAvailable > 0 and not itemBuyQuantity[itemString] then
			local numToBuy = VendoringOperation.GetNumToBuy(itemString)
			if numToBuy > 0 then
				tinsert(itemsToBuy, itemString)
				itemBuyQuantity[itemString] = min(numToBuy, numAvailable)
			end
		end
	end

	for _, itemString in ipairs(itemsToBuy) do
		local numToBuy = itemBuyQuantity[itemString]
		if isDryRun then
			local link = ItemInfo.GetLink(itemString)
			if link then
				ChatMessage.PrintfUser(L["Would buy %sx%d."], link, numToBuy)
			end
		else
			Vendor.BuyItem(itemString, numToBuy)
		end
		Threading.Yield(true)
	end

	TempTable.Release(itemsToBuy)
	TempTable.Release(itemBuyQuantity)
end



-- ============================================================================
-- Sell Thread
-- ============================================================================

function private.SellThread(groups, isDryRun)
	private.printedBagsFullMsg = false
	local totalValue = 0
	local ungroupedItems = private.GetUngroupedBagItemsThreaded()
	for _, groupPath in ipairs(groups) do
		for _, itemString, numToSell, sellSoulbound in VendoringOperation.SellItemIterator(groupPath, ungroupedItems) do
			totalValue = totalValue + private.SellItemThreaded(itemString, numToSell, sellSoulbound, isDryRun)
		end
	end
	TempTable.Release(ungroupedItems)

	if private.settings.displayMoneyCollected then
		ChatMessage.PrintfUser(isDryRun and L["Would have sold %s worth of items."] or L["Sold %s worth of items."], Money.ToStringForUI(totalValue))
	end
end

function private.GetUngroupedBagItemsThreaded()
	local items = Threading.AcquireSafeTempTable()
	local query = BagTracking.CreateQueryBags()
		:AutoRelease()
		:Distinct("itemString")
		:VirtualField("vendorSell", "number", ItemInfo.GetVendorSell, "itemString", 0)
		:GreaterThan("vendorSell", 0)
	for _, itemString in query:Iterator("itemString") do
		if Group.GetPathByItem(itemString) == Group.GetRootPath() then
			tinsert(items, itemString)
		end
	end
	return items
end

function private.SellItemThreaded(itemString, numToSell, sellSoulbound, isDryRun)
	local itemLink = ItemInfo.GetLink(itemString)

	-- Get a list of empty slots which we can use to split items into
	local itemFamily = nil
	if ItemString.IsItem(itemString) then
		itemFamily = Item.GetFamily(itemLink, ItemInfo.GetClassId(itemString) or -1)
	else
		itemFamily = 0
	end
	local emptySlotIds = private.GetEmptyBagSlotsThreaded(itemFamily)

	-- Get a list of slots containing the item we want to sell
	local slotIds = Threading.AcquireSafeTempTable()
	local bagQuery = BagTracking.CreateQueryBagsItem(itemString)
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:OrderBy("quantity", true)
		:If(not sellSoulbound)
			:Equal("isBound", false)
		:End()
	for _, slotId in bagQuery:Iterator("slotId") do
		tinsert(slotIds, slotId)
	end

	local totalValue = 0
	for _, slotId in ipairs(slotIds) do
		local quantity = BagTracking.GetQuantityBySlotId(slotId)
		if quantity <= numToSell then
			if isDryRun then
				ChatMessage.PrintfUser(L["Would sell %sx%d."], itemLink, quantity)
			else
				Container.UseItem(slotId)
				totalValue = totalValue + ((ItemInfo.GetVendorSell(itemString) or 0) * quantity)
			end
			numToSell = numToSell - quantity
		else
			if isDryRun then
				ChatMessage.PrintfUser(L["Would sell %sx%d."], itemLink, numToSell)
			elseif #emptySlotIds > 0 then
				local splitSlotId = tremove(emptySlotIds, 1)
				Container.SplitItem(slotId, numToSell)
				Container.PickupItem(splitSlotId)
				-- Wait for the stack to be split
				Threading.WaitForFunction(Container.GetItemLink, splitSlotId)
				Container.UseItem(splitSlotId)
				totalValue = totalValue + ((ItemInfo.GetVendorSell(itemString) or 0) * numToSell)
			elseif not private.printedBagsFullMsg then
				ChatMessage.PrintUser(L["Could not sell items due to not having free bag space available to split a stack of items."])
				private.printedBagsFullMsg = true
			end
			-- We're done
			numToSell = 0
		end
		if numToSell == 0 then
			break
		end
		Threading.Yield(true)
	end

	TempTable.Release(slotIds)
	TempTable.Release(emptySlotIds)
	return totalValue
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

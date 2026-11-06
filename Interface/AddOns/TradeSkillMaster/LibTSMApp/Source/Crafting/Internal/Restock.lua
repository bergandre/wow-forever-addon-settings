-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Restock = LibTSMApp:InitInternal("Crafting.Restock")
local CustomPrice = LibTSMApp:Include("Price.CustomPrice")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local MatQuantityString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.RecipeString")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local CraftingOperation = LibTSMApp:From("LibTSMSystem"):Include("CraftingOperation")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settings = nil,
	optionalMatTemp = {},
	qualityMatTemp = {},
	slotMatTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Restock:OnModuleLoad(function()
	SlashCommands.Register("restock_help", private.RestockHelp, L["Tells you why a specific item is not being restocked and added to the queue."])
end)

AddonSettings.RegisterOnLoad(Restock, function(db)
	private.settings = db:NewView("RestockSettings")
		:AddKey("global", "craftingOptions", "ignoreGuilds")
		:AddKey("global", "craftingOptions", "ignoreCharacters")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Restocks the specified groups.
---@param groups GroupPathValue[] The groups to restock
function Restock.RestockGroups(groups)
	for _, groupPath in Crafting.WithQueryUpdatesPaused(ipairs(groups)) do
		if groupPath ~= Group.GetRootPath() then
			for _, itemString in Group.ItemIterator(groupPath) do
				if Crafting.HasCraftedItem(itemString) then
					local isValid, err = private.IsOperationValid(itemString)
					if isValid then
						private.RestockItem(itemString)
					elseif err then
						ChatMessage.PrintUser(err)
					end
				end
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RestockHelp(link)
	local itemString = ItemString.Get(link)
	if not itemString then
		ChatMessage.PrintUser(L["No item specified. Usage: /tsm restock_help [ITEM_LINK]"])
		return
	end

	local msg = private.GetRestockHelpMessage(itemString)
	ChatMessage.PrintfUser(L["Restock help for %s: %s"], link, msg)
end

function private.GetRestockHelpMessage(itemString)
	-- Check if the item is in a group
	local groupPath = Group.GetPathByItem(itemString)

	-- Check that there's a crafting operation applied
	if not CraftingOperation.GetFirstOperationNameByItem(itemString) then
		return format(L["There is no Crafting operation applied to this item's TSM group (%s)."], Group.FormatPath(groupPath))
	end

	-- Check if it's an invalid operation
	local isValid, err = private.IsOperationValid(itemString)
	if not isValid then
		assert(err)
		return err
	end

	-- Check that this item is craftable
	if not Crafting.HasCraftedItem(itemString) then
		return L["You don't know how to craft this item."]
	end

	-- Check the restock quantity
	local neededQuantity = CraftingOperation.GetRestockQuantity(itemString, private.GetTotalQuantity(itemString))
	if neededQuantity == 0 then
		return L["You either already have at least your max restock quantity of this item or the number which would be queued is less than the min restock quantity."]
	end

	-- Check if we would actually queue any
	local cost, craftString = Crafting.GetLowestCostByItem(itemString)
	local numResult = craftString and Crafting.GetNumResult(craftString)
	if not numResult then
		return L["You don't know how to craft this item."]
	elseif neededQuantity < numResult then
		return format(L["A single craft makes %d and you only need to restock %d."], numResult, neededQuantity)
	end

	-- Check the prices on the item and the min profit
	local hasMinProfit, minProfit = CraftingOperation.GetMinProfit(itemString)
	if hasMinProfit then
		local craftedValue = Crafting.GetCraftedItemValue(itemString)
		local profit = cost and craftedValue and (craftedValue - cost) or nil

		-- Check that there's a crafted value
		if not craftedValue then
			return L["The 'Craft Value Method' did not return a value for this item."]
		end

		-- Check that there's a crafted cost
		if not cost then
			return L["This item does not have a crafting cost. Check that all of its mats have mat prices."]
		end

		-- Check that there's a profit
		assert(profit)

		if not minProfit then
			return L["The min profit did not evaluate to a valid value for this item."]
		end

		if profit < minProfit then
			return format(L["The profit of this item (%s) is below the min profit (%s)."], Money.ToStringExact(profit), Money.ToStringExact(minProfit))
		end
	end

	return L["This item will be added to the queue when you restock its group. If this isn't happening, please visit http://support.tradeskillmaster.com for further assistance."]
end

function private.IsOperationValid(itemString)
	local isValid, operationName, errType, errArg, errArg2 = CraftingOperation.IsValid(itemString)
	if isValid or not errType then
		return isValid
	elseif errType == CraftingOperation.ERROR.RESTOCK_QUANTITIES_CONFLICT then
		return false, format(L["'%s' is an invalid operation. Min restock of %d is higher than max restock of %d for %s."], operationName, errArg, errArg2, ItemInfo.GetLink(itemString))
	elseif errType == CraftingOperation.ERROR.MIN_RESTOCK_INVALID then
		---@cast errArg string
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		assert(errStr)
		return nil, format(L["Your min restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..errStr
	elseif errType == CraftingOperation.ERROR.MIN_RESTOCK_INVALID_RANGE then
		return nil, format(L["Your min restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..format(L["Must be between %d and %d."], CraftingOperation.GetRestockValueRange():GetValues())
	elseif errType == CraftingOperation.ERROR.MAX_RESTOCK_INVALID then
		---@cast errArg string
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		assert(errStr)
		return nil, format(L["Your max restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..errStr
	elseif errType == CraftingOperation.ERROR.MAX_RESTOCK_INVALID_RANGE then
		return nil, format(L["Your max restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..format(L["Must be between %d and %d."], CraftingOperation.GetRestockValueRange():GetValues())
	else
		error("Invalid errType: "..tostring(errType))
	end
end

function private.RestockItem(itemString)
	assert(not next(private.optionalMatTemp) and not next(private.qualityMatTemp))
	local cheapestCost, cheapestCraftString, cheapestConcentration = Crafting.GetLowestCostByItem(itemString, private.optionalMatTemp, private.qualityMatTemp)
	if not cheapestCraftString or (cheapestConcentration or 0) > 0 then
		-- Can't craft this item (or need concentration)
		wipe(private.qualityMatTemp)
		wipe(private.optionalMatTemp)
		return
	end
	assert(not next(private.slotMatTemp))
	for _, matQuantityString in ipairs(private.optionalMatTemp) do
		local slotId = private.GetOptionalMatSlotId(cheapestCraftString, matQuantityString)
		if slotId then
			private.slotMatTemp[slotId] = matQuantityString
		end
	end
	wipe(private.optionalMatTemp)
	for matQuantityString, matString in pairs(private.qualityMatTemp) do
		private.slotMatTemp[MatString.GetSlotId(matString)] = matQuantityString
	end
	wipe(private.qualityMatTemp)
	local recipeString = RecipeString.FromCraftString(cheapestCraftString, private.slotMatTemp)
	wipe(private.slotMatTemp)
	local itemValue = Crafting.GetCraftedItemValue(itemString)
	local profit = itemValue and cheapestCost and (itemValue - cheapestCost) or nil
	local hasMinProfit, minProfit = CraftingOperation.GetMinProfit(itemString)
	if hasMinProfit and (not minProfit or not profit or profit < minProfit) then
		-- Profit is too low
		return
	end

	local haveQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
	for guild, ignored in pairs(private.settings.ignoreGuilds) do
		if ignored then
			haveQuantity = haveQuantity - AltTracking.GetGuildQuantity(itemString, guild)
		end
	end
	for player, ignored in pairs(private.settings.ignoreCharacters) do
		if ignored then
			haveQuantity = haveQuantity - AltTracking.GetBagQuantity(itemString, player)
			haveQuantity = haveQuantity - AltTracking.GetBankQuantity(itemString, player)
			haveQuantity = haveQuantity - AltTracking.GetAuctionQuantity(itemString, player)
			haveQuantity = haveQuantity - AltTracking.GetMailQuantity(itemString, player)
		end
	end
	assert(haveQuantity >= 0)
	local neededQuantity = CraftingOperation.GetRestockQuantity(itemString, haveQuantity)
	if neededQuantity == 0 then
		return
	end
	Crafting.SetNumQueued(recipeString, floor(neededQuantity / Crafting.GetNumResult(cheapestCraftString)))
end

function private.GetTotalQuantity(itemString)
	return CustomString.GetSourceValue("NumInventory", itemString) or 0
end

function private.GetOptionalMatSlotId(craftString, matQuantityString)
	local result = nil
	for _, matString, slotId in Crafting.OptionalMatIterator(craftString) do
		if not result and private.ContainsAllItems(matString, matQuantityString) then
			result = slotId
		end
	end
	return result
end

function private.ContainsAllItems(matString, matQuantityString)
	local result = true
	for _, itemString in MatQuantityString.Iterator(matQuantityString) do
		result = result and MatString.ContainsItem(matString, itemString)
	end
	return result
end

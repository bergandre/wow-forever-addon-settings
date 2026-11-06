-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local AuctionHouse = LibTSMWoW:Init("API.AuctionHouse")
local ScriptWrapper = LibTSMWoW:Include("API.ScriptWrapper")
local Event = LibTSMWoW:Include("Service.Event")
local SlotId = LibTSMWoW:Include("Type.SlotId")
local Move = LibTSMWoW:Include("Service.Move")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local LibAHTab = LibStub("LibAHTab-1-0")
local private = {
	auctionIdToLink = {},
	auctionIdToItemBuyout = {},
	postHookFuncs = CallbackRegistry.NewList(),
	itemPostedCallbacks = CallbackRegistry.NewList(),
	purchaseHookFuncs = CallbackRegistry.NewList(),
	getAllHookFuncs = CallbackRegistry.NewList(),
	lastPurchase = {
		link = nil,
		name = nil,
		quantity = nil,
		buyout = nil,
	},
	notificationCallbacks = CallbackRegistry.NewList(),
	pendingPost = {
		itemLink = nil,
		quantity = nil,
		unitPrice = nil,
		timestamp = nil,
	},
}
AuctionHouse.DURATIONS = {
	not LibTSMWoW.IsVanillaClassic() and AUCTION_DURATION_ONE or gsub(AUCTION_DURATION_ONE, "12", "2"),
	not LibTSMWoW.IsVanillaClassic() and AUCTION_DURATION_TWO or gsub(AUCTION_DURATION_TWO, "24", "8"),
	not LibTSMWoW.IsVanillaClassic() and AUCTION_DURATION_THREE or gsub(AUCTION_DURATION_THREE, "48", "24"),
}
local NOTIFICATION = EnumType.New("AUCTION_NOTIFICATION", {
	BUY = EnumType.NewValue(),
	BID = EnumType.NewValue(),
	OUTBID = EnumType.NewValue(),
	EXPIRED = EnumType.NewValue(),
	SOLD = EnumType.NewValue(),
	CANCELLED = EnumType.NewValue(),
})
AuctionHouse.NOTIFICATION = NOTIFICATION
local AUCTIONABLE_WOW_TOKEN_ITEM_ID = 122270
local function NoOp()
end

---@class ExtendedItemSearchResultInfo: ItemSearchResultInfo
---@field isHighBidder boolean

---@diagnostic disable-next-line: class-shadows-builtin
---@class AuctionFrameType
---@field numTabs number
---@field selectedTab number



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctionHouse:OnModuleLoad(function()
	if not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() then
		-- Maintain our auctionId maps
		Event.Register("ITEM_SEARCH_RESULTS_UPDATED", private.HandleItemSearchResultsUpdated)
		-- Handle auctions being created
		Event.Register("AUCTION_HOUSE_AUCTION_CREATED", private.AuctionCreatedHandler)
	end
	-- Setup Hooks
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		hooksecurefunc("PostAuction", private.PostAuctionHook)
		hooksecurefunc("PlaceAuctionBid", private.PlaceAuctionBidHook)
	else
		hooksecurefunc(C_AuctionHouse, "PostCommodity", private.PostCommodityHook)
		hooksecurefunc(C_AuctionHouse, "PostItem", private.PostItemHook)
		hooksecurefunc(C_AuctionHouse, "PlaceBid", private.PlaceBidHook)
		hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", private.ConfirmCommoditiesPurchaseHook)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not an item in the player's bags can be sold on the AH (requires C_AuctionHouse).
---@param slotId number The slot ID
---@return boolean
function AuctionHouse.IsSellable(slotId)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	local itemLocation = SlotId.AcquireItemLocation(slotId)
	local canSell = itemLocation:IsValid() and C_AuctionHouse.IsSellItemValid(itemLocation, false) or false -- FIXME: Duplicate hover
	SlotId.ReleaseItemLocation(itemLocation)
	return canSell
end

---Returns whether or not the owned auctions are fully loaded.
---@return boolean
function AuctionHouse.OwnedFullyLoaded()
	return (LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic()) or C_AuctionHouse.HasFullOwnedAuctionResults()
end

---Returns whether or not owned auctions are sorted by owner/duration (not available with C_AuctionHouse).
---@return boolean
function AuctionHouse.AreOwnedSortedByOwnerDuration()
	assert(LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic())
	---@diagnostic disable: undefined-global
	local sortEntries = AuctionSort.owner_duration
	---@diagnostic enable: undefined-global
	local numColumns = #sortEntries
	for i, info in ipairs(sortEntries) do
		local col, reversed = GetAuctionSort("owner", numColumns - i + 1)
		-- We want to do the opposite order
		reversed = not reversed
		if col ~= info.column or info.reverse ~= reversed then
			return false
		end
	end
	return true
end

---Sorts owned auctions by owner/duration (not available with C_AuctionHouse).
function AuctionHouse.SortOwnedByOwnerDuration()
	AuctionFrame_SetSort("owner", "duration", true)
	SortAuctionApplySort("owner")
end

---Gets the number of owned auctions.
---@return number
function AuctionHouse.GetNumOwned()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		return GetNumAuctionItems("owner")
	else
		return C_AuctionHouse.GetNumOwnedAuctions()
	end
end

---Gets info on an owned auction (auctionId of math.huge indicates ignored WoW token).
---@param index number The owned auction index
---@return number? auctionId
---@return string|number|nil itemLinkOrId
---@return string? name
---@return number? texture
---@return number? stackSize
---@return number? quality
---@return number? currentBid
---@return number? buyout
---@return string? highBidder
---@return boolean? isSold
---@return number? duration
function AuctionHouse.GetOwnedInfo(index)
	local auctionId, link, name, texture, stackSize, quality, minBid, buyout, bid, highBidder, saleStatus, duration = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		local _
		name, texture, stackSize, quality, _, _, _, minBid, _, buyout, bid, highBidder, _, _, _, saleStatus = GetAuctionItemInfo("owner", index)
		link = name and name ~= "" and GetAuctionItemLink("owner", index)
		if not link then
			return
		end
		duration = GetAuctionItemTimeLeft("owner", index)
		auctionId = index
		highBidder = highBidder or ""
	else
		local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
		assert(info)
		if info.itemKey.itemID == AUCTIONABLE_WOW_TOKEN_ITEM_ID then
			-- We currently just ignore posted tokens, so just return an auctionId as math.huge to indicate this
			return math.huge
		end
		link = info and info.itemLink or info.itemKey.itemID
		bid = info.bidAmount or info.buyoutAmount
		auctionId = info.auctionID
		stackSize = info.quantity
		minBid = bid
		buyout = info.buyoutAmount or 0
		highBidder = info.bidder or ""
		saleStatus = info.status
		duration = info.timeLeftSeconds or 0
	end
	local currentBid = highBidder ~= "" and bid or minBid
	if saleStatus == 0 then
		if not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() then
			duration = time() + duration
		end
	elseif saleStatus == 1 then
		if not currentBid and not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() then
			-- Sometimes wow doesn't tell us the current bid on sold auctions on retail
			currentBid = 0
		end
		duration = time() + duration
	else
		error("Invalid sale status: "..tostring(saleStatus))
	end
	if not link then
		return
	end
	return auctionId, link, name, texture, stackSize, quality, currentBid, buyout, highBidder, saleStatus == 1, duration
end

---Register a secure hook function for when an auction is posted.
---@param func fun(duration: number, itemLink: string?, quantity: number?, price: number?) The function to call
function AuctionHouse.SecureHookPost(func)
	private.postHookFuncs:Add(func)
end

---Register a callback when an item is posted.
---@param func fun(itemLink: string, quantity: number, price: number) The function to call
function AuctionHouse.RegisterItemPostedCallback(func)
	private.itemPostedCallbacks:Add(func)
end

---Register a secure hook function for when an auction is cancelled.
---@param func fun(auctionId: number) The function to call
function AuctionHouse.SecureHookCancel(func)
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		hooksecurefunc("CancelAuction", func)
	else
		hooksecurefunc(C_AuctionHouse, "CancelAuction", func)
	end
end

---Register a secure hook function for when an auction is purchased.
---@param func fun(itemLink: string, quantity: number) The function to call
function AuctionHouse.SecureHookPurchase(func)
	private.purchaseHookFuncs:Add(func)
end

---Register a secure hook function for when a GetAll scan is started
---@param func fun() The function to call
function AuctionHouse.SecureHookGetAllScan(func)
	if private.getAllHookFuncs:IsEmpty() then
		if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
			hooksecurefunc("QueryAuctionItems", function(_, _, _, _, _, _, isGetAll)
				if not isGetAll then
					return
				end
				private.GetAllScanHook()
			end)
		else
			hooksecurefunc(C_AuctionHouse, "ReplicateItems", private.GetAllScanHook)
		end
	end
	private.getAllHookFuncs:Add(func)
end

---Starts a GetAll scan.
function AuctionHouse.StartGetAllScan()
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	C_AuctionHouse.ReplicateItems()
end

---Gets info on the last purchase made.
---@return string|number|nil link
---@return string? name
---@return number? quantity
---@return number? buyout
function AuctionHouse.GetLastPurchase()
	return private.lastPurchase.link, private.lastPurchase.name, private.lastPurchase.quantity, private.lastPurchase.buyout
end

---Gets the number of black market auction house items.
---@return number?
function AuctionHouse.GetNumBlackMarketAuctions()
	return C_BlackMarket.GetNumItems()
end

---Gets info on a black market auction house item.
---@param index number The auction index
---@return number quantity
---@return number minBid
---@return number minIncr
---@return number currBid
---@return number numBids
---@return number timeLeft
---@return string itemLink
---@return number bmId
function AuctionHouse.GetBlackMarketItemInfo(index)
	local _, _, quantity, _, _, _, _, _, minBid, minIncr, currBid, _, numBids, timeLeft, itemLink, bmId = C_BlackMarket.GetItemInfoByIndex(index)
	return quantity, minBid, minIncr, currBid, numBids, timeLeft, itemLink, bmId
end

---Makes an item key.
---@param itemId number The item ID
---@param battlePetSpeciesId? number The battle pet species ID
---@return ItemKey
function AuctionHouse.MakeItemKey(itemId, battlePetSpeciesId)
	local itemKey = C_AuctionHouse.MakeItemKey(itemId, 0, 0, battlePetSpeciesId)
	return itemKey
end

---Check if the full browse results are loaded.
---@return boolean
function AuctionHouse.HasFullBrowseResults()
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	return C_AuctionHouse.HasFullBrowseResults()
end

---Check if the full search results are loaded.
---@param item number|ItemKey Either the item ID or item key (for commodities / items respectively)
---@return boolean
function AuctionHouse.HasFullSearchResults(item)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	if type(item) == "table" then
		return C_AuctionHouse.HasFullItemSearchResults(item)
	else
		return C_AuctionHouse.HasFullCommoditySearchResults(item --[[@as number]])
	end
end

---Gets the number of search results.
---@param item number|ItemKey Either the item ID or item key (for commodities / items respectively)
---@return number
function AuctionHouse.GetNumSearchResults(item)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	if type(item) == "table" then
		return C_AuctionHouse.GetNumItemSearchResults(item)
	else
		return C_AuctionHouse.GetNumCommoditySearchResults(item --[[@as number]])
	end
end

---Gets the number of auctions of browse results.
---@return number
function AuctionHouse.GetNumAuctions()
	assert(LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic())
	local numAuctions = GetNumAuctionItems("list")
	return numAuctions
end

---Gets the number of auctions for a GetAll scan.
---@return number
function AuctionHouse.GetNumGetAllAuctions()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		local numAuctions = GetNumAuctionItems("list")
		return numAuctions
	else
		return C_AuctionHouse.GetNumReplicateItems()
	end
end

---Gets the number of pages of browse results.
---@return number
function AuctionHouse.GetNumPages()
	assert(LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic())
	local numAuctions, totalNumAuctions = GetNumAuctionItems("list")
	if numAuctions == 0 then
		-- Sometimes the AH refuses to give more results, so don't keep scanning
		totalNumAuctions = 0
	end
	return ceil(totalNumAuctions / NUM_AUCTION_ITEMS_PER_PAGE)
end

---Gets the browse results.
---@return BrowseResultInfo[]
function AuctionHouse.GetBrowseResults()
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	return C_AuctionHouse.GetBrowseResults()
end

---Gets a browse query result entry.
---@param index number The result index
---@return (string rawName, string? itemLink, number stackSize, number timeLeft, number buyout, string? seller, number minIncrement, number minBid, number bid, boolean isHighBidder)
---|       (nil, nil, nil, nil, nil, nil, nil, nil, nil)
function AuctionHouse.GetBrowseResult(index)
	assert(LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic())
	local rawName, _, stackSize, _, _, _, _, minBid, minIncrement, buyout, bid, highBidder, _, seller, sellerFull = GetAuctionItemInfo("list", index)
	-- This is to get around a bug in Blizzard's code where the minIncrement value will be inconsistent for auctions where the player is the highest bidder
	minIncrement = highBidder and 0 or minIncrement
	local itemLink = GetAuctionItemLink("list", index)
	local timeLeft = GetAuctionItemTimeLeft("list", index)
	if sellerFull and strjoin("-", seller, GetRealmName()) ~= sellerFull then
		seller = sellerFull
	end
	local isHighBidder = UnitName("player") == highBidder
	return rawName, itemLink, stackSize, timeLeft, buyout, seller, minIncrement, minBid, bid, isHighBidder
end

---Gets a limited subset of browse query result data appropriate for a GetAll scan.
---@param index number The result index
---@return string? itemLink
---@return number? stackSize
---@return number? buyout
function AuctionHouse.GetGetAllResult(index)
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		local itemLink = GetAuctionItemLink("list", index)
		local _, _, stackSize, _, _, _, _, _, _, buyout = GetAuctionItemInfo("list", index)
		return itemLink, stackSize, buyout
	else
		local itemLink = C_AuctionHouse.GetReplicateItemLink(index - 1)
		local _, _, stackSize, _, _, _, _, _, _, buyout = C_AuctionHouse.GetReplicateItemInfo(index - 1)
		return itemLink, stackSize, buyout
	end
end

---Gets the search result info.
---@param item number|ItemKey Either the item ID or item key (for commodities / items respectively)
---@param index number The result index
---@return ExtendedItemSearchResultInfo|CommoditySearchResultInfo
function AuctionHouse.GetSearchResultInfo(item, index)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	local info = nil
	if type(item) == "table" then
		info = C_AuctionHouse.GetItemSearchResultInfo(item, index) --[[@as ExtendedItemSearchResultInfo]]
		info.isHighBidder = info.bidder and info.bidder == UnitGUID("player") or false
	else
		info = C_AuctionHouse.GetCommoditySearchResultInfo(item --[[@as number]], index)
	end
	assert(info)
	for i, owner in ipairs(info.owners) do
		if owner == "player" then
			info.owners[i] = UnitName("player")
		elseif owner == "" then
			info.owners[i] = "?"
		end
	end
	return info
end

---Gets info for an item key.
---@param itemKey ItemKey The item key
---@return ItemKeyInfo?
function AuctionHouse.GetItemKeyInfo(itemKey)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	return C_AuctionHouse.GetItemKeyInfo(itemKey, true)
end

---Gets extra browse info for an item key.
---@param itemKey ItemKey The item key
---@return number?
function AuctionHouse.GetExtraBrowseInfo(itemKey)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	return C_AuctionHouse.GetExtraBrowseInfo(itemKey)
end

---Whether or not the AH is ready for a query.
---@return boolean canSendQuery
function AuctionHouse.CanSendQuery()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		return CanSendAuctionQuery() and true or false
	else
		return true
	end
end

---Gets the remaining duration on the commodity price quote.
---@return number
function AuctionHouse.GetQuoteDurationRemaining()
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	return C_AuctionHouse.GetQuoteDurationRemaining()
end

---Registers a callback for auction house notification messages.
---@param callback fun(notification: EnumValue, arg?: string|number)
function AuctionHouse.RegisterNotificationCallback(callback)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	if private.notificationCallbacks:IsEmpty() then
		Event.Register("AUCTION_HOUSE_SHOW_NOTIFICATION", private.HandleNotification)
		Event.Register("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", private.HandleNotification)
		Event.Register("AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION", private.HandleCommodityNotification)
	end
	private.notificationCallbacks:Add(callback)
end

---Gets the formatted auction purchase message.
---@param name string The item name
---@return string
function AuctionHouse.GetPurchaseMessage(name)
	return format(ERR_AUCTION_WON_S, name)
end

---Gets the formatted auction sold message.
---@param name string The item name
---@return string
function AuctionHouse.GetSoldMessage(name)
	return format(ERR_AUCTION_SOLD_S, name)
end

---Returns whether or not the specified message is an auction purchase message.
---@param msg string The message
---@param name string The item name
---@param quantity? number The auction quantity
---@return boolean
function AuctionHouse.IsPurchaseMessage(msg, name, quantity)
	if msg == AuctionHouse.GetPurchaseMessage(name) then
		return true
	elseif quantity and not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() and msg == format(ERR_AUCTION_COMMODITY_WON_S, name, quantity) then
		return true
	end
	return false
end

---Gets the localized string for a time left duration.
---@param duration number The time left
---@return string str
---@return string detailStr
function AuctionHouse.GetTimeLeftStrings(duration)
	return _G["AUCTION_TIME_LEFT"..duration], _G["AUCTION_TIME_LEFT"..duration.."_DETAIL"]
end

---Gets the cancel cost for an auction.
---@param auctionId number The auction ID
---@return number
function AuctionHouse.GetCancelCost(auctionId)
	return C_AuctionHouse.GetCancelCost(auctionId)
end

---Gets the max allowed price.
---@return number
function AuctionHouse.GetMaxPrice()
	return MAXIMUM_BID_PRICE
end

---Clears any pending sell item.
function AuctionHouse.ClearSellItem()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		ClearCursor()
		ClickAuctionSellItemButton(AuctionsItemButton, "LeftButton")
	end
	ClearCursor()
end

---Unregisters the default UI AH notification events.
function AuctionHouse.UnregisterDefaultUINotificationEvents()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		return
	end
	UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW_NOTIFICATION")
	UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION")
	UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION")
end

---Unregisters the default AH show event.
function AuctionHouse.UnregisterDefaultShowEvent()
	UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW")
end

---Adds a tab to the auction house frame.
---@param tabId string The tab ID
---@param text string The text to display within the tab
---@param onClickHandler function The "OnClick" script handler
function AuctionHouse.AddTab(tabId, text, onClickHandler)
	local tab = nil
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		tabId = AuctionFrame.numTabs + 1
		tab = CreateFrame("Button", "AuctionFrameTab"..tabId, AuctionFrame, "AuctionTabTemplate")
		tab:Hide()
		tab:SetID(tabId)
		tab:SetText(text)
		tab:SetNormalFontObject(GameFontHighlightSmall)
		tab:SetPoint("LEFT", _G["AuctionFrameTab"..tabId - 1], "RIGHT", -8, 0)
		tab:Show()
		PanelTemplates_SetNumTabs(AuctionFrame, tabId)
		PanelTemplates_EnableTab(AuctionFrame, tabId)
	else
		LibAHTab:CreateTab(tabId, CreateFrame("Frame"), text)
		tab = LibAHTab:GetButton(tabId)
		if AuctionHouseFrame:IsVisible() then
			private.UnregisterDefaultUIEvents()
		end
	end
	ScriptWrapper.Set(tab, "OnClick", function(...)
		private.TabOnClickHelper(tabId)
		return onClickHandler(...)
	end)
end

---Sets the selected tab.
---@param tabId string The tab ID
function AuctionHouse.SetSelectedTab(tabId)
	assert(not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic())
	Move.SetDefaultUIOffScreen(AuctionHouseFrame)
	AuctionHouseFrame:SetScale(0.001)
	LibAHTab:SetSelected(tabId)
end

---Loads the default UI auction house addon.
function AuctionHouse.LoadAddon()
	C_AddOns.LoadAddOn((LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic()) and "Blizzard_AuctionUI" or "Blizzard_AuctionHouseUI")
	if not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() then
		AuctionHouseFrame:HookScript("OnShow", private.UnregisterDefaultUIEvents)
	end
end

---Closes the auction house UI.
function AuctionHouse.Close()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		CloseAuctionHouse()
	else
		AuctionHouseFrame:SetScale(1)
		Move.RestoreDefaultUI(AuctionHouseFrame)
		C_AuctionHouse.CloseAuctionHouse()
	end
end

---Restores the default UI after showing a custom tab.
function AuctionHouse.RestoreDefaultUI()
	if not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() then
		AuctionHouseFrame:SetScale(1)
		Move.RestoreDefaultUI(AuctionHouseFrame)
		AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
	end
end

---Shows the default auction house UI.
function AuctionHouse.ShowDefaultUI()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		GameEvent.HandleAuctionHouseShow()
	else
		UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleItemSearchResultsUpdated(_, itemKey)
	wipe(private.auctionIdToLink)
	wipe(private.auctionIdToItemBuyout)
	for i = 1, AuctionHouse.GetNumSearchResults(itemKey) do
		local info = AuctionHouse.GetSearchResultInfo(itemKey, i)
		if info.buyoutAmount then
			private.auctionIdToLink[info.auctionID] = info.itemLink
			private.auctionIdToItemBuyout[info.auctionID] = info.buyoutAmount
		end
	end
end

function private.PostCommodityHook(item, duration, quantity, unitPrice)
	private.HandlePostHook(duration, C_Item.GetItemLink(item), quantity, unitPrice)
end

function private.PostItemHook(item, duration, quantity, _, buyout)
	private.HandlePostHook(duration, C_Item.GetItemLink(item), quantity, buyout)
end

function private.PostAuctionHook(_, _, duration)
	private.HandlePostHook(duration)
end

function private.HandlePostHook(duration, itemLink, quantity, price)
	if itemLink then
		private.pendingPost.itemLink = itemLink
		private.pendingPost.quantity = quantity
		private.pendingPost.unitPrice = price
		private.pendingPost.timestamp = LibTSMWoW.GetTime()
	else
		wipe(private.pendingPost)
	end
	private.postHookFuncs:CallAll(duration, itemLink, quantity, price)
end

function private.AuctionCreatedHandler()
	if LibTSMWoW.GetTime() - (private.pendingPost.timestamp or 0) > 5 then
		-- Too much time elapsed or nothing pending
		return
	end
	private.itemPostedCallbacks:CallAll(private.pendingPost.itemLink, private.pendingPost.quantity, private.pendingPost.unitPrice)
	wipe(private.pendingPost)
end

function private.PlaceBidHook(auctionId, bidPlaced)
	local link = private.auctionIdToLink[auctionId]
	local buyout = private.auctionIdToItemBuyout[auctionId]
	if not link or buyout ~= bidPlaced then
		return
	end
	private.HandlePurchaseHook(link, nil, 1, bidPlaced)
end

function private.ConfirmCommoditiesPurchaseHook(itemId, quantity)
	local origQuantity = quantity
	local buyout = 0
	for i = 1, AuctionHouse.GetNumSearchResults(itemId) do
		local info = AuctionHouse.GetSearchResultInfo(itemId, i)
		local resultQuantity = min(quantity, info.quantity - info.numOwnerItems)
		buyout = buyout + resultQuantity * info.unitPrice
		quantity = quantity - resultQuantity
		if quantity == 0 then
			break
		end
	end
	if quantity > 0 then
		return
	end
	private.HandlePurchaseHook(itemId, nil, origQuantity, buyout)
end

function private.PlaceAuctionBidHook(_, index, amountPaid)
	local name, itemLink, stackSize, _, buyout = AuctionHouse.GetBrowseResult(index)
	if amountPaid ~= buyout then
		return
	end
	private.HandlePurchaseHook(itemLink, name, stackSize, buyout)
	if itemLink then
		private.purchaseHookFuncs:CallAll(itemLink, stackSize)
	end
end

function private.HandlePurchaseHook(link, name, quantity, price)
	private.lastPurchase.link = link
	private.lastPurchase.name = name
	private.lastPurchase.quantity = quantity
	private.lastPurchase.buyout = price
end

function private.HandleNotification(_, msg, msgArg)
	if msg == Enum.AuctionHouseNotification.AuctionWon then
		private.notificationCallbacks:CallAll(NOTIFICATION.BUY)
	elseif msg == Enum.AuctionHouseNotification.AuctionSold and msgArg then
		private.notificationCallbacks:CallAll(NOTIFICATION.SOLD, msgArg)
	elseif msg == Enum.AuctionHouseNotification.AuctionOutbid and msgArg then
		private.notificationCallbacks:CallAll(NOTIFICATION.OUTBID, format(ERR_AUCTION_OUTBID_S, msgArg))
	elseif msg == Enum.AuctionHouseNotification.AuctionExpired and msgArg then
		private.notificationCallbacks:CallAll(NOTIFICATION.EXPIRED, format(ERR_AUCTION_EXPIRED_S, msgArg))
	elseif msg == Enum.AuctionHouseNotification.BidPlaced then
		private.notificationCallbacks:CallAll(NOTIFICATION.BID, ERR_AUCTION_BID_PLACED)
	elseif msg == Enum.AuctionHouseNotification.AuctionRemoved then
		private.notificationCallbacks:CallAll(NOTIFICATION.CANCELLED, ERR_AUCTION_REMOVED)
	end
end

function private.HandleCommodityNotification(_, _, quantity)
	private.notificationCallbacks:CallAll(NOTIFICATION.BUY, quantity)
end

function private.GetAllScanHook()
	private.getAllHookFuncs:CallAll()
end

function private.UnregisterDefaultUIEvents()
	AuctionHouseFrame:UnregisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
	AuctionHouseFrame:UnregisterEvent("AUCTION_HOUSE_SHOW_NOTIFICATION")
	AuctionHouseFrame:UnregisterEvent("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION")
	AuctionHouseFrame:UnregisterEvent("AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION")
end

function private.TabOnClickHelper(tabId)
	AuctionHouse.ClearSellItem()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		-- Replace CloseAuctionHouse() with a no-op while hiding the AH frame so we don't stop interacting with the AH NPC
		local origCloseAuctionHouse = CloseAuctionHouse
		CloseAuctionHouse = NoOp
		AuctionFrame_Hide()
		CloseAuctionHouse = origCloseAuctionHouse
	else
		AuctionHouseFrame:SetScale(0.001)
		Move.SetDefaultUIOffScreen(AuctionHouseFrame)
		LibAHTab:SetSelected(tabId)
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AuctionChatMessage = LibTSMApp:Init("Service.AuctionChatMessage")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local AuctionHouse = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouse")
local ChatFrame = LibTSMApp:From("LibTSMWoW"):Include("API.ChatFrame")
local SoundAlert = LibTSMApp:From("LibTSMWoW"):Include("UI.SoundAlert")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local Lifecycle = LibTSMApp:From("LibTSMService"):Include("Util.Lifecycle")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local private = {
	settings = nil,
	prevLineId = nil,
	freeTablesTemp = {},
	nameTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(AuctionChatMessage, function(db)
	private.settings = db:NewView("AuctionChatMessageSettings")
		:AddKey("char", "internalData", "auctionPrices")
		:AddKey("char", "internalData", "auctionMessages")
		:AddKey("global", "coreOptions", "auctionSaleSound")
		:Commit()

	Auction.RegisterThrottledIndexCallback(private.HandleThrottledAuctionsUpdate)

	-- Setup enhanced sale / buy messages
	if LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic() then
		ChatFrame.AddMessageFilter(private.FilterSystemMsg)
		-- Setup auction created / cancelled filtering
		-- NOTE: This is delayed until the game is loaded to avoid taint issues
		Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
	else
		AuctionHouse.RegisterNotificationCallback(private.HandleNotification)
	end
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	ChatFrame.SuppressAuctionMessages()
	return true
end

function private.HandleThrottledAuctionsUpdate()
	-- Recycle tables from private.settings.auctionPrices if we can so we're not creating a ton of garbage
	assert(not next(private.freeTablesTemp))
	for _, tbl in pairs(private.settings.auctionPrices) do
		Table.WipeAndDeallocate(tbl)
		tinsert(private.freeTablesTemp, tbl)
	end
	wipe(private.settings.auctionPrices)
	wipe(private.settings.auctionMessages)
	assert(not next(private.nameTemp))
	local query = Auction.NewIndexQuery()
		:AutoRelease()
		:Equal("isSold", false)
		:GreaterThan("buyout", 0)
		:OrderBy("index", true)
	for _, link, buyout in query:Iterator("itemLink", "buyout") do
		if not private.nameTemp[link] then
			local name = ItemInfo.GetName(link) or false
			private.nameTemp[link] = name
			if name then
				local msg = (LibTSMApp.IsVanillaClassic() or LibTSMApp.IsBCClassic()) and AuctionHouse.GetSoldMessage(name) or name
				private.settings.auctionMessages[msg] = link
			end
		end
		if private.nameTemp[link] then
			private.settings.auctionPrices[link] = private.settings.auctionPrices[link] or tremove(private.freeTablesTemp) or {}
			tinsert(private.settings.auctionPrices[link], buyout)
		end
	end
	for _, prices in pairs(private.settings.auctionPrices) do
		sort(prices)
	end
	wipe(private.freeTablesTemp)
	Table.WipeAndDeallocate(private.nameTemp)
end

function private.FilterSystemMsg(_, _, msg, ...)
	local lineID = select(10, ...)
	if lineID == private.prevLineId then
		return
	end
	private.prevLineId = lineID
	local chatMsg = nil
	if private.LastPurchaseMatchesAuctionWonMessage(msg) then
		-- We just bought an auction
		chatMsg = private.GetAuctionWonMessage()
	elseif private.settings.auctionMessages[msg] then
		-- We just sold an auction
		chatMsg = private.GetAuctionSoldMessage(msg)
	end
	if chatMsg then
		return nil, chatMsg, ...
	end
end

function private.LastPurchaseMatchesAuctionWonMessage(msg)
	local _, name, quantity = private.GetLastPurchase()
	return name and AuctionHouse.IsPurchaseMessage(msg, name, quantity) or false
end

function private.GetLastPurchase()
	local link, name, quantity, buyout = AuctionHouse.GetLastPurchase()
	if type(link) == "number" then
		link = ItemInfo.GetLink(ItemString.FromItemId(link))
	end
	if not link then
		return nil, nil, nil, nil
	end
	name = ItemInfo.GetName(link) or name
	return link, name, quantity, buyout
end

function private.HandleNotification(notification, arg)
	local chatMsg = nil
	if notification == AuctionHouse.NOTIFICATION.BUY then
		chatMsg = private.GetAuctionWonMessage(arg)
	elseif notification == AuctionHouse.NOTIFICATION.SOLD then
		chatMsg = private.GetAuctionSoldMessage(arg)
	elseif notification == AuctionHouse.NOTIFICATION.OUTBID then
		chatMsg = arg
	elseif notification == AuctionHouse.NOTIFICATION.EXPIRED then
		chatMsg = arg
	elseif notification == AuctionHouse.NOTIFICATION.BID then
		chatMsg = arg
	elseif notification == AuctionHouse.NOTIFICATION.CANCELLED then
		chatMsg = arg
	end
	if not chatMsg then
		return
	end
	ChatMessage.PrintUserRaw(Theme.GetColor("BLIZZARD_YELLOW"):ColorText(chatMsg))
end

function private.GetAuctionSoldMessage(msg)
	local link = private.settings.auctionMessages[msg]
	local price = nil
	if link then
		price = tremove(private.settings.auctionPrices[link], 1)
		if #private.settings.auctionPrices[link] == 0 then
			-- This was the last auction
			private.settings.auctionMessages[msg] = nil
		end
	else
		link = msg
	end
	SoundAlert.Play(private.settings.auctionSaleSound)
	if price then
		return format(L["Your auction of %s has sold for %s!"], link, Money.ToStringForAH(price, "|cffffffff"))
	else
		return format(L["Your auction of %s has sold!"], link)
	end
end

function private.GetAuctionWonMessage(forceQuantity)
	local link, _, quantity, buyout = private.GetLastPurchase()
	if not link or not buyout then
		return nil
	end
	return format(L["You won an auction for %sx%d for %s"], link, forceQuantity or quantity, Money.ToStringForAH(buyout, "|cffffffff"))
end

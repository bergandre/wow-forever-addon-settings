-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local PendingMail = LibTSMService:InitInternal("Mail.PendingMail")
local Scanner = LibTSMService:Include("Mail.Scanner")
local Util = LibTSMService:Include("Mail.Util")
local Auction = LibTSMService:Include("Auction")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	pendingMailStorage = nil, ---@type table<string,table<string,number>>
	characterValidationFunc = nil,
	cancelAuctionQuery = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param pendingMailData table<string,table<string,number>> Pending mail item quantities by character
---@param characterValidationFunc fun(character: string): string? Function used to validate character names for tracking pending mail
function PendingMail.Load(pendingMailData, characterValidationFunc)
	private.pendingMailStorage = pendingMailData
	private.characterValidationFunc = characterValidationFunc

	-- Sanitize the pending mail data
	for character, characterData in pairs(pendingMailData) do
		if characterData.items then
			Log.Info("Converting pending mail data for %s", character)
			pendingMailData[character] = characterData.items
			characterData = characterData.items --[[@as table<string,number>]]
		end
		for levelItemString, quantity in pairs(characterData) do
			if quantity <= 0 then
				characterData[levelItemString] = nil
			end
		end
	end

	-- Initialize for the current character
	local playerName = SessionInfo.GetCharacterName()
	pendingMailData[playerName] = pendingMailData[playerName] or {}

	-- Insert pending mail into the quantity DB
	Scanner.InsertPendingMail(pendingMailData[playerName])
end

---Starts the pending mail code.
function PendingMail.Start()
	Scanner.RegisterMailCallback(private.HandleMailCallback)

	-- Handle auction canceling
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		AuctionHouse.SecureHookCancel(function(index)
			local _, link, _, _, stackSize = AuctionHouse.GetOwnedInfo(index)
			local itemString = link and ItemString.Get(link) or nil
			-- For some reason, these APIs don't always work properly, so check the return values
			if not itemString or not stackSize or stackSize == 0 then
				return
			end
			private.ChangePendingMailQuantity(ItemString.ToLevel(itemString), stackSize)
		end)
	else
		private.cancelAuctionQuery = Auction.NewIndexQuery()
			:Equal("auctionId", Database.BoundQueryParam())
		AuctionHouse.SecureHookCancel(function(auctionId)
			private.cancelAuctionQuery:BindParams(auctionId)
			for _, levelItemString, stackSize in private.cancelAuctionQuery:Iterator("levelItemString", "stackSize") do
				private.ChangePendingMailQuantity(levelItemString, stackSize)
			end
		end)
	end

	-- Handle auction buying (handled via PendingMail.HandleAuctionPurchase() for retail)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		AuctionHouse.SecureHookPurchase(function(itemLink, quantity)
			local itemString = itemLink and ItemString.Get(itemLink) or nil
			if not itemString then
				return
			end
			private.ChangePendingMailQuantity(ItemString.ToLevel(itemString), quantity)
		end)
	end

	-- Handle sending mail to alts
	Inbox.SecureHookSendMail(function(target)
		local character = private.characterValidationFunc(target)
		if not character then
			return
		end
		private.pendingMailStorage[character] = private.pendingMailStorage[character] or {}
		local altPendingMail = private.pendingMailStorage[character]
		for i = 1, Inbox.GetMaxSendAttachments() do
			local itemLink, quantity = Inbox.GetSendAttachment(i)
			local itemString = itemLink and ItemString.Get(itemLink) or nil
			if itemString and quantity then
				local levelItemString = ItemString.ToLevel(itemString)
				altPendingMail[levelItemString] = (altPendingMail[levelItemString] or 0) + quantity
			end
		end
	end)

	-- Handle returning mail to alts
	Inbox.SecureHookReturnMail(function(index)
		local sender = Inbox.GetHeaderInfo(index)
		local character = sender and private.characterValidationFunc(sender) or nil
		if not character then
			return
		end
		private.pendingMailStorage[character] = private.pendingMailStorage[character] or {}
		local altPendingMail = private.pendingMailStorage[character]
		for i = 1, Inbox.GetMaxSendAttachments() do
			local itemLink, quantity = Util.GetAttachment(index, i)
			local itemString = itemLink and ItemString.Get(itemLink) or nil
			if itemString then
				local levelItemString = ItemString.ToLevel(itemString)
				altPendingMail[levelItemString] = (altPendingMail[levelItemString] or 0) + quantity
			end
		end
	end)
end

---Handles an auction purchase.
---@param levelItemString string The level item string
---@param stackSize number The stack size
function PendingMail.HandleAuctionPurchase(levelItemString, stackSize)
	if LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() then
		-- Auction buys handled via a secure hook
		return
	end
	private.ChangePendingMailQuantity(levelItemString, stackSize)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleMailCallback()
	wipe(private.pendingMailStorage[SessionInfo.GetCharacterName()])
end

function private.ChangePendingMailQuantity(levelItemString, changeQuantity)
	assert(changeQuantity ~= 0)
	local playerName = SessionInfo.GetCharacterName()
	private.pendingMailStorage[playerName][levelItemString] = (private.pendingMailStorage[playerName][levelItemString] or 0) + changeQuantity
	Scanner.HandlePendingMailChange(levelItemString, changeQuantity)
end

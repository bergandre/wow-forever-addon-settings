-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Auctioning = LibTSMApp:InitInternal("Banking.Auctioning")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local Banking = LibTSMApp:From("LibTSMService"):Include("Banking")
local private = {
	settingsDB = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Banking, function(db)
	private.settingsDB = db
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Moves items from the specified groups to the bags based on the post cap.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Auctioning.PostCapToBags(groups, callback)
	Banking.WithdrawGroupItems(groups, callback, private.GetNumToMoveToBagsPostCap)
end

---Moves items from the specified groups to the bags based on the auction shortfall.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Auctioning.ShortfallToBags(groups, callback)
	Banking.WithdrawGroupItems(groups, callback, private.GetNumToMoveToBagsShortfall)
end

---Moves items from the specified groups to the bank which have reached their max expires.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Auctioning.MaxExpiresToBank(groups, callback)
	Banking.DepositGroupItems(groups, callback, private.MaxExpiresGetNumToMoveToBank)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetNumToMoveToBagsPostCap(itemString, numHave)
	return private.GetNumToMoveToBags(itemString, numHave, false)
end

function private.GetNumToMoveToBagsShortfall(itemString, numHave)
	return private.GetNumToMoveToBags(itemString, numHave, true)
end

function private.GetNumToMoveToBags(itemString, numHave, includeAH)
	local numAvailable = numHave
	local numInBags = BagTracking.CreateQueryBagsItem(itemString)
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Sum("quantity")
	if includeAH then
		numInBags = numInBags + Auction.GetQuantity(itemString) + Mail.GetQuantity(itemString)
		-- Include alt auctions on connected realms
		local isCommodity = ItemInfo.IsCommodity(itemString)
		for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not isCommodity) do
			for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
				numInBags = numInBags + AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
			end
		end
	end
	local moveQuantity = AuctioningOperation.GetTotalPostQuantity(itemString)
	moveQuantity = max(moveQuantity - numInBags, 0)
	return min(numAvailable, moveQuantity)
end

function private.MaxExpiresGetNumToMoveToBank(itemString, numHave)
	if not AuctioningOperation.HasReachedMaxExpires(itemString) then
		return 0
	end
	local numToKeepInBags = AuctioningOperation.GetTotalPostQuantity(itemString)
	return max(numHave - numToKeepInBags, 0)
end

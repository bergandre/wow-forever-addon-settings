-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Banking = LibTSMApp:Init("Banking")
local Auctioning = LibTSMApp:Include("Banking.Auctioning")
local Mailing = LibTSMApp:Include("Banking.Mailing")
local Warehousing = LibTSMApp:Include("Banking.Warehousing")
local BankingService = LibTSMApp:From("LibTSMService"):Include("Banking")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Moves groups to the open bank.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveGroupsToBank(groups, callback)
	BankingService.DepositGroupItems(groups, callback)
end

---Moves items from the specified groups to the bags based on the Auctioning operation post cap.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveAuctioningPostCapToBags(groups, callback)
	Auctioning.PostCapToBags(groups, callback)
end

---Moves items from the specified groups to the bags based on the Auctioning operation shortfall.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveAuctioningShortfallToBags(groups, callback)
	Auctioning.ShortfallToBags(groups, callback)
end

---Moves items from the specified groups to the bank which have reached their Auctioning operation max expires.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveAuctioningMaxExpiresToBank(groups, callback)
	Auctioning.MaxExpiresToBank(groups, callback)
end

---Moves items which don't have an operation to the open bank.
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveMailingNonGroupToBank(callback)
	Mailing.NonGroupToBank(callback)
end

---Moves items from the specified groups to the bags based on the target shortfall.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveMailingTargetShortfallToBags(groups, callback)
	Mailing.TargetShortfallToBags(groups, callback)
end

---Moves groups to the open bank based on the Warehousing operation settings.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveWarehousingGroupsToBank(groups, callback)
	Warehousing.MoveGroupsToBank(groups, callback)
end

---Moves groups to the bags based on the Warehousing operation settings.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveWarehousingGroupsToBags(groups, callback)
	Warehousing.MoveGroupsToBags(groups, callback)
end

---Restock the bags for the specified groups based on the Warehousing operation settings.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Banking.MoveWarehousingRestockBags(groups, callback)
	Warehousing.RestockBags(groups, callback)
end

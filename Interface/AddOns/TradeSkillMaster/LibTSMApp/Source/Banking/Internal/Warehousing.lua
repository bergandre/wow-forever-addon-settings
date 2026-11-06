-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Warehousing = LibTSMApp:InitInternal("Banking.Warehousing")
local WarehousingOperation = LibTSMApp:From("LibTSMSystem"):Include("WarehousingOperation")
local Banking = LibTSMApp:From("LibTSMService"):Include("Banking")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Moves groups to the open bank based on the Warehousing operation settings.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Warehousing.MoveGroupsToBank(groups, callback)
	Banking.DepositGroupItems(groups, callback, WarehousingOperation.GetNumToMoveToBank)
end

---Moves groups to the bags based on the Warehousing operation settings.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Warehousing.MoveGroupsToBags(groups, callback)
	Banking.WithdrawGroupItems(groups, callback, WarehousingOperation.GetNumToMoveToBags)
end

---Restock the bags for the specified groups based on the Warehousing operation settings.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Warehousing.RestockBags(groups, callback)
	Banking.WithdrawGroupItems(groups, callback, WarehousingOperation.GetNumToMoveRestock)
end

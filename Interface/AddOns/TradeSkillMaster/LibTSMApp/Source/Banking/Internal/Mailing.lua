-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Mailing = LibTSMApp:InitInternal("Banking.Mailing")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMApp:From("LibTSMTypes"):Include("GroupOperation")
local MailingOperation = LibTSMApp:From("LibTSMSystem"):Include("MailingOperation")
local Banking = LibTSMApp:From("LibTSMService"):Include("Banking")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Moves items which don't have an operation to the open bank.
---@param callback BankingMoveCallback The banking move callback
function Mailing.NonGroupToBank(callback)
	Banking.DepositItemsWithFunc(callback, private.NonGroupGetNumToBank)
end

---Moves items from the specified groups to the bags based on the target shortfall.
---@param groups table<string,boolean> The set of groups to include
---@param callback BankingMoveCallback The banking move callback
function Mailing.TargetShortfallToBags(groups, callback)
	Banking.WithdrawGroupItems(groups, callback, MailingOperation.TargetShortfallGetNumToBags)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NonGroupGetNumToBank(itemString, numHave)
	return GroupOperation.HasAnyNonIgnoredOperation(Group.GetPathByItem(itemString), "Mailing") and 0 or numHave
end

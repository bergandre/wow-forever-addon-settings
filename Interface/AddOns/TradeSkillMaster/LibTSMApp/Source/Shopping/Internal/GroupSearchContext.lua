-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local AuctionSearchContext = LibTSMApp:From("LibTSMService"):IncludeClassType("AuctionSearchContext")
local GroupSearchContext = LibTSMApp:DefineInternalClassType("GroupSearchContext", AuctionSearchContext)



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

---@param search GroupSearch The group search object
---@param threadId string The thread ID for running the scan
---@param marketValueFunc fun(subRow: AuctionSubRow): number? The function for looking up the market value of an item
function GroupSearchContext:__init(search, threadId, marketValueFunc)
	self.__super:__init(threadId, marketValueFunc)
	self._search = search
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the max quantity of an item which can be bought.
---@param itemString string The item
---@return number?
function GroupSearchContext:GetMaxCanBuy(itemString)
	return self._search:GetMaxCanBuy(itemString)
end

---Handles an item being bought.
---@param itemString string The item string
---@param quantity number The number bought
function GroupSearchContext:OnBuy(itemString, quantity)
	self.__super:OnBuy(itemString, quantity)
	self._search:HandlePurchase(itemString, quantity)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local AuctionSearchContext = LibTSMApp:From("LibTSMService"):IncludeClassType("AuctionSearchContext")
local FilterSearchContext = LibTSMApp:DefineInternalClassType("FilterSearchContext", AuctionSearchContext)
local private = {}



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

---@param search FilterSearch The filter search object
---@param threadId string The thread ID for running the scan
---@param marketValueFunc fun(subRow: AuctionSubRow): number? The function for looking up the market value of an item
function FilterSearchContext:__init(search, threadId, marketValueFunc)
	self.__super:__init(threadId, marketValueFunc)
	self._search = search
	self._isGathering = nil
	self._isSpecial = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the scan context.
---@param name string The name of the scan
---@param filterInfo any
---@param postContext? AuctionPostContext The post context
---@param pctTooltip string The percent tooltip
---@param isGathering boolean Whether or not this is a gathering search
---@param isSpecial boolean Whether or not this is a special search which is not recorded as a recent saved search
---@return self
function FilterSearchContext:SetScanContext(name, filterInfo, postContext, pctTooltip, isGathering, isSpecial)
	self._isGathering = isGathering
	self._isSpecial = isSpecial
	self.__super:SetScanContext(name, filterInfo, postContext, pctTooltip)
	return self
end

---Gets the gathering results function.
---@return function?
function FilterSearchContext:GetGatheringResultsFunc()
	return self._isGathering and private.GatheringResultsFunction or nil
end

---Gets the max quantity of an item which can be bought.
---@param itemString string The item
---@return number?
function FilterSearchContext:GetMaxCanBuy(itemString)
	return self._search:GetMaxCanBuy(itemString)
end

---Handles an item being bought.
---@param itemString string The item string
---@param quantity number The number bought
function FilterSearchContext:OnBuy(itemString, quantity)
	self._search:HandlePurchase(itemString, quantity)
	self.__super:OnBuy(itemString, quantity)
end

---Returns whether or not this is a special search which shouldn't be recorded as a recent saved search.
---@return boolean
function FilterSearchContext:IsSpecial()
	return self._isSpecial
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GatheringResultsFunction(auctionScan, marketValueFunc, itemString, quantity, maxQuantity)
	local filterQuantity = 0
	for _, query in auctionScan:QueryIterator() do
		for _, subRow in query:ItemSubRowIterator(itemString) do
			local _, itemBuyout = subRow:GetBuyouts()
			if marketValueFunc(subRow) >= itemBuyout then
				local _, numOwnerItems = subRow:GetOwnerInfo()
				local quantityAvailable = subRow:GetQuantities() - numOwnerItems
				filterQuantity = filterQuantity + quantityAvailable
			end
		end
	end
	return filterQuantity > 0 and min(filterQuantity, quantity, maxQuantity) or min(quantity, maxQuantity)
end

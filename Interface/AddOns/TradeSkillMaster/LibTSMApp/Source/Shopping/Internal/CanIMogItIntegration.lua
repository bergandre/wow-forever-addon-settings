-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local CanIMogItIntegration = LibTSMApp:InitInternal("Shopping.CanIMogItIntegration")
local ItemFilter = LibTSMApp:From("LibTSMService"):IncludeClassType("ItemFilter")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
	hasUnlearnedFilter = false,
	hasCanLearnFilter = false,
}
local UNLEARNED_FILTER_PART = "unlearned"
local CAN_LEARN_FILTER_PART = "canlearn"



-- ============================================================================
-- Module Loading
-- ============================================================================

CanIMogItIntegration:OnModuleLoad(function()
	-- CanIMogIt integration
	if CanIMogIt and CanIMogIt.PlayerKnowsTransmog then
		ItemFilter.AddKeyMatchPart(UNLEARNED_FILTER_PART, function(item)
			return CanIMogIt:PlayerKnowsTransmog(ItemInfo.GetLink(item))
		end)
		private.hasUnlearnedFilter = true
	end
	if CanIMogIt and CanIMogIt.CharacterCanLearnTransmog then
		ItemFilter.AddKeyMatchPart(CAN_LEARN_FILTER_PART, function(item)
			return CanIMogIt:CharacterCanLearnTransmog(ItemInfo.GetLink(item))
		end)
		private.hasCanLearnFilter = true
	end
end)



-- ============================================================================
-- Module Loading
-- ============================================================================

---Populates a query with fields from the item filter.
---@param query AuctionQuery The query to populate
---@param itemFilter ItemFilter The item filter
function CanIMogItIntegration.PopulateAuctionQuery(query, itemFilter)
	if private.hasUnlearnedFilter then
		query:SetUnlearned(itemFilter:GetAddedKeyValue(UNLEARNED_FILTER_PART))
	end
	if private.hasCanLearnFilter then
		query:SetCanLearn(itemFilter:GetAddedKeyValue(CAN_LEARN_FILTER_PART))
	end
end

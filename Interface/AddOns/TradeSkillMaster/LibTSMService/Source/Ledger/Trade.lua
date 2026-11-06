-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Trade = LibTSMService:Init("Ledger.Trade")
local TradeAPI = LibTSMService:From("LibTSMWoW"):Include("API.Trade")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local private = {
	tradeHandler = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Trade:OnModuleLoad(function()
	TradeAPI.RegisterTradeCompleteCallback(private.OnTradeComplete)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the trade code.
---@param tradeHandler fun(tradeType: LedgerTransactionType, itemString: string, money: number, count: number, target: string) The trade handler function
function Trade.Configure(tradeHandler)
	assert(not private.tradeHandler and tradeHandler)
	private.tradeHandler = tradeHandler
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnTradeComplete(playerMoney, playerItems, target, targetMoney, targetItems)
	-- Trade went through
	local tradeType, itemString, count, money = nil, nil, nil, nil
	if playerMoney > 0 and not next(playerItems) and targetMoney == 0 and next(targetItems) then
		-- Player bought items
		for itemLink, itemCount in pairs(targetItems) do
			local targetItemString = ItemString.Get(itemLink)
			if not itemString then
				itemString = targetItemString
				count = itemCount
			elseif itemString == targetItemString then
				count = itemCount
			else
				return
			end
		end
		tradeType = "buy"
		money = playerMoney
	elseif playerMoney == 0 and next(playerItems) and targetMoney > 0 and not next(targetItems) then
		-- Player sold items
		for itemLink, itemCount in pairs(playerItems) do
			local playerItemString = ItemString.Get(itemLink)
			if not itemString then
				itemString = playerItemString
				count = itemCount
			elseif itemString == playerItemString then
				count = count + itemCount
			else
				return
			end
		end
		tradeType = "sale"
		money = targetMoney
	end
	if not tradeType or not itemString or not count then
		return
	end
	private.tradeHandler(tradeType, itemString, money, count, target)
end

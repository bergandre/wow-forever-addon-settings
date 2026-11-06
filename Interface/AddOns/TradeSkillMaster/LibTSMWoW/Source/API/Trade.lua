-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Trade = LibTSMWoW:Init("API.Trade")
local Event = LibTSMWoW:Include("Service.Event")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local private = {
	info = {
		playerItems = {},
		targetItems = {},
		playerMoney = 0,
		targetMoney = 0,
		isValid = false,
	},
	completeCallbacks = CallbackRegistry.NewList(),
}
local NUM_ITEM_SLOTS = 6
local ENCHANT_ITEM_SLOT = 7



-- ============================================================================
-- Module Loading
-- ============================================================================

Trade:OnModuleLoad(function()
	Event.Register("TRADE_ACCEPT_UPDATE", private.OnAcceptUpdate)
	Event.Register("UI_INFO_MESSAGE", private.OnChatMsg)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for when a trade is completed.
---@param callback fun(playerMoney: number, playerItems: table<string,number>, target: string, targetMoney: number, targetItems: table<string,number>)
function Trade.RegisterTradeCompleteCallback(callback)
	private.completeCallbacks:Add(callback)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnAcceptUpdate(_, player, target)
	if (player == 1 or target == 1) and not GetTradePlayerItemLink(ENCHANT_ITEM_SLOT) and not GetTradeTargetItemLink(ENCHANT_ITEM_SLOT) then
		-- Update info
		private.info.isValid = true
		private.info.playerMoney = tonumber(GetPlayerTradeMoney()) or 0
		private.info.targetMoney = tonumber(GetTargetTradeMoney()) or 0
		private.info.target = UnitName("NPC")

		wipe(private.info.playerItems)
		wipe(private.info.targetItems)
		for i = 1, NUM_ITEM_SLOTS do
			local targetItemLink = GetTradeTargetItemLink(i)
			local _, _, targetCount = GetTradeTargetItemInfo(i)
			if targetItemLink then
				private.info.targetItems[targetItemLink] = (private.info.targetItems[targetItemLink] or 0) + targetCount
			end

			local playerItemLink = GetTradePlayerItemLink(i)
			local _, _, playerCount = GetTradePlayerItemInfo(i)
			if playerItemLink then
				private.info.playerItems[playerItemLink] = (private.info.playerItems[playerItemLink] or 0) + playerCount
			end
		end
	else
		private.info.isValid = false
	end
end

function private.OnChatMsg(_, msg)
	if msg ~= LE_GAME_ERR_TRADE_COMPLETE or not private.info.isValid then
		return
	end
	private.completeCallbacks:CallAll(private.info.playerMoney, private.info.playerItems, private.info.target, private.info.targetMoney, private.info.targetItems)
end

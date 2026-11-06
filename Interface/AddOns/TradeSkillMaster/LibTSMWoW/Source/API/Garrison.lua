-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Garrison = LibTSMWoW:Init("API.Garrison")
local Event = LibTSMWoW:Include("Service.Event")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local private = {
	moneyAwardCallbacks = CallbackRegistry.NewList(),
}
local GOLD_TRAIT_ID = 256 -- traitId for the treasure hunter trait which increases gold from missions

---@class MissionInfoExtended: MissionInfo
---@field overMaxRewards number



-- ============================================================================
-- Module Loading
-- ============================================================================

Garrison:OnModuleLoad(function()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		Event.Register("GARRISON_MISSION_COMPLETE_RESPONSE", private.MissionComplete)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback when missions are completed with a money award.
---@param callback fun(amount: number) The callback function
function Garrison.RegisterMoneyAwardCallback(callback)
	assert(LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	private.moneyAwardCallbacks:Add(callback)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MissionComplete(_, missionId)
	local info = C_Garrison.GetBasicMissionInfo(missionId) --[[@as MissionInfoExtended?]]
	if not info then
		return
	end

	local moneyAward = 0
	for _, reward in pairs(info.rewards) do
		if reward.title == GARRISON_REWARD_MONEY and reward.currencyID == 0 then
			moneyAward = moneyAward + reward.quantity
		end
	end
	if moneyAward == 0 then
		return
	end

	-- Check for followers which give bonus gold
	local multiplier = 1
	for _, followerId in ipairs(info.followers) do
		for _, trait in ipairs(C_Garrison.GetFollowerAbilities(followerId)) do
			if trait.id == GOLD_TRAIT_ID then
				multiplier = multiplier + 1
			end
		end
	end
	moneyAward = moneyAward * multiplier

	private.moneyAwardCallbacks:CallAll(moneyAward)
end

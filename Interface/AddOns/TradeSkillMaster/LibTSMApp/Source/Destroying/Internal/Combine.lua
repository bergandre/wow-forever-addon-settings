-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Combine = LibTSMApp:InitInternal("Destroying.Combine")
local BagDB = LibTSMApp:Include("Destroying.BagDB")
local Future = LibTSMApp:From("LibTSMUtil"):IncludeClassType("Future")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local Container = LibTSMApp:From("LibTSMWoW"):Include("API.Container")
local private = {
	combineThread = nil,
	combineFuture = Future.New("DESTROYING_COMBINE_FUTURE"), ---@type Future<boolean>
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Combine:OnModuleLoad(function()
	private.combineThread = Threading.New("COMBINE_STACKS", private.CombineThread)
	Threading.SetCallback(private.combineThread, private.CombineThreadDone)

	private.combineFuture:SetScript("OnCleanup", function()
		Threading.Kill(private.combineThread)
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts combining any available stacks.
---@return Future
function Combine.Start()
	private.combineFuture:Start()
	Threading.Start(private.combineThread)
	return private.combineFuture
end



-- ============================================================================
-- Combine Stacks Thread
-- ============================================================================

function private.CombineThread()
	while true do
		local didCombine = false
		for _, sourceSlotId, targetSlotId in BagDB.PendingCombineIterator() do
			Container.PickupItem(sourceSlotId)
			Container.PickupItem(targetSlotId)
			didCombine = true
		end
		if not didCombine then
			return
		end
		-- Wait for the bagDB to change
		BagDB.WaitForUpdateThreaded()
	end
end

function private.CombineThreadDone(result)
	private.combineFuture:Done(result)
end

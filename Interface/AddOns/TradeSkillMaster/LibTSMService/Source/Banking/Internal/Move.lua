-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Move = LibTSMService:InitInternal("Banking.Move")
local OpenFrame = LibTSMService:Include("Banking.OpenFrame")
local Util = LibTSMService:Include("Banking.Util")
local MoveContext = LibTSMService:IncludeClassType("MoveContext")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local Guild = LibTSMService:From("LibTSMWoW"):Include("API.Guild")
local private = {
	moveThread = nil,
	moveContext = MoveContext(),
}
local MOVE_WAIT_TIMEOUT = 2

---@alias BankingMoveCallback fun(event: "MOVED"|"PROGRESS"|"DONE", ...)



-- ============================================================================
-- Module Loading
-- ============================================================================

Move:OnModuleLoad(function()
	private.moveThread = Threading.New("BANKING_MOVE", private.MoveThread)
	OpenFrame.RegisterCallback(function(frame)
		if not frame then
			Move.Stop()
		end
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts a move.
---@param source EnumValue The frame to move from
---@param target EnumValue The frame to move to
---@param items table<string,number> The items to move
---@param callback BankingMoveCallback A callback function which gets various events
function Move.Start(source, target, items, callback)
	Move.Stop()
	private.moveContext:Configure(source, target, items)
	Threading.Start(private.moveThread, private.moveContext, callback)
end

---Stops any in progress move.
function Move.Stop()
	private.moveContext:Reset()
	Threading.Kill(private.moveThread)
end



-- ============================================================================
-- Thread
-- ============================================================================

---@param context MoveContext
---@param callback BankingMoveCallback
function private.MoveThread(context, callback)
	-- Prepare for moving
	context:PopulateEmptySlots()
	Threading.Yield()
	local numMoves = context:CalculateMoves()
	Threading.Yield()

	local numDone = 0
	while context:HasPendingSlot() do
		-- Do some moves
		context:DoMoveThreaded()

		-- Wait for at least one to finish or the timeout to elapse
		local didMove = false
		local timeout = LibTSMService.GetTime() + MOVE_WAIT_TIMEOUT
		while not didMove and LibTSMService.GetTime() < timeout do
			-- Check for any moves that are done
			local slotId, itemString, quantity = context:CheckForDoneSlotsThreaded()
			if slotId then
				didMove = true
				numDone = numDone + 1
				callback("MOVED", itemString, quantity)
				callback("PROGRESS", numDone / numMoves)
			end
			Threading.Yield(true)
		end
	end

	if OpenFrame.Get() == Util.FRAME.GUILD_BANK then
		Guild.QueryTab(Guild.GetCurrentTab())
	end
	context:Reset()
	callback("DONE")
end

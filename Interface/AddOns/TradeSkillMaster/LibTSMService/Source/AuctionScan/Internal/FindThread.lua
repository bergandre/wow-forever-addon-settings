-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local FindThread = LibTSMService:InitInternal("AuctionScan.FindThread")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local private = {
	threadId = nil,
	startTimer = nil,
	isRunning = false,
	auctionScan = nil, ---@type AuctionScanManager?
	startArgs = {
		auctionScan = nil,
		auction = nil,
		callback = nil,
		noSeller = nil,
	},
	callback = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

FindThread:OnModuleLoad(function()
	-- Initialize threads
	private.threadId = Threading.New("AUCTION_SCAN_FIND", private.FindThread)
	Threading.SetCallback(private.threadId, private.ThreadCallback)
	private.startTimer = DelayTimer.New("AUCTION_SCAN_FIND_START", private.StartThread)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts the find thread.
---@param auctionScan AuctionScanManager The auction scan
---@param auction AuctionSubRow The sub row to find
---@param callback fun(...: any) The result callback
---@param noSeller boolean Ignore seller names
function FindThread.StartFindAuction(auctionScan, auction, callback, noSeller)
	FindThread.StopFindAuction(false)
	private.startArgs.auctionScan = auctionScan
	private.startArgs.auction = auction
	private.startArgs.callback = callback
	private.startArgs.noSeller = noSeller
	private.startTimer:RunForTime(0)
end

---Stops any in-progress find thread.
---@param noKill boolean Don't kill the thread
function FindThread.StopFindAuction(noKill)
	wipe(private.startArgs)
	private.callback = nil
	if not noKill then
		Threading.Kill(private.threadId)
		if private.auctionScan then
			private.auctionScan:_HandleFindThreadKilled() ---@diagnostic disable-line: invisible
		end
		private.isRunning = false
		private.auctionScan = nil
	end
end

---Stops the find thread if it's running or pending for the specified auction scan.
---@param auctionScan AuctionScanManager The auction scan
function FindThread.StopForAuctionScan(auctionScan)
	if private.auctionScan ~= auctionScan and private.startArgs.auctionScan ~= auctionScan then
		return
	end
	FindThread.StopFindAuction(false)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param auctionScan AuctionScanManager
function private.FindThread(auctionScan, row, noSeller)
	return auctionScan:_FindAuctionThreaded(row, noSeller) ---@diagnostic disable-line: invisible
end

function private.StartThread()
	if not private.startArgs.auctionScan then
		return
	end
	if private.isRunning then
		private.startTimer:RunForTime(0.1)
		return
	end
	private.isRunning = true
	private.auctionScan = private.startArgs.auctionScan
	private.callback = private.startArgs.callback
	Threading.Start(private.threadId, private.startArgs.auctionScan, private.startArgs.auction, private.startArgs.noSeller)
	wipe(private.startArgs)
end

function private.ThreadCallback(...)
	private.isRunning = false
	private.auctionScan = nil
	if private.callback then
		private.callback(...)
	end
end

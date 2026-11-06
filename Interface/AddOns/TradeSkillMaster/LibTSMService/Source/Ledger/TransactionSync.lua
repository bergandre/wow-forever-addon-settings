-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local TransactionSync = LibTSMService:Init("Ledger.TransactionSync")
local Transactions = LibTSMService:Include("Ledger.Transactions")
local Sync = LibTSMService:Include("Sync")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local private = {
	accountLookup = {},
	accountStatus = {},
	pendingChunks = {},
	dataTemp = {},
	changeTimer = nil,
	hashesRetryTimer = nil
}
local STATUS = EnumType.New("LEDGER_DATA_SYNC_STATUS", {
	NOT_CONNECTED = EnumType.NewValue(),
	UPDATING = EnumType.NewValue(),
	RETRY = EnumType.NewValue(),
	SYNCED = EnumType.NewValue(),
})
TransactionSync.STATUS = STATUS
local CHANGE_NOTIFICATION_DELAY = 5
local RETRY_DELAY = 5



-- ============================================================================
-- Module Loading
-- ============================================================================

TransactionSync:OnModuleLoad(function()
	private.changeTimer = DelayTimer.New("ACCOUNTING_SYNC_CHANGE", private.NotifyChange)
	private.hashesRetryTimer = DelayTimer.New("ACCOUNTING_SYNC_HASHES_RETRY", private.RetryGetPlayerHashRPC)
	Sync.RegisterConnectionChangedCallback(private.ConnectionChangedHandler)
	Sync.RegisterRPC("ACCOUNTING_GET_PLAYER_HASH", private.RPCGetPlayerHash)
	Sync.RegisterRPC("ACCOUNTING_GET_PLAYER_CHUNKS", private.RPCGetPlayerChunks)
	Sync.RegisterRPC("ACCOUNTING_GET_PLAYER_DATA", private.RPCGetData)
	Sync.RegisterRPC("ACCOUNTING_CHANGE_NOTIFICATION", private.RPCChangeNotification)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function TransactionSync.GetStatus(account)
	return private.accountStatus[account] or STATUS.NOT_CONNECTED
end

function TransactionSync.OnTransactionsChanged()
	private.changeTimer:RunForTime(CHANGE_NOTIFICATION_DELAY)
end



-- ============================================================================
-- RPC Functions and Result Handlers
-- ============================================================================

function private.GetPlayerHash(player)
	local account = private.accountLookup[player]
	private.accountStatus[account] = STATUS.UPDATING
	Transactions.PrepareSyncHashes(player)
	Sync.CallRPC("ACCOUNTING_GET_PLAYER_HASH", player, private.RPCGetPlayerHashResultHandler)
end

function private.RPCGetPlayerHash()
	return Transactions.GetSyncHash(SessionInfo.GetCharacterName())
end

function private.RPCGetPlayerHashResultHandler(success, player, hash)
	local account = private.HandleRPCResult("GET_PLAYER_HASH", success, player)
	if not account then
		return
	elseif not hash then
		-- The hash isn't ready yet, so try again
		Log.Warn("Sync player hash not ready yet (%s)", player)
		private.RestartForAccount(account)
		return
	end

	local currentHash = Transactions.GetSyncHash(player)
	if not currentHash then
		-- Don't have our hash yet, so try again
		Log.Warn("Current player hash not ready yet (%s)", player)
		private.RestartForAccount(account)
		return
	end

	if hash ~= currentHash then
		Log.Info("Need updated transactions data from %s (%s, %s)", player, hash, currentHash)
		private.GetPlayerChunks(player)
	else
		Log.Info("Transactions data for %s already up to date (%s, %s)", player, hash, currentHash)
		private.accountStatus[account] = STATUS.SYNCED
	end
end

function private.GetPlayerChunks(player)
	local account = private.accountLookup[player]
	private.accountStatus[account] = STATUS.UPDATING
	Sync.CallRPC("ACCOUNTING_GET_PLAYER_CHUNKS", player, private.RPCGetPlayerChunksResultHandler)
end

function private.RPCGetPlayerChunks()
	return Transactions.GetSyncHashByDay(SessionInfo.GetCharacterName())
end

function private.RPCGetPlayerChunksResultHandler(success, player, chunks)
	local account = private.HandleRPCResult("GET_PLAYER_CHUNKS", success, player)
	if not account then
		return
	elseif not chunks then
		-- The hashes have been invalidated, so try again from the start
		Log.Warn("Sync player chunks not ready yet (%s)", player)
		private.RestartForAccount(account)
		return
	end

	local currentChunks = Transactions.GetSyncHashByDay(player)
	if not currentChunks then
		-- Our hashes have been invalidated, so try again from the start
		Log.Warn("Local hashes are invalid (%s)", player)
		private.RestartForAccount(account)
		return
	end
	for day in pairs(currentChunks) do
		if not chunks[day] then
			-- Remove day which no longer exists
			Transactions.RemovePlayerDay(player, day)
		end
	end

	-- Queue up all the pending chunks
	private.pendingChunks[player] = private.pendingChunks[player] or TempTable.Acquire()
	wipe(private.pendingChunks[player])
	for day, hash in pairs(chunks) do
		if currentChunks[day] ~= hash then
			tinsert(private.pendingChunks[player], day)
		end
	end

	local requestDay = private.GetNextPendingChunk(player)
	if requestDay then
		Log.Info("Requesting transactions data (%s, %s, %s, %s)", player, requestDay, tostring(currentChunks[requestDay]), chunks[requestDay])
		private.GetPlayerData(player, requestDay)
	else
		Log.Info("All chunks are up to date (%s)", player)
		private.accountStatus[account] = STATUS.SYNCED
	end
end

function private.GetPlayerData(player, requestDay)
	local account = private.accountLookup[player]
	private.accountStatus[account] = STATUS.UPDATING
	Sync.CallRPC("ACCOUNTING_GET_PLAYER_DATA", player, private.RPCGetPlayerDataResultHandler, requestDay)
end

function private.RPCGetData(day)
	wipe(private.dataTemp)
	Transactions.GetSyncData(SessionInfo.GetCharacterName(), day, private.dataTemp)
	return day, private.dataTemp
end

function private.RPCGetPlayerDataResultHandler(success, player, day, data)
	local account = private.HandleRPCResult("GET_PLAYER_DATA", success, player)
	if not account then
		return
	elseif #data % 9 ~= 0 then
		-- Invalid data - just silently give up
		Log.Err("Got invalid transactions data")
		return
	end

	Log.Info("Received transactions data (%s, %s, %s)", player, day, #data)
	Transactions.HandleSyncedData(player, day, data)

	local requestDay = private.GetNextPendingChunk(player)
	if requestDay then
		-- Request the next chunk
		Log.Info("Requesting transactions data (%s, %s)", player, requestDay)
		private.GetPlayerData(player, requestDay)
	else
		-- Request chunks again to check for other chunks we need to sync
		private.GetPlayerChunks(player)
	end
end

function private.RPCChangeNotification(player)
	if private.accountStatus[private.accountLookup[player]] == STATUS.SYNCED then
		-- Request the player hash
		Log.Info("Got change notification - requesting player hash")
		private.GetPlayerHash(player)
	else
		Log.Info("Got change notification - dropping (%s)", player)
	end
end

function private.RPCChangeNotificationResultHandler()
	-- nop
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ConnectionChangedHandler(account, player, connected)
	if connected then
		private.accountLookup[player] = account
		private.GetPlayerHash(player)
	else
		private.accountLookup[player] = nil
		private.accountStatus[account] = nil
		if private.pendingChunks[player] then
			TempTable.Release(private.pendingChunks[player])
			private.pendingChunks[player] = nil
		end
	end
end

function private.GetNextPendingChunk(player)
	if not private.pendingChunks[player] then
		return nil
	end
	local result = tremove(private.pendingChunks[player])
	if not result then
		TempTable.Release(private.pendingChunks[player])
		private.pendingChunks[player] = nil
	end
	return result
end

function private.RetryGetPlayerHashRPC()
	for player, account in pairs(private.accountLookup) do
		if private.accountStatus[account] == STATUS.RETRY then
			private.GetPlayerHash(player)
		end
	end
end

function private.NotifyChange()
	for player, account in pairs(private.accountLookup) do
		if private.accountStatus[account] == STATUS.SYNCED then
			-- Notify the other account that our data has changed and request the other account's latest hash ourselves
			private.GetPlayerHash(player)
			Sync.CallRPC("ACCOUNTING_CHANGE_NOTIFICATION", player, private.RPCChangeNotificationResultHandler, SessionInfo.GetCharacterName())
		end
	end
end

function private.HandleRPCResult(tag, success, player)
	local account = private.accountLookup[player]
	if not account then
		if success then
			Log.Warn("Got RPC (%s) response but player (%s) is no longer connected", tag, player)
		else
			Log.Info("RPC (%s) failed and player (%s) is no longer connected", tag, player)
		end
		return nil
	elseif not success then
		-- Request timed out, so try again from the start
		Log.Warn("RPC (%s) timed out (%s)", tag, player)
		private.RestartForAccount(account)
		return nil
	end
	return account
end

function private.RestartForAccount(account)
	private.accountStatus[account] = STATUS.RETRY
	private.hashesRetryTimer:RunForTime(RETRY_DELAY)
end

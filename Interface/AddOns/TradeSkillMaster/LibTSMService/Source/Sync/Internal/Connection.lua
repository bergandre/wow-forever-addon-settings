-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Connection = LibTSMService:InitInternal("Sync.Connection")
local Comm = LibTSMService:Include("Sync.Comm")
local Constants = LibTSMService:Include("Sync.Constants")
local Presence = LibTSMService:Include("Sync.Presence")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local FriendList = LibTSMService:From("LibTSMWoW"):Include("API.FriendList")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	managementTimer = nil,
	newAccountTimer = nil,
	friendsInfoTimer = nil,
	localAccountKey = nil,
	accountIteratorFunc = nil,
	accessibleCharacterIterFunc = nil,
	newAccountHandler = nil,
	removeAccountHandler = nil,
	isActive = false,
	hasFriendsInfo = false,
	pendingFriendsUpdate = false,
	newFriendsUpdateTimeout = nil,
	newCharacter = nil,
	newAccount = nil,
	newSyncAcked = nil,
	connectionChangedCallbacks = CallbackRegistry.NewList(),
	threadId = {},
	threadRunning = {},
	threadTarget = {},
	connectedCharacter = {},
	lastHeartbeat = {},
	suppressThreadTime = {},
	connectionRequestReceived = {},
}
Connection.ERROR = EnumType.New("CONNECTION_ERROR", {
	NOT_READY = EnumType.NewValue(),
	CURRENT_CHARACTER = EnumType.NewValue(),
	NOT_ONLINE = EnumType.NewValue(),
	ALREADY_KNOWN = EnumType.NewValue(),
})
local RECEIVE_TIMEOUT = 5
local HEARTBEAT_TIMEOUT = 10
local NEW_FRIENDS_UPDATE_TIMEOUT = 5

---@alias AccessibleCharacterIterFunction fun(accountKeyFilter?: string): IteratorObject<fun(): number, string>



-- ============================================================================
-- Module Loading
-- ============================================================================

Connection:OnModuleLoad(function()
	private.managementTimer = DelayTimer.New("SYNC_CONNECTION_MANAGEMENT", private.ManagementLoop)
	private.newAccountTimer = DelayTimer.New("SYNC_CONNECTION_NEW_ACCOUNT", private.SendNewAccountWhoAmI)
	private.friendsInfoTimer = DelayTimer.New("SYNC_CONNECTION_FRIENDS_INFO", FriendList.Query)
end)

Connection:OnModuleUnload(function()
	for _, player in pairs(private.connectedCharacter) do
		private.DisconnectCharacter(player)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and starts the connection code.
---@param localAccountKey string The local account key
---@param accountIteratorFunc function Function which returns an iterator with fields: `index`, `accountKey`
---@param accessibleCharacterIterFunc AccessibleCharacterIterFunction Function which returns an iterator over the accessible characters
---@param newAccountHandler fun(accountKey: string, character: string) Handler for a new account being added
---@param removeAccountHandler fun(accountKey: string) Handler for an account being removed
function Connection.Load(localAccountKey, accountIteratorFunc, accessibleCharacterIterFunc, newAccountHandler, removeAccountHandler)
	private.localAccountKey = localAccountKey
	private.accountIteratorFunc = accountIteratorFunc
	private.accessibleCharacterIterFunc = accessibleCharacterIterFunc
	private.newAccountHandler = newAccountHandler
	private.removeAccountHandler = removeAccountHandler

	for _ in private.accountIteratorFunc() do
		private.isActive = true
	end

	Comm.SetDisconnectFunction(private.DisconnectCharacter)
	Comm.RegisterHandler(Constants.DATA_TYPES.WHOAMI_ACCOUNT, private.WhoAmIAccountHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.WHOAMI_ACK, private.WhoAmIAckHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CONNECTION_REQUEST, private.ConnectionRequestAndAckHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CONNECTION_REQUEST_ACK, private.ConnectionRequestAndAckHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.DISCONNECT, private.DisconnectHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.HEARTBEAT, private.HeartbeatHandler)

	Event.Register("FRIENDLIST_UPDATE", private.PrepareFriendsInfo)
	private.PrepareFriendsInfo()
end

---Registers a callback for when a connection changes.
---@param handler fun(accountKey: string, character: string, connected: boolean|nil)
function Connection.RegisterConnectionChangedCallback(handler)
	private.connectionChangedCallbacks:Add(handler)
end

---Returns if a character is connected or not.
---@param character string The character
---@return boolean
function Connection.IsCharacterConnected(character)
	return Table.KeyByValue(private.connectedCharacter, character) ~= nil
end

---Iterates over the connected accounts.
---@return fun(): string, string @Iterator with fields: `accountKey`, `character`
---@return table
function Connection.ConnectedAccountIterator()
	return pairs(private.connectedCharacter)
end

---Establishes a new connection.
---@param targetCharacter string The character to connect to
---@return boolean isConnecting
---@return EnumValue? errType
function Connection.Establish(targetCharacter)
	if not private.hasFriendsInfo then
		return false, Connection.ERROR.NOT_READY
	end
	Presence.ClearOffline(targetCharacter)
	local wasFriend = Presence.IsTracked(targetCharacter)
	if strlower(targetCharacter) == strlower(SessionInfo.GetCharacterName()) then
		return false, Connection.ERROR.CURRENT_CHARACTER
	elseif not Presence.IsOnline(targetCharacter) and wasFriend then
		return false, Connection.ERROR.NOT_ONLINE
	end
	local iter = private.accessibleCharacterIterFunc()
	for _, player in iter do
		if strlower(player) == strlower(targetCharacter) then
			iter:Release()
			return false, Connection.ERROR.ALREADY_KNOWN
		end
	end
	if not private.isActive then
		private.isActive = true
		private.managementTimer:RunForTime(1)
	end
	private.newCharacter = targetCharacter
	private.newFriendsUpdateTimeout = NEW_FRIENDS_UPDATE_TIMEOUT
	private.newAccount = nil
	private.newSyncAcked = nil
	private.newAccountTimer:Cancel()
	private.newAccountTimer:RunForTime(0)
	return true
end

---Gets the character currently being connected to.
---@return string?
function Connection.GetConnectingCharacter()
	return private.newCharacter
end

---Gets the status for an account.
---@param accountKey string The account key
---@return boolean isConnected
---@return string? character
function Connection.GetStatus(accountKey)
	if private.connectedCharacter[accountKey] then
		return true, private.connectedCharacter[accountKey]
	else
		return false
	end
end

---Removes the connection to an account.
---@param accountKey string The account key
function Connection.Remove(accountKey)
	if private.threadRunning[accountKey] then
		private.KillConnectionThread(accountKey)
	end
	Presence.RemoveAccount(accountKey)
	private.removeAccountHandler(accountKey)
end



-- ============================================================================
-- Message Handlers
-- ============================================================================

---@param sourceAccount string
---@param sourceCharacter string
function private.WhoAmIAckHandler(sourceAccount, sourceCharacter, data)
	if not private.newCharacter or strlower(private.newCharacter) ~= strlower(sourceCharacter) then
		-- We aren't trying to connect with a new account
		return
	end
	Log.Info("WHOAMI_ACK '%s'", tostring(private.newCharacter))
	private.newSyncAcked = true
	private.CheckNewAccountStatus()
end

---@param sourceAccount string
---@param sourceCharacter string
function private.WhoAmIAccountHandler(sourceAccount, sourceCharacter, data)
	if not private.newCharacter then
		-- We aren't trying to connect with a new account
		return
	elseif strlower(private.newCharacter) ~= strlower(sourceCharacter) then
		Log.Info("WHOAMI_ACCOUNT from unknown player \"%s\", expected \"%s\"", private.newCharacter, sourceCharacter)
		return
	end
	private.newCharacter = sourceCharacter -- Get correct capitalization
	private.newAccount = sourceAccount
	Log.Info("WHOAMI_ACCOUNT '%s' '%s'", private.newCharacter, private.newAccount)
	Comm.SendData(Constants.DATA_TYPES.WHOAMI_ACK, private.newCharacter)
	private.CheckNewAccountStatus()
end

---@param sourceAccount string
---@param sourceCharacter string
function private.ConnectionRequestAndAckHandler(sourceAccount, sourceCharacter, data)
	if Presence.HandleConnectionRequest(sourceAccount, sourceCharacter) then
		private.StartConnectionTo(sourceAccount, sourceCharacter)
	elseif not private.threadRunning[sourceAccount] then
		return
	end
	private.connectionRequestReceived[sourceAccount] = true
end

---@param sourceAccount string
---@param sourceCharacter string
function private.DisconnectHandler(sourceAccount, sourceCharacter, data)
	if not private.threadRunning[sourceAccount] then
		return
	end

	-- Kill the thread and prevent it from running again for 2 seconds
	private.KillConnectionThread(sourceAccount)
	private.suppressThreadTime[sourceAccount] = LibTSMService.GetTime() + 2
end

---@param sourceAccount string
---@param sourceCharacter string
function private.HeartbeatHandler(sourceAccount, sourceCharacter)
	if not Connection.IsCharacterConnected(sourceCharacter) then
		-- We're not connected to this player
		return
	end
	private.lastHeartbeat[sourceAccount] = LibTSMService.GetTime()
end



-- ============================================================================
-- Management Loop / Sync Thread
-- ============================================================================

function private.PrepareFriendsInfo()
	if not FriendList.IsPopulated() then
		-- Try again
		Log.Err("Missing friends info - will try again")
		private.friendsInfoTimer:RunForTime(0.5)
		return
	end

	if (not private.hasFriendsInfo or private.pendingFriendsUpdate) and private.isActive then
		-- Start the management loop
		private.managementTimer:RunForTime(1)
	end
	private.hasFriendsInfo = true
	private.pendingFriendsUpdate = false
end

function private.ManagementLoop()
	private.managementTimer:RunForTime(1)
	-- Continuously spawn connection threads with online players as necessary
	local hasAccount, hasCharacter = false, false
	for _, account in private.accountIteratorFunc() do
		hasAccount = true
		local targetCharacter = Presence.GetTargetCharacter(account)
		if targetCharacter then
			hasCharacter = true
			if not private.threadId[account] then
				private.threadId[account] = Threading.New("SYNC_"..String.StrictMatch(account, "(%d+)$"), private.ConnectionThread)
			end
			if not private.threadRunning[account] and (private.suppressThreadTime[account] or 0) < LibTSMService.GetTime() then
				private.threadRunning[account] = true
				private.threadTarget[account] = targetCharacter
				Threading.Start(private.threadId[account], account, targetCharacter)
			end
		end
	end
	if not hasAccount then
		Log.Info("No more sync accounts.")
		private.isActive = false
		if not private.newCharacter then
			private.managementTimer:Cancel()
		end
	elseif not hasCharacter then
		private.pendingFriendsUpdate = true
		private.managementTimer:Cancel()
	end
end

function private.ConnectionThreadInner(account, targetCharacter)
	-- For the initial handshake, the lower account key is the server, other is the client - after this it doesn't matter
	-- add some randomness to the timeout so we don't get stuck in a race condition
	local timeout = LibTSMService.GetTime() + RECEIVE_TIMEOUT + random(0, 1000) / 1000
	if account < private.localAccountKey then
		if not Presence.CanDetectOnline() then
			Comm.SendData(Constants.DATA_TYPES.CONNECTION_REQUEST, targetCharacter)
		end
		-- Wait for the connection request from the client
		while not private.connectionRequestReceived[account] do
			if LibTSMService.GetTime() > timeout then
				-- Timed out on the connection - don't try again for a bit
				Log.Warn("Timed out")
				return
			elseif Presence.IsKnownOffline(targetCharacter) then
				Log.Info("Target is offline")
				return
			end
			Threading.Yield(true)
		end
		-- Send a connection request ACK back to the client
		Comm.SendData(Constants.DATA_TYPES.CONNECTION_REQUEST_ACK, targetCharacter)
	else
		-- Send a connection request to the server
		Comm.SendData(Constants.DATA_TYPES.CONNECTION_REQUEST, targetCharacter)
		-- Wait for the connection request ACK
		while not private.connectionRequestReceived[account] do
			if LibTSMService.GetTime() > timeout then
				-- Timed out on the connection - don't try again for a bit
				Log.Warn("Timed out")
				private.suppressThreadTime[account] = LibTSMService.GetTime() + RECEIVE_TIMEOUT
				return
			elseif Presence.IsKnownOffline(targetCharacter) then
				Log.Info("Target is offline")
				return
			end
			Threading.Yield(true)
		end
	end

	-- We are now connected
	Log.Info("Connected to: %s %s", account, targetCharacter)
	Presence.HandleConnected(account, targetCharacter)
	private.connectedCharacter[account] = targetCharacter
	private.lastHeartbeat[account] = LibTSMService.GetTime()
	private.connectionChangedCallbacks:CallAll(account, targetCharacter, true)

	-- Now that we are connected, data can flow in both directions freely
	local lastHeartbeatSend = LibTSMService.GetTime()
	while true do
		-- Check if they either logged off or the heartbeats have timed-out
		if not Presence.IsOnline(targetCharacter, true) or LibTSMService.GetTime() - private.lastHeartbeat[account] > HEARTBEAT_TIMEOUT then
			return
		end

		-- Check if we should send a heartbeat
		if LibTSMService.GetTime() - lastHeartbeatSend > floor(HEARTBEAT_TIMEOUT / 2) then
			Comm.SendData(Constants.DATA_TYPES.HEARTBEAT, targetCharacter)
			lastHeartbeatSend = LibTSMService.GetTime()
		end

		Threading.Yield(true)
	end
end

function private.ConnectionThread(account, targetCharacter)
	private.ConnectionThreadInner(account, targetCharacter)
	private.ConnectionThreadDone(account)
end

function private.ConnectionThreadDone(account)
	Log.Info("Connection ended to %s", account)
	local player = private.connectedCharacter[account]
	private.connectedCharacter[account] = nil
	if player then
		private.connectionChangedCallbacks:CallAll(account, player, false)
	end
	private.threadRunning[account] = nil
	private.threadTarget[account] = nil
	private.connectionRequestReceived[account] = nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SendNewAccountWhoAmI()
	if not private.newCharacter then
		private.newAccountTimer:Cancel()
	elseif not Presence.IsTracked(private.newCharacter) then
		assert(private.newFriendsUpdateTimeout)
		private.newFriendsUpdateTimeout = private.newFriendsUpdateTimeout - 1
		if private.newFriendsUpdateTimeout > 0 then
			Log.Info("Waiting for friends list to update")
			private.newAccountTimer:RunForTime(1)
		else
			Log.Err("Timeout waiting for friends list to update")
			private.newAccountTimer:Cancel()
			private.newCharacter = nil
			private.newFriendsUpdateTimeout = nil
			private.newAccount = nil
			private.newSyncAcked = nil
		end
	elseif not Presence.IsOnline(private.newCharacter) then
		private.newAccountTimer:Cancel()
		private.newCharacter = nil
		private.newFriendsUpdateTimeout = nil
		private.newAccount = nil
		private.newSyncAcked = nil
		Log.Err("New player went offline")
	else
		Comm.SendData(Constants.DATA_TYPES.WHOAMI_ACCOUNT, private.newCharacter)
		Log.Info("Sent WHOAMI_ACCOUNT")
		private.newAccountTimer:RunForTime(1)
	end
end

function private.CheckNewAccountStatus()
	if not private.newCharacter or not private.newAccount or not private.newSyncAcked then
		return
	end
	Log.Info("New sync character: '%s' '%s'", private.newCharacter, private.newAccount)
	-- The other account ACK'd so setup a connection
	private.newAccountHandler(private.newAccount, private.newCharacter)
	Presence.SetOnline(private.newAccount, private.newCharacter)

	-- Call the callbacks for this new account
	private.connectionChangedCallbacks:CallAll(private.newAccount, private.newCharacter, nil)

	private.newCharacter = nil
	private.newFriendsUpdateTimeout = nil
	private.newAccount = nil
	private.newSyncAcked = nil
end

function private.StartConnectionTo(account, character)
	if private.threadRunning[account] and strlower(private.threadTarget[account]) ~= strlower(character) then
		private.KillConnectionThread(account)
	end
	if not private.threadRunning[account] then
		private.suppressThreadTime[account] = nil
		private.managementTimer:RunForTime(0)
	end
end

function private.DisconnectCharacter(character)
	local account = Table.KeyByValue(private.connectedCharacter, character)
	if not account or not private.threadRunning[account] then
		return
	end
	Comm.SendData(Constants.DATA_TYPES.DISCONNECT, character)
	private.KillConnectionThread(account)
end

function private.KillConnectionThread(account)
	Threading.Kill(private.threadId[account])
	private.ConnectionThreadDone(account)
end

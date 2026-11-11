-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Presence = LibTSMService:InitInternal("Sync.Presence")
local FriendList = LibTSMService:From("LibTSMWoW"):Include("API.FriendList")
local ChatEvent = LibTSMService:From("LibTSMWoW"):Include("Service.ChatEvent")
local private = {
	settingsDB = nil,
	onlineCharacter = {},
	offlineCharacter = {},
	searchedAccount = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the presence code.
---@param settingsDB SettingsDB The settings DB
function Presence.Load(settingsDB)
	private.settingsDB = settingsDB
	if not Presence.CanDetectOnline() then
		ChatEvent.RegisterPlayerNotFoundHandler(private.HandlePlayerNotFound)
	end
end

---Returns whether or not the online status of a character can be detected without contacting it.
---@return boolean
function Presence.CanDetectOnline()
	return not LibTSMService.IsForever()
end

---Returns whether or not the online status of a character is being tracked.
---@param character string The character
---@return boolean
function Presence.IsTracked(character)
	return not Presence.CanDetectOnline() or FriendList.IsFriend(character)
end

---Returns whether or not a character is online, starting to track it if possible.
---@param character string The character
---@param noTrack? boolean Don't start tracking the character
---@return boolean
function Presence.IsOnline(character, noTrack)
	if not Presence.CanDetectOnline() then
		return not Presence.IsKnownOffline(character)
	elseif FriendList.IsFriend(character) then
		return FriendList.IsOnline(character)
	elseif not noTrack and FriendList.CanAdd(character) then
		-- Add them as a friend
		FriendList.Add(character)
		FriendList.Query()
		return FriendList.IsOnline(character)
	else
		return false
	end
end

---Returns whether or not a character is known to be offline.
---@param character string The character
---@return boolean
function Presence.IsKnownOffline(character)
	return private.offlineCharacter[strlower(character)] or false
end

---Clears the known offline status of a character.
---@param character string The character
function Presence.ClearOffline(character)
	private.offlineCharacter[strlower(character)] = nil
end

---Marks a character as online.
---@param account string The account key
---@param character string The character
function Presence.SetOnline(account, character)
	Presence.ClearOffline(character)
	private.onlineCharacter[account] = character
end

---Gets the character to connect to for an account.
---@param account string The account key
---@return string?
function Presence.GetTargetCharacter(account)
	if not Presence.CanDetectOnline() then
		return private.GetUndetectableTargetCharacter(account)
	end

	-- Find the player to connect to without adding to the friends list
	local iter = private.settingsDB:AccessibleCharacterIterator(account)
	for _, player in iter do
		if Presence.IsOnline(player, true) then
			iter:Release()
			return player
		end
	end

	-- If we failed, try again with adding to friends list
	iter = private.settingsDB:AccessibleCharacterIterator(account)
	for _, player in iter do
		if Presence.IsOnline(player) then
			iter:Release()
			return player
		end
	end
end

---Handles a connection request and returns whether or not it shows the source character is online.
---@param account string The account key
---@param character string The character
---@return boolean
function Presence.HandleConnectionRequest(account, character)
	if Presence.CanDetectOnline() or not private.IsSyncAccount(account) then
		return false
	end
	Presence.SetOnline(account, character)
	return true
end

---Handles a connection being established.
---@param account string The account key
---@param character string The character
function Presence.HandleConnected(account, character)
	if Presence.CanDetectOnline() then
		return
	end
	Presence.SetOnline(account, character)
	private.searchedAccount[account] = true
end

---Removes the presence info for an account.
---@param account string The account key
function Presence.RemoveAccount(account)
	private.onlineCharacter[account] = nil
	private.searchedAccount[account] = nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetUndetectableTargetCharacter(account)
	local onlineCharacter = private.onlineCharacter[account]
	if onlineCharacter and Presence.IsOnline(onlineCharacter) then
		return onlineCharacter
	elseif private.searchedAccount[account] then
		return nil
	end
	local iter = private.settingsDB:AccessibleCharacterIterator(account)
	for _, player in iter do
		if Presence.IsOnline(player) then
			iter:Release()
			return player
		end
	end
	private.searchedAccount[account] = true
	return nil
end

function private.HandlePlayerNotFound(character)
	private.offlineCharacter[strlower(character)] = true
end

function private.IsSyncAccount(account)
	local result = false
	for _, syncAccount in private.settingsDB:SyncAccountIterator() do
		if syncAccount == account then
			result = true
		end
	end
	return result
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local FriendList = LibTSMWoW:Init("API.FriendList")
local Event = LibTSMWoW:Include("Service.Event")
local private = {
	addedFriends = {},
	invalidCharacters = {},
}
local MAX_FRIENDS = 100



-- ============================================================================
-- Module Loading
-- ============================================================================

FriendList:OnModuleLoad(function()
	Event.Register("CHAT_MSG_SYSTEM", private.ChatMsgSystemEventHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Queries the friend list.
function FriendList.Query()
	C_FriendList.ShowFriends()
end

---Checks if the friend list is populated.
---@return boolean
function FriendList.IsPopulated()
	for i = 1, private.GetNumFriends() do
		if not (C_FriendList.GetFriendInfoByIndex(i) --[[@as FriendInfo?]]) then
			return false
		end
	end
	return true
end

---Checks whether or not a character is a friend.
---@param character string The character name
---@return boolean
function FriendList.IsFriend(character)
	return private.GetFriendInfoByName(character) and true or false
end

---Checks whether or not a friend is online.
---@param character string The character name
---@return boolean
function FriendList.IsOnline(character)
	local info = private.GetFriendInfoByName(character)
	return info and info.connected or false
end

---Checks whether or not a character can be added as a friend.
---@return boolean
function FriendList.CanAdd(character)
	if private.GetNumFriends() == MAX_FRIENDS then
		return false
	elseif private.invalidCharacters[strlower(character)] then
		return false
	end
	return true
end

---Adds a character to the friend list.
---@param character string The character name
function FriendList.Add(character)
	C_FriendList.AddFriend(character)
	tinsert(private.addedFriends, character)
end

---Iterates over the friends list.
function FriendList.Iterator()
	return private.FriendListIterator, nil, 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ChatMsgSystemEventHandler(_, msg)
	if (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and issecretvalue(msg) then
		-- The message is a secret, so just ignore it
		return
	end
	if #private.addedFriends == 0 then
		return
	end
	if msg == ERR_FRIEND_NOT_FOUND then
		if #private.addedFriends > 0 then
			private.invalidCharacters[strlower(tremove(private.addedFriends, 1))] = true
		end
	else
		for i, v in ipairs(private.addedFriends) do
			if format(ERR_FRIEND_ADDED_S, v) == msg then
				tremove(private.addedFriends, i)
				private.invalidCharacters[strlower(v)] = nil
				break
			end
		end
	end
end

function private.GetNumFriends()
	return C_FriendList.GetNumFriends() --[[@as number?]] or 0
end

function private.GetFriendInfoByName(name)
	return C_FriendList.GetFriendInfo(name) --[[@as FriendInfo?]]
end

function private.FriendListIterator(_, i)
	i = i + 1
	if i > private.GetNumFriends() then
		return
	end
	local info = C_FriendList.GetFriendInfoByIndex(i)
	return i, info.name
end

#!/usr/bin/env python3
"""Patch TSM Account Sync to work between WoW accounts on the same Battle.net account.

WoW refuses to friend your own bnet characters ("You can't put yourself on your friend list"),
and TSM uses the friends list to tell whether the other character is online. This patch:
  - treats non-friends as online unless a whisper to them recently bounced ("No player named ...")
  - hides those bounce messages for sync targets
  - keeps the management loop polling instead of waiting for a FRIENDLIST_UPDATE that never comes
Re-run after every TSM update (idempotent). Requires /reload or relog.
"""
import os, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(ROOT, "Interface/AddOns/TradeSkillMaster/LibTSMService/Source/Sync/Internal/Connection.lua")
MARK = "-- PATCHED(same-bnet)"

src = open(F, encoding="utf-8", newline="").read()
if MARK in src:
    sys.exit("already patched")

REPLACEMENTS = [
    # 1. New-account handshake: don't wait for the target to appear in the friends list
    ("\telseif not FriendList.IsFriend(private.newCharacter) then\n",
     f"\telseif false then {MARK}: own-bnet chars can't be friends\n"),
    # 2. No online characters: keep polling instead of waiting for FRIENDLIST_UPDATE
    ("\t\tprivate.pendingFriendsUpdate = true\n\t\tprivate.managementTimer:Cancel()\n",
     f"\t\tprivate.pendingFriendsUpdate = true\n\t\tprivate.managementTimer:RunForTime(5) {MARK}\n"),
    # 3. Online check without the friends list
    ("""function private.IsOnline(target, noAdd)
	if FriendList.IsFriend(target) then
		return FriendList.IsOnline(target)
	elseif not noAdd and FriendList.CanAdd(target) then
		-- Add them as a friend
		FriendList.Add(target)
		FriendList.Query()
		return FriendList.IsOnline(target)
	else
		return false
	end
end
""",
     f"""function private.IsOnline(target, noAdd)
	if FriendList.IsFriend(target) then
		return FriendList.IsOnline(target)
	end
	{MARK}: assume online unless a whisper to them bounced in the last 30s
	local key = strlower(target)
	private.syncTargets[key] = true
	return (private.offlineUntil[key] or 0) < LibTSMService.GetTime()
end

{MARK}: detect offline sync targets from "No player named '%s' is currently playing." and hide it
private.syncTargets = {{}}
private.offlineUntil = {{}}
do
	local pattern = "^"..(gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
	pattern = (gsub(pattern, "%%%%s", "(.+)")).."$"
	local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
	if addFilter then
		addFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
			if issecretvalue and issecretvalue(msg) then
				return false
			end
			local name = strmatch(msg, pattern)
			if not name then
				return false
			end
			local key = strlower(Ambiguate(name, "none"))
			if not private.syncTargets[key] then
				return false
			end
			private.offlineUntil[key] = LibTSMService.GetTime() + 30
			return true
		end)
	end
end
"""),
]

for old, new in REPLACEMENTS:
    if src.count(old) != 1:
        sys.exit(f"pattern not found (TSM changed?), nothing written:\n{old[:80]}")
    src = src.replace(old, new)

open(F, "w", encoding="utf-8", newline="").write(src)
print("patched", os.path.relpath(F, ROOT), "- now /reload all clients")

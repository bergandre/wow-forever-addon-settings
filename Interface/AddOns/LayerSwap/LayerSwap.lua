-- LayerSwap 1.14.14 - host + panel.
-- A player changes layer by joining a group whose leader stands on another layer. A host
-- is somebody who invites whoever asks. This file is the host, the reading of the player's
-- own layer from creature GUIDs, the request for a swap, and the small panel on top of them.
-- What happens is written to SavedVariables so it can be read from disk after a /reload.
--
-- Measured on the Forever beta (build 69913, 19 Sep 2026):
--   * a chat sender is "First Surname" with a SPACE and no realm; UnitName("player")
--     returns that combined string, UnitName(otherUnit) returns first, surname
--   * the custom channel arrives with channelBaseName "layer" and zoneChannelID 0,
--     General with zoneChannelID 1
--   * "player" contains "layer" - requests are matched on whole words
--   * Blizzard calls a layer change a shard transfer (SHARD_TRANSFER_IMMINENT / SHARD_TRANSFER)
local ADDON = ...

-- One file for WoW Forever and for the Classic clients (Era 1.15, TBC Anniversary 2.5). Forever
-- has Blizzard's shard-transfer system; Era and Anniversary have none of it (their API docs list
-- no SHARD_TRANSFER, no GetEvictionTimeRemaining, 27 Sep 2026): there a move shows only in the
-- creature GUIDs, and names are "Name-Realm".
local TOC = (type(GetBuildInfo) == "function" and select(4, GetBuildInfo())) or 16001
local FOREVER = TOC >= 16000 and TOC < 20000
-- 9 Nov 2026, measured on live Forever: the layer is the creature GUID's server part - 6843 of
-- 6843-8; the second part differs between two players on one layer. Four joins of a host whose
-- id shared the server part and not the second part moved nobody; the one join of a host with
-- another server part moved the guest at once (and the guest's own id there had yet another
-- second part). What LayerSwap sends keeps the whole id, so older versions read it as before;
-- every comparison goes through Layer.same. Classic keeps the whole id (NWB numbers its layers).
local Layer = {}
function Layer.key(id)
  if not FOREVER or type(id) ~= "string" then return id end
  return string.match(id, "^(%d+)%-") or id
end
function Layer.same(a, b)
  if a == nil or b == nil then return false end
  return a == b or Layer.key(a) == Layer.key(b)
end
local TBC = TOC >= 20000 and TOC < 30000

LayerSwapDB = LayerSwapDB or {}

local LAYER_CHANNEL = "layer"
local PARTY_MAX = 5
local PLAYER_COOLDOWN = 60      -- seconds before the same player is invited again
local INVITE_SPACING = 1        -- seconds between two invites
local PENDING_TTL = 60          -- an unanswered invite stops counting after this long
local WATCH_AFTER_INVITE = 6    -- seconds of system/error messages logged after an invite
local LOG_MAX = 1000            -- 1.14 writes a 'spot' entry per ask on top of the rest (about 100 bytes each)
-- The chat line is a plain "inv layer" that anyone can read. What LayerSwap knows about the
-- layer (the one wanted, or the one being left) goes along out of sight as an addon message
-- in the layer channel - a "note": "want <id>", "not <id>" or "any". Only LayerSwap reads it.
-- On Forever a "zone <map id>" note goes just before it, and a host in that zone who stands on
-- the asker's own layer whispers "same" back instead of an invite that would change nothing; a
-- host that has not read its own layer yet stays out too (1.9).
-- 1.10: the zone and the layer also ride in the chat line, as a short tag (routeTag below) - on
-- 10 Oct 2026 the notes came 68-139 s late while the line took 0.13-0.34 s. The notes still go
-- out for hosts older than 1.10.
local NOTE_PREFIX = "LayerSwap"
local NOTE_TTL = 10             -- seconds a host keeps an asker's note
-- The note can land after the chat line although it was sent first (beta 26 Sep 2026: same
-- frame, just after). A plain "inv layer" - LayerSwap's own line - waits this long for it.
local NOTE_WAIT = 0.5
-- 1.14: an ask also carries the asker's position, as a note of its own ("pos <zone map id> <x> <y>",
-- whole yards), for a host that skips askers near it (the option "Skip askers near you", see
-- Near.check). Where the yards come from is one constant: "world" = UnitPosition, which needs no
-- map; "map" = the position on the zone map times the map's size in yards, the fallback, under
-- its own note kind ("posm") so the two frames are never compared with each other.
-- Everything behind it lives in this one table: Lua 5.1 allows 200 locals in a file, and this
-- file is close to that.
local Near = { SOURCE = "world", DEFAULT = 150, MIN = 50, MAX = 1000, later = {} }
Near.KIND = Near.SOURCE == "world" and "pos" or "posm"

-- 1.14.2: how the ask leaves the player. The live Forever realms do not let an addon post a chat
-- line (C_ChatInfo.AreOutgoingAddonChatMessagesRestricted, a realm setting; the beta realms
-- allowed it): the server answers "That operation is not permitted in this channel", and the
-- notes (addon messages) in the layer channel are refused by the client. On such a realm Swap
-- layer puts the line into the chat box, and the player's own Enter sends it (measured 6 Nov
-- 2026: the line went out and a host invited 5 s later). Everything behind it lives in this one
-- table - the pending line, the chat box, the channel notices the server sends, and a gate per
-- note kind - for the same reason Near is a table (200 locals).
local Send = { comms = {}, notices = {}, noticeCount = 0, count = 0 }
Send.ECHO_WAIT = 3          -- seconds for the line's own echo once it has left the box
Send.BOX_TTL = 600          -- a line that sits in a box the addon cannot read is given up after this
Send.PENDING_TEXT = "|cff40ff40Your request is in the chat box|r - press Enter to send it, Escape to drop it."
-- 1.14.4: LayerSwap's own channel (the hub). On such a realm the request goes there instead of
-- General whenever we sit in it, so General stays free of it (a user on CurseForge, 7 Nov 2026:
-- "spamming in /1 general"). A custom channel reaches the players of every layer; General may
-- reach only one's own layer (players' reports, and every invite through it so far came from the
-- asker's own layer). The hub is joined on a click, the one moment an addon may join a channel,
-- the game rejoins it at every login, and it is taken out of every chat window.
Send.HUB = "LayerSwap"
Send.HUB_WAIT = 10          -- an ask in the hub no host has invited by then: the button offers General (not below SWAP_COOLDOWN)
Send.REPEAT_WAIT = 60       -- an ask nobody answered is not sent to the same place from the same zone sooner
Send.lastAt = {}            -- [place] = { zone, at, invited }: our last ask that went out there
Send.REFUSED = { NOT_ALLOWED_IN_CHANNEL = true, MUTED = true, NOT_MEMBER = true, BANNED = true, WRONG_PASSWORD = true }
-- 1.14.6: the hub as a place to ask is off. On 7 Nov 2026 the game disabled the channel for the
-- account of a player who had only joined it, and refused another's rejoin at login after two
-- accepted lines: a custom channel is no place the live realms let an addon's traffic stay. Hosts
-- still read it, for askers on 1.14.4; nothing joins it and nothing is said about it. The tests
-- turn the machinery on through this global before the file loads.
Send.HUB_ASKS = rawget(_G, "LayerSwapHubAsks") == true

-- 1.14.6: the ask without a channel. On a realm that refuses chat lines an addon posts, the request
-- needs no channel at all: the click asks the game who stands in the zone (the player search
-- reaches every layer of the realm), and the request goes to each of them as a hidden addon
-- whisper - the one message the live realms still carry between strangers, the kind every addon's
-- version check runs on. Only a LayerSwap user reads it: a host on another layer in the zone
-- invites, every user in the zone answers "heard" the same way, and nothing shows in anyone's
-- chat. General, which the game may keep to one layer, is left to Ask in General. Everything of it
-- lives in this one table (200 locals): the search that waits, the names, the burst, the senders.
-- The client lets an addon send about 10 messages per prefix at once and then about one a second
-- (its answer 3 past that): the first round takes up to BURST (two left for a host's own replies), each later round, a second apart,
-- what the budget has grown back - so 49 names take some 40 s, and an invite ends the burst.
local Who = { WAIT = 5, BURST = 8, BURST_WAIT = 1, ROUNDS = 45, MAX = 49, LATE = 30, from = {} }
-- The search asks the players of our own zone: only a host there moves us (8 Nov 2026 23:21, measured
-- on live: a host in Elwynn invited an asker in Westfall and the game moved nobody - 1.14.8 had
-- asked the whole realm). The game answers 50 names at most, so the clicks go round the zone's
-- level range in BANDS slices. FRESH: creatures read after a
-- join that must still show the old layer before LayerSwap calls the host one on our layer - the
-- game's transfer event alone said "not moved" for every host in another zone (7 of 7, Oct 2026),
-- and no creature had been read in any of them. JUDGE_FOR: how long after a join the verdict is tried.
Who.BANDS, Who.FRESH, Who.JUDGE_FOR = 6, 3, 60
-- The map search (8 Nov 2026): the live group finder's who list filters by map, class and race
-- (SendWho's third argument). Each click asks the zone's map, then the map one class at a time -
-- 50 names a class instead of 50 in all. The text filter z-"<zone>" gave 7 of 50 rows in the zone
-- (Westfall, 8 Nov 23:17) and 11 of 50 (Elwynn, 12:56).
Who.CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
-- The book: LayerSwap users who answered our asks (heard, same), whispered first when the search
-- finds them again - an invite in the first burst instead of up to 40 s of whispers.
Who.BOOK_TTL, Who.BOOK_MAX = 7 * 86400, 300
-- 1.14.12: a player a search whispered is not whispered again for ASKED_FOR seconds unless it answered (Who.fresh)
Who.ASKED_FOR, Who.ASKED_MAX = 6 * 3600, 3000
-- 1.14.14: the names whispered lately (Who.sentTo[name] = GetTime()), for the game's "No player named ..." line:
-- within GONE_WAIT seconds of our whisper that line is ours, not the player's own (Who.notPlaying)
-- a known LayerSwap user the game could not find is left alone for GONE_FOR seconds, or until it answers (Adam,
-- 11 Nov 2026: it has to come back by itself - a known host is too rare to drop for six hours)
Who.sentTo, Who.GONE_WAIT, Who.GONE_FOR = {}, 15, 600
-- 1.14.13: seconds after the burst before a host with an unknown layer is asked once more (Who.anyway), and
-- how long a host known to stand on another layer gets to invite before that happens all the same
Who.ANYWAY_WAIT, Who.ANYWAY_LATE = 3, 10
-- 1.14.14: an ask for new layers only names up to SEEN_MAX layers seen in the zone after the one it leaves;
-- the guest leaves a LayerSwap host's group LEAVE_AFTER seconds after the move is confirmed
Layer.SEEN_MAX, Layer.LEAVE_AFTER = 6, 3
-- The border probe: the layer read within this long after a zone border is logged with the one
-- before it (which zones share layers - Westfall and Duskwood may, Elwynn and Westfall did not).
Who.BORDER_FOR, Who.BORDER_READS, Who.BORDER_QUIET = 60, 3, 15
Who.GUILD_LINE = "Hidden whispers are refused here - /ls guild asks your guild, on every layer."

-- The option "Skip askers near you" (1.14): off unless ticked, and its distance in yards.
function Near.on()
  return FOREVER and LayerSwapDB.skipNear == true
end

function Near.yards()
  local v = tonumber(LayerSwapDB.skipNearYards)
  if not v or v ~= v then return Near.DEFAULT end
  return math.max(Near.MIN, math.min(Near.MAX, math.floor(v / 10 + 0.5) * 10))
end

local hosting = false
local hosted = {}               -- [fullName] = true: players this session invited
local lastInvite = {}           -- [fullName] = GetTime() of the last invite
local pending = {}              -- [fullName] = GetTime() of an invite not yet answered
local lastInviteAt = 0
local watchUntil = 0
local stats = { requests = 0, askers = 0, invites = 0, joined = 0, skipped = 0 }

-- 1.14.12, live Forever (the realm refuses addon chat): a host sends at most Host.CAP invites in
-- Host.WINDOW seconds, then takes a break until the oldest of them is that old. Invites are what other
-- players see of a host, and players told of Blizzard silences for "spamming group invites"
-- (CurseForge, 10 Nov 2026). Host.left(now): the seconds the break still lasts, nil while the host may
-- invite. Elsewhere there is no break.
local Host = { CAP = 6, WINDOW = 600, sent = {} }
function Host.left(now)
  if not (FOREVER and Send.restricted()) then return nil end
  local keep = {}
  for _, t in ipairs(Host.sent) do
    if now - t < Host.WINDOW then keep[#keep + 1] = t end
  end
  Host.sent = keep
  if #keep < Host.CAP then return nil end
  return keep[#keep - Host.CAP + 1] + Host.WINDOW - now
end
local askers = {}                -- [fullName] = true: the players who asked this session, host on or off
local notes = {}                -- [First Surname] = { want, avoid, at, zone, zoneAt, from, pos, posAt }: what an asker's notes said
local requestedAt = {}          -- [First Surname] = GetTime() of their last request line
local came = {}                 -- [fullName] = true: a player we invited who joined
-- Our own ask waits for an invite (waitingAsk, below): the host then invites nobody - a group of
-- our own would keep that invite out (Adam, 11 Oct 2026: a guest joined while he asked, and two
-- hosts' invites to him bounced off "already in a group").
local ownAskWaiting = function() return false end
-- id of the layer the player stands on, nil while unknown (read in "which layer is this?");
-- declared up here because the host needs it to answer requests that name a layer
local current

-- ---------------------------------------------------------------------------------------
-- helpers

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, s = pcall(issecretvalue, v)
  return ok and s == true
end

local function say(msg)
  print("|cff7fd4ffLayerSwap|r: " .. msg)
end

local function log(kind, a, b, c, d)
  local db = LayerSwapDB
  db.log = db.log or {}
  if #db.log >= LOG_MAX then return nil end
  local e = { t = date("%H:%M:%S"), g = math.floor(GetTime() * 100) / 100, kind = kind, a = a, b = b, c = c, d = d }
  db.log[#db.log + 1] = e
  return e
end

local function leaveParty()
  local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
  if leave then leave() end
end

local function surnameSeparator()
  local c = Constants and Constants.CharacterNameSeparatorConsts
  local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
  if type(sep) == "string" and sep ~= "" then return sep end
  return " "
end

-- Classic: every name as "Name-Realm", the shape chat senders have and invites take.
local function withRealm(name)
  if FOREVER or type(name) ~= "string" or name == "" or string.find(name, "-", 1, true) then return name end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  if type(realm) ~= "string" or realm == "" then return name end
  return name .. "-" .. realm
end

-- Forever: "First Surname" for any unit. The player's own UnitName already carries both parts
-- in the first return; every other unit returns them separately.
-- Classic: "Name-Realm" (UnitName's second return is the realm, nil on our own).
local function fullName(unit)
  local first, surname = UnitName(unit)
  if isSecret(first) or type(first) ~= "string" or first == "" then return nil end
  if not FOREVER then
    if type(surname) == "string" and surname ~= "" then return first .. "-" .. surname end
    return withRealm(first)
  end
  if not isSecret(surname) and type(surname) == "string" and surname ~= "" then
    return first .. surnameSeparator() .. surname
  end
  return first
end

-- ---------------------------------------------------------------------------------------
-- is this message a request?

local REQUEST_WORDS = { inv = true, invite = true, hop = true, swap = true, switch = true, change = true,
                        pls = true, plz = true, please = true, need = true, lf = true }
-- Whole words that mean the line is about something else.
local BLOCK_WORDS = { wts = true, wtb = true, wtt = true, lfm = true, lfg = true, guild = true, raid = true,
                      enchant = true, enchanting = true, recruiting = true, selling = true, buying = true,
                      worldbuffs = true, autoinv = true }
local BLOCK_PHRASES = { "what layer", "which layer", "how many layer", "auto inv", "pst for" }
-- General and guild chat: an ask is short ("need layer inv", "can i get a layer swap")
local ASK_MAX_WORDS = 10

local function wordsOf(msg)
  local set = {}
  for w in string.gmatch(msg, "%a+") do set[w] = true end
  return set
end

-- where: "layer" (the custom channel), "general", "guild" or "whisper". Returns true/false, reason.
local function isRequest(msg, where)
  if isSecret(msg) or type(msg) ~= "string" then return false, "unreadable" end
  local lower = string.lower(msg)
  local words = wordsOf(lower)
  for w in pairs(words) do
    if BLOCK_WORDS[w] then return false, "blocked word " .. w end
  end
  for _, phrase in ipairs(BLOCK_PHRASES) do
    if string.find(lower, phrase, 1, true) then return false, "blocked phrase" end
  end
  local saysLayer = words.layer or words.layers
  local asks = false
  for w in pairs(words) do
    if REQUEST_WORDS[w] then asks = true; break end
  end
  if where == "general" or where == "guild" then
    -- people talk there: a layer word alone is chatter, not an ask - and so is a long sentence
    -- that happens to hold both (beta 8 Oct 2026: twenty words about layers, "need" among them)
    if saysLayer and asks then
      if select(2, string.gsub(lower, "%S+", "")) > ASK_MAX_WORDS then return false, "too long for an ask" end
      return true
    end
    return false, saysLayer and "no request word" or "no layer word"
  end
  -- the layer channel and whispers exist for this: either word is enough
  if saysLayer or words.inv or words.invite then return true end
  return false, "no layer word"
end

-- Nova World Buffs (Classic): the layer numbers Classic players use. NWB numbers the layers it
-- knows and shares them between its users, so "Layer 2" means the same to all of them, and
-- AutoLayer asks and answers with those numbers. Forever has no NWB: letters there.
local function nwbLayer()
  if FOREVER then return nil end
  local n = tonumber(NWB_CurrentLayer)
  if n and n > 0 and n == math.floor(n) then return n end
end

local function nwbLayerCount()
  if FOREVER or not LibStub then return nil end
  local ok, ace = pcall(LibStub, "AceAddon-3.0", true)
  if not ok or type(ace) ~= "table" or type(ace.GetAddon) ~= "function" then return nil end
  local found, nwb = pcall(ace.GetAddon, ace, "NovaWorldBuffs", true)
  local known = found and type(nwb) == "table" and type(nwb.data) == "table" and nwb.data.layers
  if type(known) ~= "table" then return nil end
  local count = 0
  for _ in pairs(known) do count = count + 1 end
  return count > 0 and count or nil
end

-- The map the player stands on - AutoLayer's zone for TBC requests.
local function mapHere()
  local ok, id = pcall(C_Map and C_Map.GetBestMapForUnit, "player")
  if ok and type(id) == "number" and id > 0 then return tostring(id) end
end

-- Forever: the zone a unit stands in, as a map id every client shares (zone names come in the
-- client's language). A cave or a building inside a zone counts as the zone - the layer is the
-- zone's, its id changes at a zone border. nil when the game does not say.
local ZONE_MAP = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local function zoneOf(unit)
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, unit)
  if not ok or isSecret(id) or type(id) ~= "number" or id <= 0 then return nil end
  local zone = id
  for _ = 1, 6 do
    local found, info = pcall(C_Map.GetMapInfo, zone)
    if not found or type(info) ~= "table" or isSecret(info.mapType) or type(info.mapType) ~= "number" then break end
    if info.mapType == ZONE_MAP then return zone end
    local up = info.parentMapID
    if info.mapType < ZONE_MAP or isSecret(up) or type(up) ~= "number" or up <= 0 then break end
    zone = up
  end
  return id
end

local function zoneName(map)
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, map)
  local name = ok and type(info) == "table" and info.name
  if isSecret(name) or type(name) ~= "string" or name == "" then return nil end
  return name
end

-- 1.14.14: the name the layers are filed under. On Forever the zone-level map's name: the game's own zone text
-- changes inside some buildings (the tower at Sentinel Hill read "Sentinel Tower", 11 Nov 2026, and the layer
-- read there got a new letter). The game's zone text where the map says nothing, and on Classic as before.
function Layer.zone()
  local map = FOREVER and zoneOf("player")
  local name = map and zoneName(map)
  if name then return name end
  local text = type(GetRealZoneText) == "function" and GetRealZoneText(nil) or nil
  if isSecret(text) or type(text) ~= "string" then return nil end
  return text
end

-- 1.14: the player's own position, for the ask's pos note and for a host that skips askers
-- near it. x and y in whole yards, and the zone map id the two sides compare on (the number
-- the route tag carries). nil and a reason when the game gives nothing readable - no zone, a
-- missing function, a secret value. Forever only.
-- frame: "world" (UnitPosition) or "map" (the zone map); Near.SOURCE when not given. A position
-- read in the map frame carries the note kind "posm", one from the world frame "pos", so a host
-- compares each asker's position in the frame it came in (1.14.2: the tag carries map
-- coordinates, a hidden note world yards).
function Near.read(frame)
  if not FOREVER then return nil, "not Forever" end
  local zone = zoneOf("player")
  if not zone then return nil, "zone unknown" end
  frame = frame or Near.SOURCE
  local kind = frame == "world" and "pos" or "posm"
  if frame == "world" then
    if type(UnitPosition) ~= "function" then return nil, "no UnitPosition" end
    local ok, a, b = pcall(UnitPosition, "player")
    if not ok or isSecret(a) or isSecret(b) or type(a) ~= "number" or type(b) ~= "number" then return nil, "unreadable" end
    return { kind = kind, ref = tostring(zone), x = math.floor(a + 0.5), y = math.floor(b + 0.5) }
  end
  local px, py, why = Near.fraction(zone)
  if not px then return nil, why end
  local w, h = Near.mapSize(zone)
  if not w then return nil, "map size unknown" end
  return { kind = kind, ref = tostring(zone), x = math.floor(px * w + 0.5), y = math.floor(py * h + 0.5), fx = px, fy = py }
end

-- The player's place on a map as the game's own fraction (0-1 across the map), or nil and why.
function Near.fraction(zone)
  if not (C_Map and C_Map.GetPlayerMapPosition) then return nil, "no map position API" end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, zone, "player")
  if not ok or type(pos) ~= "table" or isSecret(pos) then return nil, "no map position" end
  local px, py = pos.x, pos.y
  if type(pos.GetXY) == "function" then
    local okXY, gx, gy = pcall(pos.GetXY, pos)
    if okXY then px, py = gx, gy end
  end
  if isSecret(px) or isSecret(py) or type(px) ~= "number" or type(py) ~= "number" then return nil, "unreadable" end
  if px < 0 or px > 1 or py < 0 or py > 1 then return nil, "off the map" end
  return px, py
end

-- A map's size in yards, or nil.
function Near.mapSize(zone)
  if not (C_Map and C_Map.GetMapWorldSize) then return nil end
  local ok, w, h = pcall(C_Map.GetMapWorldSize, tonumber(zone) or zone)
  if not ok or isSecret(w) or isSecret(h) or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return nil end
  return w, h
end

-- 1.14.2: the asker's map position from the tag of its line ("48.2,42.5" = percent of the zone
-- map), turned into map yards on the tag's zone and kept with the asker's other notes, as a
-- hidden note would be. The hidden notes do not travel on the live realms (the client refuses
-- them), so the line carries the position instead - the asker chose to send it.
function Near.fromTag(sender, tag, from)
  if not (FOREVER and tag and tag.pos and tag.zone) then return end
  local w, h = Near.mapSize(tag.zone)
  if not w then return end
  local was = notes[sender]
  notes[sender] = { want = was and was.want, avoid = was and was.avoid, at = was and was.at,
                    zone = was and was.zone, zoneAt = was and was.zoneAt, from = (was and was.from) or from or sender,
                    pos = { kind = "posm", ref = tostring(tag.zone), x = tag.pos.x / 100 * w, y = tag.pos.y / 100 * h },
                    posAt = GetTime() }
end

function Near.between(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- Every reading behind a position, raw, for the log: what the live client answers has not been
-- seen (the beta closed before this was built). One entry per ask and per /ls spot, with the
-- distance from the last reading, so a walk of ten seconds shows the yard scale.
function Near.probe(label)
  local function plain(v)
    if isSecret(v) then return "secret" end
    -- whole numbers (ids, yards) as they are; a map fraction with five decimals, which is under a
    -- yard on any zone map, so the two frames can be compared from the log
    if type(v) == "number" then return (v == math.floor(v)) and string.format("%.0f", v) or string.format("%.5f", v) end
    return tostring(v)
  end
  local best
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, v = pcall(C_Map.GetBestMapForUnit, "player")
    if ok then best = v end
  end
  local zone = zoneOf("player")
  local raw = { "bestmap " .. plain(best), "zone " .. plain(zone) }
  if type(UnitPosition) == "function" then
    local ok, r1, r2, r3, r4 = pcall(UnitPosition, "player")
    raw[#raw + 1] = ok and ("unit " .. plain(r1) .. " " .. plain(r2) .. " " .. plain(r3) .. " " .. plain(r4)) or "unit error"
  else
    raw[#raw + 1] = "unit none"
  end
  local px, py, w, h
  if zone and C_Map and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, zone, "player")
    if ok and type(pos) == "table" and not isSecret(pos) then
      px, py = pos.x, pos.y
      if type(pos.GetXY) == "function" then
        local okXY, gx, gy = pcall(pos.GetXY, pos)
        if okXY then px, py = gx, gy end
      end
    end
    raw[#raw + 1] = ok and ("map " .. plain(px) .. " " .. plain(py)) or "map error"
  end
  if zone and C_Map and C_Map.GetMapWorldSize then
    local ok, a, b = pcall(C_Map.GetMapWorldSize, zone)
    if ok then w, h = a, b end
    raw[#raw + 1] = ok and ("size " .. plain(w) .. " " .. plain(h)) or "size error"
  end
  local combat = false
  if type(InCombatLockdown) == "function" then
    local ok, v = pcall(InCombatLockdown)
    combat = ok and not isSecret(v) and v == true
  end
  local p, why = Near.read()
  -- the distance from the last reading, in the chosen frame and on the map, so one walk shows
  -- whether the two scales agree (a reading inside a mine may lack the map one)
  local moved
  if p and Near.lastProbe and p.ref == Near.lastProbe.ref then
    moved = string.format("%d yards from the last reading", math.floor(Near.between(p, Near.lastProbe) + 0.5))
  end
  local m
  if zone and not isSecret(px) and not isSecret(py) and not isSecret(w) and not isSecret(h)
     and type(px) == "number" and type(py) == "number" and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
    m = { ref = tostring(zone), x = px * w, y = py * h }
    if Near.lastProbeMap and Near.lastProbeMap.ref == m.ref then
      moved = (moved and (moved .. ", ") or "") .. string.format("%d yards on the map", math.floor(Near.between(m, Near.lastProbeMap) + 0.5))
    end
  end
  log("spot", label, p and (p.kind .. " " .. p.ref .. " " .. p.x .. " " .. p.y) or ("none: " .. tostring(why)),
      table.concat(raw, "; "), (combat and "combat" or "no combat") .. (moved and (", " .. moved) or ""))
  if p then Near.lastProbe = p end
  if m then Near.lastProbeMap = m end
  return p, why, raw, moved
end

-- AutoLayer on TBC Anniversary ignores a request without its header (layerSegments is on by
-- default) and turns down one from another zone: "<AL2V1_9_7Z1946> inv layer 1,3". The version
-- in it must be 1.9.5 or later for its hosts to answer; 1.9.7 is its current one (15 Sep 2026).
local function autoLayerHeader()
  return string.format("<AL2V%d_%d_%dZ%s>", 1, 9, 7, mapHere() or "0")
end

-- AutoLayer's reading of a request: layer numbers 1-20 and ranges ("1-3"), turned around by
-- a word like "not" or "except". Returns the numbers (sorted) and whether they are the ones
-- NOT wanted.
local INVERT_WORDS = { "not", "off", "except", "but", "out", "other than", "besides", "apart from" }
local function nwbNumbersIn(msg)
  local lower, set, list = string.lower(msg), {}, {}
  for num in string.gmatch(lower, "%d+") do
    local n = tonumber(num)
    if n >= 1 and n <= 20 then set[n] = true end
  end
  for a, b in string.gmatch(lower, "(%d+)%-(%d+)") do
    a, b = tonumber(a), tonumber(b)
    if a > b then a, b = b, a end
    for n = math.max(a, 1), math.min(b, 20) do set[n] = true end
  end
  for n in pairs(set) do list[#list + 1] = n end
  table.sort(list)
  local invert = false
  for _, w in ipairs(INVERT_WORDS) do
    if string.find(lower, "%f[%w]" .. w .. "%f[%W]") then invert = true; break end
  end
  return list, invert
end

-- LayerSwap 1.0 and 1.0.1 named the layer in the chat line itself: "inv layer 4621-72594"
-- wants that one, "inv layer, not 4621-58389" any layer but that one. Newer versions send the
-- same in a note (see NOTE_PREFIX). Returns the wanted id, the avoided id (either may be nil).
local function namedLayer(msg)
  if isSecret(msg) or type(msg) ~= "string" then return nil, nil end
  local lower = string.lower(msg)
  if not FOREVER then return nil, nil end   -- Classic chat carries NWB numbers, not ids
  local avoid = string.match(lower, "not%s+(%d%d%d+%-%d+)")
  for id in string.gmatch(lower, "(%d%d%d+%-%d+)") do
    if id ~= avoid then return id, avoid end
  end
  return nil, avoid
end

-- Forever, 1.10: the route at the end of the chat line - "inv layer <LS 1431 not 6782-1753>":
-- the asker's zone (its map id) and the layer it leaves, or "want <id>" for one layer. The line
-- arrives on time when the notes do not (10 Oct 2026), and a host answers only a route it can
-- read (see answer). Hosts from 1.0 on read "not <id>" / "want <id>" in it (namedLayer).
-- 1.14.2: the asker's map position closes the tag - "<LS 1429 not 7088-2 48.2,42.5>", percent of
-- the zone map with one decimal (a few yards), x then y - so a host that keeps its spot can judge
-- the distance without a hidden note. Hosts from 1.10 to 1.14.1 read the zone and the layer past
-- it (the zone is the first number, the layer sits after "not"/"want"); "48.2,42.5" matches no id.
local function routeTag(msg)
  if not FOREVER or isSecret(msg) or type(msg) ~= "string" then return nil end
  local body = string.match(msg, "<LS([^<>]*)>")
  if not body then return nil end
  local px, py = string.match(body, "(%d+%.?%d*),(%d+%.?%d*)%s*$")
  local pos
  if px and py then
    local x, y = tonumber(px), tonumber(py)
    if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then pos = { x = x, y = y } end
  end
  -- 1.14.14: an ask for new layers only names the layers the asker has seen after the one it leaves
  local avoids = {}
  for id in string.gmatch(body, "not%s+(%d+%-%d+)") do avoids[#avoids + 1] = id end
  return { zone = string.match(body, "^%s*(%d+)%s") or string.match(body, "^%s*(%d+)%s*$"),
           want = string.match(body, "want%s+(%d+%-%d+)"), avoid = string.match(body, "not%s+(%d+%-%d+)"), avoids = avoids, pos = pos }
end

local function routeText(zone, want, avoid, fx, fy, more)
  local parts = { "<LS" }
  if zone then parts[#parts + 1] = tostring(zone) end
  if want then parts[#parts + 1] = "want " .. want elseif avoid then parts[#parts + 1] = "not " .. avoid end
  -- more: the layers seen in the zone, after the one we leave - a host from 1.14.14 on any of them skips
  -- the ask; an older host reads the first "not" alone
  if not want and avoid and more then
    for _, id in ipairs(more) do parts[#parts + 1] = "not " .. id end
  end
  if zone and fx and fy then parts[#parts + 1] = string.format("%.1f,%.1f", fx * 100, fy * 100) end
  return table.concat(parts, " ") .. ">"
end

-- ---------------------------------------------------------------------------------------
-- may we invite right now?

local function pendingCount()
  local now, n = GetTime(), 0
  for name, at in pairs(pending) do
    if now - at > PENDING_TTL then pending[name] = nil else n = n + 1 end
  end
  return n
end

-- The group as full names, without the player. nil when a member cannot be read.
local function groupMembers()
  local list = {}
  if not IsInGroup() then return list end
  if IsInRaid() then return nil end
  for i = 1, PARTY_MAX - 1 do
    local unit = "party" .. i
    if UnitExists(unit) then
      local name = fullName(unit)
      if not name then return nil end
      list[#list + 1] = name
    end
  end
  return list
end

local function canInvite()
  if ownAskWaiting() then return false, "our own ask waits for an invite" end
  if IsInInstance() then return false, "in an instance" end
  -- 1.14.12: a host on its break (Host.left) invites nobody, and so makes no claim either
  local pause = Host.left(GetTime())
  if pause then
    return false, Host.CAP .. " invites in " .. (Host.WINDOW / 60) .. " min - a break of " .. math.ceil(pause / 60) .. " min"
  end
  local members = groupMembers()
  if not members then return false, "in a raid or a group that cannot be read" end
  for _, name in ipairs(members) do
    if not hosted[name] then return false, "in a group with " .. name .. ", who was not invited by LayerSwap" end
  end
  if #members > 0 and not UnitIsGroupLeader("player") then return false, "not the group leader" end
  if 1 + #members + pendingCount() >= PARTY_MAX then return false, "group is full - /ls kick clears it" end
  return true
end

local function invite(name, source)
  if pending[name] then return end          -- an invite to this player is already out
  local now = GetTime()
  if now - lastInviteAt < INVITE_SPACING then
    C_Timer.After(INVITE_SPACING, function()
      if hosting then invite(name, source) end
    end)
    return
  end
  local ok, why = canInvite()
  if not ok then
    stats.skipped = stats.skipped + 1
    log("skip", name, why, source)
    return
  end
  lastInviteAt, lastInvite[name], pending[name], hosted[name] = now, now, now, true
  if FOREVER and Send.restricted() then Host.sent[#Host.sent + 1] = now end
  watchUntil = now + WATCH_AFTER_INVITE
  stats.invites = stats.invites + 1
  -- No hardware event is behind this call: it runs from a chat event or a timer.
  local called, err = pcall((C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit, name)
  log("invite", name, called and "called" or ("error: " .. tostring(err)), source)
  -- 1.14.14: no chat line for an invite or a guest who joins - the panel counts them, the log names them
end

-- The client's own line for a refusal, with its "%s" (the name) taken out: every part of it in
-- the text. Reads in any language the client runs in.
local function saysGlobal(text, global)
  local s = _G[global]
  if isSecret(s) or type(s) ~= "string" or not string.find(s, "%s", 1, true) then return false end
  local found = false
  for part in string.gmatch(s .. "%s", "(.-)%%s") do
    part = strtrim(part)
    if part ~= "" then
      if not string.find(text, part, 1, true) then return false end
      found = true
    end
  end
  return found
end

-- The game's answer when our invite cannot count: the asker sits in a group already (the one
-- refusal in the logs, 8 Oct 2026: "X is already in a group." - a guest of another host), or
-- another host's invite got there first. nil for anything else.
local function refusal(text)
  local lower = string.lower(text)
  if string.find(lower, "already in a group", 1, true) or saysGlobal(text, "ERR_ALREADY_IN_GROUP_S") then
    return "already in a group"
  end
  if string.find(lower, "already been invited", 1, true) then return "already invited by another host" end
end

-- ---------------------------------------------------------------------------------------
-- host: chat and roster

local refresh = function() end      -- replaced once the panel exists
local refreshMini = function() end  -- replaced once the mini line exists
local mini, toggleMini              -- the small line and its switch, set further down

-- Several hosts hear the same ask, and the game lets one invite through; the others would only
-- put the asker on their cooldown, so the next ask goes unanswered (a user on CurseForge,
-- 9 Oct 2026: "invited by 4 different players at the same time and only one goes through ...
-- if I try to swap again no one invites me"). So a host waits a random moment first and says
-- "claim <asker>" out of sight before inviting. A claim from another host seen meanwhile means
-- that host invites, and this one stays free for the asker's next ask. Hosts older than 1.7
-- make no claim and invite at once; the game's "already been invited" then frees this host.
local CLAIM_WAIT = 1.5            -- the random delay runs up to this many seconds
local claims = {}                 -- [asker] = { by = host, at = GetTime() }

local function sendClaim(name, where)
  local kind, channel = "CHANNEL", GetChannelName(LAYER_CHANNEL)
  if where == "guild" then kind, channel = "GUILD", nil end
  local res = Send.note(kind, channel, "claim " .. name)
  if res ~= nil then log("claim", name, tostring(res), where) end
end


-- 1.14, the option "Skip askers near you" (a user on CurseForge, 23 Oct 2026, farming a spot with
-- Host on): an asker within the distance is skipped, so a swap does not bring someone to the
-- spot this host farms. The asker's position came as a note of its own (see onNote); without
-- one - an older LayerSwap, an ask in General, a note the game has not passed on yet - the ask
-- is skipped too, because a filter that lets through what it cannot read would invite exactly
-- the asker it is for. Each reason has its own log line, so a timing miss can be told from a
-- real skip. The host's own position is read now, at decision time, and never leaves this
-- client. Runs inside the claim delay (see claimThenInvite): a tagged ask is answered in the
-- frame its line arrives, and every asker's note a host ever logged came after its line.
function Near.check(name, where)
  local note = notes[name]
  local p = note and note.pos
  if not (p and note.posAt and note.posAt >= (requestedAt[name] or 0) - 5) then
    stats.skipped = stats.skipped + 1
    log("skip", name, "no position in the ask", where)
    return false
  end
  local here = zoneOf("player")
  if not here then
    stats.skipped = stats.skipped + 1
    log("skip", name, "own position unknown", where)
    return false
  end
  if p.ref ~= tostring(here) then
    -- in another zone the asker stays where it is when the swap moves it: never near (1.14.8)
    log("spot", name, "another zone (map " .. p.ref .. ")", where)
    return true
  end
  local mine = Near.read(p.kind == "posm" and "map" or "world")
  if not mine or mine.kind ~= p.kind then
    stats.skipped = stats.skipped + 1
    log("skip", name, "own position unknown", where)
    return false
  end
  local d = math.floor(Near.between(p, mine) + 0.5)
  log("spot", name, d .. " yards", where, p.kind == "posm" and "from the line" or "from the note")
  if d < Near.yards() then
    stats.skipped = stats.skipped + 1
    log("skip", name, "too close (" .. d .. " yards)", where)
    return false
  end
  return true
end

local function claimThenInvite(name, where)
  -- Classic hosts (AutoLayer) make no claims; a whisper reached only us
  if not FOREVER or where == "whisper" then invite(name, where); return end
  local heardAt = GetTime()
  local near = Near.on()
  -- 1.14.5: where the realm refuses addon chat no claim can travel in a channel, and the asker's
  -- spot came in its line - the invite goes at once. The wait was the whole margin the auto-
  -- inviters on the asker's own layer won by (two of two invites in General, 7 Nov 2026, within
  -- 2 s). A guild claim may still travel, so the guild keeps the wait.
  local direct = Send.restricted() and where ~= "guild"
  local function go()
    if not hosting then Near.settle(name, false); return end
    if near then
      -- the asker's position note has had the delay to arrive; a skip here claims nothing, so it
      -- holds back no other host, and the asker is told that this host does not invite it
      if not Near.check(name, where) then Near.settle(name, false); return end
      Near.settle(name, true)
    end
    local c = claims[name]
    if c and c.at >= heardAt - 0.5 then
      log("yield", name, c.by, string.format("claimed %.1f s ago", GetTime() - c.at), where)
      return
    end
    -- a host that cannot invite makes no claim: it would only hold back a host that can (1.10)
    if pending[name] then return end
    local ok, why = canInvite()
    if not ok then
      stats.skipped = stats.skipped + 1
      log("skip", name, why, where)
      return
    end
    sendClaim(name, where)
    invite(name, where)
    refresh()
  end
  -- with the box on the delay never runs under NOTE_WAIT: an asker's note lands after its line
  -- (32 of 32 logged, up to 0.26 s), and a check in the line's frame would never see it
  local delay = direct and 0 or (near and (NOTE_WAIT + math.random() * (CLAIM_WAIT - NOTE_WAIT)) or (math.random() * CLAIM_WAIT))
  if delay > 0 then C_Timer.After(delay, go) else go() end
end


local answer    -- below: onChat hands a request to it, now or once the note is in
local onSame    -- below: a host's "same" note to the asker, counted with the ask it answers
local onHeard   -- below: a LayerSwap user's "heard" note to the asker, with its layer and zone
local onEcho    -- below: one of our own notes came back - the ask's ping times the game (1.10)

-- With Host off, asks are still counted (the panel says how many asked - Adam, 8 Oct 2026) but
-- never answered. A whisper only counts while hosting: to anyone else "inv" is not a layer ask.
-- Every LayerSwap user who hears an ask says so to the asker, out of sight: its layer, its zone,
-- and whether it hosts (Adam, 8 Oct 2026: the layer channel held 46-56 players and hardly a host;
-- the asker's panel can now say how many LayerSwap users heard it and whether any of them hosts).
-- Only an asker whose zone note is in reads it (1.4 on) - so the reply waits a moment for the
-- note, as the host does - and only once in a while per asker. Same way back as the ask came.
-- Only a user in the asker's zone replies (Adam, 11 Oct 2026): only a host there can move the
-- asker, and every user answering every ask to the whole channel, from any zone, was traffic the
-- asker could not use - our own replies came back 95-180 s late that day.
local HEARD_COOLDOWN = 10
local heardAt = {}              -- [First Surname] = GetTime() of our last reply to them

-- tag: the route the ask carries in its line (1.10, see routeTag), so the asker reads the reply
-- and its zone is known at once - no note to wait for.
-- host: the 4th field of the reply - nil says what hosting says now; a host that skips askers
-- near it answers "-" for an ask it does not invite (1.14), the same as any Host-off user sends.
-- at: the time of the line a held-back reply answers, so its 10 s cooldown counts from the ask
-- and not from the delayed send (the asker's own cooldown is 10 s too: a re-ask the moment its
-- button lights must be answered)
local function replyHeard(where, sender, tag, host, at)
  local function send(zone)
    local here = zoneOf("player")
    if not zone then return end
    if where == "layer" and not (here and tostring(here) == tostring(zone)) then return end
    if heardAt[sender] and GetTime() - heardAt[sender] < HEARD_COOLDOWN then return end
    local kind, channel = "GUILD", nil
    if where == "layer" then kind, channel = "CHANNEL", GetChannelName(LAYER_CHANNEL)
    elseif where == "direct" then kind, channel = "WHISPER", Who.from[sender] or sender end
    if Send.comms[kind] == "refused" then return end
    heardAt[sender] = at or GetTime()
    local flag = host
    if flag == nil then flag = hosting end
    -- a host on its break (Host.left) invites nobody: it answers like a Host-off user (1.14.12)
    if flag and Host.left(GetTime()) then flag = false end
    local text = "heard " .. sender .. "|" .. (current or "-") .. "|" .. (zoneOf("player") or "-") .. "|" .. (flag and "h" or "-")
    local res = Send.note(kind, channel, text)
    if res ~= nil then log("heard", sender, text, tostring(res)) end
  end
  if tag then send(tag.zone); return end
  C_Timer.After(NOTE_WAIT, function()
    local note = notes[sender]
    if note and note.zoneAt and GetTime() - note.zoneAt <= NOTE_TTL then send(note.zone) end
  end)
end

-- A reply held back in onChat (a host with the box on) goes out once, when the ask is settled:
-- "h" when this host answers it like any other ask, "-" when it skips it. Nothing after the
-- first call sends a second one.
Near.settle = function(sender, host)
  local held = Near.later[sender]
  if not held then return end
  Near.later[sender] = nil
  replyHeard(held.where, sender, held.tag, host, held.at)
end

local function onChat(where, msg, sender)
  if not hosting and where == "whisper" then return end
  if isSecret(sender) or type(sender) ~= "string" or sender == "" then
    if hosting then log("skip", "?", "sender not readable", where) end
    return
  end
  sender = withRealm(sender)
  -- NWB and AutoLayer post lines of their own with the word "layer" in them
  if not isSecret(msg) and type(msg) == "string" and (string.find(msg, "^%[NWB%]") or string.find(msg, "^%[AutoLayer%]")) then
    return
  end
  -- Classic: AutoLayer's TBC header carries the asker's zone; its Era prefix ("<AZ> ") is dropped
  local scope
  if not FOREVER and not isSecret(msg) and type(msg) == "string" then
    local z, body = string.match(msg, "^<AL%d+V%d+_%d+_%d+Z(%d+)>%s*(.*)$")
    if z then scope, msg = z, body else msg = string.gsub(msg, "^<%w+> ", "") end
  end
  local wants, reason = isRequest(msg, where)
  if not wants then
    if hosting and where ~= "general" and where ~= "guild" then log("ignored", sender, reason, where) end
    return
  end
  local own = sender == fullName("player")
  -- 1.14.12, live Forever (the realm refuses addon chat): a host answers only the players who ask
  -- through LayerSwap (out of sight), whisper this host or ask in the guild. A line in General or a
  -- channel reaches every host around, and with no claim travelling there several of them invite the
  -- same player at once - an invite the player never asked LayerSwap for, and the kind that gets
  -- reported (players told of Blizzard silences for "spamming group invites", CurseForge, 10 Nov 2026).
  -- Such a line is not counted and not logged.
  if FOREVER and not own and Send.restricted() and where ~= "direct" and where ~= "whisper" and where ~= "guild" then return end
  -- 1.14.14: a LayerSwap that has not read its own layer reads it from the units in view the moment an ask
  -- arrives - after a zone border nothing reads them again by itself, and a host that stands still then
  -- skips every ask. Never within BORDER_QUIET of a border (Who.rescan).
  if FOREVER and not own and not current then Who.rescan() end
  if own then
    Send.echo(where, msg)
    Near.echoLine(msg)
  else
    stats.requests = stats.requests + 1
    if not askers[sender] then askers[sender], stats.askers = true, stats.askers + 1 end
  end
  requestedAt[sender] = GetTime()
  log("request", sender, string.sub(msg, 1, 120), where, (not hosting) and "host off" or nil)
  if not own and FOREVER and (where == "layer" or where == "guild" or where == "direct") then
    if hosting and Near.on() then
      -- the reply waits for the verdict (1.14): the asker reads one reply per user, so it has to
      -- carry whether this host invites it; a timer settles it in any case
      Near.later[sender] = { where = where, tag = routeTag(msg), at = GetTime() }
      C_Timer.After(CLAIM_WAIT + 1, function() Near.settle(sender, hosting) end)
    else
      replyHeard(where, sender, routeTag(msg))
    end
  end
  if not hosting then refresh(); return end
  if own then log("skip", sender, "own message", where); return end
  local last = lastInvite[sender]
  if last and GetTime() - last < PLAYER_COOLDOWN then
    stats.skipped = stats.skipped + 1
    log("skip", sender, "invited less than " .. PLAYER_COOLDOWN .. " s ago", where)
    Near.settle(sender, hosting)
    return
  end
  local want, avoid = namedLayer(msg)
  local note = notes[sender]
  local plainAsk = string.lower(strtrim(msg))
  plainAsk = plainAsk == "inv layer" or (not FOREVER and string.find(plainAsk, "^inv layer[%d%s,%-]*$") ~= nil)
  if not (want or avoid) and not (note and note.at and GetTime() - note.at <= NOTE_TTL) and plainAsk then
    -- LayerSwap's own line, its note not here yet: give it a moment
    C_Timer.After(NOTE_WAIT, function() answer(where, msg, sender, scope) end)
    return
  end
  answer(where, msg, sender, scope)
end

-- The answer to a request that passed the checks: a host is only any use on another layer
-- than the one the asker is leaving, and only on the layer the asker named.
answer = function(where, msg, sender, scope)
  if not hosting then Near.settle(sender, false); return end
  if not FOREVER then
    -- TBC: an invite from a leader in another zone does not move the asker (AutoLayer 1.9.6)
    local here = TBC and scope and scope ~= "0" and mapHere()
    if here and here ~= scope then
      stats.skipped = stats.skipped + 1
      log("skip", sender, "asks from another zone (map " .. scope .. ", we are on " .. here .. ")", where)
      return
    end
    -- AutoLayer's numbers: only a host on one of the NWB layers asked for (or not on the ones
    -- ruled out) is any use
    local numbers, invert = nwbNumbersIn(msg)
    if #numbers > 0 then
      local mine = nwbLayer()
      local listed = false
      for _, n in ipairs(numbers) do if n == mine then listed = true end end
      local note = notes[sender]
      local noted = note and note.at and GetTime() - note.at <= NOTE_TTL   -- a LayerSwap asker: its note decides below
      if (mine and listed == invert) or (not mine and not noted) then
        stats.skipped = stats.skipped + 1
        log("skip", sender, (invert and "not " or "wants ") .. "NWB layer " .. table.concat(numbers, ",") ..
          ", we are on " .. (mine and ("Layer " .. mine) or "an NWB layer we do not know"), where)
        return
      end
    end
  end
  local want, avoid = namedLayer(msg)
  local note = notes[sender]
  -- Forever: the game moves a guest only to a host in the guest's own zone. Measured 7-9 Oct
  -- 2026 with the host's zone read from the group: every host in another zone moved nobody (6
  -- of 6 by 10 Oct). A LayerSwap asker names its zone - in the line from 1.10 (the tag), in a
  -- note from 1.4 - and a host elsewhere stays out, so the asker is not sent into a group that
  -- changes nothing (a user on CurseForge, 10 Oct 2026).
  local tag = routeTag(msg)
  local zone
  if tag then
    zone, want, avoid = tag.zone, tag.want, tag.avoid
    if tag.pos then Near.fromTag(sender, tag, sender); note = notes[sender] end
  elseif FOREVER and note and note.zoneAt and GetTime() - note.zoneAt <= NOTE_TTL then
    zone = note.zone
  end
  -- 1.14.8 invited askers from the realm search in any zone; measured 8 Nov 2026 23:21 on live, the
  -- game moved nobody (a host in Elwynn, the asker in Westfall). Own zone only again, by any route.
  if zone then
    local here = zoneOf("player")
    if not here then
      stats.skipped = stats.skipped + 1
      log("skip", sender, "own zone unknown (the asker is on map " .. zone .. ")", where)
      Near.settle(sender, hosting)
      return
    end
    if tostring(here) ~= zone then
      stats.skipped = stats.skipped + 1
      log("skip", sender, "asks from another zone (map " .. zone .. ", we are on " .. here .. ")", where)
      Near.settle(sender, hosting)
      return
    end
  elseif FOREVER and where ~= "whisper" and where ~= "general" then
    -- 1.10: no zone, no invite. Before, a host whose note had not come invited anyway, from
    -- wherever it stood (10 Oct 2026: the notes came minutes late, and every invite that day
    -- came from another zone). General is the zone's own channel, so its askers stand in ours;
    -- a whisper asked this host by name.
    stats.skipped = stats.skipped + 1
    log("skip", sender, "no zone in the ask", where)
    Near.settle(sender, hosting)
    return
  end
  if not tag and not (want or avoid) and note and note.at and GetTime() - note.at <= NOTE_TTL then
    want, avoid = note.want, note.avoid
  end
  if want and not Layer.same(want, current) then
    stats.skipped = stats.skipped + 1
    log("skip", sender, "wants " .. want .. ", we are on " .. (current or "an unknown layer"), where)
    Near.settle(sender, hosting)
    return
  end
  if avoid and not current then
    -- the asker leaves a layer this host cannot rule out standing on: an invite from that very
    -- layer changes nothing, so it waits for an ask a host on another layer answers (1.9)
    stats.skipped = stats.skipped + 1
    log("skip", sender, "own layer unknown (the asker leaves " .. avoid .. ")", where)
    Near.settle(sender, hosting)
    return
  end
  if avoid and Layer.same(avoid, current) then
    stats.skipped = stats.skipped + 1
    log("skip", sender, "already on our layer " .. avoid, where)
    Near.settle(sender, hosting)
    -- the asker's zone and layer: say so out of sight, so the asker knows a host heard it and
    -- why no invite comes (instead of two minutes of waiting)
    local to = (where == "direct" and Who.from[sender]) or (note and note.from)
    if zone and to then
      local res = Send.note("WHISPER", to, "same")
      if res ~= nil then log("note", "same to " .. sender, tostring(res)) end
    end
    return
  end
  -- 1.14.14: an ask for new layers only - this host stands on a layer the asker has seen
  if tag and tag.avoids and current then
    for i = 2, #tag.avoids do
      if Layer.same(tag.avoids[i], current) then
        stats.skipped = stats.skipped + 1
        log("skip", sender, "on a layer the asker has seen " .. tag.avoids[i], where)
        Near.settle(sender, hosting)
        return
      end
    end
  end
  claimThenInvite(sender, where)
end

-- A note from an asker: kept a few seconds for the chat line that follows it. The asker
-- sends the note first, so it is normally here before the line; one that comes after is
-- logged, to see whether that ever happens.
local function onNote(text, sender)
  if isSecret(text) or isSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
  -- Forever: "First Surname-Realm" -> "First Surname"; Classic keeps "Name-Realm"
  local name = FOREVER and string.match(sender, "^([^%-]+)") or withRealm(sender)
  if not name then return end
  if name == fullName("player") then
    log("note", "came back", text)
    onEcho(text)
    Near.echo(text)
    return
  end
  -- another host claims an asker (see claimThenInvite)
  local claimed = string.match(text, "^claim (.+)$")
  if claimed then
    claims[claimed] = { by = name, at = GetTime() }
    if hosting then log("claimed", claimed, name) end
    return
  end
  -- a LayerSwap user heard our ask: "heard <asker>|<layer>|<zone>|<h or ->" (see replyHeard)
  local target, layer, zone, host = string.match(text, "^heard (.-)|([^|]*)|([^|]*)|([^|]*)$")
  if target then
    if target == fullName("player") then
      Who.from[name] = sender   -- the name as the game gives it, for a whisper back (Who.anyway)
      onHeard(name, layer ~= "-" and layer or nil, zone ~= "-" and zone or nil, host == "h")
    end
    return
  end
  -- the asker's position (1.14): "pos <zone map id> <x> <y>" in yards, kept with the asker's other
  -- notes for a host that skips askers near it (Near.check). Only a note of this host's own kind
  -- counts ("pos" = world yards, "posm" = map yards): two frames are never compared. Hosts
  -- older than 1.14 drop it below, at the gate that drops anything but want, not and any.
  local pKind, pRef, px, py = string.match(text, "^(pos%a?) (%d+) (%-?%d+) (%-?%d+)$")
  if pKind then
    local was = notes[name]
    -- only this host's own frame, and only yards a zone can hold (world coordinates stay within
    -- about 20,000): anything else is no position, and a filter without one fails closed
    local x, y = tonumber(px), tonumber(py)
    local pos = ((pKind == "pos" or pKind == "posm") and x and y and math.abs(x) <= 100000 and math.abs(y) <= 100000)
      and { kind = pKind, ref = pRef, x = x, y = y } or nil
    -- a note of neither kind leaves a position the line already gave (1.14.2)
    local posAt = pos and GetTime() or nil
    if not pos and was and was.pos then pos, posAt = was.pos, was.posAt end
    notes[name] = { want = was and was.want, avoid = was and was.avoid, at = was and was.at,
                    zone = was and was.zone, zoneAt = was and was.zoneAt, from = sender,
                    pos = pos, posAt = posAt }
    if hosting then
      local late = requestedAt[name] and GetTime() - requestedAt[name] < NOTE_TTL
      log("note", name, text, late and "after the chat line" or nil)
    end
    return
  end
  local kind, id = string.match(text, "^(%a+)%s*(%S*)$")
  id = (id ~= "" and id) or nil
  -- a host in our zone on our layer heard our ask (see answer)
  if kind == "same" then onSame(name); return end
  -- the asker's zone, a note of its own just before the layer note (1.4): hosts older than
  -- that read only want/not/any and go on as before
  local old = notes[name]
  if kind == "zone" then
    notes[name] = { want = old and old.want, avoid = old and old.avoid, at = old and old.at,
                    zone = id, zoneAt = GetTime(), from = sender,
                    pos = old and old.pos, posAt = old and old.posAt }
    return
  end
  if kind ~= "want" and kind ~= "not" and kind ~= "any" then return end
  notes[name] = { want = kind == "want" and id or nil, avoid = kind == "not" and id or nil, at = GetTime(),
                  zone = old and old.zone, zoneAt = old and old.zoneAt, from = sender,
                  pos = old and old.pos, posAt = old and old.posAt }
  if hosting then
    local late = requestedAt[name] and GetTime() - requestedAt[name] < NOTE_TTL
    log("note", name, text, late and "after the chat line" or nil)
  end
end

-- How long a guest stays: someone who leaves within seconds believes the move holds after
-- leaving; the phase API could not tell who was moved (beta 26 Sep 2026: 4 of 4 guests read
-- "same shard" at the join and 5 s later).
local guestSince = {}           -- [fullName] = GetTime() of the join, while in our group

-- An invite from while we hosted can be accepted long after (160 s on 11 Oct 2026). Accepted
-- with Host off by then, it is undone: no LayerSwap group with Host off (Adam, 11 Oct 2026).
local LATE_ACCEPT = 300

local function onRoster()
  local members = groupMembers()
  if not members then return end
  local names, present, now = {}, {}, GetTime()
  for _, name in ipairs(members) do
    names[#names + 1] = name
    present[name] = true
    if not hosting and hosted[name] and not came[name] and lastInvite[name] and now - lastInvite[name] <= LATE_ACCEPT
       and UnitIsGroupLeader("player") then
      pending[name], hosted[name] = nil, nil
      local ok, err = pcall((C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit, name)
      log("kick", name, ok and "called" or tostring(err), "accepted with Host off")
      say(name .. " accepted an invite from before Host was turned off - removed from the group.")
    elseif pending[name] then
      pending[name], came[name] = nil, true
      stats.joined = stats.joined + 1
      guestSince[name] = now
      log("joined", name, string.format("%.1f s after the invite", now - (lastInvite[name] or now)))
      Who.phase("guest")
      Who.phaseSoon("guest")
    end
  end
  for name, since in pairs(guestSince) do
    if not present[name] then
      guestSince[name] = nil
      log("guestLeft", name, string.format("%d s after joining", math.floor(now - since + 0.5)))
    end
  end
  log("roster", table.concat(names, ", "), #members)
  refresh()
end

-- The players LayerSwap invited, out of the group. Returns how many.
-- Only in a group we lead: in another host's group (our own swap) the leader may be someone we
-- once invited, and a guest removed is forgotten, so the next Host off does not try again.
local function removeHosted(why)
  local members = groupMembers() or {}
  if #members == 0 or not UnitIsGroupLeader("player") then return 0 end
  local n = 0
  for _, name in ipairs(members) do
    if hosted[name] then
      local ok, err = pcall((C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit, name)
      log("kick", name, ok and "called" or tostring(err), why)
      hosted[name], came[name], pending[name] = nil, nil, nil
      n = n + 1
    end
  end
  return n
end

local function kickHosted()
  local n = removeHosted("/ls kick")
  say(n == 0 and "nobody to remove." or ("removed " .. n .. " hosted player(s)."))
end

-- 1.14.7: Host is on at every login, and the player's off lasts until the logout (Adam, 8 Nov 2026:
-- the requests by hidden whisper reach only LayerSwap users, so every one of them who hosts is a way
-- out for the next asker). The off is kept across a /reload, which is no logout. While it is off, the
-- panel's status line says why it is on - in the panel, not in chat (Adam, 8 Nov 2026).
local HOST_OFF_LINE = "Host off until you log out. Host on helps LayerSwap players change layer."
local function setHosting(on)
  hosting = on
  LayerSwapDB.hosting = on and true or false
  log("hosting", hosting and "on" or "off")
  if not on then
    -- with Host off, no LayerSwap group (Adam, 11 Oct 2026): the guests it invited go with it
    local n = removeHosted("host off")
    if n > 0 then say("Host off: removed " .. n .. (n == 1 and " player" or " players") .. " LayerSwap invited.") end
  end
  -- only ever reached from a slash command or a click, so a hardware event is behind it:
  -- the one place a channel can be joined
  Send.joins()
  refresh()
end

-- ---------------------------------------------------------------------------------------
-- which layer is this?
--
-- The game has no layer API. A creature's GUID is Creature-0-[server]-[map]-[zoneUID]-[npc]-
-- [spawn], and server + zoneUID change when the world is refreshed (measured 19 Sep 2026:
-- three different pairs in Elwynn in one evening, and one of them came back unchanged).
-- Pets carry the pair of the place they were summoned, so only creatures are read, and a
-- layer is only believed when two different creatures agree.

local VOTES = 5
local LAYER_TTL = 3600          -- a layer not seen for an hour leaves the list
local layers = {}               -- [id] = { id, n, letter, zone, first, last }; kept in SavedVariables, times are time()
local layerCount = 0
-- The entry a reading belongs to: a layer already known in this zone keeps its first id.
function Layer.canon(id)
  if not FOREVER or id == nil or layers[id] then return id end
  local zone = Layer.zone()
  for other, l in pairs(layers) do
    if l.zone == zone and Layer.key(other) == Layer.key(id) then return other end
  end
  return id
end
local votes, votedGuid = {}, {}
local evictAt                  -- GetTime() when the server will move the player, if announced

local swap                      -- the running request: { at, from, inviter, joinedAt }
local swapGroup = false         -- true while in a group that was joined through a request
local leftInfo                  -- { at, layer }: set when such a group is left, until the next layer reading
-- In the beta, leaving the host's group undid the swap (19 and 24 Sep 2026). On live Forever the new
-- layer stays (9 Nov 2026 10:55 and 11:48, 10 Nov 13:10), so from 1.14.14 LayerSwap leaves the group of a
-- LayerSwap host by itself Layer.LEAVE_AFTER seconds after the move is confirmed, and the host is free for
-- the next player. A group joined on an invite sent by hand (no reply to our ask) is left to the player.
local notice, noticeUntil       -- one line for the panel, kept a little while
local held                      -- { host, from, to } after a swap, while in the host's group

local function layerLabel(id)
  local l = id and (layers[id] or layers[Layer.canon(id)])
  if not l then return "Unknown layer" end
  if l.nwb and not FOREVER then return "Layer " .. l.nwb end
  return "Layer " .. l.letter
end

-- A layer we have stood on for a while takes NWB's number: NWB itself records nothing for
-- 180 s after a group join, and needs a moment after a move. The number belongs to one layer
-- of the zone at a time (NWB renumbers when it learns a new layer).
local currentSince, joinedGroupAt = 0, -1000
local lastShardAt = -1000      -- GetTime() of the last SHARD_TRANSFER, for the group log
local function noteNwb()
  local n = nwbLayer()
  local l = n and current and layers[current]
  if not l or l.nwb == n then return end
  local now = GetTime()
  if now - currentSince < 20 or now - joinedGroupAt < 180 then return end
  for id, other in pairs(layers) do
    if not Layer.same(id, current) and other.nwb == n and other.zone == l.zone then other.nwb = nil end
  end
  l.nwb = n
end

local function letterFor(n)
  if n <= 26 then return string.char(64 + n) end
  return tostring(n)
end

local function forgetSightings()
  votes, votedGuid = {}, {}
end

-- 9 Nov 2026, live, 11:48: 0.3 s after the game moved the player, the nameplates still held creatures of
-- the layer just left, and a scan read them as the player's layer - "Layer C" for 17 s, and no
-- "swapped". The creatures in view when the game moves a player whose layer was known are the old
-- layer's: they do not count for STALE_FOR seconds (a creature of the new layer has another GUID).
Layer.STALE_FOR = 10
function Layer.markStale()
  if not current then return end
  local guids = {}
  for guid in pairs(votedGuid) do guids[guid] = true end
  local function add(unit)
    local okE, there = pcall(UnitExists, unit)
    if not (okE and there == true) then return end
    local guid = UnitGUID(unit)
    if not isSecret(guid) and type(guid) == "string" then guids[guid] = true end
  end
  for i = 1, 40 do add("nameplate" .. i) end
  add("target")
  add("mouseover")
  Layer.stale = { untilAt = GetTime() + Layer.STALE_FOR, guid = guids }
end

local function setNotice(text, seconds)
  notice, noticeUntil = text, GetTime() + (seconds or 30)
end

local function setCurrent(id)
  if Layer.same(id, current) then return end
  local now = GetTime()
  local l = layers[id]
  if not l then
    layerCount = layerCount + 1
    l = { id = id, n = layerCount, letter = letterFor(layerCount), first = time() }
    layers[id] = l
  end
  l.last, l.zone = time(), Layer.zone()
  local from = current
  current, currentSince = id, now
  log("layer", id, l.letter, from)
  -- the border probe: the layer read after a zone border, against the one before it
  local cr = Who.crossing
  if cr and cr.from and now - cr.at <= Who.BORDER_FOR and cr.reads < Who.BORDER_READS and l.zone ~= cr.from
     and not (swap and swap.joinedAt) then
    cr.reads = cr.reads + 1
    log("border", cr.from .. " > " .. tostring(l.zone), cr.layer .. " > " .. id, Layer.same(id, cr.layer) and "same layer" or "other layer",
      string.format("%.0f s after", now - cr.at))
  end
  Who.here = { zone = l.zone, layer = id }
  -- the layer we asked from belongs to another zone: we walked on, the host did not move us (1.14.8) -
  -- the transfer event fires after every zone border too, so it proves nothing here
  local asked = swap and swap.from and layers[swap.from]
  local walked = asked and asked ~= l and asked.zone and l.zone and asked.zone ~= l.zone
  if swap and swap.joinedAt and swap.from and not Layer.same(swap.from, id) and not walked then
    -- the request worked: say so, and hand the host their group back
    log("swapped", swap.from, id, string.format("%.1f s after joining%s", now - swap.joinedAt,
      swap.want and (", asked for " .. swap.want) or ""))
    -- the host answered our ask as a LayerSwap user: its group is left by itself (see above)
    local auto = FOREVER and Send.restricted() and swap.inviter ~= nil and swap.replies ~= nil and swap.replies[swap.inviter] ~= nil
    if swap.want and not Layer.same(swap.want, id) then
      -- a host who invites by hand may stand anywhere
      say("you are now on " .. layerLabel(id) .. " - not the " .. layerLabel(swap.want) .. " you asked for.")
      setNotice("You are on " .. layerLabel(id) .. ", not " .. layerLabel(swap.want) .. ".", 60)
    elseif FOREVER then
      say("you are now on " .. layerLabel(id) .. (auto and " - LayerSwap leaves the group for you, the layer stays."
        or " - you can leave the group, the layer stays."))
      notice = nil   -- a warning about an earlier invite must not hide the line that says the swap worked
    else
      -- Classic keeps the new layer after the group is left; AutoLayer asks its guests to leave
      say("you are now on " .. layerLabel(id) .. " - you can leave the group.")
      setNotice("On " .. layerLabel(id) .. " now - you can leave the group.", 60)
    end
    if FOREVER then held = { host = swap.inviter, from = swap.from, to = id, auto = auto or nil } end
    swap = nil
    if auto then
      log("autoLeave", held.host, id, "moved")
      C_Timer.After(Layer.LEAVE_AFTER, function()
        if swapGroup and held and held.auto and IsInGroup() then pcall(leaveParty) end
      end)
    end
  end
  if leftInfo then
    -- what did leaving the host's group do to the layer?
    log("afterLeave", leftInfo.layer or "unknown", id, string.format("%.1f s after leaving", now - leftInfo.at))
    leftInfo = nil
  end
  refresh()
end

local function observe(unit)
  local guid = UnitGUID(unit)
  if isSecret(guid) or type(guid) ~= "string" then return end
  local kind, _, server, _, zoneUID = strsplit("-", guid)
  if (kind ~= "Creature" and kind ~= "Vehicle") or not server or not zoneUID then return end
  -- a player's own summons (totems, guardians) are Creatures too, and carry the place they were made
  if type(UnitPlayerControlled) == "function" then
    local okP, pc = pcall(UnitPlayerControlled, unit)
    if okP and not isSecret(pc) and pc == true then return end
  end
  local stale = Layer.stale
  if stale and GetTime() < stale.untilAt and stale.guid[guid] then return end
  local id = server .. "-" .. zoneUID
  -- read after joining a host and still on our layer, each creature once (1.14.8): one already seen
  -- before the join counts too - still in view after it, the join did not move us
  if swap and swap.joinedAt and Layer.same(id, current) then
    swap.readGuid = swap.readGuid or {}
    if not swap.readGuid[guid] then
      swap.readGuid[guid] = true
      swap.fresh = (swap.fresh or 0) + 1
      if swap.fresh == Who.FRESH then refresh() end
    end
  end
  if votedGuid[guid] then return end
  votedGuid[guid] = true
  votes[#votes + 1] = id
  if #votes > VOTES then table.remove(votes, 1) end
  local count = 0
  for _, v in ipairs(votes) do if Layer.same(v, id) then count = count + 1 end end
  if Layer.same(id, current) then
    layers[current].last = time()
  elseif count >= (current and 3 or 2) then
    -- Two creatures are enough while nothing is known (after a refresh the sightings start
    -- from zero). Leaving a layer that is believed takes a majority of the last five: a
    -- pair of patrols that wandered in from the next zone must not flip it.
    setCurrent(Layer.canon(id))
  end
end

-- ---------------------------------------------------------------------------------------
-- asking for a swap. Always called from a click or a slash command: a channel message needs
-- a hardware event.

local SWAP_COOLDOWN = 10
local SWAP_TTL = 120            -- seconds a request waits for an invite
-- The Swap button turns into Stop asking while a request waits; for the first second it does
-- nothing, so a double click on Swap layer cannot ask and stop in one go.
local STOP_AFTER = 1
-- A stopped ask still counts for the cooldown, so Swap, Stop, Swap cannot post a line every two
-- seconds (beta 8 Oct 2026: three asks in four seconds from one player). GetTime() of the ask
-- that was stopped, and of its guild ask.
local stopped = { at = -1000, guildAt = -1000 }

-- Joining a host on another layer moves the player about 1.3 s later (SHARD_TRANSFER, beta
-- 19 Sep 2026). None within this many seconds: the host stands on the player's own layer - a
-- player who invites by hand cannot read the note (beta 25 Sep 2026: invited, joined, no move).
local SAME_LAYER_AFTER = 5
-- A host in our zone (or one whose zone is unknown) that has not moved us by then: LayerSwap
-- leaves its group only this long after the join (1.10). Every move so far came 1.1-1.4 s after
-- the join, but on 10 Oct 2026 the server answered minutes late, and leaving undoes a move.
local SAME_LAYER_LEAVE = 15

-- Hosts who did not move us, by name: { at, layer, elsewhere }. The invite carries no layer, and
-- a host who invites by hand invites again (the same host twice in 4 min, beta 27 Sep 2026).
-- Such a host's next invite is named in chat and in the panel; declining it is the player's
-- (1.9 declined it by itself; 1.10 does not - see warnInvite).
local SAME_HOST_TTL = 600
local sameHosts = {}

-- The game now and then stops the channel message even on a click (ADDON_ACTION_BLOCKED,
-- "UNKNOWN()": 2 of 7 asks in the beta, 25 Sep 2026). The event fires during the send, so
-- the ask can tell it went nowhere.
local sendingAsk, askHeldBack = false, false

-- The ask's own ping (see requestSwap): no echo within this many seconds, or a later one, and
-- the panel says the game is slow with addon messages - invites came late that day too.
local LAG_AFTER = 5
local pingCount = 0

-- The note for an ask, into the layer channel. Not a protected call; the result is logged
-- so the beta shows whether addon messages reach the channel at all.
local function sendNote(note, kind, channel)
  if not note then return nil end
  local res = Send.note(kind, channel, note)
  if res ~= nil then log("note", "sent", note, tostring(res)) end
  return res
end

-- Forever: our zone goes ahead of the layer note, so only a host in this zone answers.
local function sendZone(kind, channel)
  local here = FOREVER and zoneOf("player")
  if here then sendNote("zone " .. here, kind, channel) end
end

-- 1.14: the asker's position goes first in the burst, as a note of its own. A host that skips
-- askers near it reads it (Near.check); every other host drops it. Sent first because a dropped
-- zone or layer note costs a 1.10 host nothing - the line carries both - while a missing
-- position makes that host skip the ask. The raw readings go to the log every time.
function Near.send(label, kind, channel)
  if not FOREVER then return end
  -- the probe has never run in a game client: whatever it meets, the ask itself goes out
  local ok, p, why = pcall(Near.probe, label)
  if not ok then log("pos", "error", tostring(p)); return end
  if p then sendNote(p.kind .. " " .. p.ref .. " " .. p.x .. " " .. p.y, kind, channel)
  else log("pos", "unreadable", why) end
end

-- One ask in one place (kind = CHANNEL with its number, or GUILD), from a click. Returns true
-- when it went out; otherwise it says so (button = the label to click again) and returns false
-- plus the reason for the log.
local function sendAsk(text, kind, channel, button)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  sendingAsk, askHeldBack = true, false
  local ok, err = pcall(send, text, kind, nil, channel)
  sendingAsk = false
  if askHeldBack or not ok then
    -- button: the label to click again, or the command to type again ("/ls guild")
    local again = (string.sub(button, 1, 1) == "/" and "type " or "click ") .. button .. " again."
    local line = askHeldBack and ("The game held back your request - " .. again)
      or ("Your request did not go out - " .. again)
    setNotice(line, 15)
    say(line)
    return false, askHeldBack and "held back" or tostring(err)
  end
  return true
end

-- The layers seen in this zone within the hour, newest first, without the current one - the
-- ones that can be asked for. Layers not seen for an hour are dropped on the way.
local function seenInZone()
  local seen, today, zone = {}, time(), Layer.zone() or ""
  for id, l in pairs(layers) do
    if today - l.last > LAYER_TTL then
      if not Layer.same(id, current) then layers[id] = nil end
    elseif not Layer.same(id, current) and l.zone == zone then seen[#seen + 1] = l end
  end
  table.sort(seen, function(a, b) return a.last > b.last end)
  return seen
end

-- 1.14.14: their ids, the newest SEEN_MAX, for an ask that wants a new layer only; and whether a layer is one of a list
function Layer.seen()
  local zone, today, list = Layer.zone() or "", time(), {}
  for id, l in pairs(layers) do
    if not Layer.same(id, current) and l.zone == zone and type(l.last) == "number" and today - l.last <= LAYER_TTL then
      list[#list + 1] = id
    end
  end
  table.sort(list, function(a, b) return layers[a].last > layers[b].last end)
  for i = #list, Layer.SEEN_MAX + 1, -1 do list[i] = nil end
  return list
end

function Layer.inList(id, list)
  if not id or type(list) ~= "table" then return false end
  for _, other in ipairs(list) do
    if Layer.same(id, other) then return true end
  end
  return false
end

-- The zone's name when no other layer has been seen in it within the hour: a 'same layer'
-- verdict there may mean the zone has only one layer right now, and no host can move anyone.
-- (Beta, 27 Sep 2026: four hosts in a row on the player's layer in Westfall, where one layer
-- was ever seen; in Elwynn Forest next door, with three, the move came.)
local function onlyLayerHere()
  local zone = Layer.zone()
  if isSecret(zone) or type(zone) ~= "string" or zone == "" or #seenInZone() > 0 then return nil end
  return zone
end

-- The host's zone, read from the group we joined: its map id, nil when the game does not say.
local function hostZone(name)
  if not (FOREVER and name) then return nil end
  for i = 1, PARTY_MAX - 1 do
    local unit = "party" .. i
    if UnitExists(unit) and fullName(unit) == name then return zoneOf(unit) end
  end
end

-- In the host's group, and the game did not move us: the host is on our layer - or, when the
-- group says so, in another zone, from where no host moves anyone (swap.elsewhere: its name).
local function hostOnOurLayer(now)
  if not FOREVER then return false end   -- no transfer event on Classic: no way to tell
  local base = swap ~= nil and swap.joinedAt ~= nil and swapGroup and not held
  local yes = base and not swap.transferAt and now - swap.joinedAt >= SAME_LAYER_AFTER and (swap.fresh or 0) >= Who.FRESH
  -- 1.14.14: the game refreshed the world after the join, and the layer read since is the one we asked from
  -- (live, 11 Nov 2026: a transfer 0.9 s after joining, the same layer 5 s later - the host was moved, not
  -- the guest). Not moved: said once the units of the layer left are out of doubt (Layer.STALE_FOR).
  if base and not yes and swap.transferAt and current and swap.from and Layer.same(current, swap.from)
     and now - swap.transferAt >= Layer.STALE_FOR + 2 then
    yes, swap.refreshed = true, true
  end
  if yes and not swap.sameLogged then
    swap.sameLogged = true
    local here, there = zoneOf("player"), hostZone(swap.inviter)
    if here and there and there ~= here then
      swap.elsewhere = zoneName(there) or "another zone"
      log("otherZone", swap.inviter, current, "no transfer " .. SAME_LAYER_AFTER .. " s after joining", swap.elsewhere)
    else
      log("sameLayer", swap.inviter, current,
        swap.refreshed and "world refreshed, same layer" or ("no transfer " .. SAME_LAYER_AFTER .. " s after joining"),
        onlyLayerHere() and "the only layer seen in this zone" or nil)
      if swap.inviter and current then sameHosts[swap.inviter] = { at = now, layer = current } end
    end
  end
  return yes
end

-- target: the id of the layer wanted, or nil for any layer but this one
-- via: the control that asked (button, row, menu, slash, again) - for the log
-- leaving: the player is on the way out of a group (Leave and ask again)
-- Returns "held" when the game stopped the message; the caller then says nothing more.
local function askText(target, wantNumber, header, more)
  local text = "inv layer"
  if FOREVER then
    -- the route, in the line (1.10): our zone, and the layer named or the one we leave - and,
    -- since 1.14.2, where we stand on the zone map (Near.fraction; left out when unreadable)
    local zone = zoneOf("player")
    local fx, fy
    if zone then
      local ok, a, b = pcall(Near.fraction, zone)
      if ok and a then fx, fy = a, b end
    end
    return text .. " " .. routeText(zone, target, (not target) and current or nil, fx, fy, more)
  else
    -- Classic: the NWB numbers AutoLayer hosts read - all but ours, or the one picked
    local numbers = {}
    local wanted = wantNumber or (target and layers[target] and layers[target].nwb)
    if wanted then
      numbers = { wanted }
    elseif not target then
      local mine, count = nwbLayer(), nwbLayerCount()
      if mine and count then
        for n = 1, count do if n ~= mine then numbers[#numbers + 1] = n end end
      end
    end
    if #numbers > 0 then text = "inv layer " .. table.concat(numbers, ",") end
    if TBC and header then text = autoLayerHeader() .. " " .. text end
  end
  return text
end

-- How many players the layer channel holds, for the status line after an ask (Adam, 8 Oct 2026:
-- "how many does my click reach?"). Unmeasured on Forever: each source is logged at every ask.
-- The count includes the player. nil while unknown.
local channelCount

-- The layer channel's place in the game's channel list, and the member count listed there.
local function layerDisplay()
  if type(GetNumDisplayChannels) ~= "function" or type(GetChannelDisplayInfo) ~= "function" then return nil end
  local okN, n = pcall(GetNumDisplayChannels)
  if not okN or isSecret(n) or type(n) ~= "number" then return nil end
  for i = 1, n do
    local ok, name, _, _, _, count = pcall(GetChannelDisplayInfo, i)
    if ok and not isSecret(name) and type(name) == "string" and string.lower(name) == LAYER_CHANNEL then
      return i, (not isSecret(count) and type(count) == "number") and count or nil
    end
  end
end

local function readChannelCount(why)
  local i, count = layerDisplay()
  local members
  if type(GetNumChannelMembers) == "function" then
    local ok, m = pcall(GetNumChannelMembers, GetChannelName(LAYER_CHANNEL))
    members = ok and not isSecret(m) and type(m) == "number" and m or nil
  end
  log("channelCount", why, i or "not listed", count or "no count", members or "no member count")
  channelCount = count or members or channelCount
  -- asks the server for the channel's roster; the answer comes as CHANNEL_COUNT_UPDATE
  if i and type(SetSelectedDisplayChannel) == "function" then pcall(SetSelectedDisplayChannel, i) end
end

local function onChannelCount(ev, index, count)
  local i = layerDisplay()
  if not i or isSecret(index) or index ~= i or isSecret(count) or type(count) ~= "number" then return end
  if count ~= channelCount then log("channelCount", ev, i, count) end
  channelCount = count
  refresh()
end

-- 9 Nov 2026: a look at the player's channels once a minute (Forever only), written to the log and
-- nowhere else: number, name and the member count the game lists, with the layer and the zone.
-- Whether a channel's members follow the layer shows itself without a second account - General's
-- count jumping when the layer changes, a channel's name (LookingForGroup 40) changing its number.
-- The game is asked for the counts of General and LookingForGroup with the roster request
-- SetSelectedDisplayChannel makes (as readChannelCount does), one after the other, and the player's
-- own selection in the channel window put back. The log keeps 300 entries free for the rest.
Layer.CENSUS_EVERY, Layer.CENSUS_FIRST, Layer.CENSUS_ROOM, Layer.CENSUS_GAP = 60, 20, 700, 2
function Layer.census()
  if not FOREVER or type(GetNumDisplayChannels) ~= "function" or type(GetChannelDisplayInfo) ~= "function" then return end
  if type(LayerSwapDB.log) == "table" and #LayerSwapDB.log >= Layer.CENSUS_ROOM then return end
  local okN, n = pcall(GetNumDisplayChannels)
  if not okN or isSecret(n) or type(n) ~= "number" then return end
  local parts, ask = {}, {}
  for i = 1, math.min(n, 24) do
    local ok, name, header, _, number, count = pcall(GetChannelDisplayInfo, i)
    if ok and header ~= true and not isSecret(name) and type(name) == "string" then
      local lower = string.lower(name)
      if string.find(lower, "^general") or string.find(lower, "^lookingforgroup") then ask[#ask + 1] = i end
      parts[#parts + 1] = ((not isSecret(number) and type(number) == "number" and number > 0) and (number .. " ") or "") .. name
        .. " " .. ((not isSecret(count) and type(count) == "number") and count or "?")
    end
  end
  local zone = Layer.zone()
  log("channels", current or "unknown", (not isSecret(zone) and type(zone) == "string" and zone ~= "") and zone or "?",
    string.sub(table.concat(parts, "; "), 1, 400))
  -- the counts for the next look: one channel at a time, then the player's own selection back
  if #ask == 0 or type(SetSelectedDisplayChannel) ~= "function" then return end
  local was
  if type(GetSelectedDisplayChannel) == "function" then
    local okS, sel = pcall(GetSelectedDisplayChannel)
    if okS and not isSecret(sel) and type(sel) == "number" and sel > 0 then was = sel end
  end
  for k, i in ipairs(ask) do
    C_Timer.After((k - 1) * Layer.CENSUS_GAP, function() pcall(SetSelectedDisplayChannel, i) end)
  end
  if was then C_Timer.After(#ask * Layer.CENSUS_GAP, function() pcall(SetSelectedDisplayChannel, was) end) end
end

-- 1.14.13: a measuring tool, so only for a player who switched it on in the saved data
-- (/run LayerSwapDB.census = true, then /reload) - not something every client asks the game for.
function Layer.startCensus()
  if not FOREVER or Layer.censusOn or LayerSwapDB.census ~= true then return end
  Layer.censusOn = true
  local function again()
    Layer.census()
    C_Timer.After(Layer.CENSUS_EVERY, again)
  end
  C_Timer.After(Layer.CENSUS_FIRST, again)
end

-- ---------------------------------------------------------------------------------------
-- 1.14.2: how the ask leaves the player (see the Send table at the top)

-- Does this realm let an addon post a chat line? Forever only: the Classic clients know the
-- function too, but there the lines go out, and nothing here changes for them.
function Send.restricted()
  if not FOREVER then return false end
  local f = C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
  if type(f) ~= "function" then return false end
  local ok, v = pcall(f)
  return ok and not isSecret(v) and v == true
end

-- One note (addon message), through a gate per kind: the first answer the client gives decides
-- whether this kind is sent again this session. 4 (not that chat type) and 7 (no such channel)
-- close a kind - 7 only for a channel the game lists as joined, since a channel still joining
-- answers 7 too; every other answer leaves the gate as it is. nil when nothing was sent.
function Send.note(kind, channel, text)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return nil end
  if kind == "CHANNEL" and (not channel or channel == 0) then return nil end
  if kind == "GUILD" and not IsInGuild() then return nil end
  if Send.comms[kind] == "refused" then return nil end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, text, kind, channel)
  if not ok then return "error: " .. tostring(res) end
  if isSecret(res) then return "secret" end
  local state
  if res == 0 then state = "ok"
  elseif res == 4 then state = "refused"
  elseif res == 7 then state = (kind ~= "CHANNEL" or layerDisplay() ~= nil) and "refused" or nil end
  if state and Send.comms[kind] ~= state then
    Send.comms[kind] = state
    log("comms", kind, state, tostring(res))
  end
  return res
end

-- General's number: the client says it; else the first joined channel the game calls a zone
-- channel of kind 1. Never the name - it is translated.
function Send.generalId()
  local f = C_ChatInfo and C_ChatInfo.GetGeneralChannelLocalID
  if type(f) == "function" then
    local ok, id = pcall(f)
    if ok and not isSecret(id) and type(id) == "number" and id > 0 then return id end
  end
  local info = C_ChatInfo and C_ChatInfo.GetChannelInfoFromIdentifier
  if type(info) ~= "function" then return nil end
  local max = (Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatChannels) or 20
  for i = 1, max do
    local ok, id, name = pcall(GetChannelName, i)
    if ok and not isSecret(id) and type(id) == "number" and id > 0 and not isSecret(name) and type(name) == "string" then
      local okI, c = pcall(info, name)
      if okI and type(c) == "table" and not isSecret(c) and not isSecret(c.zoneChannelID) and c.zoneChannelID == 1 then return id end
    end
  end
end

-- The layer channel as the game sees it for us: "ok" (numbered, listed, open), "not joined",
-- "not listed" (a join the server has not completed), "closed" (a notice refused it this
-- session) or "disabled" (the game keeps the account on the channel without a voice - the state
-- a refused line leaves behind on the live realms, on every character of the account).
function Send.layerState()
  local id = GetChannelName(LAYER_CHANNEL)
  if isSecret(id) or type(id) ~= "number" or id == 0 then return "not joined", 0 end
  if Send.layerClosed then return "closed", id end
  if Send.layerDisabled() then return "disabled", id end
  if layerDisplay() == nil then return "not listed", id end
  return "ok", id
end

-- The game's own flag for a channel the account may not use (GetChannelList: id, name, disabled).
function Send.layerDisabled()
  return Send.channelDisabled(LAYER_CHANNEL)
end

function Send.channelDisabled(channel)
  if type(GetChannelList) ~= "function" then return false end
  local ok, list = pcall(function() return { GetChannelList() } end)
  if not ok or type(list) ~= "table" then return false end
  for i = 1, #list, 3 do
    local name, disabled = list[i + 1], list[i + 2]
    if not isSecret(name) and type(name) == "string" and string.lower(name) == string.lower(channel) then
      return not isSecret(disabled) and disabled == true
    end
  end
  return false
end

-- Where the line goes. 1.14.3: General - the zone's own channel, which nobody owns and the game
-- cannot close to one account the way it closed the layer channel to many on the live realms.
-- 1.14.4: LayerSwap's own channel ahead of it whenever we sit in it (see Send.HUB); General when
-- the hub is not there for us, or when notHub asks for it (Ask in General). The layer channel only
-- when neither is, and only while it is usable. "hub"/"general"/"layer" and the number, or nothing.
function Send.target(notHub)
  local hub, hubId = Send.hubState()
  if hub == "ok" and not notHub and Send.HUB_ASKS then return "hub", hubId end
  local g = Send.generalId()
  if g then return "general", g end
  local state, id = Send.layerState()
  if state == "ok" then return "layer", id end
  return nil
end

-- Our zone as the hub's tables key it ("?" while the game does not say).
function Send.zoneKey()
  return tostring(zoneOf("player") or "?")
end

-- The place a request goes, in the panel's words.
function Send.placeName(where)
  if where == "hub" then return "LayerSwap's channel" end
  if where == "direct" then return "players across the realm, by hidden whisper" end
  if where == "general" then return "General" end
  if where == "guild" then return "your guild" end
  if where == "layer" then return "the layer channel" end
  return "nowhere - join General"
end

function Send.isHub(name)
  return not isSecret(name) and type(name) == "string" and string.lower(name) == string.lower(Send.HUB)
end

-- A channel by name in the game's own list (the Social window's): a join the server has not
-- completed is numbered but not listed (launch night, 5 Nov 2026).
function Send.listed(channel)
  if type(GetNumDisplayChannels) ~= "function" or type(GetChannelDisplayInfo) ~= "function" then return false end
  local okN, n = pcall(GetNumDisplayChannels)
  if not okN or isSecret(n) or type(n) ~= "number" then return false end
  for i = 1, n do
    local ok, name = pcall(GetChannelDisplayInfo, i)
    if ok and not isSecret(name) and type(name) == "string" and string.lower(name) == string.lower(channel) then return true end
  end
  return false
end

-- The hub as the game sees it for us, like the layer channel (Send.layerState), and its number.
function Send.hubState()
  local id = GetChannelName(Send.HUB)
  if isSecret(id) or type(id) ~= "number" then id = 0 end
  if Send.hubClosed then return "closed", id end
  if id == 0 then return "not joined", 0 end
  if Send.channelDisabled(Send.HUB) then return "disabled", id end
  if not Send.listed(Send.HUB) then return "not listed", id end
  return "ok", id
end

-- Out of every chat window: the addon reads the hub, nobody else.
function Send.hideHub()
  Send.hubHidden = true
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    if type(frame) == "table" then
      if type(frame.RemoveChannel) == "function" then pcall(frame.RemoveChannel, frame, Send.HUB)
      elseif type(ChatFrame_RemoveChannel) == "function" then pcall(ChatFrame_RemoveChannel, frame, Send.HUB) end
    end
  end
end

-- The player's /leave of the hub, kept per character (LayerSwapDB is the account's: one alt's
-- automatic rejoin must not undo another's /leave).
function Send.left()
  local t = LayerSwapDB.hubLeft
  return type(t) == "table" and t[fullName("player")] == true
end

function Send.setLeft(on)
  if type(LayerSwapDB.hubLeft) ~= "table" then LayerSwapDB.hubLeft = {} end
  LayerSwapDB.hubLeft[fullName("player")] = on or nil
end

function Send.realmKey()
  local ok, r = pcall(GetRealmName)
  return (ok and not isSecret(r) and type(r) == "string" and r ~= "") and r or "?"
end

-- The realm's hub refused us: a password or a ban someone set holds a day, a refusal of our own
-- join or line an hour (1.14.5; the game's own rejoin refused with nothing of ours out marks
-- nothing, see Send.hubNotice). No click asks again meanwhile, so nobody meets the game's
-- password box at every session. The mark is the moment the hold ends.
function Send.realmRefused()
  local r = type(LayerSwapDB.hubRefused) == "table" and LayerSwapDB.hubRefused[Send.realmKey()]
  return type(r) == "number" and time() < r
end

function Send.refusedLeft()
  local r = LayerSwapDB.hubRefused[Send.realmKey()] - time()
  return r >= 3600 and (math.ceil(r / 3600) .. " h") or (math.ceil(r / 60) .. " min")
end

function Send.refused(hold)
  hold = hold or 86400
  if type(LayerSwapDB.hubRefused) ~= "table" then LayerSwapDB.hubRefused = {} end
  LayerSwapDB.hubRefused[Send.realmKey()] = time() + hold
  if not Send.refusedSaid then
    Send.refusedSaid = true
    say("LayerSwap's channel refused you on this realm - requests go to General " .. (hold >= 86400 and "for a day." or "for the next hour."))
  end
end

-- Into the hub, from a click (Send.joins): once a session, never after the player left it (a
-- /leave is the player's word) or the realm's hub refused us, and only where the realm refuses
-- addon chat.
function Send.joinHub()
  if not Send.HUB_ASKS or not Send.restricted() or Send.hubTried or Send.left() or Send.realmRefused() then return end
  local id = GetChannelName(Send.HUB)
  if not isSecret(id) and type(id) == "number" and id > 0 then
    if not Send.hubHidden then Send.hideHub() end
    return
  end
  Send.hubTried, Send.hubTriedAt = true, GetTime()
  local join = JoinPermanentChannel or JoinChannelByName
  if type(join) ~= "function" then return end
  local ok, err = pcall(join, Send.HUB)
  log("hub", "join", ok and "asked" or tostring(err))
end

-- The click that may join a channel (any LayerSwap control). On a realm that refuses addon chat
-- the hub, never the layer channel: the game bars an account from that one after a refused line,
-- and a refused join shows the same red line (one of Adam's characters, 7 Nov 2026, at Host on).
-- Elsewhere the layer channel, for a host.
function Send.joins()
  if Send.restricted() then Send.joinHub(); return end
  if hosting and GetChannelName(LAYER_CHANNEL) == 0 then pcall(JoinChannelByName, LAYER_CHANNEL) end
end

-- 1.14.4: an ask nobody answered is not sent again to the same place from the same zone within
-- REPEAT_WAIT - the same hosts heard it, and a second line only fills the channel. After an
-- invite (one that did not move us), from another zone or to another place it may go at once.
-- The seconds left, or nil.
function Send.repeatLeft(now, where)
  local l = where and Send.lastAt[where]
  if not (l and not l.invited and l.zone == Send.zoneKey()) then return nil end
  local left = Send.REPEAT_WAIT - (now - l.at)
  return left > 0 and left or nil
end

-- Our last ask in the hub from this zone went unanswered and is still within its repeat wait: the
-- next ask, from any control, goes to General - the hub had its chance - and to the hub after.
function Send.hubSpent(now)
  local l = Send.lastAt.hub
  return l ~= nil and not l.invited and l.zone == Send.zoneKey() and now - l.at >= Send.HUB_WAIT and now - l.at < Send.REPEAT_WAIT
end

-- Where a click's line goes (requestSwap), and where the panel says it goes. With both places
-- asked and unanswered, the hub, whose wait ends first.
function Send.place(now, via)
  return Send.target(via == "fallback" or (Send.hubSpent(now) and not Send.repeatLeft(now, "general")))
end

-- An ask in the hub no host has invited by HUB_WAIT: logged once, and the Swap button offers
-- General (Send.offerGeneral); with the panel closed, chat says it.
function Send.hubCheck(s)
  if swap ~= s or (s.inviter and not s.inviterSeen) or s.joinedAt or s.missed then return end
  s.missed = true
  local direct = s.where == "direct"
  log("ask", direct and "no invite from the zone's players" or "no invite from the hub", current, s.want, Send.HUB_WAIT .. " s")
  local pf = _G.LayerSwapPanel
  if not (type(pf) == "table" and pf:IsShown()) and Send.generalId() then
    say(direct and "no host on another layer has answered yet - Ask in General in the panel (/ls) puts the request in General too."
      or "no invite from LayerSwap's channel yet - Swap layer or /ls swap asks in General now.")
  end
  refresh()
end

-- The hub's ask waits past HUB_WAIT without an invite, from the zone we still stand in, and
-- General is there to ask instead.
-- 1.14.6: never after an ask by hidden whisper - General holds only the asker's own layer (every
-- invite through it came from there), so it moves nobody (Adam, 8 Nov 2026: "General will not help").
function Send.offerGeneral(now)
  return swap ~= nil and swap.where == "hub" and not (swap.inviter and not swap.inviterSeen)
    and not swap.joinedAt and not Send.pending and now - swap.at >= Send.HUB_WAIT and now - swap.at <= SWAP_TTL and swap.zone == Send.zoneKey() and Send.generalId() ~= nil
end

-- The chat box back to the type it had before a hub line (Send.preSend): CHANNEL is sticky, so the
-- send leaves the box on the hub, where the player's next lines would vanish unseen. Only when
-- the send left it on the hub, and only to a type known from before.
function Send.restoreBox(box, prev)
  if type(box) ~= "table" or type(box.GetStickyType) ~= "function" or type(box.SetStickyType) ~= "function" then return end
  local ok, sticky = pcall(box.GetStickyType, box)
  local okT, target = pcall(box.GetChannelTarget, box)
  if not (ok and sticky == "CHANNEL" and okT and target == prev.hub) then return end
  if prev.sticky == "CHANNEL" and prev.channel == nil then return end
  pcall(box.SetStickyType, box, prev.sticky)
  if type(box.SetChatType) == "function" then pcall(box.SetChatType, box, prev.sticky) end
  if prev.sticky == "CHANNEL" and type(box.SetAttribute) == "function" then pcall(box.SetAttribute, box, "channelTarget", prev.channel) end
  if type(box.IsShown) == "function" and box:IsShown() and type(box.UpdateHeader) == "function" then pcall(box.UpdateHeader, box) end
  log("box", "back to", prev.sticky)
end

-- 1.14.4: other players' LayerSwap requests stay out of the chat windows - the addon reads them
-- from the event, not from a window, so a host answers as before. Our own request in General still
-- shows; every line of the hub is hidden, as the hub is. true hides the line.
function Send.filterLine(_, _, msg, author, _, _, _, _, _, _, base)
  if Send.isHub(base) then return true end
  if isSecret(msg) or type(msg) ~= "string" then return false end
  -- our tag's own shape: "<LS>", or a zone number, "want" or "not" first ("<LSD>" or "<LS Raiders>"
  -- closing a line is somebody's guild)
  local body = string.match(msg, "<LS([^<>]*)>%s*$")
  if not body or not (body == "" or string.find(body, "^ %d") or string.find(body, "^ want %d") or string.find(body, "^ not %d")) then return false end
  if isSecret(author) or type(author) ~= "string" or author == "" then return true end
  return withRealm(author) ~= fullName("player")
end

function Send.filterNotice(_, _, _, _, _, _, _, _, _, _, base)
  return Send.isHub(base)
end

-- The chat edit box the line goes into.
function Send.editBox()
  local f = ChatFrameUtil and ChatFrameUtil.GetActiveWindow
  local box = type(f) == "function" and select(2, pcall(f)) or nil
  if type(box) ~= "table" then box = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox end
  if type(box) ~= "table" then box = _G.ChatFrame1EditBox end
  return type(box) == "table" and box or nil
end

function Send.boxText()
  local box = Send.editBox()
  if not (box and type(box.GetText) == "function") then return nil end
  local ok, s = pcall(box.GetText, box)
  if ok and not isSecret(s) and type(s) == "string" then return s end
  return nil
end

-- The line into the chat box, one frame later (a slash command runs inside the box's own send,
-- which empties the box right after; a frame later it is free). The pending line is remembered
-- until its own echo comes back (Send.echo) or the box has let go of it (Send.tick).
function Send.box(line, kind, channel, where, ask)
  local prefix = kind == "GUILD" and (SLASH_GUILD1 or "/g") or ("/" .. tostring(channel))
  local text = prefix .. " " .. line
  Send.count = Send.count + 1
  Send.pending = { id = Send.count, body = line, text = text, where = where, kind = kind, channel = channel,
                   from = ask.from, want = ask.want, via = ask.via, at = GetTime() }
  notice = nil   -- a notice from before the click must not stand in for the line's own instruction
  log("ask", "in the box", current, ask.want, (ask.via or "?") .. " " .. where)
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if type(open) ~= "function" then
    setNotice("Type this in chat: " .. text, 60)
    return
  end
  local id = Send.count
  C_Timer.After(0, function()
    if not (Send.pending and Send.pending.id == id) then return end
    -- the box OpenChat will use, as it stands before our line (Send.restoreBox)
    local chooser = ChatFrameUtil and ChatFrameUtil.ChooseBoxForSend
    if type(chooser) == "function" then
      local ok, box = pcall(chooser, DEFAULT_CHAT_FRAME)
      if ok and type(box) == "table" and type(box.GetAttribute) == "function" then
        local okA, target = pcall(box.GetAttribute, box, "channelTarget")
        Send.pending.box, Send.pending.prevChannel = box, (okA and not isSecret(target)) and target or nil
      end
    end
    pcall(open, text, DEFAULT_CHAT_FRAME)
  end)
  if not Send.ticker and C_Timer.NewTicker then Send.ticker = C_Timer.NewTicker(1, Send.tick) end
end

-- The line is dropped: nothing went out. The box is emptied only when it still holds our line.
function Send.drop(why, line)
  local p = Send.pending
  if not p then return end
  Send.pending = nil
  local s = Send.boxText()
  if s and string.find(s, p.body, 1, true) then
    local box = Send.editBox()
    if box and type(box.SetText) == "function" then pcall(box.SetText, box, "") end
  end
  log("ask", "dropped", current, p.want, why)
  if line then setNotice(line, 15) end
  refresh()
end

-- Once a second while a line is pending: as long as the box holds it the player can still send
-- it, however long that takes; once it is gone (sent or Escape) the echo has ECHO_WAIT to come.
function Send.tick()
  local p = Send.pending
  if not p then
    if Send.ticker then Send.ticker:Cancel(); Send.ticker = nil end
    return
  end
  local now = GetTime()
  local s = Send.boxText()
  if s == nil then
    if now - p.at > Send.BOX_TTL then Send.drop("box unreadable", "Request not sent - click Swap layer and press Enter.") end
    return
  end
  if string.find(s, p.body, 1, true) then
    p.seen, p.goneAt = true, nil
    return
  end
  if not p.seen then
    if now - p.at >= 2 then Send.drop("never in the box", "Open the chat box, then click Swap layer again.") end
    return
  end
  p.goneAt = p.goneAt or now
  if now - p.goneAt >= Send.ECHO_WAIT then Send.drop("no echo", "Request not sent - click Swap layer and press Enter.") end
end

-- Blizzard's own hook just before the box sends: the Enter is noted (the log tells a line never
-- sent from one the realm refused), the box counts as having held the line (an Enter before the
-- ticker's first look must not read as "never in the box"), and a guild line's notes go ahead of it.
function Send.preSend(box)
  local p = Send.pending
  if not (p and box and type(box.GetText) == "function") then return end
  local ok, s = pcall(box.GetText, box)
  if ok and type(s) == "string" and string.find(s, p.body, 1, true) then
    p.enterAt, p.seen = GetTime(), true
    log("box", "enter", p.where)
    -- 1.14.4: the sticky type is still the one from before our line here (Blizzard sets it after the
    -- send): a frame later the box goes back to it
    if p.where == "hub" and type(box.GetStickyType) == "function" then
      local okS, sticky = pcall(box.GetStickyType, box)
      local prev = { sticky = (okS and not isSecret(sticky) and type(sticky) == "string") and sticky or "SAY",
                     channel = (p.box == box) and p.prevChannel or nil, hub = p.channel }
      C_Timer.After(0, function() Send.restoreBox(box, prev) end)
    end
    -- /ls guild: the guild's notes - position, zone, layer - leave here, right before the line,
    -- where a 1.14/1.14.1 guild host with the box on expects them. Once per line, and never in a
    -- way that can stop Blizzard's send.
    if p.kind == "GUILD" and not p.notesAt then
      p.notesAt = GetTime()
      pcall(function()
        Near.send("guild", "GUILD")
        sendZone("GUILD")
        sendNote((p.want and ("want " .. p.want)) or (p.from and ("not " .. p.from)) or "any", "GUILD")
      end)
    end
  end
end

-- Our own line came back (onChat): the ask is out. A line that carries our tag starts the wait
-- even when nothing was pending any more (an Enter long after the click); a plain "inv layer" of
-- ours in the pending channel counts too. An ask already waiting is left alone.
function Send.echo(where, msg)
  local now = GetTime()
  local p = Send.pending
  local tag = routeTag(msg)
  if not (tag or (p and p.where == where)) then return end
  if not p and swap and not swap.joinedAt and now - swap.at <= SWAP_TTL then return end
  local from = p and p.from or current
  local want = p and p.want or (tag and tag.want) or nil
  if where == "guild" then
    if swap and not swap.joinedAt then swap.at, swap.guildAt = now, now
    else swap = { at = now, from = from, want = want, guildAt = now } end
  else
    if swap and not swap.joinedAt and swap.guildAt then swap.at, swap.channel = now, true
    else swap = { at = now, from = from, want = want, channel = true } end
  end
  -- a guild line on top of a channel ask leaves the channel's place standing (the bottom line and
  -- Ask in General read it)
  if where ~= "guild" or not swap.where or swap.where == "guild" then swap.where, swap.zone = where, Send.zoneKey() end
  log("ask", "sent by you", current, want, where .. (tag and "" or " without the tag"))
  if where == "layer" then readChannelCount("ask") end
  if where ~= "guild" then Send.lastAt[where] = { zone = swap.zone, at = now } end
  if where == "hub" then
    local s = swap
    C_Timer.After(Send.HUB_WAIT, function() Send.hubCheck(s) end)
  end
  Send.pending, notice = nil, nil
  refresh()
end

-- The world moved or a group came while a line waited for its Enter: the line names a place
-- that is no longer ours, so it is dropped.
function Send.moved(line)
  if Send.pending then Send.drop("moved", line) end
  Who.moved(line)
end

-- What the server says about a channel (CHAT_MSG_CHANNEL_NOTICE and _USER). The layer channel
-- and General are the two that matter; each kind of notice is logged once per channel per
-- session, with a count, and never more than 20 kinds - the live client asks to join a zone
-- channel every 0.27 s and is refused each time.
function Send.notice(kind, channelName, zoneChannelID, index, base)
  if isSecret(kind) or type(kind) ~= "string" then return end
  local name = (not isSecret(base) and type(base) == "string" and base ~= "") and base
    or ((not isSecret(channelName) and type(channelName) == "string") and (string.gsub(channelName, "^%d+%.%s*", "")) or "")
  local layer = string.lower(name) == LAYER_CHANNEL
  local general = not isSecret(zoneChannelID) and zoneChannelID == 1
  local key = kind .. "|" .. string.lower(name)
  local e = Send.notices[key]
  if e then
    e.n = (e.n or 1) + 1
    e.c = e.n .. " times, last " .. date("%H:%M:%S")
  elseif Send.noticeCount < 20 then
    Send.noticeCount = Send.noticeCount + 1
    e = log("notice", kind, name ~= "" and name or "?", nil, (not isSecret(index) and index ~= nil) and tostring(index) or nil)
    if e then e.n = 1; Send.notices[key] = e end
  end
  if Send.isHub(name) then Send.hubNotice(kind); return end
  if not (layer or general) then return end
  local p = Send.pending
  if kind == "YOU_JOINED" or kind == "YOU_CHANGED" then
    if layer then Send.layerClosed = nil; Send.comms.CHANNEL = nil end
  elseif kind == "YOU_LEFT" then
    if layer and p and p.where == "layer" then Send.drop("left the channel", "You left the layer channel - click Swap layer again.") end
  elseif kind == "NOT_ALLOWED_IN_CHANNEL" or kind == "MUTED" or kind == "NOT_MEMBER" or kind == "BANNED" or kind == "WRONG_PASSWORD" then
    if layer then
      Send.layerClosed = true
      if p and p.where == "layer" then
        local id = Send.generalId()
        if id then
          Send.box(p.body, "CHANNEL", id, "general", p)
          setNotice("The layer channel refused your line - it is set for General now, press Enter.", 20)
          refresh()
        else
          Send.drop(kind, "The layer channel refused your line, and you are not in General - type /join general, then click Swap layer again.")
        end
      elseif Send.direct and swap and not swap.joinedAt and swap == Send.direct.swap and GetTime() - Send.direct.at < 5 then
        -- a line LayerSwap sent itself was refused: nothing went out, so the wait it started ends,
        -- and the same line goes into the box for the player's own Enter
        swap = nil
        local direct = Send.direct
        Send.direct = nil
        log("ask", "refused by the realm", current, direct.want, kind)
        local id = Send.generalId()
        Send.box(direct.line, "CHANNEL", id or direct.channel, id and "general" or "layer", direct)
        setNotice("The game refused LayerSwap's line - it is in the chat box now, press Enter.", 20)
        refresh()
      end
    elseif general and p and p.where == "general" then
      Send.drop(kind, "This realm does not let you post the request here.")
    end
  elseif kind == "TRIAL_RESTRICTED" then
    if p then Send.drop(kind, "Your account cannot post in this channel (trial restriction).") end
  elseif kind == "THROTTLED" then
    if p then setNotice("The channel is throttled - wait a moment, then press Enter.", 15); refresh() end
  end
end

-- What the server says about the hub (from Send.notice, logged there).
function Send.hubNotice(kind)
  local p = Send.pending
  if not Send.HUB_ASKS then
    -- read, never asked (1.14.6): the game's own rejoin at login stays out of the chat windows,
    -- nothing is said, and Send.notice has logged a refusal already
    if kind == "YOU_JOINED" or kind == "YOU_CHANGED" then Send.hubClosed = nil; Send.hideHub()
    elseif Send.REFUSED[kind] then Send.hubClosed = true end
    return
  end
  if kind == "YOU_JOINED" or kind == "YOU_CHANGED" then
    local back = Send.left()
    Send.hubClosed, Send.refusedSaid = nil, nil
    Send.setLeft(nil)
    if type(LayerSwapDB.hubRefused) == "table" then LayerSwapDB.hubRefused[Send.realmKey()] = nil end
    Send.hideHub()
    if back then
      say("back in LayerSwap's channel: requests go there again.")
    elseif not LayerSwapDB.hubSaid then
      LayerSwapDB.hubSaid = true
      say("joined LayerSwap's own channel, kept out of your chat windows: requests go there, so General stays free of them.")
    end
  elseif kind == "YOU_LEFT" then
    Send.setLeft(true)
    if p and p.where == "hub" then Send.drop("left the channel", "You left LayerSwap's channel - click Swap layer again.")
    else say("left LayerSwap's channel: requests go to General now. /join " .. Send.HUB .. " brings it back.") end
  elseif Send.REFUSED[kind] then
    Send.hubClosed = true
    local ours = (p and p.where == "hub") or (Send.hubTriedAt ~= nil and GetTime() - Send.hubTriedAt < 5)
    if kind == "BANNED" or kind == "WRONG_PASSWORD" then Send.refused()
    elseif ours then Send.refused(3600)
    else
      -- the game's own rejoin at login, refused (1.14.5): this session; the next login tries again
      log("hub", "refused at rejoin", kind)
      if not Send.refusedSaid then
        Send.refusedSaid = true
        say("LayerSwap's channel refused you - requests go to General until it lets you back in.")
      end
    end
    if p and p.where == "hub" then
      local id = Send.generalId()
      if id then
        Send.box(p.body, "CHANNEL", id, "general", p)
        setNotice("LayerSwap's channel refused your line - it is set for General now, press Enter.", 20)
        refresh()
      else
        Send.drop(kind, "LayerSwap's channel refused your line, and you are not in General - type /join general, then click Swap layer again.")
      end
    end
  elseif kind == "TRIAL_RESTRICTED" then
    if p then Send.drop(kind, "Your account cannot post in this channel (trial restriction).") end
  elseif kind == "THROTTLED" then
    if p then setNotice("The channel is throttled - wait a moment, then press Enter.", 15); refresh() end
  end
end

-- ---------------------------------------------------------------------------------------
-- 1.14.6: the ask without a channel (see the Who table at the top)

-- Does this client and realm offer the way? Forever, where the realm refuses addon chat, with the
-- player search and the addon whisper both there, and the whispers not refused this session.
function Who.can()
  if not (FOREVER and Send.restricted()) or Who.refused then return false end
  local f = C_FriendList
  return type(f) == "table" and type(f.SendWho) == "function" and type(f.GetNumWhoResults) == "function"
    and type(f.GetWhoInfo) == "function" and C_ChatInfo ~= nil and type(C_ChatInfo.SendAddonMessage) == "function"
end

-- The search's answers back to the chat, for the player's own /who - unless one of the game's who
-- lists is open and wants them. Only once our question is answered (Who.release): an answer that
-- comes after a stop or a timeout would otherwise land in the player's chat.
function Who.uiBack()
  local f = C_FriendList and C_FriendList.SetWhoToUi
  if type(f) ~= "function" then return end
  for _, name in ipairs({ "LFGWhoListFrame", "WhoFrame" }) do
    local frame = _G[name]
    if type(frame) == "table" and type(frame.IsVisible) == "function" and select(2, pcall(frame.IsVisible, frame)) == true then return end
  end
  pcall(f, false)
end

-- The game's own who lists that open their window on any who answer while the social system is off
-- (Forever's group finder, LFGWhoListMixin:UpdateWhoList; the old Friends window): out of the event
-- while our question is out, unless the player has that list open, and back after it.
Who.LISTS = { "LFGWhoListFrame", "FriendsFrame" }
function Who.hush()
  Who.muted = Who.muted or {}
  for _, name in ipairs(Who.LISTS) do
    local frame = _G[name]
    if type(frame) == "table" and not Who.muted[name] and type(frame.IsEventRegistered) == "function" and type(frame.UnregisterEvent) == "function" then
      local okR, reg = pcall(frame.IsEventRegistered, frame, "WHO_LIST_UPDATE")
      local okV, seen = pcall(frame.IsVisible, frame)
      if okR and reg == true and okV and seen ~= true and pcall(frame.UnregisterEvent, frame, "WHO_LIST_UPDATE") then Who.muted[name] = frame end
    end
  end
end

-- Our question is done with: answered, or given up LATE seconds after it went out.
function Who.release(p)
  if p and Who.inFlight ~= p then return end
  Who.inFlight = nil
  for name, frame in pairs(Who.muted or {}) do
    pcall(frame.RegisterEvent, frame, "WHO_LIST_UPDATE")
    Who.muted[name] = nil
  end
  Who.uiBack()
end

-- The search, from a click (the one moment the game answers an addon's /who): the players of the
-- zone, on every layer of the realm. Returns true when the game took the question; otherwise
-- false and why, and the click goes the old way.
-- What this click asks: our own zone, then the zone one level band at a time (BANDS slices), in
-- turn - only a host in our zone moves us. Without a zone name the level range of the realm.
function Who.filter(zone)
  local okM, m = pcall(GetMaxPlayerLevel)
  local max = okM and not isSecret(m) and tonumber(m) or nil
  if not max or max < 10 then max = 60 end
  Who.band = ((Who.band or -1) + 1) % (Who.BANDS + 1)
  local z = zone and ('z-"' .. zone .. '"') or nil
  if Who.band == 0 then return z or ("1-" .. max) end
  local size = math.ceil(max / Who.BANDS)
  local lo = (Who.band - 1) * size + 1
  local band = lo .. "-" .. math.min(max, lo + size - 1)
  return z and (z .. " " .. band) or band
end

-- The creatures around us, read for the layer (observe): the nameplates the game shows, the
-- target and the mouseover. After a join they tell whether it moved us (1.14.8).
function Who.scan()
  for i = 1, 40 do
    local unit = "nameplate" .. i
    local ok, there = pcall(UnitExists, unit)
    if ok and there == true then observe(unit) end
  end
  observe("target")
  observe("mouseover")
end

-- What the game says of each group member's phase (8 Nov 2026, a probe): UnitPhaseReason answers
-- Sharding for a member on another layer - the party frame's phase icon - so after a join it may
-- tell at once whether the host can move us. Logged only; nothing decides on it yet.
Who.PHASE = { [0] = "phasing", [1] = "sharding", [2] = "war mode", [3] = "chromie time", [4] = "world tier", [5] = "ruleset" }
function Who.shard(unit)
  if type(UnitInPartyShard) ~= "function" then return "no api" end
  local ok, v = pcall(UnitInPartyShard, unit)
  if not ok then return "error" end
  if isSecret(v) then return "secret" end
  return v and "in" or "out"
end

function Who.phase(label)
  if not FOREVER then return nil end
  local parts = {}
  for i = 1, PARTY_MAX - 1 do
    local unit = "party" .. i
    local okE, there = pcall(UnitExists, unit)
    if okE and there == true then
      local reason = "no api"
      if type(UnitPhaseReason) == "function" then
        local ok, r = pcall(UnitPhaseReason, unit)
        if not ok then reason = "error"
        elseif isSecret(r) then reason = "secret"
        elseif r == nil then reason = "none"
        else reason = Who.PHASE[r] or tostring(r) end
      end
      local okL, lead = pcall(UnitIsGroupLeader, unit)
      parts[#parts + 1] = (fullName(unit) or unit) .. ((okL and lead == true) and " (lead)" or "") .. ": " .. reason
        .. ", party shard " .. Who.shard(unit) .. ", map " .. tostring(zoneOf(unit) or "?")
    end
  end
  if #parts == 0 then return nil end
  local line = table.concat(parts, "; ")
  log("phase", label, line, "me: party shard " .. Who.shard("player") .. ", map " .. tostring(zoneOf("player") or "?"), current)
  return line
end

function Who.phaseSoon(label)
  for _, s in ipairs({ 2, 10 }) do
    C_Timer.After(s, function() if IsInGroup() then Who.phase(label .. " +" .. s .. " s") end end)
  end
end

-- What this click asks: the players on our zone's map, then the map one class at a time (the
-- label is what the log shows); the zone by name where the map is unknown or the client refused it.
-- The zone's name goes along in the text, as the group finder's own list lets a player type one: a
-- server that ignored the map would still narrow the answer to the zone, as before the map.
function Who.query(zone, map)
  if map and not Who.noMap then
    Who.round = ((Who.round or -1) + 1) % (#Who.CLASSES + 1)
    local cls = Who.round > 0 and Who.CLASSES[Who.round] or nil
    return zone and ('z-"' .. zone .. '"') or "", { classIDs = cls and { cls } or {}, raceIDs = {}, uiMapIDs = { map } },
      "map " .. map .. (cls and (" class " .. cls) or "")
  end
  local f = Who.filter(zone)
  return f, nil, f
end

function Who.rescan()
  if GetTime() - (Who.borderAt or -1000) < Who.BORDER_QUIET then return end
  Who.scan()
end

function Who.ask(ask)
  local zone = Layer.zone()
  if isSecret(zone) or type(zone) ~= "string" or zone == "" then zone = nil end
  Who.count = (Who.count or 0) + 1
  local text, filters, label = Who.query(zone, zoneOf("player"))
  -- 1.14.14: an ask for new layers only names the layers seen in this zone (Layer.seen)
  for name, at in pairs(Who.sentTo) do
    if GetTime() - at > 60 then Who.sentTo[name] = nil end
  end
  local more = ask.fresh and not ask.want and Layer.seen() or nil
  if more and #more == 0 then more = nil end
  local p = { id = Who.count, from = ask.from, want = ask.want, via = ask.via, at = GetTime(), zone = Send.zoneKey(),
              zoneName = zone, line = askText(ask.want, nil, true, more), filter = label, sent = 0, rounds = 0, seen = more }
  Who.pending, Who.inFlight = p, p
  Who.hush()
  if type(C_FriendList.SetWhoToUi) == "function" then pcall(C_FriendList.SetWhoToUi, true) end
  local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
  local ok, err
  if filters then
    ok, err = pcall(C_FriendList.SendWho, text, origin, filters)
    if not ok then
      -- this client takes no map filter: the zone by name from now on
      Who.noMap = true
      log("who", "map filter refused", tostring(err))
      text, filters = Who.filter(zone), nil
      p.filter = text
    end
  end
  if not filters then ok, err = pcall(C_FriendList.SendWho, text, origin) end
  if not ok then
    Who.pending = nil
    Who.release(p)
    return false, "SendWho: " .. tostring(err)
  end
  C_Timer.After(Who.LATE, function() Who.release(p) end)
  Who.lastAt = p.at
  notice = nil
  log("who", "asked", p.filter, ask.via)
  C_Timer.After(Who.WAIT, function() Who.timeout(p) end)
  return true
end

-- No answer to the search within WAIT: nothing went out, and the click is free again.
function Who.timeout(p)
  if Who.pending ~= p or p.names then return end
  Who.pending = nil
  log("who", "no answer", p.filter, Who.WAIT .. " s")
  local line = "The search for players got no answer - click Swap layer again in a moment."
  setNotice(line, 15)
  say(line)
  refresh()
end

-- The game's answer (WHO_LIST_UPDATE): the names, without our own, and the first burst. Only the
-- answer to our own question in flight; one that comes after a stop or a timeout is swallowed. The
-- players of our own zone go first: a host there can also say it stands on our layer (1.14.8).
function Who.results()
  local q = Who.inFlight
  if not q then return end
  local p = Who.pending
  local mine = p == q and not p.names
  local okN, n, total = pcall(C_FriendList.GetNumWhoResults)
  if not okN or isSecret(n) or type(n) ~= "number" then n = 0 end
  if isSecret(total) or type(total) ~= "number" then total = n end
  local me, names, others, seen, unread, areas = fullName("player"), {}, {}, {}, 0, {}
  for i = 1, (mine and math.min(n, Who.MAX) or 0) do
    local ok, info = pcall(C_FriendList.GetWhoInfo, i)
    local name = (ok and type(info) == "table" and not isSecret(info)) and info.fullName or nil
    if isSecret(name) or type(name) ~= "string" or name == "" then unread = unread + 1 end
    if not isSecret(name) and type(name) == "string" and name ~= "" and not seen[name] then
      seen[name] = true
      local short = FOREVER and string.match(name, "^([^%-]+)") or name
      if short ~= me and name ~= me then
        local area = info.area
        if not isSecret(area) and type(area) == "string" then areas[area] = (areas[area] or 0) + 1 end
        if q.zoneName and not isSecret(area) and area == q.zoneName then names[#names + 1] = name
        else others[#others + 1] = name end
      end
    end
  end
  Who.release(q)
  if not mine then log("who", "late answer", q.filter, "dropped"); return end
  local here = #names
  for _, name in ipairs(others) do names[#names + 1] = name end
  -- 1.14.12: a player asked in the last ASKED_FOR who did not answer is not asked again (Who.fresh)
  local found = #names
  names = Who.fresh(names)
  local before = found - #names
  names = Who.known(names)
  p.names, p.total, p.queue = names, total, {}
  for i, name in ipairs(names) do p.queue[i] = name end
  -- what the game sent, for the log: the rows, the ones it gave no name for, the ones in another zone
  log("who", #names .. (#names == 1 and " player" or " players"), "of " .. total, p.filter,
      "rows " .. n .. ", unreadable " .. unread .. ", in your zone " .. here .. (before > 0 and (", asked before " .. before) or ""))
  -- where the rows stand, the biggest first: whether the filter holds on this client
  local list = {}
  for area, k in pairs(areas) do list[#list + 1] = { area, k } end
  table.sort(list, function(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end)
  local parts = {}
  for i = 1, math.min(#list, 4) do parts[i] = list[i][1] .. " " .. list[i][2] end
  if #parts > 0 then log("whoAreas", table.concat(parts, ", "), #list > 4 and ((#list - 4) .. " more") or nil) end
  if #names == 0 and before > 0 then
    -- everyone the search found was asked lately and did not answer: nothing is sent (1.14.12)
    Who.pending = nil
    log("ask", "everyone asked before", current, p.want, p.via)
    local line = "Everyone found was asked in the last " .. math.floor(Who.ASKED_FOR / 3600) .. " h - none answered. Try another zone."
    setNotice(line, 15)
    say(line)
    refresh()
    return
  end
  if #names == 0 then
    Who.pending = nil
    log("ask", "nobody in the zone", current, p.want, p.via)
    local line = "The search found nobody else - try again in a moment, or /ls guild."
    setNotice(line, 15)
    say(line)
    refresh()
    return
  end
  Who.send(p)
end

-- The book: a LayerSwap user who answered an ask of ours, by name without the realm.
function Who.remember(name, layer, zone, host)
  if not FOREVER or isSecret(name) or type(name) ~= "string" or name == "" then return end
  local book = LayerSwapDB.book
  if type(book) ~= "table" then book = {}; LayerSwapDB.book = book end
  local key = string.match(name, "^([^%-]+)") or name
  local e = book[key] or {}
  e.layer, e.zone, e.at, e.gone = layer or e.layer, zone or e.zone, time(), nil
  if host ~= nil then e.host = host and true or nil end
  book[key] = e
end

-- At login: entries older than BOOK_TTL go, and the newest BOOK_MAX stay.
function Who.prune()
  local book = LayerSwapDB.book
  if type(book) ~= "table" then return end
  local list = {}
  for key, e in pairs(book) do
    if type(e) ~= "table" or type(e.at) ~= "number" or time() - e.at > Who.BOOK_TTL then book[key] = nil
    else list[#list + 1] = key end
  end
  if #list > Who.BOOK_MAX then
    table.sort(list, function(a, b) return book[a].at > book[b].at end)
    for i = Who.BOOK_MAX + 1, #list do book[list[i]] = nil end
  end
end

-- 1.14.12: the players a search whispered, by the name it whispered (LayerSwapDB.asked[name] = time()). A player
-- asked in the last ASKED_FOR seconds who did not answer is not asked again: only a LayerSwap user can
-- answer, and an answer puts the player in the book, which is always asked. Players told of Blizzard
-- silences (CurseForge, 10 Nov 2026), and one of our own sessions whispered 481 times in 7 minutes,
-- most of them the same players again. Kept under ASKED_MAX names, the newest.
function Who.pruneAsked()
  local asked = LayerSwapDB.asked
  if type(asked) ~= "table" then LayerSwapDB.asked = {}; return end
  local now, list = time(), {}
  for name, at in pairs(asked) do
    if type(at) ~= "number" or now - at >= Who.ASKED_FOR then asked[name] = nil else list[#list + 1] = name end
  end
  if #list > Who.ASKED_MAX then
    table.sort(list, function(a, b) return asked[a] > asked[b] end)
    for i = Who.ASKED_MAX + 1, #list do asked[list[i]] = nil end
  end
end

-- The search's names without the players asked lately who did not answer, in their order.
function Who.fresh(names)
  Who.pruneAsked()
  local asked = LayerSwapDB.asked
  local book = type(LayerSwapDB.book) == "table" and LayerSwapDB.book or {}
  local keep = {}
  for _, name in ipairs(names) do
    local e = book[string.match(name, "^([^%-]+)") or name]
    if e and type(e.gone) == "number" and time() - e.gone < Who.GONE_FOR then e = nil end   -- not found lately (Who.notPlaying)
    if not asked[name] or e then keep[#keep + 1] = name end
  end
  return keep
end

function Who.mark(name)
  if type(LayerSwapDB.asked) ~= "table" then LayerSwapDB.asked = {} end
  LayerSwapDB.asked[name] = time()
end

-- The search's names with the hosts from the book first, the rest in their order.
function Who.known(names)
  local book = type(LayerSwapDB.book) == "table" and LayerSwapDB.book or nil
  if not book then return names end
  local first, rest = {}, {}
  for _, name in ipairs(names) do
    local e = book[string.match(name, "^([^%-]+)") or name]
    if e and e.host and not (type(e.gone) == "number" and time() - e.gone < Who.GONE_FOR) then first[#first + 1] = name
    else rest[#rest + 1] = name end
  end
  if #first == 0 then return names end
  log("who", "known hosts first", #first)
  for _, name in ipairs(rest) do first[#first + 1] = name end
  return first
end

-- 1.14.14: "No player named 'X' is currently playing." - the game's own line for a whisper it could not deliver, in
-- the client's language (ERR_CHAT_PLAYER_NOT_FOUND_S). The name it carries when we whispered that player within
-- GONE_WAIT seconds, as we whispered it; nil for any other line or name (the player's own /w stays theirs).
function Who.notPlaying(text)
  local g = ERR_CHAT_PLAYER_NOT_FOUND_S
  if isSecret(text) or type(text) ~= "string" or isSecret(g) or type(g) ~= "string" then return nil end
  local pattern = "^" .. string.gsub(string.gsub(g, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), "%%%%s", "(.+)") .. "$"
  local name = string.match(text, pattern)
  if not name then return nil end
  local now = GetTime()
  for sent, at in pairs(Who.sentTo) do
    if now - at <= Who.GONE_WAIT and (sent == name or (string.match(sent, "^([^%-]+)") or sent) == name) then return sent end
  end
  return nil
end

-- That line came for a player we whispered: logged. A stranger is not asked again for ASKED_FOR, like anyone who
-- did not answer; one in the book - asked at every click otherwise - is left alone for GONE_FOR, or until it
-- answers again (Who.remember).
function Who.gone(text)
  local name = Who.notPlaying(text)
  if not name then return end
  Who.gonePlayers = Who.gonePlayers or {}
  if Who.gonePlayers[name] and GetTime() - Who.gonePlayers[name] < Who.GONE_WAIT then return end   -- once per whisper
  Who.gonePlayers[name] = GetTime()
  log("who", "not playing", name)
  if type(LayerSwapDB.asked) == "table" then LayerSwapDB.asked[name] = time() end
  local e = type(LayerSwapDB.book) == "table" and LayerSwapDB.book[string.match(name, "^([^%-]+)") or name]
  if type(e) == "table" then e.gone = time() end
end

-- The chat windows' filter: the line is ours to hide only for a name we whispered moments ago.
function Who.filterGone(_, _, text)
  if Who.notPlaying(text) then return true end
  return false
end

-- One burst of hidden whispers, BURST at a time and a second apart: the client throttles addon
-- messages (3) - a name it refused waits for the next round; any other refusal is counted and the
-- name dropped. The ask waits from the first whisper the client took (Who.out).
function Who.send(p)
  if Who.pending ~= p then return end
  p.rounds = p.rounds + 1
  local n = 0
  while #p.queue > 0 and n < Who.BURST do
    local name = p.queue[1]
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, p.line, "WHISPER", name)
    if ok and not isSecret(res) and res == 3 then break end
    table.remove(p.queue, 1)
    n = n + 1
    if ok and not isSecret(res) and res == 0 then
      p.sent = p.sent + 1
      Who.mark(name)
      Who.sentTo[name] = GetTime()
      if not p.out then Who.out(p) end
    else
      p.failed = (p.failed or 0) + 1
      p.why = p.why or (ok and (isSecret(res) and "secret" or tostring(res)) or ("error: " .. tostring(res)))
    end
  end
  if swap and swap.who == p then swap.reach = p.sent end
  if #p.queue > 0 and p.rounds < Who.ROUNDS then
    C_Timer.After(Who.BURST_WAIT, function() Who.send(p) end)
    refresh()
    return
  end
  Who.pending = nil
  Who.pruneAsked()
  log("who", "whispered " .. p.sent .. " of " .. #p.names, p.why and ("refused " .. p.failed .. ": " .. p.why) or nil,
      #p.queue > 0 and (#p.queue .. " left after " .. p.rounds .. " rounds") or nil)
  p.doneAt = GetTime()
  if p.sent > 0 then
    C_Timer.After(Who.ANYWAY_WAIT, function() Who.anyway() end)
    C_Timer.After(Who.ANYWAY_LATE, function() Who.anyway() end)
  end
  if p.sent == 0 and not p.why then
    -- every try held back by the client's budget (3): nothing went out, and the way stays open
    log("ask", "whispers throttled", current, p.want, p.via)
    local line = "The game is holding back addon messages - click Swap layer again in a moment."
    setNotice(line, 15)
    say(line)
  elseif p.sent == 0 then
    -- the client took none of them (4: not that chat type): this way is closed for the session.
    -- General is no way out (it holds only our own layer); the guild reaches every layer.
    Who.refused = p.why or "?"
    log("ask", "whispers refused", current, p.want, p.via)
    setNotice(Who.GUILD_LINE, 20)
    say(Who.GUILD_LINE)
  end
  refresh()
end

-- The ask is out: the wait for an invite starts, as after a chat line's echo. After HUB_WAIT
-- without one the button offers General (Send.hubCheck, Send.offerGeneral).
function Who.out(p)
  p.out = true
  local now = GetTime()
  if swap and not swap.joinedAt and swap.guildAt then swap.at, swap.channel = now, true
  else swap = { at = now, from = p.from, want = p.want, channel = true } end
  swap.where, swap.zone, swap.who, swap.reach = "direct", p.zone, p, p.sent
  swap.seen = p.seen
  log("ask", "sent", current, p.want, (p.via or "?") .. " direct")
  notice = nil
  refresh()
end

-- Stop asking during the search or the burst: nothing more goes out. Returns what was pending.
function Who.stop()
  local p = Who.pending
  if not p then return nil end
  Who.pending = nil
  return p
end

-- The world moved, or a group came, while the search or the burst ran: the rest is dropped - the
-- names were the old zone's.
function Who.moved(line)
  local p = Who.stop()
  if not p then return end
  if p.out then
    -- the ask is out already: only the rest of the burst is dropped
    log("who", "burst stopped", line and "moved" or "in a group", #p.queue .. " left")
  else
    log("ask", "dropped", current, p.want, "moved during the search")
    if line then setNotice(line, 15) end
  end
  refresh()
end

-- A hidden whisper that is a request: the line a chat ask carries, "inv layer ..." (Who.send).
function Who.isAsk(text)
  return not isSecret(text) and type(text) == "string" and string.find(text, "^inv layer") ~= nil
end

-- The host's side: the asker's request by hidden whisper, answered like a line in the layer
-- channel - the zone and the layer from its tag, a "heard" back the same way, an invite from a
-- host on another layer in the zone. The sender as the game names it is kept for the replies.
function Who.onAsk(text, sender)
  if isSecret(sender) or type(sender) ~= "string" or sender == "" then return end
  local name = FOREVER and string.match(sender, "^([^%-]+)") or withRealm(sender)
  if not name or name == fullName("player") then return end
  Who.from[name] = sender
  onChat("direct", text, name)
end

-- For /ls status.
function Who.state()
  if Who.refused then return "refused by the game this session (" .. tostring(Who.refused) .. ") - /ls guild asks your guild" end
  if Who.can() then return "ready: Swap layer searches players across the realm and asks each of them out of sight" end
  if not (FOREVER and Send.restricted()) then return "not needed on this realm" end
  return "no player search in this client - requests go to General"
end

local function requestSwap(target, via, leaving, wantNumber)
  local now = GetTime()
  -- an unanswered request past its time is over; it must not hide what this click says
  if swap and not swap.joinedAt and now - swap.at > SWAP_TTL then swap = nil end
  if IsInGroup() and not leaving then
    setNotice("You are in a group. Leave it to swap layers.", 10)
  elseif (swap and now - swap.at < SWAP_COOLDOWN) or now - stopped.at < SWAP_COOLDOWN then
    return
  elseif (target and Layer.same(target, current)) or (wantNumber and wantNumber == nwbLayer()) then
    -- said straight out: an older ask still waiting would otherwise hide it
    local line = "You are already on " .. (target and layerLabel(target) or ("Layer " .. wantNumber)) .. "."
    setNotice(line, 10)
    say(line)
    refresh()
    return "held"
  elseif FOREVER and not target and not current then
    -- the ask names the layer it leaves, so a host standing on it stays out; without it any
    -- host would invite, ours included (a user on CurseForge, 10 Oct 2026). Read first (1.9).
    local line = "Reading your layer first - target or mouse over an NPC, then ask."
    setNotice(line, 10)
    say(line)
    log("ask", "layer unknown", nil, nil, via)
    refresh()
    return "held"
  elseif Send.restricted() then
    -- 1.14.2: this realm does not let an addon post the line, so it goes into the chat box for
    -- the player's own Enter (Send.target says where). Nothing joins the layer channel here: on
    -- these realms the game bars a character from the channel after a line it refused (6 Nov
    -- 2026: three users, two of Adam's characters), and a join it refuses shows the same red
    -- line. 1.14.4: the click joins LayerSwap's own channel instead (Send.joinHub); this ask goes
    -- where it can now, the next one can use it.
    Send.joinHub()
    -- 1.14.6: without a channel (Who.ask). The box, for General, only for Ask in General and where
    -- the game offers no player search or refused the whispers.
    if Who.refused then
      setNotice(Who.GUILD_LINE, 15)
      say(Who.GUILD_LINE)
      log("ask", "whispers refused before", current, target, via)
      refresh()
      return "held"
    end
    if via ~= "fallback" and Who.can() then
      if Who.pending then
        local line = "Still searching for players - a moment."
        setNotice(line, 5)
        say(line)
        return "held"
      end
      if now - (Who.lastAt or -1000) < SWAP_COOLDOWN then return end
      -- a line still in the box (Ask in General) makes way for this ask, as one ask replaced another before
      if Send.pending then Send.drop("replaced") end
      local ok, why = Who.ask({ from = current, want = target, via = via,
                                fresh = not target and (via == "new" or LayerSwapDB.newOnly == true) })
      if ok then refresh(); return "search" end
      log("who", "not asked", why, via)
      -- 1.14.13: the search is there but did not start. No line for General in the chat box: since 1.14.12
      -- no LayerSwap host answers there, and it is a line other players see and can report.
      local line = "The player search did not start - try again in a moment, or /ls guild."
      setNotice(line, 15)
      say(line)
      refresh()
      return "held"
    end
    local where, id = Send.place(now, via)
    if not id then
      local line = "You are not in General or the layer channel - join General, then click again."
      setNotice(line, 15)
      say(line)
      log("ask", "no channel", current, target, via)
      refresh()
      return "held"
    end
    local left = Send.repeatLeft(now, where)
    if left then
      local line = "No host answered your last request in " .. Send.placeName(where) .. " - ask again in " .. math.ceil(left) .. " s."
      setNotice(line, 10)
      say(line)
      log("ask", "not repeated", current, target, via .. " " .. where)
      refresh()
      return "held"
    end
    Send.box(askText(target, wantNumber, true), "CHANNEL", id, where, { from = current, want = target, via = via })
    refresh()
    return "box"
  else
    local channel = GetChannelName(LAYER_CHANNEL)
    if channel == 0 then
      pcall(JoinChannelByName, LAYER_CHANNEL)
      setNotice("Joined the layer channel. Click again to ask.", 15)
    else
      -- everyone reads "inv layer"; the note tells a LayerSwap host which layer: the one named,
      -- or any but the current one, so a host on this very layer does not answer
      local note = (target and ("want " .. target)) or (current and ("not " .. current)) or "any"
      Near.send("ask", "CHANNEL", channel)
      sendZone("CHANNEL", channel)
      sendNote(note, "CHANNEL", channel)
      local line = askText(target, wantNumber, true)
      local sent, why = sendAsk(line, "CHANNEL", channel, "Swap layer")
      if not sent then
        -- nothing went out: nothing to wait for, and no cooldown before the next click
        log("ask", why, current, target, via)
        refresh()
        return "held"
      end
      -- a ping of our own after the line: its echo says whether the game is passing addon
      -- messages on time right now (0.22-0.40 s until 8 Oct 2026, 68-139 s on 10 Oct). Only a
      -- ping the client took can be waited for (1.14.2: a refused one said "delaying" for ever).
      pingCount = pingCount + 1
      local ping = "ping " .. pingCount .. "-" .. math.floor(now)
      local res = sendNote(ping, "CHANNEL", channel)
      readChannelCount("ask")
      log("ask", "sent", current, target, via)
      -- a guild ask already waiting keeps waiting: both are out now
      if swap and not swap.joinedAt and swap.guildAt then swap.at, swap.channel = now, true
      else swap = { at = now, from = current, want = target, channel = true } end
      swap.where = "layer"
      if res == 0 then swap.ping, swap.pingAt, swap.echoAt = ping, now, nil
      else swap.ping, swap.pingAt, swap.echoAt = nil, nil, nil end
      -- the line LayerSwap sent itself, for the realm's answer (Send.notice). Forever only: the
      -- Classic realms let the line out, and a channel notice there changes nothing
      if FOREVER then
        Send.direct = { at = now, line = line, channel = channel, swap = swap, from = current, want = target, via = via }
      end
      notice = nil
    end
  end
  refresh()
end

-- A request that is still waiting for its invite (asked, not yet in a group, within its time).
local function waitingAsk(now)
  return swap ~= nil and not swap.joinedAt and now - swap.at <= SWAP_TTL
end
ownAskWaiting = function() return waitingAsk(GetTime()) end

-- A host in our zone on our own layer heard the ask and cannot move us: counted once per host
-- for the ask that waits, so the panel can say why no invite comes.
-- What LayerSwap users said about the ask that waits: [name] = { layer, zone, host, same }.
-- "same" comes from a host on our layer (1.4 on; such a host is hosting by definition), "heard"
-- from every LayerSwap user (1.6 on).
local function replyFrom(name)
  swap.replies = swap.replies or {}
  local r = swap.replies[name]
  if not r then r = {}; swap.replies[name] = r end
  return r
end

onSame = function(name)
  Who.remember(name, current, zoneOf("player") and tostring(zoneOf("player")) or nil, true)
  if not waitingAsk(GetTime()) then return end
  local r = replyFrom(name)
  if r.same then return end
  r.same, r.host = true, true
  log("sameReply", name, current)
  refresh()
end

onHeard = function(name, layer, zone, host)
  Who.remember(name, layer, zone, host == true)
  if not waitingAsk(GetTime()) then return end
  local r = replyFrom(name)
  r.layer, r.zone, r.host = layer, zone, host or r.host
  log("heardReply", name, layer or "?", zone or "?", host and "hosting" or nil)
  if host and not layer then Who.anyway() end   -- a late reply from a host that has not read its layer
  Who.seenWarn(name)                            -- a reply that comes after its sender's invite
  refresh()
end

onEcho = function(text)
  if not (swap and swap.ping == text and not swap.echoAt) then return end
  swap.echoAt = GetTime()
  log("echo", string.format("%.2f s", swap.echoAt - swap.pingAt))
  refresh()
end

-- Our own pos note came back: the distance to where we stand now, through the same code a host
-- runs on an asker. About 0 yards proves the whole pipeline on one client (1.14).
Near.echo = function(text)
  local pKind, pRef, px, py = string.match(text, "^(pos%a?) (%d+) (%-?%d+) (%-?%d+)$")
  if not pKind or (pKind ~= "pos" and pKind ~= "posm") then return end
  local mine = Near.read(pKind == "posm" and "map" or "world")
  if not mine or mine.ref ~= pRef then log("spot", "self", "unreadable now"); return end
  log("spot", "self", math.floor(Near.between(mine, { x = tonumber(px), y = tonumber(py) }) + 0.5) .. " yards")
end

-- Our own line came back (1.14.2): the tag's map coordinates against where we stand now, through
-- the host's own arithmetic - about 0 yards proves the line's position on one client.
Near.echoLine = function(msg)
  local tag = routeTag(msg)
  if not (tag and tag.pos and tag.zone) then return end
  local mine = Near.read("map")
  if not mine or mine.ref ~= tostring(tag.zone) then log("spot", "self", "unreadable now", "line"); return end
  local w, h = Near.mapSize(tag.zone)
  if not w then return end
  log("spot", "self", math.floor(Near.between(mine, { x = tag.pos.x / 100 * w, y = tag.pos.y / 100 * h }) + 0.5) .. " yards", "line")
end

-- The game is slow with addon messages right now: the ask's ping took longer than LAG_AFTER to
-- come back, or has not come back by then.
local function lagging(now)
  if not (swap and swap.pingAt) then return false end
  if swap.echoAt then return swap.echoAt - swap.pingAt > LAG_AFTER end
  return now - swap.pingAt > LAG_AFTER
end

-- The replies counted: all, hosting, on another layer in our zone, on our own layer. A layer id
-- belongs to one zone, so only replies from our zone are compared with our layer.
local function heardCounts()
  local n, h, o, s, v = 0, 0, 0, 0, 0
  local here = zoneOf("player")
  here = here and tostring(here)
  for _, r in pairs(swap.replies or {}) do
    -- only a host in our zone moves us (8 Nov 2026 23:21); a layer id belongs to one zone
    local sameZone = here ~= nil and r.zone == here
    n = n + 1
    if r.host then h = h + 1 end
    if r.same or (sameZone and r.layer and current and Layer.same(r.layer, current)) then s = s + 1
    elseif r.host and sameZone and r.layer and current then
      -- 1.14.14: an ask for new layers only - a host on a layer we have seen is not one that can move us there
      if swap.seen and Layer.inList(r.layer, swap.seen) then v = v + 1 else o = o + 1 end
    end
  end
  return n, h, o, s, v
end

-- One line on what LayerSwap users said, for the status line while the ask waits; "" until the
-- first reply.
local function heardLine()
  local n, h, o, s, v = heardCounts()
  if n == 0 then return "" end
  local parts = { h > 0 and (h .. " hosting") or "none hosting" }
  if o > 0 then parts[#parts + 1] = o .. " can move you" end
  if swap.seen then
    if s + v > 0 then parts[#parts + 1] = (s + v) .. " not on a new layer" end
  elseif s > 0 then parts[#parts + 1] = s .. " on yours" end
  return n .. (n == 1 and " LayerSwap user heard you: " or " LayerSwap users heard you: ") .. table.concat(parts, ", ") .. "."
end

-- Stop asking: the wait ends here. A chat line cannot be taken back, so an invite already on
-- its way can still come - it is then the player's to decline, and it no longer counts as a swap.
local function stopAsking(via)
  local now = GetTime()
  -- the search, or the burst still going (1.14.6): nothing more goes out
  local searched = Who.stop()
  if Send.pending then
    -- the line was never sent: no cooldown, and the box lets go of it
    log("ask", "stopped", current, Send.pending.want, via .. " in the box")
    Send.drop("stopped", "Stopped - the request was not sent.")
    return true
  end
  if not waitingAsk(now) then
    if not searched then return false end
    log("ask", "stopped", current, searched.want, via .. " in the search")
    setNotice("Stopped - the request was not sent.", 10)
    refresh()
    return true
  end
  log("ask", "stopped", current, swap.want, via)
  stopped.at, stopped.guildAt = swap.at, swap.guildAt or -1000
  swap = nil
  setNotice("Stopped asking. An invite already on its way can still come.", 10)
  refresh()
  return true
end

-- Ask the guild (/ls guild): one line in guild chat, on its own command and never with Swap
-- layer - guild chat is where people talk, so LayerSwap never writes there by itself. No button
-- in the panel since 1.4.3 (Adam, 8 Oct 2026: it stood alone on a row of its own). A guildmate on another
-- layer is the most willing host there is, and invites by hand with or without the addon;
-- the note still goes to the guild's LayerSwap hosts. No AutoLayer header: nobody reads it there.
local function requestGuild(via)
  local now = GetTime()
  if swap and not swap.joinedAt and now - swap.at > SWAP_TTL then swap = nil end
  if not IsInGuild() then
    local line = "You are not in a guild."
    setNotice(line, 10)
    say(line)
    refresh()
    return "held"
  elseif IsInGroup() then
    setNotice("You are in a group. Leave it to swap layers.", 10)
  elseif (swap and swap.guildAt and now - swap.guildAt < SWAP_COOLDOWN) or now - stopped.guildAt < SWAP_COOLDOWN then
    return
  elseif FOREVER and not current and not (swap and not swap.joinedAt and swap.want) then
    local line = "Reading your layer first - target or mouse over an NPC, then ask."
    setNotice(line, 10)
    say(line)
    log("ask", "layer unknown", nil, nil, via)
    refresh()
    return "held"
  elseif Send.restricted() then
    -- 1.14.2: into the chat box for the player's own Enter (see requestSwap); the guild's notes
    -- go out at that Enter, right before the line (Send.preSend), not now
    local want = swap and not swap.joinedAt and swap.want or nil
    Send.box(askText(want, nil, false), "GUILD", nil, "guild", { from = current, want = want, via = via })
    refresh()
    return "box"
  else
    local want = swap and not swap.joinedAt and swap.want or nil
    local note = (want and ("want " .. want)) or (current and ("not " .. current)) or "any"
    Near.send("guild", "GUILD")
    sendZone("GUILD")
    sendNote(note, "GUILD")
    local sent, why = sendAsk(askText(want, nil, false), "GUILD", nil, "/ls guild")
    if not sent then
      log("ask", why, current, want, via)
      refresh()
      return "held"
    end
    log("ask", "sent in guild", current, want, via)
    -- the wait starts over from this ask; a channel ask already out stays counted
    if swap and not swap.joinedAt then swap.at, swap.guildAt = now, now
    else swap = { at = now, from = current, want = want, guildAt = now } end
    notice = nil
  end
  refresh()
end

-- One click: out of the host's group, and the same ask once more - the click is the
-- hardware event the chat line needs. The group is let go of here, so GROUP_LEFT does not
-- wipe the new ask.
local function leaveAndAskAgain(via)
  local want = swap and swap.want
  if IsInGroup() then pcall(leaveParty) end
  log("left", current, "to ask again")
  leftInfo = { at = GetTime(), layer = current }
  swapGroup, swap = false, nil
  return requestSwap(want, via, true)
end

local function leaveSwapGroup()
  if swapGroup and IsInGroup() then pcall(leaveParty) end
  swap = nil
  refresh()
end

local function clock(seconds)
  seconds = math.max(0, math.floor(seconds))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The world refresh (Blizzard's word for it): a countdown, then "any moment" - the move came
-- 14-15 s after the timer ran out (beta 19 Sep 2026), and Blizzard's toast says "Refreshing
-- your world at any time" then. Two minutes past it, without a move, the notice is dropped.
local function refreshIn(now)
  if not evictAt then return nil end
  if evictAt > now then return clock(evictAt - now) end
  if now - evictAt < 120 then return "soon" end
end

-- 1.14.13: a host in our zone that heard the ask but has not read its own layer ("?" in its reply) skips an ask
-- that names the layer we leave - it cannot rule out standing on it (10 Nov 2026: two of three LayerSwap users in
-- Westfall, one of three hosts in Stormwind). When no invite came and no host known to stand on another layer
-- heard us - or one did and has not invited within ANYWAY_LATE - each such host is whispered once more, out of
-- sight, with the layer left out: its LayerSwap then invites.
-- Never for a named layer, never before the burst is out and ANYWAY_WAIT has passed, never to a host that did not
-- move us in the last SAME_HOST_TTL. A host on our own layer is left after SAME_LAYER_LEAVE, as any host.
-- 1.14.14: an invite from a host on a layer the player has seen, while the ask was for new layers only (a host on
-- an older version reads only the layer we leave): said in the panel and in chat - declining stays the player's.
function Who.seenWarn(name)
  if not (swap and swap.seen and name and swap.inviter == name and not swap.joinedAt) then return end
  local r = swap.replies and swap.replies[name]
  if not (r and r.layer and Layer.inList(r.layer, swap.seen)) then return end
  -- like a host known to stand on our own layer, it keeps the name only until another host invites
  swap.inviterSeen = true
  swap.warned = swap.warned or {}
  if swap.warned[name] then return end
  swap.warned[name] = true
  local label = layerLabel(Layer.canon(r.layer))
  log("seenLayerInvite", name, r.layer, label)
  say(name .. " is on " .. label .. ", which you have seen - decline to wait for a new layer.")
  setNotice(name .. " is on " .. label .. " - you have seen it. Decline to wait.", 30)
  refresh()
end

function Who.anyway()
  if not (FOREVER and Send.restricted()) then return end
  local now = GetTime()
  if not (waitingAsk(now) and swap.where == "direct" and swap.who and swap.who.doneAt) then return end
  local since = now - swap.who.doneAt
  if since < Who.ANYWAY_WAIT or swap.inviter or swap.want then return end
  -- a host known to stand on another layer gets ANYWAY_LATE to invite: it answers "hosting" even while it
  -- cannot invite (in a group of its own, its group full), and then nothing comes of it
  local _, _, other = heardCounts()
  if other > 0 and since < Who.ANYWAY_LATE then return end
  local here = zoneOf("player")
  if not here then return end
  local fx, fy
  local okF, a, b = pcall(Near.fraction, here)
  if okF and a then fx, fy = a, b end
  local line = "inv layer " .. routeText(here, nil, nil, fx, fy)
  local asked = false
  for name, r in pairs(swap.replies or {}) do
    local seen = sameHosts[name]
    local before = seen and current and Layer.same(seen.layer, current) and now - seen.at <= SAME_HOST_TTL
    if r.host and not r.layer and not r.same and not r.anyway and r.zone == tostring(here) and not before then
      r.anyway = true
      local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, line, "WHISPER", Who.from[name] or name)
      Who.sentTo[Who.from[name] or name] = now
      log("ask", "asked anyway", current, name, "layer unknown, " .. ((not ok and "error") or (isSecret(res) and "secret") or tostring(res)))
      swap.anyway = { name = name, at = now }
      asked = true
    end
  end
  if asked then refresh() end
end

-- The one status line under the buttons.
local function statusLine()
  local now = GetTime()
  if Send.pending then
    -- a notice set for the line that waits (a refusal, a throttle) says why; else the line itself
    if notice and now < (noticeUntil or 0) then return notice end
    return Send.PENDING_TEXT
  end
  if Who.pending and not Who.pending.out then return "Searching for players..." end
  if swap then
    if swap.joinedAt then
      local host = swap.inviter or "a host"
      if hostOnOurLayer(now) then
        if swap.elsewhere then return host .. " in " .. swap.elsewhere .. " did not move you." end
        if swap.refreshed then return host .. " did not move you. Leave and ask again." end
        -- two lines in the panel: the chat line names the zone
        if onlyLayerHere() then return "Host on your layer - the only one seen here. Try a busier zone." end
        return host .. " is on your layer. Leave and ask again."
      end
      if not current then return "In " .. host .. "'s group. Mouse over an NPC to read the layer." end
      if not swap.transferAt and now - swap.joinedAt >= SAME_LAYER_AFTER and (swap.fresh or 0) < Who.FRESH then
        return "In " .. host .. "'s group - mouse over an NPC to check."
      end
      return "In " .. host .. "'s group, still on " .. layerLabel(current) .. ". (" .. clock(now - swap.joinedAt) .. ")"
    elseif swap.inviter and not swap.inviterSeen then
      return swap.inviter .. " invited you. Accept to swap."
    elseif swap.inviterSeen and notice and now < (noticeUntil or 0) then
      -- a host that did not move us before: the warning, not "accept"; after it the ask waits on
      return notice
    elseif now - swap.at > SWAP_TTL then
      if swap.want then return "No host on " .. layerLabel(swap.want) .. " answered. Swap layer asks for any other." end
      local n, h, other, same, known = heardCounts()
      if swap.seen and known > 0 and other == 0 then
        return "No host on a new layer answered. Click a layer in the list to go back to one."
      end
      if same > 0 then
        return "No host on another layer answered; " .. same .. " here " .. (same == 1 and "is" or "are") .. " on yours. Try a busier zone."
      end
      if n > 0 and h == 0 then
        return n .. (n == 1 and " LayerSwap user" or " LayerSwap users") .. " heard you, but none of them hosts. Try again in a moment."
      end
      if n > 0 and other == 0 then
        -- LayerSwap hosts heard it, and none of them is known to stand on another layer in our zone
        if swap.where == "direct" and IsInGuild() then return "No host on another layer heard you. /ls guild asks your guild, on every layer." end
        return "No host on another layer heard you. Try again in a moment."
      end
      -- nobody among the players asked answered at all: none of them runs a LayerSwap that reads the ask
      -- (1.14.6 or newer, Host on or off) - said as such, so the player does not click on and on (Adam, 8 Nov 2026)
      local sent = swap.reach or 0
      if swap.where == "direct" and n == 0 and sent > 0 then
        if sent == 1 then return "The player asked does not run LayerSwap yet - try later, or /ls guild." end
        return "None of the " .. sent .. " players runs LayerSwap yet - try later, or /ls guild."
      end
      if swap.where == "direct" and IsInGuild() then return "No host on another layer answered. /ls guild asks your guild, on every layer." end
      return "No host answered. Try again in a moment."
    end
    -- the request waits: the bottom line says it (askLine); this one carries what LayerSwap
    -- users said about it, if anything (Adam, 8 Oct 2026) - or that the game is slow (1.10)
    if Send.offerGeneral(now) then return "No invite from LayerSwap's channel yet - Ask in General puts the request in General too." end
    if lagging(now) then return "The game is delaying addon messages right now - an invite may come late." end
    if swap.anyway and now - swap.anyway.at < 15 then
      return swap.anyway.name .. " does not know its layer yet - asking it anyway."
    end
    return heardLine()
  end
  if notice and now < (noticeUntil or 0) then return notice end
  if held and swapGroup then
    -- on live the new layer stays after the group is left (9 Nov 2026, 10:55 and 11:48)
    if held.auto then
      return "On " .. layerLabel(current or held.to) .. " - leaving " .. (held.host or "the host") .. "'s group, the layer stays."
    end
    return "On " .. layerLabel(current or held.to) .. " in " .. (held.host or "the host") ..
      "'s group. You can leave - it stays."
  end
  -- Host off: the reason it is on stands here until it is on again (Adam, 8 Nov 2026)
  if not hosting then return HOST_OFF_LINE end
  local pause = Host.left(now)
  if pause then
    return "Host pauses: " .. Host.CAP .. " invites in " .. (Host.WINDOW / 60) .. " min. It invites again in " .. math.ceil(pause / 60) .. " min."
  end
  if FOREVER and not current then return "Swap layer asks once your layer is read, so a host on it skips you." end
  if FOREVER and Send.restricted() then
    if Who.can() then return "Swap layer asks players across the realm, out of sight, for an invite." end
    if Who.refused then return Who.GUILD_LINE end
    local where = Send.place(now)
    local left = Send.repeatLeft(now, where)
    if left then return "No host answered your last request - you can ask again in " .. math.ceil(left) .. " s." end
    if where == "hub" then return "Swap layer asks in LayerSwap's channel for an invite from a host in your zone." end
    if where == "general" and Send.hubSpent(now) then return "No invite from LayerSwap's channel - Swap layer asks in General now." end
    if where == "general" and Send.HUB_ASKS then return "Swap layer asks in General until LayerSwap's channel is open to you." end
    if where == "general" then return "Swap layer asks in General for an invite from a host in your zone." end
    if where == nil then return "Join General to ask for an invite." end
  end
  return "Swap layer asks a host in the layer channel for an invite."
end

-- The request that waits, in one line: how many it reached - the others in the layer channel,
-- when the game says - and for how long; hosts on our own layer who said so are added. The
-- panel's bottom line carries it while the request waits (Adam, 8 Oct 2026).
local function askLine(now)
  local others = swap.channel and channelCount and math.max(channelCount - 1, 0) or nil
  -- where it went is said too (Adam, 8 Oct 2026)
  local guild = swap.guildAt and " + your guild" or ""
  local reach
  if not swap.channel then
    reach = "your guild"
  elseif swap.where == "general" then
    reach = "General" .. guild
  elseif swap.where == "hub" then
    reach = "LayerSwap's channel" .. guild
  elseif swap.where == "direct" then
    local n = swap.reach or 0
    reach = n .. (n == 1 and " player" or " players") .. guild
  elseif others == 0 then
    reach = swap.guildAt and "your guild - nobody else is in the layer channel" or "nobody else in the layer channel"
  elseif others then
    reach = others .. (others == 1 and " player" or " players") .. " in the layer channel" .. guild
  else
    reach = "the layer channel" .. guild
  end
  -- by hidden whisper the count is the players the request went to, not the ones who heard it (Adam,
  -- 8 Nov 2026, read "48 players" as 48 who heard him): "Sent to" says so
  if swap.where == "direct" and swap.channel then
    return "|cff40ff40Sent to|r " .. reach .. (swap.want and (", for " .. layerLabel(swap.want)) or "") .. " (" .. clock(now - swap.at) .. ")"
  end
  local line = "|cff40ff40Asked for inv|r" .. (swap.want and (" on " .. layerLabel(swap.want)) or "")
    .. ": " .. reach .. " (" .. clock(now - swap.at) .. ")"
  return line
end

-- A request out and nobody has invited yet.
local function askWaiting(now)
  return waitingAsk(now) and not (swap.inviter and not swap.inviterSeen)
end

-- After an ask from a slash command or the menu (the panel may be closed): the line for chat.
local function sayStatus()
  local now = GetTime()
  if Send.pending then
    say((notice and now < (noticeUntil or 0)) and notice or "your request is in the chat box - press Enter to send it, Escape to drop it.")
    return
  end
  say(askWaiting(now) and askLine(now) or statusLine())
end

-- ---------------------------------------------------------------------------------------
-- panel

local PANEL_W, PAD, ROWS = 260, 12, 5
local panel

-- A button's label stays inside the button: one wider than the button drops to the small font
-- (Adam's screenshot, 26 Sep 2026: "Leave and ask again" ran past both edges).
local function setButtonText(button, text)
  button:SetNormalFontObject("GameFontNormal")
  button:SetHighlightFontObject("GameFontHighlight")
  button:SetDisabledFontObject("GameFontDisable")
  button:SetText(text)
  local fs = button:GetFontString()
  if type(fs) ~= "table" or type(fs.GetStringWidth) ~= "function" then return end
  if (fs:GetStringWidth() or 0) > button:GetWidth() - 14 then
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
  end
end

local function agoText(seconds)
  if seconds < 60 then return "just now" end
  return math.floor(seconds / 60) .. " min ago"
end

-- Every line of text is bound on both sides, so nothing can run out of its field; one-line
-- texts end in an ellipsis instead of wrapping.
local function addText(parent, font, y, lines, rightInset)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
  fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(rightInset or PAD), y)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(lines > 1)
  if fs.SetMaxLines then fs:SetMaxLines(lines) end
  local height = math.ceil((fs:GetLineHeight() or 12) * lines)
  fs:SetHeight(height)
  return fs, y - height
end

-- A "LIVE" dot, as on a news broadcast: red and pulsing while hosting, grey and still
-- when not. Solid colours cut round by the portrait mask (it exists on Forever: the dot
-- came out round in the beta). A dark ring that never pulses sits behind it - red on the
-- red Forever button was hard to see (Adam's screenshot, 24 Sep 2026). x and y place the
-- centre, counted from the middle of the parent's left edge.
local function makeLiveDot(parent, x, y)
  local function round(size, sublevel)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, sublevel)
    t:SetSize(size, size)
    t:SetPoint("CENTER", parent, "LEFT", x, y or 0)
    local mask = parent:CreateMaskTexture()
    if mask then
      mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(t)
      t:AddMaskTexture(mask)
    end
    return t
  end
  local ring = round(12, 1)
  ring:SetColorTexture(0.06, 0.02, 0.02)
  local dot = round(8, 2)
  local pulse = dot:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.3)
  fade:SetDuration(0.8)
  return dot, pulse, ring
end

local function showLive(dot, pulse, on)
  if on then
    dot:SetColorTexture(1, 0.2, 0.2)
    if not pulse:IsPlaying() then pulse:Play() end
  else
    dot:SetColorTexture(0.45, 0.45, 0.45)
    pulse:Stop()
    dot:SetAlpha(1)
  end
end

local function buildPanel()
  local p = CreateFrame("Frame", "LayerSwapPanel", UIParent)
  p:SetWidth(PANEL_W)
  p:SetPoint("CENTER", UIParent, "CENTER", 320, 120)
  p:SetFrameStrata("MEDIUM")
  p:SetClampedToScreen(true)
  p:SetMovable(true)
  p:EnableMouse(true)
  p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart", p.StartMoving)
  p:SetScript("OnDragStop", p.StopMovingOrSizing)

  local bg = p:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(p)
  bg:SetColorTexture(0.04, 0.05, 0.07, 0.92)
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                          { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local line = p:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.30, 0.52, 0.70, 0.9)
    line:SetPoint(side[1], p, side[1], 0, 0)
    line:SetPoint(side[2], p, side[2], 0, 0)
    if side[3] then line:SetHeight(1) else line:SetWidth(1) end
  end

  local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", p, "TOPRIGHT", 2, 2)
  -- the template's own click goes through HideUIPanel, which the game refuses in combat for an
  -- addon's window (Adam, 10 Oct 2026: the X did nothing in combat); a plain Hide works there
  close:SetScript("OnClick", function() p:Hide() end)
  p.closeButton = close

  -- the mini bar (the small line) is switched on and off from here, and with /ls mini: a
  -- real button with ON/OFF the way the Host button has it - grey text was missed (Adam, 26 Sep)
  p.lineButton = CreateFrame("Button", "LayerSwapPanelLineButton", p, "UIPanelButtonTemplate")
  p.lineButton:SetSize(92, 18)
  p.lineButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -30, -7)
  p.lineButton:SetNormalFontObject("GameFontNormalSmall")
  p.lineButton:SetHighlightFontObject("GameFontHighlightSmall")
  p.lineButton:SetScript("OnClick", function() toggleMini(); refresh() end)

  local y = -10
  p.title, y = addText(p, "GameFontNormal", y, 1, 30 + 92 + 4)
  p.title:SetText("LayerSwap")
  y = y - 10
  p.h1, y = addText(p, "GameFontDisableSmall", y, 1)
  p.h1:SetText("YOUR LAYER")
  y = y - 3
  p.layer, y = addText(p, "GameFontHighlightLarge", y, 1)
  y = y - 2
  p.detail, y = addText(p, "GameFontHighlightSmall", y, 1)
  y = y - 2
  p.evict, y = addText(p, "GameFontNormalSmall", y, 1)
  p.evict:SetTextColor(1, 0.6, 0.2)
  y = y - 10
  p.h2, y = addText(p, "GameFontDisableSmall", y, 1)
  y = y - 3
  p.rows = {}
  for i = 1, ROWS do
    local left, nextY = addText(p, "GameFontHighlightSmall", y, 1, PAD + 76)
    local right = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    right:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, y)
    right:SetWidth(72)
    right:SetHeight(math.ceil(right:GetLineHeight() or 12))
    right:SetJustifyH("RIGHT")
    right:SetWordWrap(false)
    -- the whole row is a button: click asks for that layer (only while one is listed)
    local hit = CreateFrame("Button", nil, p)
    hit:SetPoint("TOPLEFT", p, "TOPLEFT", PAD - 4, y + 1)
    hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(PAD - 4), y + 1)
    hit:SetHeight(y - nextY + 2)
    local lit = hit:CreateTexture(nil, "HIGHLIGHT")
    lit:SetAllPoints(hit)
    lit:SetColorTexture(1, 1, 1, 0.08)
    hit:SetScript("OnClick", function(self) if self.id then requestSwap(self.id, "row") end end)
    hit:SetScript("OnEnter", function(self)
      if not self.id then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Ask for " .. layerLabel(self.id))
      GameTooltip:AddLine("Only a LayerSwap host standing on it can tell - anyone else who invites may be anywhere.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = { left = left, right = right, y = y, hit = hit }
    y = nextY - 3
  end
  y = y - 8

  local buttonW = (PANEL_W - PAD * 2 - 8) / 2
  p.swapButton = CreateFrame("Button", "LayerSwapPanelSwapButton", p, "UIPanelButtonTemplate")
  p.swapButton:SetSize(buttonW, 24)
  p.swapButton:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, y)
  p.swapButton:SetScript("OnClick", function()
    local now = GetTime()
    if swapGroup and hostOnOurLayer(now) then leaveAndAskAgain("again")
    elseif swapGroup then leaveSwapGroup()
    elseif Send.pending then stopAsking("button")
    elseif Who.pending and not Who.pending.out then
      -- the search runs (1.14.6): the button stops it, after its first second
      if now - Who.pending.at >= STOP_AFTER then stopAsking("button") end
    elseif Send.offerGeneral(now) then
      -- the hub brought no invite: the zone counts as quiet there (now, should the timer be late)
      local want = swap.want
      Send.hubCheck(swap)
      requestSwap(want, "fallback")
    elseif waitingAsk(now) and swap.channel then
      if now - swap.at >= STOP_AFTER then stopAsking("button") end
    else requestSwap(nil, "button") end
  end)
  p.hostButton = CreateFrame("Button", "LayerSwapPanelHostButton", p, "UIPanelButtonTemplate")
  p.hostButton:SetSize(buttonW, 24)
  p.hostButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, y)
  p.hostButton:SetScript("OnClick", function() setHosting(not hosting) end)
  p.hostDot, p.hostPulse = makeLiveDot(p.hostButton, 14)
  y = y - 24 - 8

  p.status, y = addText(p, "GameFontHighlightSmall", y, 2)
  y = y - 6
  p.hostLine, y = addText(p, "GameFontDisableSmall", y, 3)
  p:SetHeight(-y + 10)

  p:SetScript("OnShow", function(self)
    refresh()
    self.ticker = self.ticker or C_Timer.NewTicker(1, refresh)
  end)
  p:SetScript("OnHide", function(self)
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
  end)
  if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "LayerSwapPanel" end
  p:Hide()
  return p
end

refresh = function()
  noteNwb()
  refreshMini()
  local p = panel
  if not p or not p:IsShown() then return end
  local now = GetTime()
  local zone = Layer.zone() or ""
  if current then
    p.layer:SetText(layerLabel(current))
    p.detail:SetText(current .. "  -  " .. zone)
  else
    p.layer:SetText("Detecting...")
    p.detail:SetText("Target or mouse over an NPC or two.")
  end
  local r = refreshIn(now)
  p.evict:SetText(r == "soon" and "World refresh any moment now." or (r and ("World refresh in " .. r .. ".")) or "")

  local seen, today = seenInZone(), time()
  p.h2:SetText(#seen > 0 and "SEEN IN THIS ZONE - CLICK ONE TO ASK" or "SEEN IN THIS ZONE")
  local asking = swap and not swap.joinedAt and now - swap.at <= SWAP_TTL and swap.want
  for i, row in ipairs(p.rows) do
    local l = seen[i]
    -- the hint has the whole row to itself; a layer row stops short of its age on the right
    row.left:SetPoint("TOPRIGHT", p, "TOPRIGHT", -((l or i > 1) and (PAD + 76) or PAD), row.y)
    row.left:SetText(l and (layerLabel(l.id) .. "  -  " .. l.id) or (i == 1 and "Layers you have stood on appear here." or ""))
    row.right:SetText(l and (asking == l.id and "asking..." or agoText(today - l.last)) or "")
    row.hit.id = l and l.id or nil
    row.hit:SetShown(l ~= nil)
  end

  p.lineButton:SetText((mini and mini:IsShown()) and "Mini bar: |cff40ff40ON|r" or "Mini bar: |cffa0a0a0OFF|r")
  if swapGroup and hostOnOurLayer(now) then
    setButtonText(p.swapButton, "Leave and ask again")
    p.swapButton:SetEnabled(true)
  elseif swapGroup then
    setButtonText(p.swapButton, "Leave group")
    p.swapButton:SetEnabled(true)
  elseif Send.pending then
    -- the line waits in the chat box for the player's Enter: the button lets go of it (1.14.5)
    setButtonText(p.swapButton, "Drop request")
    p.swapButton:SetEnabled(true)
  elseif Send.offerGeneral(now) then
    setButtonText(p.swapButton, "Ask in General")
    p.swapButton:SetEnabled(true)
  elseif Who.pending and not Who.pending.out then
    -- the search runs (1.14.6): it can be stopped
    setButtonText(p.swapButton, "Stop asking")
    p.swapButton:SetEnabled(now - Who.pending.at >= STOP_AFTER)
  elseif waitingAsk(now) and swap.channel then
    -- the wait can be ended: a request is out in the layer channel and nothing has come of it
    -- yet (after /ls guild alone the button still asks the channel too; /ls stop ends either)
    setButtonText(p.swapButton, "Stop asking")
    p.swapButton:SetEnabled(now - swap.at >= STOP_AFTER)
  elseif FOREVER and not current then
    setButtonText(p.swapButton, "Reading layer...")
    p.swapButton:SetEnabled(false)
  else
    setButtonText(p.swapButton, "Swap layer")
    p.swapButton:SetEnabled(not ((swap and now - swap.at < SWAP_COOLDOWN) or now - stopped.at < SWAP_COOLDOWN
        or now - (Who.lastAt or -1000) < SWAP_COOLDOWN)
      and not (Send.restricted() and not Who.can() and Send.repeatLeft(now, (Send.place(now)))))
  end
  -- ON has to be unmistakable at a glance: the LIVE dot pulses red
  p.hostButton:SetText(hosting and "Host: |cffff4040LIVE|r" or "Host: |cffa0a0a0OFF|r")
  showLive(p.hostDot, p.hostPulse, hosting)
  p.status:SetText(statusLine())
  -- "players asked for inv": the players who asked, each once, so one impatient asker does not count
  -- ten times; said in full, so it cannot be read as our own asks (Adam, 8 Oct 2026). The same line
  -- with Host off, only the label changes.
  -- Host off: the same design, the green word is "Asked for inv" (Adam, 8 Oct 2026)
  local who = stats.askers .. (stats.askers == 1 and " player" or " players")
  if askWaiting(now) then
    p.hostLine:SetText(askLine(now))
  elseif hosting then
    p.hostLine:SetText(string.format("|cff40ff40Hosting|r: %s asked for inv, %d invited, %d joined.", who, stats.invites, stats.joined))
  else
    p.hostLine:SetText(string.format("|cff40ff40Asked for inv|r: %s, %d invited, %d joined.", who, stats.invites, stats.joined))
  end
end

-- A click on any LayerSwap control is the hardware event the layer channel needs: a host who
-- never joined it (the default host) joins it here.
local function joinLayerChannel()
  Send.joins()
end

local function togglePanel()
  joinLayerChannel()
  panel = panel or buildPanel()
  if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- ---------------------------------------------------------------------------------------
-- the layer menu: the LayerSwap logo on the mini line drops a list of the layers that can be
-- asked for - "any other layer" first, then the ones seen in this zone, then this one, greyed.

local MENU_W, MENU_ROW, MENU_LAYERS = 230, 18, 6
local menu

local function closeMenu()
  if menu then menu:Hide() end
end

local function buildMenu()
  local f = CreateFrame("Frame", "LayerSwapMenu", UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetWidth(MENU_W)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(f)
  bg:SetColorTexture(0.04, 0.04, 0.04, 0.92)
  f.items = {}
  if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "LayerSwapMenu" end
  f:Hide()
  return f
end

local function menuItem(i)
  local b = menu.items[i]
  if b then return b end
  b = CreateFrame("Button", nil, menu)
  b:SetHeight(MENU_ROW)
  b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * MENU_ROW)
  b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4 - (i - 1) * MENU_ROW)
  local lit = b:CreateTexture(nil, "HIGHLIGHT")
  lit:SetAllPoints(b)
  lit:SetColorTexture(1, 1, 1, 0.1)
  -- both texts are bound on both sides: the name stops before the age
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
  b.label:SetPoint("RIGHT", b, "RIGHT", -64, 0)
  b.label:SetJustifyH("LEFT")
  b.label:SetWordWrap(false)
  b.age = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.age:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  b.age:SetWidth(56)
  b.age:SetJustifyH("RIGHT")
  b.age:SetWordWrap(false)
  b:SetScript("OnClick", function(self)
    if not self.enabled then return end
    -- nil = any layer but this one; the panel may be closed, so the status goes to chat.
    -- The ask goes out before the menu closes: nothing runs between the click and the send.
    local result = requestSwap(self.id, "menu")
    closeMenu()
    if result ~= "held" then sayStatus() end
  end)
  menu.items[i] = b
  return b
end

local function openMenu(anchor)
  menu = menu or buildMenu()
  local rows = { { text = current and "Any other layer" or "Any layer", enabled = true } }
  local seen = seenInZone()
  for i = 1, math.min(#seen, MENU_LAYERS) do
    local l = seen[i]
    rows[#rows + 1] = { text = layerLabel(l.id) .. "  -  " .. l.id, age = agoText(time() - l.last), id = l.id, enabled = true }
  end
  if #seen == 0 then rows[#rows + 1] = { text = "Layers you have stood on appear here.", enabled = false } end
  if current then rows[#rows + 1] = { text = layerLabel(current) .. "  -  you are here", enabled = false } end
  for i, r in ipairs(rows) do
    local b = menuItem(i)
    b.id, b.enabled = r.id, r.enabled
    b:EnableMouse(r.enabled)            -- a greyed row neither lights up nor clicks
    b.label:SetText(r.text)
    local shade = r.enabled and 1 or 0.55
    b.label:SetTextColor(shade, shade, shade)
    b.age:SetText(r.age or "")
    b:Show()
  end
  for i = #rows + 1, #menu.items do menu.items[i]:Hide() end
  menu:SetHeight(#rows * MENU_ROW + 8)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Show()
end

local function toggleMenu(anchor)
  if menu and menu:IsShown() then menu:Hide() else openMenu(anchor) end
end

-- ---------------------------------------------------------------------------------------
-- the mini line: stays on screen with the layer, LIVE while hosting, and the countdown when
-- the game announces a move. The logo drops the layer menu, a click elsewhere opens the
-- panel, drag moves it, /ls mini hides it.

local function miniText()
  local parts = { current and layerLabel(current) or "Detecting..." }
  if hosting then parts[#parts + 1] = "|cffff4040LIVE|r" end
  local now = GetTime()
  if swap and not swap.joinedAt and now - swap.at <= SWAP_TTL then parts[#parts + 1] = "|cffffd100asking|r" end
  local r = refreshIn(now)
  if r then parts[#parts + 1] = "|cffffb040refresh " .. (r == "soon" and "soon" or ("in " .. r)) .. "|r" end
  return table.concat(parts, "   ")
end

refreshMini = function()
  if not mini or not mini:IsShown() then return end
  mini.text:SetText(miniText())
  -- the line is as wide as its text, so the text can never run out of it
  mini:SetWidth(math.ceil(mini.text:GetStringWidth() or 0) + 52)
  showLive(mini.dot, mini.pulse, hosting)
end

local function saveMini()
  local point, _, _, x, y = mini:GetPoint()
  LayerSwapDB.mini = { point = point, x = x, y = y, hidden = not mini:IsShown() }
end

-- How dark the mini bar's background is, 0-100 (a user on CurseForge, 20 Oct 2026: "change
-- background or opacity of the minibar?"); 55 was the fixed value up to 1.12.
local MINI_BACKGROUND = 55
local function miniBackground()
  local v = LayerSwapDB.miniBackground
  if type(v) ~= "number" or v ~= v then return MINI_BACKGROUND end
  return math.max(0, math.min(100, math.floor(v + 0.5)))
end

local function applyMiniBackground()
  if mini and mini.bg then mini.bg:SetColorTexture(0, 0, 0, miniBackground() / 100) end
end

local function buildMini()
  local m = CreateFrame("Button", "LayerSwapMini", UIParent)
  m:SetHeight(20)
  m:SetFrameStrata("MEDIUM")
  m:SetClampedToScreen(true)
  m:SetMovable(true)
  m:RegisterForDrag("LeftButton")
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local pos = LayerSwapDB.mini
  if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" and type(pos.point) == "string" then
    m:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  else
    m:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
  local bg = m:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(m)
  bg:SetColorTexture(0, 0, 0, miniBackground() / 100)
  m.bg = bg
  -- the LayerSwap logo, left of the LIVE dot: a click drops the layer menu
  m.logo = CreateFrame("Button", "LayerSwapMiniLogo", m)
  m.logo:SetSize(16, 16)
  m.logo:SetPoint("LEFT", m, "LEFT", 3, 0)
  local icon = m.logo:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(m.logo)
  icon:SetTexture("Interface/AddOns/LayerSwap/Media/logo")
  local lit = m.logo:CreateTexture(nil, "HIGHLIGHT")
  lit:SetAllPoints(m.logo)
  lit:SetColorTexture(1, 1, 1, 0.15)
  m.logo:SetScript("OnClick", function() toggleMenu(m) end)
  m.dot, m.pulse = makeLiveDot(m, 30)
  m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  m.text:SetPoint("LEFT", m, "LEFT", 42, 0)
  m.text:SetJustifyH("LEFT")
  m.text:SetWordWrap(false)
  m:SetScript("OnDragStart", function(self) self.moved = true; self:StartMoving() end)
  m:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); saveMini() end)
  m:SetScript("OnClick", function(self, button)
    if self.moved then self.moved = nil; return end     -- the end of a drag is not a click
    if button == "RightButton" then
      -- for anyone who does not want it on screen all the time
      toggleMini()
      say("the mini bar is hidden - the Mini bar button in the panel (/ls) or /ls mini brings it back.")
      refresh()
      return
    end
    togglePanel()
  end)
  -- no tooltips on the line: it sits on screen all the time, and one popping up at every
  -- pass of the mouse was in the way (Adam, 24 Sep 2026)
  m:SetScript("OnShow", function(self)
    refreshMini()
    self.ticker = self.ticker or C_Timer.NewTicker(1, refreshMini)   -- the countdown
  end)
  m:SetScript("OnHide", function(self)
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    closeMenu()
  end)
  m:Hide()
  return m
end

toggleMini = function()
  mini = mini or buildMini()
  if mini:IsShown() then mini:Hide() else mini:Show() end
  saveMini()
end

-- ---------------------------------------------------------------------------------------
-- minimap button (LibDBIcon; the libraries ship inside LayerSwap): left-click the panel, right-click
-- the settings menu (Adam, 8 Oct 2026; hosting is switched in the panel or the menu). No LIVE dot
-- on the button: the mini line carries it (Adam, 25 Sep 2026)

local function minimapLibs()
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  local icons = LibStub and LibStub("LibDBIcon-1.0", true)
  return LDB, icons
end

local function minimapShown()
  return not (type(LayerSwapDB.minimap) == "table" and LayerSwapDB.minimap.hide)
end

local function toggleMinimap()
  local _, icons = minimapLibs()
  if not (icons and type(LayerSwapDB.minimap) == "table") then return end
  LayerSwapDB.minimap.hide = not LayerSwapDB.minimap.hide
  if LayerSwapDB.minimap.hide then icons:Hide("LayerSwap") else icons:Show("LayerSwap") end
end

-- ---------------------------------------------------------------------------------------
-- settings (Adam, 8 Oct 2026): a small menu on the minimap button's right-click, and the same
-- switches in the game's Options -> AddOns -> LayerSwap.

local showSettingsMenu, setupOptions
do
  local optionsFrame, optionsCategory, settingsMenu

  local function onOff(on) return on and "|cff40ff40ON|r" or "|cffa0a0a0OFF|r" end
  local function miniShown() return mini ~= nil and mini:IsShown() end
  local function panelShown() return panel ~= nil and panel:IsShown() end

  local function openOptions()
    if InCombatLockdown and InCombatLockdown() then say("the options open after combat."); return end
    if optionsCategory and Settings and Settings.OpenToCategory then
      pcall(Settings.OpenToCategory, optionsCategory:GetID())
    elseif optionsFrame and InterfaceOptionsFrame_OpenToCategory then
      -- the old options window lands on the page only at the second call
      pcall(InterfaceOptionsFrame_OpenToCategory, optionsFrame)
      pcall(InterfaceOptionsFrame_OpenToCategory, optionsFrame)
    end
  end

  local function hideMinimapButton()
    toggleMinimap()
    if not minimapShown() then
      say("the minimap button is hidden - Options -> AddOns -> LayerSwap or /ls minimap brings it back.")
    end
  end

  -- the menu: rows like the layer menu's; a switch keeps the menu open and shows its new state
  local function rows()
    return {
      { text = panelShown() and "Close the panel" or "Open the panel", run = togglePanel, close = true },
      { text = "Host: " .. onOff(hosting), run = function() setHosting(not hosting) end },
      { text = "Mini bar: " .. onOff(miniShown()), run = toggleMini },
      { text = "Minimap button: " .. onOff(true), run = hideMinimapButton, close = true },
      { text = "Options...", run = openOptions, close = true },
    }
  end

  local function render()
    local list = rows()
    for i, r in ipairs(list) do
      local b = settingsMenu.items[i]
      if not b then
        b = CreateFrame("Button", nil, settingsMenu)
        b:SetHeight(MENU_ROW)
        b:SetPoint("TOPLEFT", settingsMenu, "TOPLEFT", 4, -4 - (i - 1) * MENU_ROW)
        b:SetPoint("TOPRIGHT", settingsMenu, "TOPRIGHT", -4, -4 - (i - 1) * MENU_ROW)
        local lit = b:CreateTexture(nil, "HIGHLIGHT")
        lit:SetAllPoints(b)
        lit:SetColorTexture(1, 1, 1, 0.1)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
          local row = self.row
          if row.close then settingsMenu:Hide() end
          row.run()
          if settingsMenu:IsShown() then render() end
          refresh()
        end)
        settingsMenu.items[i] = b
      end
      b.row = r
      b.label:SetText(r.text)
      b:Show()
    end
    settingsMenu:SetHeight(#list * MENU_ROW + 8)
  end

  -- anchor: the minimap button; a second click on it closes the menu again
  showSettingsMenu = function(anchor)
    if settingsMenu and settingsMenu:IsShown() then settingsMenu:Hide(); return end
    closeMenu()
    if not settingsMenu then
      settingsMenu = CreateFrame("Frame", "LayerSwapSettingsMenu", UIParent)
      settingsMenu:SetFrameStrata("DIALOG")
      settingsMenu:SetClampedToScreen(true)
      settingsMenu:SetWidth(170)
      local bg = settingsMenu:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(settingsMenu)
      bg:SetColorTexture(0.04, 0.04, 0.04, 0.92)
      settingsMenu.items = {}
      if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "LayerSwapSettingsMenu" end
    end
    render()
    settingsMenu:ClearAllPoints()
    if type(anchor) == "table" and anchor.GetObjectType then
      settingsMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
    else
      settingsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    settingsMenu:Show()
  end

  -- Options -> AddOns -> LayerSwap: the same switches, each with a line on what it does
  setupOptions = function()
    if optionsFrame then return end
    local o = CreateFrame("Frame", "LayerSwapOptions", UIParent)
    o.name = "LayerSwap"
    o:Hide()
    local title = o:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", o, "TOPLEFT", 16, -16)
    title:SetText("LayerSwap")
    local sub = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetPoint("RIGHT", o, "RIGHT", -16, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("See your layer, ask for a swap, and host swaps for others. /ls opens the panel.")
    o.checks = {}
    local y = -64
    local function check(key, label, note, get, set)
      local cb = CreateFrame("CheckButton", "LayerSwapOption" .. key, o, "UICheckButtonTemplate")
      cb:SetPoint("TOPLEFT", o, "TOPLEFT", 16, y)
      local name = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      name:SetPoint("LEFT", cb, "RIGHT", 4, 1)
      name:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      name:SetJustifyH("LEFT")
      name:SetWordWrap(false)
      name:SetText(label)
      local line = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      line:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
      line:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      line:SetJustifyH("LEFT")
      line:SetWordWrap(true)
      if line.SetMaxLines then line:SetMaxLines(2) end
      line:SetHeight(math.ceil((line:GetLineHeight() or 12) * 2))
      line:SetText(note)
      cb.get = get
      cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        self:SetChecked(get())
        refresh()
      end)
      o.checks[#o.checks + 1] = cb
      y = y - 46
    end
    o.sliders = {}
    -- A slider with its label, value and note. No Blizzard template, so it looks the same on
    -- Forever, Era and Anniversary (1.13); it glides, with no steps to snap to, and set() applies
    -- the value at once. The value text is bound on both sides, like every other text.
    local function slider(key, label, note, lines, minV, maxV, step, get, set, format)
      local sName = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      sName:SetPoint("TOPLEFT", o, "TOPLEFT", 20, y - 4)
      sName:SetText(label)
      local sValue = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      sValue:SetPoint("LEFT", sName, "RIGHT", 8, 0)
      sValue:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      sValue:SetJustifyH("LEFT")
      sValue:SetWordWrap(false)
      local sNote = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sNote:SetPoint("TOPLEFT", sName, "BOTTOMLEFT", 0, -3)
      sNote:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      sNote:SetJustifyH("LEFT")
      sNote:SetWordWrap(lines > 1)
      local noteHeight = math.ceil((sNote:GetLineHeight() or 12) * lines)
      if lines > 1 then
        if sNote.SetMaxLines then sNote:SetMaxLines(lines) end
        sNote:SetHeight(noteHeight)
      end
      sNote:SetText(note)
      local s = CreateFrame("Slider", "LayerSwapOption" .. key, o)
      s:SetOrientation("HORIZONTAL")
      s:SetSize(200, 16)
      s:SetPoint("TOPLEFT", sNote, "BOTTOMLEFT", 0, -8)
      s:SetMinMaxValues(minV, maxV)
      s:SetValueStep(step)
      s:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
      local track = s:CreateTexture(nil, "BACKGROUND")
      track:SetPoint("LEFT", s, "LEFT", 0, 0)
      track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
      track:SetHeight(4)
      track:SetColorTexture(0.25, 0.25, 0.25, 0.9)
      s.get, s.valueText, s.format = get, sValue, format
      s:SetScript("OnValueChanged", function(_, value)
        sValue:SetText(format(set(tonumber(value))))
      end)
      o.sliders[#o.sliders + 1] = s
      y = y - 52 - noteHeight
    end
    -- Host: the same switch as the panel's Host button and /ls host; off lasts until the logout (1.14.7)
    check("Host", "Host", "Invite players who ask for a layer, only while you are alone. Off lasts until you log out - Host is on again at every login.",
      function() return hosting end,
      function(on) if on ~= hosting then setHosting(on) end end)
    if FOREVER then
      -- Only new layers (1.14.14; a user on CurseForge, 10 Nov 2026): Swap layer names the layers seen in the
      -- zone, and hosts on them skip the ask. Off to start: in a zone with two layers it would end after one swap.
      check("NewOnly", "Only new layers",
        "Swap layer asks only for layers you have not seen in this zone in the last hour. Click a layer in the panel's list to go back to one. Hosts on older versions may still invite you.",
        function() return LayerSwapDB.newOnly == true end,
        function(on)
          LayerSwapDB.newOnly = on and true or false
          log("newOnly", on and "on" or "off")
        end)
      -- Skip askers near you (1.14; a user on CurseForge, 23 Oct 2026, farming a spot with Host
      -- on). Off to start. The notes say what gets past it: another host in the zone, a whisper,
      -- and that an ask without a position is skipped too (see Near.check).
      check("SkipNear", "Skip askers near you",
        "With Host on, you skip anyone who asks from within the distance below, so a swap does not bring someone to the spot you farm. Their position comes with their request; hosting sends nothing of yours. Other hosts in your zone still invite.",
        Near.on,
        function(on)
          LayerSwapDB.skipNear = on and true or false
          log("near", on and "on" or "off")
        end)
      slider("SkipNearDistance", "Distance",
        "Closer than this, and the asker is skipped. An ask that carries no position (an older LayerSwap, or a line typed by hand) is skipped too.", 2,
        Near.MIN, Near.MAX, 10, Near.yards,
        function(value)
          local n = math.max(Near.MIN, math.min(Near.MAX, math.floor((value or Near.DEFAULT) / 10 + 0.5) * 10))
          if n ~= Near.yards() then LayerSwapDB.skipNearYards = n end
          return n
        end,
        function(v) return v .. " yards" end)
    end
    check("MiniBar", "Mini bar", "The small line with your layer, the LIVE dot and the world refresh countdown.",
      miniShown, function(on) if on ~= miniShown() then toggleMini() end end)
    check("Minimap", "Minimap button", "Left-click opens the panel, right-click the settings menu.",
      minimapShown, function(on) if on ~= minimapShown() then toggleMinimap() end end)
    -- Mini bar background: a slider, 0-100 % (1.13); the line fades with it as it moves (Adam,
    -- 21 Oct 2026: "seamless"), and the value is kept across logins.
    slider("MiniBackground", "Mini bar background",
      "How dark the small line's background is. 0% is see-through, 100% is solid.", 1,
      0, 100, 1, miniBackground,
      function(value)
        local pct = math.max(0, math.min(100, math.floor((value or MINI_BACKGROUND) + 0.5)))
        if pct ~= miniBackground() then
          LayerSwapDB.miniBackground = pct
          applyMiniBackground()
        end
        return pct
      end,
      function(v) return v .. "%" end)
    local open = CreateFrame("Button", "LayerSwapOptionsOpen", o, "UIPanelButtonTemplate")
    open:SetSize(150, 22)
    open:SetPoint("TOPLEFT", o, "TOPLEFT", 20, y - 6)
    open:SetText("Open the panel")
    open:SetScript("OnClick", function() if not panelShown() then togglePanel() end end)
    o:SetScript("OnShow", function(self)
      for _, cb in ipairs(self.checks) do cb:SetChecked(cb.get()) end
      for _, s in ipairs(self.sliders) do
        s:SetValue(s.get())
        s.valueText:SetText(s.format(s.get()))
      end
    end)
    optionsFrame = o
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
      local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, o, "LayerSwap")
      if ok and category then
        optionsCategory = category
        pcall(Settings.RegisterAddOnCategory, category)
      end
    elseif InterfaceOptions_AddCategory then
      pcall(InterfaceOptions_AddCategory, o)
    end
  end
end

local function setupMinimap()
  local LDB, icons = minimapLibs()
  if not (LDB and icons) then return end
  if type(LayerSwapDB.minimap) ~= "table" then LayerSwapDB.minimap = {} end
  local launcher = LDB:NewDataObject("LayerSwap", {
    type = "launcher",
    icon = "Interface/AddOns/LayerSwap/Media/logo",
    OnClick = function(button, mouse)
      joinLayerChannel()
      if mouse == "RightButton" then showSettingsMenu(button) else togglePanel() end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("LayerSwap")
      tt:AddLine((current and layerLabel(current) or "Detecting...") .. (hosting and "   |cffff4040LIVE|r" or ""), 1, 1, 1)
      tt:AddLine("Left-click: the panel.  Right-click: settings.", 0.7, 0.7, 0.7)
    end,
  })
  icons:Register("LayerSwap", launcher, LayerSwapDB.minimap)
end

-- ---------------------------------------------------------------------------------------
-- after a host who did not move us (1.9)

-- In the group of a host on our layer, or in another zone, nothing changes until the player
-- leaves (a user on CurseForge, 10 Oct 2026: "I don't want to keep leaving party and requesting
-- again"). LayerSwap leaves by itself, and names that host if it invites again. The ask
-- itself is the player's click: the game blocks the channel line without one, while leaving the
-- group works without (both measured 10 Oct 2026: ADDON_ACTION_BLOCKED on the line, "You leave
-- the group." on the leave). So the panel opens with Swap layer ready, one click away.
local function autoLeave(joined)
  if not FOREVER then return end
  local host = joined.inviter or "The host"
  if joined.inviter and current then
    sameHosts[joined.inviter] = { at = GetTime(), layer = current, elsewhere = joined.elsewhere }
  end
  local only = not joined.elsewhere and onlyLayerHere()
  log("autoLeave", joined.inviter, current,
    joined.elsewhere and ("in " .. joined.elsewhere) or (joined.refreshed and "world refreshed, same layer") or "on our layer",
    only and "the only layer seen in this zone" or nil)
  if IsInGroup() then pcall(leaveParty) end
  leftInfo = { at = GetTime(), layer = current }
  swapGroup, swap = false, nil
  C_Timer.After(2, function() log("leftCheck", IsInGroup() and "still in a group" or "out") end)
  local line, chat
  if joined.elsewhere then
    line = host .. " was in " .. joined.elsewhere .. ". Click Swap layer again."
    chat = host .. " was in " .. joined.elsewhere .. " and did not move you. LayerSwap left the group - click Swap layer in the panel to ask again."
  elseif joined.refreshed then
    line = host .. " did not move you. Click Swap layer to ask again."
    chat = host .. " did not move you: the game refreshed the world, and you are on the same layer. LayerSwap left the group - click Swap layer in the panel to ask again."
  elseif only then
    line = host .. " was on your layer, the only one seen here."
    chat = host .. " was on your layer, so nothing changed. Only one layer has been seen in " .. only
      .. " - it may have just one right now, so try a busier zone. LayerSwap left the group."
  else
    line = host .. " was on your layer. Click Swap layer to ask again."
    chat = host .. " was on your layer, so nothing changed. LayerSwap left the group - click Swap layer in the panel to ask again."
  end
  setNotice(line, 60)
  say(chat)
  panel = panel or buildPanel()
  if not panel:IsShown() then panel:Show() end
  refresh()
end

-- An invite from a host who did not move us: said, never declined - the invite is the player's
-- (1.10; 1.9 declined it while an ask waited, and a declined invite was itself reported to change
-- the layer, forever-bugs #33). The panel and chat name the host and where it was.
local function warnInvite(name, seen, ago)
  local where = seen.elsewhere and ("was in " .. seen.elsewhere) or "was on your layer"
  log("sameHostAgain", name, current, seen.elsewhere or "same layer", ago)
  say(name .. " " .. where .. " " .. ago .. " - decline and wait for another host.")
  setNotice(name .. " " .. where .. " " .. ago .. ". Decline and wait for another host.", 30)
  refresh()
end

-- ---------------------------------------------------------------------------------------
-- events

local onEnterWorld   -- below the handler: login or reload, and the login line

local f = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
                      "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE",
                      "GROUP_ROSTER_UPDATE", "GROUP_JOINED", "GROUP_LEFT", "PARTY_INVITE_REQUEST",
                      "SHARD_TRANSFER_IMMINENT", "SHARD_TRANSFER",
                      "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                      "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED", "CHAT_MSG_ADDON",
                      "CHANNEL_COUNT_UPDATE", "CHANNEL_ROSTER_UPDATE", "WHO_LIST_UPDATE",
                      "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHANNEL_PASSWORD_REQUEST" }) do
  pcall(f.RegisterEvent, f, ev)
end
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, NOTE_PREFIX) end
-- 1.14.2: the chat box tells, just before it sends, that the player pressed Enter on our line
if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
  pcall(EventRegistry.RegisterCallback, EventRegistry, "ChatFrame.OnEditBoxPreSendText", function(_, box) Send.preSend(box) end, ADDON)
end
-- 1.14.4: other players' requests and LayerSwap's channel stay out of the chat windows (Send.filterLine)
if FOREVER then
  local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if type(add) == "function" then
    pcall(add, "CHAT_MSG_CHANNEL", Send.filterLine)
    pcall(add, "CHAT_MSG_CHANNEL_NOTICE", Send.filterNotice)
    pcall(add, "CHAT_MSG_CHANNEL_NOTICE_USER", Send.filterNotice)
    pcall(add, "CHAT_MSG_SYSTEM", Who.filterGone)   -- 1.14.14: the game's line for a whisper of ours it could not deliver
  end
end

f:SetScript("OnEvent", function(_, ev, a1, a2, a3, a4, _, _, zoneChannelID, a8, channelBaseName)
  if ev == "NAME_PLATE_UNIT_ADDED" then
    if not isSecret(a1) and type(a1) == "string" then observe(a1) end
  elseif ev == "PLAYER_TARGET_CHANGED" then
    observe("target")
  elseif ev == "UPDATE_MOUSEOVER_UNIT" then
    observe("mouseover")
  elseif ev == "CHAT_MSG_CHANNEL" then
    local where
    if not isSecret(channelBaseName) and type(channelBaseName) == "string"
       and string.lower(channelBaseName) == LAYER_CHANNEL then
      where = "layer"
    elseif Send.isHub(channelBaseName) then
      where = "hub"
    elseif not isSecret(zoneChannelID) and zoneChannelID == 1 then
      where = "general"
    end
    if where then onChat(where, a1, a2) end
  elseif ev == "CHAT_MSG_CHANNEL_NOTICE" or ev == "CHAT_MSG_CHANNEL_NOTICE_USER" then
    Send.notice(a1, a4, zoneChannelID, a8, channelBaseName)
  elseif ev == "CHANNEL_PASSWORD_REQUEST" then
    -- someone set a password on the hub: our join asked for it; the game's box for it is closed
    -- (now and a frame later, whichever handler runs first) and the realm's hub left alone
    if Send.isHub(a1) then
      Send.hubClosed = true
      if Send.HUB_ASKS then Send.refused() end
      log("hub", "password asked")
      pcall(StaticPopup_Hide, "CHAT_CHANNEL_PASSWORD", a1)
      C_Timer.After(0, function() pcall(StaticPopup_Hide, "CHAT_CHANNEL_PASSWORD", a1) end)
    end
  elseif ev == "CHAT_MSG_WHISPER" then
    onChat("whisper", a1, a2)
  elseif ev == "CHAT_MSG_GUILD" then
    onChat("guild", a1, a2)
  elseif ev == "CHAT_MSG_ADDON" then
    -- prefix, text, chat type, sender; a request by hidden whisper (1.14.6) goes to the host's side
    if not isSecret(a1) and a1 == NOTE_PREFIX then
      if not isSecret(a3) and a3 == "WHISPER" and Who.isAsk(a2) then Who.onAsk(a2, a4) else onNote(a2, a4) end
    end
  elseif ev == "WHO_LIST_UPDATE" then
    Who.results()
  elseif ev == "CHAT_MSG_SYSTEM" or ev == "UI_ERROR_MESSAGE" then
    local text = (ev == "UI_ERROR_MESSAGE") and a2 or a1
    if not isSecret(text) and type(text) == "string" then
      if ev == "CHAT_MSG_SYSTEM" and FOREVER then Who.gone(text) end
      if GetTime() <= watchUntil then log(ev == "UI_ERROR_MESSAGE" and "error" or "system", text) end
      -- our invite never counted - another host's got there first, or the asker sat in a group
      -- already - so the asker's next ask is ours to answer. Read at any time: on 10 Oct 2026
      -- the game's reply to an invite came later than the few seconds logged above.
      local why = refusal(text)
      if why then
        for name in pairs(pending) do
          if string.find(text, name, 1, true) then
            pending[name], lastInvite[name] = nil, nil
            log("freed", name, why)
          end
        end
      end
    end
  elseif ev == "CHANNEL_COUNT_UPDATE" or ev == "CHANNEL_ROSTER_UPDATE" then
    onChannelCount(ev, a1, a2)
  elseif ev == "GROUP_ROSTER_UPDATE" then
    onRoster()
  elseif ev == "PARTY_INVITE_REQUEST" then
    local now = GetTime()
    local name = not isSecret(a1) and type(a1) == "string" and a1 or nil
    local seen = name and sameHosts[name]
    if seen and not (current and Layer.same(seen.layer, current) and now - seen.at <= SAME_HOST_TTL) then seen = nil end
    local mins = seen and math.floor((now - seen.at) / 60)
    local ago = mins and (mins < 1 and "a moment ago" or (mins .. " min ago"))
    if seen then warnInvite(name, seen, ago) end
    if name and waitingAsk(now) then
      -- several hosts may answer one ask (1.14.2: no claims where the notes do not travel): the
      -- first keeps the name, the others are only logged, and the group's leader corrects it
      -- a host known to stand on our layer (seen) keeps the name only until another host invites,
      -- and counts as no answer below: the hub's wait and Ask in General go on (1.14.5)
      if swap.inviter and not (swap.inviterSeen and not seen) then
        log("invited", name, "also", string.format("%.1f s after asking", now - swap.at))
      else
        swap.inviter, swap.inviterSeen = name, seen and true or nil
        log("invited", name, string.format("%.1f s after asking", now - swap.at), seen and "known same-layer host" or nil)
      end
      if not seen then
        -- answered: a new ask may go at once from the place that answered (Send.repeatLeft)
        local l = swap.where and Send.lastAt[swap.where]
        if l then l.invited = true end
        if Send.pending and Send.pending.via == "fallback" then Send.drop("invited") end
        -- answered: the rest of the burst would only ask more hosts for an invite already here
        if Who.pending and Who.pending.out and swap.who == Who.pending then
          local w = Who.stop()
          log("who", "burst stopped", "invited", #w.queue .. " left")
        end
      end
      Who.seenWarn(name)
      refresh()
    end
  elseif ev == "GROUP_JOINED" then
    joinedGroupAt = GetTime()
    Who.phase("join")
    Who.phaseSoon("join")
    if not FOREVER then forgetSightings() end   -- no transfer event on Classic to do it
    -- only a group someone invited us into is a host's group: a group we formed by
    -- inviting others is our own, and they came to our layer (beta, 24 Sep 2026)
    if swap and swap.inviter and not swap.joinedAt and GetTime() - swap.at <= SWAP_TTL then
      swap.joinedAt, swapGroup = GetTime(), true
      watchUntil = GetTime() + 20               -- "Party converted to Raid", who else joins ...
      log("joinedHost", swap.inviter, current)
      -- the creatures around us, read now and a little later: they tell whether the join moved us
      Who.scan()
      C_Timer.After(1, Who.scan)
      C_Timer.After(3, Who.scan)
      -- the panel may be closed: say it in chat once, if the game did not move us
      local joined = swap
      Send.moved(nil)
      C_Timer.After(SAME_LAYER_AFTER + 0.2, function()
        -- the group's leader is the host we joined, whatever invite was the first to arrive
        for i = 1, PARTY_MAX - 1 do
          local unit = "party" .. i
          if UnitExists(unit) and UnitIsGroupLeader(unit) then
            local leader = fullName(unit)
            if leader and leader ~= joined.inviter then
              log("inviter", joined.inviter, "corrected to " .. leader)
              -- the swap may have worked already (setCurrent): the host named for the stay follows too
              if held and held.host == joined.inviter then held.host = leader end
              joined.inviter = leader
            end
            break
          end
        end
        log("hostZone", joined.inviter, hostZone(joined.inviter) or "unknown", zoneOf("player") or "unknown",
          joined.transferAt and "moved" or "not moved")
        -- out of the group by itself once the creatures read since the join still show our layer
        -- (Who.FRESH), never before SAME_LAYER_LEAVE, in case the move is only late (1.10); tried
        -- every 2 s for JUDGE_FOR. A host in another zone gets the same time (1.14.8): the game
        -- moves a guest from any zone, and the 1.10-1.14.7 rule that left such a host at once had
        -- only the transfer event to go on.
        local function judge()
          if swap ~= joined then return end
          Who.scan()
          local now = GetTime()
          if now - joined.joinedAt >= SAME_LAYER_LEAVE and hostOnOurLayer(now) then autoLeave(joined)
          elseif now - joined.joinedAt < Who.JUDGE_FOR then C_Timer.After(2, judge) end
        end
        judge()
      end)
      refresh()
    elseif FOREVER then
      -- any other group (the group finder, a friend): who leads it, where, and did the game move
      -- us? (Adam, 8 Oct 2026: a group-finder group moved him to another layer.) Logged only.
      Send.moved("You are in a group - the request was not sent.")
      local at = joinedGroupAt
      C_Timer.After(SAME_LAYER_AFTER + 0.2, function()
        for i = 1, PARTY_MAX - 1 do
          local unit = "party" .. i
          if UnitExists(unit) and UnitIsGroupLeader(unit) then
            log("groupZone", fullName(unit), zoneOf(unit) or "unknown", zoneOf("player") or "unknown",
              lastShardAt > at and "moved" or "not moved")
            break
          end
        end
      end)
    end
  elseif ev == "GROUP_LEFT" then
    onRoster()                                  -- a host's last guest leaving ends the group
    if swapGroup then
      swapGroup = false
      leftInfo = { at = GetTime(), layer = current }
      log("left", current)
      if swap then swap = nil end
      if held then
        held = nil
        -- Once, right after a swap that worked, and only while Host is off: the moment someone
        -- has been helped is the moment to ask them to help the next one (Adam, 8 Oct 2026 - the
        -- channel holds 46-56 players and hardly any hosts). Never again once it has been said.
        if not hosting and not LayerSwapDB.hostAsked then
          LayerSwapDB.hostAsked = true
          setNotice("Help the next one: turn Host on. You only invite while you are alone.", 60)
          say("help the next one: turn Host on in the panel - you only invite while you are alone, and the group is theirs to leave.")
        else
          setNotice("You left the group - you stay on your new layer.", 30)
        end
      end
      refresh()
    end
  elseif ev == "SHARD_TRANSFER_IMMINENT" then
    local left = type(GetEvictionTimeRemaining) == "function" and GetEvictionTimeRemaining() or nil
    evictAt = (not isSecret(left) and type(left) == "number") and (GetTime() + left) or nil
    log("shard", ev, left)
    refresh()
  elseif ev == "SHARD_TRANSFER" or ev == "ZONE_CHANGED_NEW_AREA" or ev == "PLAYER_ENTERING_WORLD" then
    -- the world around the player may be another one now: believe nothing until two
    -- creatures have been seen again
    if ev == "SHARD_TRANSFER" then
      evictAt, lastShardAt = nil, GetTime()
      log("shard", ev)
      Layer.markStale()
      if IsInGroup() then C_Timer.After(1, function() if IsInGroup() then Who.phase("transfer +1 s") end end) end
      -- in the host's group: the game moved us, so the host is on another layer
      if swap and swap.joinedAt and not swap.transferAt then
        swap.transferAt = GetTime()
        log("transfer", string.format("%.1f s after joining", swap.transferAt - swap.joinedAt))
        -- a move after the 'same layer' verdict: the verdict was wrong, so it is forgotten (1.10)
        if swap.sameLogged and swap.inviter then sameHosts[swap.inviter] = nil end
      end
    end
    forgetSightings()
    if ev == "ZONE_CHANGED_NEW_AREA" then
      Who.borderAt = GetTime()
      if current and Who.here and Who.here.layer == current then
        Who.crossing = { from = Who.here.zone, layer = current, at = GetTime(), reads = 0 }
      end
    else
      -- after a world refresh or a login the units in view are read again: a host that stands still
      -- would otherwise wait for a new nameplate, target or mouseover to learn its layer, and skip
      -- every ask meanwhile. Never within BORDER_QUIET of a zone border: a target or a nameplate
      -- carried over it is a creature of the zone left behind, on that zone's layer.
      C_Timer.After(2, Who.rescan)
      C_Timer.After(5, Who.rescan)
      -- and once more after the units of a layer just left are no longer in doubt (Layer.markStale)
      C_Timer.After(Layer.STALE_FOR + 2, Who.rescan)
    end
    if ev ~= "PLAYER_ENTERING_WORLD" then Send.moved("You moved - click Swap layer again.") end
    if ev ~= "PLAYER_ENTERING_WORLD" or current == nil then
      if current then log("layer", "unknown", nil, current) end
      if swap and swap.joinedAt and swap.from == nil then swap.from = "unknown" end
      current = nil
    end
    if ev == "PLAYER_ENTERING_WORLD" then onEnterWorld(a1 == true, a2 == true) end
    refresh()
  elseif ev == "ADDON_ACTION_FORBIDDEN" or ev == "ADDON_ACTION_BLOCKED" then
    if a1 == ADDON then
      log("blocked", ev, a2)
      if sendingAsk then
        askHeldBack = true    -- a swap ask: requestSwap says it in plain words
      else
        say("the game blocked " .. tostring(a2) .. " - that action needs a click on this client.")
      end
    end
  elseif ev == "PLAYER_LOGIN" then
    -- One session per log. The log is read from disk after a /reload, so the session that
    -- was just written is kept one more round instead of being wiped by this login.
    LayerSwapDB.previous = { session = LayerSwapDB.session, log = LayerSwapDB.log }
    LayerSwapDB.log = {}
    LayerSwapDB.session = { started = date("%Y-%m-%d %H:%M:%S"), version = "1.14.14", me = fullName("player"), toc = TOC, restricted = Send.restricted(),
                            search = Who.can() }
    -- The layers seen survive a /reload and a relog; an hour without a sighting drops one.
    local saved = type(LayerSwapDB.layers) == "table" and LayerSwapDB.layers or {}
    layers, layerCount = {}, 0
    for id, l in pairs(saved) do
      if type(l) == "table" and type(l.last) == "number" and type(l.n) == "number" and time() - l.last <= LAYER_TTL then
        layers[id] = l
        if l.n > layerCount then layerCount = l.n end
      end
    end
    if FOREVER then
      -- one entry per layer and zone: variants saved by 1.14.10 or older are merged, the latest kept
      local keep = {}
      for id, l in pairs(layers) do
        local k = tostring(l.zone) .. "|" .. tostring(Layer.key(id))
        if not keep[k] or l.last > layers[keep[k]].last then keep[k] = id end
      end
      for id, l in pairs(layers) do
        if keep[tostring(l.zone) .. "|" .. tostring(Layer.key(id))] ~= id then layers[id] = nil end
      end
    end
    LayerSwapDB.layers = layers
    Who.prune()
    Who.pruneAsked()
    Layer.startCensus()
    -- Host is ON from the first login (Adam, 8 Oct 2026: the layer channel held 56 players and 11
    -- asks in 7 minutes, and he was the only host). The saved switch is read here for a /reload;
    -- a real login turns it on again (onEnterWorld, which knows the two apart). 1.12-1.14.6 kept
    -- an off across logins; 1.11.2's "Host at login" key is dropped. The host invites only while
    -- alone or leading a group it filled itself (canInvite).
    LayerSwapDB.hostAtLogin = nil
    hosting = LayerSwapDB.hosting ~= false
    log("hosting", hosting and "on" or "off", "at login")
    mini = mini or buildMini()
    if not (type(LayerSwapDB.mini) == "table" and LayerSwapDB.mini.hidden) then mini:Show() end
    setupMinimap()
    setupOptions()
    refresh()
  end
end)

-- The first PLAYER_ENTERING_WORLD of a session says whether it is a login or a /reload; the
-- login line is said here. A real login turns Host on (1.14.7); a /reload keeps what was set.
local entered = false
onEnterWorld = function(isLogin, isReload)
  if entered then return end
  entered = true
  if isLogin and not hosting then
    hosting, LayerSwapDB.hosting = true, true
    log("hosting", "on", "new login")
  end
  if hosting and not LayerSwapDB.hostSaid then
    -- the off switch, said plainly the first time, and in the panel when it opens
    LayerSwapDB.hostSaid = true
    say("type /ls to open the panel. Hosting is ON: you invite players who ask for a layer, only while you are alone."
      .. " The Host button in the panel or /ls host turns it off until you log out.")
    setNotice("Host is on: you invite askers while alone. Off lasts until you log out.", 300)
  elseif hosting and isReload then
    say("type /ls to open the panel. Hosting is ON.")
  elseif hosting then
    say("type /ls to open the panel. Hosting is ON - the Host button or /ls host turns it off until you log out.")
  else
    say("type /ls to open the panel. Hosting is OFF until you log out - the Host button or /ls host turns it on.")
  end
  if hosting then
    -- a channel can only be joined from a click; the game rejoins it by itself once joined. On a
    -- realm that refuses addon chat that is LayerSwap's own channel, never the layer channel.
    C_Timer.After(10, function()
      if not hosting then return end
      if Send.restricted() then
        if Send.HUB_ASKS and GetChannelName(Send.HUB) == 0 and not Send.left() and not Send.realmRefused() then
          say("hosting hears General, guild chat and whispers - open the panel (/ls) once to hear LayerSwap's own channel too, where requests go now.")
        end
      elseif GetChannelName(LAYER_CHANNEL) == 0 then
        say("hosting hears General, guild chat and whispers - open the panel (/ls) once to hear the layer channel too.")
      end
    end)
  end
  refresh()
end

-- ---------------------------------------------------------------------------------------
-- slash

local function status()
  say(string.format("you are on %s%s. Hosting is %s: %d request(s) seen, %d invite(s) sent, %d joined, %d skipped.",
    layerLabel(current), current and (" (" .. current .. ")") or "", hosting and "ON" or "OFF",
    stats.requests, stats.invites, stats.joined, stats.skipped))
  if hosting then
    local ok, why = canInvite()
    say(ok and "ready to invite." or ("not inviting right now: " .. why .. "."))
    if Near.on() then say("skipping askers within " .. Near.yards() .. " yards of you.") end
    if not Send.restricted() and GetChannelName(LAYER_CHANNEL) == 0 then say("you are not in the '" .. LAYER_CHANNEL .. "' channel - type /join " .. LAYER_CHANNEL) end
  end
  if FOREVER then
    local r = Send.restricted()
    say("addon chat: " .. (r and "restricted on this realm - Swap layer puts your request in the chat box for your own Enter" or "allowed - Swap layer sends the request itself"))
    local c = Send.comms.CHANNEL
    say("hidden notes in the layer channel: " .. (c == "refused" and "refused by the game" or c == "ok" and "working" or (r and "not used" or "untried")))
    local state, id = Send.layerState()
    local said = { ["ok"] = "joined as " .. tostring(id) .. ", listed by the game", ["not joined"] = "not joined",
                   ["not listed"] = "number " .. tostring(id) .. ", not listed by the game yet",
                   closed = "closed to you here", disabled = "disabled for your account by the game" }
    say("layer channel: " .. (said[state] or state) .. (r and " - used only when LayerSwap's channel and General are not there" or ""))
    if r then
      local hs, hid = Send.hubState()
      local hsaid = { ok = "joined as " .. tostring(hid) .. ", kept out of your chat windows",
                      ["not joined"] = Send.left() and ("you left it - /join " .. Send.HUB .. " brings it back")
                        or (Send.realmRefused() and ("it refused you on this realm - LayerSwap asks again in " .. Send.refusedLeft()))
                        or (Send.hubTried and "asked to join this session - the server has not let you in")
                        or "not joined yet - a click on LayerSwap joins it",
                      ["not listed"] = "number " .. tostring(hid) .. ", not listed by the game yet",
                      closed = "closed to you here", disabled = "disabled for your account by the game" }
      if Send.HUB_ASKS then say("LayerSwap channel: " .. (hsaid[hs] or hs))
      else say("LayerSwap channel: " .. (hs == "ok" and "joined - read for requests from older versions, never asked" or "not used")) end
      say("hidden whispers: " .. Who.state())
      say("requests go to: " .. (Who.refused and "your guild only, with /ls guild" or Send.placeName(Who.can() and "direct" or (Send.place(GetTime())))))
    end
    if Send.pending then
      say("request: in the chat box for " .. math.floor(GetTime() - Send.pending.at) .. " s - press Enter to send it, Escape to drop it")
    elseif Who.pending and not Who.pending.out then
      say("request: searching for players for " .. math.floor(GetTime() - Who.pending.at) .. " s")
    elseif waitingAsk(GetTime()) then
      say("request: out since " .. clock(GetTime() - swap.at) .. " ago to " .. Send.placeName(swap.where or "layer"))
    end
  end
end

SLASH_LAYERSWAP1 = "/ls"
SLASH_LAYERSWAP2 = "/layerswap"
SlashCmdList["LAYERSWAP"] = function(msg)
  msg = string.lower(strtrim(tostring(msg or "")))
  if msg == "" then
    togglePanel()
  elseif msg == "host" or msg == "on" or msg == "off" then
    if msg == "host" then setHosting(not hosting) else setHosting(msg == "on") end
    status()
  elseif msg == "swap" then
    if requestSwap(nil, "slash") ~= "held" then sayStatus() end
  elseif msg == "swap new" then
    -- 1.14.14: one ask for a layer not seen in this zone (Forever); elsewhere a plain ask
    if requestSwap(nil, FOREVER and "new" or "slash") ~= "held" then sayStatus() end
  elseif msg == "guild" then
    if requestGuild("slash") ~= "held" then sayStatus() end
  elseif msg == "stop" then
    if stopAsking("slash") then sayStatus() else say("you are not asking for a swap right now.") end
  elseif not FOREVER and msg:match("^swap%s+%d+$") then
    -- /ls swap 2 (Classic): NWB's layer 2 - AutoLayer hosts on it answer even if we never stood there
    local n, zone, target = tonumber(msg:match("^swap%s+(%d+)$")), Layer.zone()
    for id, l in pairs(layers) do
      if l.nwb == n and l.zone == zone then target = id end
    end
    if requestSwap(target, "slash", false, n) ~= "held" then sayStatus() end
  elseif msg:match("^swap%s+%a$") then
    -- /ls swap B: the letter the panel shows, in this zone
    local letter, zone, target = string.upper(msg:match("^swap%s+(%a)$")), Layer.zone()
    for id, l in pairs(layers) do
      if l.letter == letter and l.zone == zone then target = id end
    end
    if target then
      if requestSwap(target, "slash") ~= "held" then sayStatus() end
    else say("no Layer " .. letter .. " seen in this zone - the panel lists the ones you can ask for.") end
  elseif msg == "kick" then
    kickHosted()
  elseif msg == "status" then
    status()
  elseif msg == "mini" then
    toggleMini()
  elseif msg == "minimap" then
    toggleMinimap()
  elseif msg == "phase" and FOREVER then
    local line = Who.phase("slash")
    say(line and ("phase: " .. line .. " | you: party shard " .. Who.shard("player")) or "not in a group - nothing to read.")
  elseif msg == "spot" and FOREVER then
    -- where the game says you stand, logged raw (1.14): the reading behind Skip askers near you
    local room = #(LayerSwapDB.log or {}) < LOG_MAX
    local ok, p, why, raw, moved = pcall(Near.probe, "probe")
    if not ok then
      say("the position reading failed: " .. tostring(p))
    else
      say((p and ("position " .. p.kind .. " " .. p.ref .. " " .. p.x .. " " .. p.y) or ("no position: " .. tostring(why)))
        .. (moved and (" - " .. moved) or "") .. " (" .. table.concat(raw, "; ") .. "). "
        .. (room and "Logged; /reload saves it to disk." or "Not logged: the log is full."))
    end
  else
    say("/ls - open the panel   |   /ls mini - show or hide the small line   |   /ls minimap - show or hide the minimap button   |   /ls swap - ask for any other layer   |   /ls swap B - ask for Layer B   |   /ls swap new - ask for a layer you have not seen   |   /ls guild - ask your guild   |   /ls stop - stop asking   |   /ls host - start or stop hosting   |   /ls kick - remove the players LayerSwap invited"
      .. (FOREVER and "   |   /ls spot - log where you stand" or "") .. "   |   /ls status")
  end
end

local ADDON, ns = ...

local CliqueBar = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceEvent-3.0", "AceConsole-3.0")
ns.addon = CliqueBar
_G.CliqueBar = CliqueBar

local C_Spell = _G.C_Spell
local C_SpellActivationOverlay = _G.C_SpellActivationOverlay
local C_SpellBook = _G.C_SpellBook

local function GetSpellTextureByID(spellID)
	if not spellID then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(spellID)
	end
	return (select(3, GetSpellInfo(spellID)))
end

-- Classic clients keep every rank of a spell as its own spellbook entry, and Clique
-- stores the bound rank in bind.spellSubName. A bare-name lookup returns whichever rank
-- the client hands back first (in practice the lowest), so the bar would show Rank 1 for
-- a binding that actually casts Rank 6. Walking the spellbook maps an explicit rank
-- exactly, and a rank-less binding to the highest known rank -- what /cast casts. The
-- legacy globals only exist on classic-flavored clients; WoW Forever (camelot) is a
-- retail-engine client with classic ranked spells, so it needs the C_SpellBook API,
-- whose book items carry the same name/subName/spellID triple per rank.
local RANKED_SPELLBOOK = GetNumSpellTabs and GetSpellTabInfo
	and GetSpellBookItemName and GetSpellBookItemInfo
local CAMELOT_SPELLBOOK = C_SpellBook
	and C_SpellBook.GetNumSpellBookSkillLines
	and C_SpellBook.GetSpellBookSkillLineInfo
	and C_SpellBook.GetSpellBookItemInfo

local spellBook -- built lazily, dropped on every BuildEntries so new ranks are picked up

local function BuildSpellBook()
	local ranks, highest = {}, {}
	if CAMELOT_SPELLBOOK then
		local bank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player or 0
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if lineInfo then
				local offset = lineInfo.itemIndexOffset or 0
				for i = 1, lineInfo.numSpellBookItems or 0 do
					local item = C_SpellBook.GetSpellBookItemInfo(offset + i, bank)
					-- itemType 1 = spell (pet/mount/flyout slots have no rank subtext)
					if item and item.itemType == 1 and item.name and item.spellID then
						if item.subName and item.subName ~= "" then
							ranks[item.name .. "\0" .. item.subName] = item.spellID
						end
						highest[item.name] = item.spellID -- ranks are listed ascending: the last one wins
					end
				end
			end
		end
		return { ranks = ranks, highest = highest }
	end
	if not RANKED_SPELLBOOK then return { ranks = ranks, highest = highest } end
	local bookType = BOOKTYPE_SPELL or "spell"
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(tab)
		offset = offset or 0
		for slot = offset + 1, offset + (numSpells or 0) do
			local kind, spellID = GetSpellBookItemInfo(slot, bookType)
			if kind == "SPELL" and spellID then
				local name, subName = GetSpellBookItemName(slot, bookType)
				if name then
					if subName and subName ~= "" then
						ranks[name .. "\0" .. subName] = spellID
					end
					highest[name] = spellID -- ranks are listed ascending: the last one wins
				end
			end
		end
	end
	return { ranks = ranks, highest = highest }
end

local function InvalidateSpellBook()
	spellBook = nil
end

local function GetRankedSpellID(name, subName)
	if not ((RANKED_SPELLBOOK or CAMELOT_SPELLBOOK) and name) then return nil end
	if not subName then
		-- "Healing Wave(Rank 3)": the form macros (and older Clique data) carry the rank in.
		local base, rank = string.match(name, "^(.-)%s*%((.+)%)%s*$")
		if base and base ~= "" then name, subName = base, rank end
	end
	spellBook = spellBook or BuildSpellBook()
	if subName and subName ~= "" then
		return spellBook.ranks[name .. "\0" .. subName]
	end
	return spellBook.highest[name]
end

local function GetSpellIDByName(name)
	if not name then return nil end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		return info and info.spellID
	end
	return (select(7, GetSpellInfo(name)))
end

-- startTime/duration (and modRate) become secret values while Blizzard's combat addon
-- restrictions are in effect (12.0.5+); isActive/isEnabled/isOnGCD are never secret,
-- so callers gate on those when the times can't be read.
local function GetSpellCooldownByID(spellID)
	if not spellID then return 0, 0, true end
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(spellID)
		if info then
			return info.startTime, info.duration, info.isEnabled, info.isActive, info.isOnGCD
		end
		return 0, 0, true
	end
	local start, duration, enabled = GetSpellCooldown(spellID)
	return start or 0, duration or 0, enabled
end

-- Secret-safe cooldown display: Cooldown:SetCooldown refuses secret arguments from
-- addon code, so while restrictions are active the swipe must be fed a duration
-- object via SetCooldownFromDurationObject, which renders without exposing numbers.
local function GetSpellCooldownDurationByID(spellID)
	if not (spellID and C_Spell and C_Spell.GetSpellCooldownDuration) then return nil end
	return C_Spell.GetSpellCooldownDuration(spellID)
end

local function GetSpellChargesByID(spellID)
	if not spellID then return nil end
	if C_Spell and C_Spell.GetSpellCharges then
		local info = C_Spell.GetSpellCharges(spellID)
		if info then return info.currentCharges, info.maxCharges end
		return nil
	end
	if GetSpellCharges then
		return GetSpellCharges(spellID)
	end
	return nil
end

-- Proc highlight state, same source the default action bars read. The flat
-- IsSpellOverlayed is deprecated since 11.2; the namespace form replaces it. The
-- return is a plain boolean — never a secret value — so it stays readable while the
-- 12.x combat addon restrictions are in effect.
local function IsSpellOverlayedByID(spellID)
	if not spellID then return false end
	if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
		return not not C_SpellActivationOverlay.IsSpellOverlayed(spellID)
	end
	if IsSpellOverlayed then
		return not not IsSpellOverlayed(spellID)
	end
	return false
end

local SPELL_OVERLAY_SUPPORTED =
	(C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) ~= nil
	or _G.IsSpellOverlayed ~= nil

local function SetTooltipSpell(tooltip, spellID)
	if not spellID then return false end
	if tooltip.SetSpellByID then
		tooltip:SetSpellByID(spellID)
	elseif tooltip.SetHyperlink then
		tooltip:SetHyperlink("spell:" .. spellID)
	else
		return false
	end
	return true
end

ns.util = {
	GetSpellTextureByID = GetSpellTextureByID,
	GetSpellIDByName = GetSpellIDByName,
	GetRankedSpellID = GetRankedSpellID,
	GetSpellCooldownByID = GetSpellCooldownByID,
	GetSpellCooldownDurationByID = GetSpellCooldownDurationByID,
	GetSpellChargesByID = GetSpellChargesByID,
	IsSpellOverlayedByID = IsSpellOverlayedByID,
	spellOverlaySupported = SPELL_OVERLAY_SUPPORTED,
	SetTooltipSpell = SetTooltipSpell,
}

-- "CliqueBar · v1.2.3" for the drag handle. In an unpackaged checkout the TOC token
-- is still literal (no real version yet), so show "dev" instead; packaged builds get
-- the real version stamped by the packager.
function ns.BrandLabel()
	local v = ns.version or ""
	if v == "" or v:find("@") then
		return "CliqueBar |cff9d9d9d· dev|r"
	end
	return "CliqueBar |cff9d9d9d· v" .. v:gsub("^[vV]", "") .. "|r"
end

local defaults = {
	profile = {
		locked = false,
		visibility = "always",
		iconSize = 36,
		perRow = 12,
		rows = 0,
		spacing = 4,
		growth = "RIGHT_DOWN",
		showKeys = true,
		keyDash = false,
		tooltipKey = false,
		showCooldown = true,
		showGlow = true,
		border = true,
		masque = true,
		whichBinds = "macros",
		sort = "clique",
		order = {},
		scale = 1.0,
		opacity = 1.0,
		point = { "CENTER", "CENTER", 0, 0 },
		minimap = { hide = false },
	},
}

local MOD_ABBR = { SHIFT = "s", ALT = "a", CTRL = "c", META = "m" }
local BUTTON_ABBR = {
	BUTTON1 = "M1", BUTTON2 = "M2", BUTTON3 = "M3", BUTTON4 = "M4", BUTTON5 = "M5",
	LeftButton = "M1", RightButton = "M2", MiddleButton = "M3",
}

function CliqueBar:FormatKey(key)
	if not key or key == "" then return "" end
	local parts = {}
	for token in string.gmatch(key, "[^%-]+") do
		parts[#parts + 1] = token
	end
	local last = parts[#parts]
	local label = BUTTON_ABBR[last] or last
	local prefix = {}
	for i = 1, #parts - 1 do
		prefix[#prefix + 1] = MOD_ABBR[parts[i]] or parts[i]:sub(1, 1):lower()
	end
	if #prefix > 0 then
		local sep = self.db.profile.keyDash and "-" or ""
		return table.concat(prefix, sep) .. sep .. label
	end
	return label
end

function CliqueBar:GetCliqueBindings()
	local Clique = _G.Clique
	if not Clique then return nil end
	local binds = Clique.bindings
	if not binds and Clique.db and Clique.db.profile then
		binds = Clique.db.profile.bindings or Clique.db.profile.binds
	end
	if not binds and Clique.profile then
		binds = Clique.profile.binds or Clique.profile.bindings
	end
	return binds
end

-- Best-effort: pull the first cast out of a macro so it can lend its icon, cooldown,
-- and tooltip. Strips [conditionals], toggles, and castsequence reset/list syntax.
local function ParseMacroSpell(macrotext)
	if not macrotext or macrotext == "" then return nil end
	for line in string.gmatch(macrotext, "[^\r\n]+") do
		local body = string.match(line, "^%s*#?/cast%s+(.+)$")
			or string.match(line, "^%s*/use%s+(.+)$")
			or string.match(line, "^%s*/castsequence%s+(.+)$")
		if body then
			body = string.gsub(body, "%b[]", "")
			body = string.gsub(body, "reset=%S+", "")
			body = string.gsub(body, "!", "")
			local first = string.match(body, "([^;,]+)")
			if first then
				first = string.gsub(first, "^%s+", "")
				first = string.gsub(first, "%s+$", "")
				if first ~= "" then return first end
			end
		end
	end
	return nil
end

function CliqueBar:BuildEntries()
	local entries = {}
	local binds = self:GetCliqueBindings()
	if not binds then return entries end
	InvalidateSpellBook()

	local mode = self.db.profile.whichBinds -- "spells" | "macros" | "all"
	for _, bind in ipairs(binds) do
		if type(bind) == "table" then
			local key = bind.key or ""
			if bind.type == "spell" then
				local spellID = GetRankedSpellID(bind.spell, bind.spellSubName)
					or bind.spellID or GetSpellIDByName(bind.spell)
				local texture = GetSpellTextureByID(spellID) or bind.icon
				entries[#entries + 1] = {
					label = self:FormatKey(bind.key),
					spellID = spellID,
					texture = texture,
					name = bind.spell,
					key = key,
					id = key ~= "" and key or ("n:" .. tostring(bind.spell)),
					idx = #entries + 1,
				}
			elseif bind.type == "macro" and mode ~= "spells" then
				local spellName = ParseMacroSpell(bind.macrotext or bind.macro or bind.arg1)
				local spellID = spellName
					and (GetRankedSpellID(spellName) or GetSpellIDByName(spellName))
					or nil
				local texture = bind.icon or GetSpellTextureByID(spellID)
				entries[#entries + 1] = {
					label = self:FormatKey(bind.key),
					spellID = spellID,
					texture = texture,
					name = spellName or MACRO,
					key = key,
					id = key ~= "" and key or ("n:m:" .. tostring(bind.macrotext or #entries)),
					idx = #entries + 1,
				}
			elseif mode == "all" then
				entries[#entries + 1] = {
					label = self:FormatKey(bind.key),
					spellID = nil,
					texture = bind.icon,
					name = bind.spell or bind.type,
					key = key,
					id = key ~= "" and key or ("n:" .. tostring(bind.spell or bind.type)),
					idx = #entries + 1,
				}
			end
		end
	end
	return entries
end

local KEY_SORT_MOD = { CTRL = 1, ALT = 2, SHIFT = 4, META = 8 }

-- Build a comparable sort key from a Clique key ("SHIFT-BUTTON2"). Ordering:
-- unmodified keys first, then modified; within each, numbers, then letters, then
-- everything else (mouse, function keys); each group sorted naturally.
function CliqueBar:KeySortKey(key)
	local parts = {}
	for token in string.gmatch(key or "", "[^%-]+") do
		parts[#parts + 1] = token
	end
	local base = parts[#parts] or ""
	local mask = 0
	for i = 1, #parts - 1 do
		mask = mask + (KEY_SORT_MOD[parts[i]] or 0)
	end
	local rank, bsort
	if base:match("^%d$") then
		local n = tonumber(base)
		rank, bsort = 0, string.format("%02d", n == 0 and 10 or n)
	elseif base:match("^%a$") then
		rank, bsort = 1, base:upper()
	else
		rank, bsort = 2, base:upper()
	end
	return string.format("%d%d%s\031%02d", mask > 0 and 1 or 0, rank, bsort, mask)
end

function CliqueBar:SortEntries(entries)
	local mode = self.db.profile.sort
	if mode == "name" then
		table.sort(entries, function(a, b)
			local an, bn = (a.name or ""):lower(), (b.name or ""):lower()
			if an ~= bn then return an < bn end
			return a.idx < b.idx
		end)
	elseif mode == "key" then
		for _, e in ipairs(entries) do
			e.sortkey = self:KeySortKey(e.key)
		end
		table.sort(entries, function(a, b)
			if a.sortkey ~= b.sortkey then return a.sortkey < b.sortkey end
			return a.idx < b.idx
		end)
	elseif mode == "manual" then
		-- Assign each entry a grid slot from the saved order. The order array is
		-- indexed by slot and may contain `false` for a deliberately empty cell;
		-- stale ids (bind removed) also leave their slot empty. New binds append.
		local byId = {}
		for _, e in ipairs(entries) do byId[e.id] = e end
		local used = {}
		local slot = 0
		for _, v in ipairs(self.db.profile.order or {}) do
			if v and byId[v] and not used[v] then
				byId[v].slot = slot
				used[v] = true
			end
			slot = slot + 1
		end
		for _, e in ipairs(entries) do
			if not used[e.id] then
				e.slot = slot
				used[e.id] = true
				slot = slot + 1
			end
		end
		table.sort(entries, function(a, b) return a.slot < b.slot end)
	end
	-- "clique" keeps the order Clique itself stores.
end

-- Move the icon at fromSlot onto toSlot: fill an empty target (leaving the source
-- empty) or swap with an occupied one, then rewrite the saved slot order.
function CliqueBar:MoveEntryToSlot(fromSlot, toSlot)
	if not fromSlot or not toSlot or fromSlot == toSlot then return end
	local bySlot = {}
	local maxSlot = math.max(fromSlot, toSlot)
	for _, e in ipairs(self.entries or {}) do
		if e.slot then
			bySlot[e.slot] = e.id
			if e.slot > maxSlot then maxSlot = e.slot end
		end
	end
	local moving = bySlot[fromSlot]
	if not moving then return end
	bySlot[fromSlot] = bySlot[toSlot]
	bySlot[toSlot] = moving

	local order = {}
	for s = 0, maxSlot do order[s + 1] = bySlot[s] or false end
	while #order > 0 and order[#order] == false do order[#order] = nil end
	self.db.profile.order = order
	self:Refresh()
end

function CliqueBar:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("CliqueBarDB", defaults)
	-- Guard the surfaces that lean on client-version-specific APIs (native Settings,
	-- addon compartment) so a mismatch on one flavor can't stop the bar from loading.
	local okOptions, optErr = pcall(self.SetupOptions, self)
	if not okOptions then
		self:Print("options panel unavailable: " .. tostring(optErr))
	end
	pcall(self.SetupBroker, self)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self:RegisterChatCommand("cliquebar", "SlashHandler")
	self:RegisterChatCommand("cbar", "SlashHandler")
end

function CliqueBar:OnProfileChanged()
	if self.bar then
		self:RestorePosition()
		self:ApplyLock()
	end
	if self.LDBIcon then
		self.LDBIcon:Refresh("CliqueBar", self.db.profile.minimap)
	end
	-- The new profile may have the glow disabled; re-check the event registrations.
	self:SetGlowEventsEnabled(true)
	self:Refresh()
end

function CliqueBar:TryRegisterEvent(event, handler)
	pcall(self.RegisterEvent, self, event, handler)
end

-- The glow driver listens only while the feature is enabled and the client has the
-- spell-overlay API; disabled means no event registrations at all (zero-cost-when-
-- disabled). Toggling the option routes through here, then Refresh() re-syncs state.
function CliqueBar:SetGlowEventsEnabled(enabled)
	if not SPELL_OVERLAY_SUPPORTED then return end
	if enabled and self.db.profile.showGlow then
		self:TryRegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "UpdateGlows")
		self:TryRegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "UpdateGlows")
	else
		pcall(self.UnregisterEvent, self, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
		pcall(self.UnregisterEvent, self, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
	end
end

function CliqueBar:OnEnable()
	self:CreateBar()
	self:TryRegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
	self:TryRegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "Refresh")
	self:TryRegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "Refresh")
	self:TryRegisterEvent("PLAYER_TALENT_UPDATE", "Refresh")
	self:TryRegisterEvent("TRAIT_CONFIG_UPDATED", "Refresh")
	self:TryRegisterEvent("LEARNED_SPELL_IN_TAB", "Refresh") -- new rank trained (Classic)
	self:TryRegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateCooldowns")
	self:TryRegisterEvent("SPELL_UPDATE_CHARGES", "UpdateCharges")
	self:TryRegisterEvent("PLAYER_REGEN_ENABLED", "UpdateVisibility")
	self:TryRegisterEvent("PLAYER_REGEN_DISABLED", "UpdateVisibility")
	self:TryRegisterEvent("GROUP_ROSTER_UPDATE", "UpdateVisibility")
	self:SetGlowEventsEnabled(true)
	self:Refresh()
end

function CliqueBar:HookClique()
	local Clique = _G.Clique
	if not Clique or self.cliqueHooked then return end
	local function onChange() self:Refresh() end
	for _, method in ipairs({ "AddBinding", "DeleteBinding", "SetBinding", "UpdateGlobalAttributes" }) do
		if type(Clique[method]) == "function" then
			hooksecurefunc(Clique, method, onChange)
			self.cliqueHooked = true
		end
	end
end

function CliqueBar:Refresh()
	self:HookClique()
	self.entries = self:BuildEntries()
	self:SortEntries(self.entries)
	self:LayoutBar()
	self:UpdateVisibility()
	self:UpdateCooldowns()
	self:UpdateCharges()
	self:UpdateGlows()
	self:UpdateBroker()
end

function CliqueBar:SlashHandler(input)
	input = (input or ""):lower():gsub("%s+", "")
	if input == "lock" then
		self.db.profile.locked = not self.db.profile.locked
		self:ApplyLock()
	elseif input == "about" then
		ns.ShowAbout()
	else
		self:OpenOptions()
	end
end

local _, ns = ...
local L = ns.L
local util = ns.util
local CliqueBar = ns.addon

local Masque = LibStub and LibStub("Masque", true)
ns.Masque = Masque

local QUESTION_MARK = "Interface\\ICONS\\INV_Misc_QuestionMark"
local GCD_THRESHOLD = 1.5

-- Retail 12.x: cooldown times come back as secret values while combat addon
-- restrictions are active; nil on every other flavor.
local issecretvalue = _G.issecretvalue
local C_StringUtil = _G.C_StringUtil
local NUMERIC_RULE_UP = _G.Enum and _G.Enum.NumericRuleFormatRounding and _G.Enum.NumericRuleFormatRounding.Up

-- Engine-rendered countdown text for restricted cooldowns: the widget computes the
-- seconds internally, so secrets are fine where our OnUpdate text can't read them.
-- Built on first use, styled to match the OnUpdate text (whole seconds, Xm past a
-- minute) — same NumericRuleFormatter approach NDui uses for native numbers.
local countdownFormatter
local function GetRestrictedCountdownFormatter()
	if countdownFormatter then return countdownFormatter end
	if not (C_StringUtil and NUMERIC_RULE_UP) then return nil end
	local ok, f = pcall(C_StringUtil.CreateNumericRuleFormatter)
	if not (ok and f) then return nil end
	f:SetBreakpoints({
		{ threshold = 0, format = "%d", components = { { step = 1, rounding = NUMERIC_RULE_UP } } },
		{ threshold = 60, format = "%dm", components = { { div = 60, step = 1, rounding = NUMERIC_RULE_UP } } },
	})
	countdownFormatter = f
	return f
end

local GROWTH_ANCHOR = {
	RIGHT_DOWN = "TOPLEFT",
	RIGHT_UP = "BOTTOMLEFT",
	LEFT_DOWN = "TOPRIGHT",
	LEFT_UP = "BOTTOMRIGHT",
}

local BORDER_TEXTURE = "Interface\\Buttons\\UI-Quickslot2"
-- Match Blizzard action buttons: a 36px icon wears a 66px Quickslot2 border, so the
-- gold ring hugs the icon edge instead of leaving it poking out past the frame.
local BORDER_SCALE = 66 / 36

-- Proc highlight glow, mirroring the default action bars' spell alert. Retail ships
-- the flipbook art as the virtual ActionButtonSpellAlertTemplate (its mixin chains a
-- 0.7s birth flipbook into a looping pulse); flavors without the template fall back
-- to the classic IconAlert ADD-blend pulse. Frames are created lazily on first glow
-- and recycled forever after — hidden with animations stopped, never destroyed.
local SPELL_ALERT_TEMPLATE = "ActionButtonSpellAlertTemplate"
local ICON_ALERT_TEXTURE = "Interface\\SpellActivationOverlay\\IconAlert"
-- Blizzard's ActionButtonSpellAlertManager sizes the alert at 1.4x the button, but
-- our icons are cropped (texcoords 0.07-0.93) under a ~1.83x border ring, so at 1.4x
-- the animated ring stayed tucked inside the icon. 1.8x lets it clear the border
-- without spilling as far as native bars do (sized by feel in in-game testing).
local GLOW_SCALE = 1.8

local function ClearCooldown(cd)
	if cd.Clear then
		cd:Clear()
	else
		cd:SetCooldown(0, 0)
	end
end

local function AcquireGlow(btn)
	if btn.glow then return btn.glow end

	local ok, glow = pcall(CreateFrame, "Frame", nil, btn, SPELL_ALERT_TEMPLATE)
	-- Require the animation keys too: a client that resolves the template but renames
	-- them must fall back, not error inside the event handler on every glow change.
	if ok and glow and glow.ProcStartAnim and glow.ProcLoop then
		glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
		local w, h = btn:GetSize()
		glow:SetSize(w * GLOW_SCALE, h * GLOW_SCALE)
		function glow:StartGlow()
			self:Show()
			self.ProcStartAnim:Play() -- OnFinished chains into the looping ProcLoop
		end
		function glow:StopGlow()
			self.ProcStartAnim:Stop()
			self:Hide() -- template OnHide stops the looping pulse
		end
		btn.glow = glow
		return glow
	end

	-- Classic fallback: ADD-blend pulse that fades in once, then loops forever.
	glow = CreateFrame("Frame", nil, btn)
	glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
	local w, h = btn:GetSize()
	glow:SetSize(w * GLOW_SCALE, h * GLOW_SCALE)
	local tex = glow:CreateTexture(nil, "OVERLAY")
	tex:SetTexture(ICON_ALERT_TEXTURE)
	tex:SetBlendMode("ADD")
	tex:SetAllPoints()
	local fadeIn = glow:CreateAnimationGroup()
	local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
	fadeInAlpha:SetDuration(0.2)
	fadeInAlpha:SetFromAlpha(0)
	fadeInAlpha:SetToAlpha(1)
	local pulse = glow:CreateAnimationGroup()
	pulse:SetLooping("REPEAT")
	local pulseAlpha = pulse:CreateAnimation("Alpha")
	pulseAlpha:SetDuration(1)
	pulseAlpha:SetFromAlpha(0.6)
	pulseAlpha:SetToAlpha(1)
	fadeIn:SetScript("OnFinished", function() pulse:Play() end)
	function glow:StartGlow()
		self:Show()
		fadeIn:Play()
	end
	function glow:StopGlow()
		fadeIn:Stop()
		pulse:Stop()
		self:Hide()
	end
	btn.glow = glow
	return glow
end

local function StopGlow(btn)
	if btn.glowActive and btn.glow then
		btn.glow:StopGlow()
		btn.glowActive = false
	end
end

local function CooldownTextOnUpdate(overlay, elapsed)
	overlay.elapsed = (overlay.elapsed or 0) + elapsed
	if overlay.elapsed < 0.1 then return end
	overlay.elapsed = 0
	local btn = overlay.button
	local start, duration = btn.cdStart, btn.cdDuration
	local remaining = (start and duration) and (start + duration - GetTime()) or 0
	if remaining <= 0 then
		overlay:SetScript("OnUpdate", nil)
		btn.cdText:Hide()
		return
	end
	if remaining >= 60 then
		btn.cdText:SetText(string.format("%dm", math.ceil(remaining / 60)))
	else
		btn.cdText:SetText(string.format("%d", math.ceil(remaining)))
	end
	btn.cdText:Show()
end

function CliqueBar:CreateBar()
	if self.bar then return end

	local f = CreateFrame("Frame", "CliqueBarFrame", UIParent)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetSize(1, 1)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame)
		if not self.db.profile.locked then frame:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SavePosition()
	end)
	f:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" then self:ShowContextMenu(f) end
	end)

	-- Shown when unlocked: a highlight that sits BELOW the icons and handles the empty
	-- bar area — left-drag to move, right-click for the menu. Icons stay on top so their
	-- tooltips and Manual-sort dragging keep working.
	local overlay = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(1)
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:SetScript("OnDragStart", function()
		if not self.db.profile.locked then f:StartMoving() end
	end)
	overlay:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		self:SavePosition()
	end)
	overlay:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" then self:ShowContextMenu(overlay) end
	end)
	if overlay.SetBackdrop then
		overlay:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		overlay:SetBackdropColor(0, 0.6, 1, 0.25)
		overlay:SetBackdropBorderColor(0, 0.6, 1, 0.9)
	end
	overlay:Hide()
	self.dragOverlay = overlay

	-- A grab handle above the bar so it can always be moved, even at zero spacing or
	-- while Manual sort uses icon-drag for reordering.
	local handle = CreateFrame("Frame", nil, f)
	handle:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
	handle:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
	handle:SetHeight(14)
	handle:SetFrameStrata("HIGH")
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if not self.db.profile.locked then f:StartMoving() end
	end)
	handle:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		self:SavePosition()
	end)
	handle:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" then self:ShowContextMenu(handle) end
	end)
	local htex = handle:CreateTexture(nil, "BACKGROUND")
	htex:SetAllPoints()
	htex:SetTexture("Interface\\Buttons\\WHITE8x8")
	htex:SetVertexColor(0, 0.6, 1, 0.5)
	local hlabel = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hlabel:SetPoint("CENTER")
	hlabel:SetText(ns.BrandLabel())
	handle:Hide()
	self.moveHandle = handle

	local dh = CreateFrame("Frame", nil, f)
	dh:SetFrameStrata("HIGH")
	local dht = dh:CreateTexture(nil, "OVERLAY")
	dht:SetAllPoints()
	dht:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	dht:SetBlendMode("ADD")
	dh:Hide()
	self.dropHighlight = dh
	self.dragUpdater = CreateFrame("Frame", nil, f)

	self.bar = f
	self.buttons = self.buttons or {}
	self:RestorePosition()
	self:ApplyLock()
end

function CliqueBar:SavePosition()
	local point, _, relPoint, x, y = self.bar:GetPoint()
	self.db.profile.point = { point, relPoint, x, y }
end

function CliqueBar:RestorePosition()
	local p = self.db.profile.point
	self.bar:ClearAllPoints()
	self.bar:SetPoint(p[1] or "CENTER", UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
end

function CliqueBar:ApplyLock()
	local f = self.bar
	if not f then return end
	local locked = self.db.profile.locked
	f:EnableMouse(not locked)
	if self.dragOverlay then
		self.dragOverlay:SetShown(not locked)
	end
	if self.moveHandle then
		self.moveHandle:SetShown(not locked)
	end
	-- Re-lay out so icon drag registration and the drop placeholders track the lock
	-- state even when it changes from the minimap or the right-click menu (no Refresh).
	self:LayoutBar()
	-- Lock toggling also flips the unlocked-always-visible rule in UpdateVisibility.
	self:UpdateVisibility()
end

function CliqueBar:GetMasqueGroup()
	if not Masque then return nil end
	if not self.masqueGroup then
		self.masqueGroup = Masque:Group("CliqueBar")
	end
	return self.masqueGroup
end

function CliqueBar:UpdateButtonBorder(btn)
	if not btn.border then return end
	local skinned = ns.Masque ~= nil and self.db.profile.masque and btn.masqued
	btn.border:SetShown(self.db.profile.border and not skinned)
end

function CliqueBar:SkinButton(btn)
	if not self.db.profile.masque then return end
	local group = self:GetMasqueGroup()
	if not group then return end
	group:AddButton(btn, { Icon = btn.icon, Cooldown = btn.cooldown, HotKey = btn.key }, "Action")
	btn.masqued = true
	self:UpdateButtonBorder(btn)
end

function CliqueBar:ApplyMasque()
	local group = self:GetMasqueGroup()
	if not group then return end
	local enabled = self.db.profile.masque
	for i = 1, #(self.buttons or {}) do
		local btn = self.buttons[i]
		if enabled then
			group:AddButton(btn, { Icon = btn.icon, Cooldown = btn.cooldown, HotKey = btn.key }, "Action")
			btn.masqued = true
		elseif btn.masqued then
			group:RemoveButton(btn)
			btn.masqued = false
		end
		self:UpdateButtonBorder(btn)
	end
	if enabled then group:ReSkin(true) end
end

function CliqueBar:AcquireButton(index)
	local btn = self.buttons[index]
	if btn then return btn end

	btn = CreateFrame("Frame", "CliqueBarButton" .. index, self.bar)
	btn:SetFrameLevel(self.bar:GetFrameLevel() + 5)
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetAllPoints()
	btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	btn.cooldown = CreateFrame("Cooldown", "$parentCooldown", btn, "CooldownFrameTemplate")
	btn.cooldown:SetAllPoints()
	if btn.cooldown.SetDrawEdge then btn.cooldown:SetDrawEdge(false) end
	if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end

	-- Parented to the button (not the Cooldown frame) and kept above it, so the count
	-- and charge text stay visible over the swipe and even when the swipe is hidden.
	btn.cdOverlay = CreateFrame("Frame", nil, btn)
	btn.cdOverlay:SetAllPoints()
	btn.cdOverlay:SetFrameLevel(btn.cooldown:GetFrameLevel() + 5)
	btn.cdOverlay.button = btn
	btn.cdText = btn.cdOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.cdText:SetPoint("CENTER")
	btn.cdText:Hide()

	btn.chargeText = btn.cdOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.chargeText:SetPoint("BOTTOMRIGHT", -1, 1)
	btn.chargeText:SetJustifyH("RIGHT")
	btn.chargeText:Hide()

	btn.border = btn:CreateTexture(nil, "OVERLAY")
	btn.border:SetTexture(BORDER_TEXTURE)
	btn.border:SetPoint("CENTER")

	btn.key = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	btn.key:SetJustifyH("RIGHT")
	btn.key:SetPoint("TOPLEFT", 1, -2)
	btn.key:SetPoint("TOPRIGHT", -1, -2)

	btn:EnableMouse(true)
	btn:SetScript("OnEnter", function(b) self:OnButtonEnter(b) end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	btn:SetScript("OnDragStart", function(b) self:OnButtonDragStart(b) end)
	btn:SetScript("OnDragStop", function(b) self:OnButtonDragStop(b) end)
	btn:SetScript("OnMouseUp", function(b, mouseButton)
		if mouseButton == "RightButton" then self:ShowContextMenu(b) end
	end)

	self.buttons[index] = btn
	self:SkinButton(btn)
	return btn
end

function CliqueBar:ManualDragEnabled()
	return self.db.profile.sort == "manual" and not self.db.profile.locked
end

function CliqueBar:AcquirePlaceholder(index)
	self.placeholders = self.placeholders or {}
	local ph = self.placeholders[index]
	if ph then return ph end
	ph = CreateFrame("Frame", nil, self.bar)
	ph.border = ph:CreateTexture(nil, "OVERLAY")
	ph.border:SetTexture(BORDER_TEXTURE)
	ph.border:SetPoint("CENTER")
	ph.border:SetVertexColor(1, 1, 1, 0.5)
	self.placeholders[index] = ph
	return ph
end

-- Position an empty, droppable cell for every unoccupied slot of the grid. They
-- stay hidden until a drag begins (see SetPlaceholdersShown) so an idle bar shows
-- no empty borders.
function CliqueBar:LayoutPlaceholders(active, rows, perRow, size, spacing, anchor, dirX, dirY)
	self.placeholders = self.placeholders or {}
	local shown = 0
	if active then
		local occupied = {}
		for _, btn in ipairs(self.buttons) do
			if btn:IsShown() then occupied[btn.slot] = true end
		end
		for slot = 0, rows * perRow - 1 do
			if not occupied[slot] then
				shown = shown + 1
				local ph = self:AcquirePlaceholder(shown)
				ph.slot = slot
				ph:SetSize(size, size)
				ph.border:SetSize(size * BORDER_SCALE, size * BORDER_SCALE)
				local col = slot % perRow
				local row = math.floor(slot / perRow)
				ph:ClearAllPoints()
				ph:SetPoint(anchor, self.bar, anchor, dirX * col * (size + spacing), dirY * row * (size + spacing))
			end
		end
	end
	self.placeholderCount = shown
	for i = 1, #self.placeholders do
		self.placeholders[i]:Hide()
	end
end

function CliqueBar:SetPlaceholdersShown(show)
	for i = 1, (self.placeholderCount or 0) do
		self.placeholders[i]:SetShown(show)
	end
end

function CliqueBar:DropTargetUnderCursor()
	for _, btn in ipairs(self.buttons) do
		if btn ~= self.draggingButton and btn:IsShown() and btn:IsMouseOver() then
			return btn
		end
	end
	for _, ph in ipairs(self.placeholders or {}) do
		if ph:IsShown() and ph:IsMouseOver() then return ph end
	end
	return nil
end

function CliqueBar:UpdateDropHighlight()
	local target = self:DropTargetUnderCursor()
	local hl = self.dropHighlight
	if target then
		hl:ClearAllPoints()
		hl:SetPoint("CENTER", target, "CENTER")
		hl:SetSize(target:GetWidth(), target:GetHeight())
		hl:Show()
	else
		hl:Hide()
	end
end

function CliqueBar:OnButtonDragStart(btn)
	if self:ManualDragEnabled() then
		self.draggingButton = btn
		btn.icon:SetAlpha(0.4)
		GameTooltip:Hide()
		self:SetPlaceholdersShown(true)
		if self.dragUpdater then
			self.dragUpdater:SetScript("OnUpdate", function() self:UpdateDropHighlight() end)
		end
	elseif not self.db.profile.locked then
		-- Unlocked outside Manual arrange: icons sit on top of the drag overlay, so
		-- left-dragging an icon moves the whole bar instead of being swallowed.
		GameTooltip:Hide()
		self.bar:StartMoving()
	end
end

function CliqueBar:OnButtonDragStop(btn)
	btn.icon:SetAlpha(1)
	-- Resolve the drop target BEFORE hiding the placeholders — DropTargetUnderCursor only
	-- considers shown ones, and draggingButton must still be set to exclude the dragged icon.
	local target
	if self.draggingButton == btn then
		target = self:DropTargetUnderCursor()
	elseif self.bar then
		self.bar:StopMovingOrSizing()
		self:SavePosition()
	end
	self:SetPlaceholdersShown(false)
	if self.dragUpdater then self.dragUpdater:SetScript("OnUpdate", nil) end
	if self.dropHighlight then self.dropHighlight:Hide() end
	self.draggingButton = nil
	if target then self:MoveEntryToSlot(btn.slot, target.slot) end
end

function CliqueBar:OnButtonEnter(btn)
	GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
	local shown = false
	if btn.spellID then
		shown = util.SetTooltipSpell(GameTooltip, btn.spellID)
	end
	if not shown then
		GameTooltip:SetText(btn.spellName or "CliqueBar")
	end
	if self.db.profile.tooltipKey and btn.keyLabel and btn.keyLabel ~= "" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Clique key:"] .. " |cffffffff" .. btn.keyLabel .. "|r", 0.5, 0.5, 0.5)
	end
	GameTooltip:Show()
end

function CliqueBar:LayoutBar()
	if not self.bar then return end
	local p = self.db.profile
	local entries = self.entries or {}
	local size, perRow, spacing = p.iconSize, p.perRow, p.spacing
	local anchor = GROWTH_ANCHOR[p.growth] or "TOPLEFT"
	local dirX = (p.growth == "LEFT_DOWN" or p.growth == "LEFT_UP") and -1 or 1
	local dirY = (p.growth == "RIGHT_UP" or p.growth == "LEFT_UP") and 1 or -1
	local n = #entries
	local cdFont = NumberFontNormal:GetFont()
	local cdFontSize = math.max(10, size * 0.45)
	local chargeFontSize = math.max(9, size * 0.35)
	local manualDrag = self:ManualDragEnabled()

	local maxSlot = -1
	for i = 1, n do
		local e = entries[i]
		local btn = self:AcquireButton(i)
		btn.entryId = e.id
		local slot = e.slot or (i - 1)
		btn.slot = slot
		if slot > maxSlot then maxSlot = slot end
		if manualDrag or not p.locked then
			btn:RegisterForDrag("LeftButton")
		else
			btn:RegisterForDrag()
		end
		btn:SetSize(size, size)
		btn.border:SetSize(size * BORDER_SCALE, size * BORDER_SCALE)
		btn.cdText:SetFont(cdFont, cdFontSize, "OUTLINE")
		btn.chargeText:SetFont(cdFont, chargeFontSize, "OUTLINE")
		self:UpdateButtonBorder(btn)
		btn.icon:SetTexture(e.texture or QUESTION_MARK)
		btn.spellID = e.spellID
		btn.spellName = e.name
		btn.keyLabel = e.label
		btn.key:SetText(p.showKeys and e.label or "")
		btn.cooldown:SetShown(p.showCooldown and e.spellID ~= nil)
		if btn.glow then
			local glowSize = size * GLOW_SCALE
			btn.glow:SetSize(glowSize, glowSize)
		end

		local col = slot % perRow
		local row = math.floor(slot / perRow)
		local x = dirX * col * (size + spacing)
		local y = dirY * row * (size + spacing)
		btn:ClearAllPoints()
		btn:SetPoint(anchor, self.bar, anchor, x, y)
		btn:Show()
	end

	for i = n + 1, #self.buttons do
		local btn = self.buttons[i]
		btn:Hide()
		ClearCooldown(btn.cooldown)
		self:StopCooldownText(btn)
		StopGlow(btn)
	end

	local totalCells = math.max(maxSlot + 1, 1)
	local fixedRows = (p.sort == "manual") and (p.rows or 0) or 0
	local rows, cols
	if fixedRows > 0 then
		rows = math.max(fixedRows, math.ceil(totalCells / perRow))
		cols = perRow
	else
		rows = math.max(1, math.ceil(totalCells / perRow))
		cols = rows > 1 and perRow or totalCells
	end
	self.bar:SetSize(
		cols * size + (cols - 1) * spacing,
		rows * size + (rows - 1) * spacing
	)
	self:LayoutPlaceholders(manualDrag, rows, perRow, size, spacing, anchor, dirX, dirY)
	self.bar:SetScale(p.scale)
	self.bar:SetAlpha(p.opacity)
	self:UpdateCharges()
end

function CliqueBar:StartCooldownText(btn, start, duration)
	if not btn.cdOverlay then return end
	btn.cdStart = start
	btn.cdDuration = duration
	btn.cdOverlay.elapsed = 0.1
	btn.cdOverlay:SetScript("OnUpdate", CooldownTextOnUpdate)
end

function CliqueBar:StopCooldownText(btn)
	if not btn.cdOverlay then return end
	btn.cdStart = nil
	btn.cdDuration = nil
	btn.cdOverlay:SetScript("OnUpdate", nil)
	if btn.cdText then btn.cdText:Hide() end
end

function CliqueBar:UpdateCooldowns()
	if not self.buttons then return end
	local show = self.db.profile.showCooldown
	for _, btn in ipairs(self.buttons) do
		if btn:IsShown() and btn.spellID and show then
			local start, duration, enabled, isActive, onGCD = util.GetSpellCooldownByID(btn.spellID)
			if issecretvalue and issecretvalue(duration) then
				-- Secret times can't be compared, and SetCooldown rejects secret
				-- arguments from addon code: the swipe must go through a duration
				-- object (which includes the GCD, so the never-secret flags replace
				-- the duration>GCD filter). Our OnUpdate text can't read the times,
				-- but the widget's own countdown numbers are engine-rendered, so
				-- they work on secrets. pcall covers the known taint edge case.
				local durationObject = util.GetSpellCooldownDurationByID(btn.spellID)
				local shown = false
				if durationObject and enabled ~= false and isActive ~= false and not onGCD then
					shown = pcall(btn.cooldown.SetCooldownFromDurationObject, btn.cooldown, durationObject)
				end
				if shown then
					local fmt = GetRestrictedCountdownFormatter()
					if fmt then btn.cooldown:SetCountdownFormatter(fmt) end
					btn.cooldown:SetHideCountdownNumbers(false)
				else
					ClearCooldown(btn.cooldown)
				end
				self:StopCooldownText(btn)
			elseif start and duration and duration > GCD_THRESHOLD then
				if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end
				btn.cooldown:SetCooldown(start, duration)
				self:StartCooldownText(btn, start, duration)
			else
				if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end
				ClearCooldown(btn.cooldown)
				self:StopCooldownText(btn)
			end
		elseif btn.cooldown then
			ClearCooldown(btn.cooldown)
			self:StopCooldownText(btn)
		end
	end
end

function CliqueBar:UpdateCharges()
	if not self.buttons then return end
	for _, btn in ipairs(self.buttons) do
		local fs = btn.chargeText
		if fs then
			if btn:IsShown() and btn.spellID then
				local current, max = util.GetSpellChargesByID(btn.spellID)
				if max and max > 1 then
					-- currentCharges may be secret under restrictions; SetText is
					-- AllowedWhenTainted and still renders it (maxCharges never secrets).
					fs:SetText(current)
					fs:Show()
				else
					fs:Hide()
				end
			else
				fs:Hide()
			end
		end
	end
end

function CliqueBar:UpdateGlows(event, spellID)
	if not self.buttons then return end
	local show = self.db.profile.showGlow
	for _, btn in ipairs(self.buttons) do
		-- IsVisible, not IsShown: a hidden bar (combat/group visibility modes) must
		-- stop glow animations instead of ticking them on invisible buttons.
		if not show or not btn:IsVisible() or not btn.spellID then
			StopGlow(btn)
		elseif spellID == nil or spellID == btn.spellID then
			-- HIDE may fire without a spellID; treat that as a full re-query pass,
			-- which also covers entries rebuilt mid-proc (Refresh calls with none).
			-- Normalise nil/false: a button that has never glowed carries glowActive = nil
			-- and would otherwise read as a state change into the stop branch, before
			-- AcquireGlow has ever built btn.glow (every button, every pass, on clients
			-- with no spell overlays at all).
			local active = util.IsSpellOverlayedByID(btn.spellID)
			if active ~= (btn.glowActive or false) then
				if active then
					AcquireGlow(btn):StartGlow()
				else
					StopGlow(btn) -- nil-safe; btn.glow exists only after the first start
				end
				btn.glowActive = active
			end
		end
	end
end

function CliqueBar:UpdateVisibility()
	local f = self.bar
	if not f then return end
	local hasEntries = self.entries and #self.entries > 0
	local vis = self.db.profile.visibility
	local show = _G.Clique ~= nil and hasEntries
	if show then
		if vis == "combat" then
			show = InCombatLockdown() or UnitAffectingCombat("player")
		elseif vis == "group" then
			show = IsInGroup()
		elseif vis == "hidden" then
			show = false
		end
	end
	-- Unlocked shows the bar in every visibility mode so it can be moved, but only
	-- when it has icons: an empty drag bar (no Clique, or no bindings) stays hidden.
	if hasEntries and not self.db.profile.locked then show = true end
	f:SetShown(show)

	-- Mouse-over mode: keep the bar present but fade it in only while hovered
	-- (always visible while unlocked so it can still be configured/moved).
	if vis == "hover" then
		f:SetScript("OnUpdate", function(frame, elapsed) self:HoverTick(frame, elapsed) end)
	else
		f:SetScript("OnUpdate", nil)
		f:SetAlpha(self.db.profile.opacity)
	end
	-- Visibility transitions (combat enter/leave, group join/leave) can turn the bar
	-- back on while a proc is live; re-query so glows resume instead of staying stale.
	self:UpdateGlows()
end

function CliqueBar:HoverTick(frame, elapsed)
	frame.hoverElapsed = (frame.hoverElapsed or 0) + elapsed
	if frame.hoverElapsed < 0.03 then return end
	frame.hoverElapsed = 0
	local target = (frame:IsMouseOver() or not self.db.profile.locked) and self.db.profile.opacity or 0
	local cur = frame:GetAlpha()
	if math.abs(cur - target) < 0.02 then
		frame:SetAlpha(target)
	elseif cur < target then
		frame:SetAlpha(cur + 0.12)
	else
		frame:SetAlpha(cur - 0.12)
	end
end

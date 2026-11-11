local ADDON, ns = ...
local L = ns.L

local MEDIA = "Interface\\AddOns\\CliqueBar\\Media\\"
local ICON_PATH = MEDIA .. "Icon.tga"

-- Rows after All Settings on the main page, in order. The 3.3.5a popup lists
-- the same links.
local LINKS = {
	{ label = "Discord", url = "https://soguns.xyz/discord", tip = L["Copy the link to our Discord."],
		color = { 0.34, 0.40, 0.95 }, icon = MEDIA .. "discord.tga" },
	{ label = "soguns.xyz", url = "https://soguns.xyz", tip = L["Copy the link to soguns.xyz."],
		color = { 0.19, 0.73, 0.71 }, icon = MEDIA .. "soguns.tga" },
}

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or ""

local frame

local function makeLinkRow(parent, y, label, url)
	local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOPLEFT", 20, y)
	heading:SetText(label)

	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(258, 20)
	box:SetPoint("TOPLEFT", 24, y - 18)
	box:SetAutoFocus(false)
	box:SetText(url)
	box:SetCursorPosition(0)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)

	box:SetScript("OnTextChanged", function(self, user)
		if user then self:SetText(url); self:HighlightText() end
	end)
end

local function build()
	frame = CreateFrame("Frame", "CliqueBarAboutFrame", UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(320, 184)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText("CliqueBar")

	local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("TOP", title, "BOTTOM", 0, -2)
	version:SetText("v" .. (ns.version or ""))

	local y = -74
	for _, link in ipairs(LINKS) do
		makeLinkRow(frame, y, link.label, link.url)
		y = y - 46
	end

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOM", 0, 16)
	hint:SetText(L["Click the box, then Ctrl-C to copy."])

	tinsert(UISpecialFrames, "CliqueBarAboutFrame")
end

function ns.ShowAbout()
	if not frame then build() end
	frame:Show()
end

-- Settings main page, in the Warchive style shared by the soguns.xyz addons:
-- icon, name, version, author and a one-line description, then one row each
-- for All Settings, the Discord and soguns.xyz, centered on the canvas. Link
-- rows show the URL in a copy box under the row (the game cannot open a
-- browser).
local ICON_SIZE = 64
local ROW_HEIGHT, ROW_WIDTH = 34, 300
-- Vertical gaps: icon > title, title > version, version > author,
-- author > description, description > rows, row > row.
local GAP_TITLE, GAP_VERSION, GAP_AUTHOR, GAP_DESC, GAP_ROWS, GAP_ROW = 10, 4, 4, 10, 16, 5
local DESC_WIDTH = 480
local GOLD = { 1, 0.82, 0 }
local GOLD_HL = { 1, 0.93, 0.4 }
local GREY = { 0.6, 0.6, 0.66 }
local WARNING_BLUE = { 0.59, 0.67, 0.9 }

local copyPopup, copyEdit
local function ShowCopyPopup(text, anchor)
	if not copyPopup then
		copyPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		copyPopup:SetSize(380, 28)
		copyPopup:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		copyPopup:SetFrameStrata("FULLSCREEN_DIALOG")
		copyPopup:Hide()
		copyEdit = CreateFrame("EditBox", nil, copyPopup, "InputBoxTemplate")
		copyEdit:SetSize(360, 18)
		copyEdit:SetPoint("CENTER")
		copyEdit:SetAutoFocus(true)
		copyEdit:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
		copyEdit:SetScript("OnEditFocusLost", function() copyPopup:Hide() end)
	end
	copyPopup:ClearAllPoints()
	copyPopup:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
	copyEdit:SetText(text or "")
	copyPopup:Show()
	copyEdit:SetFocus()
	copyEdit:HighlightText()
	copyEdit:SetCursorPosition(0)
end

-- One row: dark card, tinted gradient, icon, label, marker on the right.
local function LinkRow(parent, opts)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetSize(ROW_WIDTH, ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp")
	row:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	row:SetBackdropColor(0.08, 0.08, 0.09, 0.94)
	row:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.7)

	local tint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	tint:SetPoint("TOPLEFT", 3, -3)
	tint:SetPoint("BOTTOMRIGHT", -3, 3)
	local c, a = opts.color, opts.alpha or 0.6
	if tint.SetGradient and CreateColor then
		tint:SetColorTexture(1, 1, 1, 1)
		tint:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a * 0.35), CreateColor(c[1], c[2], c[3], a))
	else
		tint:SetColorTexture(c[1], c[2], c[3], a * 0.6)
	end

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(opts.iconSize or 18, opts.iconSize or 18)
	icon:SetPoint("LEFT", 11, 0)
	icon:SetTexture(opts.icon)
	if opts.iconTint then icon:SetVertexColor(opts.iconTint[1], opts.iconTint[2], opts.iconTint[3]) end

	local marker = row:CreateTexture(nil, "OVERLAY")
	marker:SetSize(13, 13)
	marker:SetPoint("RIGHT", -11, 0)
	marker:SetTexture(opts.marker)
	marker:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	label:SetPoint("RIGHT", marker, "LEFT", -6, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	label:SetText(opts.label)

	row:SetScript("OnEnter", function(b)
		b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
		label:SetTextColor(GOLD_HL[1], GOLD_HL[2], GOLD_HL[3])
		marker:SetVertexColor(GOLD_HL[1], GOLD_HL[2], GOLD_HL[3])
		if opts.tip then
			GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
			GameTooltip:SetText(opts.label, GOLD[1], GOLD[2], GOLD[3])
			GameTooltip:AddLine(opts.tip, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(b)
		b:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.7)
		label:SetTextColor(1, 1, 1)
		marker:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", opts.onClick)
	return row
end

-- The TOC version is stamped by the packager; a dev checkout keeps the token.
local function VersionText()
	local v = ns.version or ""
	if v == "" or v:find("@", 1, true) then return "dev" end
	return (v:gsub("^[vV]", ""))
end

-- Builds the main page once. onSettings runs when All Settings is clicked.
function ns.CreateSettingsAboutCanvas(onSettings)
	local canvas = CreateFrame("Frame", "CliqueBarSettingsAbout")
	canvas.OnCommit = function() end
	canvas.OnDefault = function() end
	canvas.OnRefresh = function() end

	local block = CreateFrame("Frame", nil, canvas)
	block:SetPoint("LEFT", canvas, "LEFT")
	block:SetPoint("RIGHT", canvas, "RIGHT")

	local icon = block:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetTexture(ICON_PATH)
	icon:SetPoint("TOP", block, "TOP")

	local title = block:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetText("CliqueBar")
	title:SetPoint("TOP", icon, "BOTTOM", 0, -GAP_TITLE)

	local version = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	version:SetText(L["Version %s"]:format(VersionText()))
	version:SetPoint("TOP", title, "BOTTOM", 0, -GAP_VERSION)

	local author = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	author:SetText(L["by %s"]:format("Sogu"))
	author:SetPoint("TOP", version, "BOTTOM", 0, -GAP_AUTHOR)

	-- Shown only while Clique is missing (the same blue warning the minimap
	-- tooltip uses). Evaluated at display time: Clique's global may not exist
	-- yet when this addon initializes.
	local warning = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	warning:SetText(L["Clique needs to be loaded for CliqueBar to work properly"])
	warning:SetTextColor(WARNING_BLUE[1], WARNING_BLUE[2], WARNING_BLUE[3])
	warning:SetPoint("TOP", author, "BOTTOM", 0, -GAP_AUTHOR)

	local desc = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	desc:SetWidth(DESC_WIDTH)
	desc:SetJustifyH("CENTER")
	desc:SetText(L["A bar that mirrors your Clique click-cast bindings with keys and cooldowns."])
	warning:Hide()

	local rows = {}
	rows[1] = LinkRow(block, {
		icon = MEDIA .. "gear.tga",
		iconSize = 16,
		iconTint = GREY,
		color = GREY,
		alpha = 0.28,
		marker = MEDIA .. "arrow-right.tga",
		label = L["All Settings"],
		tip = L["Open the CliqueBar settings."],
		onClick = function()
			if onSettings then onSettings() end
		end,
	})
	for _, link in ipairs(LINKS) do
		local row = LinkRow(block, {
			icon = link.icon,
			color = link.color,
			marker = MEDIA .. "link-external.tga",
			label = link.label,
			tip = link.tip,
			onClick = function(b) ShowCopyPopup(link.url, b) end,
		})
		row:SetPoint("TOP", rows[#rows], "BOTTOM", 0, -GAP_ROW)
		rows[#rows + 1] = row
	end

	-- Layout only: the block's height is the sum of its rows; the warning
	-- line pushes the rows down while it shows.
	local function Layout()
		local missing = _G.Clique == nil
		warning:SetShown(missing)
		local above = missing and warning or author
		desc:ClearAllPoints()
		desc:SetPoint("TOP", above, "BOTTOM", 0, -GAP_DESC)
		rows[1]:ClearAllPoints()
		rows[1]:SetPoint("TOP", desc, "BOTTOM", 0, -GAP_ROWS)
		block:SetHeight(
			ICON_SIZE
				+ GAP_TITLE
				+ (title:GetStringHeight() or 0)
				+ GAP_VERSION
				+ (version:GetStringHeight() or 0)
				+ GAP_AUTHOR
				+ (author:GetStringHeight() or 0)
				+ (missing and (GAP_AUTHOR + (warning:GetStringHeight() or 0)) or 0)
				+ GAP_DESC
				+ (desc:GetStringHeight() or 0)
				+ GAP_ROWS
				+ #rows * ROW_HEIGHT
				+ (#rows - 1) * GAP_ROW
		)
	end
	Layout()
	canvas:SetScript("OnShow", Layout)
	canvas.Layout = Layout
	canvas.rows = rows
	return canvas
end

local _, ns = ...
local L = ns.L
local CliqueBar = ns.addon

-- Native Blizzard Settings panel (retail + Mists/Vanilla Classic — all on the modern
-- engine). The main page is the About canvas (icon, version, All Settings and link rows),
-- like Class Codex; the settings themselves live in subcategories. The 3.3.5a build
-- has its own hand-built panel and does not use this file.
function CliqueBar:SetupOptions()
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

	-- Class Codex structure: the category opens on the About canvas (icon, version,
	-- Clique warning, All Settings and link rows); every setting lives on ONE "Settings"
	-- page under it, sectioned by headers. Without the canvas API it degrades to a
	-- single flat vertical category.

	-- All Settings on the main page opens the Settings subpage; out of combat
	-- only, because the open call is protected.
	local function OpenSettingsPage()
		if InCombatLockdown() or not self.settingsSubcategory then return end
		Settings.OpenToCategory(self.settingsSubcategory:GetID())
	end
	local aboutCanvas = ns.CreateSettingsAboutCanvas and Settings.RegisterCanvasLayoutCategory
		and ns.CreateSettingsAboutCanvas(OpenSettingsPage)
	local category, layout, main
	if aboutCanvas then
		main = Settings.RegisterCanvasLayoutCategory(aboutCanvas, "CliqueBar")
		category, layout = Settings.RegisterVerticalLayoutSubcategory(main, L["Settings"])
	else
		category, layout = Settings.RegisterVerticalLayoutCategory("CliqueBar")
		main = category
	end
	-- Opening the settings lands on the About page (the category's front door with
	-- the links); the Settings page is one click down the tree.
	self.settingsCategory = main
	self.settingsSubcategory = category
	local VT = Settings.VarType

	local function section(name)
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
	end

	-- Button rows are guarded: if this client's button initializer is picky, a failure
	-- here must not blank the rest of the panel.
	local function addButton(btnName, buttonText, onClick)
		pcall(function()
			layout:AddInitializer(CreateSettingsButtonInitializer(btnName, buttonText, onClick, nil, false))
		end)
	end

	local function checkbox(key, name, default, tooltip, setextra)
		local setting = Settings.RegisterProxySetting(category, "CliqueBar_" .. key, VT.Boolean, name, default,
			function() return self.db.profile[key] end,
			function(value)
				self.db.profile[key] = value
				if setextra then setextra(value) end
				self:Refresh()
			end)
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	local function slider(key, name, default, minv, maxv, step, tooltip, percent)
		local setting = Settings.RegisterProxySetting(category, "CliqueBar_" .. key, VT.Number, name, default,
			function() return self.db.profile[key] end,
			function(value) self.db.profile[key] = value; self:Refresh() end)
		local opts = Settings.CreateSliderOptions(minv, maxv, step)
		opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
			if percent then return FormatPercentage(value, true) end
			return tostring(value)
		end)
		Settings.CreateSlider(category, setting, opts, tooltip)
	end

	local function dropdown(key, name, default, entries, tooltip)
		local setting = Settings.RegisterProxySetting(category, "CliqueBar_" .. key, VT.String, name, default,
			function() return self.db.profile[key] end,
			function(value) self.db.profile[key] = value; self:Refresh() end)
		Settings.CreateDropdown(category, setting, function()
			local c = Settings.CreateControlTextContainer()
			for _, e in ipairs(entries) do c:Add(e[1], e[2]) end
			return c:GetData()
		end, tooltip)
	end

	section(L["General"])
	checkbox("locked", L["Lock bar"], false, L["Prevent the bar from being dragged."], function() self:ApplyLock() end)
	dropdown("visibility", L["Visibility"], "always", {
		{ "always", L["Always shown"] },
		{ "combat", L["Only in combat"] },
		{ "group", L["In a group (party or raid)"] },
		{ "hover", L["On mouse-over"] },
		{ "hidden", L["Hidden"] },
	})
	dropdown("whichBinds", L["Which bindings"], "macros", {
		{ "spells", L["Spell binds only"] },
		{ "macros", L["Spells & macros"] },
		{ "all", L["All binds"] },
	})
	dropdown("sort", L["Sort by"], "clique", {
		{ "clique", L["Clique order"] },
		{ "key", L["Key"] },
		{ "name", L["Spell name"] },
		{ "manual", L["Manual"] },
	}, L["Manual: unlock the bar, then drag icons to arrange them."])

	section(L["Display"])
	slider("iconSize", L["Icon size"], 36, 16, 64, 1)
	slider("perRow", L["Icons per row"], 12, 1, 24, 1)
	slider("rows", L["Rows"], 0, 0, 12, 1, L["Fixed grid height for Manual arranging; 0 grows to fit."])
	slider("spacing", L["Spacing"], 4, 0, 16, 1)
	dropdown("growth", L["Grow direction"], "RIGHT_DOWN", {
		{ "RIGHT_DOWN", L["Right, then down"] },
		{ "RIGHT_UP", L["Right, then up"] },
		{ "LEFT_DOWN", L["Left, then down"] },
		{ "LEFT_UP", L["Left, then up"] },
	})
	slider("scale", L["Scale"], 1.0, 0.5, 2.0, 0.05, nil, true)
	slider("opacity", L["Opacity"], 1.0, 0.1, 1.0, 0.05, nil, true)

	section(L["Icons"])
	checkbox("border", L["Show border"], true)
	checkbox("showCooldown", L["Show cooldown swipe"], true)
	if ns.util.spellOverlaySupported then
		checkbox("showGlow", L["Show proc highlight glow"], true,
			L["Make icons glow while their spell is highlighted on your action bars, matching the default UI."],
			function(value) self:SetGlowEventsEnabled(value) end)
	end
	if ns.Masque then
		checkbox("masque", L["Use Masque skinning"], true,
			L["Skin the icons with Masque to match your other buttons. Requires the Masque addon."],
			function() self:ApplyMasque() end)
	end

	section(L["Keys"])
	checkbox("showKeys", L["Show key labels"], true)
	checkbox("keyDash", L["Dash between modifiers"], false,
		L["Separate modifier keys with a dash (s-M2). Off matches the default UI (sM2)."])
	checkbox("tooltipKey", L["Show Clique key in tooltip"], false,
		L["Add a line to each icon's tooltip showing its Clique key."])

	section(L["Minimap"])
	local minimapSetting = Settings.RegisterProxySetting(category, "CliqueBar_minimap", VT.Boolean,
		L["Show minimap icon"], true,
		function() return not self.db.profile.minimap.hide end,
		function(value) self.db.profile.minimap.hide = not value; self:ToggleMinimap() end)
	Settings.CreateCheckbox(category, minimapSetting)

	-- Profiles: native switcher plus AceDB's own dialog for new/copy/delete.
	section(L["Profiles"])
	local profileSetting = Settings.RegisterProxySetting(category, "CliqueBar_profile", VT.String,
		L["Active profile"], "Default",
		function() return self.db:GetCurrentProfile() end,
		function(value) self.db:SetProfile(value) end)
	Settings.CreateDropdown(category, profileSetting, function()
		local c = Settings.CreateControlTextContainer()
		for _, name in ipairs(self.db:GetProfiles()) do c:Add(name, name) end
		return c:GetData()
	end)
	local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("CliqueBar-Profiles", profileOptions)
	addButton(L["Manage profiles"], L["Open"], function() LibStub("AceConfigDialog-3.0"):Open("CliqueBar-Profiles") end)

	Settings.RegisterAddOnCategory(main)
end

function CliqueBar:OpenOptions()
	if self.settingsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.settingsCategory:GetID())
	end
end

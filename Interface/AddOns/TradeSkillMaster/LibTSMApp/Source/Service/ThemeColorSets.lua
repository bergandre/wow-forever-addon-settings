-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ThemeColorSets = LibTSMApp:Init("Service.ThemeColorSets")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local EnumType = LibTSMApp:From("LibTSMUtil"):Include("BaseType.EnumType")
local ColorRamp = LibTSMApp:From("LibTSMUtil"):IncludeClassType("ColorRamp")
local Encoder = LibTSMApp:From("LibTSMUtil"):IncludeClassType("Encoder")
local Reactive = LibTSMApp:From("LibTSMReactive"):Include("Reactive")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local private = {
	settings = nil,
	encoder = nil,
	colorSets = {},
	themeRamps = {},
	customRamps = {},
	rampsChangedStream = nil,
}
local ThemeBrandRampKey = EnumType.New("ThemeBrandRampKey", {
	NEUTRAL = EnumType.NewValue(),
	PRIMARY = EnumType.NewValue(),
	SECONDARY = EnumType.NewValue(),
})
ThemeColorSets.ThemeBrandRampKey = ThemeBrandRampKey
local ThemeSharedRampKey = EnumType.New("ThemeSharedRampKey", {
	ACCENT = EnumType.NewValue(),
	ERROR = EnumType.NewValue(),
	POSITIVE = EnumType.NewValue(),
	WARNING = EnumType.NewValue(),
	SCRIM = EnumType.NewValue(),
})
local MAGIC_STR = "TSM_THEME_EXPORT"
local VERSION = 3
local CUSTOM_THEME_KEY = "custom"
local TOKEN_RAMP_STEP_MAP = { ---@type table<string,{ramp: ThemeBrandRampKey|ThemeSharedRampKey, step: number, opacity?: number}>
	["surface/main"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 18 },
	["surface/variant"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 35 },
	["container/lowest"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 16 },
	["container/low"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 22 },
	["container/medium"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 25 },
	["container/high"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 30 },
	["container/highest"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 33 },
	["outline/main"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 70 },
	["outline/variant"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 40 },
	["on/surface"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 96 },
	["on/surface/low"] = { ramp = ThemeBrandRampKey.NEUTRAL, step = 80 },
	["primary/main"] = { ramp = ThemeBrandRampKey.PRIMARY, step = 80 },
	["primary/variant"] = { ramp = ThemeBrandRampKey.PRIMARY, step = 40 },
	["on/primary"] = { ramp = ThemeBrandRampKey.PRIMARY, step = 35 },
	["on/primary/variant"] = { ramp = ThemeBrandRampKey.PRIMARY, step = 98 },
	["secondary/main"] = { ramp = ThemeBrandRampKey.SECONDARY, step = 60 },
	["secondary/variant"] = { ramp = ThemeBrandRampKey.SECONDARY, step = 22 },
	["on/secondary"] = { ramp = ThemeBrandRampKey.SECONDARY, step = 20 },
	["on/secondary/variant"] = { ramp = ThemeBrandRampKey.SECONDARY, step = 96 },
	["accent/main"] = { ramp = ThemeSharedRampKey.ACCENT, step = 80 },
	["accent/variant"] = { ramp = ThemeSharedRampKey.ACCENT, step = 40 },
	["on/accent"] = { ramp = ThemeSharedRampKey.ACCENT, step = 35 },
	["on/accent/variant"] = { ramp = ThemeSharedRampKey.ACCENT, step = 98 },
	["error/main"] = { ramp = ThemeSharedRampKey.ERROR, step = 65 },
	["error/variant"] = { ramp = ThemeSharedRampKey.ERROR, step = 43 },
	["on/error"] = { ramp = ThemeSharedRampKey.ERROR, step = 0 },
	["on/error/variant"] = { ramp = ThemeSharedRampKey.ERROR, step = 100 },
	["positive/main"] = { ramp = ThemeSharedRampKey.POSITIVE, step = 76 },
	["positive/variant"] = { ramp = ThemeSharedRampKey.POSITIVE, step = 49 },
	["on/positive"] = { ramp = ThemeSharedRampKey.POSITIVE, step = 0 },
	["on/positive/variant"] = { ramp = ThemeSharedRampKey.POSITIVE, step = 100 },
	["warning/main"] = { ramp = ThemeSharedRampKey.WARNING, step = 77 },
	["warning/variant"] = { ramp = ThemeSharedRampKey.WARNING, step = 50 },
	["on/warning"] = { ramp = ThemeSharedRampKey.WARNING, step = 0 },
	["on/warning/variant"] = { ramp = ThemeSharedRampKey.WARNING, step = 100 },
	["scrim/main"] = { ramp = ThemeSharedRampKey.SCRIM, step = 0, opacity = 80 },
}
local SHARED_RAMPS = { ---@type table<ThemeSharedRampKey,ColorRamp>
	[ThemeSharedRampKey.ACCENT] = ColorRamp.New(94.2, 0.168),
	[ThemeSharedRampKey.ERROR] = ColorRamp.New(28.7, 0.232),
	[ThemeSharedRampKey.POSITIVE] = ColorRamp.New(151.5, 0.201),
	[ThemeSharedRampKey.WARNING] = ColorRamp.New(62.6, 0.175),
	[ThemeSharedRampKey.SCRIM] = ColorRamp.New(0, 0),
}
local TOKEN_CLASS_RAMP = { ---@type table<ThemeColorTokenClass,ThemeBrandRampKey>
	surface = ThemeBrandRampKey.NEUTRAL,
	primary = ThemeBrandRampKey.PRIMARY,
	secondary = ThemeBrandRampKey.SECONDARY,
}
local THEME_COLOR_SETS = { ---@type ThemeColorSet[]
	{
		key = "default",
		name = L["Default"],
		ramps = {
			[ThemeBrandRampKey.NEUTRAL] = ColorRamp.New(196.9, 0.008),
			[ThemeBrandRampKey.PRIMARY] = ColorRamp.New(197.0, 0.007),
			[ThemeBrandRampKey.SECONDARY] = ColorRamp.New(253.0, 0.022),
		},
	},
	{
		key = "dalaran",
		name = L["Dalaran"],
		ramps = {
			[ThemeBrandRampKey.NEUTRAL] = ColorRamp.New(286.9, 0.063),
			[ThemeBrandRampKey.PRIMARY] = ColorRamp.New(286.9, 0.063),
			[ThemeBrandRampKey.SECONDARY] = ColorRamp.New(286.9, 0.063),
		},
	},
	{
		key = "swampOfSorrows",
		name = L["Swamp of Sorrows"],
		ramps = {
			[ThemeBrandRampKey.NEUTRAL] = ColorRamp.New(169.7, 0.029),
			[ThemeBrandRampKey.PRIMARY] = ColorRamp.New(169.7, 0.029),
			[ThemeBrandRampKey.SECONDARY] = ColorRamp.New(169.7, 0.029),
		},
	},
	{
		key = "orgrimmar",
		name = L["Orgrimmar"],
		ramps = {
			[ThemeBrandRampKey.NEUTRAL] = ColorRamp.New(32.8, 0.081),
			[ThemeBrandRampKey.PRIMARY] = ColorRamp.New(32.8, 0.081),
			[ThemeBrandRampKey.SECONDARY] = ColorRamp.New(32.8, 0.081),
		},
	},
	{
		key = "stormwind",
		name = L["Stormwind"],
		ramps = {
			[ThemeBrandRampKey.NEUTRAL] = ColorRamp.New(219.1, 0.017),
			[ThemeBrandRampKey.PRIMARY] = ColorRamp.New(219.1, 0.017),
			[ThemeBrandRampKey.SECONDARY] = ColorRamp.New(219.1, 0.017),
		},
	},
}

---@class ThemeColorSet
---@field key string
---@field name string
---@field ramps table<ThemeBrandRampKey,ColorRamp>
---@alias ThemeColorTokenClass "surface"|"primary"|"secondary"



-- ============================================================================
-- Module Loading
-- ============================================================================

ThemeColorSets:OnModuleLoad(function()
	private.encoder = Encoder.Create()
		:SetEncodingType("PRINT")
		:SetSerializationType("STABLE")
	private.rampsChangedStream = Reactive.GetStream(function() return true end)
end)

AddonSettings.RegisterOnLoad(ThemeColorSets, function(db)
	private.settings = db:NewView("ThemeColorSetsSettings")
		:AddKey("global", "appearanceOptions", "activeThemeKey")
		:AddKey("global", "appearanceOptions", "customThemeRamps")
		:Commit()

	-- Register built-in themes
	local foundCurrentColorSet = false
	local defaultThemeRamps = nil
	for _, info in ipairs(THEME_COLOR_SETS) do
		private.colorSets[info.key] = private.CreateColorSet(info.ramps)
		private.themeRamps[info.key] = info.ramps
		Theme.RegisterColorSet(info.key, info.name, private.colorSets[info.key])
		foundCurrentColorSet = foundCurrentColorSet or info.key == private.settings.activeThemeKey
		if info.key == private.settings:GetDefaultReadOnly("activeThemeKey") then
			defaultThemeRamps = info.ramps
		end
	end
	assert(defaultThemeRamps)

	-- Register the custom theme
	local isCustomActive = private.settings.activeThemeKey == CUSTOM_THEME_KEY
	if not isCustomActive then
		wipe(private.settings.customThemeRamps)
	end
	for tokenClass, rampKey in pairs(TOKEN_CLASS_RAMP) do
		if isCustomActive then
			if not private.IsCustomThemeRampValid(tokenClass) then
				-- Reset to the default theme's ramp
				private.settings.customThemeRamps[tokenClass] = {defaultThemeRamps[rampKey]:GetHueChroma()}
			end
			private.customRamps[rampKey] = ColorRamp.New(unpack(private.settings.customThemeRamps[tokenClass]))
		else
			private.customRamps[rampKey] = ColorRamp.New(defaultThemeRamps[rampKey]:GetHueChroma())
		end
	end
	Theme.RegisterColorSet(CUSTOM_THEME_KEY, L["Custom"], private.CreateColorSet(private.customRamps))
	foundCurrentColorSet = foundCurrentColorSet or isCustomActive

	if not foundCurrentColorSet then
		private.settings:ResetToDefault("activeThemeKey")
	end
	private.SetActiveTheme(private.settings.activeThemeKey)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over the color sets.
---@return fun(): number, string, string, boolean @Iterator with fields: `index`, `key`, `name`
---@return table
---@return number
function ThemeColorSets.Iterator()
	return private.ColorSetIterator, THEME_COLOR_SETS, 0
end

---Sets the active color set.
---@param key string The color set key
function ThemeColorSets.SetActive(key)
	if private.settings.activeThemeKey == key then
		return
	end
	private.SetActiveTheme(key)
end

---Gets the hue and chroma of a custom theme ramp.
---@param tokenClass ThemeColorTokenClass The token class
---@return number hue
---@return number chroma
function ThemeColorSets.GetCustomRamp(tokenClass)
	return private.customRamps[TOKEN_CLASS_RAMP[tokenClass]]:GetHueChroma()
end

---Sets the hue and chroma of a custom theme ramp.
---@param tokenClass ThemeColorTokenClass The token class
---@param hue number The hue in degrees from 0 to 360
---@param chroma number The chroma in OKLab units
function ThemeColorSets.SetCustomRamp(tokenClass, hue, chroma)
	ThemeColorSets.SetActive(CUSTOM_THEME_KEY)
	private.SetCustomRampHelper(tokenClass, hue, chroma)
end

---Gets a publisher which fires whenever any custom theme ramp changes.
---@return ReactivePublisherSchema
function ThemeColorSets.GetRampsChangedPublisher()
	return private.rampsChangedStream:Publisher()
end

---Gets the custom color set key.
---@return string
function ThemeColorSets.GetCustomColorSetKey()
	return CUSTOM_THEME_KEY
end

---Gets the main step for a given token class.
---@param tokenClass ThemeColorTokenClass The token class
---@return number
function ThemeColorSets.GetMainTokenStep(tokenClass)
	return TOKEN_RAMP_STEP_MAP[tokenClass.."/main"].step
end

---Gets the on step for a given token class.
---@param tokenClass ThemeColorTokenClass The token class
---@return number
function ThemeColorSets.GetOnTokenStep(tokenClass)
	return TOKEN_RAMP_STEP_MAP["on/"..tokenClass].step
end

---Exports the current custom color set.
---@return string
function ThemeColorSets.ExportCustom()
	return private.encoder:Serialize(MAGIC_STR, VERSION, private.settings.customThemeRamps)
end

---Imports a custom color set and returns whether or not it was successful.
---@param str string
---@return boolean
function ThemeColorSets.ImportCustom(str)
	-- Deserialize and validate the data
	local success, magicStr, version, themeRamps = private.encoder:Deserialize(str)
	if not success or magicStr ~= MAGIC_STR or version ~= VERSION or type(themeRamps) ~= "table" then
		return false
	end
	local count = 0
	for tokenClass, ramp in pairs(themeRamps) do
		count = count + 1
		if not TOKEN_CLASS_RAMP[tokenClass] or not private.IsRampValueValid(ramp) then
			return false
		end
	end
	if count ~= Table.Count(TOKEN_CLASS_RAMP) then
		return false
	end

	-- Apply the ramps
	ThemeColorSets.SetActive(CUSTOM_THEME_KEY)
	for tokenClass, ramp in pairs(themeRamps) do
		private.SetCustomRampHelper(tokenClass, unpack(ramp))
	end
	return true
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsRampValueValid(ramp)
	if type(ramp) ~= "table" or #ramp ~= 2 then
		return false
	end
	local hue, chroma = unpack(ramp)
	if type(hue) ~= "number" or type(chroma) ~= "number" then
		return false
	elseif hue < 0 or hue > 360 then
		return false
	elseif chroma < 0 or chroma > 0.4 then
		return false
	end
	return true
end

function private.IsCustomThemeRampValid(tokenClass)
	return private.IsRampValueValid(private.settings.customThemeRamps[tokenClass])
end

---@return table<string,Color>
function private.CreateColorSet(brandRamps)
	local colorSet = {} ---@type table<string,Color>
	for token, spec in pairs(TOKEN_RAMP_STEP_MAP) do
		local ramp = nil
		if SHARED_RAMPS[spec.ramp] then
			assert(not brandRamps[spec.ramp])
			ramp = SHARED_RAMPS[spec.ramp]
		else
			ramp = brandRamps[spec.ramp]
		end
		assert(ramp)
		local color = ramp:GetColor(spec.step)
		colorSet[token] = spec.opacity and color:GetOpacity(spec.opacity) or color
	end
	return colorSet
end

function private.SetActiveTheme(key)
	if key ~= CUSTOM_THEME_KEY then
		-- Mirror the selected theme's ramps into the custom color set
		for tokenClass, rampKey in pairs(TOKEN_CLASS_RAMP) do
			private.SetCustomRampHelper(tokenClass, private.themeRamps[key][rampKey]:GetHueChroma())
		end
	end
	private.settings.activeThemeKey = key
	Theme.SetActiveColorSet(key)
end

function private.SetCustomRampHelper(tokenClass, hue, chroma)
	local rampKey = TOKEN_CLASS_RAMP[tokenClass]
	private.customRamps[rampKey]:SetHueChroma(hue, chroma)
	private.settings.customThemeRamps[tokenClass] = {hue, chroma}
	for token, spec in pairs(TOKEN_RAMP_STEP_MAP) do
		if spec.ramp == rampKey then
			local r, g, b = private.customRamps[rampKey]:GetRGBA(spec.step)
			Theme.UpdateColor(CUSTOM_THEME_KEY, token, r, g, b)
		end
	end
	private.rampsChangedStream:Send(true)
end

function private.ColorSetIterator(tbl, index)
	index = index + 1
	local key, name = nil, nil
	if index == #tbl + 1 then
		key = CUSTOM_THEME_KEY
		name = L["Custom"]
	elseif not tbl[index] then
		return
	else
		key = tbl[index].key
		name = tbl[index].name
	end
	return index, key, name
end

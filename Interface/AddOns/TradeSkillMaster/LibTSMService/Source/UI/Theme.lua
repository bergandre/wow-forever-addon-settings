-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Theme = LibTSMService:Init("UI.Theme")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Color = LibTSMService:From("LibTSMUtil"):IncludeClassType("Color")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = LibTSMService:From("LibTSMReactive"):Include("Reactive")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local FontObject = LibTSMService:From("LibTSMWoW"):IncludeClassType("FontObject")
local private = {
	callbacks = CallbackRegistry.NewList(),
	names = {},
	colorSets = {},
	currentColorSetKey = nil,
	currentFontSet = nil,
	streams = {}, ---@type table<string,ReactiveStream>
	streamInitialValueFunc = {},
}
---@alias ThemeColorKey
---|'"GROUP_ONE"'
---|'"GROUP_TWO"'
---|'"GROUP_THREE"'
---|'"GROUP_FOUR"'
---|'"GROUP_FIVE"'
---|'"FULL_WHITE"'
---|'"TRANSPARENT"'
---|'"BLIZZARD_YELLOW"'
---|'"BLIZZARD_GM"'
---|'"surface/main"'
---|'"surface/variant"'
---|'"container/lowest"'
---|'"container/low"'
---|'"container/medium"'
---|'"container/high"'
---|'"container/highest"'
---|'"outline/main"'
---|'"outline/variant"'
---|'"on/accent"'
---|'"on/accent/variant"'
---|'"on/error"'
---|'"on/error/variant"'
---|'"on/primary"'
---|'"on/primary/variant"'
---|'"on/secondary"'
---|'"on/secondary/variant"'
---|'"on/surface"'
---|'"on/surface/low"'
---|'"on/positive"'
---|'"on/positive/variant"'
---|'"on/warning"'
---|'"on/warning/variant"'
---|'"primary/main"'
---|'"primary/variant"'
---|'"secondary/main"'
---|'"secondary/variant"'
---|'"accent/main"'
---|'"accent/variant"'
---|'"error/main"'
---|'"error/variant"'
---|'"positive/main"'
---|'"positive/variant"'
---|'"warning/main"'
---|'"warning/variant"'
---|'"scrim/main"'
local THEME_COLOR_KEYS = {
	["surface/main"] = true,
	["surface/variant"] = true,
	["container/lowest"] = true,
	["container/low"] = true,
	["container/medium"] = true,
	["container/high"] = true,
	["container/highest"] = true,
	["outline/main"] = true,
	["outline/variant"] = true,
	["on/accent"] = true,
	["on/accent/variant"] = true,
	["on/error"] = true,
	["on/error/variant"] = true,
	["on/primary"] = true,
	["on/primary/variant"] = true,
	["on/secondary"] = true,
	["on/secondary/variant"] = true,
	["on/surface"] = true,
	["on/surface/low"] = true,
	["on/positive"] = true,
	["on/positive/variant"] = true,
	["on/warning"] = true,
	["on/warning/variant"] = true,
	["primary/main"] = true,
	["primary/variant"] = true,
	["secondary/main"] = true,
	["secondary/variant"] = true,
	["accent/main"] = true,
	["accent/variant"] = true,
	["error/main"] = true,
	["error/variant"] = true,
	["positive/main"] = true,
	["positive/variant"] = true,
	["warning/main"] = true,
	["warning/variant"] = true,
	["scrim/main"] = true,
}
local STATIC_COLORS = {
	GROUP_ONE = Color.NewFromHex("#fcf141"),
	GROUP_TWO = Color.NewFromHex("#bdaec6"),
	GROUP_THREE = Color.NewFromHex("#06a2cb"),
	GROUP_FOUR = Color.NewFromHex("#ffb85c"),
	GROUP_FIVE = Color.NewFromHex("#51b599"),

	FULL_WHITE = Color.NewFromHex("#ffffff"),
	TRANSPARENT = Color.NewFromHex("#00000000"),

	BLIZZARD_YELLOW = Color.NewFromHex("#ffff00"),
	BLIZZARD_GM = Color.NewFromHex("#00b4ff"),

	CRAFTED_QUALITY_ONE_MIDNIGHT = Color.NewFromHex("#7d7e85"),
	CRAFTED_QUALITY_TWO_MIDNIGHT = Color.NewFromHex("#e2b932"),

	CRAFTED_QUALITY_ONE = Color.NewFromHex("#904a3c"),
	CRAFTED_QUALITY_TWO = Color.NewFromHex("#7d7e85"),
	CRAFTED_QUALITY_THREE = Color.NewFromHex("#8f782e"),
	CRAFTED_QUALITY_FOUR = Color.NewFromHex("#4b9694"),
	CRAFTED_QUALITY_FIVE = Color.NewFromHex("#e2b932"),
}
local GROUP_COLOR_KEYS = {
	"GROUP_ONE",
	"GROUP_TWO",
	"GROUP_THREE",
	"GROUP_FOUR",
	"GROUP_FIVE",
}
local CRAFTED_QUALITY_KEYS_MIDNIGHT = {
	"CRAFTED_QUALITY_ONE_MIDNIGHT",
	"CRAFTED_QUALITY_TWO_MIDNIGHT",
}
local CRAFTED_QUALITY_KEYS = {
	"CRAFTED_QUALITY_ONE",
	"CRAFTED_QUALITY_TWO",
	"CRAFTED_QUALITY_THREE",
	"CRAFTED_QUALITY_FOUR",
	"CRAFTED_QUALITY_FIVE",
}
local PROFESSION_DIFFICULTY_COLORS = {
	[TradeSkill.RECIPE_DIFFICULTY.OPTIMAL] = Color.NewFromHex("#ff8040"),
	[TradeSkill.RECIPE_DIFFICULTY.MEDIUM] = Color.NewFromHex("#ffff00"),
	[TradeSkill.RECIPE_DIFFICULTY.EASY] = Color.NewFromHex("#40c040"),
	[TradeSkill.RECIPE_DIFFICULTY.TRIVIAL] = Color.NewFromHex("#9d9d9d"),
	header = Color.NewFromHex("#ffd100"),
	subheader = Color.NewFromHex("#ffd100"),
	nodifficulty = Color.NewFromHex("#f5f5f5"),
}
-- NOTE: there is a global ITEM_QUALITY_COLORS so we need to use another name
local TSM_ITEM_QUALITY_COLORS = {
	[0] = Color.NewFromHex("#9d9d9d"),
	[1] = Color.NewFromHex("#ffffff"),
	[2] = Color.NewFromHex("#1eff00"),
	[3] = Color.NewFromHex("#0070dd"),
	[4] = Color.NewFromHex("#a334ee"),
	[5] = Color.NewFromHex("#ff8000"),
	[6] = Color.NewFromHex("#e6cc80"),
	[7] = Color.NewFromHex("#00ccff"),
	[8] = Color.NewFromHex("#00ccff"),
}
local AUCTION_PCT_COLORS = {
	{ -- blue
		color = Color.NewFromHex("#2076f7"),
		value = 50,
	},
	{ -- green
		color = Color.NewFromHex("#4ff720"),
		value = 80,
	},
	{ -- yellow
		color = Color.NewFromHex("#e1f720"),
		value = 110,
	},
	{ -- orange
		color = Color.NewFromHex("#f77a20"),
		value = 135,
	},
	{ -- red
		color = Color.NewFromHex("#f72d20"),
		value = math.huge,
	},
	default = "on/surface",
	bid = "on/surface/low",
}
local OPACITY_VALUES = {
	HIGHLIGHT = 50,
}
local TINT_VALUES = {
	SELECTED = 5,
	HOVER = 5,
	SELECTED_HOVER = 8,
	DISABLED = -40,
}
local CONSTANTS = {
	COL_SPACING = 8,
	SCROLLBAR_MARGIN = 4,
	SCROLLBAR_WIDTH = 4,
	MOUSE_WHEEL_SCROLL_AMOUNT = 60,
}
local OVERRIDE_FONT_PATHS = {
	[FontObject.ALPHABET.ROMAN] = {
		[FontObject.TYPE.BODY_REGULAR] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Regular.ttf",
		[FontObject.TYPE.BODY_MEDIUM] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Medium.ttf",
		[FontObject.TYPE.BODY_SEMIBOLD] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-SemiBold.ttf",
		[FontObject.TYPE.BODY_EXTRABOLD] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-ExtraBold.ttf",
		[FontObject.TYPE.TABLE] = "Interface\\Addons\\TradeSkillMaster\\Media\\Roboto-Medium.ttf",
	},
	[FontObject.ALPHABET.CYRILLIC] = {
		[FontObject.TYPE.BODY_REGULAR] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Regular.ttf",
		[FontObject.TYPE.BODY_MEDIUM] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Medium.ttf",
		[FontObject.TYPE.BODY_SEMIBOLD] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-SemiBold.ttf",
		[FontObject.TYPE.BODY_EXTRABOLD] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-ExtraBold.ttf",
		[FontObject.TYPE.TABLE] = "Interface\\Addons\\TradeSkillMaster\\Media\\Roboto-Medium.ttf",
	},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Theme:OnModuleLoad(function()
	Table.SetReadOnly(STATIC_COLORS)
	Table.SetReadOnly(GROUP_COLOR_KEYS)
	Table.SetReadOnly(PROFESSION_DIFFICULTY_COLORS)
	Table.SetReadOnly(TSM_ITEM_QUALITY_COLORS)
	Table.SetReadOnly(CONSTANTS)

	-- Load fonts
	-- TODO: eventually allow for different font sets?
	FontObject.LoadPaths(OVERRIDE_FONT_PATHS)
	private.currentFontSet = {
		BODY_BODY1 = FontObject.New(FontObject.TYPE.BODY_REGULAR, 16, 24),
		BODY_BODY1_MEDIUM = FontObject.New(FontObject.TYPE.BODY_MEDIUM, 16, 24),
		BODY_BODY1_EXTRABOLD = FontObject.New(FontObject.TYPE.BODY_EXTRABOLD, 16, 24),
		BODY_SMALL = FontObject.New(FontObject.TYPE.BODY_REGULAR, 13, 20),
		BODY_SMALL_MEDIUM = FontObject.New(FontObject.TYPE.BODY_MEDIUM, 13, 20),
		BODY_SMALL_SEMIBOLD = FontObject.New(FontObject.TYPE.BODY_SEMIBOLD, 13, 20),
		BODY_BODY3_MEDIUM = FontObject.New(FontObject.TYPE.BODY_MEDIUM, 12, 20),
		BODY_XSMALL = FontObject.New(FontObject.TYPE.BODY_REGULAR, 11, 16),
		ITEM_BODY1 = FontObject.New(FontObject.TYPE.ITEM, 16, 24),
		ITEM_BODY2 = FontObject.New(FontObject.TYPE.ITEM, 14, 20),
		ITEM_XSMALL = FontObject.New(FontObject.TYPE.ITEM, 11, 16),
		TABLE_TABLE1_OUTLINE = FontObject.New(FontObject.TYPE.TABLE, 12, 20, "OUTLINE"),
		TABLE_XSMALL = FontObject.New(FontObject.TYPE.TABLE, 11, 16),
	}
end)


-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback when the theme changes.
---@param callback function The callback function
function Theme.RegisterChangeCallback(callback)
	private.callbacks:Add(callback)
end

---Registers a new color set.
---@param key string The key which represents the color set
---@param name string The name of the color set
---@param colorSet table The colors which make up the color set (with keys specified in `THEME_COLOR_KEYS`)
function Theme.RegisterColorSet(key, name, colorSet)
	assert(not private.colorSets[key] and type(key) == "string" and strmatch(key, "^[a-zA-Z]+$"))
	for k in pairs(THEME_COLOR_KEYS) do
		assert(Color.IsColorValue(colorSet[k]))
	end
	private.names[key] = name
	private.colorSets[key] = colorSet
end

---Gets a theme color publisher which publishes deduplicated color values.
---@param key string The theme color key
---@return ReactivePublisherSchema
function Theme.GetPublisher(key)
	assert(Theme.IsValidColor(key))
	if not private.streams[key] then
		if not private.streamInitialValueFunc[key] then
			private.streamInitialValueFunc[key] = function()
				return Theme.GetColor(key)
			end
		end
		private.streams[key] = Reactive.GetStream(private.streamInitialValueFunc[key])
			:SetNoPublishersCallback(private.HandleNoStreamPublishers)
	end
	return private.streams[key]:Publisher()
		:IgnoreDuplicates("GetHex()")
end

---Sets the active color set.
---@param colorSetKey string The key which represents the color set
function Theme.SetActiveColorSet(colorSetKey)
	assert(private.colorSets[colorSetKey])
	if private.currentColorSetKey == colorSetKey then
		return
	end
	private.currentColorSetKey = colorSetKey
	private.HandleColorChange(colorSetKey, nil)
	private.callbacks:CallAll()
end

---Replaces a specific color within a theme (for user-generated themes)
---@param colorSetKey string The key of the color set to change
---@param colorKey string The key of the color to change
---@param r number The new red value (0-255)
---@param g number The new green value (0-255)
---@param b number The new blue value (0-255)
function Theme.UpdateColor(colorSetKey, colorKey, r, g, b)
	local colorSet = private.colorSets[colorSetKey]
	assert(THEME_COLOR_KEYS[colorKey] and colorSet)
	local color = colorSet[colorKey]
	assert(color)
	color:SetRGBA(r, g, b, 255)
	private.HandleColorChange(colorSetKey, colorKey)
	if colorSetKey == private.currentColorSetKey then
		private.callbacks:CallAll()
	end
end

---Returns whether or not a theme color key is valid.
---@param key string The theme color key
---@return boolean
function Theme.IsValidColor(key)
	local colorKey, _, _, colorSetKey = private.GetColorKeyInfo(key)
	if not colorKey then
		return false
	end
	local color = nil
	if THEME_COLOR_KEYS[colorKey] then
		colorSetKey = colorSetKey or private.currentColorSetKey
		assert(colorSetKey)
		color = private.colorSets[colorSetKey][colorKey]
	else
		if colorSetKey then
			return false
		end
		color = STATIC_COLORS[colorKey]
	end
	return color and true or false
end

---Gets the color object from the current active color set.
---@param key ThemeColorKey|string The key of the color to get
---@return Color
function Theme.GetColor(key)
	local colorKey, tintPct, opacityPct, colorSetKey = private.GetColorKeyInfo(key)
	assert(colorKey)
	local color = nil
	if THEME_COLOR_KEYS[colorKey] then
		colorSetKey = colorSetKey or private.currentColorSetKey
		color = private.colorSets[colorSetKey][colorKey]
	else
		assert(not colorSetKey)
		color = STATIC_COLORS[colorKey]
	end
	assert(color)
	if tintPct then
		color = color:GetTint(tintPct)
	end
	if opacityPct then
		color = color:GetOpacity(opacityPct)
	end
	return color
end

---Gets the theme color key for a given group level.
---@param level number The level of the group (1-based)
---@return ThemeColorKey
function Theme.GetGroupColorKey(level)
	level = ((level - 1) % #GROUP_COLOR_KEYS) + 1
	return GROUP_COLOR_KEYS[level]
end

---Gets the color object for a given group level.
---@param level number The level of the group (1-based)
---@return Color
function Theme.GetGroupColor(level)
	return STATIC_COLORS[Theme.GetGroupColorKey(level)]
end

---Gets the color for a profession.
---@param difficulty EnumValue|"header"|"subheader"|"nodifficulty"
---@return Color
function Theme.GetProfessionDifficultyColor(difficulty)
	return PROFESSION_DIFFICULTY_COLORS[difficulty]
end

---Gets the color for an item quality.
---@param quality number
---@return Color
function Theme.GetItemQualityColor(quality)
	return TSM_ITEM_QUALITY_COLORS[quality]
end

---Gets the color for an auction percentage.
---@param pct number|"BID"
---@return Color
function Theme.GetAuctionPercentColor(pct)
	if pct == "BID" then
		return Theme.GetColor(AUCTION_PCT_COLORS.bid)
	end
	for _, info in ipairs(AUCTION_PCT_COLORS) do
		if pct < info.value then
			return info.color
		end
	end
	return Theme.GetColor(AUCTION_PCT_COLORS.default)
end

---Gets the color key for a crafted quality.
---@param quality number The crafted quality
---@param useMidnightIcon boolean The quality icon to use
---@return string
function Theme.GetCraftedQualityColorKey(quality, useMidnightIcon)
	local key = useMidnightIcon and CRAFTED_QUALITY_KEYS_MIDNIGHT[quality] or CRAFTED_QUALITY_KEYS[quality]
	---@cast key string?
	assert(key and Theme.IsValidColor(key))
	return key
end

---Gets the font object from the current active font set.
---@param key string The key of the font to get
function Theme.IsValidFont(key)
	return private.currentFontSet[key] and true or false
end

---Gets the font object from the current active font set.
---@param key string The key of the font to get
---@return FontObject
function Theme.GetFont(key)
	assert(Theme.IsValidFont(key))
	return private.currentFontSet[key]
end

---Gets the column spacing constant value.
---@return number
function Theme.GetColSpacing()
	return CONSTANTS.COL_SPACING
end

---Gets the scrollbar margin constant value.
---@return number
function Theme.GetScrollbarMargin()
	return CONSTANTS.SCROLLBAR_MARGIN
end

---Gets the scrollbar width constant value.
---@return number
function Theme.GetScrollbarWidth()
	return CONSTANTS.SCROLLBAR_WIDTH
end

---Gets the mouse scroll amount value.
---@return number
function Theme.GetMouseWheelScrollAmount()
	return CONSTANTS.MOUSE_WHEEL_SCROLL_AMOUNT
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetColorKeyInfo(key)
	local colorKey, tintPct, opacityPct, colorSetKey = strmatch(key, "^([A-Z_a-z/]+)([%-%+]?[0-9A-Z_]*)%%?([0-9A-Z_]*):?([a-zA-Z]*)$")
	tintPct = tonumber(tintPct) or (tintPct ~= "" and tintPct or nil)
	if type(tintPct) == "string" then
		local sign, tintKey = strmatch(tintPct, "^([%+%-])([A-Z_]+)$")
		assert(sign)
		local value = TINT_VALUES[tintKey]
		if not value then
			error("Invalid tint: "..tintPct)
		end
		tintPct = tonumber(TINT_VALUES[tintKey])
		assert(tintPct)
		tintPct = tintPct * (sign == "+" and 1 or -1)
	end
	opacityPct = tonumber(opacityPct) or (opacityPct ~= "" and opacityPct or nil)
	if type(opacityPct) == "string" then
		local value = OPACITY_VALUES[opacityPct]
		if not value then
			error("Invalid opacity: "..tostring(opacityPct))
		end
		opacityPct = value
	end
	colorSetKey = colorSetKey ~= "" and colorSetKey or nil
	return colorKey, tintPct, opacityPct, colorSetKey
end

function private.HandleColorChange(changedColorSetKey, changedColorKey)
	for key, stream in pairs(private.streams) do
		local colorKey, _, _, colorSetKey = private.GetColorKeyInfo(key)
		colorSetKey = colorSetKey or private.currentColorSetKey
		if colorSetKey == changedColorSetKey and (not changedColorKey or colorKey == changedColorKey) then
			stream:Send(Theme.GetColor(key))
		end
	end
end

function private.HandleNoStreamPublishers(stream)
	local key = Table.KeyByValue(private.streams, stream)
	assert(key)
	private.streams[key]:Release()
	private.streams[key] = nil
end

--[===[ File
This file contains the global variables and constants used throughout Titan Panel.

Titan_G is intended to reduce the global namespace through out Titan over time.
All variables in Titan_G should be declared here even if set elsewhere.
--]===]

---@meta
local L = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID, true)

-- Global variables

-- Declare the major sections within Titan_G here although they may be set elsewhere.
Titan_G = {}      -- the journey to a smaller _G footprint
Titan_G.constants = {} -- reserved for constants used across Titan
Titan_G.players = {} -- reserved for player info across Titan
Titan_G.switch = {} -- reserved for flags needed because feature / function changed over WoW versions
-- As much as possible, use something in the API to determine feature, not API version.
-- Set defaults to retail feature / function
Titan_G.plugins = {} -- reserved for plugin info across Titan
Titan_G.control = {} -- reserved for control frame, events, etc of Titan
Titan_G.bars = {} -- reserved for constants and info across Titan bar frames
Titan_G.vars = {} -- reserved for variables and saved variables used across Titan
Titan_G.utils = {} -- reserved for utility routines used across Titan
Titan_G.ldb = {} -- reserved for LDB routines used across Titan
Titan_G.menu = {} -- reserved for old DropDownMenu routines used across Titan
Titan_G.tooltip = {} -- reserved for tooltip routines across Titan

Titan_Menu = {}        -- Hold API routines for new menu scheme
Titan_G.config = {}      -- Hold API routines for config

Titan_G.recent_changes = "" -- Titan_History.lua

Titan_G.wowversion  = select(4, GetBuildInfo())


Titan_G.switch.game_ammo  = false -- if bows and guns use actual ammo
if Titan_G.wowversion < 40000 then -- before Cata
	Titan_G.switch.game_ammo  = true
else
	Titan_G.switch.game_ammo  = false
end

Titan_G.constants.DEBUG_ARRAY_MAX = 100
Titan_G.plugins.NonMovable_Plugins = {}
TITAN_PANEL_NONMOVABLE_PLUGINS = Titan_G.plugins.NonMovable_Plugins ---API Treat as deprecated

Titan_G.plugins.info = {}
TitanPlugins = Titan_G.plugins.info ---API Treat as deprecated; use internal var or Titan_G.plugins.Get
Titan_G.plugins.index = {}

Titan_G.constants.NOT_REGISTERED = _G["RED_FONT_COLOR_CODE"] .. "Not_Registered_Yet" .. _G["FONT_COLOR_CODE_CLOSE"]
Titan_G.constants.REGISTERED = _G["GREEN_FONT_COLOR_CODE"] .. "Registered" .. _G["FONT_COLOR_CODE_CLOSE"]
Titan_G.constants.REGISTER_FAILED = _G["RED_FONT_COLOR_CODE"] .. "Failed_to_Register" .. _G["FONT_COLOR_CODE_CLOSE"]

Titan_G.InitializedPEW = false

Titan_G.constants.AT_SYM = "@"
Titan_G.constants.MENU_FUNC_HIDE = "TitanPanelRightClickMenu_Hide"
TITAN_PANEL_MENU_FUNC_HIDE = Titan_G.constants.MENU_FUNC_HIDE ---API Just in case 3rd party plugins use this

TitanAll = nil;
TitanSettings = nil;
TitanPlayerSettings = nil
TitanPluginSettings = nil; -- Used by plugins
TitanPanelSettings = nil;


TITAN_PANEL_UPDATE_BUTTON = 1;
TITAN_PANEL_UPDATE_TOOLTIP = 2;
TITAN_PANEL_UPDATE_ALL = 3;
TitanTooltipOrigScale = 1;
TitanTooltipScaleSet = 0;

-- Set Titan Version var for backwards compatibility, set later
TITAN_VERSION = ""

-- Various constants
TITAN_PANEL_PLACE_TOP = 1;
TITAN_PANEL_PLACE_BOTTOM = 2;
TITAN_PANEL_PLACE_BOTH = 3;
TITAN_PANEL_MOVING = 0;

TITAN_WOW_SCREEN_TOP = 768
TITAN_WOW_SCREEN_BOT = 0

TITAN_TOP = "Top"
TITAN_BOTTOM = "Bottom"
TITAN_SHORT = "Short"

TITAN_RIGHT = "Right"
TITAN_LEFT = "Left"
TITAN_PANEL_BUTTONS_ALIGN_LEFT = 1;
TITAN_PANEL_BUTTONS_ALIGN_CENTER = 2;

-- Titan plugins are in the form of TitanPanel<id>Button
Titan_G.plugins.PRE = "TitanPanel"
Titan_G.plugins.POST = "Button"


-- New bar vars
Titan_G.bars.HEIGHT = 24
Titan_G.bars.TEXT_STR = "Text"
Titan_G.bars.PRE_STR = "Titan_Bar__Display_"
Titan_G.bars.TEX_PRE = "TitanPanelBackground_"
Titan_G.bars.MENU_PRE = "RightClickMenu"
Titan_G.bars.HIDER_PRE = "Titan_Bar__Hider_"

TITAN_PANEL_CONSTANTS = {
	FONT_SIZE = 10,
	FONT_NAME = "Friz Quadrata TT"
}

TITAN_CUSTOM_PROFILE_POSTFIX = "TitanCustomProfile"
TITAN_PROFILE_NONE = "<>"
TITAN_PROFILE_RESET = "<RESET>"
TITAN_PROFILE_USE = "<USE>"
TITAN_PROFILE_INIT = "<INIT>"

AUTOHIDE_PREFIX = "TitanPanelAutoHide_"
AUTOHIDE_SUFFIX = "Button"

--[===[ Adding Categories to Titan Menu
NAME: TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY and TITAN_PANEL_MENU_CATEGORIES
These two tables hold the list of categories for the Titan menu.
Logically they are category - text string pairs.
Where category is the internal label to be used.
Where text is the localized text.
The category should be unique across the table or the menu navigation may be what the user expects.
Some Titan plugins add to this list to make user navigation easier for their Titan plugins.

Add to these lists by using table insert. Example :
Insert the internal name
table.insert(TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY, "CAT_ZONES")

Then insert the localized string for the user
local categories = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID, true)["TITAN_PANEL_MENU_CATEGORIES"]
table.insert(categories, "Zones")
Titan uses AceLocale to simplify using localized strings.
--]===]
TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY = ---API
{ "Built-ins", "General", "Combat", "Information", "Interface", "Profession" }
---@diagnostic disable-next-line: assign-type-mismatch
L["TITAN_PANEL_MENU_CATEGORIES"] = {
	L["TITAN_PANEL_MENU_CATEGORIES_01"],
	L["TITAN_PANEL_MENU_CATEGORIES_02"],
	L["TITAN_PANEL_MENU_CATEGORIES_03"],
	L["TITAN_PANEL_MENU_CATEGORIES_04"],
	L["TITAN_PANEL_MENU_CATEGORIES_05"],
	L["TITAN_PANEL_MENU_CATEGORIES_06"],
}

---=============

-- Intended Titan only for internal 'plugins' such as Bars
Titan_G.categories = {}
Titan_G.categories.TitanBar = "Titan-bar"

-- Bar background types
Titan_G.SKIN = "skin"
Titan_G.COLOR = "color"
Titan_G.NONE = "none"

-- Profile types
Titan_G.profile = {}
Titan_G.profile.GLOBAL = "global"
Titan_G.profile.SYNC = "sync"
Titan_G.profile.TOON = "toon"
Titan_G.profile.NONE = "<>"

-- For WoW localized strings / literals we are using
Titan_G.literals = {
	low = LOW,
	high = HIGH,
	yes = YES,
	no = NO,
	help = HELP_LABEL,
	mute = MUTE,
	muted = MUTED,
	pvp = PVP,
	use = USE,
	note = LABEL_NOTE,
	all = ALL,
	none = NONE,
}

Titan_G.colors = {
	alliance = "00adf0", -- PLAYER_FACTION_COLOR_ALLIANCE
	blue = "0000ff", -- PURE_BLUE_COLOR
	blue_light = "69ccf0",
	coin_gold = "ffd100",
	coin_silver = "e6e6e6",
	coin_copper = "c8602c",
	copper = "b87333",
	gold = "f2e699", -- GOLD_FONT_COLOR
	gray = "808080", -- GRAY_FONT_COLOR
	green = "19ff19", -- GREEN_FONT_COLOR
	horde = "ff2934", -- PLAYER_FACTION_COLOR_HORDE
	orange = "ff8c00",
	pink = "f48cb78",
	purple = "949cc9",
	tan = "c79c6e",
	red = "ff2020", -- RED_FONT_COLOR
	silver = "cccccc",
	white = "ffffff", -- HIGHLIGHT_FONT_COLOR
	yellow_gold = "ffd200", -- NORMAL_FONT_COLOR
	yellow = "ffff00", -- YELLOW_FONT_COLOR
}

-- type for plugin registry
---@class PluginRegistryType
---@field id string The unique name of the plugin
---@field category? string The Titan menu category where this plugin will be placed
---@field version? string Plugin version
---@field menuText? string Localized string for the menu (right click)
---@field menuTextFunction? string | function Plugin function to call on right click NEW Jan 2026
---@field menuContextFunction? string | function Plugin function to call on right click
---@field buttonTextFunction? string | function Function to call when updating button display
---@field tooltipTitle? string Localized string for the menu
---@field tooltipTextFunction? string | function Function to call for a simple tooltip (OnEnter)
---@field tooltipCustomFunction? function Function to call for a complex tooltip (OnEnter)
---@field icon? string Path to the plugin icon
---@field iconWidth? integer Path to the plugin icon
---@field notes? string Brief description shown in Titan > Config > Plugins when this plugin is selected
---@field controlVariables? table Show or not on menu - set to true or false - ShowIcon ShowLabelText ShowColoredText DisplayOnRightSide
---@field savedVariables? table Initial value of any saved variables for this plugin; should include control variables

---Return an empty registry - only the id is set.
---@param id string The unique name of the plugin
---@return PluginRegistryType
--- reg = Titan_G.NewRegistry("MyAddon")
function Titan_G.plugins.NewRegistry(id)
	local reg = { id = id } ---@type PluginRegistryType
	return reg
---This routine was added for an IDE with Intellisense that supports Lua.
end
Titan_G.NewRegistry = Titan_G.plugins.NewRegistry ---API

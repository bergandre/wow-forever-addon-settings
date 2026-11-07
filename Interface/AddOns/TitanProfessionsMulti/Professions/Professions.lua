--[[
	Profession definitions shared by Retail and Mists.
	The tracking implementation lives in Core/ProfessionTracker.lua.
--]]

local ADDON_NAME, L = ...
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata(ADDON_NAME, "Version")
local expansionLevel = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT") or 0
local mistsExpansion = rawget(_G, "LE_EXPANSION_MISTS_OF_PANDARIA")
local isMists = mistsExpansion and expansionLevel == mistsExpansion

local function icon(modern, legacy)
	if modern and expansionLevel >= 9 then
		return modern
	end

	return legacy
end

local professions = {
	{
		id = "ALCM",
		nameKey = "alchemy",
		skillLineID = 171,
		icon = icon("Interface\\Icons\\ui_profession_alchemy", "Interface\\Icons\\trade_alchemy"),
		combinations = { "herbalism" },
	},
	{
		id = "ARCM",
		nameKey = "archaeology",
		slot = "archaeology",
		icon = "Interface\\Icons\\Trade_archaeology.blp",
		capProfile = "archaeology",
		warningMax = 950,
	},
	{
		id = "BLAM",
		nameKey = "blacksmithing",
		skillLineID = 164,
		icon = icon("Interface\\Icons\\ui_profession_blacksmithing", "Interface\\Icons\\trade_blacksmithing"),
		combinations = { "mining" },
	},
	{
		id = "COOM",
		nameKey = "cooking",
		slot = "cooking",
		icon = icon("Interface\\Icons\\ui_profession_cooking", "Interface\\Icons\\inv_misc_food_15"),
		combinations = { "fishing" },
	},
	{
		id = "ENCM",
		nameKey = "enchanting",
		skillLineID = 333,
		icon = icon("Interface\\Icons\\ui_profession_enchanting", "Interface\\Icons\\trade_engraving"),
		combinations = { "tailoring" },
	},
	{
		id = "ENGM",
		nameKey = "engineering",
		skillLineID = 202,
		icon = "Interface\\Icons\\Trade_engineering.blp",
		combinations = { "mining" },
	},
	{
		id = "FIRM",
		nameKey = "firstAid",
		slot = "firstAid",
		icon = "Interface\\Icons\\Spell_holy_sealofsacrifice.blp",
		combinations = { "tailoring" },
		unlearnedTextKey = "nosecskill",
		hideCombinationByDefault = false,
		mistsOnly = true,
	},
	{
		id = "FISM",
		nameKey = "fishing",
		slot = "fishing",
		icon = icon("Interface\\Icons\\ui_profession_fishing", "Interface\\Icons\\trade_fishing"),
		combinations = { "cooking" },
		capProfile = "fishing",
		clickable = false,
		showHint = false,
	},
	{
		id = "HERM",
		nameKey = "herbalism",
		skillLineID = 182,
		icon = icon("Interface\\Icons\\ui_profession_herbalism", "Interface\\Icons\\spell_nature_naturetouchgrow"),
		combinations = { "alchemy", "inscription" },
	},
	{
		id = "INSM",
		nameKey = "inscription",
		skillLineID = 773,
		icon = icon("Interface\\Icons\\ui_profession_inscription", "Interface\\Icons\\inv_inscription_tradeskill01"),
		combinations = { "herbalism" },
	},
	{
		id = "JEWM",
		nameKey = "jewelcrafting",
		skillLineID = 755,
		icon = icon("Interface\\Icons\\ui_profession_jewelcrafting", "Interface\\Icons\\inv_misc_gem_01"),
		combinations = { "mining" },
	},
	{
		id = "LEAM",
		nameKey = "leatherworking",
		skillLineID = 165,
		icon = "Interface\\Icons\\Trade_leatherworking.blp",
		combinations = { "skinning" },
	},
	{
		id = "MINM",
		nameKey = "mining",
		skillLineID = 186,
		icon = icon("Interface\\Icons\\ui_profession_mining", "Interface\\Icons\\trade_mining"),
		combinations = { "blacksmithing", "engineering", "jewelcrafting" },
	},
	{
		id = "SKIM",
		nameKey = "skinning",
		skillLineID = 393,
		icon = icon("Interface\\Icons\\ui_profession_skinning", "Interface\\Icons\\inv_misc_pelt_wolf_01"),
		combinations = { "leatherworking" },
	},
	{
		id = "TAIM",
		nameKey = "tailoring",
		skillLineID = 197,
		icon = icon("Interface\\Icons\\ui_profession_tailoring", "Interface\\Icons\\trade_tailoring"),
		combinations = { "enchanting" },
	},
}

for _, config in ipairs(professions) do
	if not config.mistsOnly or isMists then
		config.version = version
		L.ProfessionTracker:Register(config)
	end
end

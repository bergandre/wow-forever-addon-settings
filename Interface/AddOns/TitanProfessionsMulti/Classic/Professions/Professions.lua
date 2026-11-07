-- Profession definitions shared by Classic Era and The Burning Crusade.

local ADDON_NAME, L = ...
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata(ADDON_NAME, "Version")
local currentExpansion = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT")
local burningCrusade = rawget(_G, "LE_EXPANSION_BURNING_CRUSADE")
local isBurningCrusade = not L.IsForever and burningCrusade and currentExpansion == burningCrusade

local professions = {
	{
		id = "ALCM",
		nameKey = "alchemy",
		skillLineID = 171,
		icon = "Interface\\Icons\\Trade_alchemy.blp",
		combinations = { "herbalism" },
	},
	{
		id = "BLAM",
		nameKey = "blacksmithing",
		skillLineID = 164,
		icon = "Interface\\Icons\\Trade_blacksmithing.blp",
		combinations = { "mining" },
	},
	{
		id = "COOM",
		nameKey = "cooking",
		slot = "cooking",
		icon = "Interface\\Icons\\Inv_misc_food_15.blp",
		combinations = { "fishing" },
		unlearnedTextKey = "nosecskill",
	},
	{
		id = "ENCM",
		nameKey = "enchanting",
		skillLineID = 333,
		icon = "Interface\\Icons\\Trade_engraving.blp",
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
	},
	{
		id = "FISM",
		nameKey = "fishing",
		slot = "fishing",
		icon = "Interface\\Icons\\Trade_fishing.blp",
		combinations = { "cooking" },
		unlearnedTextKey = "nosecskill",
		clickable = false,
		showHint = false,
	},
	{
		id = "HERM",
		nameKey = "herbalism",
		skillLineID = 182,
		icon = "Interface\\Icons\\Spell_nature_naturetouchgrow.blp",
		combinations = { "alchemy" },
	},
	{
		id = "JEWM",
		nameKey = "jewelcrafting",
		skillLineID = 755,
		icon = "Interface\\Icons\\Inv_misc_gem_02.blp",
		combinations = { "mining" },
		tbcOnly = true,
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
		icon = "Interface\\Icons\\Trade_mining.blp",
		combinations = { "blacksmithing", "engineering", "jewelcrafting" },
	},
	{
		id = "SKIM",
		nameKey = "skinning",
		skillLineID = 393,
		icon = "Interface\\Icons\\Inv_misc_pelt_wolf_01.blp",
		combinations = { "leatherworking" },
	},
	{
		id = "TAIM",
		nameKey = "tailoring",
		skillLineID = 197,
		icon = "Interface\\Icons\\Trade_tailoring.blp",
		combinations = { "enchanting" },
	},
}

for _, config in ipairs(professions) do
	if not config.tbcOnly or isBurningCrusade then
		config.version = version
		config.hideCombinationByDefault = false
		L.ProfessionTracker:Register(config)
	end
end

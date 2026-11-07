-- Mists of Pandaria reagent definitions.

local _, L = ...
local RegisterExpansion = L.ReagentTracker and L.ReagentTracker.RegisterExpansion
if not RegisterExpansion then return end

local function withHarmony(items)
	items[#items + 1] = { name = "Mote of Harmony", ids = { 89112 } }
	items[#items + 1] = { name = "Spirit of Harmony", ids = { 76061 } }
	return items
end

RegisterExpansion({
	name = "Mists of Pandaria",
	labelKey = "rMists",
	shortLabelKey = "rMists",
	professions = {
		{
			id = "TITAN_RESCOOMM_MOP",
			professionKey = "cooking",
			professionName = "Cooking",
			icon = "Interface\\Icons\\Inv_misc_food_15.blp",
			items = withHarmony({
				{ name = "Raw Tiger Steak", ids = { 74833 } },
				{ name = "Mushan Ribs", ids = { 74834 } },
				{ name = "Raw Turtle Meat", ids = { 74837 } },
				{ name = "Raw Crab Meat", ids = { 74838 } },
				{ name = "Wildfowl Breast", ids = { 74839 } },
			}),
		},
		{
			id = "TITAN_RESENCHM_MOP",
			professionKey = "enchanting",
			professionName = "Enchanting",
			icon = "Interface\\Icons\\Trade_engraving",
			items = withHarmony({
				{ name = "Spirit Dust", ids = { 74249 } },
				{ name = "Mysterious Essence", ids = { 74250 } },
				{ name = "Ethereal Shard", ids = { 74247 } },
				{ name = "Sha Crystal", ids = { 74248 } },
			}),
		},
		{
			id = "TITAN_RESFISHM_MOP",
			professionKey = "fishing",
			professionName = "Fishing",
			icon = "Interface\\Icons\\Trade_fishing",
			items = withHarmony({
				{ name = "Jade Lungfish", ids = { 74856 } },
				{ name = "Giant Mantis Shrimp", ids = { 74857 } },
				{ name = "Emperor Salmon", ids = { 74859 } },
				{ name = "Redbelly Mandarin", ids = { 74860 } },
				{ name = "Tiger Gourami", ids = { 74861 } },
				{ name = "Jewel Danio", ids = { 74863 } },
				{ name = "Reef Octopus", ids = { 74864 } },
				{ name = "Krasarang Paddlefish", ids = { 74865 } },
				{ name = "Golden Carp", ids = { 74866 } },
				{ name = "Spinefish", ids = { 83064 } },
			}),
		},
		{
			id = "TITAN_RESHERBM_MOP",
			professionKey = "herbalism",
			professionName = "Herbalism",
			icon = "Interface\\Icons\\Trade_herbalism",
			items = withHarmony({
				{ name = "Green Tea Leaf", ids = { 72234 } },
				{ name = "Silkweed", ids = { 72235 } },
				{ name = "Rain Poppy", ids = { 72237 } },
				{ name = "Golden Lotus", ids = { 72238 } },
				{ name = "Snow Lily", ids = { 79010 } },
				{ name = "Fool's Cap", ids = { 79011 } },
			}),
		},
		{
			id = "TITAN_RESISCPM_MOP",
			professionKey = "inscription",
			professionName = "Inscription",
			icon = "Interface\\Icons\\Inv_inscription_tradeskill01.blp",
			items = withHarmony({
				{ name = "Shadow Pigment", ids = { 79251 } },
				{ name = "Misty Pigment", ids = { 79253 } },
				{ name = "Ink of Dreams", ids = { 79254 } },
				{ name = "Starlight Ink", ids = { 79255 } },
			}),
		},
		{
			id = "TITAN_RESJEWCM_MOP",
			professionKey = "jewelcrafting",
			professionName = "Jewelcrafting",
			icon = "Interface\\Icons\\Inv_misc_gem_02.blp",
			items = withHarmony({
				{ name = "Tiger Opal", ids = { 76130 } },
				{ name = "Primordial Ruby", ids = { 76131 } },
				{ name = "Lapis Lazuli", ids = { 76133 } },
				{ name = "Sunstone", ids = { 76134 } },
				{ name = "Roguestone", ids = { 76135 } },
				{ name = "Pandarian Garnet", ids = { 76136 } },
				{ name = "Alexandrite", ids = { 76137 } },
				{ name = "River's Heart", ids = { 76138 } },
				{ name = "Wild Jade", ids = { 76139 } },
				{ name = "Vermilion Onyx", ids = { 76140 } },
				{ name = "Imperial Amethyst", ids = { 76141 } },
				{ name = "Sun's Radiance", ids = { 76142 } },
				{ name = "Serpent's Eye", ids = { 76734 } },
			}),
		},
		{
			id = "TITAN_RESMINIM_MOP",
			professionKey = "mining",
			professionName = "Mining",
			icon = "Interface\\Icons\\Trade_mining",
			items = withHarmony({
				{ name = "Ghost Iron Ore", ids = { 72092 } },
				{ name = "Kyparite", ids = { 72093 } },
				{ name = "Black Trillium Ore", ids = { 72094 } },
				{ name = "White Trillium Ore", ids = { 72103 } },
			}),
		},
		{
			id = "TITAN_RESSKINM_MOP",
			professionKey = "skinning",
			professionName = "Skinning",
			icon = "Interface\\Icons\\Inv_misc_pelt_wolf_01",
			items = withHarmony({
				{ name = "Exotic Leather", ids = { 72120 } },
				{ name = "Prismatic Scale", ids = { 72162 } },
				{ name = "Magnificent Hide", ids = { 72163 } },
				{ name = "Hardened Magnificent Hide", ids = { 98617 } },
			}),
		},
		{
			id = "TITAN_RESTAILM_MOP",
			professionKey = "tailoring",
			professionName = "Tailoring",
			icon = "Interface\\Icons\\Trade_tailoring",
			items = withHarmony({
				{ name = "Windwool Cloth", ids = { 72988 } },
				{ name = "Imperial Silk", ids = { 82447 } },
				{ name = "Celestial Cloth", ids = { 98619 } },
			}),
		},
	},
})

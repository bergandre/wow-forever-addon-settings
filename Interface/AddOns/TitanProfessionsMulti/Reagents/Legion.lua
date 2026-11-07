-- Legion reagent definitions.

local _, L = ...
local RegisterExpansion = L.ReagentTracker and L.ReagentTracker.RegisterExpansion
if not RegisterExpansion then return end

RegisterExpansion({
	name = "Legion",
	labelKey = "rLegion",
	shortLabelKey = "rLegion",
	professions = {
		{
			id = "TITAN_RESENCHM",
			professionKey = "enchanting",
			professionName = "Enchanting",
			icon = "Interface\\Icons\\Trade_engraving",
			items = {
				{ name = "Arkhana", ids = { 124440 }, hideVariable = "HideArkhana" },
				{ name = "Leylight Shard", ids = { 124441 }, hideVariable = "HideLeylight" },
				{ name = "Chaos Crystal", ids = { 124442 }, hideVariable = "HideChaos" },
				{ name = "Blood of Sargeras", ids = { 124124 }, hideVariable = "HideBlood" },
			},
		},
		{
			id = "TITAN_RESFISHM",
			professionKey = "fishing",
			professionName = "Fishing",
			icon = "Interface\\Icons\\Trade_fishing",
			items = {
				{ name = "Silver Mackerel", ids = { 133607 }, hideVariable = "HideMackerel" },
				{ name = "Cursed Queenfish", ids = { 124107 }, hideVariable = "HideQueen" },
				{ name = "Highmountain Salmon", ids = { 124109 }, hideVariable = "HideSalmon" },
				{ name = "Mossgill Perch", ids = { 124108 }, hideVariable = "HideMossgill" },
				{ name = "Stormray", ids = { 124110 }, hideVariable = "HideStormray" },
				{ name = "Runescale Koi", ids = { 124111 }, hideVariable = "HideKoi" },
				{ name = "Black Barracuda", ids = { 124112 }, hideVariable = "HideBarracuda" },
			},
		},
		{
			id = "TITAN_RESHERBM",
			professionKey = "herbalism",
			professionName = "Herbalism",
			icon = "Interface\\Icons\\Trade_herbalism",
			items = {
				{ name = "Yseralline Seed", ids = { 128304 }, hideVariable = "HideYseralline" },
				{ name = "Felwort", ids = { 124106 }, hideVariable = "HideFelwort" },
				{ name = "Starlight Rose", ids = { 124105 }, hideVariable = "HideStarlight" },
				{ name = "Fjarnskaggl", ids = { 124104 }, hideVariable = "HideFjarnskaggl" },
				{ name = "Foxflower", ids = { 124103 }, hideVariable = "HideFox" },
				{ name = "Dreamleaf", ids = { 124102 }, hideVariable = "HideDreamleaf" },
				{ name = "Aethril", ids = { 124101 }, hideVariable = "HideAethril" },
				{ name = "Blood of Sargeras", ids = { 124124 }, hideVariable = "HideBlood" },
			},
		},
		{
			id = "TITAN_RESMINIM",
			professionKey = "mining",
			professionName = "Mining",
			icon = "Interface\\Icons\\Trade_mining",
			items = {
				{ name = "Leystone Ore", ids = { 123918 }, hideVariable = "HideLeyStone" },
				{ name = "Felslate", ids = { 123919 }, hideVariable = "HideFelslate" },
				{ name = "Infernal Brimstone", ids = { 124444 }, hideVariable = "HideBrimstone" },
				{ name = "Blood of Sargeras", ids = { 124124 }, hideVariable = "HideBlood" },
			},
		},
		{
			id = "TITAN_RESSKINM",
			professionKey = "skinning",
			professionName = "Skinning",
			icon = "Interface\\Icons\\Inv_misc_pelt_wolf_01",
			items = {
				{ name = "Stormscale", ids = { 124115 }, hideVariable = "HideStormscale" },
				{ name = "Stonehide Leather", ids = { 124113 }, hideVariable = "HideStonehide" },
				{ name = "Felhide", ids = { 124116 }, hideVariable = "HideFelhide" },
				{ name = "Unbroken Tooth", ids = { 124439 }, hideVariable = "HideTooth" },
				{ name = "Unbroken Claw", ids = { 124438 }, hideVariable = "HideClaw" },
				{ name = "Blood of Sargeras", ids = { 124124 }, hideVariable = "HideBlood" },
			},
		},
		{
			id = "TITAN_RESTAILM",
			professionKey = "tailoring",
			professionName = "Tailoring",
			icon = "Interface\\Icons\\Trade_tailoring",
			items = {
				{ name = "Shal'dorei Silk", ids = { 124437 }, hideVariable = "HideShaldorei" },
				{ name = "Imbued Silkweave", ids = { 127004 }, hideVariable = "HideSilkweave" },
				{ name = "Blood of Sargeras", ids = { 124124 }, hideVariable = "HideBlood" },
			},
		},
	},
})

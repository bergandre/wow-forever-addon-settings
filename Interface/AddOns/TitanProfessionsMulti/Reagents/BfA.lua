-- Battle for Azeroth reagent definitions.

local _, L = ...
local RegisterExpansion = L.ReagentTracker and L.ReagentTracker.RegisterExpansion
if not RegisterExpansion then return end

RegisterExpansion({
	name = "BfA",
	labelKey = "rBfA",
	shortLabelKey = "rBfA",
	professions = {
		{
			id = "TITAN_RESENCHM_BFA",
			professionKey = "enchanting",
			professionName = "Enchanting",
			icon = "Interface\\Icons\\Trade_engraving",
			items = {
				{ name = "Gloom Dust", ids = { 152875 }, hideVariable = "HideGloom" },
				{ name = "Umbra Shard", ids = { 152876 }, hideVariable = "HideUmbraShard" },
				{ name = "Veiled Crystal", ids = { 152877 }, hideVariable = "HideVC" },
			},
		},
		{
			id = "TITAN_RESFISHM_BFA",
			professionKey = "fishing",
			professionName = "Fishing",
			icon = "Interface\\Icons\\Trade_fishing",
			items = {
				{ name = "Sand Shifter", ids = { 152543 }, hideVariable = "HideSShifter" },
				{ name = "Great Sea Catfish", ids = { 152547 }, hideVariable = "HideGSea" },
				{ name = "Tiragarde Perch", ids = { 152548 }, hideVariable = "HideTPerch" },
				{ name = "Lane Snapper", ids = { 152546 }, hideVariable = "HideLSnapper" },
				{ name = "Frenzied Fangtooth", ids = { 152545 }, hideVariable = "HideFFtooth" },
				{ name = "Redtail Loach", ids = { 152549 }, hideVariable = "HideRedtailL" },
				{ name = "Slimy Mackerel", ids = { 152544 }, hideVariable = "HideSlimyM" },
				{ name = "Midnight Salmon", ids = { 162515 }, hideVariable = "HideMSalmon" },
			},
		},
		{
			id = "TITAN_RESHERBM_BFA",
			professionKey = "herbalism",
			professionName = "Herbalism",
			icon = "Interface\\Icons\\Trade_herbalism",
			items = {
				{ name = "Zin'anthid", ids = { 168487 }, hideVariable = "HideHerbOneBfA" },
				{ name = "Riverbud", ids = { 152505 }, hideVariable = "HideHerbTwoBfA" },
				{ name = "Sea Stalk", ids = { 152511 }, hideVariable = "HideHerbThreeBfA" },
				{ name = "Star Moss", ids = { 152506 }, hideVariable = "HideHerbFourBfA" },
				{ name = "Akunda's Bite", ids = { 152507 }, hideVariable = "HideHerbFiveBfA" },
				{ name = "Winter's Kiss", ids = { 152508 }, hideVariable = "HideHerbSixBfA" },
				{ name = "Siren's Pollen", ids = { 152509 }, hideVariable = "HideHerbSevenBfA" },
				{ name = "Anchor Weed", ids = { 152510 }, hideVariable = "HideHerbEightBfA" },
			},
		},
		{
			id = "TITAN_RESMINIM_BFA",
			professionKey = "mining",
			professionName = "Mining",
			icon = "Interface\\Icons\\Trade_mining",
			items = {
				{ name = "Monelite Ore", ids = { 152512 }, hideVariable = "HideMonelite" },
				{ name = "Storm Silver Ore", ids = { 152579 }, hideVariable = "HideStormSilver" },
				{ name = "Platinum Ore", ids = { 152513 }, hideVariable = "HidePlatinum" },
				{ name = "Osmenite Ore", ids = { 168185 }, hideVariable = "HideOsmenite" },
			},
		},
		{
			id = "TITAN_RESSKINM_BFA",
			professionKey = "skinning",
			professionName = "Skinning",
			icon = "Interface\\Icons\\Inv_misc_pelt_wolf_01",
			items = {
				{ name = "Calcified Bone", ids = { 154165 }, hideVariable = "HideSkinOneBfA" },
				{ name = "Blood-Stained Bone", ids = { 154164 }, hideVariable = "HideSkinTwoBfA" },
				{ name = "Mistscale", ids = { 153051 }, hideVariable = "HideSkinThreeBfA" },
				{ name = "Shimmerscale", ids = { 153050 }, hideVariable = "HideSkinFourBfA" },
				{ name = "Tempest Hide", ids = { 154722 }, hideVariable = "HideSkinFiveBfA" },
				{ name = "Coarse Leather", ids = { 152541 }, hideVariable = "HideSkinSixBfA" },
				{ name = "Dredged Leather", ids = { 168649 }, hideVariable = "HideSkinSevenBfA" },
				{ name = "Cragscale", ids = { 168650 }, hideVariable = "HideSkinEightBfA" },
			},
		},
		{
			id = "TITAN_RESTAILM_BFA",
			professionKey = "tailoring",
			professionName = "Tailoring",
			icon = "Interface\\Icons\\Trade_tailoring",
			items = {
				{ name = "Tidespray Linen", ids = { 152576 }, hideVariable = "HideTidespray" },
				{ name = "Nylon Thread", ids = { 159959 }, hideVariable = "HideNylon" },
				{ name = "Deep Sea Satin", ids = { 152577 }, hideVariable = "HideSeaSatin" },
				{ name = "Embroidered Deep Sea Satin", ids = { 158378 }, hideVariable = "HideEmbroidered" },
				{ name = "Gilded Seaweave", ids = { 167738 }, hideVariable = "HideTailFiveBfA" },
			},
		},
	},
})

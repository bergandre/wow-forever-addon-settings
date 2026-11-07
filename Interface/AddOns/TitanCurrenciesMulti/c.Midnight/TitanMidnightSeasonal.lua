--[[
Description: This plugin is part of the "Titan Panel [Currencies] Multi" addon.
It shows the seasonal currencies from Midnight.
Site: https://www.curseforge.com/wow/addons/titan-panel-currencies-multi
Author: edurne85
Data based on information available on Wowhead and in-game.
--]]

local _, L = ...;

-- Adventurer Mistcrests
L:CreateSimpleCurrencyPlugin({
	currencyId = 3442,
	titanId = "TITAN_MIDNTADVENTURERCREST",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true,
	weeklyIncrease = 90
})

-- Veteran Mistcrests
L:CreateSimpleCurrencyPlugin({
	currencyId = 3443,
	titanId = "TITAN_MIDNTVETERANCREST",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true,
	weeklyIncrease = 90
})

-- Champion Mistcrests
L:CreateSimpleCurrencyPlugin({
	currencyId = 3444,
	titanId = "TITAN_MIDNTCHAMPIONCREST",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true,
	weeklyIncrease = 90
})

-- Hero Mistcrests
L:CreateSimpleCurrencyPlugin({
	currencyId = 3445,
	titanId = "TITAN_MIDNTHEROCREST",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true,
	weeklyIncrease = 90
})

-- Myth Mistcrests
L:CreateSimpleCurrencyPlugin({
	currencyId = 3446,
	titanId = "TITAN_MIDNTMYTHCREST",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true,
	weeklyIncrease = 90
})

-- Venomblight Manaflux (Midnight S2 Catalyst charges, max 8)
L:CreateSimpleCurrencyPlugin({
	currencyId = 3465,
	titanId = "TITAN_MIDNTS1CATALYST",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true
})

-- Coffer Key Shard (Midnight S2 version)
L:CreateSimpleCurrencyPlugin({
	currencyId = 3310,
	titanId = "TITAN_CFFRKYM",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT"
})

-- Spark of Tides (Midnight S2 crafting spark)
L:CreateSimpleItemPlugin({
	itemId = 274476,
	titanId = "TITAN_MIDNTS1SPARK",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT"
})

-- Thalassian Token of Merit
L:CreateSimpleItemPlugin({
	itemId = 269862,
	titanId = "TITAN_MIDNTS1TTOM",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT"
})

-- Untainted Mana-Crystals (Midnight S2 Delves)
-- Reused ID from TWW S3
L:CreateSimpleCurrencyPlugin({
	currencyId = 3356,
	titanId = "TITAN_TWWS3UNTMANACRYS",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true
})

-- Nebulous Voidcore
L:CreateSimpleCurrencyPlugin({
	currencyId = 3418,
	titanId = "TITAN_MIDNTNEBVCORE",
	noCurrencyText = L["NoMidnightSeason2"],
	expName = L["mMidnightS2"],
	category = "CATEGORY_MIDNIGHT",
	forceMax = true
})

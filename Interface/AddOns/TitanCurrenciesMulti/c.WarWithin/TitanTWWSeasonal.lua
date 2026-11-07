--[[
Description: This plugin is part of the "Titan Panel [Currencies] Multi" addon.
It shows the seasonal currencies from The War Within.
Site: https://www.curseforge.com/wow/addons/titan-panel-currencies-multi
Author: Canettieri
Special Thanks to Odysseas68 and Protuhj.
--]]

local _, L = ...;

-- Radiant Echo (TWW S3 version)
-- These will probably remain in the game for the foreseeable future because of Achievements requiring them.
L:CreateSimpleItemPlugin({
	itemId = 246771,
	titanId = "TITAN_RADECHO",
	noCurrencyText = L["TWWSeason3"],
	expName = L["mWarWithinS3"],
	category = "CATEGORY_TWW"
})

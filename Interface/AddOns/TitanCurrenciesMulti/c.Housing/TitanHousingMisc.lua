--[[
Description: This plugin is part of the "Titan Panel [Currencies] Multi" addon.
It shows miscellaneous Housing items
Site: https://www.curseforge.com/wow/addons/titan-panel-currencies-multi
Author: Protuhj
Special Thanks to Canettieri and Eliote.
--]]

local _, L = ...;

-- Community Coupons
L:CreateSimpleCurrencyPlugin({
	currencyId = 3363,
	titanId = "TITAN_HOUSECC",
	noCurrencyText = L["noCurrCommCoupons"],
	expName = L.Utils.MakeMenuText(L["mEndeavors"]),
	category = "CATEGORY_HOUSING"
})

-- Griftah's Token of Appreciation
L:CreateSimpleItemPlugin({
	itemId = 269994,
	titanId = "TITAN_HOUSEGTOA",
	noCurrencyText = L["noCurrCommCoupons"],
	expName = L.Utils.MakeMenuText(L["mEndeavors"]),
	category = "CATEGORY_HOUSING"
})

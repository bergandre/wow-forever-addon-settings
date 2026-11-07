-- Forever-only additions to the Classic material catalogue.
-- Item IDs and research scope: see docs/forever-reagents.md.
local _, L = ...
local expansion = L.CreateClassicReagentExpansion()
expansion.name = "Forever"
expansion.labelKey = "rForever"
expansion.shortLabelKey = "rForever"

local additions = {
	enchanting = {
		{ name = "Mote of Magic", ids = { 247786 } },
		{ name = "Malleable Essence of Nature", ids = { 274030 } },
	},
	fishing = {
		{ name = "Whimsyfin", ids = { 251524 } },
		{ name = "Seasonal Fish Steaks", ids = { 273295 } },
	},
	herbalism = {
		{ name = "Frilled Lichen", ids = { 249399 } },
		{ name = "Rosecap", ids = { 249424 } },
		{ name = "Stranglevine", ids = { 249274 } },
		{ name = "Marefoil", ids = { 248823 } },
		{ name = "Demonsage", ids = { 248821 } },
		{ name = "Death Lotus", ids = { 248822 } },
		{ name = "Commonplace Herb Seeds", ids = { 268415 } },
		{ name = "Uncommon Herb Seeds", ids = { 268416 } },
		{ name = "Unusual Herb Seeds", ids = { 268417 } },
		{ name = "Scarce Herb Seeds", ids = { 268418 } },
	},
	mining = {
		{ name = "Pyrite", ids = { 249391 } },
		{ name = "Bauxite", ids = { 249425 } },
		{ name = "Pitchblende", ids = { 249426 } },
		{ name = "Heavy Thorium Ore", ids = { 248815 } },
		{ name = "Heavy Thorium Bar", ids = { 251291 } },
		{ name = "Azerothium Bar", ids = { 249726 } },
		{ name = "Legionite Bar", ids = { 251290 } },
		{ name = "Fel Crystal", ids = { 248819 } },
		{ name = "Torbernite", ids = { 248820 } },
	},
	skinning = {
		{ name = "Pristine Leather", ids = { 249427 } },
		{ name = "Pristine Hide", ids = { 249428 } },
		{ name = "Pristine Scale", ids = { 249429 } },
		{ name = "Fel Leather", ids = { 248825 } },
		{ name = "Fel Hide", ids = { 248824 } },
	},
	tailoring = {
		{ name = "Cerulean Dye", ids = { 249409 } },
		{ name = "Magenta Dye", ids = { 249430 } },
		{ name = "Viridian Dye", ids = { 249431 } },
	},
}

for _, profession in ipairs(expansion.professions) do
	-- Retain the Classic plugin IDs and HideItem_<ID> settings for existing users.
	for _, item in ipairs(additions[profession.professionKey] or {}) do
		profession.items[#profession.items + 1] = item
	end
end

L.ReagentTracker.RegisterExpansion(expansion)

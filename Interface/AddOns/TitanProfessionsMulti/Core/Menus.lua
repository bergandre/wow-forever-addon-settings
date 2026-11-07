-- Adds a dedicated Titan category for profession reagent trackers.

local _, L = ...
local CATEGORY_ID = "ProfessionReagents"
local titanLocale = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID, true)
local categories = titanLocale and titanLocale["TITAN_PANEL_MENU_CATEGORIES"]

L.ReagentCategory = CATEGORY_ID

if categories and TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY then
	local categoryExists = false
	for _, category in ipairs(TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY) do
		if category == CATEGORY_ID then
			categoryExists = true
			break
		end
	end

	if not categoryExists then
		table.insert(categories, L["reagentCategory"] or "Profession [Reagents]")
		table.insert(TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY, CATEGORY_ID)
	end
end

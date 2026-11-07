--[[
	Description: This plugin is part of the "Titan Panel [Professions] Multi" addon.
	Site: https://www.curseforge.com/wow/addons/titan-panel-professions-multi
	Author: Canettieri
	Special Thanks to Eliote.
--]]

local ADDON_NAME, L = ...;
local ACE = LibStub("AceLocale-3.0"):GetLocale("Titan", true)
L.Elib = LibStub("Elib-4.0").Register
L.ProfessionMenuColor = "FFFDCE08"

-- Titan removes color codes from menuText while registering and sorting plugins.
-- Restore them once registration has completed, as the Currencies addon does.
local pendingMenuColors = {}
local menuColorFrame

local function RestoreMenuColors(self)
	local pending = false
	for button, menuText in pairs(pendingMenuColors) do
		local registry = button.registry
		if registry and TitanPlugins and TitanPlugins[registry.id] == registry then
			registry.menuText = menuText
			pendingMenuColors[button] = nil
		else
			pending = true
		end
	end

	if not pending then
		self:SetScript("OnUpdate", nil)
	end
end

function L.RestoreTitanMenuColor(button, menuText)
	pendingMenuColors[button] = menuText
	if not menuColorFrame then
		menuColorFrame = CreateFrame("Frame")
	end
	menuColorFrame:SetScript("OnUpdate", RestoreMenuColors)
end

function L.AddMenuTitle(eddm, text)
	eddm.UIDropDownMenu_AddButton({
		text = text,
		hasArrow = false,
		isTitle = true,
		isUninteractable = true,
		notClickable = true,
		notCheckable = true,
	})
end

function L.AddBarPositionMenu(eddm, id)
	L.AddMenuTitle(eddm, L["barPosition"])

	eddm.UIDropDownMenu_AddButton({
		text = L["moveRight"],
		func = function()
			TitanUtils_ShiftButtonOnBarRight(id)
		end,
		keepShownOnClick = true,
		notCheckable = true,
	})

	eddm.UIDropDownMenu_AddButton({
		text = L["moveLeft"],
		func = function()
			TitanUtils_ShiftButtonOnBarLeft(id)
		end,
		keepShownOnClick = true,
		notCheckable = true,
	})
end

function L.AddMenuFooter(eddm, id)
	eddm.UIDropDownMenu_AddSeparator()
	eddm.UIDropDownMenu_AddButton({
		notCheckable = true,
		text = ACE["TITAN_PANEL_MENU_HIDE"],
		func = function()
			TitanPanelRightClickMenu_Hide(id)
		end,
	})
	eddm.UIDropDownMenu_AddButton({
		text = CLOSE,
		notCheckable = true,
		keepShownOnClick = false,
	})
end

local function ToggleRightSideDisplay(self, id) -- Right side display
	TitanToggleVar(id, "DisplayOnRightSide");
	TitanPanel_InitPanelButtons();
end

local function ToggleHideMax(self, id) -- Hide Max display
	TitanToggleVar(id, "HideMax");
	TitanPanelButton_UpdateButton(id)
end

local function ToggleHideCombination(self, id) -- Hide Profession Combination
	TitanToggleVar(id, "HideCombination");
	TitanPanelButton_UpdateButton(id)
end

local function ToggleShowBarBalance(self, id) -- Show Balance in Titan Bar
	TitanToggleVar(id, "ShowBarBalance");
	TitanPanelButton_UpdateButton(id)
end

local function ToggleSimpleBonus(self, id) -- Simples bonus display
	TitanToggleVar(id, "SimpleBonus");
	TitanPanelButton_UpdateButton(id)
end
----------------------------------------------
function L.PrepareProfessionsMenu(eddm, self, id)
	L.AddMenuTitle(eddm, TitanPlugins[id].menuText)

	local info = {};
	info.text = L["buttonText"];
	info.notClickable = true
	info.notCheckable = true
	info.isTitle = true
	eddm.UIDropDownMenu_AddButton(info);

	info = {};
	info.text = L["simpleb"];
	info.func = ToggleSimpleBonus;
	info.arg1 = id
	info.checked = TitanGetVar(id, "SimpleBonus");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	info = {};
	info.text = L["hidemax"];
	info.func = ToggleHideMax;
	info.arg1 = id
	info.checked = TitanGetVar(id, "HideMax");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	info = {};
	info.text = L["showbb"];
	info.func = ToggleShowBarBalance;
	info.arg1 = id
	info.checked = TitanGetVar(id, "ShowBarBalance");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	info = {};
	info.text = ACE["TITAN_CLOCK_MENU_DISPLAY_ON_RIGHT_SIDE"];
	info.func = ToggleRightSideDisplay;
	info.arg1 = id
	info.checked = TitanGetVar(id, "DisplayOnRightSide");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	eddm.UIDropDownMenu_AddSpace()

	info = {};
	info.text = L["tooltip"];
	info.notClickable = true
	info.notCheckable = true
	info.isTitle = true
	eddm.UIDropDownMenu_AddButton(info);

	info = {};
	info.text = L["hideCombination"];
	info.func = ToggleHideCombination;
	info.arg1 = id
	info.checked = TitanGetVar(id, "HideCombination");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	eddm.UIDropDownMenu_AddSpace()
	L.AddBarPositionMenu(eddm, id)
	L.AddMenuFooter(eddm, id)
end

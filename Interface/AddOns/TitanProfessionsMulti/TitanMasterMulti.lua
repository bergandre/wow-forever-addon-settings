--[[
Description: This plugin is part of the "Titan Panel [Professions] Multi" addon. It shows all professions!
Site: https://www.curseforge.com/wow/addons/titan-panel-professions-multi
Author: Canettieri
Special Thanks to Eliote.
--]]

local ADDON_NAME, L = ...;
local ACE = LibStub("AceLocale-3.0"):GetLocale("Titan", true)
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata(ADDON_NAME, "Version")
local ID = "TITAN_MSTRM"
local PLAYER_NAME = "|c" .. RAID_CLASS_COLORS[select(2, UnitClass("player"))].colorStr .. UnitName("player")

local function interp(str, tab)
	return (str:gsub('($%b{})', function(w) return tostring(tab[w:sub(3, -2)] or w) end))
end

local function trim(s)
	local from = s:match"^%s*()"
	return from > #s and "" or s:match(".*%S", from)
end
-----------------------------------------------
local INFOS_INDEX = {
	NAME = 1,
	ICON = 2,
	SKILL = 3,
	MAX = 4,
	PROFOFFSET = 6,
	BONUS = 8,
}
local profs = {}
-----------------------------------------------
local function OnUpdate(self, id)

	for i = 1, 6 do
		local prof = select(i, GetProfessions())
		if prof ~= nil then
			profs[i] = { GetProfessionInfo(prof) }
		else
			profs[i] = nil
		end
	end

	TitanPanelButton_UpdateButton(id)
	return true
end
-----------------------------------------------
local function GetButtonText(self, id)

	local profprim = ""
	for i = 1, 2 do
		if profs[i] ~= nil then
		profprim = profprim .. "  |T" .. profs[i][INFOS_INDEX.ICON]..":0|t"
		profprim = profprim .. " |cFFFFFFFF" .. profs[i][INFOS_INDEX.SKILL]
		if not TitanGetVar(ID, "HideMax") then
				profprim = profprim .. "|r/|cFFFF2e2e" .. profs[i][INFOS_INDEX.MAX]
		end
		if profs[i][INFOS_INDEX.BONUS] ~= 0 then
			profprim = profprim .. "|r|cFFFFFFFF (+|r|cFF69FF69" .. profs[i][INFOS_INDEX.BONUS].."|cFFFFFFFF)|r"
		end
	end
end

	local text
	if not TitanGetVar(ID, "HideTutorial") then
		text = L["masterTutorialBar"]
	else
		text = ""
	end

	if not TitanGetVar(ID, "PrimProf") then
		return text
	else
		return profprim
	end
end
-----------------------------------------------
local function GetTooltipText(self, id)

	local topo = interp(L["masterPlayer"], { player = PLAYER_NAME }) .. "\n"

	local textoFinal = ""
	for i = 1, 6 do
		if profs[i] ~= nil then

		-- icone
		textoFinal = textoFinal .. "\n" .. "|T" .. profs[i][INFOS_INDEX.ICON]
		-- Nome da profissão
		textoFinal = textoFinal .. ":0|t" .. " |cFFFFFFFF" .. profs[i][INFOS_INDEX.NAME]
		-- Valor atual
		textoFinal = textoFinal .. "\t|cFFFFFFFF" .. profs[i][INFOS_INDEX.SKILL]
		-- Maximo
		if profs[i][INFOS_INDEX.SKILL] < 800 then
			textoFinal = textoFinal .. "|r/|cFFFF2e2e" .. profs[i][INFOS_INDEX.MAX]
		end
		-- Bonus
		if profs[i][INFOS_INDEX.BONUS] ~= 0 then
			textoFinal = textoFinal .. "|r|cFFFFFFFF +|r" .. profs[i][INFOS_INDEX.BONUS]

			-- Total (não faz sentido se não tiver bonus)
			textoFinal = textoFinal .. "|r|cFFFFFFFF" .. " (|r|cFF69FF69" .. (profs[i][INFOS_INDEX.SKILL] + profs[i][INFOS_INDEX.BONUS]) .. "|cFFFFFFFF)"
		end

		textoFinal = textoFinal .. "|r"
	end
end

	local texthint
	if TitanGetVar(ID, "HideHint") then
		texthint = ""
	else
		texthint = L["masterHint"]
	end

	local texttooltip
	if not TitanGetVar(ID, "HideTutorial") then
		texttooltip = "|cFFFFFFFF"..L["masterTutorialIntro"].."|r\r"..L["masterTutorialIntroText"].."\r\r|cFFFFFFFF"..L["masterTutorialHowTo"].."|r\r"..L["masterTutorialHowToText"]
	else
		texttooltip = texthint..topo..textoFinal
	end

	return texttooltip
end
-----------------------------------------------
function PrepareMenu(eddm, self, id)
	L.AddMenuTitle(eddm, TitanPlugins[id].menuText)

	local info = {};
	info.text = L["primprof"];
	info.func = function() TitanToggleVar(id, "PrimProf"); TitanPanelButton_UpdateButton(id); end
	info.checked = TitanGetVar(id, "PrimProf");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	local info = {};
	info.text = L["hidemax"];
	info.func = function() TitanToggleVar(id, "HideMax"); TitanPanelButton_UpdateButton(id); end
	info.checked = TitanGetVar(id, "HideMax");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	local info = {};
	info.text = ACE["TITAN_CLOCK_MENU_DISPLAY_ON_RIGHT_SIDE"];
	info.func = function() TitanToggleVar(id, "DisplayOnRightSide"); TitanPanel_InitPanelButtons(id); end
	info.checked = TitanGetVar(id, "DisplayOnRightSide");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	eddm.UIDropDownMenu_AddSpace()
	L.AddMenuTitle(eddm, L["tooltip"])

	local info = {};
	info.text = L["hideTutorial"];
	info.func = function() TitanToggleVar(id, "HideTutorial"); TitanPanelButton_UpdateButton(id); end
	info.checked = TitanGetVar(id, "HideTutorial");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	local info = {};
	info.text = L["hidehint"];
	info.func = function() TitanToggleVar(id, "HideHint"); TitanPanelButton_UpdateButton(id); end
	info.checked = TitanGetVar(id, "HideHint");
	info.keepShownOnClick = true
	eddm.UIDropDownMenu_AddButton(info);

	eddm.UIDropDownMenu_AddSpace()
	L.AddBarPositionMenu(eddm, id)
	L.AddMenuFooter(eddm, id)
end
-----------------------------------------------
local function OnClick(self, button)
	if (button == "MiddleButton") and profs[2] and profs[2][INFOS_INDEX.PROFOFFSET] then
		L.ProfessionAPI:OpenProfession({ offset = profs[2][INFOS_INDEX.PROFOFFSET] })
	end
	if (button == "LeftButton") and profs[1] and profs[1][INFOS_INDEX.PROFOFFSET] then
		L.ProfessionAPI:OpenProfession({ offset = profs[1][INFOS_INDEX.PROFOFFSET] })
	end
end
-----------------------------------------------
local coloredName = "Titan|cFFFF2E2E Master|r Multi"
local button = L.Elib({
	id = ID,
	name = coloredName,
	tooltip = "Titan|cFFFF2e2e Master|r Multi",
	icon = "Interface\\minimap\\TRACKING\\Profession.blp",
	category = "Profession",
	version = version,
	onUpdate = OnUpdate,
	onClick = OnClick,
	getButtonText = GetButtonText,
	getTooltipText = GetTooltipText,
	prepareMenu = PrepareMenu,
	savedVariables = {
		ShowIcon = 1,
		DisplayOnRightSide = false,
		HideTutorial = false,
		PrimProf = false,
		HideHint = false,
		HideMax = false,
	}
})
L.RestoreTitanMenuColor(button, coloredName .. "|r")

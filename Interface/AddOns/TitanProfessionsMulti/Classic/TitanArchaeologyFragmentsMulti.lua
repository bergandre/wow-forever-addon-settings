--[[
Description: This plugin is part of the "Titan Panel [Professions] Multi" addon. It shows your Archaeology Fragments.
Site: https://www.curseforge.com/wow/addons/titan-panel-professions-multi
Author: Canettieri
--]]

local ADDON_NAME, L = ...;
local ACE = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID,true)
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata(ADDON_NAME, "Version")
local ID = "TITAN_ARFGM"
local ICON = "Interface\\Icons\\inv_misc_shovel_01"

local name, count, maximun, required = {}, {}, {}, {}
local varName = {
	"UNUSED", -- é como está listado na API.
	"Mogu",
	"Pandaren",
	"Mantid",
	"Vrykul",
	"Troll",
	"Tolvir",
	"Orc",
	"Nerubian",
	"NightElf",
	"Fossil",
	"Draenei",
	"Dwarf",
}

local icon = {
	"|TInterface\\Icons\\trade_archaeology_vrykul_artifactfragment:0|t", -- Só placeholder.
	"|TInterface\\Icons\\trade_archaeology_vrykul_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_vrykul_artifactfragment:0|t",
	"|TInterface\\Icons\\inv_misc_archaeology_mantidstatue_01:0|t",
	"|TInterface\\Icons\\trade_archaeology_dwarf_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_vrykul_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_troll_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_titan_fragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_orc_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_nerubian_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_highborne_artifactfragment:0|t",
	"|TInterface\\Icons\\trade_archaeology_fossil_fern:0|t",
	"|TInterface\\Icons\\trade_archaeology_draenei_artifactfragment:0|t",
}

-----------------------------------------------
local function OnClick(self, button)
	if (button == "LeftButton") then
		local prof = L["archaeology"]
		CastSpellByName(prof)
	end
end

-----------------------------------------------
local function UpdateAll(self)
	for i = 2, 13 do
		local raceName, _, _, numFragmentsCollected, numFragmentsRequired, maxFragments = GetArchaeologyRaceInfo(i)
		required[i] = numFragmentsRequired
		count[i] = numFragmentsCollected
		name[i] = raceName
		maximun[i] = maxFragments
	end

	TitanPanelButton_UpdateButton(self.registry.id)
end

-----------------------------------------------
local eventsTable = {
	CURRENCY_DISPLAY_UPDATE = UpdateAll,
	--ARTIFACT_UPDATE = UpdateAll,
	PLAYER_ENTERING_WORLD = UpdateAll
}
-----------------------------------------------
local function GetButtonText(self, id)
	local finalText = ""
	for i = 2, 13 do
		local text = "|cFFf69112" .. name[i] .. ":|r " .. TitanUtils_GetHighlightText(count[i]) .. "/|cFF69FF69" .. required[i] .. "|r  "

		-- Mesmo que você não esteja com a raça na barra, o plugin mostrará quando o artefato estiver pronto para ser feito.
		if required[i] ~= 0 and count[i] >= required[i] then
			text = "|cFFf69112" .. name[i] .. ":|r " .. L["ready"]
		elseif not TitanGetVar(ID, varName[i]) then
			text = ""
		end

		finalText = finalText .. text
	end

	return L["fragments"] .. "  ", finalText
end

-----------------------------------------------
local function GetTooltipText(self, id)
	local continue = false
	for i = 2, 13 do
		if (count[i] > 0) then
			continue = true
			break
		end
	end

	if not continue then return L["noarchaeology"] end

	local finalNoTooltip = ""
	local finalTooltip = ""
	for i = 2, 13 do
		local tooltip = icon[i] .. "|cFFf69112 " .. name[i] .. ":|r\t" .. TitanUtils_GetHighlightText(count[i]) .. "/|cFF69FF69" .. required[i] .. "|r\n"
		if required[i] ~= 0 and count[i] >= required[i] then
			tooltip = icon[i] .. "|cFFFF2e2e " .. name[i] .. "!|r\t" .. TitanUtils_GetHighlightText(count[i]) .. "/|cFF69FF69" .. required[i] .. "|r\n"
		elseif count[i] == 0 and required[i] == 0 then
			tooltip = ""
		end

		finalTooltip = finalTooltip .. tooltip

		local noTooltip = "" -- Essa parte do "no" é para a lista que mostra as raças que o usuário não tem fragmento. Ela fica desativada no menu, mas o usuário pode ativar se quiser.
		if count[i] == 0 and required[i] == 0 then
			noTooltip = icon[i] .. "|cFFf69112 " .. name[i] .. "\n"
		end

		finalNoTooltip = finalNoTooltip .. noTooltip
	end

	local Hint = L["fragtooltip"] -- Para o usuário esconder a dica.
	if TitanGetVar(ID, "HideHint") then
		Hint = "                                             " -- Esse espaço é para o tolltip não ficar muito justo.
	end

	local NoFragToggle = "" -- Aqui o toggle do "no" para o usuário ver no tooltip quais raças está sem artefato.
	if TitanGetVar(ID, "DisplayNoFrag") then
		NoFragToggle = "\r" .. L["nofragments"] .. ":\n" .. finalNoTooltip
	end

	return Hint .. L["inprog"] .. "\n" .. finalTooltip .. NoFragToggle
end

-----------------------------------------------
function PrepareMenu(eddm, self, id)
	L.AddMenuTitle(eddm, TitanPlugins[id].menuText)

	local continue = false
	for i = 2, 13 do
		if (count[i] > 0) then
			continue = true
			break
		end
	end

	if continue then
		L.AddMenuTitle(eddm, L["buttonText"])

		local info = {};
		info.text = L["hidehint"];
		info.func = function() TitanToggleVar(id, "HideHint"); TitanPanelButton_UpdateButton(id); end
		info.checked = TitanGetVar(id, "HideHint");
		info.keepShownOnClick = true
		eddm.UIDropDownMenu_AddButton(info);

		local info = {};
		info.text = L["displaynofrag"];
		info.func = function() TitanToggleVar(id, "DisplayNoFrag"); TitanPanelButton_UpdateButton(id); end
		info.checked = TitanGetVar(id, "DisplayNoFrag");
		info.keepShownOnClick = true
		eddm.UIDropDownMenu_AddButton(info);

		eddm.UIDropDownMenu_AddSpace()
		L.AddMenuTitle(eddm, L["archfragments"])

		for i = 2, 13 do
			local info = {};
			info.text = name[i];
			info.func = function() TitanToggleVar(id, varName[i]); TitanPanelButton_UpdateButton(id); end
			info.checked = TitanGetVar(id, varName[i]);
			info.keepShownOnClick = true
			eddm.UIDropDownMenu_AddButton(info);
		end

		eddm.UIDropDownMenu_AddSpace()
	end

	L.AddBarPositionMenu(eddm, id)
	L.AddMenuFooter(eddm, id)
end
-----------------------------------------------
local coloredName = "Titan|c" .. L.ProfessionMenuColor .. " " .. L["archaeology"]
	.. "|r [|c" .. L.ProfessionMenuColor .. L["fragments"] .. "|r] Multi"
local button = L.Elib({
	id = ID,
	name = coloredName,
	tooltip = L["fragments"],
	icon = ICON,
	category = "Profession",
	version = version,
	onClick = OnClick,
	getButtonText = GetButtonText,
	getTooltipText = GetTooltipText,
	eventsTable = eventsTable,
	prepareMenu = PrepareMenu,
	savedVariables = {
		ShowIcon = 1,
		ShowLabelText = true,
		HideHint = false,
		DisplayNoFrag = false,
		Dwarf = false,
		Draenei = false,
		Fossil = false,
		NightElf = false,
		Nerubian = false,
		Orc = false,
		Troll = false,
		Vrykul = false,
	}
})
L.RestoreTitanMenuColor(button, coloredName .. "|r")

-- ******************************** Constants *******************************
-- Setup the name we want in the global namespace
TitanRestPlus = {}

-- Reduce the chance of functions and variables colliding with another addon.
local TRP = TitanRestPlus
local L = LibStub("AceLocale-3.0"):GetLocale("Titan", true)

TRP.id = "RestPlus";
TRP.addon = "TitanRestPlus";

-- These strings will be used for display. Localized strings are outside the scope of this example.
TRP.button_label = TRP.id..": "
TRP.menu_text = TRP.id
TRP.tooltip_header = TRP.id.." Info"
TRP.menu_coption = "Color Options"
TRP.menu_option = "Options"
TRP.menu_CMaxLevel = "Max Level Color"
TRP.menu_CNormal = "Normal XP Color"
TRP.menu_CLevel = "Next Level Color"
TRP.menu_CCapped = "Rest Capped Color"
TRP.menu_CActServ = "Active Server Color"
TRP.menu_COthServ = "Other Server Color"
TRP.menu_ColorReset = "Reset Colors"

TRP.version = tostring(C_AddOns.GetAddOnMetadata(TRP.addon, "Version")) or "Unknown" 
TRP.author = C_AddOns.GetAddOnMetadata(TRP.addon, "Author") or "Unknown"

RPDEBUG = false;

RESTPLUS_SOUND_LEVEL = "LEVELUPSOUND"; -- Sound to play when CurrentXP + RestPlus >= NextXP
RESTPLUS_SOUND_CAPPED = "QUESTADDED"; -- Sound to play when RestPlus reaches the character's rested XP cap

RESTPLUS_DELAY = 1800; -- check every 30 min
RESTPLUS_COLOR = "magenta";

RESTPLUS_ALERTSTATUS_NORMAL = 0;
RESTPLUS_ALERTSTATUS_LEVEL = 1;
RESTPLUS_ALERTSTATUS_CAPPED = 2;

-- This will be used to store the final result of information processing and sorting.
RestPlus_ToPrint = {};
RestPlus_ToPrintIndex = 0;
RestPlus_ToPrintColor = {};
RestPlus_ActiveCharXP = "";
RestPlus_ActiveCharXPRaw = "";
RestPlus_ActiveCharColor = "";
RestPlus_ActiveCharIndex = "";
RestPlus_RealmList = {};

TITAN_RESTPLUS_ACTIVE_FORMAT = "%s";
TITAN_RESTPLUS_FREQUENCY = 5;
TITAN_RESTPLUS_ICON = "Interface\\Icons\\Spell_Holy_BlessingOfStamina";

local u = {};
local RestTimer = 0;
local ShowActiveChar = true;

-- WoW Forever's Legacy talents use the modern trait system, not the old
-- GetTalentInfo/GetNumTalentTabs API. Walk available trait configs and trees,
-- resolve each node's entry/definition name, and read the allocated rank.
local function RestPlus_TraitEntryName(configID, entryID)
    if not (C_Traits and C_Traits.GetEntryInfo) then return nil end
    local ok, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
    if not ok or not entryInfo then return nil end
    if entryInfo.name and string.lower(entryInfo.name) == "well rested" then return entryInfo.name end
    local definitionID = entryInfo.definitionID
    if not definitionID or not C_Traits.GetDefinitionInfo then return nil end
    local okDef, defInfo = pcall(C_Traits.GetDefinitionInfo, definitionID)
    if not okDef or not defInfo then return nil end
    local name = defInfo.overrideName
    if (not name or name == "") and defInfo.spellID and C_Spell then
        if C_Spell.GetSpellName then
            local okName, spellName = pcall(C_Spell.GetSpellName, defInfo.spellID)
            if okName then name = spellName end
        elseif C_Spell.GetSpellInfo then
            local okInfo, spellInfo = pcall(C_Spell.GetSpellInfo, defInfo.spellID)
            if okInfo and type(spellInfo) == "table" then name = spellInfo.name end
        end
    end
    return name
end

local function RestPlus_GetLegacyWellRestedRank()
    if not (C_Traits and C_Traits.GetNodeInfo and C_Traits.GetTreeNodes and C_Traits.GetConfigInfo) then return nil end

    local configIDs, seen = {}, {}
    local function addConfigs(ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if type(id) == "number" and not seen[id] then
                    seen[id] = true
                    table.insert(configIDs, id)
                end
            end
        end
    end

    -- Config type enums have varied between builds; try the known Legacy type
    -- first, then other values, and also include the active class config.
    if C_Traits.GetConfigsByType then
        for _, configType in ipairs({3, 4, 2, 1, 5}) do
            local ok, ids = pcall(C_Traits.GetConfigsByType, configType)
            if ok then addConfigs(ids) end
        end
    end
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        if ok and type(id) == "number" and not seen[id] then
            seen[id] = true
            table.insert(configIDs, id)
        end
    end

    local foundRank = nil
    for _, configID in ipairs(configIDs) do
        local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, configID)
        if okConfig and type(configInfo) == "table" and type(configInfo.treeIDs) == "table" then
            for _, treeID in ipairs(configInfo.treeIDs) do
                local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
                if okNodes and type(nodeIDs) == "table" then
                    for _, nodeID in ipairs(nodeIDs) do
                        local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                        if okNode and type(nodeInfo) == "table" then
                            local entryIDs = nodeInfo.entryIDs or {}
                            if nodeInfo.activeEntry and nodeInfo.activeEntry.entryID then
                                table.insert(entryIDs, nodeInfo.activeEntry.entryID)
                            end
                            local isWellRested = false
                            for _, entryID in ipairs(entryIDs) do
                                local name = RestPlus_TraitEntryName(configID, entryID)
                                if name and string.lower(name) == "well rested" then
                                    isWellRested = true
                                    break
                                end
                            end
                            if isWellRested then
                                local rank = tonumber(nodeInfo.currentRank or nodeInfo.activeRank)
                                if rank == nil and nodeInfo.activeEntry then
                                    rank = tonumber(nodeInfo.activeEntry.rank)
                                end
                                if rank ~= nil then
                                    foundRank = math.max(0, math.min(5, rank))
                                    if foundRank > 0 then return foundRank end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return foundRank
end

local function RestPlus_GetTalentRankByName()
    -- Forever builds use C_Traits for both class and Legacy talent trees.
    local rank = RestPlus_GetLegacyWellRestedRank()
    if rank ~= nil then return rank end
    -- Keep compatibility with any build that still exposes the old talent API.
    if type(GetNumTalentTabs) == "function" and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
        local tabs = GetNumTalentTabs() or 0
        for tab = 1, tabs do
            local talents = GetNumTalents(tab) or 0
            for index = 1, talents do
                local name, _, _, _, oldRank = GetTalentInfo(tab, index)
                if name and string.lower(name) == "well rested" then return tonumber(oldRank) or 0 end
            end
        end
    end
    return nil
end

function RestPlus_GetWellRestedRank()
    local detected = RestPlus_GetTalentRankByName()
    if detected ~= nil then return math.max(0, math.min(5, detected)) end
    local index = UnitName("player").."="..GetRealmName()
    local data = RestPlus_Data and RestPlus_Data[index]
    return math.max(0, math.min(5, tonumber(data and data.wellRestedRank) or 0))
end

function RestPlus_RestRateMultiplier(data)
    local rank = tonumber(data and data.wellRestedRank) or 0
    rank = math.max(0, math.min(5, rank))
    return 1 + rank * 0.04
end

-- Standard rested XP cap is 150% of the next level's XP.
-- Each Well Rested Legacy rank adds another 4 percentage points,
-- up to 170% at rank 5.
function RestPlus_RestCapMultiplier(data)
    local rank = tonumber(data and data.wellRestedRank) or 0
    rank = math.max(0, math.min(5, rank))
    return 1.5 + rank * 0.04
end

function RestPlus_OnLoad(self)
	u = Utility_Class:New();
	-- @@ Changed this to self @@ Vogonjeltz
	self:RegisterEvent("PLAYER_UPDATE_RESTING");
	self:RegisterEvent("PLAYER_XP_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");

	SlashCmdList["RestPlus"] = function(msg)
		RestPlus_Command(msg);
	end
	SLASH_RestPlus1 = "/restplus";
	
	--print("max level color before load data = ", RESTPLUS_COLOR_MAXLEVEL);
	
	SlashCmdList["RestLog"] = RestPlus_Logout;
	SLASH_RestLog1 = "/log";

	RestPlus_LoadData();
	RestPlus_LoadCData();
	
	RESTPLUS_COLOR_MAXLEVEL = RestPlus_Colors.CMaxLevel;
	--print("RestPlus Color MaxLevel after LoadData = ", RESTPLUS_COLOR_MAXLEVEL);
	RESTPLUS_COLOR_NORMAL = RestPlus_Colors.CNormal;
	RESTPLUS_COLOR_LEVEL = RestPlus_Colors.CLevel;
	RESTPLUS_COLOR_CAPPED = RestPlus_Colors.CCapped;
	RESTPLUS_COLOR_ACTIVESERVER = RestPlus_Colors.CActServ;
	RESTPLUS_COLOR_OTHERSERVER = RestPlus_Colors.COthServ;
	
--	if GetAccountExpansionLevel() == 7 then EXPAN_MAXLEVEL = 120
--        elseif GetAccountExpansionLevel() == 6 then EXPAN_MAXLEVEL = 110	
--        elseif GetAccountExpansionLevel() == 5 then EXPAN_MAXLEVEL = 100
--        elseif GetAccountExpansionLevel() == 4 then EXPAN_MAXLEVEL = 90
--		elseif GetAccountExpansionLevel() == 3 then EXPAN_MAXLEVEL = 85
--		elseif GetAccountExpansionLevel() == 2 then EXPAN_MAXLEVEL = 80
--		elseif GetAccountExpansionLevel() == 1 then EXPAN_MAXLEVEL = 70
--        elseif GetAccountExpansionLevel() == 0 then EXPAN_MAXLEVEL = 60
--	end
	EXPAN_MAXLEVEL = 60
	
	--u:Print(RESTPLUS_LOADED, RESTPLUS_COLOR);
	--Print(TITAN_RESTPLUS_CBLUE, "-Blue");
	--DEFAULT_CHAT_FRAME:AddMessage(TITAN_RESTPLUS_CBLUE);
	--DEFAULT_CHAT_FRAME:AddMessage("^^Color");
end

-- **************************************************************************
-- NAME : TitanPanelRestPlusButton_OnLoad()
-- DESC : Registers the plugin upon it loading
-- **************************************************************************

function TitanPanelRestPlusButton_OnLoad(self)
	self.registry = { 
		id = TRP.id,
		version = TRP.version,
		menuText = TRP.menu_text,
		category = "Information",
		buttonTextFunction = "TitanPanelRestPlusButton_GetButtonText", 
		tooltipTitle = TRP.tooltip_header,
		tooltipTextFunction = "TitanPanelRestPlusButton_GetTooltipText",
		icon = TITAN_RESTPLUS_ICON,
		iconWidth = 16,
		savedVariables = {
			ShowLabelText = 1,
			ShowIcon = 1,
			ShowColoredText = 1,
		}
	};
	--print ("Button On Load, max level color = ", RESTPLUS_COLOR_MAXLEVEL)
	self:RegisterEvent("PLAYER_UPDATE_RESTING");
	self:RegisterEvent("PLAYER_XP_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	-- shamelessly print a load message to chat window
	DEFAULT_CHAT_FRAME:AddMessage(
		GREEN_FONT_COLOR_CODE
		..TRP.addon.." "..TRP.version
		.." by "
		..FONT_COLOR_CODE_CLOSE
		.."|cFFFFFF00"..TRP.author..FONT_COLOR_CODE_CLOSE);
	
	-- u = Utility_Class:New();
end

function TitanPanelRestPlusButton_OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_UPDATE_RESTING"
        or event == "PLAYER_XP_UPDATE"
        or event == "PLAYER_REGEN_ENABLED" then
        RestPlus_SaveCharacter()
        TitanPanelButton_UpdateButton(TRP.id)
    end
end

function TitanPanelRestPlusButton_GetButtonText(id)
	local button, id = TitanUtils_GetButton(id, true);
	local playerLevel = UnitLevel("player");
	RestPlus_SaveCharacter();
	RestPlus_Sort();
		
	local activeText = "";
	if(RestPlus_Settings.PctActive) then
		activeText = format(TITAN_RESTPLUS_ACTIVE_FORMAT, RestPlus_ActiveCharXP);
	else
		activeText = format(TITAN_RESTPLUS_ACTIVE_FORMAT, RestPlus_ActiveCharXPRaw);
	end
	if (playerLevel and playerLevel < EXPAN_MAXLEVEL) then -- EMERALD
		return TITAN_RESTPLUS_BUTTON_LABEL, TitanUtils_GetColoredText(activeText, u.ColorList[string.lower(RestPlus_ActiveCharColor)]);
	else
		return TITAN_RESTPLUS_BUTTON_LABEL, TitanUtils_GetColoredText("Rest+", u.ColorList["yellow"]);
	end
end

function TitanPanelRestPlusButton_GetTooltipText()

	local i;
	local value = "";
	local thisRealm = "";
	local thisColor = {};
	
	RESTPLUS_COLOR_MAXLEVEL = RestPlus_Colors.CMaxLevel;
	---print("RestPlus Color MaxLevel after LoadData = ", RESTPLUS_COLOR_MAXLEVEL);
	RESTPLUS_COLOR_NORMAL = RestPlus_Colors.CNormal;
	RESTPLUS_COLOR_LEVEL = RestPlus_Colors.CLevel;
	RESTPLUS_COLOR_CAPPED = RestPlus_Colors.CCapped;
	RESTPLUS_COLOR_ACTIVESERVER = RestPlus_Colors.CActServ;
	RESTPLUS_COLOR_OTHERSERVER = RestPlus_Colors.COthServ;
	
	RestPlus_SaveCharacter();
	RestPlus_Sort();
	
	for i = 0, RestPlus_ToPrintIndex - 1 do
		if (strfind(RestPlus_ToPrint[i],"\t")) then -- CHARACTER
			local first = strsub(RestPlus_ToPrint[i], 1, strfind(RestPlus_ToPrint[i], "\t", 1) - 1);
			local last = strsub(RestPlus_ToPrint[i], strfind(RestPlus_ToPrint[i], "\t", 1) + 1);
			--value = value..TitanUtils_GetColoredText(first, u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\t"..TitanUtils_GetColoredText(last, u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\n";
			if (RestPlus_Settings.ShowRealms) then
				value = value..thisRealm..TitanUtils_GetColoredText(first, u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\t"..TitanUtils_GetColoredText(last, u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\n";
				--print("Get text to print color = ", RestPlus_ToPrintColor[i]);
			else
				value = value..TitanUtils_GetColoredText(first, u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\t"..TitanUtils_GetColoredText(last, u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\n";
			end
		else -- REALM
			--value = value..TitanUtils_GetColoredText("Realm: ", u.ColorList[string.lower("white")]).."\t"..TitanUtils_GetColoredText(RestPlus_ToPrint[i], u.ColorList[string.lower(RestPlus_ToPrintColor[i])]).."\n";
			thisRealm = RestPlus_ToPrint[i]..": "; -- Only store this, to use inline with the characters.
			
			if (string.lower(RestPlus_ToPrintColor[i])=="grey") then
				thisColor = { r = 0.6, g = 0.6, b = 0.6 };
			elseif (string.lower(RestPlus_ToPrintColor[i])=="offwhite") then
				thisColor = { r = 0.85, g = 0.85, b = 0.85 };
			else
				thisColor = u.ColorList[string.lower(RestPlus_ToPrintColor[i])];
			end
			thisRealm = TitanUtils_GetColoredText(thisRealm, thisColor);
		end
	end
	
	return value;	
end

-- ***********************************************************************
-- ***** Begin Right-Click Menu *****
-- ***********************************************************************

function TitanPanelRightClickMenu_PrepareRestPlusMenu()
	local info;
		
	if UIDROPDOWNMENU_MENU_LEVEL == 3 then
		if UIDROPDOWNMENU_MENU_VALUE == "Max Level Color" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_CMaxLevel, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_CBLUE;
			info.colorCode = "|c000000FF";
			info.func = TitanPanelRestPlusButton_ColorMaxBlue;
			info.checked = TitanPanelRestPlusButton_CheckMaxBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CCYAN;
			info.colorCode = "|c0000FFFF";
			info.func = TitanPanelRestPlusButton_ColorMaxCyan;
			info.checked = TitanPanelRestPlusButton_CheckMaxCyan;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CFGREEN;
			info.colorCode = "|c00228B22";  -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
			info.func = TitanPanelRestPlusButton_ColorMaxFgreen;
			info.checked = TitanPanelRestPlusButton_CheckMaxFgreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CGREEN;
			info.colorCode = "|c0000FF00";
			info.func = TitanPanelRestPlusButton_ColorMaxGreen;
			info.checked = TitanPanelRestPlusButton_CheckMaxGreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CGREY;
			info.colorCode = "|c00C1C1C1";
			info.func = TitanPanelRestPlusButton_ColorMaxGrey;
			info.checked = TitanPanelRestPlusButton_CheckMaxGrey;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CKHAKI;
			info.colorCode = "|c00BDB76B";
			info.func = TitanPanelRestPlusButton_ColorMaxKhaki;
			info.checked = TitanPanelRestPlusButton_CheckMaxKhaki;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CLOlive;
			info.colorCode = "|c00CAFF70";
			info.func = TitanPanelRestPlusButton_ColorMaxLolive;
			info.checked = TitanPanelRestPlusButton_CheckMaxLolive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CMAGENTA;
			info.colorCode = "|c00FF00FF";
			info.func = TitanPanelRestPlusButton_ColorMaxMagenta;
			info.checked = TitanPanelRestPlusButton_CheckMaxMagenta;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COWHITE;
			info.colorCode = "|c00EAEAEA";
			info.func = TitanPanelRestPlusButton_ColorMaxOwhite;
			info.checked = TitanPanelRestPlusButton_CheckMaxOwhite;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COLIVE;
			info.colorCode = "|c00808000";
			info.func = TitanPanelRestPlusButton_ColorMaxOlive;
			info.checked = TitanPanelRestPlusButton_CheckMaxOlive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CORANGE;
			info.colorCode = "|c00FF9900";
			info.func = TitanPanelRestPlusButton_ColorMaxOrange;
			info.checked = TitanPanelRestPlusButton_CheckMaxOrange;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CPURPLE;
			info.colorCode = "|c008B008B";
			info.func = TitanPanelRestPlusButton_ColorMaxPurple;
			info.checked = TitanPanelRestPlusButton_CheckMaxPurple;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CRED;
			info.colorCode = "|c00FF0000";
			info.func = TitanPanelRestPlusButton_ColorMaxRed;
			info.checked = TitanPanelRestPlusButton_CheckMaxRed;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSALMON;
			info.colorCode = "|c00FFA07A";
			info.func = TitanPanelRestPlusButton_ColorMaxSalmon;
			info.checked = TitanPanelRestPlusButton_CheckMaxSalmon;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CSBLUE;
			info.colorCode = "|c0000BFFF";
			info.func = TitanPanelRestPlusButton_ColorMaxSblue;
			info.checked = TitanPanelRestPlusButton_CheckMaxSblue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {}
			info.text = TITAN_RESTPLUS_CYELLOW;
			info.colorCode = "|c00FFFF00";
			info.func = TitanPanelRestPlusButton_ColorMaxYellow;
			info.checked = TitanPanelRestPlusButton_CheckMaxYellow;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			return
		end
		if UIDROPDOWNMENU_MENU_VALUE == "Normal XP Color" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_CNormal, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_CBLUE;
			info.colorCode = "|c000000FF";
			info.func = TitanPanelRestPlusButton_ColorNormBlue;
			info.checked = TitanPanelRestPlusButton_CheckNormBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CCYAN;
			info.colorCode = "|c0000FFFF";
			info.func = TitanPanelRestPlusButton_ColorNormCyan;
			info.checked = TitanPanelRestPlusButton_CheckNormCyan;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CFGREEN;
			info.colorCode = "|c00228B22";  -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
			info.func = TitanPanelRestPlusButton_ColorNormFgreen;
			info.checked = TitanPanelRestPlusButton_CheckNormFgreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CGREEN;
			info.colorCode = "|c0000FF00";
			info.func = TitanPanelRestPlusButton_ColorNormGreen;
			info.checked = TitanPanelRestPlusButton_CheckNormGreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CGREY;
			info.colorCode = "|c00C1C1C1";
			info.func = TitanPanelRestPlusButton_ColorNormGrey;
			info.checked = TitanPanelRestPlusButton_CheckNormGrey;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CKHAKI;
			info.colorCode = "|c00BDB76B";
			info.func = TitanPanelRestPlusButton_ColorNormKhaki;
			info.checked = TitanPanelRestPlusButton_CheckNormKhaki;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CLOlive;
			info.colorCode = "|c00CAFF70";
			info.func = TitanPanelRestPlusButton_ColorNormLolive;
			info.checked = TitanPanelRestPlusButton_CheckNormLolive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CORANGE;
			info.colorCode = "|c00FF9900";
			info.func = TitanPanelRestPlusButton_ColorNormOrange;
			info.checked = TitanPanelRestPlusButton_CheckNormOrange;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CMAGENTA;
			info.colorCode = "|c00FF00FF";
			info.func = TitanPanelRestPlusButton_ColorNormMagenta;
			info.checked = TitanPanelRestPlusButton_CheckNormMagenta;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COWHITE;
			info.colorCode = "|c00EAEAEA";
			info.func = TitanPanelRestPlusButton_ColorNormOwhite;
			info.checked = TitanPanelRestPlusButton_CheckNormOwhite;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COLIVE;
			info.colorCode = "|c00808000";
			info.func = TitanPanelRestPlusButton_ColorNormOlive;
			info.checked = TitanPanelRestPlusButton_CheckNormOlive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CPURPLE;
			info.colorCode = "|c008B008B";
			info.func = TitanPanelRestPlusButton_ColorNormPurple;
			info.checked = TitanPanelRestPlusButton_CheckNormPurple;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CRED;
			info.colorCode = "|c00FF0000";
			info.func = TitanPanelRestPlusButton_ColorNormRed;
			info.checked = TitanPanelRestPlusButton_CheckNormRed;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSALMON;
			info.colorCode = "|c00FFA07A";
			info.func = TitanPanelRestPlusButton_ColorNormSalmon;
			info.checked = TitanPanelRestPlusButton_CheckNormSalmon;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSBLUE;
			info.colorCode = "|c0000BFFF";
			info.func = TitanPanelRestPlusButton_ColorNormSblue;
			info.checked = TitanPanelRestPlusButton_CheckNormSblue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CYELLOW;
			info.colorCode = "|c00FFFF00";
			info.func = TitanPanelRestPlusButton_ColorNormYellow;
			info.checked = TitanPanelRestPlusButton_CheckNormYellow;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			return
		end
		if UIDROPDOWNMENU_MENU_VALUE == "Next Level Color" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_CLevel, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_CBLUE;
			info.colorCode = "|c000000FF";
			info.func = TitanPanelRestPlusButton_ColorLevelBlue;
			info.checked = TitanPanelRestPlusButton_CheckLevelBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CCYAN;
			info.colorCode = "|c0000FFFF";
			info.func = TitanPanelRestPlusButton_ColorLevelCyan;
			info.checked = TitanPanelRestPlusButton_CheckLevelCyan;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CFGREEN;
			info.colorCode = "|c00228B22";  -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
			info.func = TitanPanelRestPlusButton_ColorLevelFgreen;
			info.checked = TitanPanelRestPlusButton_CheckLevelFgreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CGREEN;
			info.colorCode = "|c0000FF00";
			info.func = TitanPanelRestPlusButton_ColorLevelGreen;
			info.checked = TitanPanelRestPlusButton_CheckLevelGreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CGREY;
			info.colorCode = "|c00C1C1C1";
			info.func = TitanPanelRestPlusButton_ColorLevelGrey;
			info.checked = TitanPanelRestPlusButton_CheckLevelGrey;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CKHAKI;
			info.colorCode = "|c00BDB76B";
			info.func = TitanPanelRestPlusButton_ColorLevelKhaki;
			info.checked = TitanPanelRestPlusButton_CheckLevelKhaki;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CLOlive;
			info.colorCode = "|c00CAFF70";
			info.func = TitanPanelRestPlusButton_ColorLevelLolive;
			info.checked = TitanPanelRestPlusButton_CheckLevelLolive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CMAGENTA;
			info.colorCode = "|c00FF00FF";
			info.func = TitanPanelRestPlusButton_ColorLevelMagenta;
			info.checked = TitanPanelRestPlusButton_CheckLevelMagenta;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COWHITE;
			info.colorCode = "|c00EAEAEA";
			info.func = TitanPanelRestPlusButton_ColorLevelOwhite;
			info.checked = TitanPanelRestPlusButton_CheckLevelOwhite;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COLIVE;
			info.colorCode = "|c00808000";
			info.func = TitanPanelRestPlusButton_ColorLevelOlive;
			info.checked = TitanPanelRestPlusButton_CheckLevelOlive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CORANGE;
			info.colorCode = "|c00FF9900";
			info.func = TitanPanelRestPlusButton_ColorLevelOrange;
			info.checked = TitanPanelRestPlusButton_CheckLevelOrange;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CPURPLE;
			info.colorCode = "|c008B008B";
			info.func = TitanPanelRestPlusButton_ColorLevelPurple;
			info.checked = TitanPanelRestPlusButton_CheckLevelPurple;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CRED;
			info.colorCode = "|c00FF0000";
			info.func = TitanPanelRestPlusButton_ColorLevelRed;
			info.checked = TitanPanelRestPlusButton_CheckLevelRed;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSALMON;
			info.colorCode = "|c00FFA07A";
			info.func = TitanPanelRestPlusButton_ColorLevelSalmon;
			info.checked = TitanPanelRestPlusButton_CheckLevelSalmon;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSBLUE;
			info.colorCode = "|c0000BFF";
			info.func = TitanPanelRestPlusButton_ColorLevelSblue;
			info.checked = TitanPanelRestPlusButton_CheckLevelSblue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CYELLOW;
			info.colorCode = "|c00FFFF00";
			info.func = TitanPanelRestPlusButton_ColorLevelYellow;
			info.checked = TitanPanelRestPlusButton_CheckLevelYellow;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			return
		end
		if UIDROPDOWNMENU_MENU_VALUE == "Rest Capped Color" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_CCapped, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_CBLUE;
			info.colorCode = "|c000000FF";
			info.func = TitanPanelRestPlusButton_ColorCapBlue;
			info.checked = TitanPanelRestPlusButton_CheckCapBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CCYAN;
			info.colorCode = "|c0000FFFF";
			info.func = TitanPanelRestPlusButton_ColorCapCyan;
			info.checked = TitanPanelRestPlusButton_CheckCapCyan;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CFGREEN;
			info.colorCode = "|c00228B22";  -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
			info.func = TitanPanelRestPlusButton_ColorCapFgreen;
			info.checked = TitanPanelRestPlusButton_CheckCapFgreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CGREEN;
			info.colorCode = "|c0000FF00";
			info.func = TitanPanelRestPlusButton_ColorCapGreen;
			info.checked = TitanPanelRestPlusButton_CheckCapGreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CGREY;
			info.colorCode = "|c00C1C1C1";
			info.func = TitanPanelRestPlusButton_ColorCapGrey;
			info.checked = TitanPanelRestPlusButton_CheckCapGrey;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CKHAKI;
			info.colorCode = "|c00BDB76B";
			info.func = TitanPanelRestPlusButton_ColorCapKhaki;
			info.checked = TitanPanelRestPlusButton_CheckCapKhaki;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CLOlive;
			info.colorCode = "|c00CAFF70";
			info.func = TitanPanelRestPlusButton_ColorCapLolive;
			info.checked = TitanPanelRestPlusButton_CheckCapLolive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CMAGENTA;
			info.colorCode = "|c00FF00FF";
			info.func = TitanPanelRestPlusButton_ColorCapMagenta;
			info.checked = TitanPanelRestPlusButton_CheckCapMagenta;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COWHITE;
			info.colorCode = "|c00EAEAEA";
			info.func = TitanPanelRestPlusButton_ColorCapOwhite;
			info.checked = TitanPanelRestPlusButton_CheckCapOwhite;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COLIVE;
			info.colorCode = "|c00808000";
			info.func = TitanPanelRestPlusButton_ColorCapOlive;
			info.checked = TitanPanelRestPlusButton_CheckCapOlive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CORANGE;
			info.colorCode = "|c00FF9900";
			info.func = TitanPanelRestPlusButton_ColorCapOrange;
			info.checked = TitanPanelRestPlusButton_CheckCapOrange;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CPURPLE;
			info.colorCode = "|c008B008B";
			info.func = TitanPanelRestPlusButton_ColorCapPurple;
			info.checked = TitanPanelRestPlusButton_CheckCapPurple;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CRED;
			info.colorCode = "|c00FF0000";
			info.func = TitanPanelRestPlusButton_ColorCapRed;
			info.checked = TitanPanelRestPlusButton_CheckCapRed;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSALMON;
			info.colorCode = "|c00FFA07A";
			info.func = TitanPanelRestPlusButton_ColorCapSalmon;
			info.checked = TitanPanelRestPlusButton_CheckCapSalmon;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSBLUE;
			info.colorCode = "|c0000BFFF";
			info.func = TitanPanelRestPlusButton_ColorCapSblue;
			info.checked = TitanPanelRestPlusButton_CheckCapSblue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CYELLOW;
			info.colorCode = "|c00FFFF00";
			info.func = TitanPanelRestPlusButton_ColorCapYellow;
			info.checked = TitanPanelRestPlusButton_CheckCapYellow;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			return
		end
		if UIDROPDOWNMENU_MENU_VALUE == "Active Server Color" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_CActServ, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_CBLUE;
			info.colorCode = "|c000000FF";
			info.func = TitanPanelRestPlusButton_ColorAsBlue;
			info.checked = TitanPanelRestPlusButton_CheckAsBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CCYAN;
			info.colorCode = "|c0000FFFF";
			info.func = TitanPanelRestPlusButton_ColorAsCyan;
			info.checked = TitanPanelRestPlusButton_CheckAsCyan;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CFGREEN;
			info.colorCode = "|c00228B22";  -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
			info.func = TitanPanelRestPlusButton_ColorAsFgreen;
			info.checked = TitanPanelRestPlusButton_CheckAsFgreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CGREEN;
			info.colorCode = "|c0000FF00";
			info.func = TitanPanelRestPlusButton_ColorAsGreen;
			info.checked = TitanPanelRestPlusButton_CheckASGreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CGREY;
			info.colorCode = "|c00C1C1C1";
			info.func = TitanPanelRestPlusButton_ColorAsGrey;
			info.checked = TitanPanelRestPlusButton_CheckAsGrey;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CKHAKI;
			info.colorCode = "|c00BDB76B";
			info.func = TitanPanelRestPlusButton_ColorAsKhaki;
			info.checked = TitanPanelRestPlusButton_CheckAsKhaki;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CLOlive;
			info.colorCode = "|c00CAFF70";
			info.func = TitanPanelRestPlusButton_ColorAsLolive;
			info.checked = TitanPanelRestPlusButton_CheckAsLolive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CMAGENTA;
			info.colorCode = "|c00FF00FF";
			info.func = TitanPanelRestPlusButton_ColorAsMagenta;
			info.checked = TitanPanelRestPlusButton_CheckAsMagenta;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COWHITE;
			info.colorCode = "|c00EAEAEA";
			info.func = TitanPanelRestPlusButton_ColorAsOwhite;
			info.checked = TitanPanelRestPlusButton_CheckAsOwhite;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COLIVE;
			info.colorCode = "|c00808000";
			info.func = TitanPanelRestPlusButton_ColorAsOlive;
			info.checked = TitanPanelRestPlusButton_CheckAsOlive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CORANGE;
			info.colorCode = "|c00FF9900";
			info.func = TitanPanelRestPlusButton_ColorAsOrange;
			info.checked = TitanPanelRestPlusButton_CheckAsOrange;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CPURPLE;
			info.colorCode = "|c008B008B";
			info.func = TitanPanelRestPlusButton_ColorAsPurple;
			info.checked = TitanPanelRestPlusButton_CheckAsPurple;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CRED;
			info.colorCode = "|c00FF0000";
			info.func = TitanPanelRestPlusButton_ColorAsRed;
			info.checked = TitanPanelRestPlusButton_CheckAsRed;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSALMON;
			info.colorCode = "|c00FFA07A";
			info.func = TitanPanelRestPlusButton_ColorAsSalmon;
			info.checked = TitanPanelRestPlusButton_CheckAsSalmon;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSBLUE;
			info.colorCode = "|c0000BFFF";
			info.func = TitanPanelRestPlusButton_ColorAsSblue;
			info.checked = TitanPanelRestPlusButton_CheckAsSblue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CYELLOW;
			info.colorCode = "|c00FFFF00";
			info.func = TitanPanelRestPlusButton_ColorAsYellow;
			info.checked = TitanPanelRestPlusButton_CheckAsYellow;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			return
		end
		if UIDROPDOWNMENU_MENU_VALUE == "Other Server Color" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_COthServ, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_CBLUE;
			info.colorCode = "|c000000FF";
			info.func = TitanPanelRestPlusButton_ColorOsBlue;
			info.checked = TitanPanelRestPlusButton_CheckOsBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CCYAN;
			info.colorCode = "|c0000FFFF";
			info.func = TitanPanelRestPlusButton_ColorOsCyan;
			info.checked = TitanPanelRestPlusButton_CheckOsCyan;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_CFGREEN;
			info.colorCode = "|c00228B22";  -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
			info.func = TitanPanelRestPlusButton_ColorOsFgreen;
			info.checked = TitanPanelRestPlusButton_CheckOsFgreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TITAN_RESTPLUS_CGREEN;
			info.colorCode = "|c0000FF00";
			info.func = TitanPanelRestPlusButton_ColorOsGreen;
			info.checked = TitanPanelRestPlusButton_CheckOSGreen;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CGREY;
			info.colorCode = "|c00C1C1C1";
			info.func = TitanPanelRestPlusButton_ColorOsGrey;
			info.checked = TitanPanelRestPlusButton_CheckOsGrey;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CKHAKI;
			info.colorCode = "|c00BDB76B";
			info.func = TitanPanelRestPlusButton_ColorOsKhaki;
			info.checked = TitanPanelRestPlusButton_CheckOsKhaki;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CLOlive;
			info.colorCode = "|c00CAFF70";
			info.func = TitanPanelRestPlusButton_ColorOsLolive;
			info.checked = TitanPanelRestPlusButton_CheckOsLolive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CMAGENTA;
			info.colorCode = "|c00FF00FF";
			info.func = TitanPanelRestPlusButton_ColorOsMagenta;
			info.checked = TitanPanelRestPlusButton_CheckOsMagenta;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COWHITE;
			info.colorCode = "|c00EAEAEA";
			info.func = TitanPanelRestPlusButton_ColorOsOwhite;
			info.checked = TitanPanelRestPlusButton_CheckOsOwhite;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_COLIVE;
			info.colorCode = "|c00808000";
			info.func = TitanPanelRestPlusButton_ColorOsOlive;
			info.checked = TitanPanelRestPlusButton_CheckOsOlive;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CORANGE;
			info.colorCode = "|c00FF9900";
			info.func = TitanPanelRestPlusButton_ColorOsOrange;
			info.checked = TitanPanelRestPlusButton_CheckOsOrange;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CPURPLE;
			info.colorCode = "|c008B008B";
			info.func = TitanPanelRestPlusButton_ColorOsPurple;
			info.checked = TitanPanelRestPlusButton_CheckOsPurple;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CRED;
			info.colorCode = "|c00FF0000";
			info.func = TitanPanelRestPlusButton_ColorOsRed;
			info.checked = TitanPanelRestPlusButton_CheckOsRed;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSALMON;
			info.colorCode = "|c00FFA07A";
			info.func = TitanPanelRestPlusButton_ColorAOsSalmon;
			info.checked = TitanPanelRestPlusButton_CheckOsSalmon;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CSBLUE;
			info.colorCode = "|c0000BFFF";
			info.func = TitanPanelRestPlusButton_ColorAOsSBlue;
			info.checked = TitanPanelRestPlusButton_CheckOsSBlue;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {}
			info.text = TITAN_RESTPLUS_CYELLOW;
			info.colorCode = "|c00FFFF00";
			info.func = TitanPanelRestPlusButton_ColorOsYellow;
			info.checked = TitanPanelRestPlusButton_CheckOsYellow;
			--info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			return
		end
	end
	if UIDROPDOWNMENU_MENU_LEVEL == 2 and UIDROPDOWNMENU_MENU_VALUE == "Options" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_option, UIDROPDOWNMENU_MENU_LEVEL)
			
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_REALM;
			info.func = TitanPanelRestPlusButton_ToggleRealm;
			info.checked = RestPlus_Settings.ShowRealms;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 
			
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_RACE;
			info.func = TitanPanelRestPlusButton_ToggleRace;
			info.checked = RestPlus_Settings.ShowRace;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_CLASS;
			info.func = TitanPanelRestPlusButton_ToggleClass;
			info.checked = RestPlus_Settings.ShowClass;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 	
	
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_STATE;
			info.func = TitanPanelRestPlusButton_ToggleState;
			info.checked = RestPlus_Settings.ShowState;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL); 

			TitanPanelRightClickMenu_AddSpacer(UIDROPDOWNMENU_MENU_LEVEL);	
	
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_RESTXP;
			info.func = TitanPanelRestPlusButton_ToggleRestXP;
			info.checked = RestPlus_Settings.PctRestXP;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_XP;
			info.func = TitanPanelRestPlusButton_ToggleXP;
			info.checked = RestPlus_Settings.PctExp;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);	
	
			info = {};
			info.text = TITAN_RESTPLUS_TOGGLE_ACTIVE;
			info.func = TitanPanelRestPlusButton_ToggleActive;
			info.checked = RestPlus_Settings.PctActive;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);	
			
		--end
		return
	end
	
	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		if UIDROPDOWNMENU_MENU_VALUE == "Color Options" then
			TitanPanelRightClickMenu_AddTitle(TRP.menu_coption, UIDROPDOWNMENU_MENU_LEVEL);
			info = {};
			info.text = TRP.menu_CMaxLevel;
			info.value = "Max Level Color";
			info.hasArrow = true;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TRP.menu_CNormal;
			info.value = "Normal XP Color";
			info.hasArrow = true;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TRP.menu_CLevel;
			info.value = "Next Level Color";
			info.hasArrow = true;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TRP.menu_CCapped;
			info.value = "Rest Capped Color";
			info.hasArrow = true;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TRP.menu_CActServ;
			info.value = "Active Server Color";
			info.hasArrow = true;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TRP.menu_COthServ;
			info.value = "Other Server Color";
			info.hasArrow = true;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			TitanPanelRightClickMenu_AddSpacer(UIDROPDOWNMENU_MENU_LEVEL);
			
			info = {};
			info.text = TRP.menu_ColorReset;
			info.func = RestPlus_DefaultColors;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
		end
		return -- so the menu does not create extra repeat buttons
	end
	
	TitanPanelRightClickMenu_AddTitle(TitanPlugins[TRP.id].menuText);	
        TitanPanelRightClickMenu_AddTitle(TITAN_RESTPLUS_ABOUT);
		TitanPanelRightClickMenu_AddSpacer();
		
	info = {};
	info.text = TRP.menu_option;
	info.value = "Options";
	info.hasArrow = true;
	UIDropDownMenu_AddButton(info);
	
	info = {};
	info.text = TRP.menu_coption;
	info.value = "Color Options";
	info.hasArrow = true;
	UIDropDownMenu_AddButton(info);

	TitanPanelRightClickMenu_AddSpacer();
	TitanPanelRightClickMenu_AddToggleIcon(TRP.id);
	TitanPanelRightClickMenu_AddToggleLabelText(TRP.id);

	--TitanPanelRightClickMenu_AddSpacer();
	TitanPanelRightClickMenu_AddCommand(L["TITAN_PANEL_MENU_HIDE"], TRP.id, TITAN_PANEL_MENU_FUNC_HIDE);
end

-- ***********************************************************************
-- ***** Begin Menu Color Functions *****
-- ***********************************************************************
-- ***** Max Level Colors *****
function TitanPanelRestPlusButton_ColorMaxBlue()
	RestPlus_Colors.CMaxLevel = "blue";
end

function TitanPanelRestPlusButton_CheckMaxBlue()
	if RestPlus_Colors.CMaxLevel == "blue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxCyan()
	RestPlus_Colors.CMaxLevel = "cyan";
end

function TitanPanelRestPlusButton_CheckMaxCyan()
	if RestPlus_Colors.CMaxLevel == "cyan" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxFgreen()
	RestPlus_Colors.CMaxLevel = "forestgreen";
end

function TitanPanelRestPlusButton_CheckMaxFgreen()
	if RestPlus_Colors.CMaxLevel == "forestgreen" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxGreen()
	RestPlus_Colors.CMaxLevel = "green";
end

function TitanPanelRestPlusButton_CheckMaxGreen()
	if RestPlus_Colors.CMaxLevel == "green" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxGrey()
	RestPlus_Colors.CMaxLevel = "grey";
end

function TitanPanelRestPlusButton_CheckMaxGrey()
	if RestPlus_Colors.CMaxLevel == "grey" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxKhaki()
	RestPlus_Colors.CMaxLevel = "khaki";
end

function TitanPanelRestPlusButton_CheckMaxKhaki()
	if RestPlus_Colors.CMaxLevel == "khaki" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxLolive()
	RestPlus_Colors.CMaxLevel = "lightolive";
end

function TitanPanelRestPlusButton_CheckMaxLolive()
	if RestPlus_Colors.CMaxLevel == "lightolive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxMagenta()
	RestPlus_Colors.CMaxLevel = "magenta";
end

function TitanPanelRestPlusButton_CheckMaxMagenta()
	if RestPlus_Colors.CMaxLevel == "magenta" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxOwhite()
	RestPlus_Colors.CMaxLevel = "offwhite";
end

function TitanPanelRestPlusButton_CheckMaxOwhite()
	if RestPlus_Colors.CMaxLevel == "offwhite" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxOlive()
	RestPlus_Colors.CMaxLevel = "olive";
end

function TitanPanelRestPlusButton_CheckMaxOlive()
	if RestPlus_Colors.CMaxLevel == "olive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxOrange()
	RestPlus_Colors.CMaxLevel = "orange";
end

function TitanPanelRestPlusButton_CheckMaxOrange()
	if RestPlus_Colors.CMaxLevel == "orange" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxPurple()
	RestPlus_Colors.CMaxLevel = "purple";
end

function TitanPanelRestPlusButton_CheckMaxPurple()
	if RestPlus_Colors.CMaxLevel == "purple" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxRed()
	RestPlus_Colors.CMaxLevel = "red";
end

function TitanPanelRestPlusButton_CheckMaxRed()
	if RestPlus_Colors.CMaxLevel == "red" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxSalmon()
	RestPlus_Colors.CMaxLevel = "salmon";
end

function TitanPanelRestPlusButton_CheckMaxSalmon()
	if RestPlus_Colors.CMaxLevel == "salmon" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxSblue()
	RestPlus_Colors.CMaxLevel = "skyblue";
end

function TitanPanelRestPlusButton_CheckMaxSblue()
	if RestPlus_Colors.CMaxLevel == "skyblue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorMaxYellow()
	RestPlus_Colors.CMaxLevel = "yellow";
end

function TitanPanelRestPlusButton_CheckMaxYellow()
	if RestPlus_Colors.CMaxLevel == "yellow" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

-- ***** Normal XP Colors *****
function TitanPanelRestPlusButton_ColorNormBlue()
	RestPlus_Colors.CNormal = "blue";
end

function TitanPanelRestPlusButton_CheckNormBlue()
	if RestPlus_Colors.CNormal == "blue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormCyan()
	RestPlus_Colors.CNormal = "cyan";
end

function TitanPanelRestPlusButton_CheckNormCyan()
	if RestPlus_Colors.CNormal == "cyan" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormFgreen()
	RestPlus_Colors.CNormal = "forestgreen";
end

function TitanPanelRestPlusButton_CheckNormFgreen()
	if RestPlus_Colors.CNormal == "forestgreen" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormGreen()
	RestPlus_Colors.CNormal = "green";
end

function TitanPanelRestPlusButton_CheckNormGreen()
	if RestPlus_Colors.CNormal == "green" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormGrey()
	RestPlus_Colors.CNormal = "grey";
end

function TitanPanelRestPlusButton_CheckNormGrey()
	if RestPlus_Colors.CNormal == "grey" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormKhaki()
	RestPlus_Colors.CNormal = "khaki";
end

function TitanPanelRestPlusButton_CheckNormKhaki()
	if RestPlus_Colors.CNormal == "khaki" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormLolive()
	RestPlus_Colors.CNormal = "lightolive";
end

function TitanPanelRestPlusButton_CheckNormLolive()
	if RestPlus_Colors.CNormal == "lightolive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormMagenta()
	RestPlus_Colors.CNormal = "magenta";
end

function TitanPanelRestPlusButton_CheckNormMagenta()
	if RestPlus_Colors.CNormal == "magenta" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormOwhite()
	RestPlus_Colors.CNormal = "offwhite";
end

function TitanPanelRestPlusButton_CheckNormOwhite()
	if RestPlus_Colors.CNormal == "offwhite" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormOlive()
	RestPlus_Colors.CNormal = "olive";
end

function TitanPanelRestPlusButton_CheckNormOlive()
	if RestPlus_Colors.CNormal == "olive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormOrange()
	RestPlus_Colors.CNormal = "orange";
end

function TitanPanelRestPlusButton_CheckNormOrange()
	if RestPlus_Colors.CNormal == "orange" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormPurple()
	RestPlus_Colors.CNormal = "purple";
end

function TitanPanelRestPlusButton_CheckNormPurple()
	if RestPlus_Colors.CNormal == "purple" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormRed()
	RestPlus_Colors.CNormal = "red";
end

function TitanPanelRestPlusButton_CheckNormRed()
	if RestPlus_Colors.CNormal == "red" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormSalmon()
	RestPlus_Colors.CNormal = "salmon";
end

function TitanPanelRestPlusButton_CheckNormSalmon()
	if RestPlus_Colors.CNormal == "salmon" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormSblue()
	RestPlus_Colors.CNormal = "skyblue";
end

function TitanPanelRestPlusButton_CheckNormSblue()
	if RestPlus_Colors.CNormal == "skyblue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorNormYellow()
	RestPlus_Colors.CNormal = "yellow";
end

function TitanPanelRestPlusButton_CheckNormYellow()
	if RestPlus_Colors.CNormal == "yellow" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

-- ***** Next Level Color *****
function TitanPanelRestPlusButton_ColorLevelBlue()
	RestPlus_Colors.CLevel = "blue";
end

function TitanPanelRestPlusButton_CheckLevelBlue()
	if RestPlus_Colors.CLevel == "blue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelCyan()
	RestPlus_Colors.CLevel = "cyan";
end

function TitanPanelRestPlusButton_CheckLevelCyan()
	if RestPlus_Colors.CLevel == "cyan" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelFgreen()
	RestPlus_Colors.CLevel = "forestgreen";
end

function TitanPanelRestPlusButton_CheckLevelFgreen()
	if RestPlus_Colors.CLevel == "forestgreen" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelGreen()
	RestPlus_Colors.CLevel = "green";
end

function TitanPanelRestPlusButton_CheckLevelGreen()
	if RestPlus_Colors.CLevel == "green" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelGrey()
	RestPlus_Colors.CLevel = "grey";
end

function TitanPanelRestPlusButton_CheckLevelGrey()
	if RestPlus_Colors.CLevel == "grey" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelKhaki()
	RestPlus_Colors.CLevel = "khaki";
end

function TitanPanelRestPlusButton_CheckLevelKhaki()
	if RestPlus_Colors.CLevel == "khaki" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelLolive()
	RestPlus_Colors.CLevel = "lightolive";
end

function TitanPanelRestPlusButton_CheckLevelLolive()
	if RestPlus_Colors.CLevel == "lightolive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelMagenta()
	RestPlus_Colors.CLevel = "magenta";
end

function TitanPanelRestPlusButton_CheckLevelMagenta()
	if RestPlus_Colors.CLevel == "magenta" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelOwhite()
	RestPlus_Colors.CLevel = "offwhite";
end

function TitanPanelRestPlusButton_CheckLevelOwhite()
	if RestPlus_Colors.CLevel == "offwhite" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelOlive()
	RestPlus_Colors.CLevel = "olive";
end

function TitanPanelRestPlusButton_CheckLevelOlive()
	if RestPlus_Colors.CLevel == "olive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelOrange()
	RestPlus_Colors.CLevel = "orange";
end

function TitanPanelRestPlusButton_CheckLevelOrange()
	if RestPlus_Colors.CLevel == "orange" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelPurple()
	RestPlus_Colors.CLevel = "purple";
end

function TitanPanelRestPlusButton_CheckLevelPurple()
	if RestPlus_Colors.CLevel == "purple" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelRed()
	RestPlus_Colors.CLevel = "red";
end

function TitanPanelRestPlusButton_CheckLevelRed()
	if RestPlus_Colors.CLevel == "red" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelSalmon()
	RestPlus_Colors.CLevel = "salmon";
end

function TitanPanelRestPlusButton_CheckLevelSalmon()
	if RestPlus_Colors.CLevel == "salmon" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelSblue()
	RestPlus_Colors.CLevel = "skyblue";
end

function TitanPanelRestPlusButton_CheckLevelSblue()
	if RestPlus_Colors.CLevel == "skyblue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorLevelYellow()
	RestPlus_Colors.CLevel = "yellow";
end

function TitanPanelRestPlusButton_CheckLevelYellow()
	if RestPlus_Colors.CLevel == "yellow" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

-- ***** Rest Capped Color *****
function TitanPanelRestPlusButton_ColorCapBlue()
	RestPlus_Colors.CCapped = "blue";
end

function TitanPanelRestPlusButton_CheckCapBlue()
	if RestPlus_Colors.CCapped == "blue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapCyan()
	RestPlus_Colors.CCapped = "cyan";
end

function TitanPanelRestPlusButton_CheckCapCyan()
	if RestPlus_Colors.CCapped == "cyan" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapFgreen()
	RestPlus_Colors.CCapped = "forestgreen";
end

function TitanPanelRestPlusButton_CheckCapFgreen()
	if RestPlus_Colors.CCapped == "forestgreen" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapGreen()
	RestPlus_Colors.CCapped = "green";
end

function TitanPanelRestPlusButton_CheckCapGreen()
	if RestPlus_Colors.CCapped == "green" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapGrey()
	RestPlus_Colors.CCapped = "grey";
end

function TitanPanelRestPlusButton_CheckCapGrey()
	if RestPlus_Colors.CCapped == "grey" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapKhaki()
	RestPlus_Colors.CCapped = "khaki";
end

function TitanPanelRestPlusButton_CheckCapKhaki()
	if RestPlus_Colors.CCapped == "khaki" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapLolive()
	RestPlus_Colors.CCapped = "lightolive";
end

function TitanPanelRestPlusButton_CheckCapLolive()
	if RestPlus_Colors.CCapped == "lightolive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapMagenta()
	RestPlus_Colors.CCapped = "magenta";
end

function TitanPanelRestPlusButton_CheckCapMagenta()
	if RestPlus_Colors.CCapped == "magenta" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapOwhite()
	RestPlus_Colors.CCapped = "offwhite";
end

function TitanPanelRestPlusButton_CheckCapOwhite()
	if RestPlus_Colors.CCapped == "offwhite" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapOlive()
	RestPlus_Colors.CCapped = "olive";
end

function TitanPanelRestPlusButton_CheckCapOlive()
	if RestPlus_Colors.CCapped == "olive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapOrange()
	RestPlus_Colors.CCapped = "orange";
end

function TitanPanelRestPlusButton_CheckCapOrange()
	if RestPlus_Colors.CCapped == "orange" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapPurple()
	RestPlus_Colors.CCapped = "purple";
end

function TitanPanelRestPlusButton_CheckCapPurple()
	if RestPlus_Colors.CCapped == "purple" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapRed()
	RestPlus_Colors.CCapped = "red";
end

function TitanPanelRestPlusButton_CheckCapRed()
	if RestPlus_Colors.CCapped == "red" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapSalmon()
	RestPlus_Colors.CCapped = "salmon";
end

function TitanPanelRestPlusButton_CheckCapSalmon()
	if RestPlus_Colors.CCapped == "salmon" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapSblue()
	RestPlus_Colors.CCapped = "skyblue";
end

function TitanPanelRestPlusButton_CheckCapSblue()
	if RestPlus_Colors.CCapped == "skyblue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorCapYellow()
	RestPlus_Colors.CCapped = "yellow";
end

function TitanPanelRestPlusButton_CheckCapYellow()
	if RestPlus_Colors.CCapper == "yellow" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

-- ***** Active Server Color *****
function TitanPanelRestPlusButton_ColorAsBlue()
	RestPlus_Colors.CActServ = "blue";
end

function TitanPanelRestPlusButton_CheckAsBlue()
	if RestPlus_Colors.CActServ == "blue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsCyan()
	RestPlus_Colors.CActServ = "cyan";
end

function TitanPanelRestPlusButton_CheckAsCyan()
	if RestPlus_Colors.CActServ == "cyan" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsFgreen()
	RestPlus_Colors.CActServ = "forestgreen";
end

function TitanPanelRestPlusButton_CheckAsFgreen()
	if RestPlus_Colors.CActServ == "forestgreen" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsGreen()
	RestPlus_Colors.CActServ = "green";
end

function TitanPanelRestPlusButton_CheckAsGreen()
	if RestPlus_Colors.CActServ == "green" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsGrey()
	RestPlus_Colors.CActServ = "grey";
end

function TitanPanelRestPlusButton_CheckAsGrey()
	if RestPlus_Colors.CActServ == "grey" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsKhaki()
	RestPlus_Colors.CActServ = "khaki";
end

function TitanPanelRestPlusButton_CheckAsKhaki()
	if RestPlus_Colors.CActServ == "khaki" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsLolive()
	RestPlus_Colors.CActServ = "lightolive";
end

function TitanPanelRestPlusButton_CheckAsLolive()
	if RestPlus_Colors.CActServ == "lightolive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsMagenta()
	RestPlus_Colors.CActServ = "magenta";
end

function TitanPanelRestPlusButton_CheckAsMagenta()
	if RestPlus_Colors.CActServ == "magenta" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsOwhite()
	RestPlus_Colors.CActServ = "offwhite";
end

function TitanPanelRestPlusButton_CheckAsOwhite()
	if RestPlus_Colors.CActServ == "offwhite" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsOlive()
	RestPlus_Colors.CActServ = "olive";
end

function TitanPanelRestPlusButton_CheckAsOlive()
	if RestPlus_Colors.CActServ == "olive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsOrange()
	RestPlus_Colors.CActServ = "orange";
end

function TitanPanelRestPlusButton_CheckAsOrange()
	if RestPlus_Colors.CActServ == "orange" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsPurple()
	RestPlus_Colors.CActServ = "purple";
end

function TitanPanelRestPlusButton_CheckAsPurple()
	if RestPlus_Colors.CActServ == "purple" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsRed()
	RestPlus_Colors.CActServ = "red";
end

function TitanPanelRestPlusButton_CheckAsRed()
	if RestPlus_Colors.CActServ == "red" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsSalmon()
	RestPlus_Colors.CActServ = "salmon";
end

function TitanPanelRestPlusButton_CheckAsSalmon()
	if RestPlus_Colors.CActServ == "salmon" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsSblue()
	RestPlus_Colors.CActServ = "skyblue";
end

function TitanPanelRestPlusButton_CheckAsSblue()
	if RestPlus_Colors.CActServ == "skyblue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorAsYellow()
	RestPlus_Colors.CActServ = "yellow";
end

function TitanPanelRestPlusButton_CheckAsYellow()
	if RestPlus_Colors.CActServ == "yellow" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

-- ***** Other Server Color
function TitanPanelRestPlusButton_ColorOsCyan()
	RestPlus_Colors.COthServ = "cyan";
end

function TitanPanelRestPlusButton_CheckOsCyan()
	if RestPlus_Colors.COthServ == "cyan" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsBlue()
	RestPlus_Colors.COthServ = "blue";
end

function TitanPanelRestPlusButton_CheckOsBlue()
	if RestPlus_Colors.COthServ == "blue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsFgreen()
	RestPlus_Colors.COthServ = "forestgreen";
end

function TitanPanelRestPlusButton_CheckOsFgreen()
	if RestPlus_Colors.COthServ == "forestgreen" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsGreen()
	RestPlus_Colors.COthServ = "green";
end

function TitanPanelRestPlusButton_CheckOsGreen()
	if RestPlus_Colors.COthServ == "green" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsGrey()
	RestPlus_Colors.COthServ = "grey";
end

function TitanPanelRestPlusButton_CheckOsGrey()
	if RestPlus_Colors.COthServ == "grey" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsKhaki()
	RestPlus_Colors.COthServ = "khaki";
end

function TitanPanelRestPlusButton_CheckOsKhaki()
	if RestPlus_Colors.COthServ == "khaki" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsLolive()
	RestPlus_Colors.COthServ = "lightolive";
end

function TitanPanelRestPlusButton_CheckOsLolive()
	if RestPlus_Colors.COthServ == "lightolive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsMagenta()
	RestPlus_Colors.COthServ = "magenta";
end

function TitanPanelRestPlusButton_CheckOsMagenta()
	if RestPlus_Colors.COthServ == "magenta" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsOwhite()
	RestPlus_Colors.COthServ = "offwhite";
end

function TitanPanelRestPlusButton_CheckOsOwhite()
	if RestPlus_Colors.COthServ == "offwhite" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsOlive()
	RestPlus_Colors.COthServ = "olive";
end

function TitanPanelRestPlusButton_CheckOsOlive()
	if RestPlus_Colors.COthServ == "olive" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsOrange()
	RestPlus_Colors.COthServ = "orange";
end

function TitanPanelRestPlusButton_CheckOsOrange()
	if RestPlus_Colors.COthServ == "orange" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsPurple()
	RestPlus_Colors.COthServ = "purple";
end

function TitanPanelRestPlusButton_CheckOsPurple()
	if RestPlus_Colors.COthServ == "purple" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsRed()
	RestPlus_Colors.COthServ = "red";
end

function TitanPanelRestPlusButton_CheckOsRed()
	if RestPlus_Colors.COthServ == "red" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsSalmon()
	RestPlus_Colors.COthServ = "salmon";
end

function TitanPanelRestPlusButton_CheckOsSalmon()
	if RestPlus_Colors.COthServ == "salmon" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsSblue()
	RestPlus_Colors.COthServ = "skyblue";
end

function TitanPanelRestPlusButton_CheckOsSblue()
	if RestPlus_Colors.COthServ == "skyblue" then
		checked = true;
	else
		checked = false;
	end
	return checked
end

function TitanPanelRestPlusButton_ColorOsYellow()
	RestPlus_Colors.COthServ = "yellow";
end

function TitanPanelRestPlusButton_CheckOsYellow()
	if RestPlus_Colors.COthServ == "yellow" then
		checked = true;
	else
		checked = false;
	end
	return checked
end


-- *************************************************************
-- ***** End Menu Color Functions *****
-- *************************************************************

function TitanPanelRestPlusButton_ToggleRealm()
	RestPlus_Settings.ShowRealms = not RestPlus_Settings.ShowRealms;
end

function TitanPanelRestPlusButton_ToggleRace()
	RestPlus_Settings.ShowRace = not RestPlus_Settings.ShowRace;
end

function TitanPanelRestPlusButton_ToggleClass()
	RestPlus_Settings.ShowClass = not RestPlus_Settings.ShowClass;
end

function TitanPanelRestPlusButton_ToggleState()
	RestPlus_Settings.ShowState = not RestPlus_Settings.ShowState;
end

function TitanPanelRestPlusButton_ToggleRestXP()
	RestPlus_Settings.PctRestXP = not RestPlus_Settings.PctRestXP;
end

function TitanPanelRestPlusButton_ToggleXP()
	RestPlus_Settings.PctExp = not RestPlus_Settings.PctExp;
end

function TitanPanelRestPlusButton_ToggleActive()
	RestPlus_Settings.PctActive = not RestPlus_Settings.PctActive;
	TitanPanelButton_UpdateButton(TITAN_RESTPLUS_ID);
end

function RestPlus_OnUpdate(self,elapsed)
	if RestPlus_Settings.EnableTimer then
		if (not RestTimer) then
			RestTimer = RestPlus_Settings.TimerDelay;		
		end
		if (RestTimer > 0) then 
			RestTimer = RestTimer - elapsed;
		else
			RestPlus_AlertCheck();
			RestTimer = RestPlus_Settings.TimerDelay;
		end
	end
	-- begin debug
	
		--print (elapsed)
	
	 -- end debug
 
end

function RestPlus_OnEvent(self, event, ...)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		RestPlus_DumpData();
		--RestPlus_LoadCData();
		--RESTPLUS_COLOR_MAXLEVEL = RestPlus_Colors.CMaxLevel;
		--print("RestPlus Color MaxLevel after LoadData = ", RESTPLUS_COLOR_MAXLEVEL);
		--RESTPLUS_COLOR_NORMAL = RestPlus_Colors.CNormal;
		--RESTPLUS_COLOR_LEVEL = RestPlus_Colors.CLevel;
		--RESTPLUS_COLOR_CAPPED = RestPlus_Colors.CCapped;
		--RESTPLUS_COLOR_ACTIVESERVER = RestPlus_Colors.CActServ;
		--RESTPLUS_COLOR_OTHERSERVER = RestPlus_Colors.COthServ;
	end
	if ( event == "PLAYER_UPDATE_RESTING" ) or ( event == "PLAYER_XP_UPDATE" ) 
		or ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( UnitName("player") ~= UNKNOWNOBJECT ) then
			RestPlus_SaveCharacter();
		end
	end
end

function RestPlus_Command(msg)
	local args={};
	local counter=0;
	local i=0;	

	for w in string.gmatch(msg, "[%w']+") do
		counter=counter+1;
		args[counter]=string.lower(w);
	end
	
	if (args[1]=="wellrested") then
        local index = UnitName("player").."="..GetRealmName()
        if args[2] == "auto" then
            RestPlus_Data = RestPlus_Data or {}
            RestPlus_Data[index] = RestPlus_Data[index] or {}
            RestPlus_Data[index].wellRestedManual = nil
            local detected = RestPlus_GetTalentRankByName()
            if detected ~= nil then RestPlus_Data[index].wellRestedRank = detected end
            u:Print("Automatic Well Rested detection re-enabled. Detected rank: "..tostring(detected or "unavailable")..".", RESTPLUS_COLOR)
            RestPlus_SaveCharacter()
            TitanPanelButton_UpdateButton(TRP.id)
        else
            local rank = tonumber(args[2])
            if rank == nil or rank < 0 or rank > 5 or rank ~= math.floor(rank) then
                u:Print("Usage: /restplus wellrested 0-5 OR /restplus wellrested auto", RESTPLUS_COLOR)
            else
                RestPlus_SaveCharacter()
                RestPlus_Data[index].wellRestedRank = rank
                RestPlus_Data[index].wellRestedManual = true
                u:Print("Well Rested rank set to "..rank.." for "..UnitName("player")..".", RESTPLUS_COLOR)
                TitanPanelButton_UpdateButton(TRP.id)
            end
        end
    elseif (args[1]=="save") then
		RestPlus_SaveCharacter();
	elseif (args[1]=="reset") then
		RestPlus_Data = { };
		u:Print(RESTPLUS_RESET, RESTPLUS_COLOR);
	elseif (args[1]=="remove") then	
		if(args[2]) and (args[3]) then	
			-- Make sure names are properly capitalized.
			args[2] = gsub(args[2], "%l", string.upper, 1);
			args[3] = gsub(args[3], "%l", string.upper, 1);
			if(args[4]) then
				-- Realm name is made up of two words.
				args[4] = gsub(args[4], "%l", string.upper, 1)
				args[3] = args[3].." "..args[4];
			elseif (strfind(args[3], "'")) then
				-- Realm is 'ed - capitalize start and after '
				startpos,endpos = strfind(args[3], "'")
				args[3] = gsub(args[3], "'%l", string.upper, 2);
			end
			local index = args[2].."="..args[3];
			if(RestPlus_Data[index]) then
				RestPlus_Data[index] = nil;
				u:Print(RESTPLUS_CHAR_REMOVED..args[2]..", "..args[3]);
			else
				u:Print(index..": "..RESTPLUS_NOCHAR);
			end
		elseif (args[2]) then
			local realm = GetRealmName();
			args[2] = gsub(args[2], "%l", string.upper, 1);
			local index = args[2].."="..realm;
			if (RestPlus_Data[index]) then
				RestPlus_Data[index] = nil;
				u:Print(RESTPLUS_CHAR_REMOVED..args[2]..", "..realm);
			end
		else
			u:Print(RESTPLUS_INSUFFICIENT_ARGS);
		end
	elseif (args[1]=="help") then
        u:Print("Well Rested support: /restplus wellrested 0-5 sets this character's legacy talent rank.", RESTPLUS_COLOR)
		u:Print(RESTPLUS_HELP1, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP2, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP3, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP4, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP5, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP6, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP7, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP8, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP9, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP10, RESTPLUS_COLOR);
		u:Print(RESTPLUS_HELP11, RESTPLUS_COLOR);
	elseif (args[1]=="sound") then
		if (RestPlus_Settings.EnableSound) then
			RestPlus_Settings.EnableSound = false;
			u:Print(RESTPLUS_SOUND..RESTPLUS_OFF,RESTPLUS_COLOR);
		else
			RestPlus_Settings.EnableSound = true;
			u:Print(RESTPLUS_SOUND..RESTPLUS_ON,RESTPLUS_COLOR);
		end
	elseif (args[1]=="timer") then
		if (RestPlus_Settings.EnableTimer) then
			RestPlus_Settings.EnableTimer = false;
			u:Print(RESTPLUS_TIMER..RESTPLUS_OFF,RESTPLUS_COLOR);
		else
			RestPlus_Settings.EnableTimer = true;
			u:Print(RESTPLUS_TIMER..RESTPLUS_ON,RESTPLUS_COLOR);
		end
	elseif (args[1]=="delay") then
		if (args[2]) and (tonumber(args[2])) and (tonumber(args[2]) > 0) then
			RestPlus_Settings.TimerDelay = tonumber(args[2]);
			u:Print(RESTPLUS_DELAY_MSG..args[2]..".");
		else
			u:Print(RESTPLUS_INVALID_TIME);
		end
	elseif (args[1]=="recycle") then
		RestPlus_DefaultOptions();
	elseif (args[1]=="debug") then
		RPDEBUG = not RPDEBUG;
	else
		RestPlus_AlertCheck();
		RestPlus_DisplayChatList();
	end
end
function RestPlus_DefaultColors()
	RestPlus_Colors = {};
	RestPlus_Colors.CMaxLevel = "cyan";
	RestPlus_Colors.CNormal = "green";
	RestPlus_Colors.CLevel = "yellow";
	RestPlus_Colors.CCapped = "red";
	RestPlus_Colors.CActServ = "offwhite";
	RestPlus_Colors.COthServ = "grey";
end
function RestPlus_DefaultOptions()
		RestPlus_Settings = {};
		RestPlus_Settings.EnableSound = true;
		RestPlus_Settings.EnableTimer = true;
		RestPlus_Settings.TimerDelay = RESTPLUS_DELAY;
		RestPlus_Settings.ShowRealms = true;
		RestPlus_Settings.ShowRace = false;
		RestPlus_Settings.ShowClass = true;
		RestPlus_Settings.ShowState = true;
		RestPlus_Settings.PctExp = true;
		RestPlus_Settings.PctRestXP = true;	
		RestPlus_Settings.PctActive = true;
end

function RestPlus_LoadData()
	if (not RestPlus_Data) then
		RestPlus_Data = { };
	end
	--print("Colorl Setting before TimerDelay check = ", RestPlus_Settings.CMaxLevel);
	if(not RestPlus_Settings) or (RestPlus_Settings.TimerDelay == nil) then
		RestPlus_DefaultOptions();
	end
	if(RestPlus_Settings.ShowRealms == nil) then
		RestPlus_Settings.ShowRealms = true;	
	end
	if(RestPlus_Settings.ShowRace == nil) then
		RestPlus_Settings.ShowRace = false;	
	end
	if(RestPlus_Settings.ShowClass == nil) then
		RestPlus_Settings.ShowClass= true;	
	end
	if(RestPlus_Settings.ShowState == nil) then
		RestPlus_Settings.ShowState = true;	
	end
	if(RestPlus_Settings.PctExp == nil) then
		RestPlus_Settings.PctExp = true;	
	end	
	if(RestPlus_Settings.PctRestXP == nil) then
		RestPlus_Settings.PctRestXP = true;	
	end	
	if(RestPlus_Settings.PctActive == nil) then
		RestPlus_Settings.PctActive = true;	
	end	
	if(RestPlus_Settings.TimerDelay == nil) then
		RestPlus_Settings.TimerDelay = RESTPLUS_DELAY;	
	end	
	
end

function RestPlus_LoadCData()
	--print("Load data color max level = ", RestPlus_Colors.CMaxLevel);
	if RestPlus_Colors == nil then
		RestPlus_Colors = {};
	else
		return
	end
	if(RestPlus_Colors.CMaxLevel == nil) then
		RestPlus_Colors.CMaxLevel = "cyan";
	end
	if(RestPlus_Colors.CNormal == nil) then
		RestPlus_Colors.CNormal = "green";
	end
	if(RestPlus_Colors.CLevel == nil) then
		RestPlus_Colors.CLevel = "yellow";
	end
	if(RestPlus_Colors.CCapped == nil) then
		RestPlus_Colors.CCapped = "red";
	end
	if(RestPlus_Colors.CActServ == nil) then
		RestPlus_Colors.CActServ = "offwhite";
	end
	if(RestPlus_Colors.COthServ == nil) then
		RestPlus_Colors.COthServ = "grey";
	end
end

function RestPlus_Logout()
	RestPlus_SaveCharacter();
	Logout();
end

-- *******************************************
-- *** Set short class name ***
-- *******************************************
function RestPlus_ShortClass(class)
	if (class == "Druid") then return "Dru";
	elseif (class == "Demon Hunter") then return "DH";
	elseif (class == "Hunter") then return "Hun";
	elseif (class == "Mage") then return "Mag";	
	elseif (class == "Priest") then return "Pri";
	elseif (class == "Paladin") then return "Pal";
	elseif (class == "Rogue") then return "Rog";		
	elseif (class == "Shaman") then return "Sha";		
	elseif (class == "Warrior") then return "War";		
	elseif (class == "Warlock") then return "Wck";
	elseif (class == "Death Knight") then return "DK";
	elseif (class == "Monk") then return "Mnk";
	end
end

-- ********************************************
-- *** Set short race name ***
-- ********************************************
function RestPlus_ShortRace(race)
	--u:print(race.." - Race", RESTPLUS_COLOR);
	--DEFAULT_CHAT_FRAME:AddMessage(race.." - Full Race to shorten",1.0,0.0,1.0);
	if (race == "BloodElf") then return "BE";
	elseif (race == "Draenei") then return "Drn";
	elseif (race == "Dwarf") then return "Drf";
	elseif (race == "Gnome") then return "Gnm";	
	elseif (race == "Goblin") then return "Gbn";
	elseif (race == "Human") then return "Hmn";
	elseif (race == "NightElf") then return "NE";		
	elseif (race == "Orc") then return "Orc";		
	elseif (race == "Pandaren") then return "Pan";		
	elseif (race == "Tauren") then return "Trn";
	elseif (race == "Troll") then return "Trl";
	elseif (race == "Scourge") then return "Und";
	elseif (race == "Worgen") then return "Wgn";
	--elseif (race == "DarkIronDwarf") then return "DID";
	--elseif (race == "LightforgedDraenei") then return "LDr";
	--elseif (race == "VoidElf") then return "VEl";
	--elseif (race == "HighmountainTauren") then return "HTn";
	--elseif (race == "Mag'harOrc") then return "MOr";
	--elseif (race == "Nightborne") then return "Nbn";
	else return "AlR";
	end
	-- u:print(race.." - Race, "..RestPlus_ShortRace.." - Short Race", RESTPLUS_COLOR);
end

function RestPlus_SaveCharacter()
	-- RestPlus_Debug("RestPlus_SaveCharacter called.");
	if (not RestPlus_Data) then
		RestPlus_Debug("RestPlus_Data empty");
		return;
	end
	for index,value in pairs(RestPlus_Data) do
		-- This is conversion code to move to the new separator, '='
--		if (strfind(index, "|")) then
--			local oldindex = index;
--			index = gsub(index, "|", "=");
--			RestPlus_Data[index] = RestPlus_Data[oldindex];
--			RestPlus_Data[oldindex] = nil;
--		end
		-- Remove any accidental unknown entities
		if(RestPlus_PlayerName(index) == UNKNOWNOBJECT) then
			RestPlus_Debug("Removing accidental unknown entities")
			RestPlus_Data[index] = nil;
		end
	end
	local index = UnitName("player").."="..GetRealmName();
	RestPlus_Debug("Saving to index: "..index);
    -- Preserve per-character settings such as the manually entered talent rank.
    RestPlus_Data[index] = RestPlus_Data[index] or {}
    local existingRank = tonumber(RestPlus_Data[index].wellRestedRank) or 0
    RestPlus_Data[index].level = 0
    RestPlus_Data[index].currXP = 0
    RestPlus_Data[index].nextXP = 0
    RestPlus_Data[index].restXP = 0
    RestPlus_Data[index].resting = 0
    RestPlus_Data[index].logtime = 0
    RestPlus_Data[index].class = 0
    RestPlus_Data[index].race = 0
    RestPlus_Data[index].wellRestedRank = existingRank
	RestPlus_Data[index].level = UnitLevel("player");
	RestPlus_Data[index].class = RestPlus_ShortClass(UnitClass("player"));
	RestPlus_Data[index].race = RestPlus_ShortRace(UnitRace("player"));
	--u:print(RestPlus_Data[index].race.." - Short Race Save Character", RESTPLUS_COLOR);
	--DEFAULT_CHAT_FRAME:AddMessage(RestPlus_Data[index].race.." - Short Race Save Character",1.0,0.0,1.0);
	RestPlus_Data[index].currXP = UnitXP("player");
	RestPlus_Data[index].nextXP = UnitXPMax("player");
	RestPlus_Data[index].restXP = GetXPExhaustion();
	if (RestPlus_Data[index].restXP == nil) then -- GetXPExhaustion returns nil instead of 0
		RestPlus_Data[index].restXP = 0;
	end
    local detectedRank = RestPlus_GetTalentRankByName()
    if detectedRank ~= nil then
        RestPlus_Data[index].wellRestedRank = math.max(0, math.min(5, detectedRank))
        RestPlus_Data[index].wellRestedManual = nil
    end
	RestPlus_Data[index].resting = IsResting();
	if (RestPlus_Data[index].resting == nil) then
		RestPlus_Data[index].resting = 0;
	end
	RestPlus_Data[index].logtime = RestPlus_GetTime();
	RestPlus_Debug(RESTPLUS_SAVE_CHAR, RESTPLUS_COLOR);

	RestPlus_DumpData(index);
end

function RestPlus_GetTime()
	local MonthDays = {};
	local currTime = 0;
	MonthDays[1]=0;
	MonthDays[2]=31;
	MonthDays[3]=MonthDays[2]+28;
	MonthDays[4]=MonthDays[3]+31;
	MonthDays[5]=MonthDays[4]+30;
	MonthDays[6]=MonthDays[5]+31;
	MonthDays[7]=MonthDays[6]+30;
	MonthDays[8]=MonthDays[7]+31;
	MonthDays[9]=MonthDays[8]+31;
	MonthDays[10]=MonthDays[9]+30;
	MonthDays[11]=MonthDays[10]+31;
	MonthDays[12]=MonthDays[11]+30;
	local Days = tonumber(date("%d"));
	local Months = tonumber(date("%m"));
	local Years = tonumber(date("%y"));
	local hours = tonumber(date("%H"));
	local minutes = tonumber(date("%M"));
--	u:Print(Days.."/"..Months.."/"..Years.." "..hours..":"..minutes, RESTPLUS_COLOR);
	currTime = ((Years-5)*365 + MonthDays[Months] + Days-1)*24*60 + hours*60 + minutes;
	return currTime;
end

function RestPlus_PlayerName(index)
	local first, last = strfind(index, "=", 1);
	if first then -- found
		return strsub(index, 1, first-1);
	else
		return index;
	end
end

function RestPlus_RealmName(index)
	local first, last = strfind(index, "=", 1);
	if last then -- found
		return strsub(index, last + 1);
	else
		return RESTPLUS_UNKNOWN_REALM;
	end
end

function RestPlus_AlertCheck()
	RestPlus_SaveCharacter()
	local index;
	local currTime = RestPlus_GetTime();
	local EnableSound = RestPlus_Settings.EnableSound;
	for index,value in pairs(RestPlus_Data) do
		--DEFAULT_CHAT_FRAME:AddMessage(index.." - Index Alert Check-1",1.0,0.2,0.5);
		if ( RestPlus_Data[index].resting ) then
			RestPlus = RestPlus_Data[index].restXP + RestPlus_Data[index].nextXP*(5/100)*RestPlus_RestRateMultiplier(RestPlus_Data[index])*((currTime-RestPlus_Data[index].logtime)/(60*8));
		else
			RestPlus = RestPlus_Data[index].restXP + RestPlus_Data[index].nextXP*(5/100)*RestPlus_RestRateMultiplier(RestPlus_Data[index])*((currTime-RestPlus_Data[index].logtime)/(60*32));
		end
		if ((RestPlus_Data[index].currXP + RestPlus) < RestPlus_Data[index].nextXP) then
			RestPlus_Data[index].AlertStatus = RESTPLUS_ALERTSTATUS_NORMAL;
		else
			--u:print(RestPlus_Data[index].race.." - Short Race Alert Check", RESTPLUS_COLOR);
			--DEFAULT_CHAT_FRAME:AddMessage(index.." - Index Alert Check-2",1.0,0.0,0.5);
			--DEFAULT_CHAT_FRAME:AddMessage(RestPlus_Data[index].nextXP.." - Next XP Alert Check",1.0,0.0,.8);
			--DEFAULT_CHAT_FRAME:AddMessage(RestPlus_Data[index].race.." - Short Race Alert Check",1.0,0.0,1.0);
			if (RestPlus_Data[index].race == "Pan") then
				if (RestPlus >= (3*RestPlus_Data[index].nextXP)) and (RestPlus_Data[index].AlertStatus ~= RESTPLUS_ALERTSTATUS_CAPPED) and (RestPlus_PlayerName(index) ~= UNKNOWNOBJECT) and (index ~= RestPlus_ActiveCharIndex) then
					u:Print(RestPlus_PlayerName(index)..RESTPLUS_MSG_CAPPED, RESTPLUS_COLOR_CAPPED);
					RestPlus_Data[index].AlertStatus = RESTPLUS_ALERTSTATUS_CAPPED;
					if (EnableSound) then
						PlaySound(862);
						EnableSound = false;
					end
				else
					if ((RestPlus_Data[index].currXP + RestPlus) >= RestPlus_Data[index].nextXP) and (RestPlus_Data[index].AlertStatus == RESTPLUS_ALERTSTATUS_NORMAL) and (index ~= RestPlus_ActiveCharIndex) then
						u:Print(RestPlus_PlayerName(index)..RESTPLUS_MSG_LEVEL, RESTPLUS_COLOR_LEVEL);
						RestPlus_Data[index].AlertStatus = RESTPLUS_ALERTSTATUS_LEVEL;
						if (EnableSound) then
							PlaySound(863);
							EnableSound = false;
						end
					end
				end
			else
				if (RestPlus >= (RestPlus_RestCapMultiplier(RestPlus_Data[index])*RestPlus_Data[index].nextXP)) and (RestPlus_Data[index].AlertStatus ~= RESTPLUS_ALERTSTATUS_CAPPED) and (RestPlus_PlayerName(index) ~= UNKNOWNOBJECT) and (index ~= RestPlus_ActiveCharIndex) then
					u:Print(RestPlus_PlayerName(index)..RESTPLUS_MSG_CAPPED, RESTPLUS_COLOR_CAPPED);
					RestPlus_Data[index].AlertStatus = RESTPLUS_ALERTSTATUS_CAPPED;
					if (EnableSound) then
						PlaySound(862);
						EnableSound = false;
					end
				else
					if ((RestPlus_Data[index].currXP + RestPlus) >= RestPlus_Data[index].nextXP) and (RestPlus_Data[index].AlertStatus == RESTPLUS_ALERTSTATUS_NORMAL) and (index ~= RestPlus_ActiveCharIndex) then
						u:Print(RestPlus_PlayerName(index)..RESTPLUS_MSG_LEVEL, RESTPLUS_COLOR_LEVEL);
						RestPlus_Data[index].AlertStatus = RESTPLUS_ALERTSTATUS_LEVEL;
						if (EnableSound) then
							PlaySound(863);
							EnableSound = false;
						end
					end
				end
			end
		end
	end
end

function RestPlus_Sort()
	local restXP = 0;
	local currTime = RestPlus_GetTime();
	local ActiveChar = UnitName("player").."="..GetRealmName();
	local toSort = {};
	local toSortIndex = 0;
	
	RestPlus_Debug("Player: "..ActiveChar);
	for index,value in pairs(RestPlus_Data) do
		RestPlus_Debug("Sorting saved data: "..index);
		local Name = RestPlus_PlayerName(index);
		local Realm = RestPlus_RealmName(index);
		local Level = RestPlus_Data[index].level;
		local Race = RestPlus_Data[index].race;
		local strExp = "";
		if Race == nil then
			Race = "NA";
		end
		if(RestPlus_Settings.PctExp) then
			strExp = format("%.2f%%",(tonumber(RestPlus_Data[index].currXP) / tonumber(RestPlus_Data[index].nextXP)) * 100);
		else
			strExp = format("%d", tonumber(RestPlus_Data[index].currXP));
		end
		local restXP = RestPlus_Data[index].restXP;
		local TimeLeft = 0;
		local strResting;
		local strRestPlus;
		local strLeft = "";
		local StatusColor = RESTPLUS_COLOR_NORMAL;
		-- Logout at Inn (Yes/No) for 5%/8h or 5%/32h
		if ( currTime > RestPlus_Data[index].logtime ) then
			if ( RestPlus_Data[index].resting ) then
					restXP = restXP + RestPlus_Data[index].nextXP*(5/100)*RestPlus_RestRateMultiplier(RestPlus_Data[index])*((currTime-RestPlus_Data[index].logtime)/(60*8));
			else
				restXP = restXP + RestPlus_Data[index].nextXP*(5/100)*RestPlus_RestRateMultiplier(RestPlus_Data[index])*((currTime-RestPlus_Data[index].logtime)/(60*32));
			end
		end

		RestPlus_Debug("sort_index: "..index);
		if ((RestPlus_Data[index].currXP + restXP) >= RestPlus_Data[index].nextXP) then
			StatusColor = RESTPLUS_COLOR_LEVEL;
		end
		if (Race == "Pan") then
			if (restXP >= (3*RestPlus_Data[index].nextXP)) then
				restXP = 3*RestPlus_Data[index].nextXP;
				StatusColor = RESTPLUS_COLOR_CAPPED;
			else
				if ( RestPlus_Data[index].resting ) then
					--DEFAULT_CHAT_FRAME:AddMessage(tostring(restXP).." - Rest XP Alert Check",1.0,0.0,0.5);
					TimeLeft = format("%.2f", (300 - (tonumber(restXP) / tonumber(RestPlus_Data[index].nextXP)) * 100)* 8 / (5 * RestPlus_RestRateMultiplier(RestPlus_Data[index])));
				else
					--DEFAULT_CHAT_FRAME:AddMessage(tostring(restXP).." - Rest XP Alert Check",1.0,0.0,0.5);
					TimeLeft = format("%.2f", (300 - (tonumber(restXP) / tonumber(RestPlus_Data[index].nextXP)) * 100)* 32 / (5 * RestPlus_RestRateMultiplier(RestPlus_Data[index])));		
				end
			end
			TimeLeft = tonumber(TimeLeft);
			local DaysLeft = "";
			if(TimeLeft > 24) then
				DaysLeft = format("%d", TimeLeft / 24);
				TimeLeft = TimeLeft - DaysLeft * 24;
				DaysLeft = DaysLeft..RESTPLUS_DAYS;
			end
			local whole = floor(TimeLeft);
			strLeft = format("(%s%d:%02d)", DaysLeft, whole, (TimeLeft - whole) * 60);
		else
			if (restXP >= (RestPlus_RestCapMultiplier(RestPlus_Data[index])*RestPlus_Data[index].nextXP)) then
				restXP = RestPlus_RestCapMultiplier(RestPlus_Data[index])*RestPlus_Data[index].nextXP;
				StatusColor = RESTPLUS_COLOR_CAPPED;
			else
				if ( RestPlus_Data[index].resting ) then
					TimeLeft = format("%.2f", ((RestPlus_RestCapMultiplier(RestPlus_Data[index])*100) - (tonumber(restXP) / tonumber(RestPlus_Data[index].nextXP)) * 100)* 8 / (5 * RestPlus_RestRateMultiplier(RestPlus_Data[index])));
				else
					TimeLeft = format("%.2f", ((RestPlus_RestCapMultiplier(RestPlus_Data[index])*100) - (tonumber(restXP) / tonumber(RestPlus_Data[index].nextXP)) * 100)* 32 / (5 * RestPlus_RestRateMultiplier(RestPlus_Data[index])));		
				end
				TimeLeft = tonumber(TimeLeft);
				local DaysLeft = "";
				if(TimeLeft > 24) then
					DaysLeft = format("%d", TimeLeft / 24);
					TimeLeft = TimeLeft - DaysLeft * 24;
					DaysLeft = DaysLeft..RESTPLUS_DAYS;
				end
				local whole = floor(TimeLeft);
				strLeft = format("(%s%d:%02d)", DaysLeft, whole, (TimeLeft - whole) * 60);
			end
		end
		
		local Class = "";
		-- The following conditional is needed because the class field is a new addition.
		if(RestPlus_Data[index].class) then
			Class = RestPlus_Data[index].class;
		end
		
		
		
		strRestPlus = format("%.2f%%",(tonumber(restXP) / tonumber(RestPlus_Data[index].nextXP)) * 100);
		if(Level == EXPAN_MAXLEVEL) then
			strRestPlus = "000.01%";
		end
		
		if ( index == ActiveChar ) then 
			strResting = RESTPLUS_RESTING_ACTIVE;
			RestPlus_ActiveCharXP = strRestPlus;
			RestPlus_ActiveCharColor = StatusColor;
			RestPlus_ActiveCharXPRaw = format("%d", (tonumber(restXP) / 2));
			RestPlus_ActiveCharIndex = index;
		elseif ( RestPlus_Data[index].resting ) then
			strResting = RESTPLUS_RESTING_TRUE;
		else
			strResting = RESTPLUS_RESTING_FALSE;
		end
		
		local tempxp = strRestPlus;
		while (string.len(tempxp) < 7) do
			tempxp = "0"..tempxp; 
		end
		local tempstr = tempxp.."="..Name.." (";
		--if(RestPlus_Settings.ShowRealms) then
			--tempstr = tempstr..Realm..", ";
		--end
		if(RestPlus_Settings.ShowClass) then
			tempstr = tempstr..Class.." ";
		end	
		if(RestPlus_Settings.ShowRace) then
			tempstr = tempstr..Race.." ";
		end	
        tempstr = tempstr.."L"..Level.." WR"..(tonumber(RestPlus_Data[index].wellRestedRank) or 0)..") ";
		tempstr = tempstr.."\t";
		if(Level == EXPAN_MAXLEVEL) then
			-- The following is to prevent alerts for this character.
			RestPlus_Data[index].logtime = currTime;
			if(RestPlus_Settings.ShowState) then
				tempstr = tempstr..RESTPLUSLOCAL_LEVELMAX;
			end
			tempstr = tempstr.."="..RESTPLUS_COLOR_MAXLEVEL;
		else
			if(RestPlus_Settings.ShowState) then
				tempstr = tempstr..strResting.." ";
			end
			if(not RestPlus_Settings.PctRestXP) then
				strRestPlus = format("%d", (tonumber(restXP) / 2));
			end
			tempstr = tempstr..strLeft.." "..strExp.." (+"..strRestPlus..")";
			tempstr = tempstr.."="..StatusColor;
		end
		RestPlus_RealmList[toSortIndex] = Realm; -- EMERALD
		toSort[toSortIndex] = tempstr;
		toSortIndex = toSortIndex + 1;
		--u:Print(Name.." ("..Realm.." L"..Level..") "..strExp.."(+"..strRestPlus..") "..strLeft.." "..strResting,StatusColor);
	end
	local i, j, min;
	
	for i = 0, toSortIndex - 1 do
		min = i;
		for j = i, toSortIndex - 1 do
			local a = strsub(toSort[j], 1, strfind(toSort[j], "=", 1) - 2);
			local b = strsub(toSort[min], 1, strfind(toSort[min], "=", 1) - 2);
			if(a < b) then
				min = j;
			end
		end
		local buf = toSort[i];
		toSort[i] = toSort[min];
		toSort[min] = buf;
		local buf2 = RestPlus_RealmList[i]; -- EMERALD
		RestPlus_RealmList[i] = RestPlus_RealmList[min];
		RestPlus_RealmList[min] = buf2;
	end
	
	RestPlus_ToPrintIndex = 0;
	-- EMERALD Start
		-- Get unique realms
		--local tempTableEmerald = table.sort(RestPlus_RealmList);
		local tempTableEmerald = RestPlus_RealmList;
		local tempTableRealms = {};
		local found = false;
		for key, tempRealm in pairs(tempTableEmerald) do
			for key2, tempRealmCheck in pairs(tempTableRealms) do
				if (tempRealm==tempRealmCheck) then
					found = true;
					break;
				end
			end
			if (not found) then table.insert(tempTableRealms, tempRealm); end
			found = false;
		end
		
		-- Sort current realm to top
		local thisRealm = GetRealmName();
		RestPlus_ToPrint[RestPlus_ToPrintIndex] = thisRealm;
		RestPlus_ToPrintColor[RestPlus_ToPrintIndex] = RESTPLUS_COLOR_ACTIVESERVER;
		RestPlus_ToPrintIndex = RestPlus_ToPrintIndex + 1;
		for i = toSortIndex - 1, 0, -1 do
			if (RestPlus_RealmList[i]==thisRealm) then
				RestPlus_ToPrint[RestPlus_ToPrintIndex] = "  "; -- EMERALD: Indent
				local first = strfind(toSort[i], "=", 1);
				RestPlus_ToPrint[RestPlus_ToPrintIndex] = strsub(toSort[i], first + 1);
				first = strfind (RestPlus_ToPrint[RestPlus_ToPrintIndex] , "=", 1);
				local color = strsub(RestPlus_ToPrint[RestPlus_ToPrintIndex] , first + 1);
				RestPlus_ToPrint[RestPlus_ToPrintIndex] = strsub(RestPlus_ToPrint[RestPlus_ToPrintIndex] , 1, first - 1);
				RestPlus_ToPrintColor[RestPlus_ToPrintIndex] = color;
				RestPlus_ToPrintIndex = RestPlus_ToPrintIndex + 1;
			end
		end
		-- Add other realms afterward
		for key, realmName in pairs(tempTableRealms) do -- cycle Unique realms
			if (realmName ~= thisRealm) then
				RestPlus_ToPrint[RestPlus_ToPrintIndex] = realmName;
				RestPlus_ToPrintColor[RestPlus_ToPrintIndex] = RESTPLUS_COLOR_OTHERSERVER;
				RestPlus_ToPrintIndex = RestPlus_ToPrintIndex + 1;
				for i = toSortIndex - 1, 0, -1 do
					if (RestPlus_RealmList[i]==realmName) then
						RestPlus_ToPrint[RestPlus_ToPrintIndex] = "  "; -- EMERALD: Indent
						local first = strfind(toSort[i], "=", 1);
						RestPlus_ToPrint[RestPlus_ToPrintIndex] = strsub(toSort[i], first + 1);
						first = strfind (RestPlus_ToPrint[RestPlus_ToPrintIndex] , "=", 1);
						local color = strsub(RestPlus_ToPrint[RestPlus_ToPrintIndex] , first + 1);
						RestPlus_ToPrint[RestPlus_ToPrintIndex] = strsub(RestPlus_ToPrint[RestPlus_ToPrintIndex] , 1, first - 1);
						RestPlus_ToPrintColor[RestPlus_ToPrintIndex] = color;
						RestPlus_ToPrintIndex = RestPlus_ToPrintIndex + 1;
					end
				end
			end
		end
		
	-- EMERALD End
	-- for i = toSortIndex - 1, 0, -1 do
		-- local first = strfind(toSort[i], "=", 1);
		-- RestPlus_ToPrint[RestPlus_ToPrintIndex] = strsub(toSort[i], first + 1);
		-- first = strfind (RestPlus_ToPrint[RestPlus_ToPrintIndex] , "=", 1);
		-- local color = strsub(RestPlus_ToPrint[RestPlus_ToPrintIndex] , first + 1);
		-- RestPlus_ToPrint[RestPlus_ToPrintIndex] = strsub(RestPlus_ToPrint[RestPlus_ToPrintIndex] , 1, first - 1);		
		-- RestPlus_ToPrintColor[RestPlus_ToPrintIndex] = color;
		-- RestPlus_ToPrintIndex = RestPlus_ToPrintIndex + 1;
	-- end
end

function RestPlus_DisplayChatList()
	local i;
	RestPlus_Sort();
	for i = 0, RestPlus_ToPrintIndex - 1 do
		u:Print(RestPlus_ToPrint[i], RestPlus_ToPrintColor[i]);
	end
end

-- Class declarations
-- Utility class provides print (to the chat box) and echo (displays over your character's head).
-- Instantiate it and use the colon syntax.
-- Color is an optional argument.  You can either use one of 7 named colors
-- "red", "green", "blue", "yellow", "cyan", "magenta", "white" or
-- a table with the r, g, b values.
-- IE foo:Print("some text", {r = 1.0, g=1.0, b=.5})

-- if there is an existing Utility Class version of equal or greater version, don't declare.
if not Utility_Class or (not Utility_Class.version) or (Utility_Class.version < 1.02) then
	Utility_Class = {};
	Utility_Class.version = 1.02
	function Utility_Class:New ()
		local o = {}   -- create object
		setmetatable(o, self)
		self.__index = self
		return o
	end
	
	function Utility_Class:Print(msg, color)
	local text;
	local r, g, b;
		if msg == nil then return; end
		if color == nil then color = "white"; end
		if (color=="grey") then
			r = 0.6; g = 0.6; b = 0.6;
		elseif (color=="offwhite") then
			r = 0.85; g = 0.85; b = 0.85;
		else
			r, g, b = self.GetColor(color);
		end
		
		if( DEFAULT_CHAT_FRAME ) then
			DEFAULT_CHAT_FRAME:AddMessage(msg,r,g,b);
			--DEFAULT_CHAT_FRAME:AddMessage(msg,1.0,0.0,1.0);
		end
		
	end
	
	function Utility_Class:Echo(msg, color)
	local text;
	local r, g, b;
		if msg == nil then return; end
		if color == nil then color = "white"; end
		r, g, b = self.GetColor(color);
		
		UIErrorsFrame:AddMessage(msg, r, g, b, 1.0, UIERRORS_HOLD_TIME);
		
	end
	
	function Utility_Class:GetColor(color)
		if color == nil then color = self; end
		if color == nil then return 0, 0, 0 end
	
		if type(color) == "string" then 
			color = Utility_Class.ColorList[string.lower(color)];
		end
		
		if type(color) == "table" then
			if color.r == nil then color.r = 0.0 end
			if color.g == nil then color.g = 0.0 end
			if color.b == nil then color.g = 0.0 end
		else
			return 0, 0, 0 
		end
	
		if color.r < 0 then color.r = 0.0 end
		if color.g < 0 then color.g = 0.0 end
		if color.b < 0 then color.g = 0.0 end
	
		if color.r > 1 then color.r = 1.0 end
		if color.g > 1 then color.g = 1.0 end
		if color.b > 1 then color.g = 1.0 end
		
		return color.r, color.g, color.b
		
	end
	
	Utility_Class.ColorList = {}
	Utility_Class.ColorList["red"] = { r = 1.0, g = 0.0, b = 0.0 }
	Utility_Class.ColorList["salmon"] = { r = 1.0, g = 0.63, b = 0.48 }
	Utility_Class.ColorList["purple"] = { r = 0.54, g = 0.00, b = 0.54 }
	Utility_Class.ColorList["forestgreen"] = { r = 0.13, g = 0.54, b = 0.13 }
	Utility_Class.ColorList["green"] = { r = 0.0, g = 1.0, b = 0.0 }
	Utility_Class.ColorList["blue"] = { r = 0.0, g = 0.0, b = 1.0 }
	Utility_Class.ColorList["white"] = { r = 1.0, g = 1.0, b = 1.0 }
	Utility_Class.ColorList["magenta"] = { r = 1.0, g = 0.0, b = 1.0 }
	Utility_Class.ColorList["yellow"] = { r = 1.0, g = 1.0, b = 0.0 }
	Utility_Class.ColorList["khaki"] = { r = 0.8, g = 0.78, b = 0.45 }
	Utility_Class.ColorList["lightolive"] = { r = 0.79, g = 1.0, b = 0.44 }
	Utility_Class.ColorList["olive"] = { r = 0.5, g = 0.5, b = 0.0 }
	Utility_Class.ColorList["orange"] = { r = 1.0, g = 0.6, b = 0.0 }
	Utility_Class.ColorList["cyan"] = { r = 0.0, g = 1.0, b = 1.0 }
	Utility_Class.ColorList["blue"] = { r = 0.0, g = 0.0, b = 1.0 }
	Utility_Class.ColorList["skyblue"] = { r = 0.0, g = .75, b = 1.0 }
	Utility_Class.ColorList["orange"] = { r = 1.0, g = 0.6, b = 0.0 }
	Utility_Class.ColorList["offwhite"] = { r = 0.85, g = 0.85, b = 0.85 }
	Utility_Class.ColorList["grey"] = { r = 0.6, g = 0.6, b = 0.6 }
end

function RestPlus_Debug(message)
	if (RPDEBUG and DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("DEBUG: "..message);
	end
end

function RestPlus_DumpData(index)
	if (not RPDEBUG) then
		return;
	end
	u:Print("Level: "..RestPlus_Data[index].level);
	u:Print("Class: "..RestPlus_Data[index].class);
	u:Print("Race: "..RestPlus_Data[index].race);
	u:Print("CurrXP: "..RestPlus_Data[index].currXP);
	u:Print("NextXP: "..RestPlus_Data[index].nextXP);
	u:Print("RestXP: "..RestPlus_Data[index].restXP);
	u:Print("Resting: "..RestPlus_Data[index].resting);
	u:Print("Logtime: "..RestPlus_Data[index].logtime);
	u:Print("Rest XP %: "..RestPlus_ActiveCharXP);
	u:Print("Rest XP: "..RestPlus_ActiveCharXPRaw);
end

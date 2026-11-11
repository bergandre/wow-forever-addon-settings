-- InstanceAtlas 0.6.1 - custom instance atlas (WoW Forever)
local frame = CreateFrame("Frame")
local panel
local bossPins, bossRows = {}, {}
local entryPins = {}
local MAP_W, MAP_H = 544, 488
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 1, 2.5, 0.25
local currentZoom, centerX, centerY = 1, 0.5, 0.5
local currentData

local DATA = {
  ["Blackfathom Deeps"] = {
    kind = "dungeon",
    map = "BlackfathomDeeps_Floor1",
    floors = { { map="BlackfathomDeeps_Floor1", imageW=1002, imageH=668, label="1" }, { map="BlackfathomDeeps_Floor2", imageW=1002, imageH=668, label="2" }, { map="BlackfathomDeeps_Floor3", imageW=1002, imageH=668, label="3" } },
    bosses = {
      "Baron Aquanis",
      "Ghamoo-ra",
      "Lady Sarevess",
      "Gelihast",
      "Lorgus Jett",
      "Old Serra'kis",
      "Twilight Lord Kelris",
      "Aku'mai",
    },
  },
  ["Blackrock Depths"] = {
    kind = "dungeon",
    bosses = {
      "High Interrogator Gerstahn",
      "Lord Roccor",
      "Houndmaster Grebmar",
      "Ring of Law",
      "Pyromancer Loregrain",
      "Lord Incendius",
      "Warder Stilgiss",
      "Fineous Darkvire",
      "Bael'Gar",
      "General Angerforge",
      "Golem Lord Argelmach",
      "Hurley Blackbreath",
      "Phalanx",
      "Ribbly Screwspigot",
      "Plugger Spazzring",
      "The Vault",
      "Ambassador Flamelash",
      "The Seven",
      "Magmus",
      "Princess Moira Bronzebeard",
      "Emperor Dagran Thaurissan",
    },
  },
  ["Blackrock Spire"] = {
    kind = "dungeon",
    bosses = {
      "Highlord Omokk",
      "Shadow Hunter Vosh'gajin",
      "War Master Voone",
      "Mother Smolderweb",
      "Urok Doomhowl",
      "Quartermaster Zigris",
      "Halycon",
      "Gizrul the Slavener",
      "Overlord Wyrmthalak",
      "Pyroguard Emberseer",
      "Warchief Rend Blackhand",
      "The Beast",
      "General Drakkisath",
      "Lord Valthalak",
    },
  },
  ["City of Dalaran"] = {
    kind = "dungeon",
    bosses = {
      "Arcane Anomaly",
      "Fel Ancient",
      "Mana Devourer",
      "Mana Elemental",
      "Unstable Sentinel",
      "Shade of the Archmage",
      "Lyn the Ignored",
      "Atrexis the Grave Knight",
      "Mana Wraith",
    },
  },
  ["Deadmines"] = {
    kind = "dungeon",
    note = "Using the map image supplied for InstanceAtlas. Boss portraits are listed; map positions have not been independently verified.",
    map = "Deadmines_Floor1",
    floors = { { map="Deadmines_Floor1", imageW=1002, imageH=668, label="1" }, { map="Deadmines_Floor2", imageW=1002, imageH=668, label="2" } },
    bosses = {
      { name="Rhak'Zor", icon="Deadmines_rhakzor", size=38 },
      { name="Sneed + Shredder", icon="Deadmines_sneeds-shredder", size=38 },
      { name="Gilnid", icon="Deadmines_gilnid", size=38 },
      { name="Mr. Smite", icon="Deadmines_mr-smite", size=38 },
      { name="Captain Greenskin", icon="Deadmines_captain-greenskin", size=38 },
      { name="Edwin Vancleef", icon="Deadmines_edwin-vancleef", size=38 },
      { name="Cookie", icon="Deadmines_cookie", size=38 },
      { name="Miner Johnson", icon="Deadmines_unnamed-lvl19", size=38 },
    },
  },
  ["Demon Fall Canyon"] = {
    kind = "dungeon",
    bosses = {
      "Grimroot",
      "Destructor's Wraith",
      "Zilbagob",
      "Pyranis",
      "Diathorus the Seeker",
      "Hellscream's Phantom",
      "Azgaloth",
    },
  },
  ["Dire Maul"] = {
    kind = "dungeon",
    bosses = {
      "Zevrim Thornhoof",
      "Hydrospawn",
      "Lethtendris",
      "Pusillin",
      "Alzzin the Wildshaper",
      "Tendris Warpwood",
      "Illyanna Ravenoak",
      "Magister Kalendris",
      "Immol'thar",
      "Prince Tortheldrin",
      "Guard Mol'dar",
      "Stomper Kreeg",
      "Guard Fengus",
      "Guard Slip'kik",
      "Captain Kromcrush",
      "Cho'Rush the Observer",
      "King Gordok",
      "Lord Hel'nurath",
      "Tsu'zee",
    },
  },
  ["Excavation Site: Wetlands"] = {
    kind = "dungeon",
    bosses = {
      "Saltspine",
      "Shadetooth",
      "Highland Horror",
      "Relic Guardian",
    },
  },
  ["Gnomeregan"] = {
    kind = "dungeon",
    map = "Gnomeregan_Floor1",
    floors = { { map="Gnomeregan_Floor1", imageW=1002, imageH=668, label="1" }, { map="Gnomeregan_Floor2", imageW=1002, imageH=668, label="2" }, { map="Gnomeregan_Floor3", imageW=1002, imageH=668, label="3" }, { map="Gnomeregan_Floor4", imageW=1002, imageH=668, label="4" } },
    bosses = {
      "Grubbis",
      "Viscous Fallout",
      "Electrocutioner 6000",
      "Crowd Pummeler 9-60",
      "Mekgineer Thermaplugg",
      "Mechanical Menagerie",
    },
  },
  ["Karazhan Crypts"] = {
    kind = "dungeon",
    bosses = {
      "Harbinger of Sin",
      "Creeping Malison",
      "Three Little Wolves",
      "Dark Rider",
      "Kharon",
      "Unk'omon",
      "Hans and Greta",
      "The Ugly Goblin",
      "Kaigy Maryla",
      "Sairuh Maryla",
      "Barian Maryla",
    },
  },
  ["Maraudon"] = {
    kind = "dungeon",
    bosses = {
      "Noxxion",
      "Razorlash",
      "Tinkerer Gizlock",
      "Lord Vyletongue",
      "Celebras the Cursed",
      "Landslide",
      "Rotgrip",
      "Princess Theradras",
    },
  },
  ["Razorfen Downs"] = {
    kind = "dungeon",
    bosses = {
      "Tuten'kash",
      "Plaguemaw the Rotting",
      "Mordresh Fire Eye",
      "Ragglesnout",
      "Glutton",
      "Amnennar the Coldbringer",
    },
  },
  ["Razorfen Kraul"] = {
    kind = "dungeon",
    map = "RazorfenKraul",
    floors = { { map="RazorfenKraul", imageW=1002, imageH=668, label="1" } },
    bosses = {
      "Roogug",
      "Aggem Thorncurse",
      "Death Speaker Jargba",
      "Overlord Ramtusk",
      "Agathelos the Raging",
      "Charlga Razorflank",
    },
  },
  ["Ruins of Lordaeron"] = {
    kind = "dungeon",
    note = "Using the map image supplied for InstanceAtlas. Boss portraits are listed; map positions have not been independently verified.",
    map = "RuinsofLordaeron",
    floors = { { map="RuinsofLordaeron", imageW=2048, imageH=1365, label="1" } },
    bosses = {
      { name="The Baron", icon="RuinsOfLordaeron_the-baron", size=38 },
      { name="Witherfang", icon="RuinsOfLordaeron_witherfang", size=38 },
      { name="Viktor The Vile", icon="RuinsOfLordaeron_viktor-the-vile", size=38 },
      { name="Bjork", icon="RuinsOfLordaeron_bjork", size=38 },
      { name="Rath'mael", icon="RuinsOfLordaeron_rath-mael", size=38 },
      { name="The Abandoned", icon="RuinsOfLordaeron_the-abandoned", size=38 },
    },
  },
  ["Scarlet Monastery"] = {
    kind = "dungeon",
    map = "ScarletMonastery_Graveyard",
    floors = { { map="ScarletMonastery_Graveyard", imageW=1002, imageH=668, label="Graveyard" }, { map="ScarletMonastery_Library", imageW=1002, imageH=668, label="Library" }, { map="ScarletMonastery_Armory", imageW=1002, imageH=668, label="Armory" }, { map="ScarletMonastery_Cathedral", imageW=1002, imageH=668, label="Cathedral" } },
    bosses = {
      "Interrogator Vishas",
      "Bloodmage Thalnos",
      "Houndmaster Loksey",
      "Arcanist Doan",
      "Herod",
      "High Inquisitor Fairbanks",
      "High Inquisitor Whitemane",
    },
  },
  ["Scholomance"] = {
    kind = "dungeon",
    bosses = {
      "Kirtonos",
      "Jandice Barov",
      "Rattlegore",
      "Marduk Blackpool",
      "Vectus",
      "Kormok",
      "Ras Frostwhisperer",
      "Instructor Malicia",
      "Doctor Theolen Krastinov",
      "Lorekeeper Polkelt",
      "The Ravenian",
      "Lord Alexei Barov",
      "Lady Illucia Barov",
      "Darkmaster Gandling",
    },
  },
  ["Shadowfang Keep"] = {
    kind = "dungeon",
    map = "ShadowfangKeep_Floor1",
    floors = { { map="ShadowfangKeep_Floor1", imageW=1002, imageH=668, label="1" }, { map="ShadowfangKeep_Floor2", imageW=1002, imageH=668, label="2" }, { map="ShadowfangKeep_Floor3", imageW=1002, imageH=668, label="3" }, { map="ShadowfangKeep_Floor4", imageW=1002, imageH=668, label="4" } },
    bosses = {
      "Rethilgore",
      "Razorclaw the Butcher",
      "Baron Silverlaine",
      "Commander Springvale",
      "Odo the Blindwatcher",
      "Fenrus the Devourer",
      "Wolf Master Nandos",
      "Archmage Arugal",
    },
  },
  ["Stormwind Stockade"] = {
    kind = "dungeon",
    bosses = {
      "Targorr the Dread",
      "Kam Deepfury",
      "Hamhock",
      "Dextren Ward",
      "Bazil Thredd",
    },
  },
  ["Stratholme"] = {
    kind = "dungeon",
    bosses = {
      "Hearthsinger Forresten",
      "Timmy the Cruel",
      "Malor the Zealous",
      "Cannon Master Willey",
      "Archivist Galford",
      "Balnazzar",
      "The Unforgiven",
      "Baroness Anastari",
      "Nerub'enkan",
      "Maleki the Pallid",
      "Magistrate Barthilas",
      "Ramstein the Gorger",
      "Baron Rivendare",
      "Black Guard Swordsmith",
      "Crimson Hammersmith",
      "Ezra Grimm",
      "Postmaster Malown",
      "Skul",
      "Stonespine",
    },
  },
  ["Sunken Temple"] = {
    kind = "dungeon",
    bosses = {
      "Avatar of Hakkar",
      "Jammal'an the Prophet",
      "Dreamscythe",
      "Festering Rotslime",
      "Weaver",
      "Atal'ai Defenders",
      "Dreamscythe and Weaver",
      "Morphaz",
      "Jammal'an and Ogom",
      "Hazzas",
      "Morphaz and Hazzas",
      "Shade of Eranikus",
      "Atal'alarion",
    },
  },
  ["Hall of Thanes"] = {
    kind = "dungeon",
    map = "HallofThanes",
    floors = { { map="HallofThanes", imageW=2048, imageH=1365, label="1" } },
    bosses = {
      "Faldrim Anvilmar",
      "Magmatus",
      "Plunder",
      "Durgen Dirgehammer",
    },
  },
  ["Uldaman"] = {
    kind = "dungeon",
    bosses = {
      "Revelosh",
      "The Lost Dwarves",
      "Ironaya",
      "Obsidian Sentinel",
      "Ancient Stone Keeper",
      "Galgann Firehammer",
      "Grimlok",
      "Archaedas",
    },
  },
  ["Wailing Caverns"] = {
    kind = "dungeon",
    note = "Using the map image supplied for InstanceAtlas. Boss portraits are listed; map positions have not been independently verified.",
    map = "WailingCaverns",
    floors = { { map="WailingCaverns", imageW=1000, imageH=667, label="1" } },
    bosses = {
      { name="Lady Anacondra", icon="WailingCaverns_lady-anacondra", size=38 },
      { name="Lady Anacondra", icon="WailingCaverns_lady-anacondra", size=38 },
      { name="Lady Anacondra", icon="WailingCaverns_lady-anacondra", size=38 },
      { name="Lady Anacondra", icon="WailingCaverns_lady-anacondra", size=38 },
      { name="Lord Pythas", icon="WailingCaverns_lord-pythas", size=38 },
      { name="Skum", icon="WailingCaverns_skum", size=38 },
      { name="Lord Serpentis", icon="WailingCaverns_lord-serpentis", size=38 },
      { name="Verdan the Everliving", icon="WailingCaverns_verdan-the-everliving", size=38 },
      { name="Mutanus the Devourer", icon="WailingCaverns_mutanus-the-devourer", size=38 },
      { name="Kresh", icon="WailingCaverns_kresh", size=38 },
      { name="Lord Cobrahn", icon="WailingCaverns_lord-cobrahn", size=38 },
    },
  },
  ["Zul'Farrak"] = {
    kind = "dungeon",
    bosses = {
      "Hydromancer Velratha",
      "Gahz'rilla",
      "Antu'sul",
      "Theka the Martyr",
      "Witch Doctor Zum'rah",
      "Nekrum Gutchewer",
      "Shadowpriest Sezz'ziz",
      "Chief Ukorz Sandscalp",
    },
  },
  ["Ahn'Qiraj Temple"] = {
    kind = "raid",
    bosses = {
      "The Prophet Skeram",
      "Silithid Royalty",
      "Battleguard Sartura",
      "Fankriss the Unyielding",
      "Viscidus",
      "Princess Huhuran",
      "Twin Emperors",
      "Ouro",
      "C'thun",
    },
  },
  ["Blackwing Lair"] = {
    kind = "raid",
    bosses = {
      "Razorgore the Untamed",
      "Vaelastrasz the Corrupt",
      "Broodlord Lashlayer",
      "Firemaw",
      "Ebonroc",
      "Flamegor",
      "Chromaggus",
      "Nefarian",
    },
  },
  ["Molten Core"] = {
    kind = "raid",
    bosses = {
      "Lucifron",
      "Magmadar",
      "Gehennas",
      "Garr",
      "Shazzrah",
      "Baron Geddon",
      "Sulfuron Harbinger",
      "Golemagg the Incinerator",
      "Majordomo Executus",
      "Ragnaros",
      "The Molten Core",
    },
  },
  ["Nightmare Grove"] = {
    kind = "raid",
    bosses = {
      "Emeriss",
      "Lethon",
      "Taerar",
      "Ysondre",
    },
  },
  ["Onyxia's Lair"] = {
    kind = "raid",
    bosses = {
      "Onyxia",
    },
  },
  ["Ruins of Ahn'Qiraj"] = {
    kind = "raid",
    bosses = {
      "Kurinnaxx",
      "General Rajaxx",
      "Moam",
      "Buru the Gorger",
      "Ayamiss the Hunter",
      "Ossirian the Unscarred",
    },
  },
  ["Scarlet Enclave"] = {
    kind = "raid",
    bosses = {
      "Balnazzar",
      "Beatrix",
      "Beastmaster",
      "Solistrasza",
      "Mason",
      "Reborn Council",
      "Lillian Voss",
      "Caldoran",
    },
  },
  ["Storm Cliffs"] = {
    kind = "raid",
    bosses = {
      "Azuregos",
    },
  },
  ["The Crystal Vale"] = {
    kind = "raid",
    bosses = {
      "Prince Thunderaan",
    },
  },
  ["The Tainted Scar"] = {
    kind = "raid",
    bosses = {
      "Lord Kazzak",
    },
  },
  ["Zul'Gurub"] = {
    kind = "raid",
    bosses = {
      "High Priestess Jeklik",
      "High Priest Venoxis",
      "High Priestess Mar'li",
      "Bloodlord Mandokir",
      "Edge of Madness",
      "High Priest Thekal",
      "Gahz'ranka",
      "High Priestess Arlokk",
      "Jin'do the Hexxer",
      "Hakkar",
    },
  },
  ["Naxxramas"] = {
    kind = "raid",
    bosses = {
      "Anub'Rekhan",
      "Grand Widow Faerlina",
      "Maexxna",
      "Noth the Plaguebringer",
      "Heigan the Unclean",
      "Loatheb",
      "Instructor Razuvious",
      "Gothik the Harvester",
      "The Four Horsemen",
      "Patchwerk",
      "Grobbulus",
      "Gluth",
      "Thaddius",
      "Sapphiron",
      "Kel'Thuzad",
    },
  },
  ["Burning of Andorhal"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Caverns of Time"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Deadwind Pass"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Manor Mistmantle"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Shadow Hold"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Starfall Barrow Den"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["The Scarab Dais"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["The Searing Basin"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Testwerk"] = {
    kind = "dungeon",
    bosses = {
    },
  },
  ["Ragefire Chasm"] = {
    kind = "dungeon",
    mapID = 389,
    floor = "Floor 1",
    note = "Using the map image supplied for InstanceAtlas. Boss portraits are listed; map positions have not been independently verified.", 
    map = "RagefireChasm",
    floors = { { map="RagefireChasm", imageW=1002, imageH=668, label="1" } },
    bosses = {
      { name="Oggleflint", icon="Oggleflint", order=1 },
      { name="Taragaman the Hungerer", icon="Taragaman", order=2 },
      { name="Jergosh the Invoker", icon="Jergosh", order=3 },
      { name="Bazzalan", icon="Bazzalan", order=4 },
    },
  },
  ["Emerald Dream"] = {
    kind = "raid",
    bosses = {
    },
  },
}

local INSTANCE_ALIASES = {
  ["The Ruins of Lordaeron"] = "Ruins of Lordaeron",
  ["The Hall of Thanes"] = "Hall of Thanes",
  ["The Deadmines"] = "Deadmines",
  ["The Stockade"] = "Stormwind Stockade",
  ["Lower Blackrock Spire"] = "Blackrock Spire",
  ["Upper Blackrock Spire"] = "Blackrock Spire",
  ["Temple of Ahn'Qiraj"] = "Ahn'Qiraj Temple",
  ["The Temple of Ahn'Qiraj"] = "Ahn'Qiraj Temple",
}


InstanceAtlasDB = InstanceAtlasDB or {}
if InstanceAtlasDB.showOnEnter == nil then InstanceAtlasDB.showOnEnter = false end

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff62c5ffInstanceAtlas:|r "..tostring(msg))
  end
end

local function GetInstance()
  local inInstance, instanceType = false, nil
  if IsInInstance then inInstance, instanceType = IsInInstance() end
  local name, infoType, difficulty, difficultyName, maxPlayers, dynamic, isDynamic, instanceID
  if GetInstanceInfo then
    name, infoType, difficulty, difficultyName, maxPlayers, dynamic, isDynamic, instanceID = GetInstanceInfo()
  end
  instanceType = instanceType or infoType
  if (inInstance or instanceType == "party" or instanceType == "raid") and name and name ~= "" then
    return name, instanceType, instanceID
  end
  return nil, instanceType, instanceID
end

local function SetBackdrop(f, color)
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile="Interface/Tooltips/UI-Tooltip-Background",
      edgeFile="Interface/Tooltips/UI-Tooltip-Border",
      tile=true, tileSize=16, edgeSize=12,
      insets={left=3,right=3,top=3,bottom=3}
    })
    f:SetBackdropColor(color[1],color[2],color[3],color[4] or 0.97)
  end
end

local function ClearChildren(list)
  for _, child in ipairs(list) do child:Hide() end
  wipe(list)
end

local function ClampView()
  local half = 0.5 / currentZoom
  centerX = math.max(half, math.min(1-half, centerX))
  centerY = math.max(half, math.min(1-half, centerY))
end

local function UpdateMapView()
  if not panel or not currentData then return end
  ClampView()
  local halfX, halfY = 0.5/currentZoom, 0.5/currentZoom
  local left, right = centerX-halfX, centerX+halfX
  local top, bottom = centerY-halfY, centerY+halfY
  -- Ragefire Chasm source map is landscape (892 x 799); preserve its native aspect ratio.
  panel.map:SetTexCoord(left, right, top, bottom)
  for i,pin in ipairs(entryPins) do
    local e=currentData.entries and currentData.entries[i]
    if e then
      local ex=(e.x-left)/(right-left)*MAP_W
      local ey=(e.y-top)/(bottom-top)*MAP_H
      pin:ClearAllPoints()
      pin:SetPoint("CENTER",panel.mapArea,"TOPLEFT",ex,-ey)
      if ex < -60 or ex > MAP_W+60 or ey < -30 or ey > MAP_H+30 then pin:Hide() else pin:Show() end
    else
      pin:Hide()
    end
  end
  for i,boss in ipairs(currentData.bosses) do
    local pin=bossPins[i]
    if type(boss)=="table" and pin and boss.x and boss.y then
      local px=(boss.x-left)/(right-left)*MAP_W
      local py=(boss.y-top)/(bottom-top)*MAP_H
      pin:ClearAllPoints()
      pin:SetPoint("CENTER",panel.mapArea,"TOPLEFT",px,-py)
      if px < -20 or px > MAP_W+20 or py < -20 or py > MAP_H+20 then pin:Hide() else pin:Show() end
    elseif pin then
      pin:Hide()
    end
  end
  if panel.zoomText then panel.zoomText:SetText(string.format("%d%%",math.floor(currentZoom*100+0.5))) end
end

local function SetZoom(value, focusX, focusY)
  local oldZoom=currentZoom
  value=math.max(ZOOM_MIN,math.min(ZOOM_MAX,value))
  if value==oldZoom then return end
  focusX=focusX or centerX
  focusY=focusY or centerY
  -- Keep the chosen map point under the viewport centre while changing zoom.
  local ratio=oldZoom/value
  centerX=focusX+(centerX-focusX)*ratio
  centerY=focusY+(centerY-focusY)*ratio
  currentZoom=value
  UpdateMapView()
end

local function SelectBoss(index, center)
  local boss=currentData and currentData.bosses[index]
  if type(boss)=="string" then boss={name=boss,room="Boss location not yet verified on supplied map"} end
  if not boss or not panel then return end
  panel.selectedBoss=index
  panel.detail:SetText(boss.name.."\n"..(boss.room or "Boss location not yet verified on supplied map"))
  for i,row in ipairs(bossRows) do
    local entry=currentData.bosses[i]
    local entryName=type(entry)=="table" and entry.name or entry
    if i==index then row.text:SetText("|cffffd27f"..i..". "..entryName.."|r")
    else row.text:SetText(i..". "..entryName) end
  end
  for i,pin in ipairs(bossPins) do
    if i==index then
      pin:SetSize(46,46)
      pin.icon:SetAlpha(1)
    else
      pin:SetSize(boss.size or 38,boss.size or 38)
      pin.icon:SetAlpha(0.92)
    end
  end
  if center and boss.x and boss.y then
    centerX,centerY=boss.x,boss.y
    if currentZoom<1.5 then currentZoom=1.5 end
    UpdateMapView()
  end
end

local function MakePanel()
  if panel then return end
  panel=CreateFrame("Frame","InstanceAtlasPanel",UIParent)
  panel:SetSize(950,625)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel(50)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart",panel.StartMoving)
  panel:SetScript("OnDragStop",panel.StopMovingOrSizing)

  panel.opaque=panel:CreateTexture(nil,"BACKGROUND")
  panel.opaque:SetAllPoints()
  panel.opaque:SetColorTexture(0.015,0.025,0.04,0.995)

  panel.title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  panel.title:SetPoint("TOPLEFT",18,-14)
  panel.title:SetText("|cffffd84aINSTANCE ATLAS|r")

  panel.subtitle=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
  panel.subtitle:SetPoint("TOPLEFT",panel.title,"BOTTOMLEFT",0,-7)

  local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",-3,-3)
  close:SetScript("OnClick",function() panel:Hide() end)

  panel.mapArea=CreateFrame("Frame",nil,panel)
  panel.mapArea:SetSize(MAP_W,MAP_H)
  panel.mapArea:SetPoint("TOPLEFT",18,-68)
  panel.mapArea:EnableMouse(true)
  panel.mapArea:EnableMouseWheel(true)
  panel.mapArea.bg=panel.mapArea:CreateTexture(nil,"BACKGROUND")
  panel.mapArea.bg:SetAllPoints()
  panel.mapArea.bg:SetColorTexture(0.035,0.045,0.055,1)
  panel.map=panel.mapArea:CreateTexture(nil,"ARTWORK")
  panel.map:SetAllPoints(panel.mapArea)
  panel.map:SetTexCoord(0,1,0.125,0.875)

  panel.mapArea:SetScript("OnMouseWheel",function(self,delta)
    local step=delta>0 and ZOOM_STEP or -ZOOM_STEP
    SetZoom(currentZoom+step)
  end)
  panel.mapArea:SetScript("OnMouseDown",function(self,button)
    if button=="LeftButton" then
      local scale=UIParent:GetEffectiveScale()
      local cx,cy=GetCursorPosition()
      self.dragStartX=cx/scale
      self.dragStartY=cy/scale
      self.dragCenterX=centerX
      self.dragCenterY=centerY
      self:SetScript("OnUpdate",function(area)
        if not IsMouseButtonDown("LeftButton") then
          area:SetScript("OnUpdate",nil)
          return
        end
        local s=UIParent:GetEffectiveScale()
        local x,y=GetCursorPosition()
        local dx=(x/s-area.dragStartX)/MAP_W/currentZoom
        local dy=(area.dragStartY-y/s)/MAP_H/currentZoom
        centerX=area.dragCenterX-dx
        centerY=area.dragCenterY-dy
        UpdateMapView()
      end)
    end
  end)
  panel.mapArea:SetScript("OnMouseUp",function(self)
    self:SetScript("OnUpdate",nil)
  end)

  panel.side=CreateFrame("Frame",nil,panel)
  panel.side:SetSize(245,MAP_H)
  panel.side:SetPoint("TOPLEFT",panel.mapArea,"TOPRIGHT",14,0)

  panel.bossHeader=panel.side:CreateFontString(nil,"OVERLAY","GameFontNormal")
  panel.bossHeader:SetPoint("TOPLEFT",0,0)
  panel.bossHeader:SetText("|cffffd84aBOSSES|r")

  panel.detail=panel.side:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  panel.detail:SetPoint("BOTTOMLEFT",0,8)
  panel.detail:SetWidth(240)
  panel.detail:SetJustifyH("LEFT")
  panel.detail:SetText("Select a boss to centre the map on its room.")
  panel.roster=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  panel.roster:SetPoint("TOPLEFT",18,-78)
  panel.roster:SetWidth(900)
  panel.roster:SetHeight(470)
  panel.roster:SetJustifyH("LEFT")
  panel.roster:SetJustifyV("TOP")
  panel.roster:Hide()

  panel.status=panel:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
  panel.status:SetPoint("BOTTOMLEFT",18,12)
  panel.status:SetWidth(910)
  panel.status:SetJustifyH("LEFT")

  local zoomOut=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
  zoomOut:SetSize(34,24)
  zoomOut:SetPoint("BOTTOMLEFT",panel.mapArea,"TOPLEFT",0,5)
  zoomOut:SetText("-")
  zoomOut:SetScript("OnClick",function() SetZoom(currentZoom-ZOOM_STEP) end)
  local zoomIn=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
  zoomIn:SetSize(34,24)
  zoomIn:SetPoint("LEFT",zoomOut,"RIGHT",4,0)
  zoomIn:SetText("+")
  zoomIn:SetScript("OnClick",function() SetZoom(currentZoom+ZOOM_STEP) end)
  local reset=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
  reset:SetSize(64,24)
  reset:SetPoint("LEFT",zoomIn,"RIGHT",4,0)
  reset:SetText("Reset")
  reset:SetScript("OnClick",function()
    currentZoom,centerX,centerY=1,0.5,0.5
    UpdateMapView()
  end)
  panel.floorButtons={}
  panel.zoomText=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  panel.zoomText:SetPoint("LEFT",reset,"RIGHT",8,0)
  panel.zoomText:SetText("100%")
end


local function ApplyFloor(index)
  if not currentData or not currentData.floors or not currentData.floors[index] then return end
  local floor=currentData.floors[index]
  currentData.currentFloor=index
  currentData.map=floor.map
  currentData.imageW=floor.imageW
  currentData.imageH=floor.imageH
  local aspect=floor.imageW/floor.imageH
  MAP_W,MAP_H=544,544/aspect
  if MAP_H>488 then MAP_H=488; MAP_W=MAP_H*aspect end
  panel.mapArea:SetSize(MAP_W,MAP_H)
  panel.side:SetSize(245,MAP_H)
  panel.map:SetTexture("Interface\\AddOns\\InstanceAtlas\\Maps\\"..floor.map..".tga")
  panel.map:SetTexCoord(0,1,0,1)
  currentZoom,centerX,centerY=1,0.5,0.5
  for i,button in ipairs(panel.floorButtons or {}) do
    if i==index then button:SetText("|cffffd84a"..(floor.label or tostring(i)).."|r")
    else button:SetText(floor.label or tostring(i)) end
  end
  UpdateMapView()
end

local function BuildBossUI(data)
  ClearChildren(bossPins)
  ClearChildren(bossRows)
  for _,pin in ipairs(entryPins) do pin:Hide() end
  currentData=data
  for i,e in ipairs(data.entries or {}) do
    local pin=entryPins[i]
    if not pin then
      pin=CreateFrame("Frame",nil,panel.mapArea)
      pin:SetSize(92,22)
      pin.text=pin:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      pin.text:SetPoint("CENTER")
      pin.text:SetShadowOffset(1,-1)
      pin.text:SetShadowColor(0,0,0,1)
      pin:SetFrameLevel(panel.mapArea:GetFrameLevel()+8)
      entryPins[i]=pin
    end
    pin.text:SetText("|cff70e0a0"..(e.label or "ENTRY / EXIT").."|r")
    pin:Show()
  end
  for i,boss in ipairs(data.bosses) do
    local index,bossEntry=i,boss
    if type(bossEntry)=="string" then bossEntry={name=bossEntry,room="Boss location not yet verified on supplied map"} end
    local pin
    if bossEntry.x and bossEntry.y then
    pin=CreateFrame("Button",nil,panel.mapArea)
    pin:SetSize(bossEntry.size or 38,bossEntry.size or 38)
    pin.icon=pin:CreateTexture(nil,"ARTWORK")
    pin.icon:SetAllPoints()
    pin.icon:SetTexture("Interface\\AddOns\\InstanceAtlas\\Maps\\Bosses\\"..(bossEntry.icon or "Oggleflint")..".tga")
    pin:SetScript("OnClick",function() SelectBoss(index,true) end)
    pin:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:AddLine(bossEntry.name,1,0.82,0.45)
      GameTooltip:AddLine(bossEntry.room,1,1,1,true)
      GameTooltip:Show()
    end)
    pin:SetScript("OnLeave",GameTooltip_Hide)
    bossPins[#bossPins+1]=pin
    end

    local row=CreateFrame("Button",nil,panel.side)
    row:SetSize(240,29)
    row:SetPoint("TOPLEFT",0,-27-(i-1)*33)
    row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    row.text:SetPoint("LEFT",2,0)
    row.text:SetJustifyH("LEFT")
    row.text:SetText(i..". "..bossEntry.name)
    row:SetScript("OnClick",function() SelectBoss(index,true) end)
    bossRows[#bossRows+1]=row
  end
  currentZoom,centerX,centerY=1,0.5,0.5
  UpdateMapView()
  if #data.bosses>0 then SelectBoss(1,false) end
end

local function OpenAtlas()
  local name,instanceType,instanceID=GetInstance()
  if not name then
    Print("You must be inside a dungeon or raid. Use /ia debug for diagnostics.")
    return
  end
  MakePanel()
  panel.subtitle:SetText(name.."  |  "..tostring(instanceType or "instance").."  |  ID "..tostring(instanceID or "unknown"))
  local data=DATA[name] or DATA[INSTANCE_ALIASES[name]]
  if data then
    currentData=data
    panel.roster:Hide()
    panel.side:Hide()
    ClearChildren(bossPins)
    ClearChildren(bossRows)
    if data.map then
      panel.side:SetPoint("TOPLEFT",panel.mapArea,"TOPRIGHT",14,0)
      panel.mapArea:Show()
      panel.side:Show()
      if data.floors then
        panel.floorButtons=panel.floorButtons or {}
        for i,b in ipairs(panel.floorButtons) do b:Hide() end
        for i,floor in ipairs(data.floors) do
          local b=panel.floorButtons[i]
          if not b then
            b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            b:SetSize(42,22)
            panel.floorButtons[i]=b
          end
          b:ClearAllPoints()
          b:SetPoint("BOTTOMRIGHT",panel.mapArea,"TOPRIGHT",-((#data.floors-i)*46),5)
          b:SetText(floor.label or tostring(i))
          b:SetScript("OnClick",function() ApplyFloor(i) end)
          b:Show()
        end
        ApplyFloor(1)
      else
        for _,b in ipairs(panel.floorButtons or {}) do b:Hide() end
        local aspect=(data.imageW or 892)/(data.imageH or 799)
        MAP_W,MAP_H=544,544/aspect
        if MAP_H>488 then MAP_H=488; MAP_W=MAP_H*aspect end
        panel.mapArea:SetSize(MAP_W,MAP_H)
        panel.side:SetSize(245,MAP_H)
        panel.map:SetTexture("Interface\\AddOns\\InstanceAtlas\\Maps\\"..data.map..".tga")
        panel.map:SetTexCoord(0,1,0,1)
      end
      BuildBossUI(data)
      panel.status:SetText((data.note or "Using the map supplied for InstanceAtlas.").."  Boss positions are shown only when verified; live player tracking is not available yet.")
    else
      panel.map:SetTexture(nil)
      for _,pin in ipairs(entryPins) do pin:Hide() end
      panel.mapArea:Hide()
      local lines={}
      for i,boss in ipairs(data.bosses) do lines[#lines+1]=string.format("%02d. %s",i,boss) end
      local kind=(data.kind=="raid") and "RAID" or "DUNGEON"
      local header=kind.."  |  "..#data.bosses.." CLIENT-LISTED ENCOUNTERS"
      if #lines==0 then
        panel.roster:SetText(header.."\n\nNo encounter names are currently included in this client-derived catalogue entry.")
      else
        panel.roster:SetText(header.."\n\n"..table.concat(lines,"\n"))
      end
      panel.roster:Show()
      local pilot = false
      if pilot then
        panel.status:SetText("PILOT INSTANCE PROFILE LOADED  |  Boss roster is available for in-game detection testing. Floor artwork and Forever-confirmed boss coordinates are not bundled yet; no Cataclysm positions are being presented as accurate.")
      else
        panel.status:SetText("Catalogue profile loaded. A custom floor map and verified boss-room coordinates have not yet been added for this instance.")
      end
    end
  else
    currentData=nil
    panel.map:SetTexture(nil)
    for _,pin in ipairs(entryPins) do pin:Hide() end
    panel.mapArea:Hide()
    panel.side:Hide()
    ClearChildren(bossPins)
    ClearChildren(bossRows)
    panel.roster:SetText("No catalogue entry exists for this instance yet.")
    panel.roster:Show()
    panel.status:SetText("Instance detected, but no InstanceAtlas profile is installed.")
  end
  panel:Show()
end

local function ToggleAtlas()
  if panel and panel:IsShown() then panel:Hide() else OpenAtlas() end
end

SLASH_INSTANCEATLAS1="/instanceatlas"
SLASH_INSTANCEATLAS2="/ia"
SlashCmdList.INSTANCEATLAS=function(msg)
  msg=(msg or ""):lower():match("^%s*(.-)%s*$")
  if msg=="close" then if panel then panel:Hide() end
  elseif msg=="debug" then
    local inInstance,instanceType=false,nil
    if IsInInstance then inInstance,instanceType=IsInInstance() end
    local name,infoType,difficulty,difficultyName,maxPlayers,dynamic,isDynamic,instanceID
    if GetInstanceInfo then name,infoType,difficulty,difficultyName,maxPlayers,dynamic,isDynamic,instanceID=GetInstanceInfo() end
    local x,y,z,posID
    if UnitPosition then x,y,z,posID=UnitPosition("player") end
    Print("DEBUG inInstance="..tostring(inInstance).." type="..tostring(instanceType or infoType).." name="..tostring(name).." instanceID="..tostring(instanceID).." UnitPosition="..tostring(x)..","..tostring(y)..","..tostring(z)..","..tostring(posID))
  else ToggleAtlas() end
end

-- Override the normal M (World Map) key only while inside a dungeon or raid.
-- Outside instances, clearing this addon's override restores the player's normal M binding.
local mapKeyButton=CreateFrame("Button","InstanceAtlasMapKeyButton",UIParent)
mapKeyButton:SetSize(1,1)
mapKeyButton:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",-10,-10)
mapKeyButton:SetAlpha(0)
mapKeyButton:RegisterForClicks("AnyUp")
mapKeyButton:SetScript("OnClick",function()
  -- The override is only installed while inside an instance. Do not gate
  -- this click on GetInstanceInfo(), which can return incomplete data on
  -- some WoW Forever client builds.
  ToggleAtlas()
end)

local mapKeyOverrideActive=false
local function RefreshMapKeyOverride()
  -- Binding changes are protected in combat; retry after PLAYER_REGEN_ENABLED.
  if InCombatLockdown and InCombatLockdown() then return end
  local inInstance, instanceType = false, nil
  if IsInInstance then inInstance, instanceType = IsInInstance() end
  local active = inInstance or instanceType == "party" or instanceType == "raid"
  if active then
    -- Reapply the override on each relevant world/zone event. This also
    -- repairs the binding if another addon or UI reload changed it.
    SetOverrideBindingClick(frame,true,"M","InstanceAtlasMapKeyButton")
    mapKeyOverrideActive=true
  elseif mapKeyOverrideActive then
    ClearOverrideBindings(frame)
    mapKeyOverrideActive=false
  end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent",function(self,event)
  RefreshMapKeyOverride()
  if event~="PLAYER_REGEN_ENABLED" and InstanceAtlasDB.showOnEnter then
    local name=GetInstance()
    if name then OpenAtlas() elseif panel then panel:Hide() end
  end
end)

local mini=CreateFrame("Button","InstanceAtlasMinimapButton",Minimap)
mini:SetSize(32,32)
mini:SetFrameStrata("MEDIUM")
mini:SetPoint("TOPLEFT",Minimap,"TOPLEFT",2,-2)
mini:SetNormalTexture("Interface\\Minimap\\Tracking\\None")
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mini:SetScript("OnClick",ToggleAtlas)
mini:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_LEFT")
  GameTooltip:AddLine("InstanceAtlas")
  GameTooltip:AddLine("Click to open the custom instance atlas",1,1,1)
  GameTooltip:AddLine("/ia - toggle atlas",0.7,0.7,0.7)
  GameTooltip:Show()
end)
mini:SetScript("OnLeave",GameTooltip_Hide)

Print("Loaded v0.6.0. Press M inside an instance to open InstanceAtlas. Supplied instance maps and floor selectors are installed. Type /ia.")

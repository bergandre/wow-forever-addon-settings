
Grid2DB = {
["namespaces"] = {
["Grid2Frame"] = {
["profiles"] = {
["Karums Warrior"] = {
["iconSize"] = 18,
["frameHeight"] = 62,
["displayZoomedIcons"] = true,
["frameWidth"] = 91,
},
},
},
["Grid2Layout"] = {
["profiles"] = {
["Karums Warrior"] = {
["BackgroundTexture"] = "None",
["Spacing"] = 9,
["anchor"] = "CENTER",
["PosY"] = -219.067239736878,
["PosX"] = -26.99965568690459,
},
},
},
},
["profileKeys"] = {
["Karums Warrior"] = "Karums Warrior",
},
["profiles"] = {
["Karums Warrior"] = {
["themes"] = {
["indicators"] = {
[0] = {
},
},
},
["indicators"] = {
["power-bar-color"] = {
["type"] = "bar-color",
},
["text-down"] = {
["type"] = "text",
["location"] = {
["y"] = 4,
["relPoint"] = "BOTTOM",
["point"] = "BOTTOM",
["x"] = 0,
},
["level"] = 6,
["textlength"] = 6,
["fontSize"] = 10,
},
["icon-left"] = {
["type"] = "icon",
["location"] = {
["y"] = 0,
["relPoint"] = "LEFT",
["point"] = "LEFT",
["x"] = -2,
},
["level"] = 8,
["fontSize"] = 8,
["size"] = 12,
},
["border"] = {
["type"] = "border",
["color1"] = {
["a"] = 0,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
},
["text-down-color"] = {
["type"] = "text-color",
},
["icon-center"] = {
["type"] = "icon",
["location"] = {
["y"] = 0,
["relPoint"] = "CENTER",
["point"] = "CENTER",
["x"] = 0,
},
["level"] = 9,
["fontSize"] = 8,
["size"] = 20,
},
["corner-shield"] = {
["type"] = "icon",
["enableCooldownText"] = true,
["borderSize"] = 2,
["ctFontSize"] = 10,
["useStatusColor"] = true,
["location"] = {
["y"] = -1,
["relPoint"] = "TOPRIGHT",
["point"] = "TOPRIGHT",
["x"] = -1,
},
["level"] = 9,
["fontSize"] = 8,
["size"] = 18,
},
["icon-right"] = {
["type"] = "icon",
["location"] = {
["y"] = 0,
["relPoint"] = "RIGHT",
["point"] = "RIGHT",
["x"] = 2,
},
["level"] = 8,
["fontSize"] = 8,
["size"] = 12,
},
["health-bar"] = {
{
["horTile"] = "REPEAT",
["reverse"] = true,
["color"] = {
["a"] = 0.7,
["r"] = 1,
["g"] = 0,
["b"] = 0.737,
},
["verTile"] = "REPEAT",
["texture"] = "Grid2 Shield",
},
{
["color"] = {
["a"] = 0.5,
},
},
{
["horTile"] = "REPEAT",
["color"] = {
["a"] = 0.7,
},
["verTile"] = "REPEAT",
["prevBar"] = 1,
["texture"] = "Grid2 Shield",
},
{
["color"] = {
["a"] = 1,
["r"] = 0.965,
["g"] = 0.992,
["b"] = 1,
},
["glowLine"] = 6,
["prevBar"] = -1,
["texture"] = "Grid2 GlowH",
},
["location"] = {
["y"] = 0,
["relPoint"] = "CENTER",
["point"] = "CENTER",
["x"] = 0,
},
["type"] = "multibar",
["textureColor"] = {
["a"] = 1,
},
["level"] = 3,
},
["debuffs-icons"] = {
["fontSize"] = 9,
["borderOpacity"] = 1,
["disableCooldown"] = true,
["fontJustifyV"] = "TOP",
["borderSize"] = 1,
["iconSize"] = 18,
["level"] = 8,
["tooltipAnchor"] = "ANCHOR_BOTTOMRIGHT",
["type"] = "icons",
["enableCooldownText"] = true,
["reverseCooldown"] = true,
["color1"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["maxIcons"] = 3,
["ctFontSize"] = 10,
["tooltipEnabled"] = true,
["location"] = {
["y"] = -2,
["relPoint"] = "CENTER",
["point"] = "CENTER",
["x"] = 0,
},
["fontJustifyH"] = "RIGHT",
["useStatusColor"] = true,
["smartCenter"] = true,
},
["alpha"] = {
["type"] = "alpha",
},
["buffs-icons"] = {
["tooltipAnchor"] = "ANCHOR_TOPRIGHT",
["fontSize"] = 9,
["fontJustifyV"] = "TOP",
["enableCooldownText"] = true,
["tooltipEnabled"] = true,
["fontJustifyH"] = "RIGHT",
["borderOpacity"] = 1,
["color1"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["maxIcons"] = 3,
["borderSize"] = 1,
["ctFontSize"] = 10,
["iconSize"] = 12,
["location"] = {
["y"] = 6,
["relPoint"] = "BOTTOMLEFT",
["point"] = "BOTTOMLEFT",
["x"] = 0,
},
["level"] = 8,
["type"] = "icons",
["reverseCooldown"] = true,
},
["health-bar-color"] = {
["type"] = "multibar-color",
},
["corner-renew"] = {
["type"] = "icon",
["enableCooldownText"] = true,
["borderSize"] = 2,
["ctFontSize"] = 10,
["useStatusColor"] = true,
["location"] = {
["y"] = -1,
["relPoint"] = "TOPLEFT",
["point"] = "TOPLEFT",
["x"] = 1,
},
["level"] = 9,
["fontSize"] = 8,
["size"] = 18,
},
["corner-bottom"] = {
["type"] = "square",
["location"] = {
["y"] = 5,
["relPoint"] = "BOTTOM",
["point"] = "BOTTOM",
["x"] = 0,
},
["level"] = 9,
["size"] = 7,
["color1"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
},
["text-up-color"] = {
["type"] = "text-color",
},
["text-up"] = {
["type"] = "text",
["percent"] = true,
["location"] = {
["y"] = -8,
["relPoint"] = "TOP",
["point"] = "TOP",
["x"] = 0,
},
["level"] = 7,
["textlength"] = 6,
["fontSize"] = 9,
},
["power-bar"] = {
["type"] = "bar",
["backColor"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["color1"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["hideWhenInactive"] = true,
["orientation"] = "HORIZONTAL",
["height"] = 4,
["backTexture"] = "Grid2 Flat",
["level"] = 5,
["location"] = {
["y"] = -1,
["relPoint"] = "BOTTOM",
["point"] = "BOTTOM",
["x"] = 0,
},
["texture"] = "Gradient",
},
["tooltip"] = {
["showDefault"] = true,
["type"] = "tooltip",
},
["background"] = {
["type"] = "background",
},
},
["statusMap"] = {
["power-bar-color"] = {
["power"] = 51,
},
["text-down"] = {
["name"] = 99,
},
["icon-left"] = {
["raid-icon-player"] = 155,
},
["health-bar-color"] = {
["classcolor"] = 50,
},
["text-down-color"] = {
["classcolor"] = 99,
},
["icon-center"] = {
["phased"] = 50,
["resurrection"] = 54,
["death"] = 53,
["ready-check"] = 55,
["offline"] = 52,
["summon"] = 51,
},
["corner-shield"] = {
["debuff-WeakenedSoul"] = 50,
["buff-PWShield"] = 60,
},
["icon-right"] = {
["dungeon-role"] = 150,
},
["health-bar"] = {
["heal-absorbs"] = 2,
["shields"] = 4,
["shields-overflow"] = 5,
["heals-incoming"] = 3,
["health-current"] = 1,
},
["debuffs-icons"] = {
["debuffs-Relevant"] = 50,
},
["alpha"] = {
["range"] = 99,
},
["buffs-icons"] = {
["buffs-Relevant"] = 100,
},
["corner-renew"] = {
["buff-Renew-mine"] = 60,
["buff-Renew-other"] = 50,
},
["corner-bottom"] = {
["threat"] = 99,
},
["text-up"] = {
["charmed"] = 70,
["feign-death"] = 96,
["death"] = 97,
["vehicle"] = 93,
["health-current"] = 65,
["offline"] = 95,
},
["power-bar"] = {
["power"] = 50,
},
["border"] = {
["target"] = 50,
["debuffs-DispellableByMe"] = 51,
},
["text-up-color"] = {
["charmed"] = 93,
["feign-death"] = 96,
["death"] = 98,
["classcolor"] = 65,
["offline"] = 97,
["vehicle"] = 95,
},
},
["statuses"] = {
["buffs-Relevant"] = {
["type"] = "mbuffs",
["aura_filter"] = {
["filter"] = "HELPFUL|RAID_IN_COMBAT",
["sortRule"] = 3,
},
["color1"] = {
["a"] = 1,
["r"] = 0,
["g"] = 1,
["b"] = 0,
},
},
["dungeon-role"] = {
["hideInCombat"] = true,
},
["buff-Renew-mine"] = {
["auras"] = {
139,
6074,
6075,
6076,
6077,
6078,
10927,
10928,
10929,
25315,
},
["type"] = "mbuff",
["aura_filter"] = {
["filter"] = "HELPFUL|PLAYER",
},
["color1"] = {
["a"] = 1,
["r"] = 0,
["g"] = 1,
["b"] = 0,
},
},
["debuff-WeakenedSoul"] = {
["type"] = "mdebuffs",
["colors"] = {
["None"] = {
["a"] = 1,
["r"] = 1,
["g"] = 0,
["b"] = 0,
},
},
["auras"] = {
6788,
},
},
["heals-incoming"] = {
["includePlayerHeals"] = true,
},
["buff-PWShield"] = {
["type"] = "mbuff",
["auras"] = {
17,
592,
600,
3747,
6065,
6066,
10898,
10899,
10900,
10901,
},
["color1"] = {
["a"] = 1,
["r"] = 1,
["g"] = 0.85,
["b"] = 0,
},
},
["buff-Renew-other"] = {
["auras"] = {
139,
6074,
6075,
6076,
6077,
6078,
10927,
10928,
10929,
25315,
},
["type"] = "mbuff",
["aura_filter"] = {
["filter"] = "HELPFUL|!PLAYER",
},
["color1"] = {
["a"] = 1,
["r"] = 0.5,
["g"] = 0.5,
["b"] = 0.5,
},
},
["debuffs-Relevant"] = {
["type"] = "mdebuffs",
["colors"] = {
},
["aura_filter"] = {
["excludeSatedDebuffs"] = true,
["sortRule"] = 3,
},
},
},
["versions"] = {
["Grid2"] = 200,
},
["__template"] = "Classic",
["hideBlizzard"] = {
["party"] = true,
},
},
},
}

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMData = select(2, ...).LibTSMData
local Professions = LibTSMData:Init("Professions")



-- ============================================================================
-- Ignored Spell IDs / Names
-- ============================================================================

Professions.IgnoredSpellIds = {
	[2366] = true, -- Herb Gathering
	[2787] = true, -- Abominable Stitching
	[5149] = true, -- Beast Training
	[7620] = true, -- Fishing Skills (shows up as Fishing)
	[8613] = true, -- Skinning
	[53428] = true, -- Runeforging
	[158756] = true, -- Skinning Skills
	[193290] = true, -- Herbalism Skills
	[278910] = true, -- Archaeology
}

Professions.IgnoredNames = {
	["Bestienausbildung"] = true, -- Beast Training (German)
	["Entrenamiento de bestias"] = true, -- Beast Training (Spanish)
	["Воспитание питомца"] = true, -- Beast Training (Russian)
}



-- ============================================================================
-- Map from Localized Name to Skill Name
-- ============================================================================

Professions.LocalizedNameToSkillMap = {
	["Sastrería"] = "Costura", -- Tailoring (Spanish)
	["Peletería"] = "Marroquinería", -- Leatherworking (Spanish)
	["Ingénieur"] = "Ingénierie", -- Engineering (French)
	["Premiers soins"] = "Secourisme", -- First Aid (French)
}

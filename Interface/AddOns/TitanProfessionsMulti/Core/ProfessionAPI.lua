--[[
	Shared profession API adapter for the Retail and Mists clients.
	Classic Era and TBC keep using Classic/Core/LibAddonCompat-1.0.lua.
--]]

local _, L = ...

local ProfessionAPI = {}

local SLOT_INDEX = {
	archaeology = 3,
	fishing = 4,
	cooking = 5,
	firstAid = 6,
}

local function getExpansionConstant(name)
	local value = rawget(_G, name)
	return type(value) == "number" and value or nil
end

local function isCurrentExpansion(name)
	local current = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT")
	local expansion = getExpansionConstant(name)
	return expansion and current == expansion
end

local function getProfessionInfo(index)
	if not index or type(GetProfessionInfo) ~= "function" then
		return nil
	end

	local name, icon, skill, maxSkill, numAbilities, offset, skillLine, bonus = GetProfessionInfo(index)
	return {
		index = index,
		name = name,
		icon = icon,
		skill = tonumber(skill) or 0,
		maxSkill = tonumber(maxSkill) or 0,
		numAbilities = tonumber(numAbilities) or 0,
		offset = offset,
		skillLine = skillLine,
		bonus = tonumber(bonus) or 0,
	}
end

function ProfessionAPI:CreateSnapshot()
	local snapshot = {
		bySkillLine = {},
		bySlot = {},
	}

	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
		return snapshot
	end

	local primary1, primary2, archaeology, fishing, cooking, firstAid = GetProfessions()
	local indexes = { primary1, primary2, archaeology, fishing, cooking, firstAid }

	for slotIndex = 1, 6 do
		local info = getProfessionInfo(indexes[slotIndex])
		if info then
			snapshot.bySlot[slotIndex] = info
			if info.skillLine then
				snapshot.bySkillLine[info.skillLine] = info
			end
		end
	end

	return snapshot
end

function ProfessionAPI:GetProfession(snapshot, config)
	if config.skillLineID then
		return snapshot.bySkillLine[config.skillLineID]
	end

	local slotIndex = SLOT_INDEX[config.slot]
	return slotIndex and snapshot.bySlot[slotIndex] or nil
end

function ProfessionAPI:GetMaximumCap(config)
	if config.capProfile == "archaeology" then
		if isCurrentExpansion("LE_EXPANSION_MISTS_OF_PANDARIA") then
			return 600
		elseif isCurrentExpansion("LE_EXPANSION_WARLORDS_OF_DRAENOR") then
			return 700
		elseif isCurrentExpansion("LE_EXPANSION_LEGION") then
			return 800
		end

		local current = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT") or 0
		local battleForAzeroth = getExpansionConstant("LE_EXPANSION_BATTLE_FOR_AZEROTH")
		if battleForAzeroth and current >= battleForAzeroth then
			return 950
		end

		return 600
	end

	if isCurrentExpansion("LE_EXPANSION_MISTS_OF_PANDARIA") then
		return 600
	elseif isCurrentExpansion("LE_EXPANSION_WARLORDS_OF_DRAENOR") then
		return 700
	elseif isCurrentExpansion("LE_EXPANSION_LEGION") then
		return 800
	elseif isCurrentExpansion("LE_EXPANSION_BATTLE_FOR_AZEROTH") then
		return 150
	elseif isCurrentExpansion("LE_EXPANSION_SHADOWLANDS") then
		return config.capProfile == "fishing" and 200 or 100
	elseif isCurrentExpansion("LE_EXPANSION_DRAGONFLIGHT") then
		return 100
	elseif isCurrentExpansion("LE_EXPANSION_THE_WAR_WITHIN") then
		return config.capProfile == "fishing" and 300 or 100
	elseif isCurrentExpansion("LE_EXPANSION_MIDNIGHT") then
		return config.capProfile == "fishing" and 300 or 100
	end

	-- Midnight and later clients without a named expansion constant use the
	-- latest known profession model. This avoids falling back to Mists values.
	local current = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT") or 0
	local warWithin = getExpansionConstant("LE_EXPANSION_THE_WAR_WITHIN")
	if warWithin and current > warWithin then
		return config.capProfile == "fishing" and 300 or 100
	end

	return 600
end

function ProfessionAPI:OpenProfession(info)
	if not info or not info.offset then return false end
	if InCombatLockdown and InCombatLockdown() then return false end

	if C_SpellBook and C_SpellBook.CastSpellBookItem and Enum and Enum.SpellBookSpellBank then
		C_SpellBook.CastSpellBookItem(info.offset + 1, Enum.SpellBookSpellBank.Player)
		return true
	end

	if info and info.offset and type(CastSpell) == "function" then
		CastSpell(info.offset + 1, "Spell")
		return true
	end

	return false
end

L.ProfessionAPI = ProfessionAPI

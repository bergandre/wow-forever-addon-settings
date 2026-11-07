-- Profession API adapter for Classic Era and The Burning Crusade.

local _, L = ...
local Compat = LibStub("LibAddonCompat-1.0")

local ProfessionAPI = {}

local SLOT_INDEX = {
	fishing = 4,
	cooking = 5,
	firstAid = 6,
}

local function getProfessionInfo(index)
	if not index then return nil end

	local name, icon, skill, maxSkill, numAbilities, offset, skillLine, bonus = Compat:GetProfessionInfo(index)
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

	local primary1, primary2, archaeology, fishing, cooking, firstAid = Compat:GetProfessions()
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

function ProfessionAPI:GetMaximumCap()
	local current = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT")
	local burningCrusade = rawget(_G, "LE_EXPANSION_BURNING_CRUSADE")
	if burningCrusade and current == burningCrusade then
		return 375
	end

	return 300
end

function ProfessionAPI:OpenProfession(info)
	if info and info.offset and type(CastSpell) == "function" then
		CastSpell(info.offset + 1, "Spell")
		return true
	end

	return false
end

L.ProfessionAPI = ProfessionAPI

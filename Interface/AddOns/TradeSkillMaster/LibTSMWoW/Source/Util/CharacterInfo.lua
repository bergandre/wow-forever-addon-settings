-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local CharacterInfo = LibTSMWoW:Init("Util.CharacterInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the level of the current character.
---@return number
function CharacterInfo.GetLevel()
	return UnitLevel("player")
end

---Gets the specialization ID for the current character (or nil if none).
---@return number?
function CharacterInfo.GetSpecializationId()
	if not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
		return nil
	end
	local spec = C_SpecializationInfo.GetSpecialization()
	---@cast spec number?
	return spec and C_SpecializationInfo.GetSpecializationInfo(spec) or nil
end

---Gets the max player level.
---@return number
function CharacterInfo.GetMaxLevel()
	if LibTSMWoW.IsForever() then
		return 60
	elseif LibTSMWoW.IsRetail() then
		return 90
	elseif LibTSMWoW.IsMistsClassic() then
		return 90
	elseif LibTSMWoW.IsBCClassic() then
		return 70
	elseif LibTSMWoW.IsVanillaClassic() then
		return 60
	else
		error("Invalid game version")
	end
end

---Ambiguates a character name.
---@param name string
---@return string
function CharacterInfo.Ambiguate(name)
	return Ambiguate(name, "none")
end

---Gets the raid color for a class.
---@param class string The class
---@return string?
function CharacterInfo.GetClassRaidColorString(class)
	return RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr or nil
end

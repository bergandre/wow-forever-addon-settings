-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Spell = LibTSMWoW:Init("API.Spell")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets info on a spell.
---@param spellId number The spell ID
---@return string? name
---@return number? icon
---@return number? castTime
function Spell.GetInfo(spellId)
	local info = C_Spell.GetSpellInfo(spellId) --[[@as SpellInfo?]]
	if not info then
		return nil, nil, nil
	end
	return info.name, info.originalIconID, info.castTime
end

---Returns info about the current spell being cast by the player.
---@return (number spellId, number castDuration)|(nil, nil)
function Spell.GetPlayerCastingInfo()
	local spellId, castEndTimeMs = nil, nil
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local _
		_, _, _, _, castEndTimeMs, _, _, _, spellId = UnitCastingInfo("player")
	else
		local _
		_, _, _, _, castEndTimeMs, _, _, _, spellId = CastingInfo()
	end
	if not spellId then
		return nil, nil
	end
	return spellId, (castEndTimeMs - GetTime()) / 1000
end

---Checks if a spell is known by the current character.
---@param spellId number The spell ID
---@return boolean
function Spell.IsKnown(spellId)
	return C_SpellBook.IsSpellInSpellBook(spellId, Enum.SpellBookSpellBank.Player, false)
end

---Checks if a spell is waiting for the player to select a target.
---@return boolean
function Spell.IsTargeting()
	return SpellIsTargeting()
end

---Clears any spell active on the cursor.
function Spell.ClearCursor()
	ClearCursor()
end

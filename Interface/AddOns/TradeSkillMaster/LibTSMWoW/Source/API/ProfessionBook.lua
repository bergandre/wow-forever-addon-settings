-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ProfessionBook = LibTSMWoW:Init("API.ProfessionBook")
local Vararg = LibTSMWoW:From("LibTSMUtil"):Include("Lua.Vararg")
local private = {
	professionsTemp = {}, ---@type table<number,number>
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Queries the server to update the player professions.
function ProfessionBook.Query()
	if LibTSMWoW.IsRetail() then
		ProfessionsBookFrame_Update()
	elseif LibTSMWoW.IsMistsClassic() then
		SpellBook_UpdateProfTab()
	elseif LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		SpellBookFrame:UpdateSkillLineTabs()
	end
end

---Checks if the profession info is available.
---@return boolean
function ProfessionBook.HasProfessionInfo()
	if LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() then
		for _, _, subName in ProfessionBook.SpellBookProfessionInfoIterator() do
			if not subName then
				return false
			end
		end
		return true
	end

	private.PopulateProfessionsTemp()
	if not next(private.professionsTemp) then
		return false
	end

	local hasInfo = true
	-- Needs to iterate using `pairs()` since there might be holes
	for _, id in pairs(private.professionsTemp) do
		if not (GetProfessionInfo(id) --[[@as string?]]) then
			hasInfo = false
			break
		end
	end
	wipe(private.professionsTemp)
	return hasInfo
end

---Iterates over the profession info (should only be used on Vanilla / BC Classic).
---@return fun(): number, string, string @Iterator with fields: `index`, `name`, `subName`
---@return number
---@return number
function ProfessionBook.SpellBookProfessionInfoIterator()
	assert(LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic())
	local _, _, offset, numSpells = GetSpellTabInfo(1)
	return private.SpellBookProfessionInfoIterator, offset + numSpells, offset
end

---Iterates over the profession info (should only be used on Mists Classic / Retail - must be run to completion).
---@return fun(): number, number, string, number, number, number @Iterator with fields: `index`, `id`, `name`, `level`, `maxLevel`, `skillId`
function ProfessionBook.MistsRetailProfessionInfoIterator()
	assert(LibTSMWoW.IsMistsClassic() or LibTSMWoW.IsRetail() or LibTSMWoW.IsForever())
	private.PopulateProfessionsTemp()
	assert(next(private.professionsTemp) ~= nil)
	return private.MistsRetailProfessionInfoIterator
end

---Iterates over the skill info (should only be used on Vanilla / BC Classic).
---@return fun(): number, string, number, number @Iterator with fields: `index`, `name`, `rank`, `maxRank`
---@return number
---@return number
function ProfessionBook.SkillLineInfoIterator()
	return private.SkillLineInfoIterator, GetNumSkillLines(), 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PopulateProfessionsTemp()
	assert(not next(private.professionsTemp))
	Vararg.IntoTable(private.professionsTemp, GetProfessions())
	-- Ignore archaeology and fishing which are in the 3rd and 4th slots respectively
	if not LibTSMWoW.IsForever() then
		private.professionsTemp[3] = nil
	end
	private.professionsTemp[4] = nil
end

function private.SpellBookProfessionInfoIterator(maxIndex, index)
	index = index + 1
	if index > maxIndex then
		return
	end
	local name, subName = GetSpellBookItemName(index, BOOKTYPE_SPELL)
	return index, name, subName
end

function private.MistsRetailProfessionInfoIterator(_, index)
	local id = nil
	index, id = next(private.professionsTemp, index)
	if not index then
		wipe(private.professionsTemp)
		return
	end
	---@cast id -nil
	local name, _, level, maxLevel, _, _, skillId = GetProfessionInfo(id)
	return index, id, name, level, maxLevel, skillId
end

function private.SkillLineInfoIterator(numLines, index)
	index = index + 1
	if index > numLines then
		return
	end
	local name, _, _, rank, _, _, maxRank = GetSkillLineInfo(index)
	return index, name, rank, maxRank
end

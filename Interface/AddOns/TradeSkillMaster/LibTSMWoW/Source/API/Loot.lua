-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Loot = LibTSMWoW:Init("API.Loot")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the number of loot items.
---@return number
function Loot.GetNumItems()
	return GetNumLootItems()
end

---Gets info on the loot item at the specified index.
---@param index number The index
---@return string? link
---@return number? quantity
function Loot.GetInfo(index)
	local link = GetLootSlotLink(index)
	local _, _, quantity = GetLootSlotInfo(index)
	return link, quantity
end

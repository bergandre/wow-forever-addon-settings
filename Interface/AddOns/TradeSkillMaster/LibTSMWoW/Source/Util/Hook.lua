-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Hook = LibTSMWoW:Init("Util.Hook")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a secure post-hook of a function.
---@param tbl table The containing table
---@param key string The key within the table for the function to hook
---@param func function The hook handler
function Hook.SecurePost(tbl, key, func)
	hooksecurefunc(tbl, key, func)
end

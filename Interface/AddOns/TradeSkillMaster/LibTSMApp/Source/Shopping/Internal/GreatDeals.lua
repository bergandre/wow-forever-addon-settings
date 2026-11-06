-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local GreatDeals = LibTSMApp:InitInternal("Shopping.GreatDeals")
local String = LibTSMApp:From("LibTSMUtil"):Include("Lua.String")
local AppHelper = LibTSMApp:From("LibTSMService"):Include("AppHelper")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local Lifecycle = LibTSMApp:From("LibTSMService"):Include("Util.Lifecycle")
local private = {
	isAvailable = nil,
	filter = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

GreatDeals:OnModuleLoad(function()
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not the great deals search is available.
---@return boolean
function GreatDeals.IsAvailable()
	assert(private.isAvailable ~= nil)
	return private.isAvailable
end

---Gets the great deals filter.
---@return string
function GreatDeals.GetFilter()
	return private.filter
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	local appData = AppHelper.GetAndClearShoppingData()
	private.isAvailable = appData and true or false
	if not appData then
		return true
	end
	private.filter = assert(loadstring(appData))().greatDeals
	-- Populate item info cache
	for item in String.SplitIterator(private.filter, ";") do
		item = strmatch(item, "^([^/]*)/")
		ItemInfo.FetchInfo(item)
	end
	return true
end

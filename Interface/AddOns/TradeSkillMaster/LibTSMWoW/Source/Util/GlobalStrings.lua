-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local GlobalStrings = LibTSMWoW:Init("Util.GlobalStrings")
local MoneyFormatter = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local private = {
	strings = {}, ---@type table<GlobalStringKey,string>
}
local KEYS = { ---@type GlobalStringKey[]
	"ALL",
	"ALT_KEY",
	"AUCTION_SOLD_MAIL_SUBJECT",
	"BANK",
	"BUYBACK",
	"BUYOUT",
	"CANCEL",
	"CTRL_KEY",
	"DAYS",
	"DONE",
	"GUILD",
	"LOGOUT",
	"OKAY",
	"OPENING",
	"REMOVE",
	"SEARCH",
}

---@alias GlobalStringKey
---|"ALL"
---|"ALT_KEY"
---|"AUCTION_SOLD_MAIL_SUBJECT"
---|"BANK"
---|"BUYBACK"
---|"BUYOUT"
---|"CANCEL"
---|"CTRL_KEY"
---|"DAYS"
---|"DONE"
---|"GUILD"
---|"LOGOUT"
---|"OKAY"
---|"OPENING"
---|"REMOVE"
---|"SEARCH"



-- ============================================================================
-- Module Loading
-- ============================================================================

GlobalStrings:OnModuleLoad(function()
	MoneyFormatter.SetLargeNumberSeparator(LARGE_NUMBER_SEPERATOR)
	for _, key in ipairs(KEYS) do
		local str = _G[key]
		assert(str)
		private.strings[key] = str
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets a global string which will be localized.
---@param key GlobalStringKey The global string key
---@return string
function GlobalStrings.Get(key)
	local str = private.strings[key]
	assert(str)
	return str
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UISettings = LibTSMUI:Init("Util.UISettings")
local Vararg = LibTSMUI:From("LibTSMUtil"):Include("Lua.Vararg")
local private = {
	keys = {},
	view = nil,
}

---@class UISettingsView: PlayerGoldTextSettings, MailContactsDialogSettings



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers expected UI setting keys.
---@param ... string The setting keys
function UISettings.RegisterKeys(...)
	assert(not private.view)
	for _, key in Vararg.Iterator(...) do
		assert(type(key) == "string")
		if not private.keys[key] then
			tinsert(private.keys, key)
			private.keys[key] = true
		end
	end
end

---Sets the UI settings view.
---@param view UISettingsView
function UISettings.Set(view)
	view:AssertHasKeys(unpack(private.keys))
	private.view = view
end

---Returns the UI settings view.
---@return UISettingsView
function UISettings.Get()
	assert(private.view)
	return private.view
end

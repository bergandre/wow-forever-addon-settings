-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local WidgetsDebug = LibTSMUI:Init("Util.WidgetsDebug")
local ErrorHandler = LibTSMUI:From("LibTSMService"):Include("Debug.ErrorHandler")
local private = {
	debugNameOwnerLookup = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

WidgetsDebug:OnModuleLoad(function()
	ErrorHandler.RegisterNameTranslationFunction(function(result)
		for name, owner in pairs(private.debugNameOwnerLookup) do
			result[name] = "<"..tostring(owner)..">"
		end
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a name for debug purposes.
---@param typePrefix string The widget type prefix
---@param owner any The owner of the widget
---@return string?
function WidgetsDebug.CreateName(typePrefix, owner)
	if not LibTSMUI.IsDevVersion() and not LibTSMUI.IsTestVersion() then
		return nil
	end
	local name = strjoin(":", typePrefix, owner.__class.__name, format("%06x", random(0, 2 ^ 24 - 1)))
	private.debugNameOwnerLookup[name] = owner
	return name
end

---Gets the owner for a given debug name.
---@param name string The debug name
---@return any?
function WidgetsDebug.GetOwner(name)
	return private.debugNameOwnerLookup[name]
end

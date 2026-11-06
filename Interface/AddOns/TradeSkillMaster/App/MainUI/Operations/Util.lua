-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Util = App:Init("MainUI.Operations.Util")
local private = {
	showGroupSettingsCallback = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the operations util code.
---@param showGroupSettingsCallback fun(groupPath: GroupPathValue) Function to show the group settings
function Util.Configure(showGroupSettingsCallback)
	private.showGroupSettingsCallback = showGroupSettingsCallback
end

---Shows the group settings for the specified group.
---@param groupPath GroupPathValue The group to open the settings of
function Util.ShowGroupSettings(groupPath)
	private.showGroupSettingsCallback(groupPath)
end

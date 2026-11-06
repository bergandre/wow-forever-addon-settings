-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local MinimapIcon = LibTSMUI:Init("MinimapIcon")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")



-- ============================================================================
-- Module Loading
-- ============================================================================

---Configures the minimap icon.
---@param settingsTable table The settings table
---@param clickHandler fun() The click handler
function MinimapIcon.Configure(settingsTable, clickHandler)
	-- Create / register the minimap button
	local dataObj = LibDataBroker:NewDataObject("TradeSkillMaster", {
		type = "launcher",
		icon = "Interface\\Addons\\TradeSkillMaster\\Media\\TSM_Icon2",
		OnClick = function(_, button)
			if button ~= "LeftButton" then
				return
			end
			clickHandler()
		end,
		OnTooltipShow = function(tooltip)
			local cs = Theme.GetColor("accent/main"):GetTextColorPrefix()
			local ce = "|r"
			tooltip:AddLine("TradeSkillMaster "..LibTSMUI.GetVersionStr())
			tooltip:AddLine(format(L["%sLeft-Click%s to open the main window"], cs, ce))
			tooltip:AddLine(format(L["%sDrag%s to move this button"], cs, ce))
		end,
	})
	LibDBIcon:Register("TradeSkillMaster", dataObj, settingsTable)
end

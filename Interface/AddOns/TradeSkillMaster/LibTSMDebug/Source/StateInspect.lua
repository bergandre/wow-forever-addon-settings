-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMDebug = select(2, ...).LibTSMDebug
local StateInspect = LibTSMDebug:InitInternal("StateInspect")
local SlashCommands = LibTSMDebug:From("LibTSMApp"):Include("Service.SlashCommands")
local Debug = LibTSMDebug:From("LibTSMReactive"):Include("Debug")



-- ============================================================================
-- Module Loading
-- ============================================================================

StateInspect:OnModuleLoad(function()
	SlashCommands.RegisterDebug("state", function()
		C_AddOns.LoadAddOn("Blizzard_DebugTools")
		DisplayTableInspectorWindow(Debug.GetAllStateData())
	end)
end)

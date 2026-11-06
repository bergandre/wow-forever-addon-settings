-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local DebugConfig = LibTSMApp:Init("Config.DebugConfig")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local DebugStack = LibTSMApp:From("LibTSMUtil"):Include("Lua.DebugStack")
local ObjectPool = LibTSMApp:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Addon = LibTSMApp:From("LibTSMWoW"):Include("API.Addon")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Lifecycle = LibTSMApp:From("LibTSMService"):Include("Util.Lifecycle")
local private = {}



-- ============================================================================
-- Module Loading
-- ============================================================================

DebugConfig:OnModuleLoad(function()
	-- Shorten "TradeSkillMaster" to "TSM" in debug stack frames
	DebugStack.AddShortenPattern(".-lMaster\\", "TSM\\")
	DebugStack.AddShortenPattern(".-r\\LibTSM", "TSM\\LibTSM")

	SlashCommands.Register("version", private.PrintVersions, L["Prints out the installed TSM version."])
	SlashCommands.RegisterDebug("leaks", private.EnableLeakDebug)
	SlashCommands.RegisterDebug("logout", private.TestLogout)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PrintVersions()
	ChatMessage.PrintUser(L["TSM Version Info:"])
	ChatMessage.PrintUserRaw("TradeSkillMaster "..ChatMessage.ColorUserAccentText(LibTSMApp.GetVersionStr()))
	local _, appHelperVersion = Addon.GetInfo("TradeSkillMaster_AppHelper")
	if appHelperVersion == "" then
		return
	end
	if strmatch(appHelperVersion, "project%-version@$") then
		appHelperVersion = "Dev"
	end
	ChatMessage.PrintUserRaw("TradeSkillMaster_AppHelper "..ChatMessage.ColorUserAccentText(appHelperVersion))
end

function private.EnableLeakDebug()
	TempTable.EnableLeakDebug()
	ObjectPool.EnableLeakDebug()
end

function private.TestLogout()
	Lifecycle.TestEvent(Lifecycle.EVENT.LOGOUT)
end

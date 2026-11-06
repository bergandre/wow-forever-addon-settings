-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local LogConfig = LibTSMApp:Init("Config.LogConfig")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local ChatFrame = LibTSMApp:From("LibTSMWoW"):Include("API.ChatFrame")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(LogConfig, function(db)
	private.settings = db:NewView("LogConfigSettings")
		:AddKey("global", "coreOptions", "chatFrame")
		:AddKey("global", "debug", "chatLoggingEnabled")
		:Commit()

	ChatFrame.SetActive(private.settings.chatFrame)

	if LibTSMApp.IsTestVersion() then
		private.settings.chatLoggingEnabled = true
	elseif not LibTSMApp.IsDevVersion() then
		private.settings.chatLoggingEnabled = false
	end
	Log.SetLoggingToChatEnabled(private.settings.chatLoggingEnabled)

	SlashCommands.RegisterDebug("logging", private.ToggleLogging)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ToggleLogging()
	assert(not LibTSMApp.IsTestVersion() and LibTSMApp.IsDevVersion())
	private.settings.chatLoggingEnabled = not private.settings.chatLoggingEnabled
	Log.SetLoggingToChatEnabled(private.settings.chatLoggingEnabled)
	if private.settings.chatLoggingEnabled then
		ChatMessage.PrintfUser("Logging to chat enabled")
	else
		ChatMessage.PrintfUser("Logging to chat disabled")
	end
end

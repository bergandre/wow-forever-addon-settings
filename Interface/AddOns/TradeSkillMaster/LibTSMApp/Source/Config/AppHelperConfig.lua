-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AppHelperConfig = LibTSMApp:Init("Config.AppHelperConfig")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Addon = LibTSMApp:From("LibTSMWoW"):Include("API.Addon")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local AppHelper = LibTSMApp:From("LibTSMService"):Include("AppHelper")
local UIElements = LibTSMApp:From("LibTSMUI"):Include("UIElements")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(AppHelperConfig, function(db)
	private.settings = db:NewView("AppHelperConfigSettings")
		:AddKey("global", "internalData", "appMessageId")
		:AddKey("global", "internalData", "lastCharacter")
		:AddKey("realm", "coreOptions", "auctionDBAltRealm")
		:Commit()
	-- Set the last character we logged into for display in the app
	private.settings.lastCharacter = SessionInfo.GetCharacterName().." - "..SessionInfo.GetRealmName()
	AppHelper.Configure(private.settings.auctionDBAltRealm, private.HandleDataLoaded)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleDataLoaded(status)
	if status == AppHelper.DATA_STATUS.LOADED then
		-- pass
	elseif status == AppHelper.DATA_STATUS.APP_HELPER_NOT_ENABLED then
		Addon.Enable("TradeSkillMaster_AppHelper")
		UIElements.New("ReloadPopupDialog", "dialog")
			:SetMessage(L["The TradeSkillMaster_AppHelper addon is installed, but not enabled. TSM has enabled it and requires a reload."])
			:Show()
			:Draw()
		return
	elseif status == AppHelper.DATA_STATUS.APP_NOT_RUN or status == AppHelper.DATA_STATUS.DATA_OLD then
		UIElements.New("InfoPopupDialog", "dialog")
			:SetMessage(L["TSM is missing important information from the TSM Desktop Application. Please ensure the TSM Desktop Application is running and is properly configured."])
			:Show()
			:Draw()
		return
	else
		error("Unexpected status: "..tostring(status))
	end
	local msg, msgId = AppHelper.GetMessage()
	if msg and msgId > private.settings.appMessageId then
		private.settings.appMessageId = msgId
		UIElements.New("InfoPopupDialog", "dialog")
			:SetMessage(msg)
			:Show()
			:Draw()
	end
end

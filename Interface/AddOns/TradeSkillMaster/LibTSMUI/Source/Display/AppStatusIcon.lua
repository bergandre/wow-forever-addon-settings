-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TimeFormat = LibTSMUI:From("LibTSMWoW"):Include("UI.TimeFormat")
local SessionInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.SessionInfo")
local AppHelper = LibTSMUI:From("LibTSMService"):Include("AppHelper")
local AuctionDB = LibTSMUI:From("LibTSMService"):Include("AuctionDB")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	tooltipTemp = {},
}
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR
local APP_UPDATE_AGE_WARNING = SECONDS_PER_HOUR
local APP_UPDATE_AGE_ERROR = SECONDS_PER_DAY
local AUCTIONDB_REALM_AGE_WARNING = 12 * SECONDS_PER_HOUR
local AUCTIONDB_REALM_AGE_ERROR = 7 * SECONDS_PER_DAY
local AUCTIONDB_REGION_AGE_ERROR = 7 * SECONDS_PER_DAY



-- ============================================================================
-- Element Definition
-- ============================================================================

local AppStatusIcon = ComponentRegistry.Define("AppStatusIcon", "BaseButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AppStatusIcon:Acquire()
	self.__super:Acquire()
	local syncTime = AppHelper.GetLastSync()
	local realmTime, regionTime = AuctionDB.GetAppDataUpdateTimes()
	local color, texture = nil, nil
	local appUpdateAge = LibTSMUI.GetTime() - syncTime
	local auctionDBRealmAge = LibTSMUI.GetTime() - realmTime
	local auctionDBRegionAge = LibTSMUI.GetTime() - regionTime
	if appUpdateAge >= APP_UPDATE_AGE_ERROR or auctionDBRealmAge > AUCTIONDB_REALM_AGE_ERROR or auctionDBRegionAge > AUCTIONDB_REALM_AGE_ERROR then
		color = "error/main"
		texture = "iconPack.14x14/Attention"
	elseif appUpdateAge >= APP_UPDATE_AGE_WARNING or auctionDBRealmAge >= AUCTIONDB_REALM_AGE_WARNING then
		color = "warning/main"
		texture = "iconPack.14x14/Attention"
	else
		color = "positive/main"
		texture = "iconPack.14x14/Checkmark/Circle"
	end
	self:SetBackgroundAndSize(TextureAtlas.GetColoredKey(texture, color))
	self:SetTooltip(self:__closure("_GetAppStatusTooltip"))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AppStatusIcon.__private:_GetAppStatusTooltip()
	local regionRealmName = AppHelper.GetRegion().."-"..SessionInfo.GetRealmName()
	if not LibTSMUI.IsRetail() then
		regionRealmName = regionRealmName.."-"..SessionInfo.GetFactionName()
	end
	tinsert(private.tooltipTemp, format(L["TSM Desktop App Status (%s)"], regionRealmName))

	local appUpdateAge = LibTSMUI.GetTime() - AppHelper.GetLastSync()
	if appUpdateAge < APP_UPDATE_AGE_WARNING then
		tinsert(private.tooltipTemp, Theme.GetColor("positive/main"):ColorText(format(L["App Synced %s Ago"], TimeFormat.Duration(appUpdateAge))))
	elseif appUpdateAge < APP_UPDATE_AGE_ERROR then
		tinsert(private.tooltipTemp, Theme.GetColor("warning/main"):ColorText(format(L["App Synced %s Ago"], TimeFormat.Duration(appUpdateAge))))
	else
		tinsert(private.tooltipTemp, Theme.GetColor("error/main"):ColorText(L["App Not Synced"]))
	end

	local realmTime, regionTime = AuctionDB.GetAppDataUpdateTimes()
	local auctionDBRealmAge = LibTSMUI.GetTime() - realmTime
	local auctionDBRegionAge = LibTSMUI.GetTime() - regionTime
	if auctionDBRealmAge < AUCTIONDB_REALM_AGE_WARNING then
		tinsert(private.tooltipTemp, Theme.GetColor("positive/main"):ColorText(format(L["AuctionDB Realm Data is %s Old"], TimeFormat.Duration(auctionDBRealmAge))))
	elseif auctionDBRealmAge < AUCTIONDB_REALM_AGE_ERROR then
		tinsert(private.tooltipTemp, Theme.GetColor("warning/main"):ColorText(format(L["AuctionDB Realm Data is %s Old"], TimeFormat.Duration(auctionDBRealmAge))))
	else
		tinsert(private.tooltipTemp, Theme.GetColor("error/main"):ColorText(L["No AuctionDB Realm Data"]))
	end
	if auctionDBRegionAge < AUCTIONDB_REGION_AGE_ERROR then
		tinsert(private.tooltipTemp, Theme.GetColor("positive/main"):ColorText(format(L["AuctionDB Region Data is %s Old"], TimeFormat.Duration(auctionDBRegionAge))))
	else
		tinsert(private.tooltipTemp, Theme.GetColor("error/main"):ColorText(L["No AuctionDB Region Data"]))
	end

	local result = table.concat(private.tooltipTemp, "\n")
	wipe(private.tooltipTemp)
	return result, true, 16
end

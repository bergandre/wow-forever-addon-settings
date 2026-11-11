-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AppHelper = LibTSMService:Init("AppHelper")
local Auction = LibTSMService:Include("Auction")
local ErrorHandler = LibTSMService:Include("Debug.ErrorHandler")
local RealmInfo = LibTSMService:Include("Data.RealmInfo")
local Analytics = LibTSMService:Include("Util.Analytics")
local Lifecycle = LibTSMService:Include("Util.Lifecycle")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local BinarySearch = LibTSMService:From("LibTSMUtil"):Include("Util.BinarySearch")
local ExecutionTime = LibTSMService:From("LibTSMUtil"):Include("Util.ExecutionTime")
local Hash = LibTSMService:From("LibTSMUtil"):Include("Util.Hash")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Addon = LibTSMService:From("LibTSMWoW"):Include("API.Addon")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	altAuctionDBRealm = nil,
	dataLoadCallback = nil,
	-- The addon has historically had the game version as a suffix, whereas the app data has it as a prefix, so we store both
	addonRegion = nil,
	appDataRegion = nil,
	appInfo = nil, ---@type AppInfo?
	auctionDBData = nil, ---@type AppAuctionDBData?
	shoppingData = nil,
	altRealms = {},
	groupImports = {}, ---@type AppGroupImport[]
	groupImportsById = {}, ---@type table<string,AppGroupImport>
	groupImportResults = nil, ---@type table<string,AppGroupImportResultInfo>!
}
local DATA_STATUS = EnumType.New("APP_HELPER_DATA_STATUS", {
	APP_HELPER_NOT_ENABLED = EnumType.NewValue(),
	APP_NOT_RUN = EnumType.NewValue(),
	DATA_OLD = EnumType.NewValue(),
	LOADED = EnumType.NewValue(),
})
AppHelper.DATA_STATUS = DATA_STATUS
local APP_INFO_REQUIRED_KEYS = { "version", "lastSync", "message", "news" }
local AUCTIONDB_REALM_TAGS = {
	AUCTIONDB_NON_COMMODITY_DATA = true,
	AUCTIONDB_NON_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_NON_COMMODITY_HISTORICAL = true,
}
local AUCTIONDB_REGION_TAGS = {
	AUCTIONDB_REGION_STAT = true,
	AUCTIONDB_REGION_HISTORICAL = true,
	AUCTIONDB_REGION_SALE = true,
}
local AUCTIONDB_COMMODITY_TAGS = {
	AUCTIONDB_COMMODITY_DATA = true,
	AUCTIONDB_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_COMMODITY_HISTORICAL = true,
}
local GROUP_IMPORT_RESULTS = {
	IMPORTED = true,
	DISCARDED = true,
}
local MAX_ANALYTICS_AGE = 14 * 24 * 60 * 60 -- 2 weeks
local MIN_GROUP_IMPORT_RESULT_AGE = 7 * 24 * 60 * 60
local MAX_FULL_SCAN_AGE = 12 * 60 * 60 -- 12 hours
local APP_DB_GLOBAL_NAME = "TradeSkillMaster_AppHelperDB"

---@class AppInfo
---@field news AppInfoNewsEntry[]
---@field lastSync number
---@field message AppInfoMessage

---@class AppInfoNewsEntry
---@field content string
---@field timestamp number
---@field title string
---@field link string

---@class AppInfoMessage
---@field id number
---@field msg string

---@class AppAuctionDBData
---@field realm table<string,string>
---@field region table<string,string>
---@field commodity table<string,string>
---@field altRealm table<string,string>

---@class AppGroupImport
---@field id string
---@field name string
---@field author string
---@field sentAt number
---@field importString string

---@alias AppGroupImportResult "IMPORTED"|"DISCARDED"

---@class AppGroupImportResultInfo
---@field result AppGroupImportResult
---@field time number



-- ============================================================================
-- Global Function
-- ============================================================================

function TSM_APPHELPER_LOAD_DATA(tag, realmOrRegion, data)
	if type(tag) ~= "string" or type(realmOrRegion) ~= "string" or type(data) ~= "string" then
		Log.Err("Unknown AppHelper data: %s, %s, %s", strsub(tostring(tag), 1, 20), strsub(tostring(realmOrRegion), 1, 20), strsub(tostring(data), 1, 20))
		return
	end
	if tag == "APP_INFO" and realmOrRegion == "Global" then
		if private.appInfo then
			Log.Err("Duplicate app info")
			return
		end
		Log.Info("Got app info")

		-- Load the app info
		private.appInfo = assert(loadstring(data))()
		assert(private.appInfo)
		for _, key in ipairs(APP_INFO_REQUIRED_KEYS) do
			assert(private.appInfo[key])
		end

		-- Clean up the news content strings
		for _, info in ipairs(private.appInfo.news) do
			-- For some reason the data is missing a few newlines before bold headings, so add one
			info.content = gsub(info.content, "(<strong>)", "\n\n%1")
			info.content = gsub(info.content, "<br%s+/>", "\n")
			info.content = gsub(info.content, "<strong>(.-)</strong>", "%1")
			info.content = gsub(info.content, "<a href='.-'>(.-)</a>", "%1")
			info.content = gsub(info.content, "&#8211;", "-")
			info.content = gsub(info.content, "&#8216;", "'")
		end
	elseif AUCTIONDB_REALM_TAGS[tag] or AUCTIONDB_REGION_TAGS[tag] or AUCTIONDB_COMMODITY_TAGS[tag] then
		private.auctionDBData = private.auctionDBData or {
			realm = {},
			region = {},
			commodity = {},
			altRealm = {},
		}
		if AUCTIONDB_REALM_TAGS[tag] and private.IsCurrentRealm(realmOrRegion) then
			private.StoreAuctionDBData(private.auctionDBData.realm, tag, data, "realm")
		elseif AUCTIONDB_REALM_TAGS[tag] and private.IsRealm(realmOrRegion, private.altAuctionDBRealm) then
			private.altRealms[realmOrRegion] = true
			private.StoreAuctionDBData(private.auctionDBData.altRealm, tag, data, "alt realm")
		elseif AUCTIONDB_REGION_TAGS[tag] and realmOrRegion == private.appDataRegion then
			private.StoreAuctionDBData(private.auctionDBData.region, tag, data, "region")
		elseif AUCTIONDB_COMMODITY_TAGS[tag] and realmOrRegion == private.appDataRegion then
			private.StoreAuctionDBData(private.auctionDBData.commodity, tag, data, "commodity")
		else
			Log.Info("Ignoring AuctionDB data (%s) for '%s'", tag, realmOrRegion)
			if AUCTIONDB_REALM_TAGS[tag] then
				private.altRealms[realmOrRegion] = true
			end
		end
	elseif tag == "SHOPPING_SEARCHES" then
		if not private.IsCurrentRealm(realmOrRegion) then
			Log.Info("Ignoring Shopping data for '%s'", realmOrRegion)
			private.altRealms[realmOrRegion] = true
			return
		elseif private.shoppingData then
			Log.Err("Duplicate Shopping data")
			return
		end
		private.shoppingData = data
		Log.Info("Got Shopping data")
	elseif tag == "GROUP_IMPORTS" then
		private.LoadGroupImports(data)
	else
		Log.Err("Unknown AppHelper data: %s, %s", strsub(tag, 1, 25), strsub(realmOrRegion, 1, 25))
	end
end



-- ============================================================================
-- Module Loading
-- ============================================================================

AppHelper:OnModuleLoad(function()
	local region = RealmInfo.GetRegion()
	if LibTSMService.IsForever() and SessionInfo.IsHardcore() then
		private.addonRegion = region.."-Forever-HC"
		private.appDataRegion = "Forever-HC-"..region
	elseif LibTSMService.IsForever() then
		private.addonRegion = region.."-Forever"
		private.appDataRegion = "Forever-"..region
	elseif LibTSMService.IsRetail() then
		private.addonRegion = region
		private.appDataRegion = region
	elseif LibTSMService.IsVanillaClassic() and SessionInfo.IsHardcore() then
		private.addonRegion = region.."-HC"
		private.appDataRegion = "HC-"..region
	elseif LibTSMService.IsVanillaClassic() and SessionInfo.IsSeasonOfDiscovery() then
		private.addonRegion = region.."-SoD"
		private.appDataRegion = "SoD-"..region
	elseif LibTSMService.IsBCClassic() then
		private.addonRegion = region.."-Fresh"
		private.appDataRegion = "Fresh-"..region
	elseif LibTSMService.IsVanillaClassic() then
		private.addonRegion = region.."-Classic"
		private.appDataRegion = "Classic-"..region
	elseif LibTSMService.IsMistsClassic() then
		private.addonRegion = region.."-BCC"
		private.appDataRegion = "BCC-"..region
	else
		error("Invalid game version")
	end
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
end)

AppHelper:OnModuleUnloadLate(function()
	for _ in ExecutionTime.WithMeasurement("private.SaveAppData()") do
		private.SaveAppData()
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the AppHelper code.
---@param altAuctionDBRealm string The alternate auctionDB realm to load data for
---@param groupImportResults table<string,AppGroupImportResultInfo> The table to store group import results in
---@param dataLoadCallback fun(status: EnumValue) A callback for when loading of AppHelper data is complete
function AppHelper.Configure(altAuctionDBRealm, groupImportResults, dataLoadCallback)
	private.altAuctionDBRealm = altAuctionDBRealm
	private.groupImportResults = groupImportResults
	private.dataLoadCallback = dataLoadCallback
end

---Gets the latest app message.
---@return string?
---@return number?
function AppHelper.GetMessage()
	if not private.appInfo or not private.appInfo.message.msg then
		return nil, nil
	end
	return private.appInfo.message.msg, private.appInfo.message.id
end

---Gets the last sync time.
---@return number
function AppHelper.GetLastSync()
	return private.appInfo and private.appInfo.lastSync or 0
end

---Gets the news data.
---@return AppInfoNewsEntry[]?
function AppHelper.GetNews()
	return private.appInfo and private.appInfo.news or nil
end

---Gets the current region.
---@return string
function AppHelper.GetRegion()
	return private.addonRegion
end

---Gets and clears the AuctionDB data.
---@return AppAuctionDBData?
function AppHelper.GetAndClearAuctionDBData()
	local data = private.auctionDBData
	private.auctionDBData = nil
	return data
end

---Gets and clears the shopping data.
---@return string?
function AppHelper.GetAndClearShoppingData()
	local data = private.shoppingData
	private.shoppingData = nil
	return data
end

---Gets the group imports sent from the website which haven't been imported or discarded yet.
---@return AppGroupImport[]
function AppHelper.GetPendingGroupImports()
	local result = {}
	for _, groupImport in ipairs(private.groupImports) do
		if not private.groupImportResults[groupImport.id] then
			tinsert(result, groupImport)
		end
	end
	return result
end

---Gets a group import sent from the website by its id.
---@param id string The id of the group import
---@return AppGroupImport?
function AppHelper.GetGroupImport(id)
	return private.groupImportsById[id]
end

---Stores the result of a group import sent from the website so it isn't offered again.
---@param id string The id of the group import
---@param result AppGroupImportResult The result
function AppHelper.SetGroupImportResult(id, result)
	assert(private.groupImportsById[id] and GROUP_IMPORT_RESULTS[result])
	private.groupImportResults[id] = {
		result = result,
		time = LibTSMService.GetTime(),
	}
end

---Iterates over the alt realm names.
---@return fun(): string @Iterator with fields: `realm`
---@return table
---@return nil
function AppHelper.AltRealmIterator()
	return Table.KeyIterator(private.altRealms)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	TSM_APPHELPER_LOAD_DATA = function(tag)
		Log.Err("Got late app data: %s", tag)
	end
	private.PruneGroupImportResults()

	if not Addon.IsInstalled("TradeSkillMaster_AppHelper") then
		return true
	elseif not Addon.IsEnabled("TradeSkillMaster_AppHelper") then
		-- TSM_AppHelper is disabled
		private.dataLoadCallback(DATA_STATUS.APP_HELPER_NOT_ENABLED)
		return true
	elseif not private.appInfo or not private.appInfo.lastSync then
		-- The app hasn't run yet or isn't pointing at the right WoW directory
		private.dataLoadCallback(DATA_STATUS.APP_NOT_RUN)
		return true
	end

	local isAppRunning = LibTSMService.GetTime() - private.appInfo.lastSync <= 60 * 60
	if LibTSMService.IsMistsClassic() then
		-- Only enable the full scan if this user hasn't scanned in the last hour and their app is running
		local appDB = _G[APP_DB_GLOBAL_NAME]
		local lastFullScanTime = appDB and appDB.fullScan and appDB.fullScan.updateTime or 0
		if isAppRunning and LibTSMService.GetTime() - lastFullScanTime > 60 * 60 then
			Auction.EnableFullScan()
		end
	else
		Auction.EnableFullScan()
	end

	private.dataLoadCallback(isAppRunning and DATA_STATUS.LOADED or DATA_STATUS.DATA_OLD)
	return true
end

function private.LoadGroupImports(data)
	local func = loadstring(data)
	local groupImports = func and func()
	if type(groupImports) ~= "table" then
		Log.Err("Invalid group imports data")
		return
	end
	for _, groupImport in ipairs(groupImports) do
		if not private.IsValidGroupImport(groupImport) then
			Log.Err("Invalid group import")
		elseif private.groupImportsById[groupImport.id] then
			Log.Err("Duplicate group import (%s)", groupImport.id)
		else
			private.groupImportsById[groupImport.id] = groupImport
			tinsert(private.groupImports, groupImport)
		end
	end
	Log.Info("Got %d group imports", #private.groupImports)
end

function private.IsValidGroupImport(groupImport)
	if type(groupImport) ~= "table" then
		return false
	elseif type(groupImport.id) ~= "string" or groupImport.id == "" then
		return false
	elseif type(groupImport.name) ~= "string" or type(groupImport.author) ~= "string" then
		return false
	elseif type(groupImport.sentAt) ~= "number" then
		return false
	elseif type(groupImport.importString) ~= "string" or groupImport.importString == "" then
		return false
	end
	return true
end

function private.PruneGroupImportResults()
	local minTime = LibTSMService.GetTime() - MIN_GROUP_IMPORT_RESULT_AGE
	for id, info in pairs(private.groupImportResults) do
		if info.time < minTime and not private.groupImportsById[id] then
			private.groupImportResults[id] = nil
		end
	end
end

function private.StoreAuctionDBData(tbl, tag, data, label)
	if tbl[tag] then
		Log.Err("Duplicate AuctionDB %s data (%s)", label, tag)
		return
	end
	tbl[tag] = data
	Log.Info("Got AuctionDB %s data (%s)", label, tag)
end

function private.SanitizedRealmName(realm)
	return gsub(realm, "\226", "'")
end

function private.IsCurrentRealm(realm)
	local realmName = SessionInfo.GetRealmName()
	if not LibTSMService.IsRetail() then
		realmName = realmName.."-"..SessionInfo.GetFactionName()
	end
	return private.IsRealm(realm, realmName)
end

function private.IsRealm(realm, targetRealm)
	return strlower(private.SanitizedRealmName(realm)) == strlower(private.SanitizedRealmName(targetRealm))
end

function private.SaveAppData()
	if not Addon.IsInstalled("TradeSkillMaster_AppHelper") or not Addon.IsEnabled("TradeSkillMaster_AppHelper") then
		return
	end

	local appDB = _G[APP_DB_GLOBAL_NAME]
	if not appDB then
		appDB = {}
		_G[APP_DB_GLOBAL_NAME] = appDB
	end
	appDB.region = private.addonRegion
	ErrorHandler.SaveReports(appDB)
	private.SaveBlackMarket(appDB)
	private.SaveAnalytics(appDB)
	private.SaveFullScan(appDB)
	private.SaveGroupImports(appDB)
end

function private.SaveBlackMarket(appDB)
	local realmName = SessionInfo.GetRealmName()
	appDB.blackMarket = appDB.blackMarket or {}
	local blackMarketData, blackMarketTime = Auction.GetBlackMarketScanData()
	if blackMarketData then
		appDB.blackMarket[realmName] = {
			data = blackMarketData,
			key = Hash.Calculate(blackMarketData..":"..blackMarketTime),
			updateTime = blackMarketTime
		}
	end
end

function private.SaveAnalytics(appDB)
	appDB.analytics = appDB.analytics or {updateTime=0, data={}}
	appDB.analytics.updateTime = Analytics.GetLastEventTime() or appDB.analytics.updateTime

	-- Remove entries which are too old
	local minTime = LibTSMService.GetTime() - MAX_ANALYTICS_AGE
	local index, insertIndex = BinarySearch.Table(appDB.analytics.data, minTime, Analytics.GetEntryTime)
	local removeEndIndex = index or (insertIndex - 1)
	if removeEndIndex > 0 then
		Table.RemoveRange(appDB.analytics.data, 1, removeEndIndex)
	end

	-- Add new entries
	for _, eventStr in Analytics.EventIterator() do
		tinsert(appDB.analytics.data, eventStr)
	end
end

function private.SaveFullScan(appDB)
	appDB.fullScan = appDB.fullScan or {updateTime=0, data={}}

	-- Remove entries which are too old
	local minTime = LibTSMService.GetTime() - MAX_FULL_SCAN_AGE
	for i = #appDB.fullScan.data, 1, -1 do
		if appDB.fullScan.data[i].scanTime < minTime then
			tremove(appDB.fullScan.data, i)
		end
	end

	-- Save the new data (if available)
	local data, scanTime = Auction.GetFullScanData()
	if not data then
		return
	end
	appDB.fullScan.updateTime = scanTime
	tinsert(appDB.fullScan.data, {
		data = data,
		scanTime = scanTime,
	})
end

function private.SaveGroupImports(appDB)
	appDB.groupImports = {}
	for id, info in pairs(private.groupImportResults) do
		appDB.groupImports[id] = info.result
	end
end

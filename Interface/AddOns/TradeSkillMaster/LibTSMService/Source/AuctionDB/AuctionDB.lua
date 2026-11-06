-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionDB = LibTSMService:Init("AuctionDB")
local AppHelper = LibTSMService:Include("AppHelper")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Lifecycle = LibTSMService:Include("Util.Lifecycle")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local TimeFormat = LibTSMService:From("LibTSMWoW"):Include("UI.TimeFormat")
local private = {
	dataLoadCallback = nil,
	realmData = {},
	realmUpdateTime = nil, ---@type number
	regionData = {},
	regionUpdateTime = nil, ---@type number
	altRealmData = {},
}
local UPDATE_TIME_KEYS = {
	AUCTIONDB_NON_COMMODITY_DATA = true,
	AUCTIONDB_NON_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_REGION_STAT = true,
	AUCTIONDB_REGION_HISTORICAL = true,
	AUCTIONDB_REGION_SALE = true,
}
local RECENT_THRESHOLD = 12 * 60 * 60



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctionDB:OnModuleLoad(function()
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the AuctionDB code.
---@param dataLoadCallback fun() A function that's called when the data is fully loaded
function AuctionDB.Configure(dataLoadCallback)
	private.dataLoadCallback = dataLoadCallback
end

---Gets the data update times.
---@return number realmUpdateTime
---@return number regionUpdateTime
function AuctionDB.GetAppDataUpdateTimes()
	return private.realmUpdateTime, private.regionUpdateTime
end

---Checks if the last scan is recent or not.
---@return boolean
function AuctionDB.IsLastScanRecent()
	return LibTSMService.GetTime() - private.realmUpdateTime < RECENT_THRESHOLD
end

---Gets items from the last scan in a thread context.
---@param filterFunc fun(itemString: string, minBuyout: number): boolean A function used to filter the results (return true to remove the value)
---@param items string[] The table to store the resulting item list in
function AuctionDB.GetLastScanItemsThreaded(filterFunc, items)
	local minBuyoutData = private.realmData.minBuyout
	local minBuyoutIndex = minBuyoutData.fieldLookup.minBuyout
	assert(minBuyoutIndex)
	local includedItems = Threading.AcquireSafeTempTable()
	local baseItems = Threading.AcquireSafeTempTable()
	for item in pairs(minBuyoutData.itemLookup) do
		local data = private.UnpackData(minBuyoutData, item)
		local minBuyout = data and data[minBuyoutIndex] or nil
		local itemString = ItemString.Get(item)
		assert(itemString)
		local baseItemString = ItemString.GetBaseFast(itemString)
		if baseItemString ~= itemString then
			baseItems[baseItemString] = true
		end
		minBuyout = min(includedItems[itemString] or math.huge, minBuyout or 0)
		if minBuyout > 0 and not filterFunc(itemString, minBuyout) then
			includedItems[itemString] = minBuyout
		end
		Threading.Yield()
	end

	-- Remove the base items since they would be double-counted with the specific variants
	for itemString in pairs(baseItems) do
		includedItems[itemString] = nil
	end

	Table.GetKeys(includedItems, items)
	TempTable.Release(baseItems)
	TempTable.Release(includedItems)
end

---Gets realm data for an item.
---@param key string The data key
---@param itemString string The item string
---@return number?
function AuctionDB.GetRealmData(key, itemString)
	return private.GetItemDataHelper(private.realmData[key], key, itemString)
end

---Gets alt realm data for an item.
---@param key string The data key
---@param itemString string The item string
---@return number?
function AuctionDB.GetAltRealmData(key, itemString)
	return private.GetItemDataHelper(private.altRealmData[key], key, itemString)
end

---Gets region data for an item.
---@param key string The data key
---@param itemString string The item string
---@return number?
function AuctionDB.GetRegionData(key, itemString)
	return private.GetItemDataHelper(private.regionData[key], key, itemString)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	local auctionDBData = AppHelper.GetAndClearAuctionDBData()
	if auctionDBData then
		private.realmUpdateTime = private.LoadRegionRealmAppData(private.realmData, auctionDBData.realm)
		private.regionUpdateTime = private.LoadRegionRealmAppData(private.regionData, auctionDBData.region)
		private.LoadRegionRealmAppData(private.realmData, auctionDBData.commodity)
		private.LoadRegionRealmAppData(private.altRealmData, auctionDBData.altRealm)
		if next(private.altRealmData) then
			private.LoadRegionRealmAppData(private.altRealmData, auctionDBData.commodity)
		end

		-- Pre-fetch item info for items currently on the AH
		if private.realmData.minBuyout then
			for itemString in pairs(private.realmData.minBuyout.itemLookup) do
				ItemInfo.FetchInfo(itemString)
			end
		end
	else
		private.realmUpdateTime = 0
		private.regionUpdateTime = 0
	end

	private.dataLoadCallback()
	return true
end

function private.LoadRegionRealmAppData(tbl, appData)
	local maxUpdateTime = 0
	for key, data in pairs(appData) do
		local loadedData, updateTime = private.LoadAppData(data)
		local existing = tbl[next(loadedData.fieldLookup)]
		if existing then
			-- Merge items into existing realmData
			assert(Table.Equal(existing.fieldLookup, loadedData.fieldLookup))
			for itemString, itemData in pairs(loadedData.itemLookup) do
				if existing.itemLookup[itemString] then
					error("Duplicate data for item: "..tostring(itemString))
				end
				existing.itemLookup[itemString] = itemData
			end
		else
			for field in pairs(loadedData.fieldLookup) do
				assert(not tbl[field])
				tbl[field] = loadedData
			end
		end
		Log.Info("Loaded %s data (%s)", key, TimeFormat.Duration(LibTSMService.GetTime() - updateTime).." ago")
		if UPDATE_TIME_KEYS[key] then
			maxUpdateTime = max(maxUpdateTime, updateTime)
		end
	end
	return maxUpdateTime
end

function private.LoadAppData(appData)
	-- Extract the metadata from the start of the string
	local metadataEndIndex, dataStartIndex = strfind(appData, ",data={")
	assert(metadataEndIndex and dataStartIndex)
	local itemData = strsub(appData, dataStartIndex + 1, -3)
	local metadataStr = strsub(appData, 1, metadataEndIndex - 1).."}"
	local metadata = assert(loadstring(metadataStr))()

	local result = { fieldLookup = {}, itemLookup = {} }
	assert(metadata.fields[1] == "itemString")
	for i = 2, #metadata.fields do
		result.fieldLookup[metadata.fields[i]] = i - 1
	end

	for itemString, otherData in gmatch(itemData, "{\"?([^,\"]+)\"?,([^}]+)}") do
		if tonumber(itemString) then
			itemString = "i:"..itemString
		end
		result.itemLookup[itemString] = otherData
	end

	return result, metadata.downloadTime
end

function private.GetItemDataHelper(tbl, key, itemString)
	if not itemString or not tbl then
		return nil
	end
	local fieldIndex = tbl.fieldLookup[key]
	if not fieldIndex then
		return nil
	end
	-- Convert to a level item string
	itemString = ItemString.ToLevel(itemString)
	if not tbl.itemLookup[itemString] then
		-- Try the base item
		itemString = ItemString.GetBaseFast(itemString)
		if not tbl.itemLookup[itemString] then
			return nil
		end
	end
	local data = private.UnpackData(tbl, itemString)
	local value = data and data[fieldIndex] or 0
	return value > 0 and value or nil
end

---@return number[]?
function private.UnpackData(tbl, itemString)
	local data = tbl.itemLookup[itemString]
	if type(data) ~= "string" then
		return data
	end
	-- Need to unpack the data
	local tblData = {strsplit(",", data)}
	for i = 1, #tblData do
		local val = tblData[i]
		if #val > 6 then
			-- tonumber only works for 32-bit values, so need to cut the value in half
			local lower = tonumber(strsub(val, -6), 32)
			local upper = tonumber(strsub(val, 1, -7), 32)
			assert(lower and upper)
			val = lower + upper * (2 ^ 30)
		else
			val = tonumber(val, 32)
			assert(val)
		end
		tblData[i] = val
	end
	tbl.itemLookup[itemString] = tblData
	data = tblData
	return data
end

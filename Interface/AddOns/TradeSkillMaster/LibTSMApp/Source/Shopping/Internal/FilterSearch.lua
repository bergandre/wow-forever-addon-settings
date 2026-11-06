-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local FilterSearch = LibTSMApp:DefineInternalClassType("FilterSearch")
local FilterSearchContext = LibTSMApp:IncludeClassType("FilterSearchContext")
local CanIMogItIntegration = LibTSMApp:Include("Shopping.CanIMogItIntegration")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local DisenchantData = LibTSMApp:From("LibTSMData"):Include("Disenchant")
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local String = LibTSMApp:From("LibTSMUtil"):Include("Lua.String")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local EnumTypes = LibTSMApp:From("LibTSMTypes"):Include("EnumTypes")
local Conversion = LibTSMApp:From("LibTSMTypes"):Include("Item.Conversion")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local ShoppingSavedSearches = LibTSMApp:From("LibTSMTypes"):Include("SavedSearches.ShoppingSavedSearches")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local ItemClass = LibTSMApp:From("LibTSMWoW"):Include("Util.ItemClass")
local Conversions = LibTSMApp:From("LibTSMService"):Include("Item.Conversions")
local ItemFilter = LibTSMApp:From("LibTSMService"):IncludeClassType("ItemFilter")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settings = nil,
	created = false,
	validationItemFilter = ItemFilter.New(),
	filtersTemp = {},
}
local DISENCHANT_CLASS_ID_LOOKUP = {
	[DisenchantData.ITEM_CLASSES.ARMOR] = ItemClass.GetArmorClassId(),
	[DisenchantData.ITEM_CLASSES.WEAPON] = ItemClass.GetWeaponClassId(),
	[DisenchantData.ITEM_CLASSES.PROFESSION] = ItemClass.GetProfessionClassId(),
}
local ITEM_FILTER_ERROR_LOOKUP = {
	[ItemFilter.ERROR.ITEM_NOT_FOUND] = L["The specified item was not found."],
	[ItemFilter.ERROR.DUPLICATE_FILTER] = L["The same filter was specified multiple times."],
	[ItemFilter.ERROR.MAX_QUANTITY_ZERO] = L["The max quantity cannot be zero."],
	[ItemFilter.ERROR.UNKNOWN_WORD] = L["Unknown word (%s)."],
	[ItemFilter.ERROR.CRAFTING_DISENCHANT_ADDITIONAL] = L["Cannot use additional filters with /crafting or /disenchant."],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(FilterSearch, function(db)
	private.settings = db:NewView("FilterSearchSettings")
		:AddKey("global", "shoppingOptions", "pctSource")
		:Commit()
end)



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function FilterSearch:__init()
	-- This is a singleton class since it contains a thread
	assert(not private.created)
	private.created = true
	self._scanThreadId = Threading.New("SHOPPING_FILTER_SEARCH", self:__closure("_ScanThread"))
	self._searchContext = FilterSearchContext(self, self._scanThreadId, self:__closure("_GetMarketValue"))
	self._maxQuantityParentQuery = {} ---@type table<AuctionQuery,AuctionQuery>
	self._maxQuantity = {} ---@type table<AuctionQuery,number>
	self._itemFilter = ItemFilter.New()
	self._itemMap = {}
	self._queryMap = {}
	self._itemListTemp = {}
	self._firstQuery = nil
	self._auctionScan = nil
	self._addedAuctionScanCallbacks = false
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Validates and sanitizes a filter string.
---@param filterStr string The filter string
---@param mode EnumValue The search mode
---@param showError? boolean Whether or not to display the error to the user
---@return string?
function FilterSearch:ValidateFilterString(filterStr, mode, showError)
	local origFilterStr = filterStr
	filterStr = strtrim(filterStr)
	if mode == EnumTypes.SHOPPING_SEARCH_MODE.NORMAL and not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic() and filterStr == "" then
		return filterStr
	elseif filterStr == "" then
		if showError then
			ChatMessage.PrintUser(format(L["Invalid search filter (%s)."], origFilterStr).." "..L["The specified filter was empty."])
		end
		return nil
	end
	assert(not next(private.filtersTemp))
	for filterPart in String.SplitIterator(filterStr, ";") do
		local validatedFilterPart, errMsg = private.ValidateFilterPart(filterPart, mode)
		if validatedFilterPart then
			tinsert(private.filtersTemp, validatedFilterPart)
		else
			wipe(private.filtersTemp)
			if showError then
				ChatMessage.PrintUser(format(L["Invalid search filter (%s)."], origFilterStr).." "..errMsg)
			end
			return nil
		end
	end
	local result = table.concat(private.filtersTemp, ";")
	wipe(private.filtersTemp)
	assert(result ~= "")
	return result
end

---Prepares and returns the scan context.
---@param name string The name of the scan
---@param filterInfo any The filter info
---@param postContext? AuctionPostContext The post context
---@param pctTooltip string The percent tooltip
---@param isGathering boolean Whether or not this is a gathering search
---@param isSpecial boolean Whether or not this is a special search which is not recorded as a recent saved search
---@return FilterSearchContext
function FilterSearch:PrepareScanContext(name, filterInfo, postContext, pctTooltip, isGathering, isSpecial)
	return self._searchContext:SetScanContext(name, filterInfo, postContext, pctTooltip, isGathering, isSpecial)
end

---Gets the max quantity of an item which can be bought.
---@param itemString string The item
---@return number?
function FilterSearch:GetMaxCanBuy(itemString)
	local targetItemString = self._itemMap[itemString]
	local query = self:_GetMaxQuantityParentQueryForItem(targetItemString or itemString)
	local maxNum = query and self._maxQuantity[query] or nil
	if maxNum and targetItemString then
		local rate, chunkSize = private.GetRate(targetItemString, itemString)
		maxNum = Math.Ceil(maxNum / rate, chunkSize)
	end
	return maxNum
end

---Handles a purchase of an item.
---@param itemString string The item which was bought
---@param quantity number The quantity bought
function FilterSearch:HandlePurchase(itemString, quantity)
	local targetItemString = self._itemMap[itemString]
	local query = self:_GetMaxQuantityParentQueryForItem(targetItemString or itemString)
	if not query then
		return
	end
	self._maxQuantity[query] = self._maxQuantity[query] - quantity * (targetItemString and private.GetRate(targetItemString, itemString) or 1)
	if self._maxQuantity[query] <= 0 then
		for childQuery, parentQuery in pairs(self._maxQuantityParentQuery) do
			if parentQuery == query then
				childQuery:WipeBrowseResults()
			end
		end
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param auctionScan AuctionScanManager
function FilterSearch.__private:_ScanThread(auctionScan, filterStr)
	wipe(self._itemMap)
	wipe(self._queryMap)
	wipe(self._maxQuantity)
	wipe(self._maxQuantityParentQuery)
	self._firstQuery = nil
	self._auctionScan = auctionScan
	self._addedAuctionScanCallbacks = false

	-- Set up the search and add queries
	self:_AddQueriesThreaded(filterStr)

	-- Run the scan
	if not self._auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
	return true
end

function FilterSearch.__private:_AddQueriesThreaded(filterStr)
	if not LibTSMApp.IsVanillaClassic() and not LibTSMApp.IsBCClassic() and filterStr == "" then
		-- Empty search
		self._auctionScan:NewQuery()
			:SetStr("")
		return
	end
	for filterPart in String.SplitIterator(filterStr, ";") do
		assert(filterPart == strtrim(filterPart) and filterPart ~= "")
		assert(self._itemFilter:ParseStr(filterPart) and true or false)
		local searchMode = self._itemFilter:GetShoppingSearchMode()
		if searchMode == EnumTypes.SHOPPING_SEARCH_MODE.NORMAL then
			self:_AddItemFilterQuery(self._itemFilter)
		else
			local itemName = self._itemFilter:GetStr()
			assert(itemName)
			local maxQuantity = self._itemFilter:GetMaxQuantity()
			self:_AddTargetItemQueriesThreaded(itemName, maxQuantity, searchMode)
		end
	end
	if not self._searchContext:IsSpecial() then
		ShoppingSavedSearches.Record(filterStr)
	end
end

---@param itemFilter ItemFilter
function FilterSearch.__private:_AddItemFilterQuery(itemFilter)
	local query = self._auctionScan:NewQuery()
		:SetStr(itemFilter:GetStr(), itemFilter:GetExactOnly())
		:SetQualityRange(itemFilter:GetMinQuality(), itemFilter:GetMaxQuality())
		:SetLevelRange(itemFilter:GetMinLevel(), itemFilter:GetMaxLevel())
		:SetItemLevelRange(itemFilter:GetMinItemLevel(), itemFilter:GetMaxItemLevel())
		:SetClass(itemFilter:GetClass(), itemFilter:GetSubClass(), itemFilter:GetInvSlotId())
		:SetUsable(itemFilter:GetUsableOnly())
		:SetUncollected(itemFilter:GetUncollected())
		:SetUpgrades(itemFilter:GetUpgrades())
		:SetPriceRange(itemFilter:GetMinPrice(), itemFilter:GetMaxPrice())
		:SetItems(itemFilter:GetItem())
	CanIMogItIntegration.PopulateAuctionQuery(query, itemFilter)
	local maxQuantity = itemFilter:GetMaxQuantity()
	if maxQuantity then
		assert(not self._maxQuantity[query] and not self._maxQuantityParentQuery[query])
		self._maxQuantity[query] = maxQuantity
		self._maxQuantityParentQuery[query] = query
	end
end

function FilterSearch.__private:_AddTargetItemQueriesThreaded(targetItemName, maxQuantity, searchMode)
	assert(searchMode == EnumTypes.SHOPPING_SEARCH_MODE.DISENCHANT or searchMode == EnumTypes.SHOPPING_SEARCH_MODE.CRAFTING)
	self._firstQuery = nil
	wipe(self._itemListTemp)

	-- Get the target item
	local targetItemString = private.GetTargetItem(targetItemName)
	assert(targetItemString)

	-- Generate general search queries
	if searchMode == EnumTypes.SHOPPING_SEARCH_MODE.DISENCHANT then
		local data = Conversion.GetDisenchantData(targetItemString)
		assert(data)
		for _, info in ipairs(data.sourceInfo) do
			local query = self:_CreateDisenchantQuery(info, data.minLevel, data.maxLevel)
			self:_HandleQueryAdded(query, targetItemString, maxQuantity)
		end
	end

	-- Get the list of items to search for and generate queries for them
	assert(not next(self._itemListTemp))
	tinsert(self._itemListTemp, targetItemString)
	self._itemMap[targetItemString] = targetItemString
	if searchMode == EnumTypes.SHOPPING_SEARCH_MODE.CRAFTING then
		local conversionInfo = Conversion.GetSourceItems(targetItemString)
		assert(conversionInfo)
		for itemString in pairs(conversionInfo) do
			if not self._itemMap[itemString] then
				self._itemMap[itemString] = targetItemString
				tinsert(self._itemListTemp, itemString)
			end
		end
	end
	for _, query in self._auctionScan:AddItemListQueriesThreaded(self._itemListTemp) do
		self:_HandleQueryAdded(query, targetItemString, maxQuantity)
	end
	wipe(self._itemListTemp)

	if not self._addedAuctionScanCallbacks then
		self._auctionScan:AddResultsUpdateCallback(self:__closure("_HandleResultsUpdated"))
		self._auctionScan:SetScript("OnQueryDone", self:__closure("_HandleQueryDone"))
		self._addedAuctionScanCallbacks = true
	end
end

function FilterSearch.__private:_CreateDisenchantQuery(info, minLevel, maxLevel)
	local classId = DISENCHANT_CLASS_ID_LOOKUP[info.class]
	assert(classId)
	return self._auctionScan:NewQuery()
		:SetLevelRange(minLevel, maxLevel)
		:SetQualityRange(info.quality, info.quality)
		:SetClass(classId)
		:SetItemLevelRange(info.minItemLevel, info.maxItemLevel)
end

---@param query AuctionQuery
function FilterSearch.__private:_HandleQueryAdded(query, targetItemString, maxQuantity)
	self._queryMap[query] = targetItemString
	query:AddCustomFilter(self:__closure("_TargetItemQueryFilter"))
	if not maxQuantity then
		return
	end
	assert(not self._maxQuantity[query] and not self._maxQuantityParentQuery[query])
	assert(not self._firstQuery or self._maxQuantity[self._firstQuery])
	self._maxQuantityParentQuery[query] = self._firstQuery or query
	if not self._firstQuery then
		self._maxQuantity[query] = maxQuantity
		self._firstQuery = query
	end
end

---@param query AuctionQuery
---@param row AuctionSubRow
function FilterSearch.__private:_TargetItemQueryFilter(query, row)
	local itemString = row:GetItemString()
	if not itemString then
		return false
	end
	local targetItemString = self._itemMap[itemString] or self._queryMap[query]
	if not targetItemString then
		return false
	end
	return private.GetRate(targetItemString, itemString) == 0
end

function FilterSearch.__private:_HandleResultsUpdated(_, query)
	local targetItemString = self._queryMap[query]
	if not targetItemString then
		return
	end

	-- Populate the item map for each item in the results
	for _, row in query:BrowseResultsIterator() do
		if row:HasItemInfo() then
			for _, subRow in row:SubRowIterator() do
				local itemString = subRow:GetItemString()
				if itemString then
					self._itemMap[itemString] = targetItemString
				end
			end
		end
	end
end

function FilterSearch.__private:_HandleQueryDone(_, query)
	self:_HandleResultsUpdated(nil, query)
	self._queryMap[query] = nil
end

function FilterSearch.__private:_GetMarketValue(subRow)
	local marketValueSource = self._searchContext:GetGatheringResultsFunc() and "MatPrice" or private.settings.pctSource
	local baseItemString = subRow:GetBaseItemString()
	local itemString = subRow:GetItemString()
	if next(self._itemMap) then
		local targetItemString = self._itemMap[itemString]
		if not itemString or not targetItemString then
			return nil
		end
		local targetItemRate = private.GetRate(targetItemString, itemString)
		return Math.Round(targetItemRate * CustomString.GetValue(marketValueSource, targetItemString))
	else
		local value = CustomString.GetValue(marketValueSource, itemString or baseItemString)
		return value
	end
end

function FilterSearch.__private:_GetMaxQuantityParentQueryForItem(itemString)
	for query, parentQuery in pairs(self._maxQuantityParentQuery) do
		if query:HasItemSubRow(itemString) then
			return parentQuery
		end
	end
	return nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetRate(targetItemString, sourceItemString)
	if sourceItemString == targetItemString then
		return 1, 1
	end
	if Conversion.IsDisenchantTargetItem(targetItemString) then
		local classId = ItemInfo.GetClassId(sourceItemString)
		local quality = ItemInfo.GetQuality(sourceItemString)
		local itemLevel = LibTSMApp.IsRetail() and ItemInfo.GetItemLevel(sourceItemString) or ItemInfo.GetItemLevel(ItemString.GetBaseFast(sourceItemString))
		local expansion = LibTSMApp.IsRetail() and ItemInfo.GetExpansion(sourceItemString) or nil
		local amountOfMats = classId and quality and itemLevel and Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
		if amountOfMats then
			return amountOfMats, 1
		end
	end
	local conversionInfo = Conversion.GetSourceItems(targetItemString)
	local conversionChunkSize = 1
	for _ in Conversion.TargetItemsByMethodIterator(sourceItemString, Conversion.METHOD.MILL) do
		conversionChunkSize = 5
	end
	for _ in Conversion.TargetItemsByMethodIterator(sourceItemString, Conversion.METHOD.PROSPECT) do
		conversionChunkSize = 5
	end
	return conversionInfo and conversionInfo[sourceItemString] or 0, conversionChunkSize
end

function private.ValidateFilterPart(filter, mode)
	filter = strtrim(filter)
	if gsub(filter, "/", "") == "" then
		return nil, L["The specified filter was empty."]
	end
	local filterIsValid, filterErrType, filterErrArg = private.validationItemFilter:ParseStr(filter)
	if not filterIsValid then
		return nil, format(ITEM_FILTER_ERROR_LOOKUP[filterErrType], filterErrArg)
	end

	local str = private.validationItemFilter:GetStr()
	if mode == EnumTypes.SHOPPING_SEARCH_MODE.CRAFTING and not strfind(strlower(filter), "/crafting") and str then
		filter = filter.."/crafting"
	elseif mode == EnumTypes.SHOPPING_SEARCH_MODE.DISENCHANT and not strfind(strlower(filter), "/disenchant") and str then
		filter = filter.."/disenchant"
	end
	if strfind(strlower(filter), "/crafting") then
		local craftingTargetItem = str and private.GetTargetItem(str) or nil
		if not craftingTargetItem or not Conversion.GetSourceItems(craftingTargetItem) then
			return nil, L["The specified item is not supported for crafting searches."]
		end
	end
	if strfind(strlower(filter), "/disenchant") then
		local targetItemString = str and private.GetTargetItem(str) or nil
		if not Conversion.IsDisenchantTargetItem(targetItemString) then
			return nil, L["The specified item is not supported for disenchant searches."]
		end
	end
	return filter, nil
end

function private.GetTargetItem(targetItemName)
	targetItemName = strlower(targetItemName)
	for targetItemString in Conversion.TargetItemIterator() do
		local name = ItemInfo.GetName(targetItemString)
		if name and strlower(name) == targetItemName then
			return targetItemString
		end
	end
	for targetItemString in Conversion.DisenchantTargetItemIterator() do
		local name = ItemInfo.GetName(targetItemString)
		if name and strlower(name) == targetItemName then
			return targetItemString
		end
	end
	return nil
end

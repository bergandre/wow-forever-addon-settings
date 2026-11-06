-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local AuctioningSavedSearches = LibTSMTypes:Init("SavedSearches.AuctioningSavedSearches")
local Util = LibTSMTypes:Include("SavedSearches.Util")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Database = LibTSMTypes:From("LibTSMDatabase"):Include("Database")
local private = {
	db = nil,
	data = nil,
	defaultNameFunc = nil,
}
local SEARCH_TYPE = EnumType.New("AUCTIONING_SAVED_EARCH_TYPE", {
	POST_ITEMS = EnumType.NewValue(),
	POST_GROUPS = EnumType.NewValue(),
	CANCEL_GROUPS = EnumType.NewValue(),
})
AuctioningSavedSearches.SEARCH_TYPE = SEARCH_TYPE
local SEARCH_TYPE_STR = {
	[SEARCH_TYPE.POST_ITEMS] = "postItems",
	[SEARCH_TYPE.POST_GROUPS] = "postGroups",
	[SEARCH_TYPE.CANCEL_GROUPS] = "cancelGroups",
}
local SEARCH_TYPE_LOOKUP = {
	postItems = SEARCH_TYPE.POST_ITEMS,
	postGroups = SEARCH_TYPE.POST_GROUPS,
	cancelGroups = SEARCH_TYPE.CANCEL_GROUPS,
}
local FILTER_SEP = "\001"
local MAX_RECENT_SEARCHES = 500

---@class AuctioningSavedSearchesData
---@field filters string[]
---@field searchTypes string[]
---@field name table<string,string>
---@field isFavorite table<string,boolean>



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctioningSavedSearches:OnModuleLoad(function()
	private.db = Database.NewSchema("AUCTIONING_SAVED_SEARCHES")
		:AddUniqueNumberField("index")
		:AddBooleanField("isFavorite")
		:AddEnumField("searchType", SEARCH_TYPE)
		:AddStringField("filter")
		:AddStringField("name")
		:AddIndex("index")
		:AddIndex("name")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the auctioning saved searches code.
---@param data AuctioningSavedSearchesData The saved searches data
---@param defaultNameFunc fun(filter: string, searchType: EnumValue): string A function to generate a default display name for a saved search
function AuctioningSavedSearches.Configure(data, defaultNameFunc)
	Util.CleanData(data, MAX_RECENT_SEARCHES)
	private.data = data
	private.defaultNameFunc = defaultNameFunc
	private.RebuildDB()
end

---Gets the filter separator.
---@return string
function AuctioningSavedSearches.GetFilterSeparator()
	return FILTER_SEP
end

---Get a query for recent searches.
---@return DatabaseQuery
function AuctioningSavedSearches.CreateRecentQuery()
	return private.db:NewOwnedQuery()
		:OrderBy("index", false)
end

---Get a query for favorite searches.
---@return DatabaseQuery
function AuctioningSavedSearches.CreateFavoriteQuery()
	return private.db:NewOwnedQuery()
		:Equal("isFavorite", true)
		:OrderBy("name", true)
end

---Gets the search type and populates the filters.
---@param index number The index of the search
---@param filters string[] A table that's populated with the filters
---@return EnumValue searchType
function AuctioningSavedSearches.GetInfo(index, filters)
	local searchType, filter = private.db:GetRowFields(private.db:GetUniqueRow("index", index), "searchType", "filter")
	String.SafeSplit(filter, FILTER_SEP, filters)
	return searchType
end

---Sets whether or not a search is favorited.
---@param index number The index of the search
---@param isFavorite boolean Whether or not the search is favorited
function AuctioningSavedSearches.SetIsFavorite(index, isFavorite)
	local uuid = private.db:GetUniqueRow("index", index)
	private.db:UpdateRow(uuid, "isFavorite", isFavorite)
	local filter = private.db:GetRowFields(uuid, "filter")
	private.data.isFavorite[filter] = isFavorite or nil
end

---Renames a search.
---@param index number The index of the search to rename
---@param newName string The new name
function AuctioningSavedSearches.Rename(index, newName)
	local uuid = private.db:GetUniqueRow("index", index)
	private.db:UpdateRow(uuid, "name", newName)
	local filter = private.db:GetRowFields(uuid, "filter")
	private.data.name[filter] = newName
end

---Deletes a search.
---@param index number The index of the search to delete
function AuctioningSavedSearches.Delete(index)
	Util.Delete(private.data, index)
	private.RebuildDB()
end

---Records a new search.
---@param searchList string[] The list of items or groups being searched for
---@param searchType EnumValue The type of search
function AuctioningSavedSearches.Record(searchList, searchType)
	assert(SEARCH_TYPE:HasValue(searchType))
	local searchTypeStr = SEARCH_TYPE_STR[searchType]
	assert(searchTypeStr)
	local filter = table.concat(searchList, FILTER_SEP)

	if Util.MoveFilterToEndIfExists(private.data, filter, searchTypeStr, true) then
		private.RebuildDB()
		return
	end

	-- Didn't find an existing entry, so add a new one
	tinsert(private.data.filters, filter)
	tinsert(private.data.searchTypes, searchTypeStr)
	assert(#private.data.filters == #private.data.searchTypes)
	private.db:InsertRow(#private.data.filters, false, searchType, filter, private.defaultNameFunc(filter, searchType))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RebuildDB()
	assert(#private.data.filters == #private.data.searchTypes)
	private.db:TruncateAndBulkInsertStart()
	for index, filter in ipairs(private.data.filters) do
		local searchType = SEARCH_TYPE_LOOKUP[private.data.searchTypes[index]]
		assert(searchType)
		local name = private.data.name[filter] or private.defaultNameFunc(filter, searchType)
		local isFavorite = private.data.isFavorite[filter] and true or false
		private.db:BulkInsertNewRow(index, isFavorite, searchType, filter, name)
	end
	private.db:BulkInsertEnd()
end

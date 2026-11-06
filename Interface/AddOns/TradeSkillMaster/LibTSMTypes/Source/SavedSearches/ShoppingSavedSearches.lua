-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local ShoppingSavedSearches = LibTSMTypes:Init("SavedSearches.ShoppingSavedSearches")
local Util = LibTSMTypes:Include("SavedSearches.Util")
local Database = LibTSMTypes:From("LibTSMDatabase"):Include("Database")
local private = {
	db = nil,
	data = nil,
}
local MAX_RECENT_SEARCHES = 2000

---@class ShoppingSavedSearchesData
---@field filters string[]
---@field name table<string,string>
---@field isFavorite table<string,boolean>



-- ============================================================================
-- Module Loading
-- ============================================================================

ShoppingSavedSearches:OnModuleLoad(function()
	private.db = Database.NewSchema("SHOPPING_SAVED_SEARCHES")
		:AddUniqueNumberField("index")
		:AddStringField("name")
		:AddBooleanField("isFavorite")
		:AddStringField("filter")
		:AddIndex("index")
		:AddIndex("name")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the shopping saved searches code.
---@param data ShoppingSavedSearchesData The saved searches data
function ShoppingSavedSearches.Configure(data)
	Util.CleanData(data, MAX_RECENT_SEARCHES)
	private.data = data
	private.RebuildDB()
end

---Creates a recent searches query.
---@return DatabaseQuery
function ShoppingSavedSearches.CreateRecentQuery()
	return private.db:NewOwnedQuery()
		:OrderBy("index", false)
end

---Creates a favorite searches query.
---@return DatabaseQuery
function ShoppingSavedSearches.CreateFavoriteQuery()
	return private.db:NewOwnedQuery()
		:Equal("isFavorite", true)
		:OrderBy("name", true)
end

---Sets whether or not a search should be favorited.
---@param index number The search index
---@param isFavorite boolean Whether or not it should be favorited
function ShoppingSavedSearches.SetIsFavorite(index, isFavorite)
	local uuid = private.db:GetUniqueRow("index", index)
	private.db:UpdateRow(uuid, "isFavorite", isFavorite)
	local filter = private.db:GetRowFields(uuid, "filter")
	private.data.isFavorite[filter] = isFavorite or nil
end

---Renames a search.
---@param index number The search index
---@param newName string The new name
function ShoppingSavedSearches.Rename(index, newName)
	local uuid = private.db:GetUniqueRow("index", index)
	private.db:UpdateRow(uuid, "name", newName)
	local filter = private.db:GetRowFields(uuid, "filter")
	private.data.name[filter] = newName ~= filter and newName or nil
end

---Deletes a search.
---@param index number The index of the search
function ShoppingSavedSearches.Delete(index)
	Util.Delete(private.data, index)
	private.RebuildDB()
end

---Records a new search.
---@param filter string The search filter
function ShoppingSavedSearches.Record(filter)
	if Util.MoveFilterToEndIfExists(private.data, filter, nil, false) then
		private.RebuildDB()
		return
	end

	-- Didn't find an existing entry, so add a new one
	tinsert(private.data.filters, filter)
	private.db:InsertRow(#private.data.filters, filter, false, filter)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RebuildDB()
	private.db:TruncateAndBulkInsertStart()
	for index, filter in ipairs(private.data.filters) do
		local name = private.data.name[filter] or filter
		local isFavorite = private.data.isFavorite[filter] and true or false
		private.db:BulkInsertNewRow(index, name, isFavorite, filter)
	end
	private.db:BulkInsertEnd()
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Util = LibTSMTypes:InitInternal("SavedSearches.Util")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local private = {
	seenTemp = {},
}

---@alias SavedSearchesData AuctioningSavedSearchesData|ShoppingSavedSearchesData



-- ============================================================================
-- Module Functions
-- ============================================================================

---Cleans the saved searches data by removing duplicates and old recent searches beyond the max.
---@param data SavedSearchesData The saved searches data
---@param maxRecentSearches number The maximum number of recent searches to keep
function Util.CleanData(data, maxRecentSearches)
	local numKeptRecentSearches, numRemovedRecent, numRemovedDuplicates = 0, 0, 0
	assert(not next(private.seenTemp))
	for i, filter in Table.ReverseIPairs(data.filters) do
		if private.seenTemp[filter] then
			Util.Delete(data, i)
			numRemovedDuplicates = numRemovedDuplicates + 1
		elseif not data.isFavorite[filter] and numKeptRecentSearches >= maxRecentSearches then
			Util.Delete(data, i)
			numRemovedRecent = numRemovedRecent + 1
		else
			private.seenTemp[filter] = true
			if not data.isFavorite[filter] then
				numKeptRecentSearches = numKeptRecentSearches + 1
			end
		end
	end
	wipe(private.seenTemp)

	if numRemovedDuplicates > 0 or numRemovedRecent > 0 then
		Log.RaiseStackLevel()
		Log.Info("Removed %d duplicates and %d old recent searches", numRemovedDuplicates, numRemovedRecent)
		Log.LowerStackLevel()
	end
end

---Deletes a saved search.
---@param data SavedSearchesData The saved searches data
---@param index number The index to delete
function Util.Delete(data, index)
	local filter = tremove(data.filters, index)
	if data.searchTypes then
		tremove(data.searchTypes, index)
	end
	data.name[filter] = nil
	data.isFavorite[filter] = nil
end

---Moves a filter to the end of the list if it exists.
---@param data SavedSearchesData The saved searches data
---@param filter string The filter to move
---@param searchTypeStr? string The search type string if applicable
---@param caseSensitive boolean Whether or not the filter is case sensitive
---@return boolean
function Util.MoveFilterToEndIfExists(data, filter, searchTypeStr, caseSensitive)
	assert((searchTypeStr == nil and not data.searchTypes) or (searchTypeStr and data.searchTypes))
	filter = caseSensitive and filter or strlower(filter)
	for i, existingFilter in ipairs(data.filters) do
		local existingSearchType = data.searchTypes and data.searchTypes[i] or nil
		if filter == (caseSensitive and existingFilter or strlower(existingFilter)) and searchTypeStr == existingSearchType then
			-- Move this to the end of the list, but keep the existing filter so we don't need to update the isFavorite and name tables
			tremove(data.filters, i)
			tinsert(data.filters, existingFilter)
			if data.searchTypes then
				tremove(data.searchTypes, i)
				tinsert(data.searchTypes, existingSearchType)
			end
			return true
		end
	end
	return false
end

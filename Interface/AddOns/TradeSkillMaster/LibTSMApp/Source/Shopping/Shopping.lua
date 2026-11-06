-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Shopping = LibTSMApp:Init("Shopping")
local DisenchantSearch = LibTSMApp:IncludeClassType("DisenchantSearch")
local FilterSearch = LibTSMApp:IncludeClassType("FilterSearch")
local GreatDeals = LibTSMApp:Include("Shopping.GreatDeals")
local GroupSearch = LibTSMApp:IncludeClassType("GroupSearch")
local VendorSearch = LibTSMApp:IncludeClassType("VendorSearch")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local EnumTypes = LibTSMApp:From("LibTSMTypes"):Include("EnumTypes")
local ShoppingSavedSearches = LibTSMApp:From("LibTSMTypes"):Include("SavedSearches.ShoppingSavedSearches")
local private = {
	filterSearch = FilterSearch(),
	vendorSearch = VendorSearch(),
	disenchantSearch = DisenchantSearch(),
	groupSearch = GroupSearch(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Shopping, function(db)
	local settings = db:NewView("ShoppingSettings")
		:AddKey("global", "userData", "savedShoppingSearches")
		:Commit()
	ShoppingSavedSearches.Configure(settings.savedShoppingSearches)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not the great deals search is available.
---@return boolean
function Shopping.IsGreatDealsAvailable()
	return GreatDeals.IsAvailable()
end

---Gets the search context for a great deals search.
---@return FilterSearchContext?
function Shopping.GetGreatDealsSearchContext()
	local filterStr = private.filterSearch:ValidateFilterString(GreatDeals.GetFilter(), EnumTypes.SHOPPING_SEARCH_MODE.NORMAL)
	if not filterStr then
		return nil
	end
	return private.filterSearch:PrepareScanContext(L["Great Deals Search"], filterStr, nil, L["Market Value"], false, true)
end

---Gets the search context for a normal filter search.
---@param filterStr string The filter string
---@param postContext? AuctionPostContext The post context
---@return FilterSearchContext?
function Shopping.GetFilterSearchContext(filterStr, postContext)
	local validated = private.filterSearch:ValidateFilterString(filterStr, EnumTypes.SHOPPING_SEARCH_MODE.NORMAL, true)
	if not validated then
		return nil
	end
	return private.filterSearch:PrepareScanContext(validated, validated, postContext, L["Market Value"], false, false)
end

---Gets the search context for a gathering search.
---@param filterStr string The filter string
---@param mode EnumValue The shopping search mode
---@return FilterSearchContext?
function Shopping.GetGatheringSearchContext(filterStr, mode)
	local validated = private.filterSearch:ValidateFilterString(filterStr, mode)
	if not validated then
		return nil
	end
	return private.filterSearch:PrepareScanContext(L["Gathering Search"], validated, nil, L["Material Cost"], true, true)
end

---Gets the search context for a vendor search.
---@return VendorSearchContext
function Shopping.GetVendorSearchContext()
	return private.vendorSearch:GetSearchContext()
end

---Gets the search context for a disenchant search.
---@return AuctionSearchContext
function Shopping.GetDisenchantSearchContext()
	return private.disenchantSearch:GetSearchContext()
end

---Gets the search context for a group search.
---@param groupList GroupPathValue[] The list of group paths
---@return AuctionSearchContext
function Shopping.GetGroupSearchContext(groupList)
	return private.groupSearch:GetSearchContext(groupList)
end

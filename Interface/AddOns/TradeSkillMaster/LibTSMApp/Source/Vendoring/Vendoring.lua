-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Vendoring = LibTSMApp:Init("Vendoring")
local Groups = LibTSMApp:Include("Vendoring.Groups")
local Ignore = LibTSMApp:Include("Vendoring.Ignore")
local PotentialValue = LibTSMApp:Include("Vendoring.PotentialValue")
local Sell = LibTSMApp:Include("Vendoring.Sell")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds an item to the ignore list for the remainder of the session.
---@param itemString string The item string
function Vendoring.IgnoreItemSession(itemString)
	Ignore.AddSession(itemString)
end

---Adds an item to the ignore list permanently.
---@param itemString string The item string
function Vendoring.IgnoreItemPermanent(itemString)
	Ignore.AddPermanent(itemString)
end

---Removes an item from the permanent ignore list
---@param itemString string The item string
function Vendoring.ForgetIgnoreItemPermanent(itemString)
	Ignore.RemovePermanent(itemString)
end

---Creates an ignore DB query.
---@return DatabaseQuery
function Vendoring.CreateIgnoreQuery()
	return Ignore.CreateQuery()
end

---Creates a sell DB bag query.
---@return DatabaseQuery
function Vendoring.CreateBagsQuery()
	local query = BagTracking.CreateQueryBags()
		:Distinct("itemString")
		:LeftJoin(Ignore.GetDBForJoin(), "itemString")
		:LeftJoin(PotentialValue.GetDBForJoin(), "itemString")
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:VirtualField("vendorSell", "number", ItemInfo.GetVendorSell, "itemString", 0)
		:VirtualField("quality", "number", ItemInfo.GetQuality, "itemString", -1)
	Vendoring.ResetBagsQuery(query)
	return query
end

---Resets a sell DB bag query.
---@param query DatabaseQuery
function Vendoring.ResetBagsQuery(query)
	query:ResetFilters()
	BagTracking.FilterQueryBags(query)
	query:NotEqual("ignoreSession", true)
		:NotEqual("ignorePermanent", true)
		:Equal("isBound", false)
		:GreaterThan("vendorSell", 0)
end

---Sell an item to the vendor.
---@param itemString string The item string
function Vendoring.SellItem(itemString)
	return Sell.SellItem(itemString)
end

---Buys items in the specified groups.
---@param callback fun() The callback when buying is complete
---@param groups GroupPathValue[] The groups to buy items from
---@param isDryRun boolean Whether or not this is a dry run
function Vendoring.BuyGroups(callback, groups, isDryRun)
	Groups.Buy(callback, groups, isDryRun)
end

---Sells items in the specified groups.
---@param callback fun() The callback when selling is complete
---@param groups GroupPathValue[] The groups to buy items from
---@param isDryRun boolean Whether or not this is a dry run
function Vendoring.SellGroups(callback, groups, isDryRun)
	Groups.Sell(callback, groups, isDryRun)
end

---Stops any in-progress buying or selling.
function Vendoring.StopBuySell()
	Groups.StopBuySell()
end

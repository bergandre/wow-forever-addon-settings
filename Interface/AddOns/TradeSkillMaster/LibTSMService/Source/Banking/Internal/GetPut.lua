-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local GetPut = LibTSMService:InitInternal("Banking.GetPut")
local Move = LibTSMService:Include("Banking.Move")
local OpenFrame = LibTSMService:Include("Banking.OpenFrame")
local Util = LibTSMService:Include("Banking.Util")
local Guild = LibTSMService:Include("Guild")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local WarbankTracking = LibTSMService:Include("Inventory.WarbankTracking")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local private = {
	itemsTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Moves items from the bags to the open bank using a filter.
---@param filterStr string The filter string
---@param callback BankingMoveCallback A callback function which gets various events
function GetPut.PutByFilter(filterStr, callback)
	local target = OpenFrame.Get()
	assert(target)

	local filterItemString = ItemString.Get(filterStr)
	filterStr = String.Escape(strlower(filterStr))

	assert(not next(private.itemsTemp))
	private.GetItems(Util.FRAME.CONTAINER.BAG, private.itemsTemp)
	Table.Filter(private.itemsTemp, private.ShouldExcludeItem, filterStr, filterItemString)

	Move.Start(Util.FRAME.CONTAINER.BAG, target, private.itemsTemp, callback)
	Table.WipeAndDeallocate(private.itemsTemp)
end

---Moves items from the open bank to the bags using a filter.
---@param filterStr string The filter string
---@param callback BankingMoveCallback A callback function which gets various events
function GetPut.GetByFilter(filterStr, callback)
	local source = OpenFrame.Get()
	assert(source)

	local filterItemString = ItemString.Get(filterStr)
	filterStr = String.Escape(strlower(filterStr))

	assert(not next(private.itemsTemp))
	private.GetItems(source, private.itemsTemp)
	Table.Filter(private.itemsTemp, private.ShouldExcludeItem, filterStr, filterItemString)

	Move.Start(source, Util.FRAME.CONTAINER.BAG, private.itemsTemp, callback)
	Table.WipeAndDeallocate(private.itemsTemp)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetItems(frame, items)
	local query = nil
	if frame == Util.FRAME.GUILD_BANK then
		query = Guild.NewIndexQuery()
	elseif frame == Util.FRAME.CONTAINER.WARBANK then
		query = WarbankTracking.CreateQuerySlot()
	elseif frame == Util.FRAME.CONTAINER.BANK then
		query = BagTracking.CreateQueryBank()
	elseif frame == Util.FRAME.CONTAINER.BAG then
		query = BagTracking.CreateQueryBags()
	else
		error("Unknown frame: "..tostring(frame))
	end
	query
		:AutoRelease()
		:GroupedSum("itemString", "quantity", items)
end

function private.ShouldExcludeItem(itemString, _, filterStr, filterItemString)
	if strmatch(ItemString.GetBaseFast(itemString), filterStr) then
		return false
	elseif strmatch(strlower(ItemInfo.GetName(itemString) or ""), filterStr) then
		return false
	elseif filterItemString and itemString == filterItemString then
		return false
	end
	return true
end

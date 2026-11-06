-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Banking = LibTSMService:Init("Banking")
local EmptyRestore = LibTSMService:Include("Banking.EmptyRestore")
local GetPut = LibTSMService:Include("Banking.GetPut")
local Move = LibTSMService:Include("Banking.Move")
local OpenFrame = LibTSMService:Include("Banking.OpenFrame")
local Util = LibTSMService:Include("Banking.Util")
local Guild = LibTSMService:Include("Guild")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = LibTSMService:Include("Inventory.WarbankTracking")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Group = LibTSMService:From("LibTSMTypes"):Include("Group")
local private = {
	itemsTemp = {},
}
Banking.FRAME = Util.FRAME

---@alias BankingGetNumFunc fun(itemString: string, numHave: number): number



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for when the visible frame changes.
---@param callback fun(frame: EnumValue?) Callback which is passed the open frame
function Banking.RegisterFrameCallback(callback)
	OpenFrame.RegisterCallback(callback)
end

---Gets the current open banking frame.
---@return EnumValue?
function Banking.GetOpenFrame()
	return OpenFrame.Get()
end

---Deposits items into the open bank.
---@param items table<string,number> The items to deposit
---@param callback BankingMoveCallback A callback function which gets various events
function Banking.DepositItems(items, callback)
	local target = OpenFrame.Get()
	assert(target)
	Move.Start(Util.FRAME.CONTAINER.BAG, target, items, callback)
end

---Deposits items into the open bank.
---@param callback BankingMoveCallback A callback function which gets various events
---@param getNumFunc BankingGetNumFunc A function which returns the number to be moved
function Banking.DepositItemsWithFunc(callback, getNumFunc)
	assert(not next(private.itemsTemp))
	private.GetItems(Util.FRAME.CONTAINER.BAG, private.itemsTemp)
	private.ProcessNumMove(private.itemsTemp, getNumFunc)
	Banking.DepositItems(private.itemsTemp, callback)
	wipe(private.itemsTemp)
end

---Deposits items within the specified groups into the open bank.
---@param groups table<GroupPathValue,boolean> The set of groups to include
---@param callback BankingMoveCallback A callback function which gets various events
---@param getNumFunc? BankingGetNumFunc A function which returns the number to be moved or nil to move everything
function Banking.DepositGroupItems(groups, callback, getNumFunc)
	assert(not next(private.itemsTemp))
	private.GetItems(Util.FRAME.CONTAINER.BAG, private.itemsTemp)
	Table.Filter(private.itemsTemp, private.NotInGroups, groups)
	if getNumFunc then
		private.ProcessNumMove(private.itemsTemp, getNumFunc)
	end
	Banking.DepositItems(private.itemsTemp, callback)
	wipe(private.itemsTemp)
end

---Withdraws items from the open bank.
---@param items table<string,number> The items to withdraw
---@param callback BankingMoveCallback A callback function which gets various events
function Banking.WithdrawItems(items, callback)
	local source = OpenFrame.Get()
	assert(source)
	Move.Start(source, Util.FRAME.CONTAINER.BAG, items, callback)
end

---Withdraw items within the specified groups from the open bank.
---@param groups table<GroupPathValue,boolean> The set of groups to include
---@param callback BankingMoveCallback A callback function which gets various events
---@param getNumFunc BankingGetNumFunc A function which returns the number to be moved
function Banking.WithdrawGroupItems(groups, callback, getNumFunc)
	assert(not next(private.itemsTemp))
	private.GetItems(OpenFrame.Get(), private.itemsTemp)
	Table.Filter(private.itemsTemp, private.NotInGroups, groups)
	private.ProcessNumMove(private.itemsTemp, getNumFunc)
	Banking.WithdrawItems(private.itemsTemp, callback)
	wipe(private.itemsTemp)
end

---Empties the bags into the open bank.
---@param callback BankingMoveCallback A callback function which gets various events
function Banking.EmptyBags(callback)
	EmptyRestore.EmptyBags(callback)
end

---Returns whether or not the bags can be restored from the open bank.
---@return boolean
function Banking.CanRestoreBags()
	return EmptyRestore.CanRestoreBags()
end

---Restores the bags from the open bank.
---@param callback BankingMoveCallback A callback function which gets various events
function Banking.RestoreBags(callback)
	EmptyRestore.RestoreBags(callback)
end

---Moves items from the bags to the open bank using a filter.
---@param filterStr string The filter string
---@param callback BankingMoveCallback A callback function which gets various events
function Banking.PutByFilter(filterStr, callback)
	GetPut.PutByFilter(filterStr, callback)
end

---Moves items from the open bank to the bags using a filter.
---@param filterStr string The filter string
---@param callback BankingMoveCallback A callback function which gets various events
function Banking.GetByFilter(filterStr, callback)
	GetPut.GetByFilter(filterStr, callback)
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
			:If(OpenFrame.Get() == Util.FRAME.GUILD_BANK)
				:Equal("isBound", false)
			:End()
	else
		error("Unknown frame: "..tostring(frame))
	end
	query
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:GroupedSum("autoBaseItemString", "quantity", items)
end

function private.NotInGroups(itemString, _, groups)
	return not groups[Group.GetPathByItem(itemString)]
end

function private.ProcessNumMove(items, getNumFunc)
	for itemString, numHave in pairs(items) do
		local numToMove = getNumFunc(itemString, numHave)
		if numToMove > 0 then
			items[itemString] = numToMove
		else
			items[itemString] = nil
		end
	end
end

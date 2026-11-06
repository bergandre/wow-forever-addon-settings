-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local EmptyRestore = LibTSMService:InitInternal("Banking.EmptyRestore")
local Move = LibTSMService:Include("Banking.Move")
local OpenFrame = LibTSMService:Include("Banking.OpenFrame")
local Util = LibTSMService:Include("Banking.Util")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	restoreFrame = nil,
	callback = nil,
	restoreItems = {},
	itemsTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Empties the bags into the open bank.
---@param callback BankingMoveCallback A callback function which gets various events
function EmptyRestore.EmptyBags(callback)
	wipe(private.restoreItems)
	local target = OpenFrame.Get()
	assert(target)
	assert(not next(private.itemsTemp))
	private.GetItems(target, private.itemsTemp)
	private.restoreFrame = target
	private.callback = callback
	Move.Start(Util.FRAME.CONTAINER.BAG, target, private.itemsTemp, private.EmptyBagsThreadCallbackWrapper)
	Table.WipeAndDeallocate(private.itemsTemp)
end

---Returns whether or not the bags can be restored from the open bank.
---@return boolean
function EmptyRestore.CanRestoreBags()
	local openFrame = OpenFrame.Get()
	assert(openFrame)
	return openFrame == private.restoreFrame
end

---Restores the bags from the open bank.
---@param callback BankingMoveCallback A callback function which gets various events
function EmptyRestore.RestoreBags(callback)
	local source = OpenFrame.Get()
	assert(source and source == private.restoreFrame)
	private.callback = callback
	Move.Start(source, Util.FRAME.CONTAINER.BAG, private.restoreItems, private.RestoreBagsThreadCallbackWrapper)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetItems(target, items)
	BagTracking.CreateQueryBags()
		:AutoRelease()
		:If(target == Util.FRAME.GUILD_BANK)
			:Equal("isBound", false)
		:End()
		:GroupedSum("itemString", "quantity", items)
end

function private.EmptyBagsThreadCallbackWrapper(event, ...)
	if event == "MOVED" then
		local itemString, numMoved = ...
		private.restoreItems[itemString] = (private.restoreItems[itemString] or 0) + numMoved
	elseif event == "DONE" then
		if not next(private.restoreItems) then
			private.restoreFrame = OpenFrame.Get()
		end
	end
	private.callback(event, ...)
end

function private.RestoreBagsThreadCallbackWrapper(event, ...)
	if event == "DONE" then
		wipe(private.restoreItems)
		private.restoreFrame = nil
	end
	private.callback(event, ...)
end

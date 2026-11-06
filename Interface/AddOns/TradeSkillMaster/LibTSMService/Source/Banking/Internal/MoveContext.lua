-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local MoveContext = LibTSMService:DefineInternalClassType("MoveContext")
local Util = LibTSMService:Include("Banking.Util")
local GuildService = LibTSMService:Include("Guild")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = LibTSMService:Include("Inventory.WarbankTracking")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Group = LibTSMService:From("LibTSMTypes"):Include("Group")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Guild = LibTSMService:From("LibTSMWoW"):Include("API.Guild")
local SlotId = LibTSMService:From("LibTSMWoW"):Include("Type.SlotId")
local private = {
	sortValueTemp = {},
	containersTemp = {},
}



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MoveContext:__init()
	self._source = nil
	self._target = nil
	self._items = {}
	self._emptySlotIds = {}
	self._slotIds = {}
	self._slotItemString = {}
	self._slotMoveQuantity = {}
	self._slotEndQuantity = {}
	self._pendingSlotId = nil
end

---Configures the move context.
---@param source EnumValue The source frame
---@param target EnumValue The target frame
---@param items table<string,number> The items to be moved
function MoveContext:Configure(source, target, items)
	assert(not self._source and not self._target)
	assert(Util.FRAME:HasValue(source))
	assert(Util.FRAME:HasValue(target))
	self._source = source
	self._target = target
	for itemString, quantity in pairs(items) do
		self._items[itemString] = quantity
	end
end

---Resets the move context.
function MoveContext:Reset()
	self._source = nil
	self._target = nil
	wipe(self._items)
	wipe(self._emptySlotIds)
	wipe(self._slotIds)
	wipe(self._slotItemString)
	wipe(self._slotMoveQuantity)
	wipe(self._slotEndQuantity)
	self._pendingSlotId = nil
end

function MoveContext:PopulateEmptySlots()
	assert(not next(private.sortValueTemp))
	for _, container in self:_TargetContainerIterator() do
		if self._target == Util.FRAME.CONTAINER then
			local isSpecial = Container.GetBagItemFamily(container) ~= 0
			for slotId in Container.SlotIdIterator(container) do
				if not Container.GetItemLink(slotId) then
					tinsert(self._emptySlotIds, slotId)
					private.sortValueTemp[slotId] = slotId + (isSpecial and 0 or 100000)
				end
			end
		elseif self._target == Util.FRAME.GUILD_BANK then
			for slotId in Guild.SlotIdIterator(container) do
				if Guild.GetItemCount(slotId) == 0 then
					tinsert(self._emptySlotIds, slotId)
					private.sortValueTemp[slotId] = #self._emptySlotIds
				end
			end
		else
			error("Unknown target: "..tostring(self._target))
		end
	end
	Table.SortWithValueLookup(self._emptySlotIds, private.sortValueTemp)
	wipe(private.sortValueTemp)
end

---Calculates the moves to be performed and returns the total number of moves.
---@return number
function MoveContext:CalculateMoves()
	assert(not next(self._slotIds) and not next(self._slotEndQuantity))
	local numMoves = 0
	for itemString, numQueued in pairs(self._items) do
		local iter = self:_SlotIdIterator(itemString)
		for _, slotId, quantity in iter do
			assert(numQueued > 0)
			-- Find a suitable empty slot
			local targetSlotId = self:_GetTargetSlotId(itemString, slotId)
			if targetSlotId then
				assert(not self._slotIds[slotId])
				self._slotIds[slotId] = targetSlotId
				self._slotItemString[slotId] = itemString
				self._slotMoveQuantity[slotId] = min(quantity, numQueued)
				self._slotEndQuantity[slotId] = max(quantity - numQueued, 0)
				numQueued = numQueued - self._slotMoveQuantity[slotId]
				numMoves = numMoves + 1
			else
				Log.Err("No target slot")
			end
			if numQueued == 0 then
				iter:Release()
				break
			end
		end
		if numQueued > 0 then
			Log.Err("No slots with item (%s)", itemString)
		end
	end
	return numMoves
end

---Returns whether or not there is a pending slot to move.
---@return boolean
function MoveContext:HasPendingSlot()
	return next(self._slotIds) and true or false
end

---Perform the next set of pending moves.
function MoveContext:DoMoveThreaded()
	self._pendingSlotId = nil
	for sourceSlotId, targetSlotId in pairs(self._slotIds) do
		self:_MoveSlot(sourceSlotId, targetSlotId, self._slotMoveQuantity[sourceSlotId])
		Threading.Yield()
		if self._source == Util.FRAME.GUILD_BANK or self._target == Util.FRAME.GUILD_BANK then
			self._pendingSlotId = sourceSlotId
			return
		end
	end
end

---Checks the pending slots for any which are done and returns the first one if found.
---@return number? slotId
---@return string? itemString
---@return number? quantity
function MoveContext:CheckForDoneSlotsThreaded()
	if self._pendingSlotId then
		local slotId = self._pendingSlotId
		if self:_IsSourceSlotDone(slotId) then
			self._slotIds[slotId] = nil
			return slotId, self._slotItemString[slotId], self._slotMoveQuantity[slotId]
		end
	else
		for slotId in pairs(self._slotIds) do
			if self:_IsSourceSlotDone(slotId) then
				self._slotIds[slotId] = nil
				return slotId, self._slotItemString[slotId], self._slotMoveQuantity[slotId]
			end
			Threading.Yield()
		end
	end
	return nil, nil, nil
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MoveContext.__private:_TargetContainerIterator()
	wipe(private.containersTemp)
	if self._target == Util.FRAME.CONTAINER.BAG then
		for bag in Container.BagIterator() do
			tinsert(private.containersTemp, bag)
		end
	elseif self._target == Util.FRAME.CONTAINER.BANK then
		if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
			tinsert(private.containersTemp, Container.GetBankContainer())
		end
		for bag in Container.BankBagIterator() do
			tinsert(private.containersTemp, bag)
		end
	elseif self._target == Util.FRAME.CONTAINER.WARBANK then
		if Container.CanAccessWarbank() then
			for bag in Container.WarbankBagIterator() do
				tinsert(private.containersTemp, bag)
			end
		end
	elseif self._target == Util.FRAME.GUILD_BANK then
		local currentTab = Guild.GetCurrentTab()
		if self:_ShouldIncludeGuildBankTab(currentTab) then
			tinsert(private.containersTemp, currentTab)
		end
		for tab = 1, Guild.GetNumTabs() do
			if tab ~= currentTab and self:_ShouldIncludeGuildBankTab(tab) then
				tinsert(private.containersTemp, tab)
			end
		end
	else
		error("Unknown target: "..tostring(self._target))
	end
	return ipairs(private.containersTemp)
end

function MoveContext.__private:_ShouldIncludeGuildBankTab(tab)
	return Guild.CanWithdrawEntireTab(tab)
end

---@return IteratorObject<fun(): number, number, number> @Iterator with fields `index`, `slotId`, `quantity`
function MoveContext.__private:_SlotIdIterator(itemString)
	local query = nil
	if self._source == Util.FRAME.CONTAINER.BAG then
		query = BagTracking.CreateQueryBagsItem(itemString)
	elseif self._source == Util.FRAME.CONTAINER.BANK then
		query = BagTracking.CreateQueryBankItem(itemString)
	elseif self._source == Util.FRAME.CONTAINER.WARBANK then
		query = WarbankTracking.CreateQuerySlotItem(itemString)
	elseif self._source == Util.FRAME.GUILD_BANK then
		query = GuildService.NewIndexQueryItem(itemString)
	else
		error("Unknown source: "..tostring(self._source))
	end
	itemString = Group.TranslateItemString(itemString)
	return query
		:AutoRelease()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Iterator("slotId", "quantity")
end

function MoveContext.__private:_GetTargetSlotId(itemString, sourceSlotId)
	if self._target == Util.FRAME.CONTAINER then
		for i, slotId in ipairs(self._emptySlotIds) do
			local bag = SlotId.Split(slotId)
			if (not sourceSlotId or not Container.IsWarbankBag(bag) or Container.CanDepositIntoWarbank(sourceSlotId)) and BagTracking.ItemWillGoInBag(itemString, bag) then
				return tremove(self._emptySlotIds, i)
			end
		end
		return nil
	elseif self._target == Util.FRAME.GUILD_BANK then
		return tremove(self._emptySlotIds, 1)
	else
		error("Unknown target: "..tostring(self._target))
	end
end

function MoveContext.__private:_MoveSlot(fromSlotId, toSlotId, quantity)
	if self._source == Util.FRAME.CONTAINER then
		Container.SplitItem(fromSlotId, quantity)
	elseif self._source == Util.FRAME.GUILD_BANK then
		Guild.SplitItem(fromSlotId, quantity)
	else
		error("Unknown source: "..tostring(self._source))
	end
	if self._target == Util.FRAME.CONTAINER then
		Container.PlaceItemFromCursor(toSlotId)
	elseif self._target == Util.FRAME.GUILD_BANK then
		Guild.PlaceItemFromCursor(toSlotId)
	else
		error("Unknown target: "..tostring(self._target))
	end
end

function MoveContext.__private:_IsSourceSlotDone(slotId)
	assert(self._slotIds[slotId])
	local quantity = nil
	if self._source == Util.FRAME.CONTAINER then
		quantity = Container.GetStackCount(slotId) or 0
	elseif self._source == Util.FRAME.GUILD_BANK then
		local tab = SlotId.Split(slotId)
		Guild.QueryTab(tab)
		quantity = Guild.GetItemCount(slotId)
	else
		error("Unknown source: "..tostring(self._source))
	end
	return quantity <= self._slotEndQuantity[slotId]
end

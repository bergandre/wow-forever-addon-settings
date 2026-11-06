-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GroupItemDB = LibTSMTypes:DefineInternalClassType("GroupItemDB")
local GroupItemMap = LibTSMTypes:IncludeClassType("GroupItemMap")
local Path = LibTSMTypes:Include("Group.Path")
local Database = LibTSMTypes:From("LibTSMDatabase"):Include("Database")
local private = {}




-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new group item DB.
---@param name string The DB name
---@return GroupItemDB
function GroupItemDB.__static.New(name)
	return GroupItemDB(name)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function GroupItemDB.__private:__init(name)
	self._numItems = {}
	self._db = Database.NewSchema(name)
		:AddUniqueStringField("itemString")
		:AddStringField("groupPath")
		:AddSmartMapField("baseItemString", GroupItemMap.GetBaseItemMap(), "itemString")
		:AddIndex("groupPath")
		:AddIndex("baseItemString")
		:Commit()
	self._baseItemQuery = self._db:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupItemDB:Load(items)
	self._db:TruncateAndBulkInsertStart()
	for itemString, groupPath in pairs(items) do
		self._db:BulkInsertNewRow(itemString, groupPath)
		self:_IncrementNumItems(groupPath, 1)
	end
	self._db:BulkInsertEnd()
end

---Returns the underlying DB table for joining.
---@return DatabaseTable
function GroupItemDB:GetForJoin()
	return self._db
end

---Creates a query.
---@param groupPathFilter? GroupPathValue The group path to filter on
---@param includeSubGroups? boolean Whether or not to include subgroups
---@return DatabaseQuery
function GroupItemDB:CreateQuery(groupPathFilter, includeSubGroups)
	assert(groupPathFilter == nil or not Path.IsRoot(groupPathFilter))
	if not groupPathFilter then
		assert(not includeSubGroups)
		return self._db:NewOwnedQuery()
	elseif includeSubGroups then
		return self._db:NewOwnedQuery()
			:StartsWith("groupPath", groupPathFilter)
			:Function("groupPath", private.ItemInGroupQueryFilter, groupPathFilter)
	else
		return self._db:NewOwnedQuery()
			:Equal("groupPath", groupPathFilter)
	end
end

---Iterates over items in a group.
---@param groupPathFilter GroupPathValue The group path to filter on
---@param includeSubGroups? boolean Whether or not to include subgroups
---@return IteratorObject<fun(): number, string, string> @Iterator with fields: `index`, `itemString`, `groupPath`
function GroupItemDB:Iterator(groupPathFilter, includeSubGroups)
	if groupPathFilter then
		return self:CreateQuery(groupPathFilter, includeSubGroups)
			:AutoRelease()
			:Iterator("itemString", "groupPath")
	else
		return self._db:NewAutoReleaseQuery()
			:Iterator("itemString", "groupPath")
	end
end

---Iterates over items in a group by their base item string.
---@param baseItemString any
---@return IteratorObject<fun(): number, string, string> @Iterator with fields: `index`, `itemString`, `groupPath`
function GroupItemDB:IteratorByBaseItem(baseItemString)
	return self._baseItemQuery:BindParams(baseItemString):Iterator("itemString", "groupPath")
end

---Gets the number of items in a group.
---@param groupPath GroupPathValue The group path
---@return number
function GroupItemDB:GetNumItems(groupPath)
	return self._numItems[groupPath] or 0
end

---Returns an iterator which executes to completion with group item DB query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function GroupItemDB:WithQueryUpdatesPaused(func, obj, key)
	return self._db:WithQueryUpdatesPaused(func, obj, key)
end

---Returns whether or not an item is in a group.
---@param itemString string The item string
---@return boolean
function GroupItemDB:HasItem(itemString)
	return self._db:HasUniqueRow("itemString", itemString)
end

---Gets the group path for an item.
---@param itemString string The item string
---@return GroupPathValue
function GroupItemDB:GetGroup(itemString)
	if not self._db:HasUniqueRow("itemString", itemString) then
		return Path.GetRoot()
	end
	return self._db:GetRowFields(self._db:GetUniqueRow("itemString", itemString), "groupPath")
end

---Sets the group an item is in.
---@param itemString string The item string
---@param groupPath? GroupPathValue The group path to put the item in, or nil to remove it from its group
function GroupItemDB:SetGroup(itemString, groupPath)
	local uuid = self._db:HasUniqueRow("itemString", itemString) and self._db:GetUniqueRow("itemString", itemString) or nil
	if uuid then
		self:_DecrementNumItems(self._db:GetRowFields(uuid, "groupPath"), 1)
	end
	if groupPath then
		self:_IncrementNumItems(groupPath, 1)
	end
	if uuid and groupPath then
		-- Move the item
		self._db:UpdateRow(uuid, "groupPath", groupPath)
	elseif uuid then
		-- Remove the item
		self._db:DeleteRow(uuid)
	elseif groupPath then
		-- Add the item
		self._db:InsertRow(itemString, groupPath)
	end
end

---Moves items from one group to another.
---@param oldPath GroupPathValue The old group path
---@param newPath GroupPathValue The new group path
---@param itemsMoved string[] A table to store the list of items moved
function GroupItemDB:Move(oldPath, newPath, itemsMoved)
	for _ in self:WithQueryUpdatesPaused() do
		local query = self._db:NewAutoReleaseQuery()
			:AutoPauseDBQueryUpdates()
			:Equal("groupPath", oldPath)
		for uuid, itemString in query:Iterator("itemString") do
			tinsert(itemsMoved, itemString)
			self._db:UpdateRow(uuid, "groupPath", newPath)
		end
		self:_DecrementNumItems(oldPath, #itemsMoved)
		self:_IncrementNumItems(newPath, #itemsMoved)
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function GroupItemDB.__private:_IncrementNumItems(groupPath, amount)
	if amount == 0 then
		return
	end
	self._numItems[groupPath] = (self._numItems[groupPath] or 0) + amount
end

function GroupItemDB.__private:_DecrementNumItems(groupPath, amount)
	if amount == 0 then
		return
	end
	local numItems = self._numItems[groupPath] - amount
	assert(numItems >= 0)
	self._numItems[groupPath] = numItems > 0 and numItems or nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemInGroupQueryFilter(groupPath, groupPathFilter)
	return groupPath == groupPathFilter or Path.IsChild(groupPath, groupPathFilter)
end

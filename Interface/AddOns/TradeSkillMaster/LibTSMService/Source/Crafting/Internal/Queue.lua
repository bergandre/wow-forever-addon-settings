-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Queue = LibTSMService:InitInternal("Crafting.Queue")
local Cost = LibTSMService:Include("Crafting.Cost")
local Procs = LibTSMService:Include("Crafting.Procs")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local Spell = LibTSMService:From("LibTSMWoW"):Include("API.Spell")
local private = {
	db = nil,
	craftSettingsTable = nil,
	queueSettingsTable = nil,
}
local MAX_NUM_QUEUED = 9999



-- ============================================================================
-- Module Loading
-- ============================================================================

Queue:OnModuleLoad(function()
	private.db = Database.NewSchema("CRAFTING_QUEUE")
		:AddUniqueStringField("recipeString")
		:AddStringField("craftString")
		:AddNumberField("num")
		:Commit()
end)


-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the queue settings tables.
---@param crafts table<string,CraftInfo> The craft info settings table
---@param queue table<string,number> The queue settings table
function Queue.Load(crafts, queue)
	private.craftSettingsTable = crafts
	private.queueSettingsTable = queue
	private.LoadData()
end

---Creates a query against the queue DB.
---@return DatabaseQuery
function Queue.CreateQuery()
	return private.db:NewOwnedQuery()
end

---Gets the queue DB for joining.
---@return DatabaseTable
function Queue.GetDBForJoin()
	return private.db
end

---Sets the number queued.
---@param recipeString string The recipe string
---@param num number The number to set.
function Queue.SetNum(recipeString, num)
	assert(type(recipeString) == "string")
	assert(strfind(recipeString, "^r:%d+"))
	local numQueued = Math.Bound(Math.Round(num), 0, MAX_NUM_QUEUED)
	private.queueSettingsTable[recipeString] = numQueued > 0 and numQueued or nil
	if private.db:HasUniqueRow("recipeString", recipeString) then
		local uuid = private.db:GetUniqueRow("recipeString", recipeString)
		if numQueued == 0 then
			-- Delete this row
			private.db:DeleteRow(uuid)
		else
			-- Update this row
			private.db:UpdateRow(uuid, "num", numQueued)
		end
	elseif numQueued > 0 then
		local craftString = CraftString.FromRecipeString(recipeString)
		-- Insert a new row
		private.db:InsertRow(recipeString, craftString, numQueued)
	end
end

---Gets the number queued.
---@param recipeString string The recipe string
---@return number
function Queue.GetNum(recipeString)
	if not private.db:HasUniqueRow("recipeString", recipeString) then
		return 0
	end
	return private.db:GetRowFields(private.db:GetUniqueRow("recipeString", recipeString), "num")
end

---Clears the queue.
function Queue.Clear()
	wipe(private.queueSettingsTable)
	private.db:Truncate()
end

---Gets the queue totals.
---@return number? totalCost
---@return number? totalProfit
---@return number? totalCastTime
function Queue.GetTotals()
	local totalCost, totalProfit, totalCastTimeMs = nil, nil, nil
	local query = private.db:NewAutoReleaseQuery()
	for _, recipeString, craftString, numQueued in query:Iterator("recipeString", "craftString", "num") do
		local craftInfo = private.craftSettingsTable[craftString]
		local _, expectedExtraYield = Procs.GetExpectedRates(craftString)
		local numResult = (craftInfo and craftInfo.numResult or 0) * (1 + expectedExtraYield)
		local cost, _, profit = Cost.GetCostsByRecipeString(recipeString)
		if cost then
			totalCost = (totalCost or 0) + cost * numQueued * numResult
		end
		if profit then
			totalProfit = (totalProfit or 0) + profit * numQueued * numResult
		end
		local spellId = CraftString.GetSpellId(craftString)
		local _, _, castTime = Spell.GetInfo(spellId)
		if castTime then
			totalCastTimeMs = (totalCastTimeMs or 0) + castTime * numQueued
		end
	end
	return totalCost, totalProfit, totalCastTimeMs and ceil(totalCastTimeMs / 1000) or nil
end

---Returns an iterator which executes to completion with queue DB query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function Queue.WithQueryUpdatesPaused(func, obj, key)
	return private.db:WithQueryUpdatesPaused(func, obj, key)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData()
	-- Copy to a temp table first since we might otherwise be modifying the settings table as we iterate
	local queuedRecipes = {}
	for recipeString, numQueued in pairs(private.queueSettingsTable) do
		queuedRecipes[recipeString] = numQueued
	end
	for recipeString, numQueued in private.db:WithQueryUpdatesPaused(pairs(queuedRecipes)) do
		Queue.SetNum(recipeString, numQueued)
	end
end

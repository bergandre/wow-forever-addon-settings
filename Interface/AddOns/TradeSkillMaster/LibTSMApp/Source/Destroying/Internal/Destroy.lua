-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Destroy = LibTSMApp:InitInternal("Destroying.Destroy")
local BagDB = LibTSMApp:Include("Destroying.BagDB")
local History = LibTSMApp:Include("Destroying.History")
local Future = LibTSMApp:From("LibTSMUtil"):IncludeClassType("Future")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local Container = LibTSMApp:From("LibTSMWoW"):Include("API.Container")
local Loot = LibTSMApp:From("LibTSMWoW"):Include("API.Loot")
local Spell = LibTSMApp:From("LibTSMWoW"):Include("API.Spell")
local TradeSkill = LibTSMApp:From("LibTSMWoW"):Include("API.TradeSkill")
local Event = LibTSMApp:From("LibTSMWoW"):Include("Service.Event")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local private = {
	destroyThread = nil,
	destroyThreadRunning = false,
	pendingSpellId = nil,
	destroySpellId = nil,
	destroyItemId = nil,
	destroyResultCache = {},
	destroyFuture = Future.New("DESTROYING_DESTROY_FUTURE"), ---@type Future<boolean>
}
local GEM_CHIPS = {
	["i:129099"] = "i:129100",
	["i:130200"] = "i:129100",
	["i:130201"] = "i:129100",
	["i:130202"] = "i:129100",
	["i:130203"] = "i:129100",
	["i:130204"] = "i:129100",
}
local START_MESSAGE = newproxy(false)

---@alias DestroyingPrepareButtonFunc fun(spellId: number, slotId: number)



-- ============================================================================
-- Module Loading
-- ============================================================================

Destroy:OnModuleLoad(function()
	-- Create the threads
	private.destroyThread = Threading.New("DESTROY", private.DestroyThread)
	Threading.SetCallback(private.destroyThread, private.DestroyThreadDone)

	-- Register event handlers / callbacks / hooks
	Event.Register("LOOT_READY", private.SendEventToThread)
	Event.Register("LOOT_CLOSED", private.SendEventToThread)
	BagTracking.RegisterCallback(function()
		private.SendEventToThread("BAG_UPDATE_DELAYED")
	end)
	Event.Register("UNIT_SPELLCAST_START", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED_QUIET", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_INTERRUPTED", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_SUCCEEDED", private.SpellCastEventHandler)
	if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
		TradeSkill.SecureHookCraftSalvage(function(spellId, slotId)
			private.destroySpellId = spellId
			private.destroyItemId = Container.GetItemId(slotId)
		end)
		Event.Register("TRADE_SKILL_ITEM_CRAFTED_RESULT", private.TradeSkillCraftResultHandler)
		Event.Register("TRADE_SKILL_LIST_UPDATE", private.TradeSkillListUpdateHandler)
	end

	-- Set up futures
	private.destroyFuture:SetScript("OnCleanup", function()
		private.destroyThreadRunning = false
		Threading.Kill(private.destroyThread)
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts destroying an item at a slot.
---@param prepareFunc DestroyingPrepareButtonFunc The function to call to prepare for destroying
---@param itemString string The item string to destroy
---@param slotId number The slot ID to destroy
---@return Future
function Destroy.Start(prepareFunc, itemString, slotId)
	private.destroyFuture:Start()
	private.destroyThreadRunning = true
	Threading.Start(private.destroyThread, prepareFunc, itemString, slotId)
	-- We need the thread to run now so send it a sync message
	Threading.SendSyncMessage(private.destroyThread, START_MESSAGE)
	return private.destroyFuture
end



-- ============================================================================
-- Destroy Thread
-- ============================================================================

---@param prepareFunc DestroyingPrepareButtonFunc
function private.DestroyThread(prepareFunc, itemString, slotId)
	-- We get sent a sync message so we run right away
	assert(Threading.ReceiveMessage() == START_MESSAGE)

	local spellId = BagDB.GetSpellId(itemString)
	local startQuantity = Container.GetStackCount(slotId)
	prepareFunc(spellId, slotId)

	-- Wait for the spell cast to start or fail
	private.pendingSpellId = spellId
	local event = Threading.ReceiveMessage()
	if event ~= "UNIT_SPELLCAST_START" then
		-- The spell cast failed for some reason
		Spell.ClearCursor()
		return false
	end

	-- Discard any other messages
	Threading.Yield(true)
	while Threading.HasPendingMessage() do
		Threading.ReceiveMessage()
	end

	-- Wait for the spell cast to finish and the loot window to open and then close
	local lootResult = nil
	local hasSpellcastSucceeded, hasLootClosed, hasBagUpdateDelayed = false, false, false
	while not hasSpellcastSucceeded or not lootResult or not hasLootClosed or not hasBagUpdateDelayed do
		event = Threading.ReceiveMessage()
		Log.Info("Got event: %s", tostring(event))
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			hasSpellcastSucceeded = true
		elseif event == "LOOT_READY" then
			if not lootResult and Loot.GetNumItems() > 0 then
				lootResult = {}
				for i = 1, Loot.GetNumItems() do
					local link, quantity = Loot.GetInfo(i)
					local lootItemString = link and ItemString.Get(link) or nil
					if lootItemString and (quantity or 0) > 0 then
						lootItemString = GEM_CHIPS[lootItemString] or lootItemString
						lootResult[lootItemString] = quantity
					end
				end
			end
		elseif event == "LOOT_CLOSED" then
			if lootResult then
				hasLootClosed = true
			end
		elseif event == "BAG_UPDATE_DELAYED" then
			if lootResult then
				hasBagUpdateDelayed = true
			end
		else
			-- The spell cast was interrupted
			return false
		end
	end

	-- Add to the history log
	History.Add(itemString, spellId, lootResult)

	-- Wait up to a second for the item we destroyed to be removed from the bags
	local timeout = LibTSMApp.GetTime() + 1
	while startQuantity == Container.GetStackCount(slotId) do
		if LibTSMApp.GetTime() > timeout then
			return false
		end
		Threading.Sleep(0.1)
	end

	-- We're done
	return true
end

function private.SendEventToThread(event)
	if not private.destroyThreadRunning then
		return
	end
	Threading.SendMessage(private.destroyThread, event)
end

function private.DestroyThreadDone(result)
	private.destroyThreadRunning = false
	private.destroyFuture:Done(result)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SpellCastEventHandler(event, unit, _, spellId)
	if unit ~= "player" then
		return
	end
	if (LibTSMApp.IsRetail() or LibTSMApp.IsForever()) and private.destroySpellId and private.destroySpellId == spellId and event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then
		private.destroySpellId = nil
		private.destroyItemId = nil
	end
	if spellId ~= private.pendingSpellId then
		return
	end
	private.SendEventToThread(event)
end

function private.TradeSkillCraftResultHandler(_, resultTable)
	if not private.destroySpellId or not private.destroyItemId then
		return
	end
	local itemString = ItemString.Get(resultTable.itemID)
	assert(itemString)
	private.destroyResultCache[itemString] = resultTable.quantity
end

function private.TradeSkillListUpdateHandler()
	if not private.destroySpellId or not private.destroyItemId or not next(private.destroyResultCache) then
		return
	end
	local itemString = ItemString.Get(private.destroyItemId)
	if not itemString then
		wipe(private.destroyResultCache)
		return
	end
	History.Add(itemString, private.destroySpellId, CopyTable(private.destroyResultCache))
	wipe(private.destroyResultCache)
end

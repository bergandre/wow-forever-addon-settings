-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Task = LibTSMApp:From("LibTSMTypes"):IncludeClassType("Task")
local CraftingTask = LibTSMApp:DefineInternalClassType("CraftingTask", Task)
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local CraftString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.CraftString")
local RecipeString = LibTSMApp:From("LibTSMTypes"):Include("Crafting.RecipeString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local TradeSkill = LibTSMApp:From("LibTSMWoW"):Include("API.TradeSkill")
local ChatEvent = LibTSMApp:From("LibTSMWoW"):Include("Service.ChatEvent")
local Event = LibTSMApp:From("LibTSMWoW"):Include("Service.Event")
local GlobalStrings = LibTSMApp:From("LibTSMWoW"):Include("Util.GlobalStrings")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local Profession = LibTSMApp:From("LibTSMService"):Include("Profession")
local private = {
	currentlyCrafting = nil,
	pendingSpellId = nil,
	pendingItemString = nil,
	activeTasks = {}, ---@type table<CraftingTask,true>
	numCraftableTemp = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

function CraftingTask.__static.Configure()
	Profession.RegisterStateCallback(private.UpdateTasks)
	Profession.RegisterHasScannedCallback(private.UpdateTasks)
	BagTracking.RegisterQuantityCallback(private.UpdateTasksForBagQuantityChange)

	ChatEvent.RegisterLootHandler(private.LootHandler)
	Event.Register("UNIT_SPELLCAST_INTERRUPTED", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED_QUIET", private.SpellCastEventHandler)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function CraftingTask:__init()
	self.__super:__init()
	self._profession = nil ---@type string!
	self._skillId = nil
	self._craftStrings = {}
	self._craftQuantity = {}
	self._mats = {}
end

function CraftingTask:Acquire(doneHandler, category, profession)
	self.__super:Acquire(doneHandler, category, format(L["%s Crafts"], profession))
	self._profession = profession
	for _, _, prof, skillId in Profession.PlayerProfessionsIterator() do
		if prof == profession and (not self._skillId or (self._skillId == -1 and skillId ~= -1)) then
			self._skillId = skillId
		end
	end
	private.activeTasks[self] = true
end

function CraftingTask:Release()
	self.__super:Release()
	self._profession = nil
	self._skillId = nil
	wipe(self._craftStrings)
	wipe(self._craftQuantity)
	wipe(self._mats)
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftingTask:WipeCraftStrings()
	wipe(self._craftStrings)
	wipe(self._craftQuantity)
	wipe(self._mats)
end

function CraftingTask:HasCraftStrings()
	return #self._craftStrings > 0
end

function CraftingTask:HasMat(itemString)
	return self._mats[itemString] and true or false
end

function CraftingTask:GetProfession()
	return self._profession
end

function CraftingTask:HasCraftString(craftString)
	return self._craftQuantity[craftString] and true or false
end

function CraftingTask:AddCraftString(craftString, quantity)
	tinsert(self._craftStrings, craftString)
	self._craftQuantity[craftString] = quantity
	for _, itemString in Crafting.MatIterator(craftString) do
		self._mats[itemString] = (self._mats[itemString] or 0) + 1
	end
end

function CraftingTask:IsSecureSpell()
	return LibTSMApp.IsForever() and self._buttonText == L["OPEN"]
end

function CraftingTask:GetSecureSpell()
	return TradeSkill.GetOpenUISpellName(self._profession)
end

function CraftingTask:OnMouseDown()
	if self._buttonText == L["CRAFT"] then
		local craftString = self._craftStrings[1]
		local quantity = self._craftQuantity[craftString]
		Log.Info("Preparing %s (%d)", craftString, quantity)
		Crafting.PrepareCraft(RecipeString.FromCraftString(craftString), quantity)
	end
end

function CraftingTask:OnButtonClick()
	if self._buttonText == L["CRAFT"] then
		local craftString = self._craftStrings[1]
		local spellId = CraftString.GetSpellId(craftString)
		local quantity = self._craftQuantity[craftString]
		local _, numMax = Profession.GetCraftedQuantityRange(craftString)
		if numMax > 1 then
			-- need minimum this many repeats
			quantity = ceil(quantity / numMax)
		end
		Log.Info("Crafting %s (%d)", craftString, quantity)
		private.currentlyCrafting = self
		private.pendingSpellId = spellId
		private.pendingItemString = Crafting.GetItemString(craftString)
		local numCrafted = Crafting.ExecuteCraft(RecipeString.FromCraftString(craftString), quantity, true, nil, self:__closure("_CraftCompleteCallback"))
		if numCrafted == 0 then
			-- we're probably crafting something else already - so just bail
			Log.Err("Failed to craft")
			private.currentlyCrafting = nil
		end
	elseif self._buttonText == L["OPEN"] then
		TradeSkill.OpenUI(LibTSMApp.IsRetail() and self._skillId or self._profession)
	else
		error("Invalid state: "..tostring(self._buttonText))
	end
	self:Update()
end

function CraftingTask:HasSubTasks()
	assert(self:HasCraftStrings())
	return true
end

function CraftingTask:SubTaskIterator()
	assert(self:HasCraftStrings())
	self:_SortCraftStrings()
	return private.SubTaskIterator, self, 0
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftingTask:_UpdateState()
	self:_SortCraftStrings()
	if Crafting.GetNumCraftableFromDB(self._craftStrings[1]) == 0 then
		-- don't have the mats to craft this
		return self:_SetButtonState(false, L["NEED MATS"])
	elseif self._profession ~= Profession.GetCurrentProfession() then
		-- the profession isn't opened
		return self:_SetButtonState(true, L["OPEN"])
	elseif not Profession.HasScanned() then
		-- the profession is opened, but we haven't yet fully scanned it
		return self:_SetButtonState(false, strupper(GlobalStrings.Get("OPENING")))
	elseif private.currentlyCrafting == self then
		return self:_SetButtonState(false, L["CRAFTING"])
	elseif private.currentlyCrafting then
		return self:_SetButtonState(false, L["BUSY"])
	else
		-- ready to craft
		return self:_SetButtonState(true, L["CRAFT"])
	end
end

function CraftingTask:_RemoveCraftString(craftString)
	assert(Table.RemoveByValue(self._craftStrings, craftString) == 1)
	self._craftQuantity[craftString] = nil
	for _, itemString in Crafting.MatIterator(craftString) do
		self._mats[itemString] = self._mats[itemString] - 1
		if self._mats[itemString] == 0 then
			self._mats[itemString] = nil
		end
	end
end

function CraftingTask:_SortCraftStrings()
	assert(not next(private.numCraftableTemp))
	for _, craftString in ipairs(self._craftStrings) do
		private.numCraftableTemp[craftString] = Crafting.GetNumCraftableFromDB(craftString)
	end
	Table.SortWithValueLookup(self._craftStrings, private.numCraftableTemp, true)
	wipe(private.numCraftableTemp)
end

function CraftingTask.__private:_CraftCompleteCallback(success, isDone)
	local craftString = self._craftStrings[1]
	if isDone then
		private.currentlyCrafting = nil
		private.ClearPendingContext()
		if success then
			self:_RemoveCraftString(craftString)
			if not self:HasCraftStrings() then
				self:_doneHandler()
			end
		end
	end
	if self:HasCraftStrings() then
		self:Update()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LootHandler(itemLink, quantity)
	if not private.pendingSpellId or not private.pendingItemString then
		return
	end
	if not itemLink or ItemString.GetBase(itemLink) ~= ItemString.GetBaseFast(private.pendingItemString) then
		Log.Info("Unknown item link (%s, %s)", tostring(itemLink), private.pendingItemString)
		return
	end
	local self = private.currentlyCrafting
	assert(self)
	---@diagnostic disable: invisible
	local craftString = self._craftStrings[1]
	self._craftQuantity[craftString] = self._craftQuantity[craftString] - quantity
	Log.Info("Crafted %s (%d), remaining: %d", private.pendingItemString, quantity, self._craftQuantity[craftString])
	if self._craftQuantity[craftString] <= 0 then
		private.ClearPendingContext()
	end
	---@diagnostic enable: invisible
end

function private.SpellCastEventHandler(_, unit, _, spellId)
	if unit ~= "player" or spellId ~= private.pendingSpellId then
		return
	end
	private.ClearPendingContext()
end

function private.ClearPendingContext()
	private.pendingSpellId = nil
	private.pendingItemString = nil
end

function private.SubTaskIterator(self, index)
	index = index + 1
	local craftString = self._craftStrings[index]
	if not craftString then
		return
	end
	return index, Crafting.GetName(craftString).." ("..self._craftQuantity[craftString]..")"
end

function private.UpdateTasks()
	for task in pairs(private.activeTasks) do
		if task:HasCraftStrings() then
			task:Update()
		end
	end
end

function private.UpdateTasksForBagQuantityChange(updatedItems)
	for task in pairs(private.activeTasks) do
		if task:HasCraftStrings() then
			for itemString in pairs(updatedItems) do
				if task:HasMat(itemString) then
					task:Update()
					break
				end
			end
		end
	end
end

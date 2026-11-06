-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Craft = LibTSMService:InitInternal("Crafting.Craft")
local CraftInfoDB = LibTSMService:Include("Crafting.CraftInfoDB")
local CraftInfoDBUtil = LibTSMService:Include("Crafting.CraftInfoDBUtil")
local BagTracking = LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = LibTSMService:Include("Inventory.WarbankTracking")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Profession = LibTSMService:Include("Profession")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local CraftString = LibTSMService:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = LibTSMService:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local RecipeString = LibTSMService:From("LibTSMTypes"):Include("Crafting.RecipeString")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Spell = LibTSMService:From("LibTSMWoW"):Include("API.Spell")
local Item = LibTSMService:From("LibTSMWoW"):Include("API.Item")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {
	recipeString = nil,
	craftQuantity = nil,
	craftSpellId = nil,
	craftBaseString = nil,
	craftCallback = nil,
	craftName = nil,
	castingTimeout = nil,
	craftTimeout = nil,
	preparedSpellId = nil,
	preparedFrame = 0,
	timeoutTimer = nil,
	optionsMatsTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Craft:OnModuleLoad(function()
	private.timeoutTimer = DelayTimer.New("PROFESSION_UTIL_TIMEOUT", private.CraftTimeoutMonitor)
	Event.Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellId)
		if unit ~= "player" or not private.SpellMatchesCraft(spellId) then
			return
		end

		if LibTSMService.IsRetail() or LibTSMService.IsForever() then
			-- Check if we need to update bank quantity manually
			assert(private.recipeString)
			for _, itemString, quantity in CraftInfoDBUtil.MatIteratorByRecipeString(private.recipeString) do
				local bagQuantity, bankQuantity = BagTracking.GetQuantities(itemString)
				local warbankQuantity = WarbankTracking.GetQuantity(itemString)
				local bankUsed = quantity - bagQuantity
				if bankUsed > 0 and bankUsed <= (bankQuantity + warbankQuantity) then
					local warbankUsed = min(bankUsed, warbankQuantity)
					bankUsed = bankUsed - warbankUsed
					Log.Info("Used %d from bank, %d from the warbank", bankUsed, warbankUsed)
					if bankUsed > 0 then
						BagTracking.ForceBankQuantityDeduction(itemString, bankUsed)
					end
					if warbankUsed > 0 then
						WarbankTracking.ForceQuantityDeduction(itemString, warbankUsed)
					end
				end
			end
		end

		assert(private.craftQuantity)
		private.craftQuantity = private.craftQuantity - 1
		private.DoCraftCallback(true, private.craftQuantity == 0)
		-- Ignore profession updates from crafting something
		Profession.IgnoreNextProfessionUpdates()
		-- Restart the timeout
	end)
	local function SpellCastFailedEventHandler(_, unit, _, spellId)
		if unit ~= "player" or not private.SpellMatchesCraft(spellId) then
			return
		end
		private.DoCraftCallback(false, true)
	end
	local function ClearCraftCast()
		private.recipeString = nil
		private.craftQuantity = nil
		private.craftSpellId = nil
		private.craftBaseString = nil
		private.craftName = nil
		private.castingTimeout = nil
		private.craftTimeout = nil
	end
	Event.Register("UNIT_SPELLCAST_INTERRUPTED", SpellCastFailedEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED", SpellCastFailedEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED_QUIET", SpellCastFailedEventHandler)
	Event.Register("TRADE_SKILL_CLOSE", ClearCraftCast)
	if not LibTSMService.IsRetail() and not LibTSMService.IsForever() then
		Event.Register("CRAFT_CLOSE", ClearCraftCast)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Prepares to start a craft.
---@param recipeString string The recipe string
---@param quantity number The desired quantity to craft
---@param salvageSlotId? number The target slot ID to salvage
function Craft.Prepare(recipeString, quantity, salvageSlotId)
	if not salvageSlotId then
		quantity = min(quantity, CraftInfoDBUtil.GetNumCraftableRecipeString(recipeString))
	end
	if quantity == 0 then
		return
	end
	private.preparedSpellId = RecipeString.GetSpellId(recipeString)
	private.preparedFrame = ClientInfo.GetFrameNumber()
end

---Executes the specified craft and returns the quantity being crafted.
---@param recipeString string The recipe string
---@param quantity number The desired quantity to craft
---@param useVellum boolean Whether or not to use a vellum
---@param salvageSlotId? number The target slot ID to salvage
---@param callback fun(result: boolean, isDone: boolean) The callback for the craft
---@return number
function Craft.Execute(recipeString, quantity, useVellum, salvageSlotId, callback)
	local level = nil
	local craftString = CraftString.FromRecipeString(recipeString)
	local spellId = RecipeString.GetSpellId(recipeString)
	if not salvageSlotId then
		level = RecipeString.GetLevel(recipeString)
		quantity = min(quantity, CraftInfoDBUtil.GetNumCraftableRecipeString(recipeString))
	end
	assert(Profession.HasCraftString(craftString))
	if private.craftSpellId then
		private.craftCallback = callback
		private.DoCraftCallback(false, true)
		return 0
	end
	if quantity == 0 then
		return 0
	end
	local isEnchant = Profession.IsEnchant(craftString)
	local vellumable = isEnchant and (not LibTSMService.IsVanillaClassic() and not LibTSMService.IsBCClassic())
	if (not LibTSMService.IsRetail() and not LibTSMService.IsForever()) and (isEnchant or TradeSkill.IsClassicCrafting()) then
		quantity = 1
	elseif spellId ~= private.preparedSpellId or private.preparedFrame == ClientInfo.GetFrameNumber() then
		-- We can only craft one of this item due to a bug on Blizzard's end
		quantity = 1
	end
	local enchantItemSlotId = nil
	if (LibTSMService.IsRetail() or LibTSMService.IsForever()) and useVellum and isEnchant and vellumable then
		enchantItemSlotId = BagTracking.CreateQueryBagsItem(Profession.GetVellumItemString(craftString))
			:AutoRelease()
			:GetFirstResult("slotId")
		if not enchantItemSlotId then
			return 0
		end
	end
	private.recipeString = recipeString
	private.craftQuantity = quantity
	private.craftSpellId = spellId
	local craftItemString = CraftInfoDB.GetItemString(craftString) --[[@as string?]]
	private.craftBaseString = craftItemString and ItemString.GetBaseFast(craftItemString) or ""
	private.craftCallback = callback
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		assert(not next(private.optionsMatsTemp))
		local applyConcentration = RecipeString.GetConcentration(recipeString) and true or false
		for _, slotId, matQuantityString in RecipeString.OptionalMatIterator(recipeString) do
			for _, itemString, matQuantity in MatQuantityString.Iterator(matQuantityString) do
				local info = TempTable.Acquire()
				info.reagent = info.reagent or {}
				info.reagent.itemID = ItemString.ToId(itemString)
				info.dataSlotIndex = slotId
				info.quantity = matQuantity
				tinsert(private.optionsMatsTemp, info)
			end
		end
		TradeSkill.Craft(spellId, quantity, private.optionsMatsTemp, level, enchantItemSlotId, salvageSlotId, applyConcentration)
		for _, info in pairs(private.optionsMatsTemp) do
			TempTable.Release(info)
		end
		wipe(private.optionsMatsTemp)
	else
		local index = Profession.GetIndexByCraftString(craftString)
		if not index then
			return 0
		end
		private.craftName = TradeSkill.GetClassicCraftName(index)
		TradeSkill.Craft(index, quantity)
		if useVellum and isEnchant and vellumable then
			local vellumName = ItemInfo.GetName(Profession.GetVellumItemString(craftString))
			if vellumName then
				Item.UseByName(vellumName)
			end
		end
	end
	private.castingTimeout = nil
	private.craftTimeout = nil
	private.timeoutTimer:RunForTime(0.5)
	return quantity
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DoCraftCallback(result, isDone)
	local callback = private.craftCallback
	assert(callback)
	-- reset timeouts
	private.castingTimeout = nil
	private.craftTimeout = nil
	if isDone then
		private.recipeString = nil
		private.craftQuantity = nil
		private.craftSpellId = nil
		private.craftBaseString = nil
		private.craftCallback = nil
		private.craftName = nil
		private.timeoutTimer:Cancel()
	end
	callback(result, isDone)
end

function private.CraftTimeoutMonitor()
	private.timeoutTimer:RunForTime(0.5)
	if not private.craftSpellId then
		Log.Info("No longer crafting")
		private.castingTimeout = nil
		private.craftTimeout = nil
		private.timeoutTimer:Cancel()
		return
	end
	local spellId, castDuration = Spell.GetPlayerCastingInfo()
	if spellId then
		private.castingTimeout = nil
	else
		private.craftTimeout = nil
	end
	if not spellId then
		-- no active cast
		if Spell.IsTargeting() then
			private.castingTimeout = nil
			return
		end
		if LibTSMService.GetTime() > (private.castingTimeout or math.huge) then
			Log.Err("Craft timed out (%s)", private.craftSpellId)
			private.DoCraftCallback(false, true)
			return
		end
		-- set the casting timeout to 1 second from now
		private.castingTimeout = private.castingTimeout or (LibTSMService.GetTime() + 1)
		return
	elseif not private.IsCastingCraft(spellId) then
		Log.Err("Crafting something else (%s, %s)", private.craftSpellId, spellId)
		private.castingTimeout = nil
		private.craftTimeout = nil
		private.timeoutTimer:Cancel()
		return
	end

	if LibTSMService.GetTime() > (private.craftTimeout or math.huge) then
		Log.Err("Craft timed out (%s)", private.craftSpellId)
		private.DoCraftCallback(false, true)
		return
	end
	-- Set the timeout to 1 second after the end time
	private.craftTimeout = LibTSMService.GetTime() + castDuration + 1
end

function private.IsCastingCraft(spellId)
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		return spellId == private.craftSpellId
	else
		return Spell.GetInfo(spellId) == private.craftName
	end
end

function private.SpellMatchesCraft(spellId)
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		if not Profession.ScannerHasSkills() then
			return false
		end
		local resultItem = Profession.GetResultItem(CraftString.Get(spellId))
		if not resultItem then
			return false
		elseif type(resultItem) == "table" then
			for i = 1, #resultItem do
				local baseItemString = ItemString.GetBase(resultItem[i]) or ""
				if spellId == private.craftSpellId and baseItemString == private.craftBaseString then
					return true
				end
			end
			return false
		else
			local baseItemString = ItemString.GetBase(resultItem) or ""
			return spellId == private.craftSpellId and baseItemString == private.craftBaseString
		end
	else
		return Spell.GetInfo(spellId) == private.craftName
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local BagDB = LibTSMApp:InitInternal("Destroying.BagDB")
local Ignore = LibTSMApp:Include("Destroying.Ignore")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Signal = LibTSMApp:From("LibTSMUtil"):IncludeClassType("Signal")
local Reactive = LibTSMApp:From("LibTSMReactive"):Include("Reactive")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Conversion = LibTSMApp:From("LibTSMTypes"):Include("Item.Conversion")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local Item = LibTSMApp:From("LibTSMWoW"):Include("API.Item")
local Spell = LibTSMApp:From("LibTSMWoW"):Include("API.Spell")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local Conversions = LibTSMApp:From("LibTSMService"):Include("Item.Conversions")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = LibTSMApp:From("LibTSMService"):Include("Profession")
local private = {
	db = nil,
	state = nil,
	settings = nil,
	canDestroyCache = {},
	destroyQuantityCache = {},
	pendingCombines = {},
	bagUpdateSignal = Signal.New("DESTROYING_BAG_UPDATE"),
	disenchantSkillLevel = nil,
	jewelcraftSkillLevel = nil,
	inscriptionSkillLevel = nil,
	itemPrevSlotIdTemp = {},
	checkedItemTemp = {},
}
local SPELL_IDS = {
	milling = 51005,
	prospect = 31252,
	disenchant = 13262,
}
local TARGET_SLOT_ID_MULTIPLIER = 1000000
local STATE_SCHEMA = Reactive.CreateStateSchema("DestroyingBagDBState")
	:AddBooleanField("canCombine", false)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

BagDB:OnModuleLoad(function()
	private.db = Database.NewSchema("DESTROYING_INFO")
		:AddUniqueStringField("itemString")
		:AddNumberField("minQuantity")
		:AddNumberField("spellId")
		:Commit()
	private.state = STATE_SCHEMA:CreateState()
	BagTracking.RegisterCallback(private.UpdateBagDB)
end)

AddonSettings.RegisterOnLoad(BagDB, function(db)
	private.settings = db:NewView("BagDBSettings")
		:AddKey("global", "destroyingOptions", "deAbovePrice")
		:AddKey("global", "destroyingOptions", "deMaxQuality")
		:AddKey("global", "destroyingOptions", "includeSoulbound")
		:Commit()
		:RegisterCallback("deAbovePrice", private.UpdateBagDB)
		:RegisterCallback("deMaxQuality", private.UpdateBagDB)
		:RegisterCallback("includeSoulbound", private.UpdateBagDB)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the spell ID to destroy an item in the bags.
---@param itemString string The item string
---@return number
function BagDB.GetSpellId(itemString)
	return private.db:GetRowFields(private.db:GetUniqueRow("itemString", itemString), "spellId")
end

---Creates a publisher for whether or not there are stacks to combine.
---@return ReactivePublisherSchema
function BagDB.CanCombinePublisher()
	return private.state:Publisher("canCombine")
end

---Iterates over the pending stacks to combine.
---@return fun(): number, number, number @Iterator with fields: `index`, `sourceSlotId`, `targetSlotId`
function BagDB.PendingCombineIterator()
	return private.PendingCombineIterator
end

---Creates a query.
---@return DatabaseQuery
function BagDB.CreateQuery()
	return BagTracking.CreateQueryBags()
		:LeftJoin(Ignore.GetDBForJoin(), "itemString")
		:InnerJoin(private.db, "itemString")
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:NotEqual("ignoreSession", true)
		:NotEqual("ignorePermanent", true)
		:GreaterThanOrEqual("quantity", Database.OtherFieldQueryParam("minQuantity"))
		:OrderBy("name", true)
		:OrderBy("slotId", true)
end

---Waits for the bag DB to be updated from a thread context.
function BagDB.WaitForUpdateThreaded()
	private.bagUpdateSignal:Clear()
	Threading.WaitForSignal(private.bagUpdateSignal)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateBagDB()
	wipe(private.pendingCombines)
	private.db:TruncateAndBulkInsertStart()
	assert(not next(private.itemPrevSlotIdTemp) and not next(private.checkedItemTemp))
	if LibTSMApp.IsMistsClassic() then
		local disenchantName = Spell.GetInfo(7411)
		local jewelcraftName = Spell.GetInfo(28897)
		local inscriptionName = Spell.GetInfo(45357)
		assert(disenchantName and jewelcraftName and inscriptionName)
		private.disenchantSkillLevel = Profession.GetSkill(disenchantName)
		private.jewelcraftSkillLevel = Profession.GetSkill(jewelcraftName)
		private.inscriptionSkillLevel = Profession.GetSkill(inscriptionName)
	elseif LibTSMApp.IsBCClassic() then
		local disenchantName = Spell.GetInfo(7411)
		local jewelcraftName = Spell.GetInfo(28897)
		assert(disenchantName and jewelcraftName)
		private.disenchantSkillLevel = Profession.GetSkill(disenchantName)
		private.jewelcraftSkillLevel = Profession.GetSkill(jewelcraftName)
	end
	local query = BagTracking.CreateQueryBags()
		:AutoRelease()
		:OrderBy("slotId", true)
		:If(not private.settings.includeSoulbound)
			:Equal("isBound", false)
		:End()
	for _, slotId, itemString, quantity in query:Iterator("slotId", "itemString", "quantity") do
		local minQuantity = nil
		if not private.checkedItemTemp[itemString] then
			private.checkedItemTemp[itemString] = true
			local spellId = nil
			minQuantity, spellId = private.ProcessBagItem(itemString)
			if minQuantity then
				private.db:BulkInsertNewRow(itemString, minQuantity, spellId)
			end
		elseif private.db:HasUniqueRow("itemString", itemString) then
			minQuantity = private.db:GetRowFields(private.db:GetUniqueRow("itemString", itemString), "minQuantity")
		end
		if minQuantity and quantity % minQuantity ~= 0 then
			if private.itemPrevSlotIdTemp[itemString] then
				-- We can combine this with the previous partial stack
				tinsert(private.pendingCombines, private.itemPrevSlotIdTemp[itemString] * TARGET_SLOT_ID_MULTIPLIER + slotId)
				private.itemPrevSlotIdTemp[itemString] = nil
			else
				private.itemPrevSlotIdTemp[itemString] = slotId
			end
		end
	end
	Table.WipeAndDeallocate(private.checkedItemTemp)
	Table.WipeAndDeallocate(private.itemPrevSlotIdTemp)
	private.db:BulkInsertEnd()
	private.state.canCombine = #private.pendingCombines > 0
	private.bagUpdateSignal:Set()
end

function private.ProcessBagItem(itemString)
	if Ignore.HasItem(itemString) then
		return
	end

	local spellId, minQuantity = private.IsDestroyable(itemString)
	if not spellId then
		return
	elseif spellId == SPELL_IDS.disenchant then
		local deAbovePrice = CustomString.GetValue(private.settings.deAbovePrice, itemString) or 0
		local deValue = CustomString.GetValue("Destroy", itemString) or math.huge
		if deValue < deAbovePrice then
			return
		end
	end
	return minQuantity, spellId
end

function private.IsDestroyable(itemString)
	if private.destroyQuantityCache[itemString] then
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	-- Disenchanting
	local quality = ItemInfo.GetQuality(itemString)
	if ItemInfo.IsDisenchantable(itemString) and quality and quality <= private.settings.deMaxQuality then
		local hasSourceItem = true
		if LibTSMApp.IsMistsClassic() or LibTSMApp.IsBCClassic() then
			local classId = ItemInfo.GetClassId(itemString)
			local itemLevel = ItemInfo.GetItemLevel(ItemString.GetBaseFast(itemString))
			hasSourceItem = false
			if classId and itemLevel then
				for targetItemString in Conversion.DisenchantTargetItemIterator() do
					local _, _, _, _, skillRequired = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel)
					if private.disenchantSkillLevel and skillRequired and private.disenchantSkillLevel >= skillRequired then
						hasSourceItem = true
					end
				end
			end
		end
		if hasSourceItem then
			private.canDestroyCache[itemString] = Spell.IsKnown(SPELL_IDS.disenchant) and SPELL_IDS.disenchant
			private.destroyQuantityCache[itemString] = 1
			return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
		end
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	local conversionMethod, destroySpellId = nil, nil
	local classId = ItemInfo.GetClassId(itemString) or -1
	local subClassId = ItemInfo.GetSubClassId(itemString) or -1
	-- Workaround for Fire Leaf (i:39970) not being treated as an herb (at least in classic)
	if Item.IsClassMillable(classId, subClassId) or itemString == "i:39970" then
		conversionMethod = Conversion.METHOD.MILL
		destroySpellId = SPELL_IDS.milling
	elseif Item.IsClassProspectable(classId, subClassId) then
		conversionMethod = Conversion.METHOD.PROSPECT
		destroySpellId = SPELL_IDS.prospect
	else
		private.canDestroyCache[itemString] = false
		private.destroyQuantityCache[itemString] = nil
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	local hasSourceItem = false
	for _, _, _, _, _, _, _, skillRequired in Conversion.TargetItemsByMethodIterator(itemString, conversionMethod) do
		if not skillRequired or (conversionMethod == Conversion.METHOD.PROSPECT and private.jewelcraftSkillLevel and skillRequired and private.jewelcraftSkillLevel >= skillRequired) or (conversionMethod == Conversion.METHOD.MILL and private.inscriptionSkillLevel and skillRequired and private.inscriptionSkillLevel >= skillRequired) then
			hasSourceItem = true
		end
	end
	if hasSourceItem then
		private.canDestroyCache[itemString] = Spell.IsKnown(destroySpellId) and destroySpellId
		private.destroyQuantityCache[itemString] = 5
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
end

function private.PendingCombineIterator(_, index)
	index = (index or 0) + 1
	local combineSlotId = private.pendingCombines[index]
	if not combineSlotId then
		return
	end
	local sourceSlotId = combineSlotId % TARGET_SLOT_ID_MULTIPLIER
	local targetSlotId = floor(combineSlotId / TARGET_SLOT_ID_MULTIPLIER)
	return index, sourceSlotId, targetSlotId
end

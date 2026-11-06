-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Item = App:From("LibTSMWoW"):Include("API.Item")
local CharacterInfo = App:From("LibTSMWoW"):Include("Util.CharacterInfo")
local ItemClass = App:From("LibTSMWoW"):Include("Util.ItemClass")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {
	subclassTemp = {},
	invSlotTemp = {},
	filterPartsTemp = {},
}
local CLASS_LIST = nil ---@type (string[])!
local RARITY_LIST = nil ---@type (string[])!
local ALL_ITEM_CLASSES = L["All Item Classes"]
local ALL_ITEM_SUBCLASSES = L["All Item Subclasses"]
local ALL_SLOTS = L["All Slots"]
local ALL_RARITIES = L["All Rarities"]
local DEFAULT_LEVEL_RANGE = "0,"..CharacterInfo.GetMaxLevel()
local DEFAULT_ITEM_LEVEL_RANGE = "0,"..Item.GetMaxItemLevel()
local HAS_UPGRADES_FILTER = App.IsRetail() or App.IsForever()
local HAS_UNCOLLECTED_FILTER = not App.IsVanillaClassic() and not App.IsBCClassic()



-- ============================================================================
-- Element Definition
-- ============================================================================

local ShoppingAdvancedSearch = UIElements.Define("ShoppingAdvancedSearch", "BaseFrame")
ShoppingAdvancedSearch._STATE_SCHEMA = ShoppingAdvancedSearch._STATE_SCHEMA:Extend("ShoppingAdvancedSearchState")
	:AddDeferredUIElementField("subclassDropdown", "ListDropdown")
	:AddDeferredUIElementField("invSlotDropdown", "ListDropdown")
	:AddStringField("keyword", "")
	:AddStringField("class", ALL_ITEM_CLASSES)
	:AddStringField("subclass", ALL_ITEM_SUBCLASSES)
	:AddStringField("invSlot", ALL_SLOTS)
	:AddStringField("levelRange", DEFAULT_LEVEL_RANGE)
	:AddStringField("itemLevelRange", DEFAULT_ITEM_LEVEL_RANGE)
	:AddNumberField("maxQty", 0)
	:AddStringField("minRarity", ALL_RARITIES)
	:AddBooleanField("uncollected", false)
	:AddBooleanField("upgrades", false)
	:AddBooleanField("usable", false)
	:AddBooleanField("exact", false)
	:AddBooleanField("crafting", false)
	:Commit()
ShoppingAdvancedSearch:_AddActionScripts("OnBackClicked", "OnStartScanClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingAdvancedSearch:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	if not CLASS_LIST then
		CLASS_LIST = {}
		tinsert(CLASS_LIST, ALL_ITEM_CLASSES)
		for _, class in ipairs(ItemClass.GetClasses()) do
			tinsert(CLASS_LIST, class)
		end
	end
	if not RARITY_LIST then
		RARITY_LIST = {}
		tinsert(RARITY_LIST, ALL_RARITIES)
		for i = 1, 7 do
			tinsert(RARITY_LIST, _G["ITEM_QUALITY"..i.."_DESC"])
		end
	end
end

function ShoppingAdvancedSearch:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseScrollFrame", "search")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8)
				:AddChild(UIElements.New("BackButton", "button")
					:SetAction("OnClick", "ACTION_BACK")
				)
				:AddChild(UIElements.New("Input", "keyword")
					:SetMargin(8, 0, 0, 0)
					:SetLeadIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:SetHintText(L["Filter by Keyword"])
					:MirrorValueState(self._state, "keyword")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "body")
				:SetLayout("VERTICAL")
				:SetPadding(8, 8, 0, 0)
				:AddChild(UIElements.New("BaseFrame", "classAndSubClassLabels")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 16, 0)
					:AddChild(UIElements.New("Text", "classLabel")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Item Class"])
					)
					:AddChild(UIElements.New("Text", "subclassLabel")
						:SetMargin(16, 0, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Item Subclass"])
					)
				)
				:AddChild(UIElements.New("BaseFrame", "classAndSubClass")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, 4, 0)
					:AddChild(UIElements.New("ListDropdown", "classDropdown")
						:SetMargin(0, 16, 0, 0)
						:SetItems(CLASS_LIST)
						:SetHintText(L["Select item class"])
						:MirrorSelectedItemState(self._state, "class")
						:SetAction("OnSelectionChanged", "ACTION_CLASS_CHANGED")
					)
					:AddChild(UIElements.New("ListDropdown", "subclassDropdown")
						:SetHintText(L["Select item subclass"])
						:SetDisabled(self._state:Publisher("class"):ToBooleanEquals(ALL_ITEM_CLASSES))
						:MirrorSelectedItemState(self._state, "subclass")
						:SetAction("OnSelectionChanged", "ACTION_SUB_CLASS_CHANGED")
						:BindElement(self._state, "subclassDropdown")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "itemSlot")
					:SetLayout("VERTICAL")
					:SetMargin(0, 0, 16, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 4)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Item Slot"])
					)
					:AddChild(UIElements.New("BaseFrame", "frame")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:AddChild(UIElements.New("ListDropdown", "dropdown")
							:SetMargin(0, 16, 0, 0)
							:SetHintText(L["Select slot"])
							:SetDisabled(self._state:Publisher("subclass"):ToBooleanEquals(ALL_ITEM_SUBCLASSES))
							:MirrorSelectedItemState(self._state, "invSlot")
							:BindElement(self._state, "invSlotDropdown")
						)
						:AddChild(UIElements.New("Spacer", "spacer"))
					)
				)
				:AddChild(UIElements.New("Text", "levelLabel")
					:SetHeight(20)
					:SetMargin(0, 0, 16, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Required Level Range"])
				)
				:AddChild(UIElements.New("RangeInput", "levelSlider")
					:SetHeight(24)
					:SetMargin(0, 0, 2, 0)
					:SetRange(DEFAULT_LEVEL_RANGE)
					:MirrorValueState(self._state, "levelRange")
				)
				:AddChild(UIElements.New("Text", "itemLevelLabel")
					:SetHeight(20)
					:SetMargin(0, 0, 18, 0)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Item Level Range"])
				)
				:AddChild(UIElements.New("RangeInput", "itemLevelSlider")
					:SetHeight(24)
					:SetMargin(0, 0, 2, 0)
					:SetRange(DEFAULT_ITEM_LEVEL_RANGE)
					:MirrorValueState(self._state, "itemLevelRange")
				)
				:AddChild(UIElements.New("BaseFrame", "content")
					:SetLayout("HORIZONTAL")
					:SetHeight(48)
					:SetMargin(0, 0, 18, 0)
					:AddChild(UIElements.New("BaseFrame", "frame")
						:SetLayout("VERTICAL")
						:SetWidth(254)
						:AddChild(UIElements.New("Text", "label")
							:SetFont("BODY_SMALL_SEMIBOLD")
							:SetText(L["Maximum Quantity to Buy"])
						)
						:AddChild(UIElements.New("BaseFrame", "maxQty")
							:SetLayout("HORIZONTAL")
							:SetHeight(24)
							:SetMargin(0, 0, 4, 0)
							:AddChild(UIElements.New("NumberInput", "input")
								:SetWidth(178)
								:SetMargin(0, 4, 0, 0)
								:SetValidRange(0, 2000)
								:MirrorValueState(self._state, "maxQty")
							)
							:AddChild(UIElements.New("Text", "label")
								:SetWidth(100)
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetFormattedText("(%d - %d)", 0, 2000)
							)
						)
					)
					:AddChild(UIElements.New("BaseFrame", "minRarity")
						:SetLayout("VERTICAL")
						:AddChild(UIElements.New("Text", "label")
							:SetFont("BODY_SMALL_SEMIBOLD")
							:SetText(L["Minimum Rarity"])
						)
						:AddChild(UIElements.New("ListDropdown", "dropdown")
							:SetHeight(24)
							:SetMargin(0, 0, 4, 0)
							:SetItems(RARITY_LIST)
							:SetHintText(L["Select rarity"])
							:MirrorSelectedItemState(self._state, "minRarity")
						)
					)
				)
				:AddChild(UIElements.New("BaseFrame", "filters")
					:SetLayout("HORIZONTAL")
					:SetMargin(0, 0, 16, 8)
					:AddChildIf(HAS_UNCOLLECTED_FILTER, UIElements.New("Checkbox", "uncollectedCheckbox")
						:SetHeight(20)
						:SetText(L["Uncollected Only"])
						:MirrorIsCheckedState(self._state, "uncollected")
					)
					:AddChildIf(HAS_UPGRADES_FILTER, UIElements.New("Checkbox", "upgradesCheckbox")
						:SetHeight(20)
						:SetText(L["Upgrades Only"])
						:MirrorIsCheckedState(self._state, "upgrades")
					)
					:AddChild(UIElements.New("Checkbox", "usableCheckbox")
						:SetHeight(20)
						:SetText(L["Usable Only"])
						:MirrorIsCheckedState(self._state, "usable")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "filters2")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Checkbox", "exact")
						:SetText(L["Exact Match"])
						:MirrorIsCheckedState(self._state, "exact")
					)
					:AddChild(UIElements.New("Checkbox", "crafting")
						:SetText(L["Crafting Mode"])
						:MirrorIsCheckedState(self._state, "crafting")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetHeight(44)
			:SetPadding(8)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "startBtn")
				:SetMargin(0, 8, 0, 0)
				:SetText(L["Run Advanced Item Search"])
				:SetAction("OnClick", "ACTION_START_SCAN")
			)
			:AddChild(UIElements.New("MediumSecondaryActionButton", "resetBtn")
				:SetWidth("AUTO")
				:SetPadding(8, 8, 0, 0)
				:SetText(L["Reset All Filters"])
				:SetAction("OnClick", "ACTION_RESET")
			)
		)
	end

	self._state:Publisher("class")
		:ReplaceWith(ALL_ITEM_SUBCLASSES)
		:AssignToTableKey(self._state, "subclass")
	self._state:Publisher("subclass")
		:ReplaceWith(ALL_SLOTS)
		:AssignToTableKey(self._state, "invSlot")
end

---Gets the current keyword filter.
---@param value string The keyword filter
---@return self
function ShoppingAdvancedSearch:SetKeywordFilter(value)
	self._state.keyword = value
	return self
end



-- ===========================================================================
-- Private Class Methods
-- ============================================================================

---@param state ShoppingAdvancedSearchState
function ShoppingAdvancedSearch.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_BACK" then
		self:_SendActionScript("OnBackClicked")
	elseif action == "ACTION_CLASS_CHANGED" then
		if state.class == ALL_ITEM_CLASSES then
			return
		end
		assert(not next(private.subclassTemp))
		tinsert(private.subclassTemp, ALL_ITEM_SUBCLASSES)
		for _, v in ipairs(ItemClass.GetSubClasses(state.class)) do
			tinsert(private.subclassTemp, v)
		end
		for _, v in ItemClass.GenericInventorySlotStringIterator(state.class) do
			tinsert(private.subclassTemp, v)
		end
		state.subclassDropdown:SetItems(private.subclassTemp)
		wipe(private.subclassTemp)
	elseif action == "ACTION_SUB_CLASS_CHANGED" then
		if state.subclass == ALL_ITEM_SUBCLASSES then
			return
		end
		assert(not next(private.invSlotTemp))
		tinsert(private.invSlotTemp, ALL_SLOTS)
		for _, invSlot in ipairs(ItemClass.GetInventorySlots(state.class, state.subclass)) do
			tinsert(private.invSlotTemp, invSlot)
		end
		state.invSlotDropdown:SetItems(private.invSlotTemp)
		wipe(private.invSlotTemp)
	elseif action == "ACTION_RESET" then
		state.keyword = ""
		state.class = ALL_ITEM_CLASSES
		state.levelRange = DEFAULT_LEVEL_RANGE
		state.itemLevelRange = DEFAULT_ITEM_LEVEL_RANGE
		state.maxQty = 0
		state.minRarity = ALL_RARITIES
		state.uncollected = false
		state.upgrades = false
		state.usable = false
		state.exact = false
		state.crafting = false
		self:Draw()
	elseif action == "ACTION_START_SCAN" then
		assert(not next(private.filterPartsTemp))
		tinsert(private.filterPartsTemp, strtrim(state.keyword))
		if state.levelRange ~= DEFAULT_LEVEL_RANGE then
			local minLevel, maxLevel = strsplit(",", state.levelRange)
			---@cast maxLevel string?
			assert(maxLevel)
			tinsert(private.filterPartsTemp, minLevel)
			tinsert(private.filterPartsTemp, maxLevel)
		end
		if state.itemLevelRange ~= DEFAULT_ITEM_LEVEL_RANGE then
			local minItemLevel, maxItemLevel = strsplit(",", state.itemLevelRange)
			---@cast maxItemLevel string?
			assert(maxItemLevel)
			tinsert(private.filterPartsTemp, "i"..minItemLevel)
			tinsert(private.filterPartsTemp, "i"..maxItemLevel)
		end
		if state.class ~= ALL_ITEM_CLASSES then
			tinsert(private.filterPartsTemp, state.class)
		end
		if state.subclass ~= ALL_ITEM_SUBCLASSES then
			tinsert(private.filterPartsTemp, state.subclass)
		end
		if state.invSlot ~= ALL_SLOTS then
			tinsert(private.filterPartsTemp, state.invSlot)
		end
		if state.minRarity ~= ALL_RARITIES then
			tinsert(private.filterPartsTemp, state.minRarity)
		end
		if state.maxQty > 0 then
			tinsert(private.filterPartsTemp, "x"..state.maxQty)
		end
		if HAS_UNCOLLECTED_FILTER and state.uncollected then
			tinsert(private.filterPartsTemp, "uncollected")
		end
		if HAS_UPGRADES_FILTER and state.upgrades then
			tinsert(private.filterPartsTemp, "upgrades")
		end
		if state.usable then
			tinsert(private.filterPartsTemp, "usable")
		end
		if state.exact then
			tinsert(private.filterPartsTemp, "exact")
		end
		if state.crafting then
			tinsert(private.filterPartsTemp, "crafting")
		end
		local filter = table.concat(private.filterPartsTemp, "/")
		wipe(private.filterPartsTemp)
		self:_SendActionScript("OnStartScanClicked", filter)
	else
		error("Unknown action: "..tostring(action))
	end
end

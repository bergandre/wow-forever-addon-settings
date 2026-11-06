-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = App:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = App:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = App:From("LibTSMTypes"):Include("Crafting.RecipeString")
local TradeSkill = App:From("LibTSMWoW"):Include("API.TradeSkill")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = App:From("LibTSMService"):Include("Profession")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local CraftingUIUtils = App:From("LibTSMUI"):Include("Crafting.CraftingUIUtils")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	matsTemp = {},
	qualityMatsTemp = {},
	optionalMatsTemp = {},
	rankDropdownTemp = {},
}
local MAX_CRAFT_RANK = 3
local MAX_CRAFT_LEVEL = 4
local MAX_CRAFT_QUALITY = 5
local CRAFT_TYPE_BUTTON_TEXT_LOOKUP = {
	ITEM = L["Craft"],
	RESEARCH = L["Craft"],
	ENCHANT = L["Enchant"],
	ENCHANT_VELLUM = L["Enchant"],
	SALVAGE = L["Salvage"],
	TINKER = L["Tinker"],
	NONE = "",
}
local CRAFT_TYPE_QUEUE_DISABLED_LOOKUP = {
	ITEM = false,
	RESEARCH = true,
	ENCHANT = true,
	ENCHANT_VELLUM = false,
	SALVAGE = true,
	TINKER = true,
	NONE = true,
}
local CRAFT_TYPE_CAN_CRAFT_MULTIPLE_LOOKUP = {
	ITEM = true,
	RESEARCH = false,
	ENCHANT = false,
	ENCHANT_VELLUM = App.IsRetail() or App.IsForever(),
	SALVAGE = true,
	TINKER = false,
	NONE = false,
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftDetails = UIElements.Define("CraftDetails", "BaseFrame")
CraftDetails._STATE_SCHEMA = CraftDetails._STATE_SCHEMA:Extend("CraftDetailsState")
	:AddDeferredUIElementField("headerFrame", "BaseFrame")
	:AddDeferredUIElementField("nameButton", "BaseButton")
	:AddDeferredUIElementField("qualityButton", "BaseButton")
	:AddDeferredUIElementField("itemSelector", "ItemSelector")
	:AddDeferredUIElementField("craftButton", "MediumPrimaryActionButton")
	:AddDeferredUIElementField("costText", "Text")
	:AddDeferredUIElementField("rankDropdown", "ListDropdown")
	:AddOptionalStringField("craftString")
	:AddOptionalStringField("recipeString")
	:AddNumberField("numCraftable", 0)
	:AddBooleanField("hasVellum", false)
	:AddOptionalStringField("neededTools")
	:AddOptionalNumberField("remainingCooldown")
	:AddOptionalEnumField("craftingSource", CraftingUIUtils.CRAFTING_SOURCE)
	:AddBooleanField("canCraft", false)
	:AddStringField("craftType", "NONE")
	:AddBooleanField("canCraftMultiple", false)
	:AddOptionalNumberField("craftingCost")
	:AddBooleanField("useConcentration", false)
	:AddNumberField("quantityInputValue", 1)
	:Commit()
CraftDetails:_AddActionScripts("OnQueueButtonClick", "OnCraftButtonMouseDown", "OnCraftButtonClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftDetails:__init()
	self.__super:__init()
	BagTracking.RegisterCallback(self:__closure("_HandleCraftableUpdate"))
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_SEND_CRAFT_BUTTON_ACTION_SCRIPT")
		:SuppressActionLog("ACTION_HANDLE_ITEM_SELECTED_CHANGED")

	self._state:PublisherForFunctionWithKeys(private.CraftStringToNeededTools, "craftString")
		:AssignToTableKey(self._state, "neededTools")
	self._state:Publisher([[not neededTools and not remainingCooldown and numCraftable > 0 and craftingSource == nil]])
		:Share()
		:AssignToTableKey(self._state, "canCraft")
		:CallFunction(self:__closure("_UpdateClassicCraftingButton"))
		:EndShare()
	self._state:PublisherForFunctionWithKeys(private.CraftStringToCraftType, "craftString")
		:Share()
		:AssignToTableKey(self._state, "craftType")
		:Map(CRAFT_TYPE_CAN_CRAFT_MULTIPLE_LOOKUP)
		:AssignToTableKey(self._state, "canCraftMultiple")
		:EndShare()
end

function CraftDetails:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(0, 0, 4, 4)
	local craftStringPublisher = self._state:Publisher("craftString")
		:Share()
	local recipeStringPublisher = self._state:Publisher("recipeString")
		:Share()
	local craftingCostPublisher = self._state:Publisher("recipeString")
		:MapNonNil(Crafting.GetCostsByRecipeString)
		:Share()
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8, 8, 4, 8)
			:SetManager(self._childManager)
			:BindElement(self._state, "headerFrame")
			:DrawPublisher(craftingCostPublisher:ReplaceWith(nil))
			:AddChild(UIElements.New("BaseButton", "name")
				:SetHeight(28)
				:SetWidth("AUTO")
				:SetFont("ITEM_BODY1")
				:SetJustifyH("LEFT")
				:BindElement(self._state, "nameButton")
				:SetText(craftStringPublisher:Map(private.CraftStringToNameText))
				:SetTooltip(self._state:PublisherForFunctionWithKeys(private.RecipeStringToResultTooltip, "recipeString"))
				:SetAction("OnClick", "ACTION_HANDLE_ITEM_CLICKED")
			)
			:AddChild(UIElements.New("BaseButton", "qualityBtn")
				:SetWidth("AUTO")
				:SetHeight(20)
				:SetMargin(8, 0, 0, 0)
				:SetBackground("container/low")
				:BindElement(self._state, "qualityButton")
				:SetText(craftStringPublisher:Map(private.CraftStringToQualityBtnText))
				:SetShown(craftStringPublisher:Map(private.CraftStringToQualityBtnShown))
				:SetAction("OnClick", "ACTION_SHOW_QUANTITY_DIALOG")
			)
			:AddChild(UIElements.New("ListDropdown", "rankDropdown")
				:SetSize(80, 20)
				:SetMargin(8, 0, 0, 0)
				:BindElement(self._state, "rankDropdown")
				:SetShown(craftStringPublisher:Map(private.CraftStringToRankDropdownShown))
				:SetHintText(L["Select rank"])
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_RANK_CHANGED")
			)
			:AddChild(UIElements.New("Text", "rankText")
				:SetWidth("AUTO")
				:SetMargin(8, 0, 0, 0)
				:SetText(craftStringPublisher:Map(private.CraftStringToRankText))
				:SetShown(craftStringPublisher:Map(private.CraftStringToRankTextShown))
			)
			:AddChild(UIElements.New("Text", "noRecipe")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetTextColor("error/main")
				:SetText(L["No recipe selected"])
				:SetShown(craftStringPublisher:ToBooleanEquals(nil))
			)
			:AddChild(UIElements.New("Text", "error")
				:SetMargin(16, 0, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetTextColor("error/main")
				:SetText(self._state:PublisherForFunctionWithKeys(private.StateToErrStr, "craftString", "neededTools", "remainingCooldown", "numCraftable"))
			)
			:AddChild(UIElements.New("Text", "costLabel")
				:SetWidth("AUTO")
				:SetMargin(24, 4, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(L["Crafting Cost"]..":")
			)
			:AddChild(UIElements.New("Text", "costText")
				:SetWidth("AUTO")
				:SetFont("TABLE_XSMALL")
				:BindElement(self._state, "costText")
				:SetText(craftingCostPublisher:MapNonNil(Money.ToStringForUI):CoalesceNil("---"))
			)
		)
		self:AddChild(UIElements.New("HorizontalLine", "headerLine"))
		local craftTypePublisher = self._state:Publisher("craftType")
			:Share()
		local craftingSourcePublisher = self._state:Publisher("craftingSource")
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:SetMargin(0, 0, 8, 0)
			:SetPadding(8, 0, 0, 0)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "left")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("BaseFrame", "selection")
					:SetLayout("VERTICAL")
					:SetShown(craftTypePublisher:ToBooleanEquals("SALVAGE"))
					:AddChild(UIElements.New("Text", "description")
						:SetSize("AUTO", 32)
						:SetFont("BODY_XSMALL")
						:SetText(craftStringPublisher:Map(Profession.GetRecipeDescription))
					)
					:AddChild(UIElements.New("BaseFrame", "content")
						:SetLayout("HORIZONTAL")
						:SetHeight(50)
						:SetMargin(0, 0, 4, 4)
						:AddChild(UIElements.New("ItemSelector", "itemSelector")
							:SetSize(32, 32)
							:BindElement(self._state, "itemSelector")
							:SetAction("OnSelectionChanged", "ACTION_HANDLE_ITEM_SELECTED_CHANGED")
						)
						:AddChild(UIElements.New("Spacer", "spacer"))
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
				:AddChild(UIElements.New("BaseFrame", "mats")
					:SetLayout("VERTICAL")
					:SetShown(craftStringPublisher:Map(private.CraftStringToMatsShown))
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(24)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Reagents"])
					)
					:AddChild(UIElements.New("CraftingMatList", "matList")
						:SetMargin(0, 0, 4, 0)
						:SetBackgroundColor("surface/main")
						:SetRecipeString(recipeStringPublisher)
						:SetAction("OnQualityChanged", "ACTION_SET_RECIPE_STRING")
					)
					:AddChild(UIElements.New("OptionalMatsRow", "optionalMats")
						:SetHeight(24)
						:SetMargin(0, 0, 4, 0)
						:SetShown(craftStringPublisher:Map(private.CraftStringToOptionsRowShown))
						:SetRecipeString(recipeStringPublisher)
						:SetAction("OnRecipeStringChanged", "ACTION_SET_RECIPE_STRING")
						:AddChild(UIElements.New("Checkbox", "useConcentration")
							:SetWidth("AUTO")
							:SetText(L["Use Concentrate"])
							:SetShown(craftStringPublisher:Map(private.CraftStringToQualityBtnShown))
							:SetDisabled(self._state:PublisherForFunctionWithKeys(private.StateToConcentrationDisabled, "craftString", "useConcentration"))
							:MirrorIsCheckedState(self._state, "useConcentration")
							:SetAction("OnValueChanged", "ACTION_HANDLE_USE_CONCENTRATION_CHANGED")
						)
						:AddChild(UIElements.New("Spacer", "spacer"))
					)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "buttons")
				:SetLayout("VERTICAL")
				:SetWidth(187)
				:SetMargin(16, 0, 0, 0)
				:AddChild(UIElements.New("Spacer", "topSpacer"))
				:AddChild(UIElements.New("BaseFrame", "quantity")
					:SetLayout("HORIZONTAL")
					:SetHeight(28)
					:AddChild(UIElements.New("NumberInput", "input")
						:SetMargin(0, 8, 0, 0)
						:SetSubAddEnabled(true)
						:SetValidRange(1, 9999)
						:MirrorValueState(self._state, "quantityInputValue")
						:SetDisabled(self._state:Publisher("canCraftMultiple"):InvertBoolean())
					)
					:AddChild(UIElements.New("MediumTertiaryActionButton", "maxBtn")
						:SetWidth("AUTO")
						:SetPadding(16, 16, 0, 0)
						:SetText(L["Max"])
						:SetDisabled(self._state:Publisher([[not canCraftMultiple or quantityInputValue >= numCraftable]]))
						:DisableClickCooldown()
						:SetAction("OnClick", "ACTION_SET_MAX_QUANTITY")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "content")
					:SetLayout("HORIZONTAL")
					:SetHeight(28)
					:SetMargin(0, 0, 8, 8)
					:AddChild(UIElements.New("MediumPrimaryActionButton", "craftBtn")
						:BindElement(self._state, "craftButton")
						:SetText(craftTypePublisher:Map(CRAFT_TYPE_BUTTON_TEXT_LOOKUP))
						:SetPressed(craftingSourcePublisher:ToBooleanEquals(CraftingUIUtils.CRAFTING_SOURCE.CRAFT))
						:SetDisabled(self._state:Publisher("canCraft"):InvertBoolean())
						:SetAction("OnMouseDown", "ACTION_PREPARE_CRAFT")
						:SetAction("OnClick", "ACTION_CRAFT")
					)
					:AddChild(UIElements.New("MediumPrimaryActionButton", "craftVellumBtn")
						:SetWidth(110)
						:SetMargin(8, 0, 0, 0)
						:SetText(L["Craft Vellum"])
						:SetDisabled(self._state:Publisher([[craftType ~= "ENCHANT_VELLUM" or not canCraft or not hasVellum]]))
						:SetShown(craftTypePublisher:ToBooleanEquals("ENCHANT_VELLUM"))
						:SetPressed(craftingSourcePublisher:ToBooleanEquals(CraftingUIUtils.CRAFTING_SOURCE.VELLUM))
						:SetAction("OnMouseDown", "ACTION_PREPARE_CRAFT_VELLUM")
						:SetAction("OnClick", "ACTION_CRAFT_VELLUM")
					)
				)
				:AddChild(UIElements.New("MediumSecondaryActionButton", "queueBtn")
					:SetText(L["Queue"])
					:DisableClickCooldown()
					:SetDisabled(craftTypePublisher:Map(CRAFT_TYPE_QUEUE_DISABLED_LOOKUP))
					:SetAction("OnClick", "ACTION_HANDLE_QUEUE_BUTTON_CLICKED")
				)
				:AddChild(UIElements.New("Spacer", "bottomSpacer"))
			)
		)
		self:AddCancellable(craftTypePublisher:EndShare())
		self:AddCancellable(craftingSourcePublisher:EndShare())
	end

	craftStringPublisher
		:MapNonNil(Profession.GetRemainingCooldown)
		:AssignToTableKey(self._state, "remainingCooldown")
		:EndShare()
	recipeStringPublisher
		:MapNonNil(Profession.HasVellum)
		:CoalesceNil(false)
		:AssignToTableKey(self._state, "hasVellum")
		:CallFunction(self:__closure("_HandleCraftableUpdate"))
		:EndShare()
	craftingCostPublisher:EndShare()
	self:_UpdateClassicCraftingButton(self._state.canCraft)
end

---Sets the selected recipe's spell ID.
---@param value? number|ReactivePublisherSchemaBase The spellId or a publisher
---@return self
function CraftDetails:SetSpellId(value)
	if value == nil or type(value) == "number" then
		assert(#private.rankDropdownTemp == 0)
		local knownRank, lowestQuality = nil, nil
		if value then
			for i = 1, MAX_CRAFT_RANK do
				if Profession.GetIndexByCraftString(CraftString.Get(value, i)) then
					knownRank = i
					break
				end
			end
			for i = 1, MAX_CRAFT_LEVEL do
				if Profession.GetIndexByCraftString(CraftString.Get(value, nil, i)) then
					tinsert(private.rankDropdownTemp, format(L["Rank %d"], i))
				else
					break
				end
			end
			for i = 1, MAX_CRAFT_QUALITY do
				if Profession.GetIndexByCraftString(CraftString.Get(value, nil, nil, i)) then
					lowestQuality = i
					break
				end
			end
		end
		local highestLevel = #private.rankDropdownTemp
		highestLevel = highestLevel > 0 and highestLevel or nil
		local craftString = value and CraftString.Get(value, knownRank, highestLevel, lowestQuality) or nil
		self._state.rankDropdown
			:SetItems(private.rankDropdownTemp)
			:SetSelectedItem(highestLevel and private.rankDropdownTemp[highestLevel] or nil, true)
		wipe(private.rankDropdownTemp)

		local changed = craftString ~= self._state.craftString
		self._state.craftString = craftString
		if changed then
			self._state.useConcentration = false
		end
		if TradeSkill.IsClassicCrafting() then
			TradeSkill.SelectCraft(craftString and Profession.GetIndexByCraftString(craftString) or 0)
		end
		self:_UpdateRecipeString(changed)
		self:Draw()
	else
		self:_MethodPublisher(value, "SetSpellId")
	end
	return self
end

---Set the type of the in-progress craft.
---@param value ReactivePublisherSchemaBase A publisher for crafting source values
---@return CraftDetails
function CraftDetails:SetCraftingSource(value)
	return self:_AssignStateKeyPublisher(value, "craftingSource")
end

---Sets the quantity currently being crafted.
---@param value number|ReactivePublisherSchemaBase The number being crafted or a publisher
---@return self
function CraftDetails:SetCraftingQuantity(value)
	if type(value) == "number" then
		self._state.quantityInputValue = value
	else
		self:_MethodPublisher(value, "SetCraftingQuantity")
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<CraftDetailsState>
---@param state CraftDetailsState
function CraftDetails.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_CLICKED" then
		assert(state.craftString)
		local itemString = Profession.GetResultInfo(state.craftString)
		if itemString then
			UIUtils.HandleModifiedItemClick(itemString)
		end
	elseif action == "ACTION_SHOW_QUANTITY_DIALOG" then
		assert(state.craftString)
		self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "container")
			:SetManager(manager)
			:AddChildNoLayout(UIElements.New("CraftTierDialog", "tier")
				:AddAnchor("BOTTOM", state.qualityButton, "TOP", 0, 4)
				:SetCraftString(state.craftString)
				:SetAction("OnQualityChanged", "ACTION_HANDLE_QUALITY_CHANGED")
			)
			:AddChildNoLayout(UIElements.New("Text", "name")
				:AddAnchor("TOPLEFT", state.nameButton)
				:AddAnchor("BOTTOMRIGHT", state.nameButton)
				:SetFont("ITEM_BODY1")
				:SetJustifyH("LEFT")
				:SetText(private.CraftStringToNameText(state.craftString))
			)
			:AddChildNoLayout(UIElements.New("BaseButton", "qualityBtn")
				:AddAnchor("TOPLEFT", state.qualityButton)
				:AddAnchor("BOTTOMRIGHT", state.qualityButton)
				:SetBackground("container/low")
				:SetText(private.CraftStringToQualityBtnText(state.craftString))
				:SetAction("OnClick", "ACTION_HIDE_QUALITY_DIALOG")
			)
		)
	elseif action == "ACTION_HIDE_QUALITY_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_HANDLE_QUALITY_CHANGED" then
		local craftString, concentration = ...
		state.useConcentration = concentration > 0
		state.craftString = craftString
		self:_UpdateRecipeString(true)
		state.headerFrame:Draw()
	elseif action == "ACTION_HANDLE_USE_CONCENTRATION_CHANGED" then
		assert(state.craftString)
		local quality = CraftString.GetQuality(state.craftString)
		assert(quality)
		state.craftString = CraftString.SetQuality(state.craftString, quality + (state.useConcentration and 1 or -1))
		self:_UpdateRecipeString()
		state.headerFrame:Draw()
	elseif action == "ACTION_HANDLE_RANK_CHANGED" then
		local level = state.rankDropdown:GetSelectedItemIndex()
		if not level then
			return
		end
		assert(self._state.craftString)
		self._state.craftString = CraftString.SetLevel(self._state.craftString, level)
		self:_UpdateRecipeString()
	elseif action == "ACTION_HANDLE_ITEM_SELECTED_CHANGED" then
		if not state.acquired or not state.recipeString then
			return
		end
		assert(state.craftString)
		state.neededTools = private.CraftStringToNeededTools(state.craftString)
		state.numCraftable = Profession.IsSalvage(state.craftString) and self:_GetSalvageCraftNum() or Crafting.GetNumCraftableRecipeString(state.recipeString)
		state.hasVellum = Profession.HasVellum(state.recipeString)
	elseif action == "ACTION_SET_RECIPE_STRING" then
		state.recipeString = ...
	elseif action == "ACTION_SET_MAX_QUANTITY" then
		if state.numCraftable < 1 then
			return
		end
		state.quantityInputValue = state.numCraftable
	elseif action == "ACTION_PREPARE_CRAFT" then
		return manager:ProcessAction("ACTION_SEND_CRAFT_BUTTON_ACTION_SCRIPT", "OnCraftButtonMouseDown", false)
	elseif action == "ACTION_PREPARE_CRAFT_VELLUM" then
		return manager:ProcessAction("ACTION_SEND_CRAFT_BUTTON_ACTION_SCRIPT", "OnCraftButtonMouseDown", true)
	elseif action == "ACTION_CRAFT" then
		return manager:ProcessAction("ACTION_SEND_CRAFT_BUTTON_ACTION_SCRIPT", "OnCraftButtonClick", false)
	elseif action == "ACTION_CRAFT_VELLUM" then
		return manager:ProcessAction("ACTION_SEND_CRAFT_BUTTON_ACTION_SCRIPT", "OnCraftButtonClick", true)
	elseif action == "ACTION_SEND_CRAFT_BUTTON_ACTION_SCRIPT" then
		local actionScript, isVellum = ...
		self:_SendActionScript(actionScript, state.recipeString, self._state.quantityInputValue, isVellum, state.itemSelector:GetNextSalvageSlotId())
	elseif action == "ACTION_HANDLE_QUEUE_BUTTON_CLICKED" then
		self:_SendActionScript("OnQueueButtonClick", state.recipeString, self._state.quantityInputValue)
	else
		error("Unknown action: "..tostring(action))
	end
end

function CraftDetails.__private:_HandleCraftableUpdate()
	if not self._state.recipeString then
		return
	end
	assert(self._state.craftString)

	if Profession.IsSalvage(self._state.craftString) then
		local matString = Profession.GetOptionalMatString(self._state.craftString, 1)
		local requiredQty = Profession.GetCraftedQuantityRange(self._state.craftString)
		self._state.itemSelector:SetMatString(matString, requiredQty)

		local qualityCraftable, salvageCraftable = self:_GetSalvageCraftNum()
		self._state.numCraftable = qualityCraftable

		if salvageCraftable == 0 and qualityCraftable == 0 then
			self._state.itemSelector:SetSelection(nil)
		end
	else
		self._state.numCraftable = Crafting.GetNumCraftableRecipeString(self._state.recipeString)
	end

	self._state.neededTools = private.CraftStringToNeededTools(self._state.craftString)
	self._state.hasVellum = Profession.HasVellum(self._state.recipeString)
end

function CraftDetails.__private:_UpdateRecipeString(wipeExisting)
	if not self._state.craftString then
		self._state.recipeString = nil
		return
	end
	assert(not next(private.optionalMatsTemp))
	if self._state.recipeString and not wipeExisting then
		-- Ensure the existing optional mats are valid for the selected recipe and can be used with the selected craft level
		for _, slotId, matQuantityString in RecipeString.OptionalMatIterator(self._state.recipeString) do
			if Profession.IsValidOptionalMat(self._state.craftString, slotId, matQuantityString) then
				private.optionalMatsTemp[slotId] = matQuantityString
			end
		end
	end

	-- Clear the salvage Item Selector
	self._state.itemSelector:SetSelection(nil)
	-- Populate the quality mats
	assert(not next(private.matsTemp) and not next(private.qualityMatsTemp))
	for _, matString, quantity in Profession.MatIterator(self._state.craftString) do
		private.matsTemp[matString] = quantity
	end
	if not Crafting.GetQualityMats(self._state.craftString, private.matsTemp, private.qualityMatsTemp) then
		wipe(private.qualityMatsTemp)
	end
	for _, matString in Profession.MatIterator(self._state.craftString) do
		local matType = MatString.GetType(matString)
		local quantity = private.matsTemp[matString]
		assert(quantity)
		if matType == MatString.TYPE.QUALITY then
			local slotId = MatString.GetSlotId(matString)
			local matQuantityString = Table.KeyByValue(private.qualityMatsTemp, matString)
			private.optionalMatsTemp[slotId] = private.optionalMatsTemp[slotId] or matQuantityString or MatQuantityString.GetForSingleItem(MatString.GetQualityItem(matString, 1), quantity)
		elseif matType == MatString.TYPE.REQUIRED and not Profession.IsSalvage(self._state.craftString) then
			local slotId = MatString.GetSlotId(matString)
			private.optionalMatsTemp[slotId] = private.optionalMatsTemp[slotId] or MatQuantityString.GetForSingleItem(MatString.GetRequiredItem(matString, 1), quantity)
		end
	end
	wipe(private.matsTemp)
	wipe(private.qualityMatsTemp)

	self._state.recipeString = RecipeString.FromCraftString(self._state.craftString, private.optionalMatsTemp, self._state.useConcentration and 1 or nil)
	wipe(private.optionalMatsTemp)
end

function CraftDetails.__private:_GetSalvageCraftNum()
	local slotId = self._state.itemSelector:GetNextSalvageSlotId()
	if not slotId then
		return 0, 0
	end
	assert(self._state.craftString and self._state.recipeString)
	local requiredQty = Profession.GetCraftedQuantityRange(self._state.craftString)
	local craftable = floor(BagTracking.GetQuantityBySlotId(slotId) / requiredQty)
	local _, _, hasQualityMats = Profession.GetRecipeQualityInfo(self._state.craftString)
	if hasQualityMats then
		local qualityCraftable = min(craftable, Crafting.GetNumCraftableRecipeString(self._state.recipeString))
		if qualityCraftable > 0 then
			self._state.quantityInputValue = qualityCraftable
		end
		return qualityCraftable, craftable
	else
		if craftable > 0 then
			self._state.quantityInputValue = craftable
		end
		return craftable, 0
	end
end

function CraftDetails.__private:_HandleDialogRecipeStringChanged(_, recipeString)
	self._state.recipeString = recipeString
end

function CraftDetails.__private:_HandleItemClick()
	assert(self._state.craftString)
	local itemString = Profession.GetResultInfo(self._state.craftString)
	if itemString then
		UIUtils.HandleModifiedItemClick(itemString)
	end
end

function CraftDetails.__private:_UpdateClassicCraftingButton(canCraft)
	if not TradeSkill.IsClassicCrafting() or not CraftCreateButton or not self._state.craftButton then
		return
	end
	-- TODO: Clean this up
	local craftBtnBaseFrame = self._state.craftButton._frame ---@diagnostic disable-line: invisible
	CraftCreateButton:SetParent(craftBtnBaseFrame)
	CraftCreateButton:ClearAllPoints()
	CraftCreateButton:SetAllPoints(craftBtnBaseFrame)
	CraftCreateButton:SetFrameLevel(200)
	CraftCreateButton:DisableDrawLayer("BACKGROUND")
	CraftCreateButton:DisableDrawLayer("ARTWORK")
	if canCraft then
		CraftCreateButton:Enable()
	else
		CraftCreateButton:Disable()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToErrStr(craftString, neededTools, remainingCooldown, numCraftable)
	if not craftString then
		return ""
	elseif neededTools then
		return REQUIRES_LABEL.." "..neededTools
	elseif remainingCooldown then
		return format(L["On Cooldown for %s"], TimeFormat.Duration(remainingCooldown))
	elseif numCraftable == 0 then
		return L["Missing Materials"]
	else
		return ""
	end
end

function private.CraftStringToNeededTools(craftString)
	return craftString and Profession.NeededTools(craftString) or nil
end

function private.CraftStringToRankText(craftString)
	local rank = craftString and CraftString.GetRank(craftString) or -1
	local level = craftString and CraftString.GetLevel(craftString) or -1
	assert(rank <= 0 or level <= 0)
	if rank > 0 then
		local filled = TextureAtlas.GetTextureLink("iconPack.14x14/Star/Filled")
		local unfilled = TextureAtlas.GetTextureLink("iconPack.14x14/Star/Unfilled")
		assert(rank >= 1 and rank <= 3)
		return strrep(filled, rank)..strrep(unfilled, 3 - rank)
	elseif level > 0 then
		local currExp = Profession.GetCurrentExpByCraftString(craftString)
		local nextExp = Profession.GetNextExpByCraftString(craftString)
		assert(currExp and nextExp)
		return currExp >= 0 and format("%s / %s", currExp, nextExp) or L["Max"]
	else
		return ""
	end
end

function private.CraftStringToRankTextShown(craftString)
	local rank = craftString and CraftString.GetRank(craftString) or -1
	local level = craftString and CraftString.GetLevel(craftString) or -1
	return rank > 0 or level > 0
end

function private.CraftStringToMatsShown(craftString)
	if not craftString then
		return false
	end
	if Profession.IsSalvage(craftString) then
		local _, _, hasQualityMats = Profession.GetRecipeQualityInfo(craftString)
		return hasQualityMats or false
	else
		return true
	end
end

function private.CraftStringToRankDropdownShown(craftString)
	local level = craftString and CraftString.GetLevel(craftString) or -1
	return level > 0
end

function private.RecipeStringToResultTooltip(recipeString)
	if not recipeString then
		return nil
	end
	local craftString = CraftString.FromRecipeString(recipeString)
	local itemString = Profession.GetResultInfo(craftString)
	if not itemString or itemString == "" then
		if TradeSkill.IsClassicCrafting() then
			return "craft:"..(Profession.GetIndexByCraftString(craftString) or craftString)
		else
			return recipeString
		end
	end
	---@cast itemString -nil

	local level = RecipeString.GetLevel(recipeString)
	local rank = RecipeString.GetRank(recipeString)
	if not level and not rank and not RecipeString.HasOptionalMats(recipeString) then
		return itemString
	elseif not level then
		return Profession.IsEnchant(craftString) and itemString or recipeString
	else
		return recipeString
	end
end

function private.CraftStringToNameText(craftString)
	if not craftString then
		return ""
	end
	local itemString, _, name = Profession.GetResultInfo(craftString)
	local itemName = itemString and ItemInfo.GetName(itemString)
	local quality = itemString and ItemInfo.GetQuality(itemString)
	if not itemName or not quality then
		return name or ""
	end
	local _, texture = Profession.GetResultInfo(craftString)
	if texture then
		itemName = "|T"..texture..":16|t "..itemName
	end
	local lNum, hNum = Profession.GetCraftedQuantityRange(craftString)
	if lNum ~= hNum or lNum >= 2 then
		itemName = itemName.." "..Theme.GetColor("accent/main"):ColorText(lNum == hNum and format("(%d)", lNum) or format("(%d-%d)", lNum, hNum))
	end
	return Theme.GetItemQualityColor(quality):ColorText(itemName)
end

function private.CraftStringToQualityBtnText(craftString)
	if not craftString then
		return ""
	end
	local craftQuality = CraftString.GetQuality(craftString)
	local useMidnightIcon = TradeSkill.IsMidnightRecipe(CraftString.GetSpellId(craftString))
	if not craftQuality then
		return ""
	end
	return TradeSkill.GetCraftedQualityChatIcon(craftQuality, useMidnightIcon, true)..TextureAtlas.GetTextureLink("iconPack.18x18/Chevron/Down")
end

function private.CraftStringToQualityBtnShown(craftString)
	return craftString and CraftString.GetQuality(craftString) and true or false
end

function private.CraftStringToOptionsRowShown(craftString)
	if not craftString then
		return false
	end
	return private.CraftStringToQualityBtnShown(craftString) or Profession.GetNumOptionalMats(craftString, MatString.TYPE.OPTIONAL) + Profession.GetNumOptionalMats(craftString, MatString.TYPE.FINISHING) > 0
end

function private.StateToConcentrationDisabled(craftString, useConcentration)
	local quality = craftString and CraftString.GetQuality(craftString)
	if not quality then
		return true
	end
	return not useConcentration and not Profession.GetIndexByCraftString(CraftString.SetQuality(craftString, quality + 1))
end

function private.CraftStringToCraftType(craftString)
	if not craftString then
		return "NONE"
	elseif Profession.IsEnchant(craftString) then
		return (App.IsVanillaClassic() or App.IsBCClassic()) and "ENCHANT" or "ENCHANT_VELLUM"
	elseif Profession.IsSalvage(craftString) then
		return "SALVAGE"
	elseif Profession.IsTinker(craftString) then
		return "TINKER"
	elseif not Profession.GetResultInfo(craftString) then
		return "RESEARCH"
	else
		return "ITEM"
	end
end

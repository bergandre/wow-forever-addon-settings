-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = App:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = App:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = App:From("LibTSMTypes"):Include("Crafting.RecipeString")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local TradeSkill = App:From("LibTSMWoW"):Include("API.TradeSkill")
local Event = App:From("LibTSMWoW"):Include("Service.Event")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = App:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = App:From("LibTSMService"):Include("Profession")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local TooltipUI = App:From("LibTSMUI"):Include("TooltipUI")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	optionalMatTemp = {},
}
local ICON_SIZE = 12
local ICON_SPACING = 4
local DIALOG_ICON_SIZE = 32
local DIALOG_OPTION_SPACING = 10
local QUALITY_OPTION_WIDTH = 72
local TIER_SELECTOR_WIDTH = 40
local TIER_SELECTOR_HEIGHT = 16



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingMatList = UIElements.Define("CraftingMatList", "List")
CraftingMatList._STATE_SCHEMA = CraftingMatList._STATE_SCHEMA:Extend("CraftingMatListState")
	:AddOptionalStringField("dialogMatString")
	:AddNumberField("dialogTotalQuantity", 0)
	:AddNumberField("dialogQ1Quantity", 0)
	:AddNumberField("dialogQ2Quantity", 0)
	:AddNumberField("dialogQ3Quantity", 0)
	:Commit()
CraftingMatList:_AddActionScripts("OnQualityChanged")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function CraftingMatList:__init()
	self.__super:__init()
	BagTracking.RegisterQuantityCallback(self:__closure("_HandleBagUpdate"))
	WarbankTracking.RegisterQuantityCallback(self:__closure("_HandleBagUpdate"))
	Event.Register("CURRENCY_DISPLAY_UPDATE", self:__closure("_UpdateConcentration"))
	self._concentrationTimer = DelayTimer.New("CRAFTING_MAT_LIST_CONCENTRATION", self:__closure("_HandleConcentrationTimer"))
	self._recipeString = nil
	self._concentrationCurrencyId = nil
	self._itemString = {}
	self._text = {}
	self._icon = {}
	self._quantity = {}
	self._playerQuantity = {}
	self._isQualityMat = {}
	self._matString = {}
	self._matQuantityString = {}
	self._totalQuantity = {}
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function CraftingMatList:Release()
	wipe(self._itemString)
	wipe(self._text)
	wipe(self._icon)
	wipe(self._quantity)
	wipe(self._playerQuantity)
	wipe(self._isQualityMat)
	wipe(self._matString)
	wipe(self._matQuantityString)
	wipe(self._totalQuantity)
	self._concentrationTimer:Cancel()
	self._recipeString = nil
	self._concentrationCurrencyId = nil
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the recipe string to display the mats for.
---@param value? string|ReactivePublisherSchemaBase The recipe string or a publisher
---@return self
function CraftingMatList:SetRecipeString(value)
	if value == nil or type(value) == "string" then
		wipe(self._itemString)
		wipe(self._text)
		wipe(self._icon)
		wipe(self._quantity)
		wipe(self._playerQuantity)
		wipe(self._isQualityMat)
		wipe(self._matString)
		wipe(self._matQuantityString)
		wipe(self._totalQuantity)
		self._concentrationTimer:Cancel()
		self._concentrationCurrencyId = nil

		if value then
			local craftString = CraftString.FromRecipeString(value)
			assert(not next(private.optionalMatTemp))
			for _, matString, quantity in Profession.MatIterator(craftString) do
				local matType = MatString.GetType(matString)
				if matType == MatString.TYPE.NORMAL then
					self:_AddMaterial(matString, quantity, matString, "", quantity)
				elseif matType == MatString.TYPE.QUALITY then
					local matQuantityString = RecipeString.GetOptionalMat(value, MatString.GetSlotId(matString))
					assert(matQuantityString)
					for _, itemString, matQuantity in MatQuantityString.Iterator(matQuantityString) do
						self:_AddMaterial(itemString, matQuantity, matString, matQuantityString, quantity)
					end
				elseif not Profession.IsSalvage(craftString) then
					local slotId = MatString.GetSlotId(matString)
					if RecipeString.GetOptionalMat(value, slotId) then
						tinsert(private.optionalMatTemp, slotId)
						private.optionalMatTemp["_"..slotId] = matString
					end
				end
			end
			sort(private.optionalMatTemp)
			for _, slotId in ipairs(private.optionalMatTemp) do
				local matString = private.optionalMatTemp["_"..slotId]
				local matQuantityString = RecipeString.GetOptionalMat(value, slotId)
				assert(matQuantityString)
				for _, itemString, matQuantity in MatQuantityString.Iterator(matQuantityString) do
					self:_AddMaterial(itemString, matQuantity, matString, matQuantityString, matQuantity)
				end
			end
			wipe(private.optionalMatTemp)
			local cost, available, currencyId = Crafting.GetConcentrationInfo(value)
			if cost then
				self._concentrationCurrencyId = currencyId
				local text, _, icon = TradeSkill.GetConcentrationUIConstants()
				tinsert(self._itemString, "")
				tinsert(self._text, text)
				tinsert(self._icon, icon)
				tinsert(self._quantity, cost)
				tinsert(self._playerQuantity, available)
				tinsert(self._isQualityMat, false)
				tinsert(self._matString, "")
				tinsert(self._matQuantityString, "")
				tinsert(self._totalQuantity, cost)
			end
		end
		self._recipeString = value
		self:_StartConcentrationTimer()

		self:_SetNumRows(#self._itemString)
		self:Draw()
	else
		self:_MethodPublisher(value, "SetRecipeString")
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<CraftingMatListState>
---@param state CraftingMatListState
function CraftingMatList.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_SELECTED" then
		local itemString = ...
		local matString = state.dialogMatString
		local quantity = state.dialogTotalQuantity
		assert(matString and quantity)
		manager:ProcessAction("ACTION_CLOSE_DIALOG")

		assert(self._recipeString)
		assert(not next(private.optionalMatTemp))
		for _, slotId, matQuantityString in RecipeString.OptionalMatIterator(self._recipeString) do
			private.optionalMatTemp[slotId] = matQuantityString
		end
		private.optionalMatTemp[MatString.GetSlotId(matString)] = MatQuantityString.GetForSingleItem(itemString, quantity)
		local newRecipeString = RecipeString.SetOptionalMats(self._recipeString, private.optionalMatTemp)
		wipe(private.optionalMatTemp)
		self:_SendActionScript("OnQualityChanged", newRecipeString)
	elseif action == "ACTION_HANDLE_QUALITY_SELECTED" then
		local itemString = ...
		local matString = state.dialogMatString
		assert(matString)
		state.dialogQ1Quantity = MatString.GetQualityItem(matString, 1) == itemString and state.dialogTotalQuantity or 0
		state.dialogQ2Quantity = MatString.GetQualityItem(matString, 2) == itemString and state.dialogTotalQuantity or 0
		state.dialogQ3Quantity = MatString.GetNumQualities(matString) == 3 and MatString.GetQualityItem(matString, 3) == itemString and state.dialogTotalQuantity or 0
	elseif action == "ACTION_HANDLE_Q1_QUANTITY_CHANGED" then
		return manager:ProcessAction("ACTION_REBALANCE_QUANTITIES", "dialogQ2Quantity", "dialogQ3Quantity")
	elseif action == "ACTION_HANDLE_Q2_QUANTITY_CHANGED" then
		return manager:ProcessAction("ACTION_REBALANCE_QUANTITIES", "dialogQ1Quantity", "dialogQ3Quantity")
	elseif action == "ACTION_HANDLE_Q3_QUANTITY_CHANGED" then
		return manager:ProcessAction("ACTION_REBALANCE_QUANTITIES", "dialogQ1Quantity", "dialogQ2Quantity")
	elseif action == "ACTION_REBALANCE_QUANTITIES" then
		local otherKey1, otherKey2 = ...
		local numExtra = state.dialogQ1Quantity + state.dialogQ2Quantity + state.dialogQ3Quantity - state.dialogTotalQuantity
		if numExtra > 0 then
			local numExtra1 = min(state[otherKey1], numExtra)
			numExtra = numExtra - numExtra1
			local numExtra2 = min(state[otherKey2], numExtra)
			numExtra = numExtra - numExtra2
			state[otherKey1] = state[otherKey1] - numExtra1
			state[otherKey2] = state[otherKey2] - numExtra2
			assert(numExtra == 0)
		elseif numExtra < 0 then
			state[otherKey1] = state[otherKey1] - numExtra
		end
	elseif action == "ACTION_CONFIRM_QUALITIES" then
		local matString = state.dialogMatString
		assert(matString)
		assert(self._recipeString)
		assert(not next(private.optionalMatTemp))
		if state.dialogQ1Quantity > 0 then
			private.optionalMatTemp[MatString.GetQualityItem(matString, 1)] = state.dialogQ1Quantity
		end
		if state.dialogQ2Quantity > 0 then
			private.optionalMatTemp[MatString.GetQualityItem(matString, 2)] = state.dialogQ2Quantity
		end
		if state.dialogQ3Quantity > 0 then
			private.optionalMatTemp[MatString.GetQualityItem(matString, 3)] = state.dialogQ3Quantity
		end
		local dialogMatQuantityString = MatQuantityString.Get(private.optionalMatTemp)
		wipe(private.optionalMatTemp)
		for _, slotId, matQuantityString in RecipeString.OptionalMatIterator(self._recipeString) do
			private.optionalMatTemp[slotId] = matQuantityString
		end
		private.optionalMatTemp[MatString.GetSlotId(matString)] = dialogMatQuantityString
		local newRecipeString = RecipeString.SetOptionalMats(self._recipeString, private.optionalMatTemp)
		wipe(private.optionalMatTemp)
		manager:ProcessAction("ACTION_CLOSE_DIALOG")
		self:_SendActionScript("OnQualityChanged", newRecipeString)
	elseif action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

function CraftingMatList.__private:_HandleBagUpdate(itemsChanged)
	for i, itemString in ipairs(self._itemString) do
		if itemsChanged[itemString] then
			self._playerQuantity[i] = BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
			local row = self:_GetRow(i)
			if row then
				self:_HandleRowDraw(row)
			end
		end
	end
end

function CraftingMatList.__private:_UpdateConcentration()
	if not self._concentrationCurrencyId or not self._recipeString then
		return
	end
	local cost, available = Crafting.GetConcentrationInfo(self._recipeString)
	if not cost then
		return
	end
	local index = #self._itemString
	assert(self._itemString[index] == "")
	if cost == self._quantity[index] and available == self._playerQuantity[index] then
		return
	end
	self._quantity[index] = cost
	self._totalQuantity[index] = cost
	self._playerQuantity[index] = available
	local row = self:_GetRow(index)
	if row then
		self:_HandleRowDraw(row)
	end
end

function CraftingMatList.__private:_StartConcentrationTimer()
	local duration = self._concentrationCurrencyId and Currency.GetRechargeDuration(self._concentrationCurrencyId) or nil
	if duration then
		self._concentrationTimer:RunForTime(duration)
	end
end

function CraftingMatList.__private:_HandleConcentrationTimer()
	self:_UpdateConcentration()
	self:_StartConcentrationTimer()
end

function CraftingMatList.__private:_AddMaterial(itemString, quantity, matString, matQuantityString, totalQuantity)
	local matType = MatString.GetType(matString)
	local isQualityMat = matType == MatString.TYPE.QUALITY or matType == MatString.TYPE.REQUIRED
	local displayName = isQualityMat and UIUtils.GetQualityColoredText(ItemInfo.GetName(itemString), ItemInfo.GetQuality(itemString)) or UIUtils.GetDisplayItemName(itemString)
	tinsert(self._itemString, itemString)
	tinsert(self._text, displayName or Theme.GetColor("error/main"):ColorText("?"))
	tinsert(self._icon, ItemInfo.GetTexture(itemString) or ItemInfo.GetTexture(ItemString.GetUnknown()))
	tinsert(self._quantity, quantity)
	tinsert(self._playerQuantity, BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString))
	tinsert(self._isQualityMat, isQualityMat)
	tinsert(self._matString, matString)
	tinsert(self._matQuantityString, matQuantityString)
	tinsert(self._totalQuantity, totalQuantity)
end

---@param row ListRow
function CraftingMatList.__protected:_HandleRowAcquired(row)
	-- Add the tier selector
	local tierBackground = row:AddTexture("tierBackground")
	tierBackground:SetDrawLayer("ARTWORK", 0)
	tierBackground:SetSize(TIER_SELECTOR_WIDTH, TIER_SELECTOR_HEIGHT)
	tierBackground:TSMSetColorTexture("container/low")

	local tier = row:AddText("tier")
	tier:SetHeight(TIER_SELECTOR_HEIGHT)
	tier:TSMSetFont("BODY_XSMALL")
	tier:SetJustifyH("CENTER")

	local tierChevron = row:AddTexture("tierChevron")
	tierChevron:SetDrawLayer("ARTWORK", 1)
	tierChevron:TSMSetTextureAndSize("iconPack.14x14/Chevron/Down")

	-- Add the icon
	local icon = row:AddTexture("icon")
	icon:SetDrawLayer("ARTWORK", 1)
	icon:SetWidth(ICON_SIZE)
	icon:SetHeight(ICON_SIZE)

	-- Add the item text
	local item = row:AddText("item")
	item:SetHeight(self.ROW_HEIGHT)
	item:TSMSetFont("ITEM_XSMALL")
	item:SetJustifyH("LEFT")

	-- Add the quantity text
	local qty = row:AddText("qty")
	qty:SetHeight(self.ROW_HEIGHT)
	qty:TSMSetFont("TABLE_XSMALL")
	qty:SetJustifyH("RIGHT")

	-- Layout the elements
	icon:SetPoint("LEFT", Theme.GetColSpacing() / 2, 0)
	item:SetPoint("LEFT", icon, "RIGHT", ICON_SPACING, 0)
	tierBackground:SetPoint("LEFT", item, "RIGHT", ICON_SPACING * 2, 0)
	tierChevron:SetPoint("RIGHT", tierBackground, -2, 0)
	tier:SetPoint("LEFT", tierBackground, 2, 0)
	tier:SetPoint("RIGHT", tierChevron, "LEFT")
	qty:SetPoint("RIGHT", -Theme.GetColSpacing() / 2, 0)
end

---@param row ListRow
function CraftingMatList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local isQualityMat = self._isQualityMat[dataIndex]
	row:SetHighlightEnabled(isQualityMat)
	row:GetTexture("tierBackground"):SetShown(isQualityMat)
	row:GetTexture("tierChevron"):SetShown(isQualityMat)
	row:GetText("tier"):SetText(isQualityMat and private.ItemStringToTierText(self._itemString[dataIndex]) or "")
	self:_DrawRowQty(row, self._playerQuantity[dataIndex], self._quantity[dataIndex])
	self:_DrawRowItem(row, self._text[dataIndex], self._icon[dataIndex], isQualityMat)
end

---@param row ListRow
function CraftingMatList.__private:_DrawRowItem(row, text, icon, isQualityMat)
	local item = row:GetText("item")
	item:SetText(text)
	local reservedWidth = Theme.GetColSpacing() * 1.5 + ICON_SIZE + ICON_SPACING + row:GetText("qty"):GetWidth() + (isQualityMat and TIER_SELECTOR_WIDTH + ICON_SPACING * 2 or 0)
	item:SetWidth(max(min(item:GetUnboundedStringWidth(), self:_GetDimension("WIDTH") - reservedWidth), 0))
	row:GetTexture("icon"):SetTexture(icon)
end

---@param row ListRow
function CraftingMatList.__private:_DrawRowQty(row, bagQuantity, quantity)
	local qty = row:GetText("qty")
	local color = bagQuantity >= quantity and "positive/main" or "error/main"
	qty:TSMSetTextColor(color)
	qty:SetText(format("%d / %d", bagQuantity, quantity))
	-- Adjust the width of the qty text to fit the text string
	qty:SetWidth(10000)
	qty:SetWidth(qty:GetStringWidth())
end

---@param row ListRow
function CraftingMatList.__protected:_HandleRowEnter(row)
	local itemString = self._itemString[row:GetDataIndex()]
	if not itemString then
		return
	elseif itemString == "" then
		if self._concentrationCurrencyId then
			row:ShowTooltip("concentration:"..self._concentrationCurrencyId)
		end
		return
	end
	row:ShowTooltip(itemString)
end

function CraftingMatList.__protected:_HandleRowLeave(row)
	-- The data might not exist anymore, so just hide the tooltip to be safe
	TooltipUI.Hide()
end

function CraftingMatList.__protected:_HandleRowClick(row, mouseButton)
	local itemString = self._itemString[row:GetDataIndex()]
	if mouseButton ~= "LeftButton" or itemString == "" then
		return
	elseif IsShiftKeyDown() or IsControlKeyDown() then
		UIUtils.HandleModifiedItemClick(itemString)
	elseif self._isQualityMat[row:GetDataIndex()] then
		self:_ShowQualityDialog(row:GetDataIndex(), row:GetTexture("tierBackground"))
	end
end

function CraftingMatList.__private:_ShowQualityDialog(dataIndex, anchorRegion)
	local matString = self._matString[dataIndex]
	local matQuantityString = self._matQuantityString[dataIndex]
	local isQualityMat = MatString.GetType(matString) == MatString.TYPE.QUALITY
	local numOptions = 0
	if isQualityMat then
		numOptions = MatString.GetNumQualities(matString)
	else
		for _ in MatString.ItemIterator(matString) do
			numOptions = numOptions + 1
		end
	end
	self._state.dialogMatString = matString
	self._state.dialogTotalQuantity = self._totalQuantity[dataIndex]
	self._state.dialogQ1Quantity = private.GetQualityQuantity(matString, matQuantityString, 1)
	self._state.dialogQ2Quantity = private.GetQualityQuantity(matString, matQuantityString, 2)
	self._state.dialogQ3Quantity = private.GetQualityQuantity(matString, matQuantityString, 3)
	for _ in self._state:WithAutoStorePaused() do
		self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "frame")
			:SetSize(max(numOptions * ((isQualityMat and QUALITY_OPTION_WIDTH or DIALOG_ICON_SIZE) + DIALOG_OPTION_SPACING) - DIALOG_OPTION_SPACING + 18, 200), isQualityMat and 126 or 78)
			:AddAnchor("TOPLEFT", anchorRegion, "BOTTOMLEFT", 0, -4)
			:SetLayout("VERTICAL")
			:SetPadding(1)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:SetMouseEnabled(true)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 4, 0)
				:AddChild(UIElements.New("Spacer", "spacer")
					:SetWidth(28)
				)
				:AddChild(UIElements.New("Text", "title")
					:SetJustifyH("CENTER")
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(L["Reagent Quality"])
				)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetMargin(0, 4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(isQualityMat and 64 or 44)
				:SetPadding(8, 8, 4, isQualityMat and 4 or 8)
				:SetContext(matString)
				:AddChild(UIElements.New("Spacer", "spacer1"))
				:AddChildrenWithFunction(self:__closure("_AddQualityDialogOptions"), matString, isQualityMat)
				:AddChild(UIElements.New("Spacer", "spacer2"))
			)
			:AddChildIf(isQualityMat, UIElements.New("BaseFrame", "footer")
				:SetLayout("HORIZONTAL")
				:SetHeight(32)
				:SetPadding(4)
				:AddChild(UIElements.New("SmallPrimaryActionButton", "confirmBtn")
					:SetMargin(0, 4, 0, 0)
					:SetText(L["Confirm"])
					:SetAction("OnClick", "ACTION_CONFIRM_QUALITIES")
				)
				:AddChild(UIElements.New("SmallSecondaryActionButton", "cancelBtn")
					:SetText(GlobalStrings.Get("CANCEL"))
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
		)
	end
end

function CraftingMatList.__private:_AddQualityDialogOptions(frame, matString, isQualityMat)
	if not isQualityMat then
		local isFirst = true
		for itemString in MatString.ItemIterator(matString) do
			frame:AddChild(UIElements.New("ItemIconButton", "button_"..itemString)
				:SetSize(DIALOG_ICON_SIZE, DIALOG_ICON_SIZE)
				:SetMargin(isFirst and 0 or DIALOG_OPTION_SPACING, 0, 0, 0)
				:SetItem(itemString)
				:SetAction("OnClick", "ACTION_HANDLE_ITEM_SELECTED")
			)
			isFirst = false
		end
		return
	end
	local totalQuantity = self._state.dialogTotalQuantity
	for quality = 1, MatString.GetNumQualities(matString) do
		frame:AddChild(UIElements.New("BaseFrame", "q"..quality)
			:SetLayout("VERTICAL")
			:SetWidth(QUALITY_OPTION_WIDTH)
			:SetMargin(quality == 1 and 0 or DIALOG_OPTION_SPACING, 0, 0, 0)
			:AddChild(UIElements.New("ItemIconButton", "button")
				:SetSize(DIALOG_ICON_SIZE, DIALOG_ICON_SIZE)
				:SetItem(MatString.GetQualityItem(matString, quality))
				:SetAction("OnClick", "ACTION_HANDLE_QUALITY_SELECTED")
			)
			:AddChild(UIElements.New("NumberInput", "input")
				:SetHeight(20)
				:SetMargin(0, 0, 4, 0)
				:SetSubAddEnabled(true)
				:SetValidRange(0, totalQuantity)
				:MirrorValueState(self._state, "dialogQ"..quality.."Quantity")
				:SetAction("OnValueChanged", "ACTION_HANDLE_Q"..quality.."_QUANTITY_CHANGED")
			)
		)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemStringToTierText(itemString)
	local craftedQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(itemString)
	if not craftedQuality then
		return ""
	end
	return TradeSkill.GetCraftedQualityChatIcon(craftedQuality, useMidnightIcon)
end

function private.GetQualityQuantity(matString, matQuantityString, quality)
	if MatString.GetType(matString) ~= MatString.TYPE.QUALITY or quality > MatString.GetNumQualities(matString) then
		return 0
	end
	return MatQuantityString.GetQuantity(matQuantityString, MatString.GetQualityItem(matString, quality))
end

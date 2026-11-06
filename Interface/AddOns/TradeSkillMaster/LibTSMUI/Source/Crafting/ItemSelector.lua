-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local UIElements = LibTSMUI:Include("UIElements")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.RecipeString")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMUI:From("LibTSMWoW"):Include("API.Container")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.WarbankTracking")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local private = {
	itemsTemp = {},
}
local CORNER_RADIUS = 6
local COMPACT_CORNER_RADIUS = 3
local DIALOG_WIDTH = 150
local DIALOG_ICON_SIZE = 30
local DIALOG_ICON_SPACING = 4
local DIALOG_ROW_SPACING = 3
local DIALOG_NUM_COLUMNS = 3
local DIALOG_MAX_ROWS = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local ItemSelector = ComponentRegistry.Define("ItemSelector", "BaseButton")
ItemSelector._STATE_SCHEMA = ItemSelector._STATE_SCHEMA:Extend("ItemSelectorState")
	:AddDeferredUIElementField("dialog", "BaseFrame")
	:AddDeferredUIElementField("dialogItems", "BaseFrame")
	:AddBooleanField("disabled", false)
	:AddBooleanField("mouseOver", false)
	:AddBooleanField("compact", false)
	:AddBooleanField("hideUnowned", false)
	:AddOptionalStringField("selection")
	:Commit()
ItemSelector:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ItemSelector:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_ENTER")
		:SuppressActionLog("ACTION_HANDLE_LEAVE")

	self._items = {}
	self._matString = nil
	self._optionalMatString = nil
	self._optionalMatType = nil
	self._optionalMatIndex = nil
	self._selectionSlotId = nil
	self._requiredQty = nil

	local selectionPublisher = self._state:Publisher("selection")
		:Share()
	local compactPublisher = self._state:Publisher("compact")
		:Share()

	self._frame:TSMSetScript("OnMouseUp", self._childManager:CallbackToProcessAction("ACTION_HANDLE_MOUSE_UP"))
	self._frame:TSMHookScript("OnEnter", self._childManager:CallbackToProcessAction("ACTION_HANDLE_ENTER"))
	self._frame:TSMHookScript("OnLeave", self._childManager:CallbackToProcessAction("ACTION_HANDLE_LEAVE"))

	self._background = self:_CreateRectangle()
	self._background:SetCornerRadius(compactPublisher:ReplaceBooleanWith(COMPACT_CORNER_RADIUS, CORNER_RADIUS))
	self._background:SubscribeColor(self._state:Publisher([[(disabled and "outline/variant") or (not mouseOver and "on/surface/low") or "on/surface/low+HOVER"]]))
	self._background:SetShown(selectionPublisher:ToBooleanEquals(nil))
	self._backgroundOverlay = self:_CreateRectangle(1)
	self._backgroundOverlay:SetCornerRadius(compactPublisher:ReplaceBooleanWith(COMPACT_CORNER_RADIUS - 1, CORNER_RADIUS))
	self._backgroundOverlay:SetInset(compactPublisher:ReplaceBooleanWith(1, 2))
	self._backgroundOverlay:SetShown(selectionPublisher:ToBooleanEquals(nil))

	self._quality = self:_CreateFontString()
	self._quality:SetSize(32, 32)
	self._quality:TSMSetFont("BODY_BODY1")
	self._quality:SetPoint("TOPLEFT", -2, 10)
	self._quality:SetJustifyH("LEFT")
	self._quality:TSMSetText(selectionPublisher:Map(private.SelectionToQualityText):IgnoreDuplicates())
	self._quality:TSMSetShown(compactPublisher:InvertBoolean())

	self._quantity = self:_CreateFontString()
	self._quantity:SetHeight(16)
	self._quantity:TSMSetFont("TABLE_TABLE1_OUTLINE")
	self._quantity:SetPoint("BOTTOMLEFT", 1, 1)
	self._quantity:SetPoint("BOTTOMRIGHT", -1, 1)
	self._quantity:SetJustifyH("RIGHT")
	self._quantity:TSMSetShown(compactPublisher:InvertBoolean())

	self._addIcon = self:_CreateTexture(nil, "ARTWORK")
	self._addIcon:TSMSetTextureAndSize(compactPublisher:ReplaceBooleanWith("iconPack.12x12/Add/Default", "iconPack.14x14/Add/Default"))
	self._addIcon:TSMSetShown(selectionPublisher:ToBooleanEquals(nil))
	compactPublisher:CallFunction(self:__closure("_UpdateAddIconPosition"))

	selectionPublisher:CallMethod(self, "SetTooltip")
	selectionPublisher:CallMethod(self, "SetBackgroundWithItemHighlight")

	selectionPublisher:EndShare()
	compactPublisher:EndShare()
end

function ItemSelector:Acquire()
	self.__super:Acquire()
	self._backgroundOverlay:SetColor("container/lowest")
	self:EnableRightClick()
end

function ItemSelector:Release()
	self.__super:Release()

	wipe(self._items)
	self._matString = nil
	self._optionalMatString = nil
	self._optionalMatType = nil
	self._optionalMatIndex = nil
	self._selectionSlotId = nil
	self._requiredQty = nil
end

---Sets the selectable items that can be picked.
---@param items string[] The indexed table that contains the possible selections
---@return self
function ItemSelector:SetItems(items)
	wipe(self._items)
	self:SetDisabled(not next(items))
	for _, itemString in ipairs(items) do
		tinsert(self._items, itemString)
	end
	return self
end

---Sets the list of items from a mat string.
---@param matString? string The mat string
---@param requiredQty? number The required stack size for this mat
---@return self
function ItemSelector:SetMatString(matString, requiredQty)
	wipe(self._items)
	self._matString = matString
	self._requiredQty = requiredQty
	if matString then
		for itemString in MatString.ItemIterator(matString) do
			if not requiredQty or private.GetBagSlotId(itemString, requiredQty) then
				tinsert(self._items, itemString)
			end
		end
	end
	self:SetDisabled(not next(self._items))
	self:SetSelection(self._state.selection, true)
	return self
end

---Sets optional mat info ahead of calling :SetOptionalMatRecipeString().
---@param matType EnumValue The optional mat type
---@param index number The optional mat index
---@return self
function ItemSelector:SetOptionalMatInfo(matType, index)
	self._optionalMatType = matType
	self._optionalMatIndex = index
	return self
end

---Sets the recipe string for showing an optional material.
---@param value string|ReactivePublisherSchemaBase The recipe string or a publisher
---@return self
function ItemSelector:SetOptionalMatRecipeString(value)
	if type(value) == "string" then
		assert(self._optionalMatType and self._optionalMatIndex)
		local index = self._optionalMatIndex
		local craftString = CraftString.FromRecipeString(value)
		local matString = nil
		for _, craftMatString in Profession.MatIterator(craftString) do
			if MatString.GetType(craftMatString) == self._optionalMatType then
				index = index - 1
				if index == 0 then
					matString = craftMatString
				end
			end
		end
		self._optionalMatString = matString
		self:SetMatString(matString)
		local matQuantityString = matString and RecipeString.GetOptionalMat(value, MatString.GetSlotId(matString)) or nil
		local itemString = nil
		if matQuantityString then
			for _, matItemString, quantity in MatQuantityString.Iterator(matQuantityString) do
				assert(quantity == 1 and not itemString)
				itemString = matItemString
			end
		end
		self:SetSelection(itemString)
		local slotText = matString and Profession.GetMatSlotText(craftString, matString) or ""
		self:SetTooltip(itemString or slotText ~= "" and slotText or nil)
	else
		self:_MethodPublisher(value, "SetOptionalMatRecipeString")
	end
	return self
end

---Get the next targetable salvage slot id
---@return number?
function ItemSelector:GetNextSalvageSlotId()
	if not self._state.selection then
		return nil
	end
	return self:IsSelectionSlotValid() and self._selectionSlotId or private.GetBagSlotId(self._state.selection, self._requiredQty)
end

---Sets the current selection of the ItemSelector.
---@param selection? string The item to select or nil to clear the selection
---@return self
function ItemSelector:SetSelection(selection, silent)
	self._state.selection = selection
	local slotId = self:IsSelectionSlotValid() and self._selectionSlotId or private.GetBagSlotId(self._state.selection, self._requiredQty)
	self._selectionSlotId = slotId
	local quantity = slotId and BagTracking.GetQuantityBySlotId(slotId) or 0
	self._quantity:SetText(quantity > 0 and tostring(quantity) or "")
	if not silent then
		self:_SendActionScript("OnSelectionChanged", selection, self._matString)
	end
	return self
end

---Sets whether or not the item selector uses the compact style for small slots.
---@param compact boolean Whether or not to use the compact style
---@return self
function ItemSelector:SetCompact(compact)
	self._state.compact = compact
	return self
end

---Set whether or not the item selector is disabled.
---@param disabled boolean Whether or not the item selector should be disabled
---@return self
function ItemSelector:SetDisabled(disabled)
	self._state.disabled = disabled and true or false
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<ItemSelectorState>
---@param state ItemSelectorState
function ItemSelector.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_MOUSE_UP" then
		local _, mouseButton = ...
		if not self._state.acquired or state.disabled or state.dialog then
			return
		end
		if mouseButton == "RightButton" then
			self:SetSelection(nil)
			TooltipUI.Hide()
		else
			self:_ShowDialog()
		end
	elseif action == "ACTION_HANDLE_ENTER" then
		state.mouseOver = true
	elseif action == "ACTION_HANDLE_LEAVE" then
		state.mouseOver = false
	elseif action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_SET_SELECTION" then
		local itemString = ...
		self:SetSelection(itemString)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	elseif action == "ACTION_UPDATE_DIALOG_ITEMS" then
		state.dialogItems
			:ReleaseAllChildren()
			:AddChildrenWithFunction(self:__closure("_CreateItems"))
		state.dialog:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

function ItemSelector.__private:_ShowDialog()
	self._state.hideUnowned = false
	local mockItemSelector = UIElements.New("ItemSelector", "selector")
		:AddAnchor("TOPLEFT", self)
		:AddAnchor("BOTTOMRIGHT", self)
		:SetCompact(self._state.compact)
	if self._matString then
		mockItemSelector:SetMatString(self._matString, self._requiredQty)
	elseif self._optionalMatString then
		mockItemSelector:SetMatString(self._optionalMatString)
	end
	local numRows = min(max(ceil(#self._items / DIALOG_NUM_COLUMNS), 1), DIALOG_MAX_ROWS)
	local itemsHeight = numRows * (DIALOG_ICON_SIZE + DIALOG_ROW_SPACING) - DIALOG_ROW_SPACING + 8
	local itemsWidth = DIALOG_NUM_COLUMNS * (DIALOG_ICON_SIZE + DIALOG_ICON_SPACING) - DIALOG_ICON_SPACING
	local isOptionalMat = self._optionalMatType ~= nil
	local title = UIElements.New("Text", "title")
		:SetJustifyH("CENTER")
		:SetFont("BODY_BODY1_EXTRABOLD")
		:SetText(private.OptionalMatTypeToTitle(self._optionalMatType))
	local width = max(DIALOG_WIDTH, ceil(title:GetStringWidth()) + 60)
	for _ in self._state:WithAutoStorePaused() do
		self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "frame")
			:SetSize(width, itemsHeight + (isOptionalMat and 62 or 34))
			:SetLayout("VERTICAL")
			:SetPadding(1)
			:AddAnchor("BOTTOMLEFT", self._frame, "TOPLEFT", 0, 4)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:SetMouseEnabled(true)
			:BindElement(self._state, "dialog")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 4, 0)
				:AddChild(UIElements.New("Spacer", "spacer")
					:SetWidth(28)
				)
				:AddChild(title)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetMargin(0, 4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("BaseScrollFrame", "scroll")
				:SetHeight(itemsHeight)
				:SetPadding((width - 2 - itemsWidth) / 2, 0, 4, 4)
				:AddChild(UIElements.New("BaseFrame", "items")
					:SetLayout("VERTICAL")
					:SetWidth(itemsWidth)
					:BindElement(self._state, "dialogItems")
					:AddChildrenWithFunction(self:__closure("_CreateItems"))
				)
			)
			:AddChildIf(isOptionalMat, UIElements.New("BaseFrame", "footer")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:SetPadding(8, 8, 4, 4)
				:AddChild(UIElements.New("Checkbox", "hideUnowned")
					:SetWidth("AUTO")
					:SetText(L["Hide Unowned"])
					:MirrorIsCheckedState(self._state, "hideUnowned")
					:SetAction("OnValueChanged", "ACTION_UPDATE_DIALOG_ITEMS")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChildNoLayout(mockItemSelector
				:SetSelection(self._state.selection)
				:SetDisabled(true)
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
	end
end

function ItemSelector.__private:_CreateItems(frame)
	assert(not next(private.itemsTemp))
	for _, itemString in ipairs(self._items) do
		if not self._state.hideUnowned or private.IsOwned(itemString) then
			tinsert(private.itemsTemp, itemString)
		end
	end
	for rowIndex = 1, ceil(#private.itemsTemp / DIALOG_NUM_COLUMNS) do
		local row = UIElements.New("BaseFrame", "row"..rowIndex)
			:SetLayout("HORIZONTAL")
			:SetHeight(DIALOG_ICON_SIZE)
			:SetMargin(0, 0, rowIndex == 1 and 0 or DIALOG_ROW_SPACING, 0)
		for column = 1, DIALOG_NUM_COLUMNS do
			local itemString = private.itemsTemp[(rowIndex - 1) * DIALOG_NUM_COLUMNS + column]
			if itemString then
				local craftQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(itemString)
				row:AddChild(UIElements.New("BaseFrame", "item"..column)
					:SetSize(DIALOG_ICON_SIZE, DIALOG_ICON_SIZE)
					:SetMargin(column == 1 and 0 or DIALOG_ICON_SPACING, 0, 0, 0)
					:AddChildNoLayout(UIElements.New("ItemSelectorButton", "icon")
						:AddAnchor("TOPLEFT")
						:AddAnchor("BOTTOMRIGHT")
						:SetItemString(itemString)
						:SetAction("OnClick", "ACTION_SET_SELECTION")
					)
					:AddChildNoLayout(UIElements.New("Text", "quality")
						:SetSize(DIALOG_ICON_SIZE, DIALOG_ICON_SIZE)
						:AddAnchor("TOPLEFT", -2, 8)
						:SetShown(craftQuality and true or false)
						:SetText(craftQuality and TradeSkill.GetCraftedQualityChatIcon(craftQuality, useMidnightIcon) or "")
					)
				)
			end
		end
		row:AddChild(UIElements.New("Spacer", "spacer"))
		frame:AddChild(row)
	end
	local numRows = ceil(#private.itemsTemp / DIALOG_NUM_COLUMNS)
	frame:SetHeight(max(numRows * (DIALOG_ICON_SIZE + DIALOG_ROW_SPACING) - DIALOG_ROW_SPACING, DIALOG_ICON_SIZE))
	wipe(private.itemsTemp)
end

function ItemSelector.__private:_UpdateAddIconPosition(compact)
	self._addIcon:ClearAllPoints()
	if compact then
		self._addIcon:SetPoint("CENTER")
	else
		self._addIcon:SetPoint("BOTTOMRIGHT", -2, 2)
	end
end

function ItemSelector.__private:IsSelectionSlotValid()
	if not self._state.selection or not self._selectionSlotId then
		return false
	end
	local itemId = Container.GetItemId(self._selectionSlotId)
	if not itemId or self._state.selection ~= ItemString.Get(itemId) then
		return false
	end
	local selectionQuantity = BagTracking.GetQuantityBySlotId(self._selectionSlotId)
	return TradeSkill.IsValidMatSlotId(self._selectionSlotId) and self._requiredQty and selectionQuantity and selectionQuantity >= self._requiredQty
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SelectionToQualityText(selection)
	if not selection then
		return ""
	end
	local itemQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(selection)
	if not itemQuality then
		return ""
	end
	return TradeSkill.GetCraftedQualityChatIcon(itemQuality, useMidnightIcon)
end

function private.OptionalMatTypeToTitle(optionalMatType)
	if optionalMatType == MatString.TYPE.OPTIONAL then
		return L["Optional"]
	elseif optionalMatType == MatString.TYPE.FINISHING then
		return L["Finishing"]
	else
		return L["Select Item"]
	end
end

function private.IsOwned(itemString)
	return BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString) > 0
end

function private.GetBagSlotId(itemString, requiredQuantity)
	if not itemString or not requiredQuantity then
		return nil
	end
	return BagTracking.CreateQueryBagsBank()
		:AutoRelease()
		:GreaterThanOrEqual("quantity", requiredQuantity)
		:Equal("itemString", itemString)
		:OrderBy("quantity", false)
		:GetFirstResult("slotId") --[[@as number?]]
end

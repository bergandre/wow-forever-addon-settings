-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Util = App:Include("VendoringUI.Util")
local Container = App:From("LibTSMWoW"):Include("API.Container")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Vendor = App:From("LibTSMService"):Include("Vendor")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorQuantityDialog = UIElements.Define("VendorQuantityDialog", "BaseFrame")
VendorQuantityDialog._STATE_SCHEMA = VendorQuantityDialog._STATE_SCHEMA:Extend("VendorQuantityDialogState")
	:AddDeferredUIElementField("quantityInput", "NumberInput")
	:AddDeferredUIElementField("costFrame", "BaseFrame")
	:AddDeferredUIElementField("purchaseButton", "ActionButton")
	:AddNumberField("quantity", 1)
	:AddNumberField("maxCanAfford", 0)
	:AddDeferredNumberField("index")
	:AddDeferredStringField("itemString")
	:AddOptionalStringField("firstCostItem")
	:AddBooleanField("quantityInputValid", true)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorQuantityDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function VendorQuantityDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetSize(328, 204)
		:SetPadding(12)
		:AddAnchor("CENTER")
		:SetMouseEnabled(true)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
	for _ in self._state:WithAutoStorePaused() do
		local itemStringPublisher = self._state:Publisher("itemString")
			:Share()
		self
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, -4, 10)
				:SetManager(self._childManager)
				:AddChild(UIElements.New("Spacer", "spacer")
					:SetWidth(20)
				)
				:AddChild(UIElements.New("Text", "title")
					:SetJustifyH("CENTER")
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(L["Purchase Item"])
				)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetMargin(0, -4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 0, 8)
				:SetRoundedBackgroundColor("container/low")
				:AddChild(UIElements.New("BaseFrame", "item")
					:SetLayout("HORIZONTAL")
					:SetPadding(6)
					:SetMargin(0, 0, 0, 16)
					:SetRoundedBackgroundColor("container/medium")
					:AddChild(UIElements.New("BaseButton", "icon")
						:SetSize(36, 36)
						:SetMargin(0, 8, 0, 0)
						:SetBackground(itemStringPublisher:IgnoreNil():Map(ItemInfo.GetTexture))
						:SetTooltip(itemStringPublisher)
					)
					:AddChild(UIElements.New("Text", "name")
						:SetHeight(36)
						:SetFont("ITEM_BODY1")
						:SetText(itemStringPublisher:MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil("?"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "qty")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, 0, 8)
					:SetManager(self._childManager)
					:AddChild(UIElements.New("Text", "text")
						:SetWidth("AUTO")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Quantity"]..":")
					)
					:AddChild(UIElements.New("NumberInput", "input")
						:SetMargin(8, 8, 0, 0)
						:SetSubAddEnabled(true)
						:SetValidRange(1, 99999)
						:SetValue(1)
						:BindElement(self._state, "quantityInput")
						:BindIsValid(self._state, "quantityInputValid")
						:SetAction("OnValueChanged", "ACTION_UPDATE_QUANTITY")
						:SetAction("OnEnterPressed", "ACTION_CLICK_PURCHASE")
					)
					:AddChild(UIElements.New("SmallPrimaryActionButton", "max")
						:SetWidth("AUTO")
						:SetPadding(16, 16, 0, 0)
						:SetText(L["Max"])
						:SetAction("OnClick", "ACTION_SET_MAX_QUANTITY")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "cost")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:BindElement(self._state, "costFrame")
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Current Price"]..":")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("BaseButton", "text")
						:SetWidth("AUTO")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(self._state:PublisherForFunctionWithKeys(private.StateToCostText, "index", "quantity"))
						:SetTooltip(self._state:Publisher("firstCostItem"))
					)
				)
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "purchaseBtn")
				:BindElement(self._state, "purchaseButton")
				:SetManager(self._childManager)
				:SetText(L["Purchase"])
				:SetDisabled(self._state:Publisher([[not quantityInputValid or quantity > maxCanAfford]]))
				:SetAction("OnClick", "ACTION_PURCHASE")
			)
			:AddCancellable(itemStringPublisher:EndShare())
	end

	self._state:Publisher("index")
		:IgnoreNil()
		:Map(Vendor.GetNumCanAfford)
		:AssignToTableKey(self._state, "maxCanAfford")
end

---Configures the vendor item to be displayed.
---@param index number The vendor buy index
---@param itemString string The item string
---@param firstCostItem? string The first cost item
---@return self
function VendorQuantityDialog:Configure(index, itemString, firstCostItem)
	assert(not self._state.index and not self._state.itemString)
	self._state.index = index
	self._state.itemString = itemString
	self._state.firstCostItem = firstCostItem
	return self
end

---Sets whether or not the quantity input is focused.
---@param focused boolean Whether or not the quantity input is focused
---@return self
function VendorQuantityDialog:SetQuantityInputFocused(focused)
	self._state.quantityInput:SetFocused(focused)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<VendorQuantityDialogState>
---@param state VendorQuantityDialogState
function VendorQuantityDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_UPDATE_QUANTITY" then
		state.quantity = state.quantityInput:GetValue()
		state.costFrame:Draw()
	elseif action == "ACTION_CLICK_PURCHASE" then
		state.purchaseButton:Click()
	elseif action == "ACTION_SET_MAX_QUANTITY" then
		local value = max(1, min(Vendor.GetNumCanAfford(state.index), (ItemInfo.GetMaxStack(state.itemString) or 1) * Container.GetTotalFreeBagSlots()))
		state.quantityInput
			:SetValue(value)
			:Draw()
		state.quantity = value
		state.costFrame:Draw()
	elseif action == "ACTION_PURCHASE" then
		Vendor.BuyIndex(state.index, state.quantity)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToCostText(index, quantity)
	if not index then
		return ""
	end
	return Util.GetAltCostText(index, quantity)
end

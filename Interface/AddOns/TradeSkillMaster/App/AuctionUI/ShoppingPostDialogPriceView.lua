-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local AuctionHouseUIUtils = App:From("LibTSMUI"):Include("AuctionHouse.AuctionHouseUIUtils")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AH_HAS_STACKS = App.IsVanillaClassic() or App.IsBCClassic()



-- ============================================================================
-- Element Definition
-- ============================================================================

local ShoppingPostDialogPriceView = UIElements.Define("ShoppingPostDialogPriceView", "BaseFrame")
ShoppingPostDialogPriceView._STATE_SCHEMA = ShoppingPostDialogPriceView._STATE_SCHEMA:Extend("ShoppingPostDialogPriceViewState")
	:AddDeferredUIElementField("priceFields", "PostingPriceFields")
	:AddDeferredUIElementField("numStacksInput", "NumberInput")
	:AddDeferredUIElementField("stackSizeInput", "NumberInput")
	:AddDeferredUIElementField("durationToggle", "AuctionDurationToggle")
	:AddDeferredStringField("itemString")
	:AddBooleanField("priceIsValid", true)
	:AddBooleanField("stackSizeIsValid", true)
	:AddDeferredNumberField("stackSize")
	:AddDeferredNumberField("numStacks")
	:AddDeferredNumberField("duration")
	:AddOptionalNumberField("depositCost")
	:AddBooleanField("noMoney", false)
	:AddNumberField("bagQuantity", 0)
	:AddNumberField("baseItemBagQuantity", 0)
	:AddNumberField("undercut", 0)
	:AddNumberField("maxPostStack", 0)
	:AddNumberField("maxItemStack", 0)
	:Commit()
ShoppingPostDialogPriceView:_AddActionScripts("OnItemEditClicked", "OnPostClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingPostDialogPriceView:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._originalPrices = {
		bid = nil,
		buyout = nil,
	}
	self._bagQuery = nil
	self._baseItemBagQuery = nil
end

function ShoppingPostDialogPriceView:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
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
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetJustifyH("CENTER")
					:SetText(L["Post from Shopping Scan"])
				)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetMargin(0, -4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "item")
				:SetLayout("HORIZONTAL")
				:SetPadding(6)
				:SetMargin(0, 0, 0, 16)
				:SetManager(self._childManager)
				:SetBackgroundColor("container/low")
				:AddChild(UIElements.New("BaseButton", "icon")
					:SetSize(36, 36)
					:SetMargin(0, 8, 0, 0)
					:SetBackground(itemStringPublisher:MapNonNil(ItemInfo.GetTexture))
					:SetTooltip(itemStringPublisher)
				)
				:AddChild(UIElements.New("Text", "name")
					:SetHeight(36)
					:SetFont("ITEM_BODY1")
					:SetText(itemStringPublisher:MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil(""))
				)
				:AddChild(UIElements.New("BaseButton", "editBtn")
					:SetMargin(8, 0, 0, 0)
					:SetBackgroundAndSize("iconPack.18x18/Edit")
					:SetAction("OnClick", "ACTION_ITEM_EDIT_CLICKED")
				)
			)
			:AddChildIf(AH_HAS_STACKS, UIElements.New("BaseFrame", "numStacks")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:SetManager(self._childManager)
				:AddChild(UIElements.New("Text", "desc")
					:SetFont("BODY_SMALL")
					:SetText(AUCTION_NUM_STACKS..":")
				)
				:AddChild(UIElements.New("NumberInput", "input")
					:SetWidth(62)
					:SetMargin(0, 8, 0, 0)
					:SetJustifyH("RIGHT")
					:SetValidRange(0, 5000)
					:SetValue(self._state:Publisher("numStacks"):IgnoreNil())
					:BindValue(self._state, "numStacks")
					:BindElement(self._state, "numStacksInput")
				)
				:AddChild(UIElements.New("SmallPrimaryActionButton", "maxBtn")
					:SetWidth(48)
					:SetText(L["Max"])
					:SetAction("OnClick", "ACTION_MAX_NUM_STACKS")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "stackSize")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:SetManager(self._childManager)
				:AddChild(UIElements.New("Text", "desc")
					:SetFont("BODY_SMALL")
					:SetText((AH_HAS_STACKS and AUCTION_STACK_SIZE or AUCTION_HOUSE_QUANTITY_LABEL)..":")
				)
				:AddChild(UIElements.New("NumberInput", "input")
					:SetWidth(62)
					:SetMargin(0, 8, 0, 0)
					:SetJustifyH("RIGHT")
					:SetValidRange(0, 5000)
					:SetValue(self._state:Publisher("stackSize"):IgnoreNil())
					:SetAction("OnValueChanged", "ACTION_STACK_SIZE_VALUE_CHANGED")
					:BindValue(self._state, "stackSize")
					:BindElement(self._state, "stackSizeInput")
				)
				:AddChild(UIElements.New("SmallPrimaryActionButton", "maxBtn")
					:SetWidth(48)
					:SetText(L["Max"])
					:SetAction("OnClick", "ACTION_MAX_STACK_SIZE")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "duration")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 8)
				:SetManager(self._childManager)
				:AddChild(UIElements.New("Text", "desc")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(L["Duration"]..":")
				)
				:AddChild(UIElements.New("AuctionDurationToggle", "toggle")
					:SetMargin(0, 48, 0, 0)
					:BindElement(self._state, "durationToggle")
					:SetAction("OnValueChanged", "ACTION_DURATION_CHANGED")
				)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("PostingPriceFields", "price")
				:SetManager(self._childManager)
				:BindElement(self._state, "priceFields")
				:SetAction("IsValidChanged", "ACTION_PRICE_IS_VALID_CHANGED")
				:SetAction("OnPriceChanged", "ACTION_PRICE_CHANGED")
			)
			:AddChild(UIElements.New("BaseFrame", "deposit")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 15)
				:AddChild(UIElements.New("Text", "desc")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Deposit Cost"]..":")
				)
				:AddChild(UIElements.New("Text", "text")
					:SetFont("BODY_SMALL")
					:SetJustifyH("RIGHT")
					:SetText(self._state:Publisher([[priceIsValid and stackSizeIsValid and depositCost or 0]]):Map(Money.ToStringForUI))
				)
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "confirmBtn")
				:SetManager(self._childManager)
				:SetText(self._state:Publisher("noMoney"):ReplaceBooleanWith(L["Not Enough Money"], L["Post Auction"]))
				:SetDisabled(self._state:Publisher([[not priceIsValid or not stackSizeIsValid or not depositCost or noMoney]]))
				:SetAction("OnClick", "ACTION_POST_AUCTION")
			)
			:AddCancellable(itemStringPublisher:EndShare())
	end

	self._state:Publisher("depositCost")
		:CoalesceNil(0)
		:ToBooleanLessThanOrEquals(Currency.GetMoney())
		:InvertBoolean()
		:AssignToTableKey(self._state, "noMoney")

	self._state:Publisher([[stackSize and numStacks and (stackSize * numStacks) <= bagQuantity or false]])
		:AssignToTableKey(self._state, "stackSizeIsValid")

	if AH_HAS_STACKS then
		self._state:Publisher("itemString")
			:IgnoreNil()
			:Map(ItemInfo.GetMaxStack)
			:AssignToTableKey(self._state, "maxItemStack")
		self._state:Publisher([[min(baseItemBagQuantity, maxItemStack)]])
			:AssignToTableKey(self._state, "maxPostStack")
	else
		self._state:Publisher([[min(bagQuantity, 5000)]])
			:AssignToTableKey(self._state, "maxPostStack")
	end

	self._state:Publisher([[stackSize and min(stackSize, maxPostStack) or nil]])
		:IgnoreNil()
		:AssignToTableKey(self._state, "stackSize")

	self._state:Publisher("stackSize")
		:IgnoreNil()
		:CallMethod(self._state.priceFields, "SetStackSize")
end

function ShoppingPostDialogPriceView:Release()
	self.__super:Release()
	wipe(self._originalPrices)
	if self._bagQuery then
		self._bagQuery:Release()
		self._bagQuery = nil
	end
	if self._baseItemBagQuery then
		self._baseItemBagQuery:Release()
		self._baseItemBagQuery = nil
	end
end

---Sets the auction being edited.
---@param itemString string The item string
---@param duration number The auction duration
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param stackSize number The stack size being posted
---@param undercut number The amount to undercut by
---@return self
function ShoppingPostDialogPriceView:SetAuction(itemString, duration, bid, buyout, stackSize, undercut)
	assert(not self._bagQuery and not self._baseItemBagQuery)
	self._bagQuery = BagTracking.CreateQueryBagsItemAuctionable(itemString)
	self:AddCancellable(self._bagQuery:Publisher()
		:Map("Sum()", "quantity")
		:AssignToTableKey(self._state, "bagQuantity")
	)
	self._baseItemBagQuery = BagTracking.CreateQueryBagsItemAuctionable(ItemString.GetBaseFast(itemString))
	self:AddCancellable(self._baseItemBagQuery:Publisher()
		:Map("Sum()", "quantity")
		:AssignToTableKey(self._state, "baseItemBagQuantity")
	)
	self._state.itemString = itemString
	self._state.numStacks = 1
	self._state.stackSize = stackSize
	self._state.duration = duration
	self._state.undercut = undercut
	self._originalPrices.bid = bid
	self._originalPrices.buyout = buyout
	self._state.priceFields:SetAuction(itemString, bid, buyout, self._state.stackSize)
	self._state.durationToggle:SetValue(duration)
	self._state.stackSizeInput
		:SetValidRange(0, self._state.maxPostStack)
		:Draw()
	if AH_HAS_STACKS then
		self._state.numStacksInput:Draw()
	end

	self:_UpdateDepositCost(self._state)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state ShoppingPostDialogPriceViewState
function ShoppingPostDialogPriceView.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_DURATION_CHANGED" then
		state.duration = state.durationToggle:GetValue()
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_PRICE_IS_VALID_CHANGED" then
		state.priceIsValid = ...
	elseif action == "ACTION_PRICE_CHANGED" then
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_STACK_SIZE_VALUE_CHANGED" then
		self:_UpdateDepositCost(state)
		local _, _, perItem = state.priceFields:GetPrices()
		if perItem then
			return
		end
		local bid = self._originalPrices.bid * state.stackSize - state.undercut
		local buyout = self._originalPrices.buyout * state.stackSize - state.undercut
		state.priceFields:SetAuction(state.itemString, bid, buyout, state.stackSize)
	elseif action == "ACTION_MAX_NUM_STACKS" then
		local maxNumStacks = min(floor(state.bagQuantity / state.stackSize), 5000)
		state.numStacks = maxNumStacks
		state.numStacksInput
			:SetFocused(false)
			:Draw()
		state.stackSizeInput
			:SetFocused(false)
			:Draw()
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_MAX_STACK_SIZE" then
		state.stackSize = state.maxPostStack
		if AH_HAS_STACKS then
			local maxNumStacks = min(floor(state.bagQuantity / state.stackSize), 5000)
			state.numStacks = min(state.numStacks, maxNumStacks)
			state.numStacksInput
				:SetFocused(false)
				:Draw()
		end
		state.stackSizeInput
			:SetFocused(false)
			:Draw()
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_ITEM_EDIT_CLICKED" then
		self:_SendActionScript("OnItemEditClicked")
	elseif action == "ACTION_POST_AUCTION" then
		local bid, buyout, perItem = state.priceFields:GetPrices()
		if perItem and AH_HAS_STACKS then
			bid = bid * state.stackSize
			buyout = buyout * state.stackSize
		end
		self:_SendActionScript("OnPostClicked", state.itemString, state.duration, state.stackSize, state.numStacks, bid, buyout)
	else
		error("Unknown action: "..tostring(action))
	end
end

function ShoppingPostDialogPriceView.__private:_UpdateDepositCost(state)
	if not state.itemString or not state.priceIsValid or not state.stackSizeIsValid then
		return
	end
	local bid, buyout, perItem = state.priceFields:GetPrices()
	if perItem then
		bid = bid * state.stackSize
		buyout = buyout * state.stackSize
	end
	state.depositCost = AuctionHouseUIUtils.CalculateDeposit(state.itemString, false, state.duration, state.stackSize, bid, buyout)
end

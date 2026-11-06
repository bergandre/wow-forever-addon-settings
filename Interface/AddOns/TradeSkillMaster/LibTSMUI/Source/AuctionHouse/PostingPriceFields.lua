-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local AuctionHouseUIUtils = LibTSMUI:Include("AuctionHouse.AuctionHouseUIUtils")
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local PostingPriceFields = ComponentRegistry.Define("PostingPriceFields", "BaseFrame")
PostingPriceFields._STATE_SCHEMA = PostingPriceFields._STATE_SCHEMA:Extend("PostingPriceFieldsState")
	:AddDeferredUIElementField("bidInput", "Input")
	:AddDeferredUIElementField("buyoutInput", "Input")
	:AddBooleanField("perItem", true)
	:AddBooleanField("isCommodity", false)
	:AddBooleanField("bidIsValid", true)
	:AddBooleanField("buyoutIsValid", true)
	:AddDeferredNumberField("bidValue")
	:AddDeferredNumberField("buyoutValue")
	:AddDeferredNumberField("stackSize")
	:Commit()
PostingPriceFields:_AddActionScripts("IsValidChanged", "OnPriceChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PostingPriceFields:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))

	self._state:Publisher([[bidIsValid and buyoutIsValid and buyoutValue and bidValue and (buyoutValue == 0 or bidValue <= buyoutValue)]])
		:CallFunction(self:_CallbackToSendActionScript("IsValidChanged"))

	self._state:PublisherForKeys("bidValue", "buyoutValue", "perItem")
		:IgnoreIfEquals(nil, "bidValue")
		:IgnoreIfEquals(nil, "buyoutValue")
		:ReplaceWith(nil)
		:CallFunction(self:_CallbackToSendActionScript("OnPriceChanged"))
end

function PostingPriceFields:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "per")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 8)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("BaseButton", "item")
				:SetWidth("AUTO")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("RIGHT")
				:SetText(L["Per Item"])
				:SetTextColor(self._state:Publisher("perItem"):ReplaceBooleanWith("accent/main", "on/surface"))
				:SetAction("OnClick", "ACTION_PER_ITEM_TOGGLE")
			)
			:AddChildIf(LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic(), UIElements.New("BaseButton", "stack")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("RIGHT")
				:SetText(L["Per Stack"])
				:SetTextColor(self._state:Publisher("perItem"):ReplaceBooleanWith("on/surface", "accent/main"))
				:SetAction("OnClick", "ACTION_PER_ITEM_TOGGLE")
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "bid")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 10)
			:AddChild(UIElements.New("Text", "desc")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Bid Price"]..":")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("Input", "input")
				:SetWidth(132)
				:SetValidateFunc(self:__closure("_BidBuyoutValidateFunc"), false)
				:SetJustifyH("RIGHT")
				:SetDisabled(self._state:Publisher("isCommodity"))
				:SetManager(self._childManager)
				:BindElement(self._state, "bidInput")
				:BindIsValid(self._state, "bidIsValid")
				:SetValue(self._state:PublisherForFunctionWithKeys(private.GetBidText, "bidValue", "isCommodity"):IgnoreNil())
				:SetAction("OnValueChanged", "ACTION_BID_VALUE_CHANGED")
				:SetAction("OnEnterPressed", "ACTION_BID_ENTER_PRESSED")
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "buyout")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 16)
			:AddChild(UIElements.New("Text", "desc")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Buyout Price"]..":")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("Input", "input")
				:SetWidth(132)
				:SetValidateFunc(self:__closure("_BidBuyoutValidateFunc"), true)
				:SetJustifyH("RIGHT")
				:SetManager(self._childManager)
				:BindElement(self._state, "buyoutInput")
				:BindIsValid(self._state, "buyoutIsValid")
				:SetValue(self._state:Publisher("buyoutValue"):IgnoreNil():Map(Money.ToStringForAH))
				:SetAction("OnValueChanged", "ACTION_BUYOUT_VALUE_CHANGED")
				:SetAction("OnEnterPressed", "ACTION_BUYOUT_ENTER_PRESSED")
			)
		)
	end
	UIUtils.ConfigureInputTabNavigation(self._state.bidInput, self._state.buyoutInput)
end

---Sets the auction being edited.
---@param itemString string The item string
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param stackSize number The stack size being posted
---@return self
function PostingPriceFields:SetAuction(itemString, bid, buyout, stackSize)
	self._state.isCommodity = ItemInfo.IsCommodity(itemString)
	self._state.bidValue = bid
	self._state.buyoutValue = buyout
	self._state.stackSize = stackSize
	return self
end

---Sets the current stack size.
---@param stackSize number The stack size being posted
---@return self
function PostingPriceFields:SetStackSize(stackSize)
	self._state.stackSize = stackSize
	return self
end

---Gets the current price values.
---@return number bidValue
---@return number buyoutValue
---@return boolean perItem
function PostingPriceFields:GetPrices()
	local bidValue = self._state.bidValue
	local buyoutValue = self._state.buyoutValue
	if self._state.isCommodity then
		bidValue = buyoutValue
	end
	if buyoutValue > 0 and bidValue > buyoutValue then
		if self._state.bidInput:HasFocus() then
			-- Update the buyout to match
			buyoutValue = bidValue
		else
			-- Update the bid to match
			bidValue = buyoutValue
		end
	end
	return bidValue, buyoutValue, self._state.perItem
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state PostingPriceFieldsState
function PostingPriceFields.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_PER_ITEM_TOGGLE" then
		if not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() then
			return
		end
		state.perItem = not state.perItem
		if state.perItem then
			state.buyoutValue = state.buyoutValue / state.stackSize
			state.bidValue = state.bidValue / state.stackSize
		else
			state.buyoutValue = state.buyoutValue * state.stackSize
			state.bidValue = state.bidValue * state.stackSize
		end
		state.bidInput
			:SetFocused(false)
			:Draw()
		state.buyoutInput
			:SetFocused(false)
			:Draw()
	elseif action == "ACTION_BID_VALUE_CHANGED" then
		state.bidValue = AuctionHouseUIUtils.ParseAuctionPrice(state.bidInput:GetValue(), false)
	elseif action == "ACTION_BUYOUT_VALUE_CHANGED" then
		state.buyoutValue = AuctionHouseUIUtils.ParseAuctionPrice(state.buyoutInput:GetValue(), not state.isCommodity)
	elseif action == "ACTION_BID_ENTER_PRESSED" then
		if state.buyoutValue > 0 and state.bidValue > state.buyoutValue then
			-- Update the buyout to match
			state.buyoutValue = state.bidValue
			state.buyoutInput:Draw()
		end
	elseif action == "ACTION_BUYOUT_ENTER_PRESSED" then
		if state.isCommodity or (state.buyoutValue > 0 and state.buyoutValue < state.bidValue) then
			-- Update the bid to match
			state.bidValue = state.buyoutValue
			state.bidInput:Draw()
		end
	else
		error("Unknown action: "..tostring(action))
	end
end

function PostingPriceFields.__private:_BidBuyoutValidateFunc(value, isBuyout)
	local errMsg = nil
	value, errMsg = AuctionHouseUIUtils.ParseAuctionPrice(value, isBuyout and not self._state.isCommodity)
	if not value then
		return false, L["Invalid price."].." "..errMsg
	end
	return true
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetBidText(bidValue, isCommodity)
	return bidValue and Money.ToStringForAH(bidValue, nil, isCommodity) or nil
end

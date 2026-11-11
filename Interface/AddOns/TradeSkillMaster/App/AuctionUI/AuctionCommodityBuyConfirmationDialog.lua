-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Log = App:From("LibTSMUtil"):Include("Util.Log")
local AuctionHouse = App:From("LibTSMWoW"):Include("API.AuctionHouse")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local AuctionHouseUIUtils = App:From("LibTSMUI"):Include("AuctionHouse.AuctionHouseUIUtils")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}
local COPPER_PER_SILVER = 100
local WARNING_TEXTS = {
	none = "",
	matValue = L["Contains auctions above your material value!"],
	alert = L["Contains auctions above your alert threshold!"],
}

---@alias AuctionCommodityBuyConfirmationMarketValueFunc fun(subRow: AuctionSubRow): number?



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctionCommodityBuyConfirmationDialog = UIElements.Define("AuctionCommodityBuyConfirmationDialog", "BaseFrame")
AuctionCommodityBuyConfirmationDialog._STATE_SCHEMA = AuctionCommodityBuyConfirmationDialog._STATE_SCHEMA:Extend("AuctionCommodityBuyConfirmationDialogState")
	:AddDeferredUIElementField("view", "ViewContainer")
	:AddDeferredUIElementField("detailsQuantityInput", "NumberInput")
	:AddDeferredUIElementField("detailsItemList", "CommodityList")
	:AddNumberField("money", 0)
	:AddDeferredClassField("auctionScan", "AuctionScanManager")
	:AddDeferredClassField("subRow", "AuctionSubRow")
	:AddDeferredStringField("itemString")
	:AddNumberField("quantity", 1)
	:AddNumberField("maxQuantity", 1)
	:AddNumberField("marketValue", 0)
	:AddNumberField("totalPrice", 0)
	:AddNumberField("maxPrice", 0)
	:AddNumberField("marketThreshold", math.huge)
	:AddNumberField("alertThreshold", math.huge)
	:AddOptionalClassField("future", "Future")
	:AddOptionalNumberField("prepareQuantity")
	:AddOptionalNumberField("prepareTotalBuyout")
	:AddBooleanField("prepareSuccess", false)
	:AddNumberField("quoteDuration", 0)
	:AddBooleanField("requireManualClick", false)
	:Commit()
AuctionCommodityBuyConfirmationDialog:_AddActionScripts("OnBuyoutClicked", "OnCommodityPriceUpdated")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctionCommodityBuyConfirmationDialog:__init()
	self.__super:__init()
	---@type UIManager<AuctionCommodityBuyConfirmationDialogState>
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_QUANTITY_INPUT_CHANGED")
	self._quoteTimer = DelayTimer.New("COMMODITY_QUOTE_TIMER", self:__closure("_HandleQuoteTick"))
	self._closeTimer = DelayTimer.New("COMMODITY_CLOSE_TIMER", self._childManager:CallbackToProcessAction("ACTION_CLOSE_DIALOG"))
	self._marketValueFunc = nil ---@type AuctionCommodityBuyConfirmationMarketValueFunc!
end

function AuctionCommodityBuyConfirmationDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(12)
		:SetMouseEnabled(true)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:AddChild(UIElements.New("ViewContainer", "view")
			:SetManager(self._childManager)
			:SetNavCallback(self:__closure("_GetContentFrame"))
			:AddPath("loading", true)
			:AddPath("details")
			:AddPath("confirm")
			:BindElement(self._state, "view")
		)
	self._state.money = Currency.GetMoney()
	self._state:Publisher([[maxPrice >= marketThreshold or maxPrice >= alertThreshold]])
		:AssignToTableKey(self._state, "requireManualClick")
end

function AuctionCommodityBuyConfirmationDialog:Release()
	self._marketValueFunc = nil
	if self._state.future then
		self._childManager:CancelFuture("future")
	end
	self._quoteTimer:Cancel()
	self._closeTimer:Cancel()
	self.__super:Release()
end

---Configures the commodity buy confirmation dialog.
---@param auctionScan AuctionScanManager The auction scan
---@param subRow AuctionSubRow The sub row
---@param defaultQuantity number The default quantity
---@param maxQuantity number The max quantity
---@param marketValueFunc AuctionCommodityBuyConfirmationMarketValueFunc The market value function
---@param marketThreshold? number The market value threshold
---@param alertThreshold? number The alert threshold
---@return self
function AuctionCommodityBuyConfirmationDialog:Configure(auctionScan, subRow, defaultQuantity, maxQuantity, marketValueFunc, marketThreshold, alertThreshold)
	self._state.auctionScan = auctionScan
	self._state.subRow = subRow
	self._state.itemString = subRow:GetItemString()
	self._marketValueFunc = marketValueFunc
	self._state.quantity = defaultQuantity
	self._state.maxQuantity = maxQuantity
	self._state.marketThreshold = marketThreshold or math.huge
	self._state.alertThreshold = alertThreshold or math.huge
	self._state.marketValue = marketValueFunc(subRow) or 0
	private.UpdateStatePrices(self._state)
	self._state.view:SetPath("details", true)
	self._childManager:ProcessAction("ACTION_PREPARE")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AuctionCommodityBuyConfirmationDialog.__private:_GetContentFrame(_, path)
	local state = self._state
	if path == "loading" then
		-- Just a placeholder before everything is configured
		return UIElements.New("BaseFrame", "loading")
	elseif path == "details" then
		private.UpdateStatePrices(state)
		private.UpdateStateQuoteDuration(state)
		local details = nil
		for _ in state:WithAutoStorePaused() do
			details = UIElements.New("BaseFrame", "details")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, -4, 10)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "title")
						:SetWidth(240)
						:SetMargin(24, 0, 0, 0)
						:SetJustifyH("CENTER")
						:SetFont("BODY_BODY1_EXTRABOLD")
						:SetText(L["Order Confirmation"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("BaseButton", "closeBtn")
						:SetMargin(0, -4, 0, 0)
						:SetBackgroundAndSize("iconPack.24x24/Close/Default")
						:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "content")
					:SetLayout("HORIZONTAL")
					:SetManager(self._childManager)
					:AddChild(UIElements.New("BaseFrame", "left")
						:SetLayout("VERTICAL")
						:AddChild(UIElements.New("BaseFrame", "item")
							:SetLayout("HORIZONTAL")
							:SetPadding(6)
							:SetMargin(0, 0, 0, 16)
							:SetRoundedBackgroundColor("container/medium")
							:AddChild(UIElements.New("BaseButton", "icon")
								:SetSize(36, 36)
								:SetMargin(0, 8, 0, 0)
								:SetBackground(ItemInfo.GetTexture(state.itemString))
								:SetTooltip(state.itemString)
							)
							:AddChild(UIElements.New("Text", "name")
								:SetHeight(36)
								:SetFont("ITEM_BODY1")
								:SetText(UIUtils.GetDisplayItemName(state.itemString) or "?")
							)
						)
						:AddChild(UIElements.New("BaseFrame", "quantity")
							:SetLayout("HORIZONTAL")
							:SetHeight(24)
							:SetMargin(0, 0, 0, 16)
							:AddChild(UIElements.New("Text", "desc")
								:SetFont("BODY_SMALL")
								:SetText(AUCTION_HOUSE_QUANTITY_LABEL..":")
							)
							:AddChild(UIElements.New("NumberInput", "input")
								:SetWidth(140)
								:SetJustifyH("RIGHT")
								:SetValidRange(1, state.maxQuantity)
								:SetValue(state.quantity)
								:BindValue(state, "quantity")
								:SetAction("OnValueChanged", "ACTION_QUANTITY_INPUT_CHANGED")
								:BindElement(state, "detailsQuantityInput")
							)
						)
						:AddChild(UIElements.New("BaseFrame", "price")
							:SetLayout("HORIZONTAL")
							:SetHeight(20)
							:SetMargin(0, 0, 0, 16)
							:AddChild(UIElements.New("Text", "desc")
								:SetWidth("AUTO")
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetText(AUCTION_HOUSE_UNIT_PRICE_LABEL..":")
							)
							:AddChild(UIElements.New("Text", "money")
								:SetJustifyH("RIGHT")
								:SetFont("BODY_SMALL")
								:SetText(state:PublisherForFunctionWithKeys(private.StateToPriceString, "quantity", "totalPrice", "marketValue"))
							)
						)
						:AddChild(UIElements.New("BaseFrame", "total")
							:SetLayout("HORIZONTAL")
							:SetHeight(20)
							:AddChild(UIElements.New("Text", "desc")
								:SetWidth("AUTO")
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetText(AUCTION_HOUSE_TOTAL_PRICE_LABEL..":")
							)
							:AddChild(UIElements.New("Text", "money")
								:SetJustifyH("RIGHT")
								:SetFont("BODY_SMALL")
								:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForAH, "totalPrice"))
							)
						)
						:AddChild(UIElements.New("Spacer", "spacer"))
						:AddChild(UIElements.New("Text", "warning")
							:SetHeight(20)
							:SetMargin(0, 0, 0, 6)
							:SetFont("BODY_XSMALL")
							:SetJustifyH("CENTER")
							:SetTextColor("warning/main")
							:SetText(state:Publisher([[(not requireManualClick and "none") or (maxPrice >= marketThreshold and "matValue") or "alert"]]):Map(WARNING_TEXTS))
						)
						:AddChild(UIElements.NewNamed("MediumPrimaryActionButton", "confirmBtn", "TSMBidBuyConfirmBtn")
							:SetText(state:PublisherForFunctionWithKeys(private.StateToBuyText, "money", "totalPrice", "quantity", "maxQuantity", "prepareSuccess", "prepareQuantity", "quoteDuration"))
							:SetDisabled(state:Publisher([[future ~= nil or money < totalPrice or totalPrice <= 0 or quantity < 1 or quantity > maxQuantity or (not prepareSuccess and prepareQuantity ~= nil)]]))
							:SetRequireManualClick(state:Publisher("requireManualClick"))
							:SetAction("OnClick", "ACTION_BUYOUT_CLICKED")
						)
					)
					:AddChild(UIElements.New("ListContainer", "items")
						:SetWidth(266)
						:SetMargin(12, 0, 0, 0)
						:AddChild(UIElements.New("CommodityList", "list")
							:SetBackgroundColor("container/lowest")
							:SetData(state.subRow:GetResultRow())
							:SelectQuantity(state.quantity)
							:SetMarketValueFunction(self._marketValueFunc)
							:SetMarketThreshold(state.marketThreshold)
							:SetAlertThreshold(state.alertThreshold)
							:SetAction("OnRowClick", "ACTION_COMMODITY_ROW_CLICKED")
							:BindElement(state, "detailsItemList")
						)
					)
				)
		end
		return details
	elseif path == "confirm" then
		private.UpdateStatePrices(state)
		private.UpdateStateQuoteDuration(state)
		local confirm = nil
		for _ in state:WithAutoStorePaused() do
			confirm = UIElements.New("BaseFrame", "confirm")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, -4, 10)
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, 0, 10)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "title")
						:SetWidth(240)
						:SetJustifyH("CENTER")
						:SetFont("BODY_BODY1_EXTRABOLD")
						:SetText(L["Buyout Above Threshold"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
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
					:SetRoundedBackgroundColor("container/medium")
					:AddChild(UIElements.New("BaseButton", "icon")
						:SetSize(36, 36)
						:SetMargin(0, 8, 0, 0)
						:SetBackground(ItemInfo.GetTexture(state.itemString))
						:SetTooltip(state.itemString)
					)
					:AddChild(UIElements.New("Text", "name")
						:SetHeight(36)
						:SetFont("ITEM_BODY1")
						:SetText(UIUtils.GetDisplayItemName(state.itemString) or "?")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "quantity")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("Text", "desc")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(AUCTION_HOUSE_QUANTITY_LABEL..":")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "text")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(state.quantity)
					)
				)
				:AddChild(UIElements.New("BaseFrame", "price")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("Text", "desc")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(AUCTION_HOUSE_UNIT_PRICE_LABEL..":")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "text")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(state:PublisherForFunctionWithKeys(private.StateToPriceString, "quantity", "totalPrice", "marketValue"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "total")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 34)
					:AddChild(UIElements.New("Text", "desc")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(AUCTION_HOUSE_TOTAL_PRICE_LABEL..":")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "text")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForAH, "totalPrice"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "footer")
					:SetLayout("HORIZONTAL")
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("MediumSecondaryActionButton", "cancelBtn")
						:SetWidth(298)
						:SetMargin(0, 8, 0, 0)
						:SetText(L["No, cancel"])
						:SetAction("OnClick", "ACTION_CANCEL_CONFIRMATION")
					)
					:AddChild(UIElements.NewNamed("MediumPrimaryActionButton", "confirmBtn", "TSMBidBuyConfirmBtn")
						:SetText(state:PublisherForFunctionWithKeys(private.QuoteDurationToConfirmText, "quoteDuration"))
						:SetDisabled(state:Publisher("future"):ToBooleanNotEquals(nil))
						:SetAction("OnClick", "ACTION_BUYOUT_CONFIRMED")
					)
				)
		end
		return confirm
	else
		error("Invalid path: "..tostring(path))
	end
end

---@param manager UIManager<AuctionCommodityBuyConfirmationDialogState>
---@param state AuctionCommodityBuyConfirmationDialogState
function AuctionCommodityBuyConfirmationDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_QUANTITY_INPUT_CHANGED" then
		self:_UpdateDetails(state, false)
	elseif action == "ACTION_BUYOUT_CLICKED" then
		if not state.prepareSuccess then
			-- This is a prepare click
			return manager:ProcessAction("ACTION_PREPARE")
		end
		assert(state.prepareQuantity == state.quantity)
		private.UpdateStatePrices(state)
		if state.maxPrice >= state.marketThreshold or state.maxPrice >= state.alertThreshold then
			state.view:SetPath("confirm", true)
			return
		end
		self:_SendActionScript("OnBuyoutClicked", state.quantity)
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_COMMODITY_ROW_CLICKED" then
		local index = ...
		local quantity = state.detailsItemList:GetTotalQuantity(index)
		state.detailsQuantityInput
			:SetValue(quantity)
			:Draw()
		state.quantity = quantity
		manager:ProcessAction("ACTION_PREPARE")
		self:_UpdateDetails(state, true)
	elseif action == "ACTION_PREPARE" then
		if state.quantity == state.prepareQuantity then
			return
		end
		if state.future then
			manager:CancelFuture("future")
		end
		private.UpdateStatePrices(state)
		local itemBuyout = state.quantity > 0 and Math.Ceil(state.totalPrice / state.quantity, (App.IsMistsClassic() or App.IsForever()) and 1 or COPPER_PER_SILVER) or nil
		local result, future = state.auctionScan:PrepareForBidOrBuyout(nil, state.subRow, true, state.quantity, itemBuyout)
		state.prepareSuccess = false
		if not result then
			state.prepareQuantity = nil
			return
		end
		state.prepareQuantity = state.quantity
		state.prepareTotalBuyout = state.totalPrice
		if future then
			self._childManager:ManageFuture("future", future, "ACTION_FUTURE_DONE")
		end
		private.UpdateStateQuoteDuration(state)
		if state.prepareSuccess then
			self._quoteTimer:RunForTime(20)
		else
			self._quoteTimer:Cancel()
		end
	elseif action == "ACTION_FUTURE_DONE" then
		local result = ...
		if not result or result ~= state.prepareTotalBuyout then
			-- The unit price changed
			ChatMessage.PrintUser(L["Failed to buy auction."])
			self:_SendActionScript("OnCommodityPriceUpdated")
			self._closeTimer:RunForFrames(0)
			return
		end
		state.prepareSuccess = state.quantity == state.prepareQuantity
		private.UpdateStatePrices(state)
		private.UpdateStateQuoteDuration(state)
		if state.prepareSuccess then
			self._quoteTimer:RunForTime(20)
		else
			self._quoteTimer:Cancel()
		end
	elseif action == "ACTION_CANCEL_CONFIRMATION" then
		state.view:SetPath("details", true)
		self:_UpdateDetails(state, true)
	elseif action == "ACTION_BUYOUT_CONFIRMED" then
		local inputQuantity = state.quantity
		self:_SendActionScript("OnBuyoutClicked", inputQuantity)
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

function AuctionCommodityBuyConfirmationDialog.__private:_UpdateDetails(state, noListUpdate)
	private.UpdateStatePrices(state)
	if not noListUpdate then
		state.detailsItemList:SelectQuantity(state.quantity)
	end
	if state.quantity ~= state.prepareQuantity then
		state.prepareSuccess = false
		state.prepareQuantity = nil
	end
	private.UpdateStateQuoteDuration(state)
	if state.prepareSuccess then
		self._quoteTimer:RunForTime(20)
	else
		self._quoteTimer:Cancel()
	end
end

function AuctionCommodityBuyConfirmationDialog.__private:_HandleQuoteTick()
	local state = self._state
	private.UpdateStateQuoteDuration(state)
	if state.quoteDuration <= 0 then
		Log.Info("Commodity quote timed out")
		if state.view:GetPath() == "confirm" then
			state.view:SetPath("details", true)
		end
		state.prepareSuccess = false
		state.prepareQuantity = nil
		self._quoteTimer:Cancel()
		private.UpdateStateQuoteDuration(state)
	else
		self._quoteTimer:RunForTime(1)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateStatePrices(state)
	local remainingQuantity = state.quantity
	local totalPrice, maxPrice = 0, 0
	for _, query in state.auctionScan:QueryIterator() do
		for _, subRow in query:ItemSubRowIterator(state.itemString) do
			if remainingQuantity > 0 then
				local _, itemBuyout = subRow:GetBuyouts()
				local _, numOwnerItems = subRow:GetOwnerInfo()
				local quantityAvailable = subRow:GetQuantities() - numOwnerItems
				local quantityToBuy = min(quantityAvailable, remainingQuantity)
				totalPrice = totalPrice + (itemBuyout * quantityToBuy)
				remainingQuantity = remainingQuantity - quantityToBuy
				maxPrice = max(maxPrice, itemBuyout)
			end
		end
	end
	state.totalPrice = totalPrice
	state.maxPrice = maxPrice
end

function private.UpdateStateQuoteDuration(state)
	state.quoteDuration = AuctionHouse.GetQuoteDurationRemaining()
end

function private.StateToPriceString(quantity, totalPrice, marketValue)
	local itemBuyout = quantity > 0 and Math.Ceil(totalPrice / quantity, (App.IsMistsClassic() or App.IsForever()) and 1 or COPPER_PER_SILVER) or 0
	local pct = marketValue > 0 and itemBuyout > 0 and Math.Round(100 * itemBuyout / marketValue) or nil
	local marketValueStr = AuctionHouseUIUtils.GetMarketValuePercentText(pct)
	return format("%s (%s)", Money.ToStringForAH(itemBuyout), marketValueStr)
end

function private.StateToBuyText(money, totalPrice, quantity, maxQuantity, prepareSuccess, prepareQuantity, quoteDuration)
	if money < totalPrice then
		return L["Not Enough Money"]
	elseif totalPrice <= 0 or quantity < 1 or quantity > maxQuantity then
		return L["Invalid Quantity"]
	elseif prepareSuccess then
		return quoteDuration <= 10 and format(L["Buy Commodity (%02d)"], quoteDuration) or L["Buy Commodity"]
	elseif prepareQuantity then
		return L["Preparing..."]
	else
		return L["Prepare Buy"]
	end
end

function private.QuoteDurationToConfirmText(quoteDuration)
	return quoteDuration <= 10 and format(L["Yes, I'm sure (%02d)"], quoteDuration) or L["Yes, I'm sure"]
end

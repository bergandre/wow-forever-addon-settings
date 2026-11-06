	-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Transactions = LibTSMUI:From("LibTSMService"):Include("Ledger.Transactions")



-- ============================================================================
-- Element Definition
-- ============================================================================

local RecordTradeDialog = ComponentRegistry.Define("RecordTradeDialog", "PopupDialog")
RecordTradeDialog._STATE_SCHEMA = RecordTradeDialog._STATE_SCHEMA:Extend("RecordTradeDialogState")
	:AddDeferredStringField("type", function(value) return value == nil or value == "sale" or value == "buy" end)
	:AddDeferredStringField("itemString")
	:AddDeferredNumberField("price")
	:AddDeferredNumberField("quantity")
	:AddDeferredStringField("character")
	:Commit()

---@class RecordTradeDialogState
---@field type LedgerTransactionType



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function RecordTradeDialog:Acquire()
	self.__super:Acquire()
	self._state.buttonsFrame
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("SmallPrimaryActionButton", "acceptBtn")
			:SetWidth(150)
			:SetText(YES)
			:SetAction("OnClick", "ACTION_RECORD_TRADE")
		)
		:AddChild(UIElements.New("SmallSecondaryActionButton", "cancelBtn")
			:SetWidth(150)
			:SetMargin(16, 0, 0, 0)
			:SetText(NO)
			:SetAction("OnClick", "ACTION_CLOSE")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
	self:HideOnEscape()
end

---Configures the dialog.
---@param tradeType LedgerTransactionType The trade type
---@param itemString string The item string
---@param money number The total amount of money
---@param quantity number The quantity traded
---@param character string The name of the character traded with
---@return self
function RecordTradeDialog:Configure(tradeType, itemString, money, quantity, character)
	assert(tradeType == "sale" or tradeType == "buy")
	self._state.type = tradeType
	self._state.itemString = itemString
	self._state.price = money / quantity
	self._state.quantity = quantity
	self._state.character = character
	local gotText, gaveText = nil, nil
	if tradeType == "buy" then
		gotText = format("%sx%d", ItemInfo.GetLink(itemString), quantity)
		gaveText = Money.ToStringExact(money)
	elseif tradeType == "sale" then
		gaveText = format("%sx%d", ItemInfo.GetLink(itemString), quantity)
		gotText = Money.ToStringExact(money)
	else
		error("Invalid tradeType: "..tostring(tradeType))
	end
	self:SetMessage(format(L["TSM detected that you just traded %s to %s in return for %s. Would you like Accounting to store a record of this trade?"], gaveText, character, gotText))
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<RecordTradeDialogState>
---@param state RecordTradeDialogState
function RecordTradeDialog.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_RECORD_TRADE" then
		if state.type == "sale" then
			Transactions.InsertTradeSale(state.itemString, state.quantity, state.price, state.character)
		elseif state.type == "buy" then
			Transactions.InsertTradeBuy(state.itemString, state.quantity, state.price, state.character)
		else
			error("Unknown type: "..tostring(state.type))
		end
		return manager:ProcessAction("ACTION_CLOSE")
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

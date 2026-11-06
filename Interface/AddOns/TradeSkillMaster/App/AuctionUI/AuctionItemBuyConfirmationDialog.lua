-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local AuctionHouseUIUtils = App:From("LibTSMUI"):Include("AuctionHouse.AuctionHouseUIUtils")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctionItemBuyConfirmationDialog = UIElements.Define("AuctionItemBuyConfirmationDialog", "BaseFrame")
AuctionItemBuyConfirmationDialog._STATE_SCHEMA = AuctionItemBuyConfirmationDialog._STATE_SCHEMA:Extend("AuctionItemBuyConfirmationDialogState")
	:AddBooleanField("isBuy", true)
	:AddNumberField("quantity", 0)
	:AddOptionalStringField("itemString")
	:AddStringField("stacksText", "")
	:AddOptionalNumberField("marketValue")
	:AddNumberField("displayItemBuyout", 0)
	:AddNumberField("displayTotalBuyout", 0)
	:Commit()
AuctionItemBuyConfirmationDialog:_AddActionScripts("OnBuyoutClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctionItemBuyConfirmationDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function AuctionItemBuyConfirmationDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(12)
		:SetMouseEnabled(true)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
	for _ in self._state:WithAutoStorePaused() do
		local itemStringPublisher = self._state:Publisher("itemString")
			:IgnoreNil()
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 10)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("Text", "title")
				:SetWidth(240)
				:SetMargin(24, 0, 0, 0)
				:SetJustifyH("CENTER")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(GlobalStrings.Get("BUYOUT"))
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "content")
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
						:SetBackground(itemStringPublisher:Map(ItemInfo.GetTexture))
						:SetTooltip(itemStringPublisher)
					)
					:AddChild(UIElements.New("Text", "name")
						:SetHeight(36)
						:SetFont("ITEM_BODY1")
						:SetText(itemStringPublisher:Map(UIUtils.GetDisplayItemName):CoalesceNil("?"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "stacks")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("Text", "desc")
						:SetWidth("AUTO")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(self._state:Publisher("isBuy"):ReplaceBooleanWith(L["Purchasing Auction"]..":", L["Bidding Auction"]..":"))
					)
					:AddChild(UIElements.New("Text", "number")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(self._state:Publisher("stacksText"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "price")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("Text", "desc")
						:SetWidth("AUTO")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Unit Price"]..":")
					)
					:AddChild(UIElements.New("Text", "money")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(self._state:PublisherForFunctionWithKeys(private.StateToUnitPriceText, "displayItemBuyout", "marketValue"))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "total")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Text", "desc")
						:SetWidth("AUTO")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetText(L["Total Price"]..":")
					)
					:AddChild(UIElements.New("Text", "money")
						:SetJustifyH("RIGHT")
						:SetFont("BODY_SMALL")
						:SetText(self._state:PublisherForFunctionWithKeys(Money.ToStringForAH, "displayTotalBuyout"))
					)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "warning")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 6)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("CENTER")
					:SetTextColor("warning/main")
					:SetText("")
				)
				:AddChild(UIElements.NewNamed("MediumPrimaryActionButton", "confirmBtn", "TSMBidBuyConfirmBtn")
					:SetText(self._state:Publisher("isBuy"):ReplaceBooleanWith(L["Buy Auction"], L["Bid Auction"]))
					:SetAction("OnClick", "ACTION_BUY_AUCTION")
				)
			)
		)
		self:AddCancellable(itemStringPublisher:EndShare())
	end
end

---Configures the confirmation details.
---@param isBuy boolean Whether this is a buy (vs. a bid) confirmation
---@param subRow AuctionSubRow The sub row
---@param quantity number The quantity
---@param auctionNum number The auction number
---@param numFound number The total number found
---@param marketValue? number The market value
---@return self
function AuctionItemBuyConfirmationDialog:Configure(isBuy, subRow, quantity, auctionNum, numFound, marketValue)
	self._state.isBuy = isBuy
	self._state.quantity = quantity
	self._state.itemString = subRow:GetItemString()
	self._state.stacksText = auctionNum.."/"..numFound
	self._state.marketValue = marketValue
	local buyout = nil
	if isBuy then
		buyout = subRow:GetBuyouts()
	else
		buyout = subRow:GetRequiredBid()
	end
	self._state.displayItemBuyout = ceil(buyout / quantity)
	self._state.displayTotalBuyout = (App.IsVanillaClassic() or App.IsBCClassic()) and buyout or ceil(buyout / quantity)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state AuctionItemBuyConfirmationDialogState
function AuctionItemBuyConfirmationDialog.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_BUY_AUCTION" then
		self:_SendActionScript("OnBuyoutClicked", state.quantity)
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToUnitPriceText(displayItemBuyout, marketValue)
	local pct = marketValue and marketValue > 0 and displayItemBuyout > 0 and Math.Round(100 * displayItemBuyout / marketValue) or nil
	return format("%s (%s)", Money.ToStringForAH(displayItemBuyout), AuctionHouseUIUtils.GetMarketValuePercentText(pct))
end

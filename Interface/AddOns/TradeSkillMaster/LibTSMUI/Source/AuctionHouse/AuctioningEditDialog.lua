-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningEditDialog = ComponentRegistry.Define("AuctioningEditDialog", "BaseFrame")
AuctioningEditDialog._STATE_SCHEMA = AuctioningEditDialog._STATE_SCHEMA:Extend("AuctioningEditDialogState")
	:AddDeferredUIElementField("priceFields", "PostingPriceFields")
	:AddDeferredUIElementField("durationToggle", "AuctionDurationToggle")
	:AddOptionalStringField("itemString")
	:AddBooleanField("priceIsValid", true)
	:AddOptionalNumberField("numStacks")
	:AddOptionalNumberField("stackSize")
	:Commit()
AuctioningEditDialog:_AddActionScripts("OnSaveClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningEditDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function AuctioningEditDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(12)
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:SetMouseEnabled(true)
	self:AddChild(UIElements.New("BaseFrame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, -4, 10)
		:AddChild(UIElements.New("Spacer", "spacer")
			:SetWidth(20)
		)
		:AddChild(UIElements.New("Text", "title")
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetJustifyH("CENTER")
			:SetText(L["Edit Post"])
		)
		:AddChild(UIElements.New("BaseButton", "closeBtn")
			:SetMargin(0, -4, 0, 0)
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
		)
	)
	for _ in self._state:WithAutoStorePaused() do
		local itemStringPublisher = self._state:Publisher("itemString")
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "item")
			:SetLayout("HORIZONTAL")
			:SetPadding(6)
			:SetMargin(0, 0, 0, 16)
			:SetRoundedBackgroundColor("container/medium")
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
		)
		-- TODO: implement editing stack sizes
		self:AddChild(UIElements.New("BaseFrame", "numStacks")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 16)
			:AddChild(UIElements.New("Text", "label")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(AUCTION_NUM_STACKS..":")
			)
			:AddChild(UIElements.New("NumberInput", "input")
				:SetSize(62, 24)
				:SetValidRange(1, 5000)
				:SetDisabled(true)
				:SetValue(self._state:Publisher("numStacks"):IgnoreNil())
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "stackSize")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 16)
			:AddChild(UIElements.New("Text", "label")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(AUCTION_STACK_SIZE..":")
			)
			:AddChild(UIElements.New("NumberInput", "input")
				:SetSize(62, 24)
				:SetValidRange(1, 5000)
				:SetDisabled(true)
				:SetValue(self._state:Publisher("stackSize"):IgnoreNil())
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "duration")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 24)
			:AddChild(UIElements.New("Text", "desc")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(L["Duration"]..":")
			)
			:AddChild(UIElements.New("AuctionDurationToggle", "toggle")
				:SetMargin(0, 48, 0, 0)
				:BindElement(self._state, "durationToggle")
			)
		)
		self:AddChild(UIElements.New("PostingPriceFields", "price")
			:SetManager(self._childManager)
			:SetAction("IsValidChanged", "ACTION_PRICE_IS_VALID_CHANGED")
			:BindElement(self._state, "priceFields")
		)
		self:AddChild(UIElements.New("MediumPrimaryActionButton", "saveBtn")
			:SetText(SAVE)
			:SetDisabled(self._state:Publisher("priceIsValid"):InvertBoolean())
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_SAVE_CLICKED")
		)
		self:AddCancellable(itemStringPublisher:EndShare())
	end
end

---Sets the auction being edited.
---@param itemString string The item string
---@param postTime number The auction duration
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param numStacks number The number of stacks being posted
---@param stackSize number The stack size being posted
---@return self
function AuctioningEditDialog:SetAuction(itemString, postTime, bid, buyout, numStacks, stackSize)
	self._state.itemString = itemString
	self._state.numStacks = numStacks
	self._state.stackSize = stackSize
	self._state.priceFields:SetAuction(itemString, bid, buyout, stackSize)
	self._state.durationToggle:SetValue(postTime)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<AuctioningEditDialogState>
---@param state AuctioningEditDialogState
function AuctioningEditDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_PRICE_IS_VALID_CHANGED" then
		state.priceIsValid = ...
	elseif action == "ACTION_SAVE_CLICKED" then
		local bid, buyout, perItem = state.priceFields:GetPrices()
		local duration = state.durationToggle:GetValue()
		self:_SendActionScript("OnSaveClicked", bid, buyout, perItem, duration)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end

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
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")
local private = {}

---@alias AuctioningPostDetailsChangePostDetailFunc fun(field: string, value: number)



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningPostDetails = ComponentRegistry.Define("AuctioningPostDetails", "BaseFrame")
AuctioningPostDetails._STATE_SCHEMA = AuctioningPostDetails._STATE_SCHEMA:Extend("AuctioningPostDetailsState")
	:AddOptionalStringField("itemString")
	:AddBooleanField("isCommodity", false)
	:AddOptionalNumberField("duration")
	:AddOptionalNumberField("bid")
	:AddOptionalNumberField("itemBid")
	:AddOptionalNumberField("buyout")
	:AddOptionalNumberField("itemBuyout")
	:AddOptionalNumberField("numProcessed")
	:AddOptionalNumberField("numStacks")
	:AddOptionalNumberField("stackSize")
	:AddOptionalStringField("operationName")
	:AddOptionalNumberField("depositCost")
	:Commit()

---@class AuctioningPostDetailsState
---@correlated itemString, duration, bid, itemBid, buyout, itemBuyout, numProcessed, numStacks, stackSize, operationName, depositCost



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningPostDetails:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._changePostDetailFunc = nil ---@type AuctioningPostDetailsChangePostDetailFunc!
end

function AuctioningPostDetails:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(8, 8, 4, 4)
	for _ in self._state:WithAutoStorePaused() do
		local itemStringPublisher = self._state:Publisher("itemString")
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "title")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 4)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseButton", "icon")
				:SetSize(16, 16)
				:SetBackground(itemStringPublisher:MapNonNil(ItemInfo.GetTexture))
				:SetTooltip(itemStringPublisher)
			)
			:AddChild(UIElements.New("BaseButton", "text")
				:SetMargin(4, 8, 0, 0)
				:SetFont("ITEM_BODY1")
				:SetJustifyH("LEFT")
				:SetText(itemStringPublisher:MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil("-"))
				:SetTooltip(itemStringPublisher)
			)
			:AddChild(UIElements.New("SmallTertiaryActionButton", "editBtn")
				:SetWidth("AUTO")
				:SetText(L["Edit Post"])
				:SetDisabled(self._state:Publisher([[not itemString]]))
				:SetAction("OnClick", "ACTION_EDIT_BUTTON_CLICKED")
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetPadding(8)
			:SetRoundedBackgroundColor("container/high")
			:AddChild(UIElements.New("BaseFrame", "operation")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:AddChild(private.CreateLabel(L["Operation"]))
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(self._state:Publisher("operationName"):CoalesceNil("-"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "bid")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetShown(self._state:Publisher([[not isCommodity and bid ~= buyout]]))
				:AddChild(private.CreateLabel(BID))
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(self._state:Publisher("bid"):MapNonNil(Money.ToStringForAH):CoalesceNil("-"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "buyout")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:AddChild(private.CreateLabel(BUYOUT))
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(self._state:Publisher([[isCommodity and itemBuyout or buyout]]):MapNonNil(Money.ToStringForAH):CoalesceNil("-"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "deposit")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:AddChild(private.CreateLabel(L["Deposit Cost"]))
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(self._state:Publisher("depositCost"):MapNonNil(Money.ToStringForUI):CoalesceNil("-"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "duration")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:AddChild(private.CreateLabel(L["Duration"]))
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(self._state:Publisher("duration"):MapNonNil(AuctionHouse.DURATIONS):CoalesceNil("-"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "quantity")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(private.CreateLabel(((LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic()) and L["Stack / Quantity"] or L["Quantity"])))
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_SMALL")
					:SetText(self._state:PublisherForFunctionWithKeys(private.StateToQuantityText, "numStacks", "numProcessed", "stackSize"))
				)
			)
		)
		self:AddCancellable(itemStringPublisher:EndShare())
	end
end

function AuctioningPostDetails:Release()
	self._changePostDetailFunc = nil
	self.__super:Release()
end

---Configures the Auctioning details.
---@param changePostDetailFunc AuctioningPostDetailsChangePostDetailFunc Changes the value of a field for the current posting auction row
---@return self
function AuctioningPostDetails:Configure(changePostDetailFunc)
	self._changePostDetailFunc = changePostDetailFunc
	return self
end

---Sets the current scan row.
---@param value DatabaseQuery|ReactivePublisherSchemaBase The query to get the first result from or a publisher
---@return self
function AuctioningPostDetails:SetAuctionRow(value)
	if value.__class.__name == "DatabaseQuery" then
		---@cast value DatabaseQuery
		local itemString, bid, itemBid, buyout, itemBuyout, numProcessed, numStacks, stackSize, operationName = value:GetFirstResult("itemString", "bid", "itemBid", "buyout", "itemBuyout", "numProcessed", "numStacks", "stackSize", "operationName")
		if not itemString then
			self._state.itemString = nil
			self._state.isCommodity = false
			self._state.duration = nil
			self._state.bid = nil
			self._state.itemBid = nil
			self._state.buyout = nil
			self._state.itemBuyout = nil
			self._state.numProcessed = nil
			self._state.numStacks = nil
			self._state.stackSize = nil
			self._state.operationName = nil
			self._state.depositCost = nil
			return self
		end
		self._state.itemString = itemString
		self._state.isCommodity = ItemInfo.IsCommodity(itemString) or false
		self._state.bid = bid
		self._state.itemBid = itemBid
		self._state.buyout = buyout
		self._state.itemBuyout = itemBuyout
		self._state.numProcessed = numProcessed
		self._state.numStacks = numStacks
		self._state.stackSize = stackSize
		self._state.operationName = operationName
		local duration, depositCost = value:GetFirstResult("postTime", "depositCost")
		self._state.duration = duration
		self._state.depositCost = depositCost
	else
		---@cast value ReactivePublisherSchemaBase
		self:_MethodPublisher(value, "SetAuctionRow")
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager
---@param state AuctioningPostDetailsState
function AuctioningPostDetails.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_EDIT_BUTTON_CLICKED" then
		if not state.itemString then
			return
		end
		self:GetBaseElement():ShowDialogFrame(UIElements.New("AuctioningEditDialog", "frame")
			:SetSize(328, 364)
			:SetPadding(12)
			:AddAnchor("CENTER")
			:SetAuction(state.itemString, state.duration, state.itemBid, state.itemBuyout, state.numStacks, state.stackSize)
			:SetManager(manager)
			:SetAction("OnSaveClicked", "ACTION_EDIT_DIALOG_SAVED")
		)
	elseif action == "ACTION_EDIT_DIALOG_SAVED" then
		local bid, buyout, perItem, duration = ...
		if buyout > 0 then
			bid = min(bid, buyout)
		end
		assert(state.itemString)
		if duration ~= state.duration then
			self._changePostDetailFunc("postTime", duration)
		end
		-- Update buyout first since doing so may change the bid
		if buyout ~= (perItem and state.itemBuyout or state.buyout) then
			self._changePostDetailFunc(perItem and "itemBuyout" or "buyout", buyout)
		end
		if not state.isCommodity and bid ~= (perItem and state.itemBid or state.bid) then
			self._changePostDetailFunc(perItem and "itemBid" or "bid", bid)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CreateLabel(text)
	return UIElements.New("Text", "label")
		:SetWidth("AUTO")
		:SetMargin(0, 4, 0, 0)
		:SetFont("BODY_SMALL_SEMIBOLD")
		:SetText(text..":")
end

function private.StateToQuantityText(numStacks, numProcessed, stackSize)
	if not numStacks or not numProcessed or not stackSize then
		return "-"
	end
	if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() then
		return format(L["%d of %d"], numStacks - numProcessed, stackSize)
	else
		return tostring(stackSize)
	end
end

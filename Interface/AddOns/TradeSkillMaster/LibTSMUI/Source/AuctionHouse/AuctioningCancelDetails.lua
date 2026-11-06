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
local SECONDS_PER_MIN = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MIN
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningCancelDetails = ComponentRegistry.Define("AuctioningCancelDetails", "BaseFrame")
AuctioningCancelDetails._STATE_SCHEMA = AuctioningCancelDetails._STATE_SCHEMA:Extend("AuctioningCancelDetailsState")
	:AddOptionalStringField("itemString")
	:AddBooleanField("isCommodity", false)
	:AddOptionalNumberField("duration")
	:AddOptionalNumberField("buyout")
	:AddOptionalNumberField("itemBuyout")
	:AddOptionalNumberField("numProcessed")
	:AddOptionalNumberField("numStacks")
	:AddOptionalNumberField("stackSize")
	:Commit()

---@class AuctioningCancelDetailsState
---@correlated itemString, duration, buyout, itemBuyout, numProcessed, numStacks, stackSize



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningCancelDetails:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	self:SetHeight(30)
	self:SetPadding(8, 8, 0, 0)
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	for _ in self._state:WithAutoStorePaused() do
		local itemStringPublisher = self._state:Publisher("itemString")
			:Share()
		self:AddChild(UIElements.New("BaseButton", "icon")
			:SetSize(16, 16)
			:SetBackground(itemStringPublisher:MapNonNil(ItemInfo.GetTexture))
			:SetTooltip(itemStringPublisher)
		)
		self:AddChild(UIElements.New("BaseButton", "item")
			:SetMargin(4, 24, 0, 0)
			:SetFont("ITEM_BODY2")
			:SetJustifyH("LEFT")
			:SetText(itemStringPublisher:MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil("-"))
			:SetTooltip(itemStringPublisher)
		)
		self:AddChild(UIElements.New("Text", "buyoutLabel")
			:SetWidth("AUTO")
			:SetMargin(0, 4, 0, 0)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(BUYOUT..":")
		)
		self:AddChild(UIElements.New("Text", "buyout")
			:SetWidth("AUTO")
			:SetMargin(0, 24, 0, 0)
			:SetFont("BODY_SMALL")
			:SetText(self._state:Publisher([[isCommodity and itemBuyout or buyout]]):MapNonNil(Money.ToStringForAH):CoalesceNil("-"))
		)
		self:AddChild(UIElements.New("Text", "quantityLabel")
			:SetWidth("AUTO")
			:SetMargin(0, 4, 0, 0)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(((LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic()) and L["Stack / Quantity"] or L["Quantity"])..":")
		)
		self:AddChild(UIElements.New("Text", "quantity")
			:SetWidth("AUTO")
			:SetMargin(0, 24, 0, 0)
			:SetFont("BODY_SMALL")
			:SetText(self._state:PublisherForFunctionWithKeys(private.StateToQuantityText, "numStacks", "numProcessed", "stackSize"))
		)
		self:AddChild(UIElements.New("Text", "durationLabel")
			:SetWidth("AUTO")
			:SetMargin(0, 4, 0, 0)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(L["Duration"]..":")
		)
		self:AddChild(UIElements.New("Text", "duration")
			:SetWidth("AUTO")
			:SetFont("BODY_SMALL")
			:SetText(self._state:Publisher("duration"):MapNonNil(private.DurationToText):CoalesceNil("-"))
		)
		self:AddCancellable(itemStringPublisher:EndShare())
	end
end

---Sets the current scan row.
---@param value DatabaseQuery|ReactivePublisherSchemaBase The query to get the first result from or a publisher
---@return self
function AuctioningCancelDetails:SetAuctionRow(value)
	if value.__class.__name == "DatabaseQuery" then
		---@cast value DatabaseQuery
		local itemString, buyout, itemBuyout, numProcessed, numStacks, stackSize, duration = value:GetFirstResult("itemString", "buyout", "itemBuyout", "numProcessed", "numStacks", "stackSize", "duration")
		if not itemString then
			self._state.itemString = nil
			self._state.isCommodity = false
			self._state.duration = nil
			self._state.buyout = nil
			self._state.itemBuyout = nil
			self._state.numProcessed = nil
			self._state.numStacks = nil
			self._state.stackSize = nil
			return self
		end
		self._state.itemString = itemString
		self._state.isCommodity = ItemInfo.IsCommodity(itemString) or false
		self._state.duration = duration
		self._state.buyout = buyout
		self._state.itemBuyout = itemBuyout
		self._state.numProcessed = numProcessed
		self._state.numStacks = numStacks
		self._state.stackSize = stackSize
	else
		---@cast value ReactivePublisherSchemaBase
		self:_MethodPublisher(value, "SetAuctionRow")
	end
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

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

function private.DurationToText(duration)
	if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() then
		local str = AuctionHouse.GetTimeLeftStrings(duration)
		return str
	end
	duration = duration - LibTSMUI.GetTime()
	if duration < SECONDS_PER_MIN then
		return duration.."s"
	elseif duration < SECONDS_PER_HOUR then
		return floor(duration / SECONDS_PER_MIN).."m"
	elseif duration < SECONDS_PER_DAY then
		return floor(duration / SECONDS_PER_HOUR).."h"
	else
		return floor(duration / SECONDS_PER_DAY).."d"
	end
end

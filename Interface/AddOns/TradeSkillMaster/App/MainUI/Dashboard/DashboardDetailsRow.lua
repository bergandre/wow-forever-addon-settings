-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardDetailsRow = UIElements.Define("DashboardDetailsRow", "BaseFrame")
DashboardDetailsRow._STATE_SCHEMA = DashboardDetailsRow._STATE_SCHEMA:Extend("DashboardDetailsRowState")
	:AddStringField("headingLabel", "")
	:AddStringField("totalLabel", "")
	:AddStringField("avgLabel", "")
	:AddNumberField("totalAmount", 0)
	:AddNumberField("avgAmount", 0)
	:AddOptionalNumberField("change")
	:AddBooleanField("changeInverted", false)
	:AddOptionalStringField("trendIcon")
	:AddBooleanField("hasTopItem", false)
	:AddOptionalStringField("topItem")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DashboardDetailsRow:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(self._state:Publisher("headingLabel"))
			)
			:AddChild(UIElements.New("BaseFrame", "total")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_XSMALL")
					:SetText(self._state:Publisher("totalLabel"))
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("BaseTexture", "trend")
					:SetSize(12, 12)
					:SetMargin(0, 4, 0, 0)
					:SetShown(self._state:Publisher("trendIcon"):ToBooleanNotEquals(nil))
					:SetTextureAndSize(self._state:Publisher("trendIcon"):IgnoreNil())
				)
				:AddChild(UIElements.New("Text", "amount")
					:SetWidth("AUTO")
					:SetFont("TABLE_XSMALL")
					:SetText(self._state:PublisherForFunctionWithKeys(private.AmountToString, "totalAmount"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "avg")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Text", "label")
					:SetWidth("AUTO")
					:SetFont("BODY_XSMALL")
					:SetText(self._state:Publisher("avgLabel"))
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("BaseTexture", "trend")
					:SetSize(12, 12)
					:SetMargin(0, 4, 0, 0)
					:SetShown(self._state:Publisher("trendIcon"):ToBooleanNotEquals(nil))
					:SetTextureAndSize(self._state:Publisher("trendIcon"):IgnoreNil())
				)
				:AddChild(UIElements.New("Text", "amount")
					:SetWidth("AUTO")
					:SetFont("TABLE_XSMALL")
					:SetText(self._state:PublisherForFunctionWithKeys(private.AmountToString, "avgAmount"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "top")
				:SetLayout("HORIZONTAL")
				:SetHeight(16)
				:SetShown(self._state:Publisher("hasTopItem"))
				:AddChild(UIElements.New("Text", "label")
					:SetWidth("AUTO")
					:SetFont("BODY_XSMALL")
					:SetText(L["Top Item"]..":")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("BaseButton", "icon")
					:SetSize(12, 12)
					:SetMargin(0, 4, 0, 0)
					:SetShown(self._state:Publisher("topItem"):MapNonNil(UIUtils.GetDisplayItemName):ToBooleanNotEquals(nil))
					:SetBackground(self._state:Publisher("topItem"))
					:SetTooltip(self._state:Publisher("topItem"))
				)
				:AddChild(UIElements.New("BaseButton", "item")
					:SetWidth("AUTO")
					:SetFont("ITEM_XSMALL")
					:SetText(self._state:Publisher("topItem"):MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil("-"))
					:SetTooltip(self._state:Publisher("topItem"))
				)
			)
	end

	-- Computed state properties
	self._state:PublisherForFunctionWithKeys(private.ChangeToTrendIcon, "change", "changeInverted")
		:AssignToTableKey(self._state, "trendIcon")
end

---Sets the labels.
---@param headingLabel string The heading label
---@param totalLabel string The total amount label
---@param avgLabel string The average amount label
---@return self
function DashboardDetailsRow:SetLabels(headingLabel, totalLabel, avgLabel)
	self._state.headingLabel = headingLabel
	self._state.totalLabel = totalLabel..":"
	self._state.avgLabel = avgLabel..":"
	return self
end

---Set the total amount.
---@param value number|ReactivePublisherSchemaBase The value or a publisher
---@return self
function DashboardDetailsRow:SetTotalAmount(value)
	if type(value) == "number" then
		self._state.totalAmount = value
	else
		self:_MethodPublisher(value, "SetTotalAmount")
	end
	return self
end

---Set the average amount.
---@param value number|ReactivePublisherSchemaBase The value or a publisher
---@return self
function DashboardDetailsRow:SetAverageAmount(value)
	if type(value) == "number" then
		self._state.avgAmount = value
	else
		self:_MethodPublisher(value, "SetAverageAmount")
	end
	return self
end

---Sets the change in the total amount from the previous period, which is shown as a trend arrow.
---@param value? number|ReactivePublisherSchemaBase The value or a publisher
---@return self
function DashboardDetailsRow:SetChange(value)
	if value == nil or type(value) == "number" then
		self._state.change = value
	else
		self:_MethodPublisher(value, "SetChange")
	end
	return self
end

---Shows an increase in the total amount as a negative trend.
---@return self
function DashboardDetailsRow:InvertChangeColors()
	self._state.changeInverted = true
	return self
end

---Set the top item.
---@param value? string|ReactivePublisherSchemaBase The value or a publisher
---@return self
function DashboardDetailsRow:SetTopItem(value)
	if value == nil or type(value) == "string" then
		self._state.hasTopItem = true
		self._state.topItem = value
	else
		self:_MethodPublisher(value, "SetTopItem")
	end
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AmountToString(amount)
	amount = Math.Round(amount)
	local color = amount < 0 and Theme.GetColor("error/main"):GetTextColorPrefix() or nil
	return Money.ToStringForUI(amount, color)
end

function private.ChangeToTrendIcon(change, inverted)
	if not change or change == 0 then
		return nil
	end
	local isIncrease = change > 0
	local key = isIncrease and "iconPack.12x12/Chevron/Up" or "iconPack.12x12/Chevron/Down"
	return TextureAtlas.GetColoredKey(key, isIncrease ~= inverted and "positive/main" or "error/main")
end

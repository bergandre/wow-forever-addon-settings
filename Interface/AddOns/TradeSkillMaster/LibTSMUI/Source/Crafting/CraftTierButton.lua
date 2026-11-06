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
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftTierButton = ComponentRegistry.Define("CraftTierButton", "BaseFrame")
CraftTierButton._STATE_SCHEMA = CraftTierButton._STATE_SCHEMA:Extend("CraftTierButtonState")
	:AddBooleanField("selected", false)
	:AddBooleanField("mouseOver", false)
	:AddOptionalStringField("craftString")
	:AddOptionalNumberField("cost")
	:AddOptionalNumberField("profit")
	:AddNumberField("concentration", 0)
	:Commit()
CraftTierButton:_AddActionScripts("OnClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftTierButton:Acquire()
	self.__super:Acquire()
	self:SetMouseEnabled(true)
	self:SetRoundedCorners("ALL", 8)
	self.__super:SetScript("OnMouseDown", self:__closure("_HandleClick"))
	self.__super:SetScript("OnEnter", self:__closure("_HandleFrameEnter"))
	self.__super:SetScript("OnLeave", self:__closure("_HandleFrameLeave"))
	self:SetLayout("VERTICAL")
	self:SetPadding(4)
	for _ in self._state:WithAutoStorePaused() do
		self:SetRoundedBackgroundColor(self._state:Publisher([[mouseOver and "container/medium+HOVER" or "container/medium"]]))
		self:SetBorderColor(self._state:Publisher([[selected and "outline/main" or nil]]))
		local craftStringPublisher = self._state:Publisher("craftString")
			:IgnoreNil()
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetHeight(20)
			:SetPadding(4, 4, 0, 0)
			:SetLayout("HORIZONTAL")
			:SetRoundedBackgroundColor(craftStringPublisher:Map(private.CraftStringToCraftedQualityColorKey))
			:AddChild(UIElements.New("BaseButton", "icon")
				:SetWidth("AUTO")
				:SetText(craftStringPublisher:Map(private.CraftStringToCraftedQuality))
				:SetTooltip(self._state:Publisher("craftString"):MapNonNil(Profession.GetItemStringByCraftString))
			)
			:AddChild(UIElements.New("Text", "text")
				:SetJustifyH("RIGHT")
				:SetTextColor("container/lowest")
				-- TODO: display how much concentration is needed
				:SetText(self._state:Publisher("concentration"):ToBooleanGreaterThanOrEquals(1):ReplaceBooleanWith(select(2, TradeSkill.GetConcentrationUIConstants()), ""))
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "prices")
			:SetLayout("VERTICAL")
			:SetMargin(0, 0, 4, 0)
			:SetPadding(4)
			:AddChild(UIElements.New("BaseFrame", "cost")
				:SetHeight(20)
				:SetLayout("HORIZONTAL")
				:AddChild(UIElements.New("Text", "label")
					:SetWidth("AUTO")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetText(L["Cost"]..":")
				)
				:AddChild(UIElements.New("Text", "value")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_XSMALL")
					:SetText(self._state:PublisherForFunctionWithKeys(private.CostToString, "cost"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "profit")
				:SetHeight(20)
				:SetLayout("HORIZONTAL")
				:AddChild(UIElements.New("Text", "label")
					:SetWidth("AUTO")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetText(L["Profit"]..":")
				)
				:AddChild(UIElements.New("Text", "value")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_XSMALL")
					:SetText(self._state:PublisherForFunctionWithKeys(private.ProfitToString, "profit"))
				)
			)
		)
		self:AddCancellable(craftStringPublisher:EndShare())
	end
end

---Sets the craft string.
---@param craftString string The craft string
---@param concentration number The required concentration amount
---@return self
function CraftTierButton:SetCraftString(craftString, concentration)
	self._state.craftString = craftString
	self._state.concentration = concentration
	return self
end

---Sets the prices for this button.
---@param cost? number The crafting cost
---@param profit? number The profit
---@return self
function CraftTierButton:SetPrices(cost, profit)
	self._state.cost = cost
	self._state.profit = profit
	return self
end

---Sets whether or not the button is selected.
---@param selected boolean The selected state
---@return self
function CraftTierButton:SetSelected(selected)
	self._state.selected = selected
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftTierButton.__private:_HandleClick()
	self:_SendActionScript("OnClick", self._state.craftString, self._state.concentration)
end

function CraftTierButton.__private:_HandleFrameEnter()
	self._state.mouseOver = true
end

function CraftTierButton.__private:_HandleFrameLeave()
	if not self._frame:IsMouseEnabled() then
		return
	end
	self._state.mouseOver = false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CraftStringToCraftedQualityColorKey(craftString)
	local craftQuality = CraftString.GetQuality(craftString)
	if not craftQuality then
		return "container/lowest"
	end
	local useMidnightIcon = TradeSkill.IsMidnightRecipe(CraftString.GetSpellId(craftString))
	return Theme.GetCraftedQualityColorKey(craftQuality, useMidnightIcon)
end

function private.CraftStringToCraftedQuality(craftString)
	local craftQuality = CraftString.GetQuality(craftString)
	local useMidnightIcon = TradeSkill.IsMidnightRecipe(CraftString.GetSpellId(craftString))
	return TradeSkill.GetCraftedQualityChatIcon(craftQuality, useMidnightIcon, true)
end

function private.CostToString(cost)
	return cost and Money.ToStringForUI(cost, Theme.GetColor("error/main"):GetTextColorPrefix()) or "---"
end

function private.ProfitToString(profit)
	return profit and Money.ToStringForUI(profit, Theme.GetColor(profit >= 0 and "positive/main" or "error/main"):GetTextColorPrefix()) or "---"
end

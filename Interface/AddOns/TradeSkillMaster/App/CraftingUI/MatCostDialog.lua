-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MatCostDialog = UIElements.Define("MatCostDialog", "CustomStringDialog")
MatCostDialog._STATE_SCHEMA = MatCostDialog._STATE_SCHEMA:Extend("MatCostDialogState")
	:AddDeferredStringField("itemString")
	:AddBooleanField("hasCustomValue", false)
	:AddDeferredStringField("defaultValue")
	:Commit()
MatCostDialog:_AddActionScripts("OnRestockClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Configures the mat cost dialog.
---@param itemString string The item string
---@param value? string The current value
---@param defaultValue string The default value
---@param validateFunc SyntaxInputValidateFunc The validation function
---@return self
function MatCostDialog:Configure(itemString, value, defaultValue, validateFunc)
	self._state.itemString = itemString
	self._state.hasCustomValue = value ~= nil
	self._state.defaultValue = defaultValue
	self.__super:Configure(L["Material Cost"], value or defaultValue, validateFunc)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MatCostDialog.__protected:_AddHeaderElements()
	local itemStringPublisher = self._state:Publisher("itemString")
		:Share()
	local resetDisabledPublisher = self._state:Publisher([[(hasCustomValue or validationError) and true or false]])
		:InvertBoolean()
		:Share()
	self:AddChild(UIElements.New("BaseFrame", "item")
		:SetLayout("HORIZONTAL")
		:SetHeight(36)
		:SetPadding(6)
		:SetMargin(0, 0, 0, 10)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:SetManager(self._childManager)
		:AddChild(UIElements.New("BaseButton", "icon")
			:SetWidth(24)
			:SetMargin(0, 8, 0, 0)
			:SetBackground(itemStringPublisher:MapNonNil(ItemInfo.GetTexture))
			:SetTooltip(itemStringPublisher)
		)
		:AddChild(UIElements.New("Text", "name")
			:SetMargin(0, 8, 0, 0)
			:SetFont("ITEM_BODY1")
			:SetText(itemStringPublisher:MapNonNil(UIUtils.GetDisplayItemName):CoalesceNil("?"))
		)
		:AddChild(UIElements.New("SmallTertiaryActionButton", "resetBtn")
			:SetWidth("AUTO")
			:SetPadding(8, 8, 0, 0)
			:SetDisabled(resetDisabledPublisher)
			:SetText(L["Reset to Default"])
			:SetAction("OnClick", "ACTION_RESET")
		)
	)
	itemStringPublisher:EndShare()
	resetDisabledPublisher:EndShare()
end

---@param manager UIManager<MatCostDialogState>
---@param state MatCostDialogState
function MatCostDialog.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_RESET" then
		assert(state.itemString)
		Crafting.SetMatCustomValue(state.itemString, nil)
		state.hasCustomValue = false
		local defaultValue = state.defaultValue
		assert(defaultValue)
		local copper = tonumber(defaultValue)
		state.stringInput
			:SetValue(copper and Money.ToStringExact(copper) or defaultValue)
			:Draw()
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function MatCostDialog.__protected:_HandleValue(value)
	if self:_IsDefault(value) and not self._state.hasCustomValue then
		return
	end
	assert(self._state.itemString)
	Crafting.SetMatCustomValue(self._state.itemString, value)
	self._state.hasCustomValue = true
end

function MatCostDialog.__protected:_HandleValueChanged(value)
	if not value then
		return
	end
	self._state.hasCustomValue = not self:_IsDefault(value)
end

function MatCostDialog.__private:_IsDefault(value)
	return gsub(value, "[\r\n ]", "") == gsub(self._state.defaultValue, "[\r\n ]", "")
end

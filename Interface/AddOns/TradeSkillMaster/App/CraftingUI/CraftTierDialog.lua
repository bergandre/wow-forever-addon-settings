-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local TradeSkill = App:From("LibTSMWoW"):Include("API.TradeSkill")
local Profession = App:From("LibTSMService"):Include("Profession")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftTierDialog = UIElements.Define("CraftTierDialog", "BaseFrame")
CraftTierDialog._STATE_SCHEMA = CraftTierDialog._STATE_SCHEMA:Extend("CraftTierDialogState")
	:AddDeferredUIElementField("innerFrame", "BaseFrame")
	:AddBooleanField("hasCraftString", false)
	:Commit()
CraftTierDialog:_AddActionScripts("OnQualityChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftTierDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function CraftTierDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetSize(254, 118)
		:SetPadding(1)
		:SetMouseEnabled(true)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 4, 0)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(28)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetJustifyH("CENTER")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(L["Select Tier"])
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, 4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "options")
			:SetLayout("HORIZONTAL")
			:SetHeight(88)
			:SetPadding(4, 0, 4, 4)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("BaseFrame", "inner")
				:SetLayout("HORIZONTAL")
				:SetHeight(88)
				:BindElement(self._state, "innerFrame")
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)
end

---Sets the craft string which options should be displayed for.
---@param craftString string The craft string
function CraftTierDialog:SetCraftString(craftString)
	assert(not self._state.hasCraftString)
	self._state.hasCraftString = true
	local selectedQuality = CraftString.GetQuality(craftString)
	local foundSelectedQuality = false
	local numOptions = 0
	local maxQuality = TradeSkill.GetMaxQualityForRecipe(CraftString.GetSpellId(craftString)) or 0
	for quality = 1, maxQuality do
		local qualityCraftString = CraftString.SetQuality(craftString, quality)
		if Profession.GetIndexByCraftString(qualityCraftString) then
			local isSelected = quality == selectedQuality
			foundSelectedQuality = foundSelectedQuality or isSelected
			local cost, _, profit, concentration = Crafting.GetCostsByCraftString(qualityCraftString)
			self._state.innerFrame:AddChild(UIElements.New("CraftTierButton", "button_"..quality)
				:SetSize(120, 80)
				:SetMargin(0, 4, 0, 0)
				:SetCraftString(qualityCraftString, concentration or 0)
				:SetPrices(cost, profit)
				:SetSelected(isSelected)
				:SetAction("OnClick", "ACTION_UPDATE_QUALITY")
			)
			numOptions = numOptions + 1
		end
	end
	self:SetWidth(max(numOptions, 2) * 124 + 6)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<CraftTierDialogState>
---@param state CraftTierDialogState
function CraftTierDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_UPDATE_QUALITY" then
		local craftString, concentration = ...
		self:_SendActionScript("OnQualityChanged", craftString, concentration)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end

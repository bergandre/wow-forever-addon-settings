-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkedAuctioningBidPercentInput = ComponentRegistry.Define("OperationLinkedAuctioningBidPercentInput", "OperationLinkedSettingLine")
OperationLinkedAuctioningBidPercentInput._STATE_SCHEMA = OperationLinkedAuctioningBidPercentInput._STATE_SCHEMA:Extend("OperationLinkedAuctioningBidPercentInputState")
	:AddDeferredUIElementField("input", "Input")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedAuctioningBidPercentInput:__init()
	self.__super:__init()
	self._childManager:SuppressActionLog("ACTION_VALUE_CHANGED")
end

function OperationLinkedAuctioningBidPercentInput:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	self:SetLabel(L["Set bid as percentage of buyout"])
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Input", "input")
				:SetMargin(0, 8, 0, 0)
				:BindElement(self._state, "input")
				:SetValidateFunc(private.BidPercentValidateFunc)
				:SetDisabled(self._state:Publisher([[relationshipSet or disabled]]))
				:SetAction("OnValueChanged", "ACTION_VALUE_CHANGED")
				:SetTooltip(L["When posting auctions, the bid price will be calculated as a percentage of the buyout price based on this setting."], true)
			)
			:AddChild(UIElements.New("Text", "label")
				:SetWidth("AUTO")
				:SetFont("BODY_XSMALL")
				:SetFormattedText(L["Enter a value from %d - %d%%"], 0, 100)
				:SetTextColor(self._state:Publisher("relationshipSet"):ReplaceBooleanWith("on/surface%40", "on/surface/low"))
			)
		)
	end
end

---Sets the operation setting to display in the dropdown.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkedAuctioningBidPercentInput:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	self:_UpdateInputValue()
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param manager UIManager<OperationLinkedAuctioningBidPercentInputState>
---@param state OperationLinkedAuctioningBidPercentInputState
function OperationLinkedAuctioningBidPercentInput.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_VALUE_CHANGED" then
		local value = String.StrictMatchNumber(self._state.input:GetValue(), "^([0-9]+) *%%?$") / 100
		Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] = value
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function OperationLinkedAuctioningBidPercentInput.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	self:_UpdateInputValue()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationLinkedAuctioningBidPercentInput.__private:_UpdateInputValue()
	local value = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey]
	assert(type(value) == "number")
	self._state.input:SetValue((value * 100).."%")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.BidPercentValidateFunc(value)
	value = strmatch(value, "^([0-9]+) *%%?$")
	value = tonumber(value)
	if not value or value < 0 or value > 100 then
		return false, L["Bid percent must be between 0 and 100."]
	end
	return true
end

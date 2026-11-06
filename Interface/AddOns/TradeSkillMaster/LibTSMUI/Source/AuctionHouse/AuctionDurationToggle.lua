-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")
local BUTTON_PADDING = 16



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctionDurationToggle = ComponentRegistry.Define("AuctionDurationToggle", "Element")
AuctionDurationToggle._STATE_SCHEMA = AuctionDurationToggle._STATE_SCHEMA:Extend("AuctionDurationToggleState")
	:AddOptionalNumberField("value")
	:Commit()
AuctionDurationToggle:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function AuctionDurationToggle:__init()
	self.__super:__init(self:_CreateFrame())
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function AuctionDurationToggle:Acquire()
	self.__super:Acquire()
	local valuePublisher = self._state:Publisher("value")
		:Share()
	for duration = 1, #AuctionHouse.DURATIONS do
		self:_AddChild(UIElements.New("AuctionDurationToggleCheckbox", self._id.."_Option"..duration)
			:SetWidth("AUTO")
			:SetManager(self._childManager)
			:SetDuration(duration)
			:SetCheckedSilent(valuePublisher:ToBooleanEquals(duration))
			:SetAction("OnValueChanged", "ACTION_SET_VALUE")
		)
	end
	valuePublisher:EndShare()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the currently selected duration.
---@param duration number The auction duration
---@return self
function AuctionDurationToggle:SetValue(duration)
	self._childManager:ProcessAction("ACTION_SET_VALUE", duration)
	return self
end

---Get the selected option.
---@return number?
function AuctionDurationToggle:GetValue()
	return self._state.value
end

function AuctionDurationToggle:Draw()
	self.__super:Draw()
	local height = self:_GetDimension("HEIGHT")
	local checkboxWidth = (self:_GetDimension("WIDTH") / #self._children) + BUTTON_PADDING
	local offsetX = 0
	for _, checkbox in ipairs(self._children) do
		checkbox:SetSize(checkboxWidth, height)
		checkbox:WipeAnchors()
		checkbox:AddAnchor("TOPLEFT", offsetX, 0)
		offsetX = offsetX + checkboxWidth
		checkbox:Draw()
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<AuctionDurationToggleState>
---@param state AuctionDurationToggleState
function AuctionDurationToggle.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_VALUE" then
		local duration = ...
		assert(AuctionHouse.DURATIONS[duration])
		self._state.value = duration
		self:_SendActionScript("OnValueChanged", duration)
	else
		error("Unknown action: "..tostring(action))
	end
end

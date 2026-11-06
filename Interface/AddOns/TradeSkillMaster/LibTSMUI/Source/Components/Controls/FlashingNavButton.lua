-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local DURATION = 1
local MIN_ALPHA = 0.3
local RELATIVE_LEVEL = 21
local STATE_COLOR_LOOKUP = {
	SELECTED = "accent/main",
	HOVER = "on/surface",
	NORMAL = "on/surface/low",
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local FlashingNavButton = ComponentRegistry.Define("FlashingNavButton", "BaseButton")
FlashingNavButton._STATE_SCHEMA = FlashingNavButton._STATE_SCHEMA:Extend("FlashingNavButtonState")
	:UpdateFieldDefault("font", "BODY_BODY1_EXTRABOLD")
	:AddBooleanField("isSelected", false)
	:AddBooleanField("isMouseOver", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function FlashingNavButton:__init()
	self.__super:__init()
	self._ag = self:_CreateAnimationGroup(self._frame)
	self._ag:SetLooping("BOUNCE")
	self._alpha = self._ag:CreateAnimation("Alpha")
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_ENTER")
		:SuppressActionLog("ACTION_HANDLE_LEAVE")
end

function FlashingNavButton:Acquire()
	self.__super:Acquire()
	self._alpha:SetFromAlpha(1)
	self._alpha:SetToAlpha(MIN_ALPHA)
	self._alpha:SetDuration(DURATION)
	self:SetRelativeLevel(RELATIVE_LEVEL)
	self:SetScript("OnEnter", self._childManager:CallbackToProcessAction("ACTION_HANDLE_ENTER"))
	self:SetScript("OnLeave", self._childManager:CallbackToProcessAction("ACTION_HANDLE_LEAVE"))
	for _ in self._state:WithAutoStorePaused() do
		self:SetTextColor(self._state:Publisher([[(isSelected and "SELECTED") or (isMouseOver and "HOVER") or "NORMAL"]]):Map(STATE_COLOR_LOOKUP))
	end
end

function FlashingNavButton:Release()
	self._ag:Stop()
	self.__super:Release()
end

---Set whether or not the button is selected.
---@param value boolean|ReactivePublisherSchemaBase The selected state or a publisher
---@return self
function FlashingNavButton:SetSelected(value)
	if type(value) == "boolean" then
		self._state.isSelected = value
	else
		self:_MethodPublisher(value, "SetSelected")
	end
	return self
end

---Sets whether or not the animation is playing.
---@param value boolean|ReactivePublisherSchemaBase Whether the animation should be playing or not or a publisher
---@return self
function FlashingNavButton:SetPlaying(value)
	if type(value) == "boolean" then
		self._ag:TSMSetPlaying(value)
	else
		self:_MethodPublisher(value, "SetPlaying")
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<FlashingNavButtonState>
---@param state FlashingNavButtonState
function FlashingNavButton.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ENTER" then
		state.isMouseOver = true
	elseif action == "ACTION_HANDLE_LEAVE" then
		state.isMouseOver = false
	else
		error("Unknown action: "..tostring(action))
	end
end

function FlashingNavButton.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		self.__super:_SendActionScript(script, self:GetText())
	else
		self.__super:_SendActionScript(script, ...)
	end
end

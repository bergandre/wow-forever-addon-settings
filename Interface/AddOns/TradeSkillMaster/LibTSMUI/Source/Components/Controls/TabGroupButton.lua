-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local STATE_COLOR_LOOKUP = {
	SELECTED = "accent/main",
	HOVER = "on/surface",
	NORMAL = "on/surface/low",
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local TabGroupButton = ComponentRegistry.Define("TabGroupButton", "BaseButton")
TabGroupButton._STATE_SCHEMA = TabGroupButton._STATE_SCHEMA:Extend("TabGroupButtonState")
	:UpdateFieldDefault("font", "BODY_BODY1_EXTRABOLD")
	:AddBooleanField("isSelected", false)
	:AddBooleanField("isMouseOver", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TabGroupButton:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_ENTER")
		:SuppressActionLog("ACTION_HANDLE_LEAVE")
end

function TabGroupButton:Acquire()
	self.__super:Acquire()
	self:SetScript("OnEnter", self._childManager:CallbackToProcessAction("ACTION_HANDLE_ENTER"))
	self:SetScript("OnLeave", self._childManager:CallbackToProcessAction("ACTION_HANDLE_LEAVE"))
	for _ in self._state:WithAutoStorePaused() do
		self:SetTextColor(self._state:Publisher([[(isSelected and "SELECTED") or (isMouseOver and "HOVER") or "NORMAL"]]):Map(STATE_COLOR_LOOKUP))
	end
end

---Set whether or not the button is selected.
---@param value boolean|ReactivePublisherSchemaBase The selected state or a publisher
---@return self
function TabGroupButton:SetSelected(value)
	if type(value) == "boolean" then
		self._state.isSelected = value
	else
		self:_MethodPublisher(value, "SetSelected")
	end
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function TabGroupButton.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		return self.__super:_SendActionScript(script, self:GetText())
	else
		return self.__super:_SendActionScript(script, ...)
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<TabGroupButtonState>
---@param state TabGroupButtonState
function TabGroupButton.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ENTER" then
		state.isMouseOver = true
	elseif action == "ACTION_HANDLE_LEAVE" then
		state.isMouseOver = false
	else
		error("Unknown action: "..tostring(action))
	end
end

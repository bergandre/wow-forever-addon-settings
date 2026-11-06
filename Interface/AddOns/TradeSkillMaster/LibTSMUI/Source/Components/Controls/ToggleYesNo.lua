-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ToggleYesNo = ComponentRegistry.Define("ToggleYesNo", "Element")
ToggleYesNo._STATE_SCHEMA = ToggleYesNo._STATE_SCHEMA:Extend("ToggleYesNoState")
	:AddDeferredUIElementField("toggleFrame", "BaseFrame")
	:AddDeferredUIElementField("yesCheckbox", "Checkbox")
	:AddDeferredUIElementField("noCheckbox", "Checkbox")
	:AddBooleanField("value", false)
	:AddBooleanField("disabled", false)
	:Commit()
ToggleYesNo:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ToggleYesNo:__init()
	local frame = self:_CreateFrame()
	frame:EnableMouse(true)
	self._frame = frame
	self.__super:__init(frame)
	self._setSettingInfo = false
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_SET_YES")
		:SuppressActionLog("ACTION_SET_NO")
end

function ToggleYesNo:Acquire()
	self.__super:Acquire()
	local valuePublisher = self._state:Publisher("value")
		:Share()
	local disabledPublisher = self._state:Publisher("disabled")
		:Share()
	self:_AddChild(UIElements.New("BaseFrame", "toggle")
		:SetLayout("HORIZONTAL")
		:AddAnchor("TOPLEFT", self._frame)
		:AddAnchor("BOTTOMRIGHT", self._frame)
		:BindElement(self._state, "toggleFrame")
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Checkbox", "yes")
			:SetWidth("AUTO")
			:SetTheme("RADIO")
			:SetText(YES)
			:BindElement(self._state, "yesCheckbox")
			:SetCheckedSilent(valuePublisher)
			:SetDisabled(disabledPublisher)
			:SetAction("OnValueChanged", "ACTION_SET_YES")
			:PropagateScript("OnEnter")
			:PropagateScript("OnLeave")
		)
		:AddChild(UIElements.New("Checkbox", "no")
			:SetWidth("AUTO")
			:SetTheme("RADIO")
			:SetMargin(8, 0, 0, 0)
			:SetText(NO)
			:BindElement(self._state, "noCheckbox")
			:SetCheckedSilent(valuePublisher:InvertBoolean())
			:SetDisabled(disabledPublisher)
			:SetAction("OnValueChanged", "ACTION_SET_NO")
			:PropagateScript("OnEnter")
			:PropagateScript("OnLeave")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:PropagateScript("OnEnter")
		:PropagateScript("OnLeave")
	)
	valuePublisher:EndShare()
	disabledPublisher:EndShare()
end

function ToggleYesNo:Release()
	self._setSettingInfo = false
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the setting info which ties the value of the toggle to the key of a table.
---@param tbl table The table which the value is stored in
---@param key string The key at which the value is stored
---@return self
function ToggleYesNo:SetSettingInfo(tbl, key)
	assert(not self._setSettingInfo)
	self._setSettingInfo = true
	self._state.value = tbl[key]
	self._state:Publisher("value")
		:AssignToTableKey(tbl, key)
	return self
end

---Enables or disables the toggle.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the toggle is disabled or a publisher
---@param redraw? boolean Whether or not to redraw the toggle
---@return self
function ToggleYesNo:SetDisabled(value, redraw)
	if type(value) == "boolean" then
		self._state.disabled = value
		if redraw then
			self:Draw()
		end
	else
		assert(redraw == nil)
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end

---Set the value of the toggle.
---@param value boolean Whether the toggle is on (true) or off (false)
---@param redraw? boolean Whether or not to redraw the toggle
---@return self
function ToggleYesNo:SetValue(value, redraw)
	if value ~= self._state.value then
		self._state.value = value
		self._bindings:Process("VALUE", value)
		self:_SendActionScript("OnValueChanged", value)
	end
	if redraw then
		self:Draw()
	end
	return self
end

---Get the value of the toggle.
---@return boolean
function ToggleYesNo:GetValue()
	return self._state.value
end

---Binds a state property to the toggle value.
---@param state ReactiveState The state to store the values in
---@param key string The state key to store the value at
function ToggleYesNo:BindValue(state, key)
	self._bindings:Add("VALUE", state, key)
	return self
end

function ToggleYesNo:Draw()
	self.__super:Draw()
	self._state.toggleFrame:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<ToggleYesNoState>
---@param state ToggleYesNoState
function ToggleYesNo.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_YES" then
		if not state.yesCheckbox:IsChecked() then
			state.yesCheckbox:SetCheckedSilent(true)
			return
		end
		self:SetValue(true, true)
	elseif action == "ACTION_SET_NO" then
		if not state.noCheckbox:IsChecked() then
			state.noCheckbox:SetCheckedSilent(true)
			return
		end
		self:SetValue(false, true)
	else
		error("Unknown action: "..tostring(action))
	end
end

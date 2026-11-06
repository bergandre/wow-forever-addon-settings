-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SettingsCustomStringInputWithResetLine = ComponentRegistry.Define("SettingsCustomStringInputWithResetLine", "BaseFrame")
SettingsCustomStringInputWithResetLine._STATE_SCHEMA = SettingsCustomStringInputWithResetLine._STATE_SCHEMA:Extend("SettingsCustomStringInputWithResetLineState")
	:AddDeferredUIElementField("input", "CustomStringSingleLineInput")
	:AddBooleanField("disabled", false)
	:AddBooleanField("isDefaultValue", false)
	:AddStringField("label", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SettingsCustomStringInputWithResetLine:__init()
	self.__super:__init()
	self._settings = nil ---@type SettingsView!
	self._key = nil ---@type string!
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function SettingsCustomStringInputWithResetLine:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		local disabledPublisher = self._state:Publisher("disabled")
			:Share()
		self:SetLayout("VERTICAL")
		self:AddChild(UIElements.New("Text", "label")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 2)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetTextColor(disabledPublisher:ReplaceBooleanWith("on/surface%40", "on/surface"))
			:SetText(self._state:Publisher("label"))
		)
		self:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("CustomStringSingleLineInput", "input")
				:SetMargin(0, 8, 0, 0)
				:BindElement(self._state, "input")
				:SetDisabled(disabledPublisher)
			)
			:AddChild(UIElements.New("SmallSecondaryActionButton", "resetButton")
				:SetWidth("AUTO")
				:SetPadding(16, 16, 0, 0)
				:SetText(L["Reset"])
				:SetDisabled(self._state:Publisher([[isDefaultValue or disabled]]))
				:SetAction("OnClick", "ACTION_RESET")
			)
		)
		self:AddCancellable(disabledPublisher:EndShare())
	end
end

function SettingsCustomStringInputWithResetLine:Release()
	self._settings = nil
	self._key = nil
	self.__super:Release()
end

---Sets the setting info.
---@param settings SettingsView The settings view
---@param key string The setting key
---@return self
function SettingsCustomStringInputWithResetLine:SetSettingInfo(settings, key)
	self._settings = settings
	self._key = key
	self:AddCancellable(settings:PublisherForKey(key)
		:ToBooleanEquals(settings:GetDefaultReadOnly(key))
		:AssignToTableKey(self._state, "isDefaultValue")
	)
	self._state.input:SetSettingInfo(settings, key)
	return self
end

---Configures the text shown by the element.
---@param label string The label
---@param tooltip string The tooltip
---@return self
function SettingsCustomStringInputWithResetLine:ConfigureText(label, tooltip)
	self._state.label = label
	self._state.input
		:SetPopoutTitle(label)
		:SetTooltip(tooltip, true)
	return self
end

---Sets the bad sources for the custom string input.
---@param badSources? table<string,any> The bad sources as keys
---@return self
function SettingsCustomStringInputWithResetLine:SetBadSources(badSources)
	self._state.input:SetBadSources(badSources)
	return self
end

---Set the disabled state.
---@param value boolean|ReactivePublisherSchemaBase The disabled state or a publisher
---@return self
function SettingsCustomStringInputWithResetLine:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.disabled = value
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<SettingsCustomStringInputWithResetLineState>
---@param state SettingsCustomStringInputWithResetLineState
function SettingsCustomStringInputWithResetLine.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_RESET" then
		self._settings:ResetToDefault(self._key)
		state.input
			:SetValue(self._settings[self._key])
			:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

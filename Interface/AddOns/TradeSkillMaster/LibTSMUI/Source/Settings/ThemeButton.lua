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

local ThemeButton = ComponentRegistry.Define("ThemeButton", "BaseFrame")
ThemeButton._STATE_SCHEMA = ThemeButton._STATE_SCHEMA:Extend("ThemeButtonState")
	:AddOptionalStringField("key")
	:AddStringField("name", "")
	:AddOptionalStringField("activeKey")
	:AddBooleanField("hideIfInactive", false)
	:Commit()
ThemeButton:_AddActionScripts("OnSelected")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ThemeButton:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function ThemeButton:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(198, 140)
	self:SetPadding(0, 0, 12, 8)
	for _ in self._state:WithAutoStorePaused() do
		self:SetShown(self._state:Publisher([[key == activeKey or not hideIfInactive]]))
		local keyPublisher = self._state:Publisher("key")
			:IgnoreNil()
			:Share()
		self:SetRoundedBackgroundColor(keyPublisher:ToStringFormat("container/medium:%s"))
		self:SetBorderColor(keyPublisher:ToStringFormat("outline/main:%s"), 1)
		self:AddChild(UIElements.New("BaseFrame", "top")
			:SetLayout("HORIZONTAL")
			:SetHeight(36)
			:SetMargin(8, 8, 0, 12)
			:AddChild(UIElements.New("BaseFrame", "left")
				:SetLayout("VERTICAL")
				:SetSize(36, 36)
				:SetMargin(0, 12, 0, 0)
				:AddChild(UIElements.New("BaseFrame", "primary")
					:SetHeight(16)
					:SetMargin(0, 0, 0, 4)
					:SetRoundedBackgroundColor(keyPublisher:ToStringFormat("primary/main:%s"))
				)
				:AddChild(UIElements.New("BaseFrame", "secondary")
					:SetHeight(16)
					:SetRoundedBackgroundColor(keyPublisher:ToStringFormat("secondary/main:%s"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "right")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("BaseFrame", "line1")
					:SetHeight(12)
					:SetMargin(0, 0, 0, 12)
					:SetRoundedBackgroundColor(keyPublisher:ToStringFormat("container/high:%s"))
				)
				:AddChild(UIElements.New("BaseFrame", "line2")
					:SetHeight(12)
					:SetRoundedBackgroundColor(keyPublisher:ToStringFormat("container/low:%s"))
				)
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "line3")
			:SetMargin(8, 8, 0, 12)
			:SetRoundedBackgroundColor(keyPublisher:ToStringFormat("container/lowest:%s"))
		)
		self:AddChild(UIElements.New("BaseTexture", "divider")
			:SetHeight(1)
			:SetColor(keyPublisher:ToStringFormat("outline/main:%s"))
		)
		self:AddChild(UIElements.New("Checkbox", "checkbox")
			:SetHeight(20)
			:SetMargin(8, 0, 8, 0)
			:SetTheme("RADIO")
			:SetManager(self._childManager)
			:SetText(self._state:Publisher("name"))
			:SetCheckedSilent(self._state:Publisher([[key == activeKey]]))
			:SetAction("OnValueChanged", "ACTION_SET_ACTIVE")
		)
		self:AddChildNoLayout(UIElements.New("BaseButton", "btn")
			:AddAnchor("TOPLEFT")
			:AddAnchor("BOTTOMRIGHT")
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_SET_ACTIVE")
		)
		self:AddCancellable(keyPublisher:EndShare())
	end
end

---Configures the theme button.
---@param key string The theme key
---@param name string The name of the theme
---@param activeThemePublisher ReactivePublisherSchemaShared A publisher for the key of the currently active theme
---@param hideIfInactive boolean Hide the button if the theme isn't active
---@return self
function ThemeButton:Configure(key, name, activeThemePublisher, hideIfInactive)
	self._state.key = key
	self._state.name = name
	self._state.hideIfInactive = hideIfInactive
	self:_AssignStateKeyPublisher(activeThemePublisher, "activeKey")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<ThemeButtonState>
---@param state ThemeButtonState
function ThemeButton.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_ACTIVE" then
		self:_SendActionScript("OnSelected", state.key)
	else
		error("Unknown action: "..tostring(action))
	end
end

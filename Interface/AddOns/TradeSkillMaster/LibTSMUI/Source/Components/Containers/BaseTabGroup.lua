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

local BaseTabGroup = ComponentRegistry.Define("BaseTabGroup", "ViewContainer", "ABSTRACT")
BaseTabGroup._STATE_SCHEMA = BaseTabGroup._STATE_SCHEMA:Extend("BaseTabGroupState")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddBooleanField("tabsDisabled", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BaseTabGroup:__init()
	self.__super:__init()
	self._tabs = {}
	self._tabButtons = {}
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function BaseTabGroup:Acquire()
	self.__super:Acquire()
	self:_AddChild(UIElements.New("BaseFrame", "content")
		:SetLayout("HORIZONTAL")
		:AddAnchor("TOPLEFT")
		:AddAnchor("TOPRIGHT")
		:SetHeight(self:_GetContentPadding("TOP"))
		:BindElement(self._state, "contentFrame")
	)
end

function BaseTabGroup:Release()
	wipe(self._tabs)
	wipe(self._tabButtons)
	self.__super:Release()
end

---Add a path.
---@param path string The path
---@param setSelected? boolean Sets this as the selected path (false by default)
---@return self
function BaseTabGroup:AddPath(path, setSelected)
	assert(not self._tabs[path])
	local button = nil
	for _ in self._state:WithAutoStorePaused() do
		button = UIElements.New("TabGroupButton", "tabButton_"..gsub(path, " ", ""))
			:SetManager(self._childManager)
			:SetText(path)
			:SetSelected(self._state:Publisher("path"):ToBooleanEquals(path))
			:SetDisabled(self._state:Publisher("tabsDisabled"))
			:SetAction("OnClick", "ACTION_SET_PATH")
	end
	local tab = self:_CreateTab(path, button)
	self._tabs[path] = tab
	self._tabButtons[path] = button
	self._state.contentFrame:AddChild(tab)
	self.__super:AddPath(path, setSelected)
	return self
end

---Sets whether or not the tabs are disabled.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the tabs are disabled or a publisher
---@return self
function BaseTabGroup:SetTabsDisabled(value)
	if type(value) == "boolean" then
		self._state.tabsDisabled = value
	else
		self:_MethodPublisher(value, "SetTabsDisabled")
	end
	return self
end

function BaseTabGroup:Draw()
	self.__super.__super:Draw()
	self._state.contentFrame:Draw()
	self.__super:Draw()
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param manager UIManager<BaseTabGroupState>
---@param state BaseTabGroupState
function BaseTabGroup.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_PATH" then
		local path = ...
		self:SetPath(path, self:GetPath() ~= path)
	else
		error("Unknown action: "..tostring(action))
	end
end

---@return Element
function BaseTabGroup.__abstract:_CreateTab(path, button) ---@diagnostic disable-line: missing-return
	-- Must be implemented by subclass
end

---@param button BaseButton
function BaseTabGroup.__protected:_HandleButtonClick(button)
	local path = button:GetText()
	self:SetPath(path, self:GetPath() ~= path)
end

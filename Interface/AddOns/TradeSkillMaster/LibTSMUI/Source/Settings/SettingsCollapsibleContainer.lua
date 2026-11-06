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

local SettingsCollapsibleContainer = ComponentRegistry.Define("SettingsCollapsibleContainer", "BaseFrame")
SettingsCollapsibleContainer._STATE_SCHEMA = SettingsCollapsibleContainer._STATE_SCHEMA:Extend("SettingsCollapsibleContainerState")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddDeferredUIElementField("headingLabel", "Text")
	:AddDeferredUIElementField("descriptionLabel", "Text")
	:AddStringField("headingText", "")
	:AddStringField("description", "")
	:AddNumberField("descriptionHeight", 20)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SettingsCollapsibleContainer:Acquire()
	self.__super:Acquire()
	self.__super:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self.__super:AddChild(UIElements.New("Text", "heading")
			:SetHeight(20)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(self._state:Publisher("headingText"))
			:BindElement(self._state, "headingLabel")
		)
		self.__super:AddChild(UIElements.New("Text", "description")
			:SetHeight(self._state:Publisher("descriptionHeight"))
			:SetMargin(0, 0, 2, 0)
			:SetFont("BODY_XSMALL")
			:SetTextColor("on/surface/low")
			:SetText(self._state:Publisher("description"))
			:SetShown(self._state:Publisher("description"):ToBooleanNotEquals(""))
			:BindElement(self._state, "descriptionLabel")
		)
		self.__super:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetMargin(0, 0, 8, 0)
			:BindElement(self._state, "contentFrame")
		)
	end
end

---Sets the heading and description label text.
---@param heading string The heading
---@param description string The description
---@return self
function SettingsCollapsibleContainer:SetHeadingDescription(heading, description)
	self._state.headingText = heading
	self._state.description = description
	return self
end

---Uses the larger heading style for a top-level section of a page.
---@return self
function SettingsCollapsibleContainer:SetLargeHeading()
	self._state.headingLabel
		:SetHeight(24)
		:SetFont("BODY_BODY1_EXTRABOLD")
	self._state.descriptionLabel
		:SetMargin(0, 0, 4, 0)
		:SetFont("BODY_SMALL_SEMIBOLD")
	return self
end

---Sets the height of the description.
---@param height number The height
---@return self
function SettingsCollapsibleContainer:SetDescriptionHeight(height)
	self._state.descriptionHeight = height
	return self
end

---Sets the layout of the content frame.
---@param layout FrameLayout The frame layout
---@return self
function SettingsCollapsibleContainer:SetLayout(layout)
	self._state.contentFrame:SetLayout(layout)
	return self
end

---Adds a child element to the content frame.
---@param child Element The child element
---@return self
function SettingsCollapsibleContainer:AddChild(child)
	self._state.contentFrame:AddChild(child)
	return self
end

---Add a child element when the required condition is true.
---@param condition boolean The required condition
---@param child Element The child element
---@return self
function SettingsCollapsibleContainer:AddChildIf(condition, child)
	self._state.contentFrame:AddChildIf(condition, child)
	return self
end

---Add child elements using a function.
---@param func fun(container: Container, ...: any) The function to call which will add children
---@param ... any Additional arguments to pass to the function
---@return self
function SettingsCollapsibleContainer:AddChildrenWithFunction(func, ...)
	self._state.contentFrame:AddChildrenWithFunction(func, ...)
	return self
end

---Binds the content element to a state property (cleared when the element is released).
---@param state ReactiveState The state
---@param key string The state key
---@return self
function SettingsCollapsibleContainer:BindContentElement(state, key)
	self._state.contentFrame:BindElement(state, key)
	return self
end

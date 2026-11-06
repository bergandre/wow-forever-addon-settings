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

local CollapsibleContainer = ComponentRegistry.Define("CollapsibleContainer", "BaseFrame")
CollapsibleContainer._STATE_SCHEMA = CollapsibleContainer._STATE_SCHEMA:Extend("CollapsibleContainerState")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddStringField("headingText", "")
	:AddBooleanField("collapsed", true)
	:AddBooleanField("setContext", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CollapsibleContainer:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function CollapsibleContainer:Acquire()
	self.__super:Acquire()
	self:SetRoundedBackgroundColor("container/low")
	self.__super:SetLayout("VERTICAL")
	self.__super:SetPadding(12, 12, 8, 8)
	for _ in self._state:WithAutoStorePaused() do
		self.__super:AddChild(UIElements.New("BaseFrame", "heading")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseButton", "expander")
				:SetMargin(0, 4, 0, 0)
				:SetAction("OnClick", "ACTION_TOGGLE_EXPAND")
				:SetBackgroundAndSize(self._state:Publisher("collapsed"):ReplaceBooleanWith("iconPack.18x18/Caret/Right", "iconPack.18x18/Caret/Down"))
			)
			:AddChild(UIElements.New("Text", "text")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(self._state:Publisher("headingText"))
			)
		)
		self.__super:AddChild(UIElements.New("BaseFrame", "content")
			:BindElement(self._state, "contentFrame")
			:SetShown(self._state:Publisher("collapsed"):InvertBoolean())
		)
	end
end

---Sets the context table and key where to store the collapsed state.
---@param tbl table The table
---@param key string The key
---@return self
function CollapsibleContainer:SetContextTable(tbl, key)
	assert(type(tbl) == "table" and type(key) == "string")
	assert(not self._state.setContext)
	self._state.setContext = true
	self._state.collapsed = tbl[key] and true or false
	self._state:Publisher("collapsed")
		:AssignToTableKey(tbl, key)
	return self
end

---Set the heading text.
---@param value string|ReactivePublisherSchemaBase The heading text or a publisher
---@return self
function CollapsibleContainer:SetHeadingText(value)
	if type(value) == "string" then
		self._state.headingText = value
	else
		self:_MethodPublisher(value, "SetHeadingText")
	end
	return self
end

---@private
function CollapsibleContainer:SetPadding(left, right, top, bottom)
	error("CollapsibleContainer doesn't support this method")
end

---Sets the layout of the content frame.
---@param layout FrameLayout The frame layout
---@return self
function CollapsibleContainer:SetLayout(layout)
	self._state.contentFrame:SetLayout(layout)
	return self
end

---Adds a child element to the content frame.
---@param child Element The child element
---@return self
function CollapsibleContainer:AddChild(child)
	self._state.contentFrame:AddChild(child)
	return self
end

---Add a child element when the required condition is true.
---@param condition boolean The required condition
---@param child Element The child element
---@return self
function CollapsibleContainer:AddChildIf(condition, child)
	self._state.contentFrame:AddChildIf(condition, child)
	return self
end

---Add child elements using a function.
---@param func fun(container: Container, ...: any) The function to call which will add children
---@param ... any Additional arguments to pass to the function
---@return self
function CollapsibleContainer:AddChildrenWithFunction(func, ...)
	self._state.contentFrame:AddChildrenWithFunction(func, ...)
	return self
end

---Binds the content element to a state property (cleared when the element is released).
---@param state ReactiveState The state
---@param key string The state key
---@return self
function CollapsibleContainer:BindContentElement(state, key)
	self._state.contentFrame:BindElement(state, key)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<CollapsibleContainerState>
---@param state CollapsibleContainerState
function CollapsibleContainer.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE_EXPAND" then
		self._state.collapsed = not self._state.collapsed
		-- TODO: is there a better way to notify the elements up the stack that our size has changed?
		self:GetBaseElement():Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

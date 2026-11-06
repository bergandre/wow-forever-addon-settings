-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local NineSlice = LibTSMUI:IncludeClassType("NineSlice")
local Rectangle = LibTSMUI:IncludeClassType("Rectangle")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local Widgets = LibTSMUI:Include("Util.Widgets")
local Scrollbar = LibTSMUI:Include("Util.Scrollbar")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMUI:From("LibTSMUtil"):Include("Lua.Vararg")
local Reactive = LibTSMUI:From("LibTSMReactive"):Include("Reactive")
local UIBindings = LibTSMUI:From("LibTSMReactive"):IncludeClassType("UIBindings")
local UIManager = LibTSMUI:From("LibTSMReactive"):IncludeClassType("UIManager")
local ScriptWrapper = LibTSMUI:From("LibTSMWoW"):Include("API.ScriptWrapper")
local private = {}
local ANCHOR_REL_PARENT = newproxy(false)
local PROPAGATE = newproxy(false)



-- ============================================================================
-- Class Definition / Static Class Functions
-- ============================================================================

local Element = ComponentRegistry.Define("Element", nil, "ABSTRACT")

Element._STATE_SCHEMA = Reactive.CreateStateSchema("ElementState")
	:AddBooleanField("acquired", false)
	:AddOptionalNumberField("width")
	:AddOptionalNumberField("height")
	:AddOptionalNumberField("parentLevel")
	:AddOptionalNumberField("relativeLevel")
	:AddNumberField("marginLeft", 0)
	:AddNumberField("marginRight", 0)
	:AddNumberField("marginTop", 0)
	:AddNumberField("marginBottom", 0)
	:AddNumberField("paddingLeft", 0)
	:AddNumberField("paddingRight", 0)
	:AddNumberField("paddingTop", 0)
	:AddNumberField("paddingBottom", 0)
	:Commit()
Element._ACTION_SCRIPTS = {}

function Element.__static._AddActionScripts(cls, ...)
	cls._ACTION_SCRIPTS = CopyTable(cls._ACTION_SCRIPTS)
	for _, script in Vararg.Iterator(...) do
		assert(not cls._ACTION_SCRIPTS[script])
		cls._ACTION_SCRIPTS[script] = true
	end
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Element:__init(frame)
	self._id = nil ---@type string!
	self._frame = frame ---@type FrameExtended
	frame:TSMSetDebugObject(self)
	self._scripts = {}
	self._baseElementCache = nil
	self._parent = nil ---@type Element?
	self._children = {}
	self._context = nil
	self._tooltip = nil
	self._tooltipAnchorToParent = false
	self._anchors = {}
	self._cancellables = {}
	self._publishers = {} ---@type ReactivePublisher[]
	self._state = self._STATE_SCHEMA:CreateState()
		:SetAutoStore(self._publishers)
		:SetAutoDisable(true)
	self._manager = nil
	self._inheritedManager = nil
	self._scriptAction = {}
	self._scriptActionCallbackFuncs = {}
	self._bindings = UIBindings.Create()

	self._state:Publisher([[parentLevel and relativeLevel and (parentLevel + relativeLevel) or nil]])
		:IgnoreNil()
		:CallMethod(self._frame, "SetFrameLevel")
end

function Element:__tostring()
	local parentId = self._parent and self._parent._id
	return self.__class.__name..":"..(parentId and (parentId..".") or "")..(self._id or "?")
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the ID of the element.
---@param id? string
function Element:SetId(id)
	-- Should only be called by core UI code before acquiring the element
	assert(not self._state.acquired)
	self._id = id or tostring(self)
end

---Acquire the element.
function Element:Acquire()
	assert(not self._state.acquired)
	self._state.acquired = true
	self:SetShown(true)
	self._state
		:SetAutoStore(self._cancellables)
		:SetAutoDisable(false)
	for _, publisher in ipairs(self._publishers) do
		publisher:EnableAndReset()
	end
end

---Release the element.
function Element:Release()
	assert(self._state.acquired)
	if self._state.relativeLevel and self._state.parentLevel then
		self._state.relativeLevel = 1
	end
	self:ReleaseAllChildren()

	self._bindings:Process("LIFECYCLE", nil)
	self._bindings:Clear()
	for _, publisher in ipairs(self._publishers) do
		publisher:Disable()
	end
	for _, cancellable in pairs(self._cancellables) do
		cancellable:Cancel()
	end
	wipe(self._cancellables)
	self._state:ResetToDefault()

	local frame = self._frame

	-- Clear the OnLeave script before hiding the frame (otherwise it'll get called)
	if self._scripts.OnLeave then
		ScriptWrapper.Clear(frame, "OnLeave")
		self._scripts.OnLeave = nil
	end

	if self._tooltip and TooltipUI.IsVisible(frame) then
		-- Hide the tooltip
		TooltipUI.Hide()
	end

	self:SetShown(false)
	frame:ClearAllPoints()
	frame:SetParent(nil)
	frame:SetScale(1)

	-- Clear scripts
	for script in pairs(self._scripts) do
		ScriptWrapper.Clear(frame, script)
	end

	wipe(self._scripts)
	wipe(self._scriptAction)
	self._manager = nil
	self._inheritedManager = nil
	self._baseElementCache = nil
	self._parent = nil
	self._context = nil
	self._tooltip = nil
	self._tooltipAnchorToParent = false
	wipe(self._anchors)

	ComponentRegistry.Recycle(self)
end

---Show the element.
---@return self
function Element:Show()
	return self:SetShown(true)
end

---Hide the element.
---@return self
function Element:Hide()
	return self:SetShown(false)
end

---Sets whether or not the element is shown.
---@param value boolean|ReactivePublisherSchemaBase The shown state or a publisher
---@return self
function Element:SetShown(value)
	if type(value) == "boolean" then
		if value then
			self._frame:Show()
		else
			self._frame:Hide()
		end
	else
		self:_MethodPublisher(value, "SetShown")
	end
	return self
end

---Returns whether or not the element is visible.
---@return boolean
function Element:IsVisible()
	return self._frame:IsVisible()
end

---Sets the width of the element.
---@param value? number|ReactivePublisherSchemaBase The width of the element, nil to have an undefined width, or a publisher
---@return self
function Element:SetWidth(value)
	if value == nil or type(value) == "number" then
		self._state.width = value
	else
		self:_MethodPublisher(value, "SetWidth")
	end
	return self
end

---Sets the height of the element.
---@param value? number|ReactivePublisherSchemaBase The height of the element, nil to have an undefined height, or a publisher
---@return self
function Element:SetHeight(value)
	if value == nil or type(value) == "number" then
		self._state.height = value
	else
		self:_MethodPublisher(value, "SetHeight")
	end
	return self
end

---Sets the width and height of the element.
---@param width? number The width of the element, or nil to have an undefined width
---@param height? number The height of the element, or nil to have an undefined height
---@return self
function Element:SetSize(width, height)
	self._state.width = width
	self._state.height = height
	return self
end

---Sets the padding of the element.
---@param leftOrAll number The left padding value if all arguments are passed or the value of all sides if a single argument is passed
---@param right? number The right padding value if all arguments are passed
---@param top? number The top padding value if all arguments are passed
---@param bottom? number The bottom padding value if all arguments are passed
---@overload fun(all: number): self
---@overload fun(left: number, right: number, top: number, bottom: number): self
---@return self
function Element:SetPadding(leftOrAll, right, top, bottom)
	if not right and not top and not bottom then
		right = leftOrAll
		top = leftOrAll
		bottom = leftOrAll
	end
	assert(type(leftOrAll) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number")
	self._state.paddingLeft = leftOrAll
	self._state.paddingRight = right
	self._state.paddingTop = top
	self._state.paddingBottom = bottom
	return self
end

---Sets the margin of the element.
---@param leftOrAll number The left margin value if all arguments are passed or the value of all sides if a single argument is passed
---@param right? number The right margin value if all arguments are passed
---@param top? number The top margin value if all arguments are passed
---@param bottom? number The bottom margin value if all arguments are passed
---@overload fun(all: number): self
---@overload fun(left: number, right: number, top: number, bottom: number): self
---@return self
function Element:SetMargin(leftOrAll, right, top, bottom)
	if not right and not top and not bottom then
		right = leftOrAll
		top = leftOrAll
		bottom = leftOrAll
	end
	assert(type(leftOrAll) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number")
	self._state.marginLeft = leftOrAll
	self._state.marginRight = right
	self._state.marginTop = top
	self._state.marginBottom = bottom
	return self
end

---Sets the relative level of this element with regards to its parent.
---@param value number|ReactivePublisherSchemaBase The relative level of this element or a publisher
---@return self
function Element:SetRelativeLevel(value)
	if type(value) == "number" then
		self._state.relativeLevel = value
	else
		self:_MethodPublisher(value, "SetRelativeLevel")
	end
	return self
end

---Wipes the element's anchors.
---@return self
function Element:WipeAnchors()
	wipe(self._anchors)
	return self
end

---Adds an anchor to the element.
---@param ... any The anchor arguments (following WoW's SetPoint() arguments)
---@return self
function Element:AddAnchor(...)
	local numArgs = select("#", ...)
	local point, relFrame, relPoint, x, y = nil, nil, nil, nil, nil
	if numArgs == 1 then
		point = ...
	elseif numArgs == 2 then
		point, relFrame = ...
	elseif numArgs == 3 then
		local arg2 = select(2, ...)
		if type(arg2) == "number" then
			point, x, y = ...
		else
			point, relFrame, relPoint = ...
		end
	elseif numArgs == 4 then
		point, relFrame, x, y = ...
	elseif numArgs == 5 then
		point, relFrame, relPoint, x, y = ...
	else
		error("Invalid anchor")
	end
	tinsert(self._anchors, point)
	tinsert(self._anchors, relFrame or ANCHOR_REL_PARENT)
	tinsert(self._anchors, relPoint or point)
	tinsert(self._anchors, x or 0)
	tinsert(self._anchors, y or 0)
	return self
end

---Gets the top-most element in the tree.
---@return ApplicationFrame
function Element:GetBaseElement()
	if not self._baseElementCache then
		local element = self
		local parent = element:GetParentElement()
		while parent do
			local temp = element
			element = parent
			parent = temp:GetParentElement()
		end
		self._baseElementCache = element
	end
	assert(ComponentRegistry.IsType(self._baseElementCache, "ApplicationFrame") or ComponentRegistry.IsType(self._baseElementCache, "OverlayApplicationFrame"))
	return self._baseElementCache --[[@as ApplicationFrame]]
end

---Draws the top-most element in the tree.
function Element:DrawBaseElement()
	self:GetBaseElement():Draw()
end

---Gets the parent element's base frame.
---@return Frame
function Element:GetParent()
	local parent = self:GetParentElement()
	assert(parent)
	return parent:_GetBaseFrame()
end

---Gets the parent element.
---@return Element?
function Element:GetParentElement()
	return self._parent
end

---Releases all children elements.
---@return self
function Element:ReleaseAllChildren()
	for _, child in ipairs(self._children) do
		child:Release()
	end
	wipe(self._children)
	return self
end

---Sets the tooltip of the element.
---@param value string|number|function|nil|ReactivePublisherSchemaBase The value passed to `TooltipUI.Show()` when the user hovers over the element, nil to clear it, or a publisher
---@param anchorToParent? boolean Anchor the tooltip to the parent element instead
---@return self
function Element:SetTooltip(value, anchorToParent)
	if type(value) ~= "table" then
		---@cast value string|number|function|nil
		self._tooltip = value
		if value then
			-- setting OnEnter/OnLeave will implicitly enable the mouse, so make sure it's previously been enabled
			assert(self._frame:IsMouseEnabled())
			self._tooltipAnchorToParent = anchorToParent and true or false
			self:SetScript("OnEnter", private.HandleOnEnter)
			self:SetScript("OnLeave", private.HandleOnLeave)
		else
			assert(anchorToParent == nil)
			self:SetScript("OnEnter", nil)
			self:SetScript("OnLeave", nil)
		end
	else
		assert(anchorToParent == nil)
		self:_MethodPublisher(value, "SetTooltip")
	end
	return self
end

---Shows a tooltip on the element.
---@param tooltip any The value passed to `TooltipUI.Show()` when the user hovers over the element
---@param noWrapping? boolean Disables wrapping of text lines
---@param xOffset? number An extra x offset to apply to the anchor of the tooltip
---@return self
function Element:ShowTooltip(tooltip, noWrapping, xOffset)
	TooltipUI.Show(self._frame, tooltip, noWrapping, xOffset)
	return self
end

---Sets the context value of the element.
---@param context any The context value
---@return self
function Element:SetContext(context)
	self._context = context
	return self
end

---Gets the context value from the element.
---@return any
function Element:GetContext()
	return self._context
end

---Registers a script handler.
---@param script string The script to register for
---@param handler? fun(element: self, ...) The script handler which will be called with the element plus any arguments to the script
---@return self
function Element:SetScript(script, handler)
	self._scripts[script] = handler
	if handler then
		ScriptWrapper.Set(self._frame, script, handler, self)
	else
		ScriptWrapper.Clear(self._frame, script)
	end
	return self
end

---Sets a script to propagate to the parent element.
---@param script string The script to propagate
---@return self
function Element:PropagateScript(script)
	self._scripts[script] = PROPAGATE
	ScriptWrapper.SetPropagate(self._frame, script, self)
	return self
end

---Takes ownership of a cancellable publisher.
---@param publisher ReactivePublisher The cancellable publisher to own
---@return self
function Element:AddCancellable(publisher)
	if self._state.acquired then
		publisher:StoreIn(self._cancellables)
	else
		publisher:Disable()
		publisher:StoreIn(self._publishers)
	end
	return self
end

---Sets the UI manager for the element.
---@param manager UIManager The UI manager
---@return self
function Element:SetManager(manager)
	assert(not self._manager)
	self._manager = manager
	return self
end

---Sets the UI manager action to send for one of the element's scripts.
---@param script string The script to send the action for
---@param action string The action to send (along with any arguments)
---@return self
function Element:SetAction(script, action)
	assert(self._ACTION_SCRIPTS[script])
	assert(not self._scriptAction[script])
	self._scriptAction[script] = action
	return self
end

---Overrides the UI manager action to send for one of the element's scripts.
---@param script string The script to send the action for
---@param action string The action to send (along with any arguments)
---@return self
function Element:OverrideAction(script, action)
	assert(self._ACTION_SCRIPTS[script])
	assert(self._scriptAction[script])
	self._scriptAction[script] = action
	return self
end

---Binds the element to a state property (cleared when the element is released).
---@param state ReactiveState The state
---@param key string The state key
---@return self
function Element:BindElement(state, key)
	self._bindings:Add("LIFECYCLE", state, key)
	-- Handle the bind action manually since there may be other binds already set for the lifecycle action
	state[key] = self
	return self
end

---Sends an action to the element's UI element for processing.
---@param action string The action to process
---@param ... any Additional arguments to send with the action
---@return self
function Element:WithProcessAction(action, ...)
	self:_GetManager():ProcessAction(action, ...)
	return self
end

---Subscribes to a publisher to draw the element.
---@param publisher ReactivePublisherSchemaBase The publisher
---@return self
function Element:DrawPublisher(publisher)
	self:_MethodPublisher(publisher, "Draw")
	return self
end

---Draws the element.
function Element:Draw()
	assert(self._state.acquired)
	local frame = self._frame ---@type Region
	local parentFrame = frame:GetParent() --[[@as Frame?]]
	if #self._anchors > 0 then
		frame:ClearAllPoints()
		for _, point, relFrame, relPoint, x, y in Table.StrideIterator(self._anchors, 5) do
			if relFrame == ANCHOR_REL_PARENT then
				relFrame = parentFrame
			elseif type(relFrame) == "table" and relFrame.__isa and relFrame:__isa(Element) then
				-- This is an element - anchor to its base frame instead
				relFrame = relFrame:_GetBaseFrame()
			end
			if relFrame == parentFrame and relPoint == point then
				frame:SetPoint(point, x, y)
			else
				frame:SetPoint(point, relFrame, relPoint, x, y)
			end
		end
	end
	local width = self._state.width
	if width then
		self:_SetDimension("WIDTH", width)
	end
	local height = self._state.height
	if height then
		self:_SetDimension("HEIGHT", height)
	end
	self._state.parentLevel = parentFrame and parentFrame:GetFrameLevel() or nil
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function Element.__private:_GetManager()
	if self._manager then
		return self._manager
	elseif self._inheritedManager then
		return self._inheritedManager
	end
	local parent = self:GetParentElement()
	while parent do
		local manager = parent._manager or parent._inheritedManager
		if manager then
			self._inheritedManager = manager
			return manager
		end
		parent = parent:GetParentElement()
	end
	error("No manager found")
end

---Creates a UI manager for the element.
---@param actionHandler UIManagerActionHandler
---@return UIManager
function Element.__protected:_CreateUIManager(actionHandler)
	return UIManager.Create("ELEMENT_"..tostring(self.__class.__name), self._state, actionHandler)
end

---Returns a function which can be used as a callback to send the specified action script.
---@param action string The action to be processed
---@return fun(...)
function Element.__protected:_CallbackToSendActionScript(action)
	if not self._scriptActionCallbackFuncs[action] then
		local sendFunc = self:__closure("_SendActionScript")
		self._scriptActionCallbackFuncs[action] = function(...)
			return sendFunc(action, ...)
		end
	end
	return self._scriptActionCallbackFuncs[action]
end

---Send an action script to the registered UI manager.
---@param script string The action script to send
---@param ... any The arguments
function Element.__protected:_SendActionScript(script, ...)
	assert(self._ACTION_SCRIPTS[script])
	local action = self._scriptAction[script]
	if action then
		self:_GetManager():ProcessAction(action, ...)
	end
end

---Gets a one-shot publisher which is owned by the element.
---@param value any The value to publish
---@param forceStorePersistent? boolean Force the publisher to be stored persistently (across acquire/release lifecycles)
---@return ReactivePublisherSchema
function Element.__protected:_GetOneShotPublisher(value, forceStorePersistent)
	local cancellablesTbl = (not self._state.acquired or forceStorePersistent) and self._publishers or self._cancellables
	return Reactive.GetOneShotPublisher(value, not self._state.acquired, cancellablesTbl)
end

---Helper function for registering a publisher which calls a method on the element.
---@param publisher ReactivePublisherSchemaBase The publisher
---@param method string The name of the method
---@param arg? any An additional argument to pass to the method
---@return self
function Element.__protected:_MethodPublisher(publisher, method, arg)
	if publisher:IsShared() then
		-- Don't store shared publishers
		publisher:CallMethod(self, method, arg)
	else
		---@cast publisher ReactivePublisherSchema
		self:AddCancellable(publisher:CallMethod(self, method, arg))
	end
	return self
end

---Helper function for registering a publisher which calls a method on the element.
---@param publisher ReactivePublisherSchemaBase The publisher
---@param func fun(value: any, arg: any) The function to call
---@param arg any An additional argument to pass to the function
---@return self
function Element.__protected:_FunctionPublisher(publisher, func, arg)
	if publisher:IsShared() then
		-- Don't store shared publishers
		publisher:CallFunction(func, arg)
	else
		---@cast publisher ReactivePublisherSchema
		self:AddCancellable(publisher:CallFunction(func, arg))
	end
	return self
end

---Helper function for registering a publisher which sets a state key.
---@param publisher ReactivePublisherSchemaBase The publisher
---@param key string The state key to assign to
---@return self
function Element.__protected:_AssignStateKeyPublisher(publisher, key)
	if publisher:IsShared() then
		-- Don't store shared publishers
		publisher:AssignToTableKey(self._state, key)
	else
		---@cast publisher ReactivePublisherSchema
		self:AddCancellable(publisher:AssignToTableKey(self._state, key))
	end
	return self
end

---Helper function for configuring a database query to call a function when it is updated.
---@param query DatabaseQuery The query
---@param func fun(query: DatabaseQuery) The function to call
---@return self
function Element.__protected:_AddQueryUpdatePublisher(query, func)
	self:AddCancellable(query:Publisher()
		:CallFunction(func)
	)
	return self
end

---@return FrameExtended
function Element.__protected:_CreateFrame(parentFrame)
	parentFrame = parentFrame or self._frame
	local frame = Widgets.CreateFrame(self, parentFrame)
	return frame
end

---@return ScrollFrameExtended
function Element.__protected:_CreateScrollFrame(parentFrame)
	parentFrame = parentFrame or self._frame
	return Widgets.CreateScrollFrame(self, parentFrame)
end

---@return ButtonExtended
function Element.__protected:_CreateButton(parentFrame, name, isSecure)
	parentFrame = parentFrame or self._frame
	return Widgets.CreateButton(self, parentFrame, name, isSecure)
end

---@return EditBoxExtended
function Element.__protected:_CreateEditBox(parentFrame)
	parentFrame = parentFrame or self._frame
	return Widgets.CreateEditBox(self, parentFrame)
end

---@param parentFrame? Frame
---@param layer? DrawLayer
---@param subLayer? number
---@return TextureExtended
function Element.__protected:_CreateTexture(parentFrame, layer, subLayer)
	parentFrame = parentFrame or self._frame
	return Widgets.CreateTexture(self, parentFrame, layer, subLayer)
end

---@return FontStringExtended
function Element.__protected:_CreateFontString(parentFrame)
	parentFrame = parentFrame or self._frame
	return Widgets.CreateFontString(self, parentFrame)
end

---@return AnimationGroupExtended
function Element.__protected:_CreateAnimationGroup(texture)
	return Widgets.CreateAnimationGroup(texture)
end

---@return Rectangle
function Element.__protected:_CreateRectangle(subLayer, parentFrame)
	parentFrame = parentFrame or self._frame
	return Rectangle.New(parentFrame, subLayer)
end

---@return NineSlice
function Element.__protected:_CreateNineSlice(subLayer, parentFrame)
	parentFrame = parentFrame or self._frame
	return NineSlice.New(parentFrame, subLayer)
end

---@return Scrollbar
function Element.__protected:_CreateScrollbar(isHorizontal)
	local parentFrame = self._frame
	return Scrollbar.Create(self, parentFrame, isHorizontal)
end

function Element:_AddChild(child)
	assert(child:__isa(Element) and not child:_GetBaseFrame():GetParent())
	tinsert(self._children, child)
	child:_GetBaseFrame():SetParent(self._frame)
	child:_SetParentElement(self)
end

function Element:_RemoveChild(child)
	assert(child:__isa(Element) and child:_GetBaseFrame():GetParent())
	assert(Table.RemoveByValue(self._children, child) == 1)
	child:Release()
end

function Element:_SetParentElement(parent)
	self._parent = parent
	self:_ClearBaseElementCache()
end

function Element:_ClearBaseElementCache()
	self._baseElementCache = nil
	self._inheritedManager = nil
	for _, child in ipairs(self._children) do
		child:_ClearBaseElementCache()
	end
end

function Element:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" then
		local width = self._state.width
		return width or 0, width == nil
	elseif dimension == "HEIGHT" then
		local height = self._state.height
		return height or 0, height == nil
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_GetPreferredDimension(dimension)
	if dimension == "WIDTH" then
		return nil
	elseif dimension == "HEIGHT" then
		return nil
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_GetDimension(dimension)
	if dimension == "WIDTH" then
		return self._frame:GetWidth()
	elseif dimension == "HEIGHT" then
		return self._frame:GetHeight()
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_SetDimension(dimension, ...)
	if dimension == "WIDTH" then
		self._frame:SetWidth(...)
	elseif dimension == "HEIGHT" then
		self._frame:SetHeight(...)
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

---@return Frame
function Element:_GetBaseFrame()
	return self._frame
end

function Element:_GetPadding(side)
	if side == "LEFT" then
		return self._state.paddingLeft
	elseif side == "RIGHT" then
		return self._state.paddingRight
	elseif side == "TOP" then
		return self._state.paddingTop
	elseif side == "BOTTOM" then
		return self._state.paddingBottom
	else
		error("Unknown side: "..tostring(side))
	end
end

function Element:_GetPaddingAnchorOffsets(anchor)
	local xPart, yPart = private.SplitAnchor(anchor)
	local x = xPart and ((xPart == "LEFT" and 1 or -1) * self:_GetPadding(xPart)) or 0
	local y = yPart and ((yPart == "BOTTOM" and 1 or -1) * self:_GetPadding(yPart)) or 0
	return x, y
end

function Element:_GetMargin(side)
	if side == "LEFT" then
		return self._state.marginLeft
	elseif side == "RIGHT" then
		return self._state.marginRight
	elseif side == "TOP" then
		return self._state.marginTop
	elseif side == "BOTTOM" then
		return self._state.marginBottom
	else
		error("Unknown side: "..tostring(side))
	end
end

function Element:_GetMarginAnchorOffsets(anchor)
	local xPart, yPart = private.SplitAnchor(anchor)
	local x = xPart and ((xPart == "LEFT" and 1 or -1) * self:_GetMargin(xPart)) or 0
	local y = yPart and ((yPart == "BOTTOM" and 1 or -1) * self:_GetMargin(yPart)) or 0
	return x, y
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SplitAnchor(anchor)
	if anchor == "BOTTOMLEFT" then
		return "LEFT", "BOTTOM"
	elseif anchor == "BOTTOM" then
		return nil, "BOTTOM"
	elseif anchor == "BOTTOMRIGHT" then
		return "RIGHT", "BOTTOM"
	elseif anchor == "RIGHT" then
		return "RIGHT", nil
	elseif anchor == "TOPRIGHT" then
		return "RIGHT", "TOP"
	elseif anchor == "TOP" then
		return nil, "TOP"
	elseif anchor == "TOPLEFT" then
		return "LEFT", "TOP"
	elseif anchor == "LEFT" then
		return "LEFT", nil
	else
		error("Invalid anchor: "..tostring(anchor))
	end
end

---@param element Element
function private.HandleOnEnter(element)
	local frame = nil
	---@diagnostic disable: invisible
	if element._tooltipAnchorToParent then
		local parentElement = element:GetParentElement()
		assert(parentElement)
		frame = parentElement:_GetBaseFrame()
	else
		frame = element:_GetBaseFrame()
	end
	TooltipUI.Show(frame, element._tooltip)
	---@diagnostic enable: invisible
end

function private.HandleOnLeave()
	TooltipUI.Hide()
end

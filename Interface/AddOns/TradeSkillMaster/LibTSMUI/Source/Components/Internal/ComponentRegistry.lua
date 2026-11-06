-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:InitInternal("ComponentRegistry")
local ObjectPool = LibTSMUI:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local LibTSMClass = LibStub("LibTSMClass")
local private = {
	elementClasses = {},
	objectPools = {}, ---@type table<any,ObjectPool>
	namedElements = {},
	activeFrameElementMap = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Defines and registers a UI element subclass.
---@defclass T : P
---@generic T : Class<P>
---@generic P : Class
---@param elementType `T` The name of the new element class
---@param parentElementType? `P` The name of the parent class (can only be nil for the base Element class)
---@param ... ClassProperties Any additional class modifiers to pass to LibTSMClass.DefineClass()
---@return T
function ComponentRegistry.Define(elementType, parentElementType, ...)
	local parentClass = parentElementType and private.elementClasses[parentElementType]
	assert(parentClass or not next(private.elementClasses))
	local class = LibTSMClass.DefineClass(elementType, parentClass, ...)
	assert(not private.elementClasses[class.__name])
	private.elementClasses[class.__name] = class
	return class
end

---Creates a new UI element.
---@generic T
---@param elementType `T` The name of the element class
---@param id string The id to assign to the element
---@return T
function ComponentRegistry.New(elementType, id)
	return private.NewElementHelper(elementType, id, nil)
end

---Creates a new named UI element.
---@generic T
---@param elementType `T` The name of the element class
---@param id string The id to assign to the element
---@param name string The global name of the element
---@return T
function ComponentRegistry.NewNamed(elementType, id, name)
	assert(name)
	return private.NewElementHelper(elementType, id, name)
end

---Recycles a UI element.
---@param element Element The UI element object
function ComponentRegistry.Recycle(element)
	private.activeFrameElementMap[element:_GetBaseFrame()] = nil
	if not Table.KeyByValue(private.namedElements, element) then
		private.objectPools[element.__class]:Recycle(element)
	end
end

---Check if an object is an `Element` or not.
---@generic T: Element
---@param obj table The object to check
---@param elementType `T` The element type to check for
---@type-narrows 1 2
---@return boolean
function ComponentRegistry.IsType(obj, elementType)
	local class = private.elementClasses[elementType]
	assert(class)
	return obj.__isa and obj:__isa(class)
end

---Gets a UI element by its frame (for debugging purposes).
---@param frame Frame The frame
---@return Element?
function ComponentRegistry.GetByFrame(frame)
	return private.activeFrameElementMap[frame]
end



-- ============================================================================
-- ReactiveStateSchema Extensions
-- ============================================================================

local ReactiveStateSchemaExtensions = LibTSMUI:From("LibTSMReactive"):ExtendClass("ReactiveStateSchema")

---Defines an optional UI element field as part of the schema which can be nil (and is by default).
---@generic T: Element
---@param key string The key of the new field
---@param elementType `T` The element type
---@builds-field 1 T?
---@return self
function ReactiveStateSchemaExtensions:AddOptionalUIElementField(key, elementType)
	local class = private.elementClasses[elementType]
	assert(class)
	return self:AddOptionalClassField(key, class)
end

---Defines an optional UI element field as part of the schema which can be nil (and is by default) but is defined with a non-nil assertion for the language server.
---@generic T: Element
---@param key string The key of the new field
---@param elementType `T` The element type
---@builds-field 1 T!
---@return self
function ReactiveStateSchemaExtensions:AddDeferredUIElementField(key, elementType)
	local class = private.elementClasses[elementType]
	assert(class)
	return self:AddDeferredClassField(key, class)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NewElementHelper(elementType, id, name)
	local class = private.elementClasses[elementType]
	if not class then
		error("Invalid elementType: "..tostring(elementType))
	end
	local element = nil
	if name then
		private.namedElements[name] = private.namedElements[name] or class(name)
		element = private.namedElements[name]
		assert(_G[name] == element:_GetBaseFrame())
	else
		if not private.objectPools[class] then
			private.objectPools[class] = ObjectPool.New("UI_"..class.__name, class, 1)
		end
		element = private.objectPools[class]:Get()
	end
	private.activeFrameElementMap[element:_GetBaseFrame()] = element
	element:SetId(id)
	element:Acquire()
	return element
end

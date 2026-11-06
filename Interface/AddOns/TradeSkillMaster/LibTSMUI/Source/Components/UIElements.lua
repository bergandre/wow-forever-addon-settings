-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Init("UIElements")
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")



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
function UIElements.Define(elementType, parentElementType, ...)
	return ComponentRegistry.Define(elementType, parentElementType, ...)
end

---Creates a new UI element.
---@generic T: Element
---@param elementType `T` The name of the element class
---@param id string The id to assign to the element
---@return T
function UIElements.New(elementType, id)
	return ComponentRegistry.New(elementType, id)
end

---Creates a new named UI element.
---@generic T: Element
---@param elementType `T` The name of the element class
---@param id string The id to assign to the element
---@param name string The global name of the element
---@return T
function UIElements.NewNamed(elementType, id, name)
	return ComponentRegistry.NewNamed(elementType, id, name)
end

---Check if an object is an `Element` or not.
---@generic T: Element
---@param obj table The object to check
---@param elementType `T` The element type to check for
---@type-narrows 1 2
---@return boolean
function UIElements.IsType(obj, elementType)
	return ComponentRegistry.IsType(obj, elementType)
end

---Gets a UI element by its frame (for debugging purposes).
---@param frame Frame The frame
---@return Element?
function UIElements.GetByFrame(frame)
	return ComponentRegistry.GetByFrame(frame)
end

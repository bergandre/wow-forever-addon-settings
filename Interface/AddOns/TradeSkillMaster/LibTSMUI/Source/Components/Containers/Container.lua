-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local Container = ComponentRegistry.Define("Container", "Element", "ABSTRACT")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Container:__init(frame)
	self.__super:__init(frame)
	self._layoutChildren = {}
	self._noLayoutChildren = {}
end

function Container:Release()
	wipe(self._layoutChildren)
	wipe(self._noLayoutChildren)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Release all child elements.
---@return self
function Container:ReleaseAllChildren()
	self.__super:ReleaseAllChildren()
	wipe(self._layoutChildren)
	wipe(self._noLayoutChildren)
	return self
end

---Adds a child element.
---@param child Element The child element
---@return self
function Container:AddChild(child)
	self:_AddChildHelper(child, true)
	return self
end

---Add a child element when the required condition is true.
---@param condition boolean The required condition
---@param child Element The child element
---@return self
function Container:AddChildIf(condition, child)
	if not condition then
		child:Release()
		return self
	end
	self:_AddChildHelper(child, true)
	return self
end

---Add child elements using a function.
---@param func fun(container: Container, ...: any) The function to call which will add children
---@param ... any Additional arguments to pass to the function
---@return self
function Container:AddChildrenWithFunction(func, ...)
	func(self, ...)
	return self
end

---Add a child element which has explicit layout performed by the application code.
---@param child Element The child element
---@return self
function Container:AddChildNoLayout(child)
	self:_AddChildHelper(child, false)
	return self
end

---Remove a child element.
---@param child Element The child element to remove
---@return self
function Container:RemoveChild(child)
	Table.RemoveByValue(self._layoutChildren, child)
	Table.RemoveByValue(self._noLayoutChildren, child)
	self:_RemoveChild(child)
	return self
end

---Iterates over all child elements involved in layout.
---@return fun(): number, Element @Iterator with fields: `index`, `child`
---@return table
---@return number
function Container:LayoutChildrenIterator()
	return private.VisibleChildrenIterator, self._layoutChildren, 0
end

function Container.Draw(self)
	self.__super:Draw()
	for _, child in ipairs(self._children) do
		child:Draw()
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Container:_GetNumLayoutChildren()
	local count = 0
	for _ in self:LayoutChildrenIterator() do
		count = count + 1
	end
	return count
end

function Container:_AddChildHelper(child, layout)
	self:_AddChild(child)
	tinsert(layout and self._layoutChildren or self._noLayoutChildren, child)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.VisibleChildrenIterator(tbl, index)
	while true do
		index = index + 1
		local child = tbl[index]
		if not child then
			return
		end
		if child:IsVisible() then
			return index, child
		end
	end
end

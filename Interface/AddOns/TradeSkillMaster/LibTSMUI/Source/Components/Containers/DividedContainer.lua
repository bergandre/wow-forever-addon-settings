-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local DIVIDER_SIZE = 2

---@class DividedContainerContextTable
---@field leftWidth number



-- ============================================================================
-- Element Definition
-- ============================================================================

local DividedContainer = ComponentRegistry.Define("DividedContainer", "BaseFrame")
DividedContainer._STATE_SCHEMA = DividedContainer._STATE_SCHEMA:Extend("DividedContainerState")
	:AddDeferredUIElementField("divider", "BaseButton")
	:AddDeferredUIElementField("leftContent", "BaseFrame")
	:AddDeferredUIElementField("rightContent", "BaseFrame")
	:AddBooleanField("resizing", false)
	:AddBooleanField("dividerHidden", false)
	:AddBooleanField("mouseOver", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DividedContainer:__init()
	self.__super:__init()
	self._resizeOffset = 0
	self._contextTable = nil ---@type DividedContainerContextTable!
	self._defaultContextTable = nil ---@type DividedContainerContextTable!
	self._minLeftWidth = nil ---@type number!
	self._minRightWidth = nil ---@type number!
	self._resizeStartX = nil
	self._isVertical = false
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_DIVIDER_ENTER")
		:SuppressActionLog("ACTION_HANDLE_DIVIDER_LEAVE")
		:SuppressActionLog("ACTION_HANDLE_DIVIDER_UPDATE")
end

function DividedContainer:Acquire()
	self.__super:Acquire()
	self.__super:SetLayout("HORIZONTAL")
	for _ in self._state:WithAutoStorePaused() do
		self.__super:AddChild(UIElements.New("BaseFrame", "leftContent")
			:SetLayout("FILL")
			:BindElement(self._state, "leftContent")
		)
		self.__super:AddChild(UIElements.New("BaseButton", "divider")
			:SetSize(DIVIDER_SIZE, nil)
			:SetHitRectInsets(-2, -2, 0, 0)
			:SetRelativeLevel(2)
			:EnableRightClick()
			:BindElement(self._state, "divider")
			:SetManager(self._childManager)
			:SetBackgroundWithHighlight(self._state:Publisher([[(not dividerHidden or mouseOver or resizing) and "outline/variant" or nil]]))
			:SetScript("OnMouseDown", self._childManager:CallbackToProcessAction("ACTION_HANDLE_DIVIDER_MOUSE_DOWN"))
			:SetScript("OnMouseUp", self._childManager:CallbackToProcessAction("ACTION_HANDLE_DIVIDER_MOUSE_UP"))
			:SetAction("OnClick", "ACTION_HANDLE_DIVIDER_CLICK")
			:SetScript("OnEnter", self._childManager:CallbackToProcessAction("ACTION_HANDLE_DIVIDER_ENTER"))
			:SetScript("OnLeave", self._childManager:CallbackToProcessAction("ACTION_HANDLE_DIVIDER_LEAVE"))
		)
		self.__super:AddChild(UIElements.New("BaseFrame", "rightContent")
			:SetLayout("FILL")
			:BindElement(self._state, "rightContent")
		)
	end
end

function DividedContainer:Release()
	self._isVertical = false
	self._resizeOffset = 0
	self._contextTable = nil
	self._defaultContextTable = nil
	self._minLeftWidth = nil
	self._minRightWidth = nil
	self._resizeStartX = nil
	self.__super:Release()
end

---Sets the divided container as vertical.
---@return self
function DividedContainer:SetVertical()
	assert(not self._isVertical)
	self._isVertical = true
	self._state.divider
		:SetSize(nil, DIVIDER_SIZE)
		:SetHitRectInsets(0, 0, -2, -2)
	self.__super:SetLayout("VERTICAL")
	return self
end

---Hides the divider
---@return self
function DividedContainer:HideDivider()
	self._state.dividerHidden = true
	return self
end

---@deprecated
function DividedContainer:SetLayout()
	error("DividedContainer doesn't support this method")
end

---@deprecated
function DividedContainer:AddChild()
	error("DividedContainer doesn't support this method")
end

---Sets the context table to preserve the divider position.
---@param tbl table The context table
---@param defaultTbl DividedContainerContextTable Default values
---@return self
function DividedContainer:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.leftWidth > 0)
	tbl.leftWidth = tbl.leftWidth or defaultTbl.leftWidth
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	return self
end

---Sets the context table from a settings object.
---@param settings SettingsView The settings object
---@param key string The setting key
---@return self
function DividedContainer:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

---Sets the minimum width of the child element.
---@param minLeftWidth number The minimum width of the left child element
---@param minRightWidth number The minimum width of the right child element
---@return self
function DividedContainer:SetMinWidth(minLeftWidth, minRightWidth)
	self._minLeftWidth = minLeftWidth
	self._minRightWidth = minRightWidth
	return self
end

---Sets the left child element.
---@param child Element The left child element
---@return self
function DividedContainer:SetLeftChild(child)
	assert(not self._isVertical)
	self:_AddDividedChild(child, true)
	return self
end

---Sets the right child element.
---@param child Element The right child element
---@return self
function DividedContainer:SetRightChild(child)
	assert(not self._isVertical)
	self:_AddDividedChild(child, false)
	return self
end

---Sets the top child element in vertical mode.
---@param child Element The top child element
---@return self
function DividedContainer:SetTopChild(child)
	assert(self._isVertical)
	self:_AddDividedChild(child, true)
	return self
end

---Sets the bottom child element in vertical mode.
---@param child Element The bottom child element
---@return self
function DividedContainer:SetBottomChild(child)
	assert(self._isVertical)
	self:_AddDividedChild(child, false)
	return self
end

function DividedContainer:Draw()
	assert(self._contextTable and self._minLeftWidth and self._minRightWidth)
	self.__super.__super.__super:Draw()

	local width = self:_GetDimension(self._isVertical and "HEIGHT" or "WIDTH") - DIVIDER_SIZE
	local leftWidth = self._contextTable.leftWidth + self._resizeOffset
	local rightWidth = width - leftWidth
	if rightWidth < self._minRightWidth then
		leftWidth = width - self._minRightWidth
		assert(leftWidth >= self._minLeftWidth)
	elseif leftWidth < self._minLeftWidth then
		leftWidth = self._minLeftWidth
	end
	self._contextTable.leftWidth = leftWidth - self._resizeOffset

	if self._isVertical then
		self._state.leftContent:SetHeight(leftWidth)
	else
		self._state.leftContent:SetWidth(leftWidth)
	end
	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<DividedContainerState>
---@param state DividedContainerState
function DividedContainer.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_DIVIDER_MOUSE_DOWN" then
		local _, mouseButton = ...
		if mouseButton ~= "LeftButton" then
			return
		end
		self._resizeStartX = select(self._isVertical and 2 or 1, GetCursorPosition()) / self._frame:GetEffectiveScale()
		self._resizeOffset = 0
		state.resizing = true
		state.divider:SetScript("OnUpdate", manager:CallbackToProcessAction("ACTION_HANDLE_DIVIDER_UPDATE"))
	elseif action == "ACTION_HANDLE_DIVIDER_MOUSE_UP" then
		local _, mouseButton = ...
		if mouseButton ~= "LeftButton" then
			return
		end
		self._contextTable.leftWidth = max(self._contextTable.leftWidth + self._resizeOffset, self._minLeftWidth)
		self._resizeOffset = 0
		self._resizeStartX = nil
		state.resizing = false
		state.divider:SetScript("OnUpdate", nil)
		self:Draw()
	elseif action == "ACTION_HANDLE_DIVIDER_CLICK" then
		local mouseButton = ...
		if mouseButton ~= "RightButton" then
			return
		end
		self._contextTable.leftWidth = self._defaultContextTable.leftWidth
		self:Draw()
	elseif action == "ACTION_HANDLE_DIVIDER_ENTER" then
		self._state.mouseOver = true
	elseif action == "ACTION_HANDLE_DIVIDER_LEAVE" then
		self._state.mouseOver = false
	elseif action == "ACTION_HANDLE_DIVIDER_UPDATE" then
		assert(self._resizeStartX)
		if self._isVertical then
			local currY = select(2, GetCursorPosition()) / self._frame:GetEffectiveScale()
			self._resizeOffset = self._resizeStartX - currY
		else
			local currX = GetCursorPosition() / self._frame:GetEffectiveScale()
			self._resizeOffset = currX - self._resizeStartX
		end
		self:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param child Element
function DividedContainer.__private:_AddDividedChild(child, isLeft)
	if isLeft then
		self._state.leftContent:AddChild(child)
	else
		self._state.rightContent:AddChild(child)
	end
end

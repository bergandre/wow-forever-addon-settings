-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")

---@class ViewContainerContextTable
---@field pathIndex number

---@alias ViewContainerNavCallback fun(viewContainer: ViewContainer, path: string): Element



-- ============================================================================
-- Element Definition
-- ============================================================================

local ViewContainer = ComponentRegistry.Define("ViewContainer", "Element")
ViewContainer._STATE_SCHEMA = ViewContainer._STATE_SCHEMA:Extend("ViewContainerState")
	:AddDeferredStringField("path")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ViewContainer:__init()
	self.__super:__init(self:_CreateFrame())
	self._child = nil ---@type Element!
	self._pathsList = {}
	self._contextTable = nil ---@type ViewContainerContextTable!
	self._defaultContextTable = nil ---@type ViewContainerContextTable!
	self._navCallback = nil ---@type ViewContainerNavCallback!
end

function ViewContainer:Release()
	wipe(self._pathsList)
	self._child = nil
	self.__super:Release()
	self._navCallback = nil
	self._contextTable = nil
	self._defaultContextTable = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the navigation callback.
---@param callback ViewContainerNavCallback The function called when the selected path changes to get the new content
---@return self
function ViewContainer:SetNavCallback(callback)
	self._navCallback = callback
	return self
end

---Add a path.
---@param path string The path
---@param setSelected? boolean Sets this as the selected path (false by default)
---@return self
function ViewContainer:AddPath(path, setSelected)
	tinsert(self._pathsList, path)
	if self._contextTable then
		assert(setSelected == nil, "Cannot set selected path when using a context table")
		local newPathIndex = self:_PathToIndex(path)
		if self._contextTable.pathIndex == newPathIndex then
			self:SetPath(path)
		end
	elseif setSelected then
		self:SetPath(path)
	end
	return self
end

---Sets the path list.
---@param paths string[] The paths
---@param selectedPath? string The selected path
---@return self
function ViewContainer:SetPathList(paths, selectedPath)
	assert(#self._pathsList == 0)
	for _, path in ipairs(paths) do
		self:AddPath(path, path == selectedPath)
	end
	return self
end

---Sets the selected path.
---@param path string The selected path
---@param redraw? boolean Whether or not to redraw the view container
---@return self
function ViewContainer:SetPath(path, redraw)
	if path ~= self._state.path then
		if self._child then
			self:_RemoveChild(self._child)
		end
		self._child = self:_navCallback(path)
		assert(self._child)
		self:_AddChild(self._child)
		self._state.path = path
	end
	if redraw then
		self:Draw()
	end
	return self
end

---Reloads the currently selected path.
function ViewContainer:ReloadContent()
	local path = self._state.path --[[@as string]]
	self._state.path = nil
	self:SetPath(path, true)
end

---Get the current path.
---@return string
function ViewContainer:GetPath()
	return self._state.path
end

---Sets the context table which can be used to save the active tab (by index).
---@param tbl table The context table
---@param defaultTbl ViewContainerContextTable Default values
---@return self
function ViewContainer:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.pathIndex ~= nil)
	tbl.pathIndex = tbl.pathIndex or defaultTbl.pathIndex
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	self._state:Publisher("path")
		:IgnoreNil()
		:Map(self:__closure("_PathToIndex"))
		:AssignToTableKey(tbl, "pathIndex")
	return self
end

---Sets the context table from a settings object.
---@param settings any The settings object
---@param key string The settings key
---@return self
function ViewContainer:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

function ViewContainer:Draw()
	self.__super:Draw()
	local childFrame = self._child:_GetBaseFrame()

	-- Set the child to be full-size
	childFrame:ClearAllPoints()
	local xOffset, yOffset = self._child:_GetMarginAnchorOffsets("BOTTOMLEFT")
	local paddingXOffset, paddingYOffset = self:_GetPaddingAnchorOffsets("BOTTOMLEFT")
	xOffset = xOffset + paddingXOffset - self:_GetContentPadding("LEFT")
	yOffset = yOffset + paddingYOffset - self:_GetContentPadding("BOTTOM")
	childFrame:SetPoint("BOTTOMLEFT", xOffset, yOffset)
	xOffset, yOffset = self._child:_GetMarginAnchorOffsets("TOPRIGHT")
	paddingXOffset, paddingYOffset = self:_GetPaddingAnchorOffsets("TOPRIGHT")
	xOffset = xOffset + paddingXOffset - self:_GetContentPadding("RIGHT")
	yOffset = yOffset + paddingYOffset - self:_GetContentPadding("TOP")
	childFrame:SetPoint("TOPRIGHT", xOffset, yOffset)
	self._child:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ViewContainer.__private:_PathToIndex(path)
	return Table.KeyByValue(self._pathsList, path)
end

function ViewContainer:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" then
		local width = self._state.width
		if width then
			return width, false
		else
			return self._child:_GetMinimumDimension(dimension)
		end
	elseif dimension == "HEIGHT" then
		local height = self._state.height
		if height then
			return height, false
		else
			return self._child:_GetMinimumDimension(dimension)
		end
	else
		error("Invalid dimension: "..tostring(dimension))
	end
end

function ViewContainer:_GetContentPadding(side)
	if side == "TOP" or side == "BOTTOM" or side == "LEFT" or side == "RIGHT" then
		return 0
	else
		error("Invalid side: "..tostring(side))
	end
end

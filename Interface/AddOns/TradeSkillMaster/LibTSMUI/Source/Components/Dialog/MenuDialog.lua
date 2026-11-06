-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local MenuDialogData = LibTSMUI:IncludeClassType("MenuDialogData")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MenuDialog = ComponentRegistry.Define("MenuDialog", "BaseFrame")
MenuDialog._STATE_SCHEMA = MenuDialog._STATE_SCHEMA:Extend("MenuDialogState")
	:AddDeferredUIElementField("list", "MenuDialogList")
	:AddOptionalUIElementField("subMenu", "MenuDialog")
	:AddOptionalStringField("id")
	:AddDeferredClassField("data", MenuDialogData)
	:Commit()
MenuDialog:_AddActionScripts("OnRowClick", "OnRowDelete")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MenuDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog(true)
end

function MenuDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetWidth(250)
	self:SetPadding(2)
	self:SetBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:AddChild(UIElements.New("MenuDialogList", "list")
		:SetManager(self._childManager)
		:SetAction("OnRowsChanged", "ACTION_UPDATE_HEIGHT")
		:SetAction("OnRowEnter", "ACTION_HANDLE_ROW_ENTER")
		:SetAction("OnRowClick", "ACTION_HANDLE_ROW_CLICK")
		:SetAction("OnRowDelete", "ACTION_HANDLE_ROW_DELETE")
		:BindElement(self._state, "list")
	)
end

function MenuDialog:Release()
	-- Need to explicitly remove the sub menu first since it has a reference to the data
	if self._state.subMenu then
		self:RemoveChild(self._state.subMenu)
		self._state.subMenu = nil
	end
	self.__super:Release()
end

---Sets the data.
---@param parentId string The parentId for this menu dialog
---@param data? MenuDialogData The data
---@return self
function MenuDialog:Configure(parentId, data)
	assert(not self._state.data)
	data = data or MenuDialogData.Get()
	self._state.data = data
	self._state.list:Configure(parentId, data)
	return self
end

---Sets whether or not data updates are paused.
---@param paused boolean Whether or not to pause data updates
---@return self
function MenuDialog:SetDataUpdatesPaused(paused)
	self._state.list:SetDataUpdatesPaused(paused)
	return self
end

---Adds a menu row.
---@param id string The id of the row
---@param parentId string The id of the parent row (or an empty string to indicate no parent)
---@param label string The text to display
---@param beforeId? string The id of an existing row to add this new row before
---@return self
function MenuDialog:AddRow(id, parentId, label, beforeId)
	self._state.data:AddEntry(id, parentId, label, beforeId)
	return self
end

---Updates the label of a row.
---@param id string The id of the row
---@param label string The text to display
function MenuDialog:UpdateRow(id, label)
	self._state.data:UpdateEntry(id, label)
end

---Removes a row.
---@param id string The id of the row
function MenuDialog:RemoveRow(id)
	self._state.data:RemoveEntry(id)
end

---Enables a delete icon for a row.
---@param id string The id of the row or the parentId of a set of rows to enable deletion for
---@return self
function MenuDialog:EnableDeletion(id)
	self._state.data:EnableDeletion(id)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<MenuDialogState>
---@param state MenuDialogState
function MenuDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_HEIGHT" then
		local listMaxHeight = ...
		self:SetHeight(min(4 + listMaxHeight, 255))
		self:Draw()
	elseif action == "ACTION_HANDLE_ROW_ENTER" then
		local id, hasChildren = ...
		if id == state.id then
			return
		end
		manager:ProcessAction("ACTION_SET_CURRENT_ID", id)
		if hasChildren then
			manager:ProcessAction("ACTION_SHOW_SUB_MENU")
		end
	elseif action == "ACTION_SET_CURRENT_ID" then
		local id = ...
		if state.id == id then
			return
		end
		if state.subMenu then
			self:RemoveChild(state.subMenu)
			state.subMenu = nil
			self:Draw()
		end
		state.list:SetSelection(id)
		state.id = id
	elseif action == "ACTION_SHOW_SUB_MENU" then
		assert(state.id and state.id ~= "")
		state.subMenu = UIElements.New("MenuDialog", "subMenu")
			:AddAnchor("TOPLEFT", self, "TOPRIGHT", 4, -state.list:GetVerticalOffset(state.id))
			:Configure(state.id, state.data)
			:SetManager(manager)
			:SetAction("OnRowClick", "ACTION_HANDLE_SUB_MENU_ROW_CLICK")
			:SetAction("OnRowDelete", "ACTION_HANDLE_SUB_MENU_ROW_DELETE")
		self:AddChildNoLayout(state.subMenu)
		state.subMenu:Draw()
	elseif action == "ACTION_HANDLE_ROW_CLICK" then
		local id = ...
		self:_SendActionScript("OnRowClick", self, id)
	elseif action == "ACTION_HANDLE_ROW_DELETE" then
		local id = ...
		self:_SendActionScript("OnRowDelete", self, id)
	elseif action == "ACTION_HANDLE_SUB_MENU_ROW_CLICK" then
		assert(state.id)
		self:_SendActionScript("OnRowClick", self, state.id, select(2, ...))
	elseif action == "ACTION_HANDLE_SUB_MENU_ROW_DELETE" then
		assert(state.id)
		self:_SendActionScript("OnRowDelete", self, state.id, select(2, ...))
	else
		error("Unknown action: "..tostring(action))
	end
end

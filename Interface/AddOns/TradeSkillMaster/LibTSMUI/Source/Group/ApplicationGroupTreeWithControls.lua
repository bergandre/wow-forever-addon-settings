-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local CONTROL_ICON_COLOR = "on/surface"



-- ============================================================================
-- Element Definition
-- ============================================================================

local ApplicationGroupTreeWithControls = ComponentRegistry.Define("ApplicationGroupTreeWithControls", "BaseFrame")
ApplicationGroupTreeWithControls._STATE_SCHEMA = ApplicationGroupTreeWithControls._STATE_SCHEMA:Extend("ApplicationGroupTreeWithControlsState")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTree")
	:AddStringField("searchValue", "")
	:Commit()
ApplicationGroupTreeWithControls:_AddActionScripts("OnGroupSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ApplicationGroupTreeWithControls:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function ApplicationGroupTreeWithControls:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Input", "input")
				:SetMargin(0, 8, 0, 0)
				:AllowItemInsert(true)
				:SetLeadIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:SetHintText(L["Search Groups"])
				:BindValue(self._state, "searchValue")
			)
			:AddChild(UIElements.New("SmallTertiaryActionButton", "expandAllBtn")
				:SetWidth(24)
				:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.14x14/Expand All", CONTROL_ICON_COLOR)))
				:SetTooltip(L["Expand / Collapse All Groups"])
				:SetAction("OnClick", "ACTION_TOGGLE_EXPAND_ALL")
			)
			:AddChild(UIElements.New("SmallTertiaryActionButton", "selectAllBtn")
				:SetWidth(24)
				:SetMargin(4, 0, 0, 0)
				:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.14x14/Select All", CONTROL_ICON_COLOR)))
				:SetTooltip(L["Select / Deselect All Groups"])
				:SetAction("OnClick", "ACTION_TOGGLE_SELECT_ALL")
			)
		)
		self:AddChild(UIElements.New("ApplicationGroupTree", "groupTree")
			:BindElement(self._state, "groupTree")
			:SetManager(self._childManager)
			:SetSearchString(self._state:PublisherForFunctionWithKeys(strlower, "searchValue"))
			:SetAction("OnGroupSelectionChanged", "ACTION_HANDLE_SELECTION_CHANGED")
		)
	end
end

---Adjusts the selection behavior to always keep the top level group selected.
---@return self
function ApplicationGroupTreeWithControls:KeepTopLevelGroupSelected()
	self._state.groupTree:KeepTopLevelGroupSelected()
	return self
end

---Sets the background color of the group tree rows so they blend with the parent container.
---@param color ThemeColorKey The background color
---@return self
function ApplicationGroupTreeWithControls:SetTreeBackgroundColor(color)
	self._state.groupTree:SetBackgroundColor(color)
	return self
end

---Sets the group tree operation type.
---@param operationType string The operation type
---@return self
function ApplicationGroupTreeWithControls:SetOperationType(operationType)
	self._state.groupTree:SetQuery(GroupOperation.CreateQuery(), operationType)
	return self
end

---Sets the query used to populate the group tree.
---@param query DatabaseQuery The database query object
---@param operationType? string The operation type to filter groups by
---@return self
function ApplicationGroupTreeWithControls:SetQuery(query, operationType)
	self._state.groupTree:SetQuery(query, operationType)
	return self
end

---Sets whether or not query updates are paused on the group tree.
---@param paused boolean Whether or not query updates are paused
---@return self
function ApplicationGroupTreeWithControls:SetQueryUpdatesPaused(paused)
	self._state.groupTree:SetQueryUpdatesPaused(paused)
	return self
end

---Sets the context table which is used to persist the selected and collapsed state.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `unselected` OR `selected`, `collapsed`)
---@return self
function ApplicationGroupTreeWithControls:SetContextTable(tbl, defaultTbl)
	self._state.groupTree:SetContextTable(tbl, defaultTbl)
	return self
end

---Sets the group tree context table from a settings object.
---@param settings SettingsView The settings object
---@param key string The setting key
---@return self
function ApplicationGroupTreeWithControls:SetSettingsContext(settings, key)
	self._state.groupTree:SetSettingsContext(settings, key)
	self._bindings:Process("SELECTION_CLEARED", self._state.groupTree:IsSelectionCleared())
	return self
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to check
---@return boolean
function ApplicationGroupTreeWithControls:IsGroupSelected(groupPath)
	return self._state.groupTree:IsGroupSelected(groupPath)
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to set the selected state of
---@param selected boolean Whether or not the group should be selected
---@return self
function ApplicationGroupTreeWithControls:SetGroupSelected(groupPath, selected)
	self._state.groupTree:SetGroupSelected(groupPath, selected)
	return self
end

---Gets whether or not the group tree selection is cleared.
---@return boolean
function ApplicationGroupTreeWithControls:IsSelectionCleared()
	return self._state.groupTree:IsSelectionCleared()
end

---Iterates through the selected groups.
---@return IteratorObject<fun(): number, GroupPathValue> @Iterator with fields: `index`, `groupPath`
function ApplicationGroupTreeWithControls:SelectedGroupsIterator()
	return self._state.groupTree:SelectedGroupsIterator()
end

---Binds a state property to whether or not the selection is cleared.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function ApplicationGroupTreeWithControls:BindSelectionCleared(state, key)
	self._bindings:Add("SELECTION_CLEARED", state, key)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<ApplicationGroupTreeWithControlsState>
---@param state ApplicationGroupTreeWithControlsState
function ApplicationGroupTreeWithControls.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE_EXPAND_ALL" then
		state.groupTree:ToggleExpandAll()
	elseif action == "ACTION_TOGGLE_SELECT_ALL" then
		state.groupTree:ToggleSelectAll()
	elseif action == "ACTION_HANDLE_SELECTION_CHANGED" then
		self._bindings:Process("SELECTION_CLEARED", state.groupTree:IsSelectionCleared())
		self:_SendActionScript("OnGroupSelectionChanged")
	else
		error("Unknown action: "..tostring(action))
	end
end

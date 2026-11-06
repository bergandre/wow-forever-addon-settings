-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ListDropdown = ComponentRegistry.Define("ListDropdown", "BaseDropdown")
ListDropdown._STATE_SCHEMA = ListDropdown._STATE_SCHEMA:Extend("ListDropdownState")
	:AddOptionalStringField("selectedItem")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ListDropdown:__init()
	self.__super:__init(false)
	self._itemIndexLookup = {}
	self._state:Publisher([[selectedItem or ""]])
		:AssignToTableKey(self._state, "currentSelectionStr")
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@return self
function ListDropdown:SetItems(items)
	wipe(self._items)
	wipe(self._itemIndexLookup)
	for i, item in ipairs(items) do
		self._items[i] = item
		assert(not self._itemIndexLookup[item])
		self._itemIndexLookup[item] = i
	end
	return self
end

---Set the currently selected item.
---@param item? string The selected item or nil if nothing should be selected
---@param silent? boolean Don't call the OnSelectionChanged callback
---@return self
function ListDropdown:SetSelectedItem(item, silent)
	self:SetSelectedItemSilent(item)
	if not silent then
		self:_SendActionScript("OnSelectionChanged")
	end
	return self
end

---Set the currently selected item silently.
---@param item? string The selected item or nil if nothing should be selected
---@return self
function ListDropdown:SetSelectedItemSilent(item)
	self._state.selectedItem = item
	return self
end

---Set the currently selected item by index.
---@param index? number The index of the item to be selected (or nil to clear the selection)
---@param silent? boolean Don't call the OnSelectionChanged callback
---@return self
function ListDropdown:SetSelectedItemByIndex(index, silent)
	assert(not index or self._items[index])
	self:SetSelectedItem(index and self._items[index] or nil, silent)
	return self
end

---Set the currently selected item by index silently.
---@param index? number The index of the item to be selected (or nil to clear the selection)
---@return self
function ListDropdown:SetSelectedItemByIndexSilent(index)
	if index == nil then
		self:SetSelectedItemSilent(nil)
	else
		local item = self._items[index]
		assert(item)
		self:SetSelectedItemSilent(item)
	end
	return self
end

---Get the currently selected item.
---@return string?
function ListDropdown:GetSelectedItem()
	return self._state.selectedItem
end

---Get the currently selected item.
---@return number?
function ListDropdown:GetSelectedItemIndex()
	return self._state.selectedItem and self._itemIndexLookup[self._state.selectedItem] or nil
end

---Mirrors the selected item value with the specified state.
---@param state ReactiveState The state to mirror
---@param key string The state key to mirror
---@return self
function ListDropdown:MirrorSelectedItemState(state, key)
	self:AddCancellable(state:Publisher(key)
		:CallMethod(self, "SetSelectedItemSilent")
	)
	self._state:Publisher("selectedItem")
		:AssignToTableKey(state, key)
	return self
end

---Mirrors the selected item index with the specified state.
---@param state ReactiveState The state to mirror
---@param key string The state key to mirror
---@return self
function ListDropdown:MirrorSelectedItemIndexState(state, key)
	self:AddCancellable(state:Publisher(key)
		:CallMethod(self, "SetSelectedItemByIndexSilent")
	)
	self._state:Publisher("selectedItem")
		:Map(self._itemIndexLookup)
		:AssignToTableKey(state, key)
	return self
end

---Sets the setting info to have the value of the dropdown automatically correspond with the value of a field in a settings table.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the dropdown state
---@return self
function ListDropdown:SetSettingInfo(tbl, key)
	if not self._items[tbl[key]] then
		tbl[key] = nil
	end
	self:SetSelectedItemByIndex(tbl[key])
	self._state:Publisher("selectedItem")
		:Map(self._itemIndexLookup)
		:AssignToTableKey(tbl, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<ListDropdownState>
---@param state ListDropdownState
function ListDropdown.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_SELECTION_CHANGED" then
		local selection = ...
		self:GetBaseElement():HideDialog()
		self:SetSelectedItem(selection)
		self:Draw()
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function ListDropdown.__protected:_GetDialogSelection()
	return self._state.selectedItem
end

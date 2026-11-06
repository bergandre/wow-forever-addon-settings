-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SelectionDropdown = ComponentRegistry.Define("SelectionDropdown", "BaseDropdown")
SelectionDropdown._STATE_SCHEMA = SelectionDropdown._STATE_SCHEMA:Extend("SelectionDropdownState")
	:AddOptionalStringField("selectedItem")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SelectionDropdown:__init()
	self.__super:__init(false)

	self._itemKeyLookup = {}

	self._state:Publisher([[selectedItem or ""]])
		:AssignToTableKey(self._state, "currentSelectionStr")
end

function SelectionDropdown:Release()
	wipe(self._itemKeyLookup)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Add an item to be shown in the dropdown dialog list.
---@param item string The item to add to the list (for display)
---@param itemKey string|number The key to use for the item
---@return self
function SelectionDropdown:AddItem(item, itemKey)
	assert(not self._itemKeyLookup[item] and not Table.KeyByValue(self._itemKeyLookup, itemKey))
	tinsert(self._items, item)
	self._itemKeyLookup[item] = itemKey
	return self
end

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@param itemKeys (string|number)[] A list of keys which go with the item at the corresponding index in the items list
---@return self
function SelectionDropdown:SetItems(items, itemKeys)
	assert(#itemKeys == #items)
	wipe(self._items)
	wipe(self._itemKeyLookup)
	for i = 1, #items do
		self:AddItem(items[i], itemKeys[i])
	end
	return self
end

---Set the currently selected item.
---@param item? string|number The selected item or nil if nothing should be selected
---@param silent? boolean Don't call the OnSelectionChanged callback
---@return self
function SelectionDropdown:SetSelectedItem(item, silent)
	self._state.selectedItem = item
	if not silent then
		self:_SendActionScript("OnSelectionChanged")
	end
	return self
end

---Set the currently selected item by key.
---@param itemKey? string|number The key for the selected item or nil if nothing should be selected
---@param silent? boolean Don't call the OnSelectionChanged callback
---@return self
function SelectionDropdown:SetSelectedItemByKey(itemKey, silent)
	local item = itemKey and Table.GetDistinctKey(self._itemKeyLookup, itemKey) or nil
	self:SetSelectedItem(item, silent)
	return self
end

---Get the currently selected item.
---@return string?
function SelectionDropdown:GetSelectedItem()
	return self._state.selectedItem
end

---Get the currently selected item.
---@return string?
function SelectionDropdown:GetSelectedItemKey()
	return self._state.selectedItem and self._itemKeyLookup[self._state.selectedItem] or nil
end

---Sets the setting info to have the value of the dropdown automatically correspond with the value of a field in a settings table.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the dropdown state
---@return self
function SelectionDropdown:SetSettingInfo(tbl, key)
	self:SetSelectedItemByKey(tbl[key])
	self._state:Publisher("selectedItem")
		:Map(self._itemKeyLookup)
		:AssignToTableKey(tbl, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<SelectionDropdownState>
---@param state SelectionDropdownState
function SelectionDropdown.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_SELECTION_CHANGED" then
		local selection = ...
		self:GetBaseElement():HideDialog()
		self:SetSelectedItem(selection)
		self:Draw()
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function SelectionDropdown.__protected:_GetDialogSelection()
	return self._state.selectedItem
end

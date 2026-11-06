-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local CombatLockdown = LibTSMUI:From("LibTSMWoW"):Include("Service.CombatLockdown")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ROW_HEIGHT = 20
local EMPTY_LIST_HEIGHT = 16



-- ============================================================================
-- Element Definition
-- ============================================================================

local SecureSelectionDropdown = ComponentRegistry.Define("SecureSelectionDropdown", "SelectionDropdown")
SecureSelectionDropdown._STATE_SCHEMA = SecureSelectionDropdown._STATE_SCHEMA:Extend("SecureSelectionDropdownState")
	:AddDeferredUIElementField("secureList", "BaseFrame")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SecureSelectionDropdown:__init()
	self.__super:__init()
	self._itemSpells = {}
end

function SecureSelectionDropdown:Acquire()
	self.__super:Acquire()
	self:AddCancellable(CombatLockdown.GetPublisher()
		:CallFunction(self:__closure("_HandleCombatLockdownChanged"))
	)
end

function SecureSelectionDropdown:Release()
	wipe(self._itemSpells)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Set the items to show in the dropdown dialog list along with the spell which selecting each one casts.
---@param items string[] A list of items to be shown in the dropdown list
---@param itemKeys (string|number)[] A list of keys which go with the item at the corresponding index in the items list
---@param spells? table<string|number,string> The name of the spell to cast for each item key which casts one
---@return self
function SecureSelectionDropdown:SetItems(items, itemKeys, spells)
	self.__super:SetItems(items, itemKeys)
	wipe(self._itemSpells)
	if spells then
		for itemKey, spell in pairs(spells) do
			self._itemSpells[itemKey] = spell
		end
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<SecureSelectionDropdownState>
---@param state SecureSelectionDropdownState
function SecureSelectionDropdown.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE_DIALOG" then
		if state.secureList then
			self:GetBaseElement():HideDialog()
		elseif not CombatLockdown.IsActive() then
			return self.__super:_ActionHandler(manager, state, action, ...)
		end
	elseif action == "ACTION_HANDLE_ROW_CLICK" then
		local _, item = ...
		if item ~= self:GetSelectedItem() and self._itemSpells[self._itemKeyLookup[item]] then
			self:GetBaseElement():HideDialog()
			return
		end
		return manager:ProcessAction("ACTION_HANDLE_SELECTION_CHANGED", item)
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function SecureSelectionDropdown.__protected:_CreateDialogList()
	local selectedItem = self:GetSelectedItem()
	local list = UIElements.New("BaseFrame", "dropdown")
		:SetLayout("VERTICAL")
		:SetRoundedBackgroundColor("container/lowest")
		:BindElement(self._state, "secureList")
	for i, item in ipairs(self._items) do
		local isSelected = item == selectedItem
		list:AddChild(UIElements.New("SecureSpellButton", "row"..i)
			:SetHeight(ROW_HEIGHT)
			:SetPadding(Theme.GetColSpacing() / 2, Theme.GetColSpacing() / 2, 0, 0)
			:SetFont("BODY_SMALL")
			:SetJustifyH("LEFT")
			:SetText(item)
			:SetIcon(isSelected and "iconPack.12x12/Checkmark/Default" or nil, isSelected and "RIGHT" or nil)
			:SetBackgroundWithHighlight("container/lowest")
			:SetSpell(not isSelected and self._itemSpells[self._itemKeyLookup[item]] or nil)
			:SetContext(item)
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_HANDLE_ROW_CLICK")
		)
	end
	return list
end

---@return number
function SecureSelectionDropdown.__protected:_GetDialogListHeight()
	return max(#self._items * ROW_HEIGHT, EMPTY_LIST_HEIGHT)
end

function SecureSelectionDropdown.__private:_HandleCombatLockdownChanged(isActive)
	if isActive and self._state.secureList then
		self:GetBaseElement():HideDialog()
	end
	self:SetDisabled(isActive)
end

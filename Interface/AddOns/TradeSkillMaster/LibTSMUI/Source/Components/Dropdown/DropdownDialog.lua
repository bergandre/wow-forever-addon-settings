-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local DropdownDialog = ComponentRegistry.Define("DropdownDialog", "BaseFrame")
DropdownDialog._STATE_SCHEMA = DropdownDialog._STATE_SCHEMA:Extend("DropdownDialogState")
	:AddDeferredUIElementField("list", "DropdownList")
	:AddBooleanField("noneSelected", false)
	:AddBooleanField("allSelected", false)
	:Commit()
DropdownDialog:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DropdownDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function DropdownDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:AddChild(UIElements.New("DropdownList", "list")
		:BindElement(self._state, "list")
		:SetManager(self._childManager)
	)
	for _ in self._state:WithAutoStorePaused() do
		self:AddCancellable(self._state:Publisher("backgroundColor")
			:IgnoreNil()
			:CallMethod(self._state.list, "SetBackgroundColor")
		)
	end
end

function DropdownDialog:SetMultiselect(multiselect)
	self._state.list
		:SetMultiselect(multiselect)
		:SetAction("OnSelectionChanged", "ACTION_HANDLE_SELECTION_CHANGED")
	return self
end

function DropdownDialog:SetItems(items, selection)
	self._state.list:SetItems(items, selection)
	self._childManager:ProcessAction("ACTION_HANDLE_SELECTION_CHANGED", selection)
	return self
end

function DropdownDialog:ToggleSelectAll()
	self._childManager:ProcessAction("ACTION_TOGGLE_SELECT_ALL")
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<DropdownDialogState>
---@param state DropdownDialogState
function DropdownDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE_SELECT_ALL" then
		if state.list:IsAllSelected() then
			state.list:DeselectAll()
		else
			state.list:SelectAll()
		end
	elseif action == "ACTION_HANDLE_SELECTION_CHANGED" then
		local selected = ...
		state.noneSelected = state.list:IsNoneSelected()
		state.allSelected = state.list:IsAllSelected()
		self:_SendActionScript("OnSelectionChanged", selected)
	else
		error("Unknown action: "..tostring(action))
	end
end

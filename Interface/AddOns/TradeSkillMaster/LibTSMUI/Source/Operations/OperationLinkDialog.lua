-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local private = {
	entriesTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkDialog = ComponentRegistry.Define("OperationLinkDialog", "PopupFrame")
OperationLinkDialog._STATE_SCHEMA = OperationLinkDialog._STATE_SCHEMA:Extend("OperationLinkDialogState")
	:AddDeferredUIElementField("selectionList", "SelectionList")
	:AddDeferredStringField("operationType")
	:AddDeferredStringField("operationName")
	:AddDeferredStringField("settingKey")
	:Commit()
OperationLinkDialog:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function OperationLinkDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:AddChild(UIElements.New("BaseFrame", "titleFrame")
		:SetLayout("VERTICAL")
		:SetHeight(37)
		:AddChild(UIElements.New("Text", "title")
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetJustifyH("CENTER")
			:SetText(L["Link to Another Operation"])
		)
	)
	self:AddChild(UIElements.New("SelectionList", "list")
		:SetMargin(2, 2, 0, 3)
		:BindElement(self._state, "selectionList")
		:SetManager(self._childManager)
		:SetAction("OnEntrySelected", "ACTION_HANDLE_ENTRY_SELECTED")
	)
end

---Sets the operation setting to display in the dialog.
---@param operationType string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkDialog:SetOperationSetting(operationType, operationName, settingKey)
	self._state.operationType = operationType
	self._state.operationName = operationName
	self._state.settingKey = settingKey
	assert(#private.entriesTemp == 0)
	for _, otherOperationName in Operation.Iterator(operationType) do
		if Operation.CanAddRelationship(operationType, operationName, otherOperationName, settingKey) then
			tinsert(private.entriesTemp, otherOperationName)
		end
	end
	sort(private.entriesTemp)
	self._state.selectionList:SetEntries(private.entriesTemp, Operation.GetRelationship(operationType, operationName, settingKey))
	wipe(private.entriesTemp)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state OperationLinkDialogState
function OperationLinkDialog.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_HANDLE_ENTRY_SELECTED" then
		local operationName = ...
		local previousValue = Operation.GetRelationship(state.operationType, state.operationName, state.settingKey)
		if operationName == previousValue then
			-- The user selects the same entry to clear the relationship
			operationName = nil
		end
		Operation.SetRelationship(state.operationType, state.operationName, state.settingKey, operationName)
		self:_SendActionScript("OnValueChanged")
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

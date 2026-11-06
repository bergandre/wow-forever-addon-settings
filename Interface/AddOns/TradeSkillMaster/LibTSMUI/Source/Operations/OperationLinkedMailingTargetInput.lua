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



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkedMailingTargetInput = ComponentRegistry.Define("OperationLinkedMailingTargetInput", "OperationLinkedSettingLine")
OperationLinkedMailingTargetInput._STATE_SCHEMA = OperationLinkedMailingTargetInput._STATE_SCHEMA:Extend("OperationLinkedMailingTargetInputState")
	:AddDeferredUIElementField("input", "Input")
	:AddDeferredUIElementField("contactsButton", "ActionButton")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedMailingTargetInput:Acquire()
	self.__super:Acquire()
	self:SetHeight(46)
	self:SetLabel(L["Target character"])
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Input", "input")
				:SetMargin(0, 8, 0, 0)
				:BindElement(self._state, "input")
				:SetHintText(L["Enter player name"])
				:SetClearButtonEnabled(true)
				:SetDisabled(self._state:Publisher([[relationshipSet or disabled]]))
				:SetTooltip(L["The name of the character to send items to. If the character is on another connected realm, you can use the format Name-Realm."], true)
			)
			:AddChild(UIElements.New("SmallSecondaryActionButton", "contacts")
				:SetWidth(152)
				:SetText(L["Contacts"])
				:BindElement(self._state, "contactsButton")
				:SetAction("OnClick", "ACTION_SHOW_CONTACTS_DIALOG")
			)
		)
	end
end

---Sets the operation setting to display in the dropdown.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkedMailingTargetInput:SetOperationSetting(typeName, operationName, settingKey)
	self.__super:SetOperationSetting(typeName, operationName, settingKey)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.input:SetSettingInfo(operationSettings, settingKey)
	return self
end

---Sets the auto complete characters for the input.
---@param characterNames string[] The character names
---@return self
function OperationLinkedMailingTargetInput:SetAutoComplete(characterNames)
	self._state.input:SetAutoComplete(characterNames)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param manager UIManager<OperationLinkedMailingTargetInputState>
---@param state OperationLinkedMailingTargetInputState
function OperationLinkedMailingTargetInput.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_CONTACTS_DIALOG" then
		state.input:SetFocused(false)
		self:GetBaseElement():ShowDialogFrame(UIElements.New("MailContactsDialog", "dialog")
			:AddAnchor("TOP", state.contactsButton, "BOTTOM", 0, -6)
			:SetManager(manager)
			:SetAction("OnRowClick", "ACTION_CONTACT_SELECTED")
		)
	elseif action == "ACTION_CONTACT_SELECTED" then
		local character = ...
		state.input:SetValue(character)
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function OperationLinkedMailingTargetInput.__protected:_HandleRelationshipChanged()
	self.__super:_HandleRelationshipChanged()
	local value = Operation.GetSettings(self._typeName, self._operationName)[self._settingKey] --[[@as string]]
	self._state.input:SetValue(value)
end

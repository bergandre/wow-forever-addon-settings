-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkedSettingLine = ComponentRegistry.Define("OperationLinkedSettingLine", "BaseFrame")
OperationLinkedSettingLine._STATE_SCHEMA = OperationLinkedSettingLine._STATE_SCHEMA:Extend("OperationLinkedSettingLineState")
	:AddDeferredUIElementField("linkButton", "OperationLinkButton")
	:AddStringField("labelText", "")
	:AddBooleanField("relationshipSet", false)
	:AddBooleanField("disabled", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedSettingLine:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._typeName = nil ---@type string!
	self._operationName = nil ---@type string!
	self._settingKey = nil ---@type string!
end

function OperationLinkedSettingLine:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "line")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 2)
			:AddChild(UIElements.New("Text", "label")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetTextColor(self._state:Publisher([[relationshipSet or disabled]]):ReplaceBooleanWith("on/surface%40", "on/surface"))
				:SetText(self._state:Publisher("labelText"))
			)
			:AddChild(UIElements.New("OperationLinkButton", "linkBtn")
				:SetMargin(4, 4, 0, 0)
				:SetDisabled(self._state:Publisher("disabled"))
				:BindElement(self._state, "linkButton")
				:SetManager(self._childManager)
				:SetAction("OnValueChanged", "ACTION_HANDLE_RELATIONSHIP_CHANGED")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
	end
end

function OperationLinkedSettingLine:Release()
	self._typeName = nil
	self._operationName = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the operation setting to display in the dialog.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkedSettingLine:SetOperationSetting(typeName, operationName, settingKey)
	self._typeName = typeName
	self._operationName = operationName
	self._settingKey = settingKey
	self._state.relationshipSet = Operation.HasRelationship(typeName, operationName, settingKey)
	self._state.linkButton:SetOperationSetting(typeName, operationName, settingKey)
	return self
end

---Sets the label text.
---@param text string The label text
---@return self
function OperationLinkedSettingLine:SetLabel(text)
	self._state.labelText = text
	return self
end

---Sets whether or not the settings line is disabled.
---@param value boolean|ReactivePublisherSchemaBase The disabled value or a publisher
---@return self
function OperationLinkedSettingLine:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.disabled = value
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OperationLinkedSettingLine.__protected:_ActionHandler(_, _, action, ...)
	if action == "ACTION_HANDLE_RELATIONSHIP_CHANGED" then
		self:_HandleRelationshipChanged()
	else
		error("Unknown action: "..tostring(action))
	end
end

function OperationLinkedSettingLine.__protected:_HandleRelationshipChanged()
	self._state.relationshipSet = Operation.HasRelationship(self._typeName, self._operationName, self._settingKey)
	self._state.linkButton:SetOperationSetting(self._typeName, self._operationName, self._settingKey)
end

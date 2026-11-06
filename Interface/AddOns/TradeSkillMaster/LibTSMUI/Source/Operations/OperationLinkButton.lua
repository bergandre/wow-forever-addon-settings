-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local private = {}
local LINK_TEXTURE = "iconPack.14x14/Link"



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkButton = ComponentRegistry.Define("OperationLinkButton", "BaseButton")
OperationLinkButton._STATE_SCHEMA = OperationLinkButton._STATE_SCHEMA:Extend("OperationLinkButtonState")
	:AddBooleanField("relationshipSet", false)
	:Commit()
OperationLinkButton:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkButton:__init()
	self.__super:__init()
	self._typeName = nil ---@type string!
	self._operationName = nil ---@type string!
	self._settingKey = nil ---@type string!
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function OperationLinkButton:Acquire()
	self.__super:Acquire()
	self:SetSize(TextureAtlas.GetSize(LINK_TEXTURE))
	for _ in self._state:WithAutoStorePaused() do
		self:SetBackground(self._state:PublisherForFunctionWithKeys(private.StateToLinkTexture, "relationshipSet", "enabled"))
	end
end

function OperationLinkButton:Release()
	self._typeName = nil
	self._operationName = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the operation represented by the link button.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return self
function OperationLinkButton:SetOperationSetting(typeName, operationName, settingKey)
	self._typeName = typeName
	self._operationName = operationName
	self._settingKey = settingKey
	self._state.relationshipSet = Operation.HasRelationship(typeName, operationName, settingKey)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationLinkButton.__private:_ActionHandler(_, _, action, ...)
	if action == "ACTION_HANDLE_DIALOG_VALUE_CHANGED" then
		self.__super:_SendActionScript("OnValueChanged")
	else
		error("Unknown action: "..tostring(action))
	end
end

function OperationLinkButton.__protected:_SendActionScript(script)
	if script == "OnClick" then
		-- Handle click events by showing the dialog
		self:GetBaseElement():ShowDialogFrame(UIElements.New("OperationLinkDialog", "linkDialog")
			:SetSize(263, 243)
			:AddAnchor("TOPRIGHT", self, "BOTTOM", 22, -16)
			:SetManager(self._childManager)
			:SetOperationSetting(self._typeName, self._operationName, self._settingKey)
			:SetAction("OnValueChanged", "ACTION_HANDLE_DIALOG_VALUE_CHANGED")
		)
	else
		error("Invalid script: "..tostring(script))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToLinkTexture(relationshipSet, enabled)
	if relationshipSet then
		return TextureAtlas.GetColoredKey(LINK_TEXTURE, enabled and "accent/main" or "accent/main%40")
	else
		return TextureAtlas.GetColoredKey(LINK_TEXTURE, enabled and "on/surface" or "on/surface%40")
	end
end

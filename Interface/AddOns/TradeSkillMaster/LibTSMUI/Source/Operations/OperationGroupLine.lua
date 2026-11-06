-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationGroupLine = ComponentRegistry.Define("OperationGroupLine", "BaseFrame")
OperationGroupLine._STATE_SCHEMA = OperationGroupLine._STATE_SCHEMA:Extend("OperationGroupLineState")
	:AddDeferredStringField("groupPath")
	:AddDeferredStringField("operationType")
	:AddDeferredStringField("operationName")
	:Commit()
OperationGroupLine:_AddActionScripts("OnViewGroup", "OnRemoved")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationGroupLine:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function OperationGroupLine:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("Text", "text")
			:SetWidth("AUTO")
			:SetFont("BODY_SMALL")
			:SetTextColor(self._state:Publisher("groupPath"):IgnoreNil():Map(Group.GetLevel):Map(Theme.GetGroupColorKey))
			:SetText(self._state:Publisher(format([[groupPath ~= "%s" and groupPath or nil]], Group.GetRootPath())):MapNonNil(Group.GetName):CoalesceNil(L["Base Group"]))
		)
		self:AddChild(UIElements.New("BaseButton", "viewBtn")
			:SetMargin(2, 2, 0, 0)
			:SetBackgroundAndSize("iconPack.14x14/Groups")
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_VIEW_GROUP")
			:SetTooltip(L["Open this group."], true)
		)
		self:AddChild(UIElements.New("BaseButton", "removeBtn")
			:SetBackgroundAndSize("iconPack.14x14/Close/Default")
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_REMOVE_GROUP")
			:SetTooltip(L["Remove this operation from the group."], true)
		)
		self:AddChild(UIElements.New("Spacer", "spacer"))
	end
end

---Sets the group and operation info.
---@param groupPath string The group path
---@param operationType string The type of the operation
---@param operationName string The name of the operation
---@return self
function OperationGroupLine:SetGroupAndOperation(groupPath, operationType, operationName)
	self._state.groupPath = groupPath
	self._state.operationType = operationType
	self._state.operationName = operationName
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state OperationGroupLineState
function OperationGroupLine.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		self:_SendActionScript("OnViewGroup", state.groupPath)
	elseif action == "ACTION_REMOVE_GROUP" then
		GroupOperation.Remove(state.groupPath, state.operationType, state.operationName)
		self:_SendActionScript("OnRemoved", self)
	else
		error("Unknown action: "..tostring(action))
	end
end

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
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local Analytics = LibTSMUI:From("LibTSMService"):Include("Util.Analytics")



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupAddOperationDialog = ComponentRegistry.Define("GroupAddOperationDialog", "BaseFrame")
GroupAddOperationDialog._STATE_SCHEMA = GroupAddOperationDialog._STATE_SCHEMA:Extend("GroupAddOperationDialogState")
	:AddStringField("typeName", "")
	:AddDeferredStringField("groupPath")
	:AddStringField("filter", "")
	:AddOptionalStringField("selectedOperation")
	:Commit()
GroupAddOperationDialog:_AddActionScripts("OnOperationCreatedAndAdded", "OnOperationAdded")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupAddOperationDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function GroupAddOperationDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(12)
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:SetMouseEnabled(true)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 10)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetJustifyH("CENTER")
				:SetText(self._state:Publisher("typeName"):ToStringFormat(L["Add %s Operation"]))
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "container")
			:SetLayout("VERTICAL")
			:SetPadding(1)
			:SetBackgroundColor("container/lowest")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "search")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8, 8, 8, 12)
				:AddChild(UIElements.New("Input", "input")
					:SetLeadIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:AllowItemInsert(true)
					:SetHintText(self._state:Publisher("typeName"):ToStringFormat(L["Search %s operations"]))
					:BindValue(self._state, "filter")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "create")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("SmallTertiaryActionButton", "createOperation")
					:SetWidth("AUTO")
					:SetPadding(8, 8, 0, 0)
					:SetText(L["Create New Operation"])
					:SetAction("OnClick", "ACTION_ADD_CREATE")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("OperationsList", "list")
				:SetFilter(self._state:Publisher("filter"))
				:BindSelection(self._state, "selectedOperation")
				:SetOperationType(self._state:Publisher("typeName"):IgnoreIfEquals(""))
			)
		)
		self:AddChild(UIElements.New("MediumPrimaryActionButton", "addBtn")
			:SetMargin(0, 0, 8, 0)
			:SetManager(self._childManager)
			:SetDisabled(self._state:Publisher("selectedOperation"):ToBooleanEquals(nil))
			:SetText(L["Add Operation"])
			:SetAction("OnClick", "ACTION_ADD")
		)
	end
end

---Configures the dialog.
---@param typeName string The operation type name
---@param groupPath GroupPathValue The current group path
---@return self
function GroupAddOperationDialog:Configure(typeName, groupPath)
	self._state.typeName = typeName
	self._state.groupPath = groupPath
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GroupAddOperationDialogState>
---@param state GroupAddOperationDialogState
function GroupAddOperationDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_ADD_CREATE" then
		assert(state.typeName)
		local operationName = Operation.GetDeduplicatedName(state.typeName, L["New Operation"])
		Operation.Create(state.typeName, operationName)
		GroupOperation.Append(state.groupPath, state.typeName, operationName)
		Analytics.Action("ADDED_GROUP_OPERATION", state.groupPath, state.typeName, operationName)
		self:_SendActionScript("OnOperationCreatedAndAdded", operationName)
	elseif action == "ACTION_ADD" then
		assert(state.groupPath and state.typeName ~= "" and state.selectedOperation)
		GroupOperation.Append(state.groupPath, state.typeName, state.selectedOperation)
		Analytics.Action("ADDED_GROUP_OPERATION", state.groupPath, state.typeName, state.selectedOperation)
		self:_SendActionScript("OnOperationAdded")
	else
		error("Unknown action: "..tostring(action))
	end
end

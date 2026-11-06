-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupOperationRow = ComponentRegistry.Define("GroupOperationRow", "BaseFrame")
GroupOperationRow._STATE_SCHEMA = GroupOperationRow._STATE_SCHEMA:Extend("GroupOperationRowState")
	:AddDeferredUIElementField("titleFrame", "BaseFrame")
	:AddDeferredUIElementField("dragButton", "BaseButton")
	:AddDeferredStringField("typeName")
	:AddDeferredNumberField("num")
	:AddStringField("name", "")
	:AddStringField("groupPath", Group.GetRootPath())
	:AddBooleanField("isDragging", false)
	:Commit()
GroupOperationRow:_AddActionScripts("OnDraggingUpdate", "OnDraggingDone", "OnConfigure", "OnRemove")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupOperationRow:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_UPDATE_DRAGGING")
end

function GroupOperationRow:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	self:SetBackgroundColor("container/low")
	for _ in self._state:WithAutoStorePaused() do
		local draggingPublisher = self._state:Publisher("isDragging")
			:Share()
		self:SetStrata(draggingPublisher:ReplaceBooleanWith("DIALOG", "HIGH"))
		self:AddChild(UIElements.New("Text", "operationNum")
			:SetWidth(20)
			:SetMargin(2, 8, 0, 0)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetText(self._state:Publisher("num"):CoalesceNil(""))
		)
		self:AddChild(UIElements.New("BaseFrame", "title")
			:SetLayout("HORIZONTAL")
			:SetPadding(0, 8, 0, 0)
			:SetWidth(draggingPublisher:ReplaceBooleanWith(250, nil))
			:SetRelativeLevel(draggingPublisher:ReplaceBooleanWith(20, 1))
			:SetRoundedBackgroundColor("container/highest")
			:BindElement(self._state, "titleFrame")
			:SetManager(self._childManager)
			:AddChildNoLayout(UIElements.New("BaseButton", "dragFrame")
				:SetSize(15, 24)
				:AddAnchor("LEFT", 1, 0)
				:BindElement(self._state, "dragButton")
				:SetScript("OnMouseDown", self._childManager:CallbackToProcessAction("ACTION_START_DRAGGING"))
				:SetScript("OnMouseUp", self._childManager:CallbackToProcessAction("ACTION_STOP_DRAGGING"))
			)
			:AddChild(UIElements.New("BaseFrame", "handleBackground")
				:SetSize(18, 28)
				:SetRoundedBackgroundColor("container/medium")
				-- Draw a line along the right to hide the rounded corners on the right of the handle
				:AddChildNoLayout(UIElements.New("BaseTexture", "line")
					:AddAnchor("TOPRIGHT")
					:AddAnchor("BOTTOMRIGHT")
					:SetWidth(6)
					:SetColor("container/medium")
				)
				:AddChildNoLayout(UIElements.New("BaseTexture", "texture")
					:AddAnchor("LEFT")
					:SetTextureAndSize("iconPack.18x18/Grip")
				)
			)
			:AddChild(UIElements.New("Text", "name")
				:SetWidth("AUTO")
				:SetMargin(8, 0, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(self._state:Publisher("name"))
				:SetTextColor(draggingPublisher:ReplaceBooleanWith("accent/main", "on/surface"))
			)
			:AddChild(UIElements.New("BaseFrame", "spacer"))
			:AddChild(UIElements.New("BaseButton", "configBtn")
				:SetBackgroundAndSize("iconPack.18x18/Popout")
				:SetAction("OnClick", "ACTION_CONFIGURE")
			)
			:AddChild(UIElements.New("BaseButton", "removeBtn")
				:SetMargin(4, 0, 0, 0)
				:SetBackgroundAndSize("iconPack.18x18/Close/Default")
				:SetShown(self._state:PublisherForFunctionWithKeys(private.StateToOverride, "typeName", "groupPath"))
				:SetAction("OnClick", "ACTION_REMOVE")
			)
		)
		self:AddCancellable(draggingPublisher:EndShare())
	end
end

---Configures the group operation row.
---@param typeName string The type of the operation
---@param num number The operation number
---@param name string The operation name
---@param groupPath GroupPathValue The current group path
---@return self
function GroupOperationRow:Configure(typeName, num, name, groupPath)
	self._state.typeName = typeName
	self._state.num = num
	self._state.name = name
	self._state.groupPath = groupPath
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GroupOperationRowState>
---@param state GroupOperationRowState
function GroupOperationRow.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_START_DRAGGING" then
		state.titleFrame:StartMoving()
		state.titleFrame:Draw()
		state.dragButton:SetScript("OnUpdate", manager:CallbackToProcessAction("ACTION_UPDATE_DRAGGING"))
		state.isDragging = true
	elseif action == "ACTION_UPDATE_DRAGGING" then
		self:_SendActionScript("OnDraggingUpdate")
	elseif action == "ACTION_STOP_DRAGGING" then
		state.isDragging = false
		state.dragButton:SetScript("OnUpdate", nil)
		state.titleFrame:StopMovingOrSizing()
		local container = self:GetParentElement() --[[@as BaseFrame]]
		-- TODO: Refactor
		local targetIndex = nil
		for i, v in container:LayoutChildrenIterator() do
			---@cast v BaseFrame
			if i ~= state.num and v:IsMouseOver() then
				targetIndex = i
			end
		end
		if targetIndex then
			GroupOperation.Swap(state.groupPath, state.typeName, state.num, targetIndex)
		end
		self:_SendActionScript("OnDraggingDone")
	elseif action == "ACTION_CONFIGURE" then
		self:_SendActionScript("OnConfigure", state.name)
	elseif action == "ACTION_REMOVE" then
		self:_SendActionScript("OnRemove", state.name)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToOverride(typeName, groupPath)
	if not typeName then
		return false
	end
	return GroupOperation.HasOverride(groupPath, typeName) or groupPath == Group.GetRootPath()
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local Analytics = LibTSMUI:From("LibTSMService"):Include("Util.Analytics")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {
	groupsTemp = {},
}
local TEXT_MARGIN = 8
local ICON_WIDTH = 18
local ICON_MARGIN = 4
local CORNER_RADIUS = 4
local DEFAULT_CONTEXT = { selected = {}, collapsed = {} }
local SELECTION_STR_SEP = "\001"



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupSelector = ComponentRegistry.Define("GroupSelector", "Element")
GroupSelector._STATE_SCHEMA = GroupSelector._STATE_SCHEMA:Extend("GroupSelectorState")
	:AddDeferredUIElementField("dialogGroupTree", "GroupTree")
	:AddBooleanField("singleSelection", false)
	:AddStringField("hintText", "")
	:AddStringField("selectionStr", "")
	:AddNumberField("numGroups", 0)
	:AddStringField("selectedText", L["%d groups"])
	:AddStringField("searchValue", "")
	:Commit()
GroupSelector:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupSelector:__init()
	local frame = self:_CreateButton()
	self.__super:__init(frame)
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	frame:TSMSetScript("OnClick", self._childManager:CallbackToProcessAction("ACTION_HANDLE_CLICK"))

	self._groupTreeContext = CopyTable(DEFAULT_CONTEXT)
	self._customQueryFunc = nil
	self._showCreateNew = false

	self._text = self:_CreateFontString()
	self._text:TSMSetFont("BODY_SMALL")
	self._text:SetPoint("TOPLEFT", TEXT_MARGIN, 0)
	self._text:SetPoint("BOTTOMRIGHT", -ICON_MARGIN - ICON_WIDTH - TEXT_MARGIN, 0)
	self._text:SetJustifyH("LEFT")
	self._text:SetJustifyV("MIDDLE")
	self._text:TSMSetText(self._state:PublisherForFunctionWithKeys(private.StateToText, "singleSelection", "selectionStr", "numGroups", "hintText", "selectedText"))

	self._icon = self:_CreateTexture()
	self._icon:SetPoint("RIGHT", -ICON_MARGIN, 0)
	self._icon:TSMSetTextureAndSize(self._state:Publisher("numGroups"):ToBooleanEquals(0):ReplaceBooleanWith("iconPack.18x18/Add/Default", "iconPack.18x18/Close/Default"))

	self._iconBtn = self:_CreateButton()
	self._iconBtn:SetAllPoints(self._icon)
	self._iconBtn:TSMSetScript("OnClick", self._childManager:CallbackToProcessAction("ACTION_HANDLE_ICON_CLICK"))

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)
	self._backgroundTexture:SubscribeColor(self:_GetOneShotPublisher("container/highest"))

	-- Computed state properties
	self._state:Publisher("selectionStr")
		:Share()
		:Map(String.SeparatedCount, SELECTION_STR_SEP)
		:AssignToTableKey(self._state, "numGroups")
		:CallFunction(self:__closure("_UpdateGroupTreeContextSelection"))
		:EndShare()
end

function GroupSelector:Release()
	wipe(self._groupTreeContext.collapsed)
	wipe(self._groupTreeContext.selected)
	self._customQueryFunc = nil
	self._showCreateNew = false
	self.__super:Release()
end

---Sets the hint text.
---@param text string The hint text
---@return self
function GroupSelector:SetHintText(text)
	assert(type(text) == "string")
	self._state.hintText = text
	return self
end

---Sets the selected text.
---@param text string The selected text (with a %d formatter for the number of groups)
---@return self
function GroupSelector:SetSelectedText(text)
	assert(type(text) == "string" and strmatch(text, "%%d"))
	self._state.selectedText = text
	return self
end

---Sets a custom function to generate a query to use for the group tree.
---@param func function A function to call to create the query (gets auto-released by the GroupTree)
---@return self
function GroupSelector:SetCustomQueryFunc(func)
	self._customQueryFunc = func
	return self
end

---Adds the "Create New Group" option to the group tree.
---@return self
function GroupSelector:AddCreateNew()
	self._showCreateNew = true
	return self
end

---Sets the selection to only handle single selection.
---@param enabled boolean The state of the single selection
---@return self
function GroupSelector:SetSingleSelection(enabled)
	self._state.singleSelection = enabled
	return self
end

---Sets the single selected group path.
---@param selection string|table|nil The selected group(s) or nil if nothing should be selected
---@return self
function GroupSelector:SetSelection(selection)
	wipe(self._groupTreeContext.selected)
	self._state.selectionStr = ""
	if not selection then
		return self
	end
	if self._state.singleSelection then
		self._groupTreeContext.selected[selection] = true
		self._state.selectionStr = selection
	else
		---@cast selection table
		for groupPath in pairs(selection) do
			self._groupTreeContext.selected[groupPath] = true
		end
		self:_UpdateSelectionStringFromGroupTreeContext()
	end
	return self
end

---Returns an iterator for all selected groups.
---@return fun(): GroupPathValue @Iterator with fields: `groupPath`
function GroupSelector:SelectedGroupIterator()
	return String.SplitIterator(self._state.selectionStr, SELECTION_STR_SEP)
end

---Clears all selected groups.
---@param silent? boolean Don't call the selection changed callback
---@return self
function GroupSelector:ClearSelectedGroups(silent)
	wipe(self._groupTreeContext.selected)
	self._state.selectionStr = ""
	if not silent then
		self:_HandleSelectionChanged()
	end
	return self
end

---Binds a state property to the selection string.
---@param state ReactiveState The state to store the values in
---@param key string The state key to store the value at
---@return self
function GroupSelector:MirrorSelectionString(state, key)
	self:_AssignStateKeyPublisher(state:Publisher(key), "selectionStr")
	self._state:Publisher("selectionStr")
		:AssignToTableKey(state, key)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GroupSelectorState>
---@param state GroupSelectorState
function GroupSelector.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_CLICK" then
		local query = self._customQueryFunc and self._customQueryFunc() or GroupOperation.CreateQuery()
		if state.singleSelection then
			query:NotEqual("groupPath", Group.GetRootPath())
		end
		self:_ShowDialog(query)
	elseif action == "ACTION_HANDLE_ICON_CLICK" then
		if state.numGroups > 0 then
			self:ClearSelectedGroups()
		else
			return manager:ProcessAction("ACTION_HANDLE_CLICK")
		end
	elseif action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_TOGGLE_COLLAPSE_ALL" then
		state.dialogGroupTree
			:ToggleExpandAll()
	elseif action == "ACTION_TOGGLE_SELECT_ALL" then
		state.dialogGroupTree --[[@as ApplicationGroupTree]]
			:ToggleSelectAll()
	elseif action == "ACTION_CREATE_GROUP" then
		local newGroupPath = L["New Group"]
		if Group.Exists(newGroupPath) then
			local num = 1
			while Group.Exists(newGroupPath.." "..num) do
				num = num + 1
			end
			newGroupPath = newGroupPath.." "..num
		end
		GroupOperation.CreateGroup(newGroupPath)
		Analytics.Action("CREATED_GROUP", newGroupPath)
		state.dialogGroupTree --[[@as SelectionGroupTree]]
			:SetSelection(newGroupPath)
			:Draw()
	elseif action == "ACTION_SELECT_GROUP" then
		self:GetBaseElement():HideDialog()
		self:_UpdateSelectionStringFromGroupTreeContext()
		self:_HandleSelectionChanged()
	else
		error("Unknown action: "..tostring(action))
	end
end

function GroupSelector.__private:_UpdateSelectionStringFromGroupTreeContext()
	assert(#private.groupsTemp == 0)
	Table.GetKeys(self._groupTreeContext.selected, private.groupsTemp)
	sort(private.groupsTemp)
	self._state.selectionStr = table.concat(private.groupsTemp, SELECTION_STR_SEP)
	wipe(private.groupsTemp)
end

function GroupSelector.__private:_UpdateGroupTreeContextSelection()
	wipe(self._groupTreeContext.selected)
	for groupPath in self:SelectedGroupIterator() do
		self._groupTreeContext.selected[groupPath] = true
	end
end

function GroupSelector.__private:_ShowDialog(query)
	for _ in self._state:WithAutoStorePaused() do
		self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "frame")
			:SetLayout("VERTICAL")
			:SetSize(464, 500)
			:SetPadding(8)
			:AddAnchor("CENTER")
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:SetMouseEnabled(true)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("Text", "title")
					:SetMargin(32, 8, 0, 0)
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetJustifyH("CENTER")
					:SetText(L["Select Group"])
				)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "container")
				:SetLayout("VERTICAL")
				:SetPadding(2)
				:SetBackgroundColor("container/lowest")
				:SetBorderColor("outline/variant")
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(8)
					:AddChild(UIElements.New("Input", "input")
						:AllowItemInsert(true)
						:SetLeadIconTexture("iconPack.18x18/Search")
						:SetClearButtonEnabled(true)
						:SetHintText(L["Search Groups"])
						:BindValue(self._state, "searchValue")
					)
					:AddChild(UIElements.New("BaseButton", "expandAllBtn")
						:SetSize(24, 24)
						:SetMargin(8, 0, 0, 0)
						:SetBackground("iconPack.18x18/Expand All")
						:SetTooltip(L["Expand / Collapse All Groups"])
						:SetAction("OnClick", "ACTION_TOGGLE_COLLAPSE_ALL")
					)
					:AddChildIf(not self._state.singleSelection, UIElements.New("BaseButton", "selectAllBtn")
						:SetSize(24, 24)
						:SetMargin(8, 0, 0, 0)
						:SetBackground("iconPack.18x18/Select All")
						:SetTooltip(L["Select / Deselect All Groups"])
						:SetAction("OnClick", "ACTION_TOGGLE_SELECT_ALL")
					)
				)
				:AddChildIf(self._showCreateNew, UIElements.New("BaseFrame", "create")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 8, 0, 0)
					:AddChild(UIElements.New("SmallTertiaryActionButton", "createGroup")
						:SetWidth("AUTO")
						:SetPadding(8, 8, 0, 0)
						:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.14x14/Add/Circle", "accent/main")).." "..L["Create New Group"])
						:SetAction("OnClick", "ACTION_CREATE_GROUP")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
				:AddChild(UIElements.New(self._state.singleSelection and "SelectionGroupTree" or "ApplicationGroupTree", "groupTree")
					:SetContextTable(self._groupTreeContext, DEFAULT_CONTEXT)
					:BindElement(self._state, "dialogGroupTree")
					:SetQuery(query)
					:SetSearchString(self._state:PublisherForFunctionWithKeys(strlower, "searchValue"))
				)
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "groupBtn")
				:SetMargin(0, 0, 8, 0)
				:SetText(L["Select Group"])
				:SetAction("OnClick", "ACTION_SELECT_GROUP")
			)
		)
	end
end

function GroupSelector.__private:_HandleSelectionChanged()
	self:_SendActionScript("OnSelectionChanged")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToText(singleSelection, selectionStr, numGroups, hintText, selectedText)
	if numGroups == 0 then
		return hintText
	elseif singleSelection then
		return Group.FormatPath(selectionStr)
	else
		return format(selectedText, numGroups)
	end
end

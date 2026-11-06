-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local DragContext = LibTSMUI:Include("Util.DragContext")
local UIElements = LibTSMUI:Include("UIElements")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Analytics = LibTSMUI:From("LibTSMService"):Include("Util.Analytics")
local DRAG_SCROLL_SPEED_FACTOR = 12
local MOVE_FRAME_PADDING = 8
local ADD_TEXTURE = "iconPack.14x14/Add/Circle"
local DELETE_TEXTURE = "iconPack.14x14/Delete"
local ICON_SPACING = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local ManagementGroupTree = ComponentRegistry.Define("ManagementGroupTree", "GroupTree")
ManagementGroupTree._STATE_SCHEMA = ManagementGroupTree._STATE_SCHEMA:Extend("ManagementGroupTreeState")
	:AddDeferredUIElementField("moveText", "Text")
	:Commit()
ManagementGroupTree:_AddActionScripts("OnGroupSelected", "OnAddGroup", "OnDragReceived")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ManagementGroupTree:__init()
	self.__super:__init()

	self._moveFrame = nil ---@type BaseFrame!
	self._dragButton = nil
	self._dragGroupPath = nil
	self._selectedGroup = nil ---@type string!
	self._scrollAmount = 0
end

function ManagementGroupTree:Acquire()
	self._moveFrame = UIElements.New("BaseFrame", self._id.."_MoveFrame")
		:SetLayout("VERTICAL")
		:SetHeight(20)
		:SetStrata("TOOLTIP")
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("accent/main")
		:SetContext(self)
		:AddChild(UIElements.New("Text", "text")
			:SetFont("BODY_XSMALL")
			:SetJustifyH("CENTER")
			:BindElement(self._state, "moveText")
		)
	self._moveFrame:SetParent(self._frame)
	self._moveFrame:Hide()
	self._moveFrame:SetScript("OnShow", self:__closure("_HandleMoveFrameShow"))
	self._moveFrame:SetScript("OnUpdate", self:__closure("_HandleMoveFrameUpdate"))

	self.__super:Acquire()
end

function ManagementGroupTree:Release()
	self._selectedGroup = nil
	self._moveFrame:Release()
	self._moveFrame = nil
	self._dragButton = nil
	self._dragGroupPath = nil
	self.__super:Release()
end

---Sets the selected group.
---@param groupPath string The selected group's path
---@param redraw? boolean Whether or not to redraw the management group tree
---@return self
function ManagementGroupTree:SetSelectedGroup(groupPath, redraw)
	if groupPath == self._selectedGroup then
		return self
	end
	local prevSelectedGroup = self._selectedGroup
	self._selectedGroup = groupPath

	local row = self:_GetRowForGroupPath(groupPath)
	if row then
		self:_DrawSelectedState(row)
	end
	if prevSelectedGroup then
		local prevRow = self:_GetRowForGroupPath(prevSelectedGroup)
		if prevRow then
			self:_DrawSelectedState(prevRow)
		end
	end

	self._selectedGroup = groupPath
	self:_SendActionScript("OnGroupSelected", groupPath)

	if redraw then
		-- Make sure this group is visible (its parent is expanded)
		local parent = Group.GetParent(groupPath)
		local changed = false
		if self._contextTable.collapsed[Group.GetRootPath()] then
			self._contextTable.collapsed[Group.GetRootPath()] = nil
			changed = true
		end
		while parent and parent ~= Group.GetRootPath() do
			if self._contextTable.collapsed[parent] then
				self._contextTable.collapsed[parent] = nil
				changed = true
			end
			parent = Group.GetParent(parent)
		end
		if changed then
			self:_HandleQueryUpdate()
		end
		self:_ScrollToRow(Table.KeyByValue(self._groupPath, groupPath))
	end
	self:_SendActionScript("OnGroupSelected", groupPath)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)

	row:EnableDragging(self:__closure("_HandleDragStart"), nil, self:__closure("_HandleDragReceived"))

	-- Add
	local add = row:AddTexture("add")
	add:TSMSetTextureAndSize(ADD_TEXTURE)

	-- Delete
	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)

	-- Layout the elements
	delete:SetPoint("RIGHT", -Theme.GetColSpacing() * 1.5, 0)
	add:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowDraw(row)
	self.__super:_HandleRowDraw(row)
	self:_DrawAddDeleteIcons(row)
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowEnter(row)
	self.__super:_HandleRowEnter(row)
	self:_DrawAddDeleteIcons(row)
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowLeave(row)
	self.__super:_HandleRowLeave(row)
	self:_DrawAddDeleteIcons(row)
end

---@param row ListRow
function ManagementGroupTree.__protected:_DrawAddDeleteIcons(row)
	local groupPath = self._groupPath[row:GetDataIndex()]
	local isSelected = self:_IsSelected(groupPath)
	local add = row:GetTexture("add")
	local delete = row:GetTexture("delete")
	local text = row:GetText("text")
	if row:IsHovering() or isSelected then
		add:Show()
		text:SetPoint("RIGHT", add, "LEFT", -ICON_SPACING, 0)
		if groupPath == Group.GetRootPath() then
			delete:Hide()
			add:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
		else
			delete:Show()
			add:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
		end
	else
		add:Hide()
		delete:Hide()
		text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	end
end

---@param row ListRow
function ManagementGroupTree.__protected:_DrawSelectedState(row)
	self.__super:_DrawSelectedState(row)
	self:_DrawAddDeleteIcons(row)
end

function ManagementGroupTree.__protected:_SetCollapsed(groupPath, collapsed)
	self.__super:_SetCollapsed(groupPath, collapsed)
	if collapsed and self._selectedGroup ~= groupPath and strmatch(self._selectedGroup, "^"..String.Escape(groupPath)) then
		-- We collapsed a parent of the selected group, so select the group we just collapsed instead
		self:SetSelectedGroup(groupPath, true)
	end
end

function ManagementGroupTree.__protected:_IsSelected(groupPath)
	return groupPath == self._selectedGroup
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowClick(row, mouseButton)
	if self.__super:_HandleRowClick(row, mouseButton) then
		return
	end

	local groupPath = self._groupPath[row:GetDataIndex()]
	if row:GetTexture("add"):IsMouseOver() then
		self:_HandleAddClick(groupPath)
		return
	elseif row:GetTexture("delete"):IsMouseOver() then
		self:_HandleDeleteClick(groupPath)
		return
	end

	if self._selectedGroup == groupPath then
		return
	end
	local prevSelectedGroup = self._selectedGroup
	self._selectedGroup = groupPath

	self:_DrawSelectedState(row)
	if prevSelectedGroup then
		local prevRow = self:_GetRowForGroupPath(prevSelectedGroup)
		if prevRow then
			self:_DrawSelectedState(prevRow)
		end
	end

	self._selectedGroup = groupPath
	self:_SendActionScript("OnGroupSelected", groupPath)
end

function ManagementGroupTree.__private:_HandleAddClick(groupPath)
	local newGroupPath = Group.JoinPath(groupPath, L["New Group"])
	if Group.Exists(newGroupPath) then
		local num = 1
		while Group.Exists(newGroupPath.." "..num) do
			num = num + 1
		end
		newGroupPath = newGroupPath.." "..num
	end
	GroupOperation.CreateGroup(newGroupPath)
	Analytics.Action("CREATED_GROUP", newGroupPath)
	self:SetSelectedGroup(newGroupPath, true)
	self:_SendActionScript("OnAddGroup")
end

function ManagementGroupTree.__private:_HandleDeleteClick(groupPath)
	local groupColor = Theme.GetGroupColor(Group.GetLevel(groupPath))
	local desc = format(L["Deleting this group (%s) will also remove any sub-groups attached to this group."], groupColor:ColorText(Group.GetName(groupPath)))
	self:GetBaseElement():ShowConfirmationDialog(L["Delete Group?"], desc, self:__closure("_DeleteConfirmed"), groupPath)
end

function ManagementGroupTree.__private:_DeleteConfirmed(groupPath)
	GroupOperation.DeleteGroup(groupPath)
	Analytics.Action("DELETED_GROUP", groupPath)
	self:SetSelectedGroup(Group.GetRootPath(), true)
end

---@param row ListRow
function ManagementGroupTree.__private:_HandleDragStart(row, mouseButton)
	local groupPath = self._groupPath[row:GetDataIndex()]
	if groupPath == Group.GetRootPath() then
		-- Don't do anything for the root group
		return
	end
	self._dragButton = mouseButton
	self._dragGroupPath = groupPath
	self._moveFrame:Show()
	self._moveFrame:SetHeight(self.ROW_HEIGHT)
	self._state.moveText
		:SetTextColor(Theme.GetGroupColorKey(Group.GetLevel(groupPath)))
		:SetText(Group.GetName(groupPath))
		:SetWidth(1000)
		:Draw()
	self._moveFrame:SetWidth(self._state.moveText:GetStringWidth() + MOVE_FRAME_PADDING * 2)
	self._moveFrame:Draw()
end

---@param row ListRow
function ManagementGroupTree.__private:_HandleDragReceived(row)
	if self._dragGroupPath then
		self._dragButton = nil
		self._moveFrame:Hide()
		local destPath = self._groupPath[row:GetDataIndex()]
		local oldPath = self._dragGroupPath
		self._dragGroupPath = nil
		if not destPath or destPath == oldPath or Group.IsChild(destPath, oldPath) then
			return
		end
		local newPath = Group.JoinPath(destPath, Group.GetName(oldPath))
		if oldPath == newPath then
			return
		elseif Group.Exists(newPath) then
			ChatMessage.PrintfUser(L["Failed to move group, as a group with the same name already exists in the target location."])
			return
		end

		GroupOperation.MoveGroup(oldPath, newPath)
		Analytics.Action("MOVED_GROUP", oldPath, newPath)
		self:SetSelectedGroup(newPath, true)
	else
		local context = DragContext.Get()
		if context then
			self:_SendActionScript("OnDragReceived", context, self._groupPath[row:GetDataIndex()])
		end
	end
end

function ManagementGroupTree.__private:_HandleMoveFrameShow()
	self._scrollAmount = 0
end

function ManagementGroupTree.__private:_HandleMoveFrameUpdate()
	if not IsMouseButtonDown(self._dragButton) then
		-- No longer dragging
		self._dragGroupPath = nil
		self._dragButton = nil
		self._moveFrame:Hide()
		return
	end

	-- TODO: Fix the private _frame access
	local uiScale = self._moveFrame._frame:GetEffectiveScale() ---@diagnostic disable-line: invisible
	local x, y = GetCursorPosition()
	x = x / uiScale
	y = y / uiScale
	self._moveFrame._frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y) ---@diagnostic disable-line: invisible

	-- Figure out if we're above or below the frame for scrolling while dragging
	local top = self._frame:GetTop()
	local bottom = self._frame:GetBottom()
	if y > top then
		self._scrollAmount = top - y
	elseif y < bottom then
		self._scrollAmount = bottom - y
	else
		self._scrollAmount = 0
	end

	self._vScrollbar:SetValue(self._vScrollbar:GetValue() + self._scrollAmount / DRAG_SCROLL_SPEED_FACTOR)
end

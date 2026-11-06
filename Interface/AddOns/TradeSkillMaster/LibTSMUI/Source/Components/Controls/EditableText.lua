-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local ItemLinked = LibTSMUI:Include("Util.ItemLinked")
local EnumType = LibTSMUI:From("LibTSMUtil"):Include("BaseType.EnumType")
local STRING_RIGHT_PADDING = 16
local ITEM_INSERT_MODE = EnumType.New("ITEM_INSERT_MODE", {
	DISABLED = EnumType.NewValue(),
	NAME = EnumType.NewValue(),
	LINK = EnumType.NewValue(),
})



-- ============================================================================
-- Element Definition
-- ============================================================================

local EditableText = ComponentRegistry.Define("EditableText", "Text")
EditableText._STATE_SCHEMA = EditableText._STATE_SCHEMA:Extend("EditableTextState")
	:AddBooleanField("editing", false)
	:Commit()
EditableText:_AddActionScripts("OnValueChanged", "OnEditingChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function EditableText:__init()
	local button = self:_CreateButton()
	self._frame = button
	self.__super:__init(button)

	self._editBox = self:_CreateEditBox(button)
	self._editBox:SetAllPoints()
	self._itemInsertMode = ITEM_INSERT_MODE.DISABLED

	local editingPublisher = self._state:Publisher("editing")
		:Share()
		:CallFunction(self:__closure("_HandleEditingChanged"))
		:CallFunction(self:__closure("_DrawForAutoWidth"))

	self._editBox:SetShadowColor(0, 0, 0, 0)
	self._editBox:SetAutoFocus(false)
	self._editBox:TSMSetScript("OnEscapePressed", self:__closure("_HandleEscapePressed"))
	self._editBox:TSMSetScript("OnEnterPressed", self:__closure("_HandleEnterPressed"))
	self._editBox:TSMSetScript("OnEditFocusLost", self:__closure("_HandleEditFocusLost"))
	self._editBox:TSMSetFont(self._state:Publisher("font"))
	self._editBox:TSMSetSpacing(self._state:Publisher("textSpacing"))
	self._editBox:TSMSetJustifyH(self._state:Publisher("justifyH"))
	self._editBox:TSMSetJustifyV(self._state:Publisher("justifyV"))
	self._editBox:TSMSubscribeTextColor(self._state:Publisher("color"))
	self._editBox:TSMSetText(self._state:Publisher([[editing and textStr or ""]]))
	self._editBox:TSMSetShown(editingPublisher)
	self._editBox:TSMSetFocused(editingPublisher)
	self._editBox:TSMSetAllHighlighted(editingPublisher)

	self._text:TSMSetShown(editingPublisher:InvertBoolean())

	self._frame:TSMSetScript("OnDoubleClick", self:__closure("_HandleDoubleClick"))

	editingPublisher:EndShare()
end

function EditableText:Acquire()
	self.__super:Acquire()
	self._frame:RegisterForClicks("LeftButtonUp")
	ItemLinked.RegisterCallback(self:__closure("_HandleItemLinked"))
end

function EditableText:Release()
	self._editBox:ClearFocus()
	ItemLinked.UnregisterCallback(self:__closure("_HandleItemLinked"))
	self._itemInsertMode = ITEM_INSERT_MODE.DISABLED
	self.__super:Release()
end

---Sets whether or not the text is currently being edited.
---@param editing boolean The editing state to set
---@return self
function EditableText:SetEditing(editing)
	self._state.editing = editing
	return self
end

---Allows inserting an item into the editable text by linking it while the editable text has focus.
---@param insertLink boolean Insert the link instead of the item name
---@return self
function EditableText:AllowItemInsert(insertLink)
	assert(insertLink == nil or type(insertLink) == "boolean")
	self._itemInsertMode = insertLink and ITEM_INSERT_MODE.LINK or ITEM_INSERT_MODE.NAME
	return self
end

---Binds a state property to whether or not the text is currently being edited.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function EditableText:BindEditing(state, key)
	self._bindings:Add("EDITING", state, key)
	return self
end

---Highlights all the text.
---@return self
function EditableText:HighlightAll()
	self._editBox:HighlightText(1, -1)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function EditableText:_GetPreferredDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth and not self._state.editing then
		return self:GetStringWidth() + STRING_RIGHT_PADDING
	else
		return self.__super.__super:_GetPreferredDimension(dimension)
	end
end

function EditableText.__private:_HandleItemLinked(name, link)
	if not self:IsVisible() or not self._state.editing then
		return false
	end
	if self._itemInsertMode == ITEM_INSERT_MODE.DISABLED then
		return false
	elseif self._itemInsertMode == ITEM_INSERT_MODE.LINK then
		self._editBox:Insert(link)
	elseif self._itemInsertMode == ITEM_INSERT_MODE.NAME then
		self._editBox:Insert(name)
	else
		error("Invalid item insert mode: "..tostring(self._itemInsertMode))
	end
	return true
end

function EditableText.__private:_HandleDoubleClick()
	self:SetEditing(true)
end

function EditableText.__private:_HandleEscapePressed()
	self:SetEditing(false)
end

function EditableText.__private:_HandleEnterPressed()
	local newText = self._editBox:GetText()
	self:SetEditing(false)
	self:_SendActionScript("OnValueChanged", newText)
end

function EditableText.__private:_HandleEditFocusLost()
	self:SetEditing(false)
end

function EditableText.__private:_HandleEditingChanged(editing)
	self._bindings:Process("EDITING", editing)
	self:_SendActionScript("OnEditingChanged")
end

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
local EXPANDER_SIZE = 18
local TEXT_PADDING = 8
local EXPANDER_PADDING = 4
local CORNER_RADIUS = 4
local MIN_DIALOG_WIDTH = 100
local DIALOG_PADDING_BOTTOM = 4
local STYLE_INFO = { ---@type table<BaseDropdown.State,BaseDropdown.StyleInfo>
	ACTIVE = {
		backgroundColor = "container/lowest",
		borderColor = "outline/variant",
		textColor = "on/surface",
		hintTextColor = "on/surface/low",
	},
	HOVER = {
		backgroundColor = "container/lowest",
		borderColor = "outline/main",
		textColor = "on/surface",
		hintTextColor = "on/surface/low",
	},
	FOCUS = {
		backgroundColor = "container/lowest",
		borderColor = "outline/main",
		textColor = "on/surface",
		hintTextColor = "on/surface/low%40",
	},
	DISABLED = {
		backgroundColor = "container/lowest%40",
		borderColor = "outline/variant%40",
		textColor = "on/surface%40",
		hintTextColor = "on/surface/low%40",
	},
}

---@alias BaseDropdown.State
---|'"ACTIVE"'
---|'"HOVER"'
---|'"FOCUS"'
---|'"DISABLED"'

---@class BaseDropdown.StyleInfo
---@field backgroundColor string
---@field borderColor string
---@field textColor string
---@field hintTextColor string



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseDropdown = ComponentRegistry.Define("BaseDropdown", "Text", "ABSTRACT")
BaseDropdown._STATE_SCHEMA = BaseDropdown._STATE_SCHEMA:Extend("BaseDropdownState")
	:UpdateFieldDefault("font", "BODY_SMALL")
	:AddDeferredUIElementField("dialogFrame", "DropdownDialog")
	:AddBooleanField("disabled", false)
	:AddStringField("hintText", "")
	:AddStringField("currentSelectionStr", "")
	:AddBooleanField("mouseOver", false)
	:Commit()
BaseDropdown:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function BaseDropdown:__init(isMultiselect)
	local frame = self:_CreateButton()
	self._frame = frame
	self.__super:__init(frame)

	self._isMultiselect = isMultiselect
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._items = {}

	local styleInfoPublisher = self._state:Publisher([[(disabled and "DISABLED") or (mouseOver and "HOVER") or "ACTIVE"]])
		:Map(STYLE_INFO)
		:Share()

	self._frame:TSMSetDisabled(self._state:Publisher("disabled"))
	self._frame:TSMHookScript("OnEnter", self:__closure("_HandleFrameEnter"))
	self._frame:TSMHookScript("OnLeave", self:__closure("_HandleFrameLeave"))
	self._frame:TSMSetScript("OnClick", self._childManager:CallbackToProcessAction("ACTION_TOGGLE_DIALOG"))

	self._text:ClearAllPoints()
	self._text:SetPoint("TOPLEFT", TEXT_PADDING, 0)
	self._text:SetPoint("BOTTOMRIGHT", -TEXT_PADDING - EXPANDER_SIZE, 0)
	self._text:TSMSubscribeTextColor(styleInfoPublisher:Map("textColor"):IgnoreDuplicates())

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)
	self._backgroundTexture:SubscribeColor(styleInfoPublisher:Map("borderColor"):IgnoreDuplicates())

	self._borderOverlay = self:_CreateRectangle(1)
	self._borderOverlay:SetCornerRadius(CORNER_RADIUS)
	self._borderOverlay:SetInset(1)
	self._borderOverlay:SubscribeColor(styleInfoPublisher:Map("backgroundColor"):IgnoreDuplicates())

	self._arrow = self:_CreateTexture()
	self._arrow:TSMSetTextureAndSize("iconPack.18x18/Chevron/Down")
	self._arrow:SetPoint("RIGHT", -EXPANDER_PADDING, 0)
	self._arrow:TSMSubscribeVertexColor(styleInfoPublisher:Map("textColor"):IgnoreDuplicates())

	self._hintText = self:_CreateFontString()
	self._hintText:TSMSetFont(self._state:Publisher("font"))
	self._hintText:SetJustifyH("LEFT")
	self._hintText:SetJustifyV("MIDDLE")
	self._hintText:TSMSetText(self._state:Publisher("hintText"))
	self._hintText:TSMSetShown(self._state:Publisher([[currentSelectionStr == "" and hintText ~= ""]]))
	self._hintText:TSMSubscribeTextColor(styleInfoPublisher:Map("hintTextColor"):IgnoreDuplicates())
	self._hintText:SetPoint("TOPLEFT", TEXT_PADDING, 0)
	self._hintText:SetPoint("BOTTOMRIGHT", -TEXT_PADDING - EXPANDER_SIZE, 0)

	self._widthText = self:_CreateFontString()
	self._widthText:Hide()
	self._widthText:TSMSetFont(self._state:Publisher("font"))

	styleInfoPublisher:EndShare()

	-- Computed state properties
	self._state:Publisher("currentSelectionStr")
		:AssignToTableKey(self._state, "textStr")
end

function BaseDropdown:Release()
	wipe(self._items)
	self._frame:Enable()
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the hint text which is shown when there's no selection and in the dialog.
---@param text string The hint text string
---@return self
function BaseDropdown:SetHintText(text)
	self._state.hintText = text
	return self
end

---Set whether or not the dropdown is disabled.
---@param value boolean|ReactivePublisherSchemaBase Whether or not to disable the dropdown or a publisher
---@return self
function BaseDropdown:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.disabled = value
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end

---@deprecated
function BaseDropdown:SetBackgroundColor()
	error("BaseDropdown does not support this method", 2)
end

---@deprecated
function BaseDropdown:SetText()
	error("BaseDropdown does not support this method", 2)
end

---@deprecated
function BaseDropdown:SetTextColor()
	error("BaseDropdown does not support this method", 2)
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<BaseDropdownState>
---@param state BaseDropdownState
function BaseDropdown.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE_DIALOG" then
		if state.dialogFrame then
			self:GetBaseElement():HideDialog()
		else
			self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "dialog")
				:SetLayout("VERTICAL")
				:AddAnchor("TOPLEFT", self)
				:SetRoundedBackgroundColor(STYLE_INFO.FOCUS.backgroundColor)
				:SetBorderColor(STYLE_INFO.FOCUS.borderColor)
				:SetSize(self:_GetDialogSize())
				:AddChild(UIElements.New("BaseFrame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(self:_GetDimension("HEIGHT"))
					:AddChild(UIElements.New("Text", "text")
						:SetMargin(TEXT_PADDING, TEXT_PADDING, 0, 0)
						:SetFont(state.font)
						:SetTextColor(STYLE_INFO.FOCUS.hintTextColor)
						:SetText(state.hintText)
					)
					:AddChildIf(self._isMultiselect, UIElements.New("BaseButton", "selectAllBtn")
						:SetMargin(0, EXPANDER_PADDING, 0, 0)
						:SetSize(EXPANDER_SIZE, EXPANDER_SIZE)
						:SetBackground("iconPack.18x18/Select All")
						:SetManager(self._childManager)
						:SetAction("OnClick", "ACTION_DIALOG_TOGGLE_SELECT_ALL")
						:SetTooltip(L["Select / Deselect All Items"])
					)
					:AddChild(UIElements.New("BaseTexture", "arrow")
						:SetMargin(0, EXPANDER_PADDING, 0, 0)
						:SetSize(EXPANDER_SIZE, EXPANDER_SIZE)
						:SetTextureAndSize("iconPack.18x18/Chevron/Up")
					)
				)
				:AddChild(self:_CreateDialogList()
					:SetMargin(1, 1, 0, DIALOG_PADDING_BOTTOM)
				)
			)
		end
	elseif action == "ACTION_HANDLE_SELECTION_CHANGED" then
		error("Action must be handled by parent class")
	elseif action == "ACTION_DIALOG_TOGGLE_SELECT_ALL" then
		assert(state.dialogFrame)
		state.dialogFrame:ToggleSelectAll()
	else
		error("Unknown action: "..tostring(action))
	end
end

function BaseDropdown.__private:_GetDialogSize()
	local width = 0
	self._widthText:Show()
	if self._state.hintText ~= "" then
		self._widthText:SetText(self._state.hintText)
		width = max(width, self._widthText:GetUnboundedStringWidth() + (EXPANDER_PADDING + EXPANDER_SIZE) * (self._isMultiselect and 2 or 1) + TEXT_PADDING * 2)
	end
	for _, item in ipairs(self._items) do
		self._widthText:SetText(item)
		width = max(width, self._widthText:GetUnboundedStringWidth() + 36)
	end
	self._widthText:Hide()
	width = max(width + Theme.GetColSpacing() * 2 + 2, self:_GetDimension("WIDTH"), MIN_DIALOG_WIDTH)
	local height = self:_GetDialogListHeight() + self:_GetDimension("HEIGHT") + DIALOG_PADDING_BOTTOM
	return width, height
end

---@return Element
function BaseDropdown.__protected:_CreateDialogList()
	return UIElements.New("DropdownDialog", "dropdown")
		:SetRoundedBackgroundColor(STYLE_INFO.FOCUS.backgroundColor)
		:SetManager(self._childManager)
		:BindElement(self._state, "dialogFrame")
		:SetMultiselect(self._isMultiselect)
		:SetItems(self._items, self:_GetDialogSelection())
		:SetAction("OnSelectionChanged", "ACTION_HANDLE_SELECTION_CHANGED")
end

---@return number
function BaseDropdown.__protected:_GetDialogListHeight()
	if #self._items == 0 then
		return 16
	elseif #self._items <= 8 then
		return #self._items * 20
	else
		return 150
	end
end

function BaseDropdown.__abstract:_GetDialogSelection()
end

function BaseDropdown.__private:_HandleFrameEnter()
	self._state.mouseOver = true
end

function BaseDropdown.__private:_HandleFrameLeave()
	self._state.mouseOver = false
end

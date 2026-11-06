-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local private = {}
local HEADER_HEIGHT = 24
local ROW_HEIGHT = 20



-- ============================================================================
-- Element Definition
-- ============================================================================

local FilterMenuDialogRow = ComponentRegistry.Define("FilterMenuDialogRow", "BaseButton")

local FilterMenuDialog = ComponentRegistry.Define("FilterMenuDialog", "BaseFrame")
FilterMenuDialog._STATE_SCHEMA = FilterMenuDialog._STATE_SCHEMA:Extend("FilterMenuDialogState")
	:AddDeferredUIElementField("rows", "BaseFrame")
	:AddStringField("title", "")
	:AddNumberField("numRows", 0)
	:AddNumberField("numChecked", 0)
	:Commit()
FilterMenuDialog:_AddActionScripts("OnRowClick", "OnClear")



-- ============================================================================
-- FilterMenuDialogRow Protected Class Methods
-- ============================================================================

function FilterMenuDialogRow.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		return self.__super:_SendActionScript(script, self:GetContext())
	else
		return self.__super:_SendActionScript(script, ...)
	end
end



-- ============================================================================
-- FilterMenuDialog Public Class Methods
-- ============================================================================

function FilterMenuDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._rows = {}
	self._checked = {}
end

function FilterMenuDialog:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self
			:SetLayout("VERTICAL")
			:SetWidth(178)
			:SetHeight(self._state:Publisher("numRows"):Map(private.NumRowsToHeight))
			:SetPadding(1)
			:SetMouseEnabled(true)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(HEADER_HEIGHT)
				:SetPadding(8, 0, 0, 0)
				:SetManager(self._childManager)
				:AddChild(UIElements.New("Text", "title")
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(self._state:Publisher("title"))
				)
				:AddChild(UIElements.New("SmallTertiaryActionButton", "clearBtn")
					:SetWidth("AUTO")
					:SetPadding(8, 8, 0, 0)
					:SetText(L["Clear"])
					:DisableClickCooldown()
					:SetDisabled(self._state:Publisher("numChecked"):ToBooleanEquals(0))
					:SetAction("OnClick", "ACTION_CLEAR")
				)
			)
			:AddChild(UIElements.New("HorizontalLine", "line"))
			:AddChild(UIElements.New("BaseFrame", "rows")
				:SetLayout("VERTICAL")
				:SetManager(self._childManager)
				:BindElement(self._state, "rows")
			)
	end
end

function FilterMenuDialog:Release()
	wipe(self._rows)
	wipe(self._checked)
	self.__super:Release()
end

---Sets the title.
---@param title string The title text
---@return self
function FilterMenuDialog:SetTitle(title)
	self._state.title = title
	return self
end

---Adds a filter row.
---@param id string The id of the row
---@param label string The text to display
---@param checked boolean Whether or not the filter is active
---@return self
function FilterMenuDialog:AddRow(id, label, checked)
	assert(not self._rows[id])
	local row = UIElements.New("FilterMenuDialogRow", id)
		:SetHeight(ROW_HEIGHT)
		:SetPadding(8, 8, 0, 0)
		:SetFont("BODY_SMALL")
		:SetJustifyH("LEFT")
		:SetBackgroundWithHighlight("container/low")
		:SetText(label)
		:SetContext(id)
		:SetAction("OnClick", "ACTION_ROW_CLICKED")
	self._rows[id] = row
	self._checked[id] = false
	self._state.rows:AddChild(row)
	self._state.numRows = self._state.numRows + 1
	self:_SetRowChecked(id, checked)
	return self
end



-- ============================================================================
-- FilterMenuDialog Private Class Methods
-- ============================================================================

---@param manager UIManager<FilterMenuDialogState>
---@param state FilterMenuDialogState
function FilterMenuDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_ROW_CLICKED" then
		local id = ...
		local checked = not self._checked[id]
		self:_SetRowChecked(id, checked)
		self:_SendActionScript("OnRowClick", id, checked)
	elseif action == "ACTION_CLEAR" then
		for id, checked in pairs(self._checked) do
			if checked then
				self:_SetRowChecked(id, false)
			end
		end
		self:_SendActionScript("OnClear")
	else
		error("Unknown action: "..tostring(action))
	end
end

function FilterMenuDialog.__private:_SetRowChecked(id, checked)
	if self._checked[id] == checked then
		return
	end
	self._checked[id] = checked
	self._state.numChecked = self._state.numChecked + (checked and 1 or -1)
	if checked then
		self._rows[id]:SetIcon("iconPack.12x12/Checkmark/Default", "RIGHT")
	else
		self._rows[id]:SetIcon(nil, nil)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NumRowsToHeight(numRows)
	return HEADER_HEIGHT + numRows * ROW_HEIGHT + 3
end

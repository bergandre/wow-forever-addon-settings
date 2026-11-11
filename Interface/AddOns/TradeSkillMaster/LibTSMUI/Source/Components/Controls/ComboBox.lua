-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local UIElements = LibTSMUI:Include("UIElements")
local private = {
	itemsTemp = {},
}
local MENU_ROW_HEIGHT = 20
local MENU_MAX_VISIBLE_ROWS = 6
local MENU_PADDING_BOTTOM = 4
local CATEGORY_ICON = "iconPack.12x12/Chevron/Right"
local MENU_ENTRY_BACK = 0



-- ============================================================================
-- Element Definition
-- ============================================================================

local ComboBox = ComponentRegistry.Define("ComboBox", "Input")
ComboBox._STATE_SCHEMA = ComboBox._STATE_SCHEMA:Extend("ComboBoxState")
	:AddOptionalUIElementField("menu", "BaseFrame")
	:AddOptionalUIElementField("menuList", "SelectionList")
	:Commit()

---@event ComboBoxAction
---| "ACTION_MENU_ENTRY_SELECTED" -> entry: string



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ComboBox:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._menuCategoryLabels = {}
	self._menuCategoryFuncs = {} ---@type (fun(context: any): (fun(): string?))[]
	self._menuCategoryContexts = {} ---@type table<number, any>
	self._menuEntries = {}
	self._menuEntryValues = {}
	self._closedStrata = nil

	self._state:Publisher("menu")
		:ToBooleanNotEquals(nil)
		:IgnoreDuplicates()
		:CallFunction(self:__closure("_HandleMenuShownChanged"))
end

function ComboBox:Release()
	self._closedStrata = nil
	wipe(self._menuCategoryLabels)
	wipe(self._menuCategoryFuncs)
	wipe(self._menuCategoryContexts)
	wipe(self._menuEntries)
	wipe(self._menuEntryValues)
	self.__super:Release()
end

---Adds a category to the menu which is shown while the combo box is focused. Selecting the category shows its items.
---@param label string The category label
---@param iterFunc fun(context: any): (fun(): string?) Function which returns an iterator over the category's items
---@param context? any Context to pass to the iterator function
---@return self
function ComboBox:AddMenuCategory(label, iterFunc, context)
	assert(type(label) == "string" and type(iterFunc) == "function")
	tinsert(self._menuCategoryLabels, label)
	tinsert(self._menuCategoryFuncs, iterFunc)
	self._menuCategoryContexts[#self._menuCategoryLabels] = context
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ComboBox.__protected:_ShouldKeepFocus()
	local menu = self._state.menu
	if menu and IsMouseButtonDown("LeftButton") and menu:IsVisible() and menu:IsMouseOver() then
		return true
	end
	return self.__super:_ShouldKeepFocus()
end

function ComboBox.__protected:_OnFocusGained()
	if self._state.menu or #self._menuCategoryLabels == 0 then
		return
	end
	self:_ShowMenu()
end

function ComboBox.__protected:_OnFocusLost()
	if not self._state.menu then
		return
	end
	self:GetBaseElement():HideDialog()
end

---@param manager UIManager<ComboBoxState>
---@param state ComboBoxState
---@param action ComboBoxAction
---@param ... params<ComboBoxAction>
function ComboBox.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_MENU_ENTRY_SELECTED" then
		local entry = ...
		local value = self._menuEntryValues[entry]
		if value == MENU_ENTRY_BACK then
			self:_ShowMenuCategories()
		elseif type(value) == "number" then
			self:_ShowMenuCategoryItems(value)
		else
			assert(type(value) == "string")
			self:_SelectValue(value)
			self:GetBaseElement():HideDialog()
			self:SetFocused(false)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end

function ComboBox.__private:_ShowMenu()
	self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "menu")
		:SetLayout("VERTICAL")
		:SetPadding(1, 1, self:_GetDimension("HEIGHT"), MENU_PADDING_BOTTOM)
		:AddAnchor("TOPLEFT", self)
		:AddAnchor("TOPRIGHT", self)
		:SetRoundedBackgroundColor("container/lowest")
		:SetBorderColor("outline/main")
		:SetMouseEnabled(true)
		:BindElement(self._state, "menu")
		:AddChild(UIElements.New("SelectionList", "list")
			:SetManager(self._childManager)
			:SetAction("OnEntrySelected", "ACTION_MENU_ENTRY_SELECTED")
			:BindElement(self._state, "menuList")
		)
	)
	self:_ShowMenuCategories()
end

function ComboBox.__private:_HandleMenuShownChanged(shown)
	self._state.backgroundShown = not shown
	if shown then
		self._closedStrata = self._frame:GetFrameStrata()
		self._frame:SetFrameStrata("DIALOG")
	elseif self._closedStrata then
		self._frame:SetFrameStrata(self._closedStrata)
		self._frame:SetFrameLevel(self._frame:GetParent():GetFrameLevel() + (self._state.relativeLevel or 1))
		self._closedStrata = nil
	end
end

function ComboBox.__private:_ShowMenuCategories()
	self:_ClearMenuEntries()
	local categoryIcon = TextureAtlas.GetTextureLink(CATEGORY_ICON)
	for i, label in ipairs(self._menuCategoryLabels) do
		self:_AddMenuEntry(label.."  "..categoryIcon, i)
	end
	self:_DrawMenu()
end

function ComboBox.__private:_ShowMenuCategoryItems(categoryIndex)
	self:_ClearMenuEntries()
	local backIcon = TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey(CATEGORY_ICON))
	self:_AddMenuEntry(backIcon.."  "..self._menuCategoryLabels[categoryIndex], MENU_ENTRY_BACK)
	assert(#private.itemsTemp == 0)
	for item in self._menuCategoryFuncs[categoryIndex](self._menuCategoryContexts[categoryIndex]) do
		if not self._menuEntryValues[item] then
			tinsert(private.itemsTemp, item)
			self._menuEntryValues[item] = item
		end
	end
	sort(private.itemsTemp)
	for _, item in ipairs(private.itemsTemp) do
		tinsert(self._menuEntries, item)
	end
	wipe(private.itemsTemp)
	self:_DrawMenu()
end

function ComboBox.__private:_ClearMenuEntries()
	wipe(self._menuEntries)
	wipe(self._menuEntryValues)
end

function ComboBox.__private:_AddMenuEntry(entry, value)
	tinsert(self._menuEntries, entry)
	self._menuEntryValues[entry] = value
end

function ComboBox.__private:_DrawMenu()
	local menu, menuList = self._state.menu, self._state.menuList
	assert(menu and menuList)
	local numVisibleRows = min(#self._menuEntries, MENU_MAX_VISIBLE_ROWS)
	menuList:SetEntries(self._menuEntries)
	menu:SetHeight(self:_GetDimension("HEIGHT") + numVisibleRows * MENU_ROW_HEIGHT + MENU_PADDING_BOTTOM)
	menu:Draw()
end

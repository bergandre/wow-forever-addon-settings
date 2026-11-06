-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local ColorPicker = App:From("LibTSMUI"):Include("Util.ColorPicker")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local ThemeColorSets = App:From("LibTSMApp"):Include("Service.ThemeColorSets")
local private = {}
local LABELS = { ---@type table<ThemeBrandRampKey,string>
	[ThemeColorSets.ThemeBrandRampKey.NEUTRAL] = L["Neutral"],
	[ThemeColorSets.ThemeBrandRampKey.PRIMARY] = L["Primary"],
	[ThemeColorSets.ThemeBrandRampKey.SECONDARY] = L["Secondary"],
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local EditableThemeColor = UIElements.Define("EditableThemeColor", "BaseFrame")
EditableThemeColor._STATE_SCHEMA = EditableThemeColor._STATE_SCHEMA:Extend("EditableThemeColorState")
	:AddDeferredUIElementField("hexText", "EditableText")
	:AddDeferredEnumField("rampKey", ThemeColorSets.ThemeBrandRampKey)
	:AddDeferredStringField("customThemeColorKey")
	:AddDeferredStringField("colorHexString")
	:AddBooleanField("editingHex", false)
	:Commit()
EditableThemeColor:_AddActionScripts("OnColorChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function EditableThemeColor:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_SET_THEME_COLOR")
end

function EditableThemeColor:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		local customThemeColorKeyPublisher = self._state:Publisher("customThemeColorKey")
			:IgnoreNil()
			:Share()
		self:AddChild(UIElements.New("Text", "label")
			:SetHeight(20)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(self._state:Publisher("rampKey"):IgnoreNil():Map(LABELS))
		)
		self:AddChild(UIElements.New("BaseFrame", "frame")
			:SetLayout("HORIZONTAL")
			:SetSize(200, 50)
			:SetMargin(0, 12, 0, 8)
			:SetRoundedBackgroundColor("container/lowest")
			:SetBorderColor("outline/main")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseFrame", "color")
				:SetWidth(50)
				:SetMouseEnabled(true)
				:SetRoundedBackgroundColor(customThemeColorKeyPublisher)
				:SetBorderColor("outline/main")
				-- Draw a line along the right to hide the rounded corners at the bottom of the header frame
				:AddChildNoLayout(UIElements.New("BaseTexture", "mask")
					:AddAnchor("TOPRIGHT", 0, -1)
					:AddAnchor("BOTTOMRIGHT", 0, 1)
					:SetWidth(8)
					:SetColor(customThemeColorKeyPublisher)
				)
				:SetScript("OnMouseUp", self._childManager:CallbackToProcessAction("ACTION_SHOW_COLOR_PICKER"))
			)
			:AddChild(UIElements.New("BaseTexture", "line")
				:SetWidth(1)
				:SetColor("outline/main")
			)
			:AddChild(UIElements.New("EditableText", "text")
				:SetMargin(8, 0, 8, 8)
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(self._state:Publisher("colorHexString"):CoalesceNil(""))
				:BindElement(self._state, "hexText")
				:BindEditing(self._state, "editingHex")
				:SetAction("OnValueChanged", "ACTION_HANDLE_HEX_VALUE_CHANGED")
				:SetAction("OnEditingChanged", "ACTION_HANDLE_EDITING_HEX_CHANGED")
			)
			:AddChild(UIElements.New("BaseButton", "edit")
				:SetMargin(8, 8, 0, 0)
				:SetBackgroundAndSize("iconPack.18x18/Edit")
				:SetShown(self._state:Publisher("editingHex"):InvertBoolean())
				:SetAction("OnClick", "ACTION_EDIT_HEX")
			)
		)
		self:AddCancellable(customThemeColorKeyPublisher:EndShare())
	end
end

---Configures the editable theme color element.
---@param rampKey ThemeBrandRampKey The theme color key
---@param customThemeColorKey string The key for the custom theme color
---@return self
function EditableThemeColor:Configure(rampKey, customThemeColorKey)
	assert(not self._state.customThemeColorKey and customThemeColorKey)
	self._state.rampKey = rampKey
	self._state.customThemeColorKey = customThemeColorKey
	self:AddCancellable(Theme.GetPublisher(customThemeColorKey)
		:Map("GetHexNoAlpha()")
		:Map(strupper)
		:AssignToTableKey(self._state, "colorHexString")
	)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<EditableThemeColorState>
---@param state EditableThemeColorState
function EditableThemeColor.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_COLOR_PICKER" then
		local r, g, b = Theme.GetColor(state.customThemeColorKey):GetFractionalRGBA()
		local baseFrame = self:GetBaseElement():_GetBaseFrame()
		ColorPicker.Show(r, g, b, baseFrame, manager:CallbackToProcessAction("ACTION_SET_THEME_COLOR"))
	elseif action == "ACTION_SET_THEME_COLOR" then
		local r, g, b = ...
		r = Math.Round(r * 255)
		g = Math.Round(g * 255)
		b = Math.Round(b * 255)
		state.hexText
			:SetText(strupper(format("#%02x%02x%02x", r, g, b)))
			:Draw()
		self:_SendActionScript("OnColorChanged", state.rampKey, r, g, b)
	elseif action == "ACTION_HANDLE_HEX_VALUE_CHANGED" then
		local newValue = ...
		local r, g, b = private.HexToRGB(strtrim(strlower(newValue)))
		if not r or not g or not b then
			state.hexText:Draw()
			return
		end
		return manager:ProcessAction("ACTION_SET_THEME_COLOR", r / 255, g / 255, b / 255)
	elseif action == "ACTION_HANDLE_EDITING_HEX_CHANGED" then
		self:Draw()
	elseif action == "ACTION_EDIT_HEX" then
		state.hexText
			:SetEditing(true)
			:HighlightAll()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HexToRGB(hexColor)
	local r, g, b = strmatch(hexColor, "^#([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$")
	if not r or not g or not b then
		return nil, nil, nil
	end
	return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

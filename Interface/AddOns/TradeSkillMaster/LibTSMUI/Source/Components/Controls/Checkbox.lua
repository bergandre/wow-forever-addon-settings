-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local THEME_TEXTURES = {
	RADIO_CHECKED = "iconPack.Misc/Radio/Checked",
	RADIO_UNCHECKED = "iconPack.Misc/Radio/Unchecked",
	CHECK_CHECKED = "iconPack.Misc/Checkbox/Checked",
	CHECK_UNCHECKED = "iconPack.Misc/Checkbox/Unchecked",
}
local CHECKBOX_SPACING = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local Checkbox = ComponentRegistry.Define("Checkbox", "Text")
Checkbox._STATE_SCHEMA = Checkbox._STATE_SCHEMA:Extend("CheckboxState")
	:UpdateFieldDefault("font", "BODY_SMALL")
	:AddStringField("theme", "CHECK", private.ValidateTheme)
	:AddBooleanField("checked", false)
	:AddBooleanField("disabled", false)
	:AddStringField("enabledColor", "on/surface", Theme.IsValidColor)
	:Commit()
Checkbox:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Checkbox:__init()
	local frame = self:_CreateButton()
	self._frame = frame
	self.__super:__init(frame)

	self._settingTable = nil
	self._settingKey = nil

	local disabledPublisher = self._state:Publisher("disabled")
		:Share()

	self._frame:TSMSetDisabled(disabledPublisher)
	self._frame:TSMSetScript("OnClick", self:__closure("_HandleClick"))

	-- Create the check texture
	self._check = self:_CreateTexture()
	self._check:TSMSetTextureAndSize(self._state:Publisher([[theme .. (checked and "_CHECKED" or "_UNCHECKED")]]):Map(THEME_TEXTURES))
	self._check:TSMSetAlpha(disabledPublisher:ReplaceBooleanWith(0.3, 1))

	-- Layout the text and check
	self._text:ClearAllPoints()
	self._check:ClearAllPoints()
	self._check:SetPoint("LEFT")
	self._text:SetJustifyH("LEFT")
	self._text:SetPoint("LEFT", self._check, "RIGHT", CHECKBOX_SPACING, 0)
	self._text:SetPoint("TOPRIGHT")
	self._text:SetPoint("BOTTOMRIGHT")

	disabledPublisher:EndShare()

	-- Computed color
	self._state:Publisher([[disabled and "on/surface%40" or enabledColor]])
		:AssignToTableKey(self._state, "color")
end

function Checkbox:Release()
	self._settingTable = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the color of the text when not disabled.
---@param color ThemeColorKey The text color as a theme color key
---@return self
function Checkbox:SetTextColor(color)
	self._state.enabledColor = color
	return self
end

---Sets the checkbox theme
---@param theme "RADIO"|"CHECK" The checkbox theme
---@return self
function Checkbox:SetTheme(theme)
	self._state.theme = theme
	return self
end

---Sets whether or not the checkbox is disabled.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the checkbox is disabled
---@return self
function Checkbox:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.disabled = value
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end

---Sets whether or not the checkbox is checked.
---@param value boolean Whether or not the checkbox is checked
---@param silent? boolean If true, will not trigger the `OnValueChanged` script
---@return self
function Checkbox:SetChecked(value, silent)
	self:SetCheckedSilent(value)
	if not silent then
		self:_SendActionScript("OnValueChanged")
	end
	return self
end

---Sets whether or not the checkbox is checked without calling the value changed handler.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the checkbox is checked or a publisher
---@return self
function Checkbox:SetCheckedSilent(value)
	if type(value) == "boolean" then
		self._state.checked = value
	else
		self:_MethodPublisher(value, "SetCheckedSilent")
	end
	return self
end

---Sets the setting info.
---
---This method is used to have the state of the checkbox automatically correspond with the boolean state of a field in
---a table. This is useful for checkboxes which are tied directly to settings.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the checkbox state
---@return self
function Checkbox:SetSettingInfo(tbl, key)
	self._settingTable = tbl
	self._settingKey = key
	self:SetChecked(tbl[key] and true or false)
	return self
end

---Gets the checked state.
---@return boolean
function Checkbox:IsChecked()
	return self._state.checked
end

---Mirrors the checked value with the specified state.
---@param state ReactiveState The state to mirror
---@param key string The state key to mirror
---@return self
function Checkbox:MirrorIsCheckedState(state, key)
	self:SetCheckedSilent(state:Publisher(key))
	self._state:Publisher("checked")
		:AssignToTableKey(state, key)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Checkbox.__private:_HandleClick()
	local value = not self._state.checked
	if self._settingTable and self._settingKey then
		self._settingTable[self._settingKey] = value
	end
	self:SetChecked(value)
end

function Checkbox:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth then
		local texture = THEME_TEXTURES[self._state.theme.."_CHECKED"]
		assert(texture)
		local checkboxWidth = TextureAtlas.GetWidth(texture)
		return self:GetStringWidth() + CHECKBOX_SPACING + checkboxWidth, nil
	else
		return self.__super:_GetMinimumDimension(dimension)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateTheme(theme)
	return THEME_TEXTURES[theme.."_CHECKED"] and true or false
end

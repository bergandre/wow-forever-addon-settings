-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local ICON_SPACING = 4
local BACKGROUND_VALID_POINTS_LOOKUP = {
	[false] = {
		{ "TOPLEFT" },
		{ "BOTTOMRIGHT" },
	},
	[true] = {
		{ "CENTER" },
	},
}
local ITEM_HIGHLIGHT_TEXTURE = 130718



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseButton = ComponentRegistry.Define("BaseButton", "Text")
BaseButton._STATE_SCHEMA = BaseButton._STATE_SCHEMA:Extend("BaseButtonState")
	:UpdateFieldDefault("justifyH", "CENTER")
	:UpdateFieldDefault("font", "BODY_BODY1")
	:AddOptionalStringField("background")
	:AddBooleanField("backgroundIsValid", false)
	:AddStringField("highlightColor", "TRANSPARENT", Theme.IsValidColor)
	:AddOptionalNumberField("highlightTexture")
	:AddBooleanField("enabled", true)
	:AddOptionalStringField("iconTexturePack", TextureAtlas.IsValid)
	:AddOptionalStringField("iconPosition", private.ValidateIconPosition)
	:AddBooleanField("locked", false)
	:Commit()
BaseButton:_AddActionScripts("OnClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BaseButton:__init(isSecure)
	local frame = self:_CreateButton(nil, nil, isSecure)
	self._frame = frame
	self.__super:__init(frame)

	local backgroundPublisher = self._state:Publisher("background")
		:Share()
	local colorPublisher = self._state:Publisher([[enabled and color or "on/surface%40"]])
		:Share()
	local iconTexturePackPublisher = self._state:Publisher("iconTexturePack")
		:Share()

	self._text:TSMSubscribeTextColor(colorPublisher)

	-- Create the highlight
	self._highlight = self:_CreateTexture(frame, "HIGHLIGHT")
	self._highlight:SetAllPoints()
	-- Only one of highlightColor / highlightTexture is in use at a time
	self._highlight:TSMSubscribeColorTexture(self._state:Publisher("highlightColor"))
	self._highlight:TSMSetTextureAndCoord(self._state:Publisher("highlightTexture"))
	self._frame:SetHighlightTexture(self._highlight)

	self._backgroundTexture = self:_CreateTexture(frame, "BACKGROUND")
	self._backgroundTexture:TSMSetPoints(self._state:Publisher("backgroundIsValid"):Map(BACKGROUND_VALID_POINTS_LOOKUP))
	self._backgroundTexture:TSMSetSize(self._state:Publisher([[backgroundIsValid and background or nil]]):IgnoreNil())
	self._backgroundTexture:TSMSetTextureAndCoord(backgroundPublisher:IgnoreNil():Map(private.BackgroundToTexture))
	self._backgroundTexture:TSMSubscribeVertexColor(backgroundPublisher:IgnoreNil():Map(private.BackgroundToColor))
	self._backgroundTexture:TSMSetShown(backgroundPublisher:ToBooleanNotEquals(nil))

	-- Create the icon
	self._icon = self:_CreateTexture(frame, "ARTWORK")
	self._icon:TSMSubscribeVertexColor(colorPublisher)
	self._icon:TSMSetTextureAndSize(iconTexturePackPublisher:IgnoreNil())
	self._icon:TSMSetShown(iconTexturePackPublisher:ToBooleanNotEquals(nil):IgnoreDuplicates())

	self._frame:TSMSetScript(isSecure and "PostClick" or "OnClick", self:__closure("_HandleClick"))
	self._frame:TSMSetDisabled(self._state:Publisher("enabled"):InvertBoolean())
	self._frame:TSMSetHighlightLocked(self._state:Publisher("locked"))

	-- Computed backgroundIsValid field
	backgroundPublisher
		:MapNonNil(TextureAtlas.IsValid)
		:CoalesceNil(false)
		:IgnoreDuplicates()
		:AssignToTableKey(self._state, "backgroundIsValid")

	-- Redraw to update text and icon layout when needed
	self._state:PublisherForKeys("iconTexturePack", "iconPosition", "justifyH", "textStr")
		:ReplaceWith(nil)
		:CallMethod(self, "Draw")

	backgroundPublisher:EndShare()
	colorPublisher:EndShare()
	iconTexturePackPublisher:EndShare()
end

function BaseButton:Acquire()
	self._frame:RegisterForClicks("LeftButtonUp")
	self._frame:SetHitRectInsets(0, 0, 0, 0)
	self.__super:Acquire()
end

---Sets the background of the button.
---@param value? string|ThemeColorKey|number|ReactivePublisherSchemaBase<string|ThemeColorKey|number> Either a texture pack string, itemString, WoW file id, theme color key, nil or a publisher
---@param highlightEnabled? boolean Whether or not the highlight is enabled
---@return self
function BaseButton:SetBackground(value, highlightEnabled)
	if value == nil or type(value) == "string" or type(value) == "number" then
		assert(highlightEnabled == nil or type(highlightEnabled) == "boolean")
		if not highlightEnabled then
			self._state.highlightColor = "TRANSPARENT"
		end
		self._state.background = value and tostring(value) or nil
		self._state.highlightTexture = nil
		if highlightEnabled then
			assert(value)
			self._state.highlightColor = value.."+HOVER"
		end
	else
		assert(highlightEnabled == nil)
		self:_MethodPublisher(value, "SetBackground")
	end
	return self
end

---Sets the background of the button with highlight enabled.
---@param value? string|ThemeColorKey|number|ReactivePublisherSchemaBase<string|ThemeColorKey|number> Either a texture pack string, itemString, WoW file id, theme color key, nil, or a publisher
---@return self
function BaseButton:SetBackgroundWithHighlight(value)
	if value == nil or type(value) == "string" or type(value) == "number" then
		self:SetBackground(value, value ~= nil)
	else
		self:_MethodPublisher(value, "SetBackgroundWithHighlight")
	end
	return self
end

---Sets the background of the button and enables a WoW-style item highlight.
---@param background? number|string A WoW file id, itemString, or nil
---@return self
function BaseButton:SetBackgroundWithItemHighlight(background)
	assert(background == nil or type(background) == "number" or type(background) == "string")
	self._state.background = background and tostring(background) or nil
	self._state.highlightTexture = background and ITEM_HIGHLIGHT_TEXTURE or nil
	return self
end

---Sets the background and size of the button based on a texture pack string.
---@param value string|ReactivePublisherSchemaBase<string> A texture pack string to set the background to and base the size on or a publisher
---@return self
function BaseButton:SetBackgroundAndSize(value)
	if type(value) == "string" then
		self:SetBackground(value)
		self:SetSize(TextureAtlas.GetSize(value))
	else
		self:_MethodPublisher(value, "SetBackgroundAndSize")
	end
	return self
end

---Sets the icon that shows within the button.
---@param texturePack? string A texture pack string to set the icon and its size to
---@param position? string The position of the icon
---@return self
function BaseButton:SetIcon(texturePack, position)
	assert((texturePack and position) or (not texturePack and not position))
	if texturePack then
		self._state.iconPosition = position
		self._state.iconTexturePack = texturePack
	else
		self._state.iconTexturePack = nil
		self._state.iconPosition = nil
	end
	return self
end

---Set whether or not the button is disabled.
---@param value boolean|ReactivePublisherSchemaBase<boolean> Whether or not the button should be disabled or a publisher
---@return self
function BaseButton:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.enabled = not value
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end

---Registers the button for drag events.
---@param button? MouseButton The mouse button to register for drag events from
---@return self
function BaseButton:RegisterForDrag(button)
	if button then
		self._frame:RegisterForDrag(button)
	else
		self._frame:RegisterForDrag()
	end
	return self
end

---Click on the button.
function BaseButton:Click()
	self._frame:Click()
end

---Enable right-click events for the button.
---@return self
function BaseButton:EnableRightClick()
	self._frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return self
end

---Set the hit rectangle insets for the button.
---@param left number How much the left side of the hit rectangle is inset
---@param right number How much the right side of the hit rectangle is inset
---@param top number How much the top side of the hit rectangle is inset
---@param bottom number How much the bottom side of the hit rectangle is inset
---@return self
function BaseButton:SetHitRectInsets(left, right, top, bottom)
	self._frame:SetHitRectInsets(left, right, top, bottom)
	return self
end

---Set whether or not to lock the button's highlight.
---@param value boolean|ReactivePublisherSchemaBase<boolean> Whether or not to lock the button's highlight or a publisher
---@return self
function BaseButton:SetHighlightLocked(value)
	if type(value) == "boolean" then
		self._state.locked = value
	else
		self:_MethodPublisher(value, "SetHighlightLocked")
	end
	return self
end

function BaseButton:Draw()
	self._text:Show()
	self.__super:Draw()

	-- Layout the text and icon
	if self._state.iconTexturePack then
		self._icon:ClearAllPoints()
		local iconWidth = TextureAtlas.GetWidth(self._state.iconTexturePack) + ICON_SPACING
		if self._state.iconPosition == "LEFT" then
			self._icon:SetPoint("RIGHT", self._text, "LEFT", -ICON_SPACING, 0)
			self._text:ClearAllPoints()
			if self._state.justifyH == "CENTER" then
				local xOffset = iconWidth / 2
				self._text:SetPoint("TOP", xOffset, -self:_GetPadding("TOP"))
				self._text:SetPoint("BOTTOM", xOffset, self:_GetPadding("BOTTOM"))
				self._text:SetWidth(self:GetStringWidth())
			elseif self._state.justifyH == "LEFT" then
				self._text:SetPoint("TOPLEFT", iconWidth + self:_GetPadding("LEFT"), -self:_GetPadding("TOP"))
				self._text:SetPoint("BOTTOMRIGHT", -self:_GetPadding("RIGHT"), self:_GetPadding("BOTTOM"))
			else
				error("Unsupported justifyH: "..tostring(self._state.justifyH))
			end
		elseif self._state.iconPosition == "LEFT_NO_TEXT" then
			self._icon:SetPoint("LEFT", self:_GetPadding("LEFT"), 0)
			self._text:ClearAllPoints()
			self._text:Hide()
		elseif self._state.iconPosition == "CENTER" then
			self._icon:SetPoint("CENTER")
			self._text:ClearAllPoints()
			self._text:Hide()
		elseif self._state.iconPosition == "RIGHT" then
			self._icon:SetPoint("RIGHT", -self:_GetPadding("RIGHT"), 0)
			local xOffset = iconWidth
			self._text:ClearAllPoints()
			-- TODO: support non-left-aligned text
			self._text:SetPoint("TOPLEFT", self:_GetPadding("LEFT"), -self:_GetPadding("TOP"))
			self._text:SetPoint("BOTTOMRIGHT", -xOffset, self:_GetPadding("BOTTOM"))
		else
			error("Invalid iconPosition: "..tostring(self._state.iconPosition))
		end
	else
		self._text:ClearAllPoints()
		self._text:SetPoint("TOPLEFT", self:_GetPadding("LEFT"), -self:_GetPadding("TOP"))
		self._text:SetPoint("BOTTOMRIGHT", -self:_GetPadding("RIGHT"), self:_GetPadding("BOTTOM"))
	end
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function BaseButton:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth then
		return self:GetStringWidth() + (self._state.iconTexturePack and TextureAtlas.GetWidth(self._state.iconTexturePack) or 0)
	else
		return self.__super:_GetMinimumDimension(dimension)
	end
end

function BaseButton.__protected:_HandleClick(_, mouseButton)
	self:_SendActionScript("OnClick", mouseButton)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateIconPosition(position)
	return position == "LEFT" or position == "LEFT_NO_TEXT" or position == "CENTER" or position == "RIGHT"
end

function private.BackgroundToTexture(background)
	if TextureAtlas.IsValid(background) then
		return background
	elseif strmatch(background, "^[ip]:%d+") then
		return ItemInfo.GetTexture(background)
	elseif tonumber(background) then
		-- This is a wow file id
		return tonumber(background)
	else
		-- We'll use the vertex color to color a white texture
		return "Interface\\Buttons\\WHITE8X8"
	end
end

function private.BackgroundToColor(background)
	local isTextureKey = TextureAtlas.IsValid(background)
	local textureColorKey = isTextureKey and TextureAtlas.GetColorKey(background)
	if textureColorKey then
		return textureColorKey
	elseif isTextureKey or strmatch(background, "^[ip]:%d+") or tonumber(background) then
		return "FULL_WHITE"
	else
		return background
	end
end

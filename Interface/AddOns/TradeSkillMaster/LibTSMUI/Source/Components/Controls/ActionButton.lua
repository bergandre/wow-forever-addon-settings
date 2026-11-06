-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Event = LibTSMUI:From("LibTSMWoW"):Include("Service.Event")
local private = {}
local CLICK_COOLDOWN = 0.2
local CORNER_RADIUS = 4
local STYLE_INFO = { ---@type table<ActionButton.Style,ActionButton.StateStyleInfo>
	PRIMARY = {
		ACTIVE = {
			backgroundColor = "primary/variant",
			textColor = "on/primary/variant",
		},
		HOVER = {
			backgroundColor = "primary/variant+HOVER",
			textColor = "on/primary/variant",
		},
		PRESSED = {
			backgroundColor = "primary/main",
			textColor = "on/primary",
		},
		DISABLED = {
			backgroundColor = "primary/variant%40",
			textColor = "on/primary/variant%40",
		},
	},
	SECONDARY = {
		ACTIVE = {
			backgroundColor = "surface/main",
			borderColor = "outline/variant",
			textColor = "on/surface",
		},
		HOVER = {
			backgroundColor = "surface/main",
			borderColor = "outline/main",
			textColor = "on/surface",
		},
		PRESSED = {
			backgroundColor = "container/high",
			borderColor = "outline/main",
			textColor = "on/surface",
		},
		DISABLED = {
			backgroundColor = "surface/main",
			borderColor = "outline/variant",
			textColor = "on/surface%40",
		},
	},
	TERTIARY = {
		ACTIVE = {
			backgroundColor = "TRANSPARENT",
			textColor = "accent/main",
		},
		HOVER = {
			backgroundColor = "container/low+HOVER",
			textColor = "accent/main",
		},
		PRESSED = {
			backgroundColor = "container/high",
			textColor = "accent/main",
		},
		DISABLED = {
			backgroundColor = "TRANSPARENT",
			textColor = "accent/main%40",
		},
	},
}
local SIZE_INFO = { ---@type table<ActionButton.Size,ActionButton.SizeInfo>
	MEDIUM = {
		font = "BODY_BODY1_MEDIUM",
		height = 28,
	},
	SMALL = {
		font = "BODY_SMALL_MEDIUM",
		height = 24,
	},
}
local COMPUTED_STYLE_INFO = {} ---@type table<ActionButton.Style,table<ActionButton.State,ActionButton.ComputedStyleInfo>>
do
	for style, states in pairs(STYLE_INFO) do
		COMPUTED_STYLE_INFO[style] = {}
		for state, info in pairs(states) do
			COMPUTED_STYLE_INFO[style][state] = {
				textColor = info.textColor,
				backgroundColor = info.borderColor or info.backgroundColor,
				borderOverlayShown = info.borderColor ~= nil,
				borderOverlayColor = info.backgroundColor,
			}
		end
	end
end

---@alias ActionButton.StateStyleInfo table<ActionButton.State,ActionButton.StyleInfo>

---@alias ActionButton.Style
---|'"PRIMARY"'
---|'"SECONDARY"'
---|'"TERTIARY"'

---@alias ActionButton.State
---|'"ACTIVE"'
---|'"HOVER"'
---|'"PRESSED"'
---|'"DISABLED"'

---@alias ActionButton.Size
---|'"MEDIUM"'
---|'"SMALL"'

---@class ActionButton.StyleInfo
---@field backgroundColor ThemeColorKey|string
---@field borderColor (ThemeColorKey|string)?
---@field textColor ThemeColorKey|string

---@class ActionButton.ComputedStyleInfo
---@field textColor ThemeColorKey|string
---@field backgroundColor ThemeColorKey|string
---@field borderOverlayShown boolean
---@field borderOverlayColor (ThemeColorKey|string)?

---@class ActionButton.SizeInfo
---@field font string
---@field height number



-- ============================================================================
-- Element Definition
-- ============================================================================

local ActionButton = ComponentRegistry.Define("ActionButton", "Text", "ABSTRACT")
ActionButton._STATE_SCHEMA = ActionButton._STATE_SCHEMA:Extend("ActionButtonState")
	:UpdateFieldDefault("justifyH", "CENTER")
	:AddStringField("defaultTextStr", "")
	:AddOptionalStringField("modifierTextStr")
	:AddOptionalStringField("pressedModifier")
	:AddBooleanField("disabled", false)
	:AddBooleanField("locked", false)
	:AddBooleanField("clickCooldownActive", false)
	:AddBooleanField("mouseOver", false)
	:Commit()
ActionButton:_AddActionScripts("OnMouseDown", "OnMouseUp", "OnClick", "OnEnter", "OnLeave")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---@param style ActionButton.Style
---@param size ActionButton.Size
function ActionButton:__init(name, isSecure, style, size)
	local frame = self:_CreateButton(nil, name, isSecure)
	self._frame = frame
	self.__super:__init(frame, true, true)
	self._style = style
	self._size = size
	self._frame:TSMSetScript(isSecure and "PostClick" or "OnClick", self:__closure("_HandleClick"))
	self._frame:TSMSetScript("OnMouseDown", self:__closure("_HandleMouseDown"))
	self._frame:TSMSetScript("OnMouseUp", self:__closure("_HandleMouseUp"))
	self._frame:TSMHookScript("OnEnter", self:__closure("_HandleFrameEnter"))
	self._frame:TSMHookScript("OnLeave", self:__closure("_HandleFrameLeave"))
	self._frame:TSMSetDisabled(self._state:Publisher([[(disabled or pressedModifier or clickCooldownActive) and true or false]]))
	self._frame:TSMSetHighlightLocked(self._state:Publisher("locked"))
	self._frame:TSMSetOnUpdate(self._state:Publisher("clickCooldownActive")
		:ReplaceBooleanWith(self:__closure("_HandleFrameUpdate"), nil)
	)

	local styleInfoPublisher = self._state:Publisher([[((pressedModifier or clickCooldownActive) and "PRESSED") or (disabled and "DISABLED") or (locked and "HOVER") or (mouseOver and "HOVER") or "ACTIVE"]])
		:Map(COMPUTED_STYLE_INFO[style])
		:Share()

	self._background = self:_CreateRectangle()
	self._background:SetCornerRadius(CORNER_RADIUS)
	self._background:SubscribeColor(styleInfoPublisher:Map("backgroundColor"):IgnoreDuplicates())

	self._borderOverlay = self:_CreateRectangle(1)
	self._borderOverlay:SetCornerRadius(CORNER_RADIUS)
	self._borderOverlay:SetInset(1)
	self._borderOverlay:SetShown(styleInfoPublisher:Map("borderOverlayShown"):IgnoreDuplicates())
	self._borderOverlay:SubscribeColor(styleInfoPublisher:Map("borderOverlayColor"):IgnoreDuplicates())

	-- Need to set an initial font here since there's no publisher that's setting it
	self._text:TSMSetFont("BODY_SMALL_MEDIUM")
	self._text:TSMSubscribeTextColor(styleInfoPublisher:Map("textColor"):IgnoreDuplicates())

	styleInfoPublisher:EndShare()

	self._clickCooldown = nil
	self._clickCooldownDisabled = false
	self._modifierText = {}
	self._isMouseDown = false
	self._manualRequired = false

	-- Handle modifier updates and update the displayed text string
	self._state:Publisher("pressedModifier")
		:CallMethod(self, "_UpdateModifierText")
	self._state:Publisher([[modifierTextStr or defaultTextStr]])
		:AssignToTableKey(self._state, "textStr")
end

function ActionButton:Acquire()
	self.__super:Acquire()
	-- Set the font and height
	self._text:TSMSetFont(SIZE_INFO[self._size].font)
	self:SetHeight(SIZE_INFO[self._size].height)
end

function ActionButton:Release()
	wipe(self._modifierText)
	self._manualRequired = false
	self._isMouseDown = false
	self._clickCooldown = nil
	self._clickCooldownDisabled = false
	self._frame:Enable()
	self._frame:RegisterForClicks("LeftButtonUp")
	self._frame:UnlockHighlight()
	self.__super:Release()
end

---Set the text.
---@param value string|number|ReactivePublisherSchemaBase<string|number> The text or a publisher
---@return self
function ActionButton:SetText(value)
	self.__super:SetText(value)
	self._state.defaultTextStr = self:GetText()
	return self
end

---Sets a script to propagate to the parent element.
---@param script string The script to propagate
---@return self
function ActionButton:PropagateScript(script)
	if script == "OnMouseDown" or script == "OnMouseUp" then
		self.__super:PropagateScript(script)
	else
		error("Cannot propagate ActionButton script: "..tostring(script))
	end
	return self
end

---Set whether or not the action button is disabled.
---@param value boolean|ReactivePublisherSchemaBase<boolean> Whether or not the action button should be disabled or a publisher
---@return self
function ActionButton:SetDisabled(value)
	if type(value) == "boolean" then
		self._state.disabled = value
	else
		self:_MethodPublisher(value, "SetDisabled")
	end
	return self
end

---Set whether or not the highlight is locked.
---@param value boolean|ReactivePublisherSchemaBase<boolean> Whether or not to lock the action button's highlight
---@return self
function ActionButton:SetHighlightLocked(value)
	if type(value) == "boolean" then
		self._state.locked = value
	else
		self:_MethodPublisher(value, "SetHighlightLocked")
	end
	return self
end

---Set whether or not the action button is pressed.
---@param value boolean|ReactivePublisherSchemaBase<boolean> Whether or not the action button should be pressed or a publisher
---@return self
function ActionButton:SetPressed(value)
	if type(value) == "boolean" then
		self._state.pressedModifier = value and private.GetModifierKey(IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown()) or nil
		if self._clickCooldown then
			self._clickCooldown = nil
			self._state.clickCooldownActive = false
		end
	else
		self:_MethodPublisher(value, "SetPressed")
	end
	return self
end

---Disables the default click cooldown to allow the button to be spammed (i.e. for macro-able buttons).
---@return self
function ActionButton:DisableClickCooldown()
	self._clickCooldownDisabled = true
	if self._clickCooldown then
		self._clickCooldown = nil
		self._state.clickCooldownActive = false
	end
	return self
end

---Change the text based on the modifier state.
---@param value string|ReactivePublisherSchemaBase<string> The text to set or a publisher
---@param ... string The modifiers to set the text for (when they are all pressed together)
---@return self
function ActionButton:SetModifierText(value, ...)
	local key = private.GetModifierKey(private.ParseModifierKey(strjoin("-", ...)))
	assert(key ~= "NONE")
	if type(value) == "string" then
		self:_SetModifierText(value, key)
	else
		self:_FunctionPublisher(value, self:__closure("_SetModifierText"), key)
	end
	return self
end

---Set whether a manual click (vs. a macro) is required.
---@param value boolean|ReactivePublisherSchemaBase<boolean> Whether or not a manual click is required or a publisher
---@return self
function ActionButton:SetRequireManualClick(value)
	if type(value) == "boolean" then
		self._manualRequired = value
	else
		self:_MethodPublisher(value, "SetRequireManualClick")
	end
	return self
end

---Click on the action button.
function ActionButton:Click()
	if self._frame:IsEnabled() and self._frame:IsVisible() then
		self:_HandleClick()
	end
end

---@deprecated
function ActionButton:SetFont()
	error("ActionButton does not support this method", 2)
end

---@deprecated
function ActionButton:SetTextColor()
	error("ActionButton does not support this method", 2)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ActionButton.__private:_HandleModifierStateChanged()
	self:_UpdateModifierText(self._state.pressedModifier)
end

function ActionButton:_UpdateModifierText(pressedModifier)
	if not next(self._modifierText) then
		self._state.modifierTextStr = nil
		return
	end
	-- Find the key with the highest number of modifiers which is currently satisfied
	local maxRank, maxRankKey = nil, nil
	local currentShift, currentControl, currentAlt = nil, nil, nil
	if pressedModifier then
		currentShift, currentControl, currentAlt = private.ParseModifierKey(pressedModifier)
	else
		currentShift = IsShiftKeyDown()
		currentControl = IsControlKeyDown()
		currentAlt = IsAltKeyDown()
	end
	for key in pairs(self._modifierText) do
		-- Check if this modifier key is currently satisfied
		local hasShift, hasControl, hasAlt = private.ParseModifierKey(key)
		if (not hasShift or currentShift) and (not hasControl or currentControl) and (not hasAlt or currentAlt) then
			local rank = select("#", strsplit("-", key))
			if rank > (maxRank or 0) then
				maxRank = rank
				maxRankKey = key
			else
				assert(rank ~= maxRank)
			end
		end
	end
	self._state.modifierTextStr = maxRankKey and self._modifierText[maxRankKey] or nil
end

function ActionButton.__private:_HandleClick()
	if not self._state.acquired then
		return
	elseif self._manualRequired and not self._isMouseDown then
		return
	end
	self._isMouseDown = false
	if not self._clickCooldownDisabled then
		self._clickCooldown = CLICK_COOLDOWN
	end
	self:_SendActionScript("OnClick")
	if self._clickCooldown then
		self._state.clickCooldownActive = true
	end
end

function ActionButton.__private:_HandleMouseDown()
	self._isMouseDown = true
	self:_SendActionScript("OnMouseDown")
end

function ActionButton.__private:_HandleMouseUp()
	self:_SendActionScript("OnMouseUp")
end

function ActionButton.__private:_HandleFrameEnter()
	self._state.mouseOver = true
	self:_SendActionScript("OnEnter")
end

function ActionButton.__private:_HandleFrameLeave()
	self._state.mouseOver = false
	if not self:IsVisible() then
		return
	end
	self:_SendActionScript("OnLeave")
end

function ActionButton.__private:_HandleFrameUpdate(frame, elapsed)
	self._clickCooldown = self._clickCooldown - elapsed
	if self._clickCooldown <= 0 then
		self._clickCooldown = nil
		self._state.clickCooldownActive = false
	end
end

function ActionButton.__private:_SetModifierText(text, key)
	if not next(self._modifierText) then
		self:AddCancellable(Event.GetPublisher("MODIFIER_STATE_CHANGED")
			:CallFunction(self:__closure("_HandleModifierStateChanged"))
		)
	end
	self._modifierText[key] = text
end



-- ============================================================================
-- Specific Style Classes
-- ============================================================================

local MediumPrimaryActionButton = ComponentRegistry.Define("MediumPrimaryActionButton", "ActionButton")
function MediumPrimaryActionButton:__init(name, isSecure)
	self.__super:__init(name, isSecure, "PRIMARY", "MEDIUM")
end

local SmallPrimaryActionButton = ComponentRegistry.Define("SmallPrimaryActionButton", "ActionButton")
function SmallPrimaryActionButton:__init(name, isSecure)
	self.__super:__init(name, isSecure, "PRIMARY", "SMALL")
end

local MediumSecondaryActionButton = ComponentRegistry.Define("MediumSecondaryActionButton", "ActionButton")
function MediumSecondaryActionButton:__init(name, isSecure)
	self.__super:__init(name, isSecure, "SECONDARY", "MEDIUM")
end

local SmallSecondaryActionButton = ComponentRegistry.Define("SmallSecondaryActionButton", "ActionButton")
function SmallSecondaryActionButton:__init(name, isSecure)
	self.__super:__init(name, isSecure, "SECONDARY", "SMALL")
end

local MediumTertiaryActionButton = ComponentRegistry.Define("MediumTertiaryActionButton", "ActionButton")
function MediumTertiaryActionButton:__init(name, isSecure)
	self.__super:__init(name, isSecure, "TERTIARY", "MEDIUM")
end

local SmallTertiaryActionButton = ComponentRegistry.Define("SmallTertiaryActionButton", "ActionButton")
function SmallTertiaryActionButton:__init(name, isSecure)
	self.__super:__init(name, isSecure, "TERTIARY", "SMALL")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetModifierKey(hasShift, hasControl, hasAlt)
	if hasShift and hasControl and hasAlt then
		return "SHIFT-CTRL-ALT"
	elseif hasShift and hasControl then
		return "SHIFT-CTRL"
	elseif hasShift and hasAlt then
		return "SHIFT-ALT"
	elseif hasShift then
		return "SHIFT"
	elseif hasControl and hasAlt then
		return "CTRL-ALT"
	elseif hasControl then
		return "CTRL"
	elseif hasAlt then
		return "ALT"
	else
		return "NONE"
	end
end

function private.ParseModifierKey(key)
	local hasShift, hasControl, hasAlt, hasNone = false, false, false, false
	for modifier in String.SplitIterator(key, "-") do
		if modifier == "SHIFT" then
			assert(not hasShift and not hasNone)
			hasShift = true
		elseif modifier == "CTRL" then
			assert(not hasControl and not hasNone)
			hasControl = true
		elseif modifier == "ALT" then
			assert(not hasAlt and not hasNone)
			hasAlt = true
		elseif modifier == "NONE" then
			assert(not hasShift and not hasControl and not hasAlt and not hasNone)
			hasNone = true
		else
			error("Invalid modifier: "..tostring(modifier))
		end
	end
	return hasShift, hasControl, hasAlt
end

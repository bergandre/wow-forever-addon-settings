-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Widgets = LibTSMUI:InitInternal("Util.Widgets")
local WidgetsDebug = LibTSMUI:Include("Util.WidgetsDebug")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local ScriptWrapper = LibTSMUI:From("LibTSMWoW"):Include("API.ScriptWrapper")
local private = {
	debugObject = {},
	colorTemp1 = CreateColor(0, 0, 0, 1),
	colorTemp2 = CreateColor(0, 0, 0, 1),
}
local FRAME_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8" }

---@alias ScrollFrameExtended ScrollFrame|BaseExtension



-- ============================================================================
-- BaseExtension Methods
-- ============================================================================

---@class BaseExtension: Region
---@field protected __debug table<string,any>!
---@field protected __super any
local BaseExtension = {}

---Sets whether or not the widget is shown.
---@param value boolean|ReactivePublisherSchemaBase The shown value or a publisher
function BaseExtension:TSMSetShown(value)
	if type(value) == "boolean" then
		self:SetShown(value)
	else
		value:CallMethod(self, "TSMSetShown")
	end
end

---Sets the size of the widget.
---@param width number
---@param height number
function BaseExtension:TSMSetSize(width, height)
	self:SetWidth(width)
	self:SetHeight(height)
end

---Sets the points of the widget.
---@param value table|ReactivePublisherSchemaBase A list of points that each unpack into `:SetPoint(...)` arguments or a publisher
function BaseExtension:TSMSetPoints(value)
	if not value.__class then
		self:ClearAllPoints()
		for _, point in ipairs(value) do
			self:SetPoint(unpack(point))
		end
	else
		value:CallMethod(self, "TSMSetPoints")
	end
end

---Sets a script handler.
---@param script string The script name
---@param handler? fun(input: BaseExtension, ...) The script handler (or nil to clear the script)
---@param obj? any The object to pass as the first parameter of the script handler instead of the widget
function BaseExtension:TSMSetScript(script, handler, obj)
	if type(handler) == "function" then
		ScriptWrapper.Set(self, script, handler, obj, private.debugObject[self])
	elseif handler == nil then
		ScriptWrapper.Clear(self, script)
	else
		error("Invalid handler: "..tostring(handler))
	end
end

---Hooks a script with a handler which is called before the one set via `TSMSetScript()` and isn't removed by it.
---@param script string The script name
---@param handler fun(input: BaseExtension, ...) The script handler
---@param obj? any The object to pass as the first parameter of the script handler instead of the widget
function BaseExtension:TSMHookScript(script, handler, obj)
	ScriptWrapper.Hook(self, script, handler, obj, private.debugObject[self])
end

---Sets the script handler to simply propagate the script to the parent.
---@param script string The script which should be propagated
---@param obj? table The object to pass to the handler as the first parameter (instead of frame)
function BaseExtension:TSMSetPropagate(script, obj)
	ScriptWrapper.SetPropagate(self, script, obj)
end

---Sets the OnUpdate handler.
---@param value? fun(input: BaseExtension, ...)|ReactivePublisherSchemaBase The OnUpdate script handler (or nil to clear the script) or a publisher
---@param obj? any The object to pass as the first parameter of the script handler instead of the widget
function BaseExtension:TSMSetOnUpdate(value, obj)
	if value == nil or type(value) == "function" then
		self:TSMSetScript("OnUpdate", value, obj)
	else
		value:CallMethod(self, "TSMSetOnUpdate")
	end
end

---Sets the object used for debugging purposes to represent this widget.
---@param obj table The object which is converted to a string for debugging purposes
function BaseExtension:TSMSetDebugObject(obj)
	private.debugObject[self] = obj
end

---Sets a debug value.
---@param key string The key
---@param value any The value
---@protected
function BaseExtension:_TSMSetDebugValue(key, value)
	if not LibTSMUI.IsDevVersion() and not LibTSMUI.IsTestVersion() then
		return
	end
	self.__debug[key] = value
end



-- ============================================================================
-- FrameExtended Methods
-- ============================================================================

---@class FrameExtended: BaseExtension, Frame
local FrameExtended = { __super = BaseExtension }

---Sets the backdrop color.
---@param value ThemeColorKey|Color The color key or color object
function FrameExtended:TSMSetBackdropColor(value)
	self:_TSMSetDebugValue("backdropColor", value)
	if type(value) == "string" then
		value = Theme.GetColor(value)
	end
	self:SetBackdrop(FRAME_BACKDROP) ---@diagnostic disable-line: undefined-field
	self:SetBackdropColor(value:GetFractionalRGBA()) ---@diagnostic disable-line: undefined-field
end

---Subscribes the backdrop color.
---@param publisher ReactivePublisherSchemaBase A publisher for the backdrop color
function FrameExtended:TSMSubscribeBackdropColor(publisher)
	publisher:FlatMapCallMethod(Theme.GetPublisher, self, "TSMSetBackdropColor")
end

---Sets the frame strata
---@param value FrameStrata|ReactivePublisherSchemaBase The strata or a publisher
function FrameExtended:TSMSetFrameStrata(value)
	if type(value) == "string" then
		self:SetFrameStrata(value)
	else
		value:CallMethod(self, "TSMSetFrameStrata")
	end
end



-- ============================================================================
-- ButtonExtended Methods
-- ============================================================================

---@class ButtonExtended: BaseExtension, Button
local ButtonExtended = { __super = BaseExtension }

---Sets whether or not the button is disabled.
---@param value boolean|ReactivePublisherSchemaBase The disabled value or a publisher
function ButtonExtended:TSMSetDisabled(value)
	if type(value) == "boolean" then
		self:_TSMSetDebugValue("disabled", value)
		if value then
			self:Disable()
		else
			self:Enable()
		end
	else
		value:CallMethod(self, "TSMSetDisabled")
	end
end

---Sets whether or not the highlight is locked.
---@param value boolean|ReactivePublisherSchemaBase The locked value or a publisher
function ButtonExtended:TSMSetHighlightLocked(value)
	if type(value) == "boolean" then
		self:_TSMSetDebugValue("highlightLocked", value)
		if value then
			self:LockHighlight()
		else
			self:UnlockHighlight()
		end
	else
		value:CallMethod(self, "TSMSetHighlightLocked")
	end
end



-- ============================================================================
-- TextureExtended Methods
-- ============================================================================

---@class TextureExtended: BaseExtension, Texture
local TextureExtended = { __super = BaseExtension }

---Sets the color texture.
---@param color Color|ThemeColorKey The color key
function TextureExtended:TSMSetColorTexture(color)
	self:_TSMSetDebugValue("colorTexture", color)
	if type(color) == "string" then
		color = Theme.GetColor(color)
	end
	self:SetColorTexture(color:GetFractionalRGBA())
end

---Subscribes the color texture.
---@param publisher ReactivePublisherSchemaBase A publisher for the color texture
function TextureExtended:TSMSubscribeColorTexture(publisher)
	publisher:FlatMapCallMethod(Theme.GetPublisher, self, "TSMSetColorTexture")
end

---Sets the vertex color.
---@param color Color|ThemeColorKey The color key
function TextureExtended:TSMSetVertexColor(color)
	self:_TSMSetDebugValue("vertexColor", color)
	if type(color) == "string" then
		color = Theme.GetColor(color)
	end
	self:SetVertexColor(color:GetFractionalRGBA())
end

---Subscribes the vertex color.
---@param publisher ReactivePublisherSchemaBase A publisher for the vertex texture
function TextureExtended:TSMSubscribeVertexColor(publisher)
	publisher:FlatMapCallMethod(Theme.GetPublisher, self, "TSMSetVertexColor")
end

---Sets the texture based on a texture atlas key.
---@param value string|ReactivePublisherSchemaBase The texture atlas key or a publisher
function TextureExtended:TSMSetTexture(value)
	if type(value) == "string" then
		self:_TSMSetDebugValue("texture", value)
		TextureAtlas.SetTexture(self, value)
	else
		value:CallMethod(self, "TSMSetTexture")
	end
end

---Sets the texture and size based on a texture atlas key.
---@param value string|ReactivePublisherSchemaBase The texture atlas key or a publisher
function TextureExtended:TSMSetTextureAndSize(value)
	if type(value) == "string" then
		self:_TSMSetDebugValue("texture", value)
		TextureAtlas.SetTextureAndSize(self, value)
	else
		value:CallMethod(self, "TSMSetTextureAndSize")
	end
end

---Sets the texture and coord based on a texture atlas key or texture path.
---@param value string|number|nil|ReactivePublisherSchemaBase The texture atlas key, texture path, texture ID or a publisher
function TextureExtended:TSMSetTextureAndCoord(value)
	if type(value) == "string" or type(value) == "number" or value == nil then
		self:_TSMSetDebugValue("texture", value)
		if type(value) == "string" and TextureAtlas.IsValid(value) then
			TextureAtlas.SetTexture(self, value)
		else
			self:SetTexture(value)
			self:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
		end
	else
		value:CallMethod(self, "TSMSetTextureAndCoord")
	end
end

---Sets a vertical gradient.
---@param color Color The color
---@param minAlpha number The min color alpha
---@param maxAlpha number The max color alpha
function TextureExtended:TSMSetVerticalGradient(color, minAlpha, maxAlpha)
	local minR, minG, minB = color:GetFractionalRGBA()
	private.colorTemp1:SetRGBA(minR, minG, minB, minAlpha)
	local maxR, maxG, maxB = color:GetFractionalRGBA()
	private.colorTemp2:SetRGBA(maxR, maxG, maxB, maxAlpha)
	self:SetGradient("VERTICAL", private.colorTemp1, private.colorTemp2)
end

---Sets the alpha.
---@param value number|ReactivePublisherSchemaBase The alpha or a publisher
function TextureExtended:TSMSetAlpha(value)
	if type(value) == "number" then
		self:_TSMSetDebugValue("alpha", value)
		self:SetAlpha(value)
	else
		value:CallMethod(self, "TSMSetAlpha")
	end
end

---Sets the size based on a texture atlas key or width / height.
---@param value number|string|ReactivePublisherSchemaBase The width or texture atlas key or a publisher
---@param height? number The height (if and only if the first argument is a numeric width)
function TextureExtended:TSMSetSize(value, height)
	if type(value) == "string" then
		assert(height == nil)
		TextureAtlas.SetSize(self, value)
	elseif type(value) == "number" then
		assert(height)
		self:SetWidth(value)
		self:SetHeight(height)
	else
		value:CallMethod(self, "TSMSetSize")
	end
end



-- ============================================================================
-- FontStringExtended Methods
-- ============================================================================

---@class FontStringExtended: BaseExtension, FontString
local FontStringExtended = { __super = BaseExtension }

---Sets the text color.
---@param color Color|ThemeColorKey The color key
function FontStringExtended:TSMSetTextColor(color)
	self:_TSMSetDebugValue("textColor", color)
	if type(color) == "string" then
		color = Theme.GetColor(color)
	end
	self:SetTextColor(color:GetFractionalRGBA())
end

---Subscribes the text color.
---@param publisher ReactivePublisherSchemaBase A publisher for the vertex texture
function FontStringExtended:TSMSubscribeTextColor(publisher)
	publisher:FlatMapCallMethod(Theme.GetPublisher, self, "TSMSetTextColor")
end

---Sets the text.
---@param value string|ReactivePublisherSchemaBase The text or a publisher
function FontStringExtended:TSMSetText(value)
	if type(value) == "string" then
		self:_TSMSetDebugValue("text", value)
		self:SetText(value)
	else
		value:CallMethod(self, "TSMSetText")
	end
end

---Sets the font.
---@param value string|ReactivePublisherSchemaBase The font key or a publisher
function FontStringExtended:TSMSetFont(value)
	if type(value) == "string" then
		self:_TSMSetDebugValue("font", value)
		self:SetFont(Theme.GetFont(value):GetWowFont())
	else
		value:CallMethod(self, "TSMSetFont")
	end
end

---Sets the horizontal justification.
---@param value JustifyHorizontal|ReactivePublisherSchemaBase The horizontal justification or a publisher
function FontStringExtended:TSMSetJustifyH(value)
	if type(value) == "string" then
		self:_TSMSetDebugValue("justifyH", value)
		self:SetJustifyH(value)
	else
		value:CallMethod(self, "TSMSetJustifyH")
	end
end

---Sets the vertical justification.
---@param value JustifyVertical|ReactivePublisherSchemaBase The vertical justification or a publisher
function FontStringExtended:TSMSetJustifyV(value)
	if type(value) == "string" then
		self:_TSMSetDebugValue("justifyV", value)
		self:SetJustifyV(value)
	else
		value:CallMethod(self, "TSMSetJustifyV")
	end
end

---Sets the font spacing.
---@param value number|ReactivePublisherSchemaBase The spacing or a publisher
function FontStringExtended:TSMSetSpacing(value)
	if type(value) == "number" then
		self:_TSMSetDebugValue("spacing", value)
		self:SetSpacing(value)
	else
		value:CallMethod(self, "TSMSetSpacing")
	end
end



-- ============================================================================
-- AnimationGroupExtended Methods
-- ============================================================================

---@class AnimationGroupExtended: BaseExtension, AnimationGroup
local AnimationGroupExtended = { __super = BaseExtension }

---Sets whether or not the animation group is playing.
---@param value boolean|ReactivePublisherSchemaBase The playing value or a publisher
function AnimationGroupExtended:TSMSetPlaying(value)
	if type(value) == "boolean" then
		if value == self:IsPlaying() then
			return
		end
		if value then
			self:Play()
		else
			self:Stop()
		end
	else
		value:CallMethod(self, "TSMSetPlaying")
	end
end



-- ============================================================================
-- EditBoxExtended Methods
-- ============================================================================

---@class EditBoxExtended: FontStringExtended, EditBox
local EditBoxExtended = { __super = FontStringExtended }

---Sets whether or not the edit box is disabled.
---@param value boolean|ReactivePublisherSchemaBase The disabled value or a publisher
function EditBoxExtended:TSMSetDisabled(value)
	if type(value) == "boolean" then
		self:_TSMSetDebugValue("disabled", value)
		if value then
			self:Disable()
		else
			self:Enable()
		end
	else
		value:CallMethod(self, "TSMSetDisabled")
	end
end

---Sets the highlight color.
---@param color Color|ThemeColorKey The color value or key
function EditBoxExtended:TSMSetHighlightColor(color)
	self:_TSMSetDebugValue("highlightColor", color)
	if type(color) == "string" then
		color = Theme.GetColor(color)
	end
	self:SetHighlightColor(color:GetFractionalRGBA())
end

---Subscribes the highlight color.
---@param publisher ReactivePublisherSchemaBase A publisher for the highlight color
function EditBoxExtended:TSMSubscribeHighlightColor(publisher)
	publisher:FlatMapCallMethod(Theme.GetPublisher, self, "TSMSetHighlightColor")
end

---Sets whether or not the edit box is focused.
---@param value boolean|ReactivePublisherSchemaBase The focused value or a publisher
function EditBoxExtended:TSMSetFocused(value)
	if type(value) == "boolean" then
		self:_TSMSetDebugValue("focused", value)
		if value then
			self:SetFocus()
		else
			self:ClearFocus()
		end
	else
		value:CallMethod(self, "TSMSetFocused")
	end
end

---Sets whether or not the edit box is fully highlighted.
---@param value boolean|ReactivePublisherSchemaBase The highlighted value or a publisher
function EditBoxExtended:TSMSetAllHighlighted(value)
	if type(value) == "boolean" then
		if value then
			self:HighlightText(0, -1)
		else
			self:HighlightText(0, 0)
		end
	else
		value:CallMethod(self, "TSMSetAllHighlighted")
	end
end

---Sets the number value for the edit box.
---@param value number|ReactivePublisherSchemaBase The value or a publisher
function EditBoxExtended:TSMSetNumber(value)
	if type(value) == "number" then
		self:_TSMSetDebugValue("number", value)
		self:SetNumber(value)
	else
		value:CallMethod(self, "TSMSetNumber")
	end
end



-- ============================================================================
-- SliderExtended Methods
-- ============================================================================

---@class SliderExtended: BaseExtension, Slider
local SliderExtended = { __super = BaseExtension }

---Creates a thumb texture and adds it to the slider.
---@generic T: Class
---@param owner T The class object which owns the new thumb texture (for debug purposes)
function SliderExtended:TSMCreateThumbTexture(owner)
	local thumb = Widgets.CreateTexture(owner, self)
	self:SetThumbTexture(thumb)
	thumb:SetPoint("CENTER")
	local orientation = self:GetOrientation()
	if orientation == "HORIZONTAL" then
		thumb:SetHeight(Theme.GetScrollbarWidth())
	elseif orientation == "VERTICAL" then
		thumb:SetWidth(Theme.GetScrollbarWidth())
	else
		error("Invalid orientation: "..tostring(orientation))
	end
end

---Sets the thumb color texture.
---@param color ThemeColorKey|string The color key
function SliderExtended:TSMSetThumbColorTexture(color)
	local texture = self:GetThumbTexture() ---@type TextureExtended
	texture:TSMSetColorTexture(color)
end

---Updates the thumb length for use in a scroll frame.
---@param contentLength number The length of the content
---@param visibleLength number The length of the visible area
function SliderExtended:TSMUpdateThumbLength(contentLength, visibleLength)
	-- Arbitrary minimum length
	local minLength = 25
	-- The maximum length of the scrollbar is half the total visible length
	local maxLength = visibleLength / 2
	if minLength >= maxLength or visibleLength >= contentLength then
		return maxLength
	end

	-- Calculate the ratio of our total content length to the visible length (capped at 10)
	local ratio = min(contentLength / visibleLength, 10)
	assert(ratio >= 1)
	-- Calculate the appropriate scroll bar length based on the ratio (which is between 1 and 10)
	local length = Math.Scale(ratio, 1, 10, maxLength, minLength)

	-- Set the appropriate dimension
	local orientation = self:GetOrientation()
	local thumb = self:GetThumbTexture()
	if orientation == "HORIZONTAL" then
		thumb:SetWidth(length)
	elseif orientation == "VERTICAL" then
		thumb:SetHeight(length)
	else
		error("Invalid orientation: "..tostring(orientation))
	end
end



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a WoW UI frame, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new slider (for debug purposes)
---@param parentFrame? Frame The parent WoW UI object
---@return FrameExtended
function Widgets.CreateFrame(owner, parentFrame)
	local name = WidgetsDebug.CreateName("TSM_FRAME", owner)
	local frame = private.WithExtension(CreateFrame("Frame", name, parentFrame, "BackdropTemplate"), FrameExtended)
	if name then
		_G[name] = nil
	end
	return frame
end

---Creates a WoW UI scroll frame, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new slider (for debug purposes)
---@param parentFrame? Frame The parent WoW UI frame
---@return ScrollFrameExtended
function Widgets.CreateScrollFrame(owner, parentFrame)
	local name = WidgetsDebug.CreateName("TSM_SCROLL_FRAME", owner)
	local scrollFrame = private.WithExtension(CreateFrame("ScrollFrame", name, parentFrame, nil), BaseExtension)
	if name then
		_G[name] = nil
	end
	return scrollFrame
end

---Creates a WoW UI button, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new slider (for debug purposes)
---@param parentFrame? Frame The parent WoW UI frame
---@param name? string The global name
---@param isSecure? boolean Whether or not the button is secure
---@return ButtonExtended
function Widgets.CreateButton(owner, parentFrame, name, isSecure)
	local isNamed = name and true or false
	name = name or WidgetsDebug.CreateName("TSM_BUTTON", owner)
	local template = isSecure and "SecureActionButtonTemplate" or nil
	local button = private.WithExtension(CreateFrame("Button", name, parentFrame, template), ButtonExtended)
	if not isNamed and name then
		_G[name] = nil
	end
	return button
end

---Creates a WoW edit box, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new slider (for debug purposes)
---@param parentFrame? Frame The parent WoW UI frame
---@return EditBoxExtended
function Widgets.CreateEditBox(owner, parentFrame)
	local name = WidgetsDebug.CreateName("TSM_EDIT_BOX", owner)
	local editBox = private.WithExtension(CreateFrame("EditBox", name, parentFrame, nil), EditBoxExtended)
	if name then
		_G[name] = nil
	end
	return editBox
end

---Creates a WoW slider, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new slider (for debug purposes)
---@param parentFrame Frame The parent WoW UI frame
---@return SliderExtended
function Widgets.CreateSlider(owner, parentFrame)
	local name = WidgetsDebug.CreateName("TSM_SLIDER", owner)
	local slider = private.WithExtension(CreateFrame("Slider", nil, parentFrame, nil), SliderExtended)
	if name then
		_G[name] = nil
	end
	return slider
end

---Creates a WoW UI font string, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new slider (for debug purposes)
---@param parentFrame Frame The parent WoW UI frame
---@return FontStringExtended
function Widgets.CreateFontString(owner, parentFrame)
	local name = WidgetsDebug.CreateName("TSM_FONT_STRING", owner)
	local fontString = private.WithExtension(parentFrame:CreateFontString(name), FontStringExtended)
	-- Set a default font to avoid errors
	fontString:SetFont("Fonts\\FRIZQT__.TTF", 11)
	if name then
		_G[name] = nil
	end
	return fontString
end

---Creates a WoW UI texture, adds our custom extensions to it, and tracks it for easier debugging.
---@generic T: Class
---@param owner T The class object which owns the new texture (for debug purposes)
---@param parentFrame Frame The parent WoW UI frame
---@param layer? DrawLayer The layer (defaults to "ARTWORK")
---@param subLayer? number The sublayer
---@return TextureExtended
function Widgets.CreateTexture(owner, parentFrame, layer, subLayer)
	local name = WidgetsDebug.CreateName("TSM_TEXTURE", owner)
	local texture = private.WithExtension(parentFrame:CreateTexture(name, layer or "ARTWORK", nil, subLayer), TextureExtended)
	if name then
		_G[name] = nil
	end
	return texture
end

---Creates an animation group with extensions.
---@param texture Texture
---@return AnimationGroupExtended
function Widgets.CreateAnimationGroup(texture)
	return private.WithExtension(texture:CreateAnimationGroup(), AnimationGroupExtended)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.WithExtension(obj, extension)
	obj.__debug = {}
	local isFirstExtension = true
	while extension do
		for name, func in pairs(extension) do
			if name == "__super" then
				-- Pass
			elseif obj[name] then
				assert(not isFirstExtension)
			else
				obj[name] = func
			end
		end
		extension = extension.__super
		isFirstExtension = false
	end
	return obj
end

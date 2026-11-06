-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local MIN_AUTO_WIDTH_PADDING = 4

---@alias JustifyHValue "LEFT"|"CENTER"|"RIGHT"
---@alias JustifyVValue "TOP"|"MIDDLE"|"BOTTOM"



-- ============================================================================
-- Element Definition
-- ============================================================================

local Text = ComponentRegistry.Define("Text", "Element")
Text._STATE_SCHEMA = Text._STATE_SCHEMA:Extend("TextState")
	:AddStringField("textStr", "")
	:AddBooleanField("autoWidth", false)
	:AddStringField("color", "on/surface", Theme.IsValidColor)
	:AddStringField("font", "BODY_BODY1", Theme.IsValidFont)
	:AddStringField("justifyH", "LEFT", private.ValidateJustifyH)
	:AddStringField("justifyV", "MIDDLE", private.ValidateJustifyV)
	:AddNumberField("textSpacing", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Text:__init(frame, noColorPublisher, noFontPublisher)
	self.__super:__init(frame or self:_CreateFrame())

	self._text = self:_CreateFontString()
	self._text:SetAllPoints()
	if not noFontPublisher then
		self._text:TSMSetFont(self._state:Publisher("font"))
	end
	self._text:TSMSetJustifyH(self._state:Publisher("justifyH"))
	self._text:TSMSetJustifyV(self._state:Publisher("justifyV"))
	if not noColorPublisher then
		self._text:TSMSubscribeTextColor(self._state:Publisher("color"))
	end
	self._text:TSMSetText(self._state:Publisher("textStr"))
	self._text:TSMSetSpacing(self._state:Publisher("textSpacing"))

	self._state:PublisherForFunctionWithKeys(private.StateToFontSpacing, "font", "textStr")
		:AssignToTableKey(self._state, "textSpacing")

	self._state:PublisherForKeys("textSpacing", "textStr", "autoWidth")
		:IgnoreIfEquals(false, "autoWidth")
		:CallMethod(self, "_DrawForAutoWidth")
end

---Sets the width of the text.
---@param value? number|"AUTO"|ReactivePublisherSchemaBase The width of the text, "AUTO" to set the width based on the length of the text, nil to have an undefined width, or a publisher
---@return self
function Text:SetWidth(value)
	if value == "AUTO" then
		self._state.autoWidth = true
	else
		---@cast value number|ReactivePublisherSchemaBase|nil
		self._state.autoWidth = false
		self.__super:SetWidth(value)
	end
	return self
end

---Sets the width and height of the element.
---@param width? number|"AUTO" The width of the text, "AUTO" to set the width based on the length of the text, or nil to have an undefined width
---@param height? number The height of the text, or nil to have an undefined height
---@return self
function Text:SetSize(width, height)
	self:SetWidth(width)
	self:SetHeight(height)
	return self
end

---Sets the font.
---@param font string The font key
---@return self
function Text:SetFont(font)
	self._state.font = font
	return self
end

---Sets the color of the text.
---@param value string|ReactivePublisherSchemaBase<string> The text color as a theme color key or a publisher
---@return self
function Text:SetTextColor(value)
	if type(value) == "string" then
		self._state.color = value
	else
		self:_MethodPublisher(value, "SetTextColor")
	end
	return self
end

---Sets the horizontal justification of the text.
---@param justifyH JustifyHValue The horizontal justification
---@return self
function Text:SetJustifyH(justifyH)
	assert(justifyH == "LEFT" or justifyH == "CENTER" or justifyH == "RIGHT")
	self._state.justifyH = justifyH
	return self
end

---Sets the vertical justification of the text.
---@param justifyV JustifyVValue The vertical justification
---@return self
function Text:SetJustifyV(justifyV)
	assert(justifyV == "TOP" or justifyV == "MIDDLE" or justifyV == "BOTTOM")
	self._state.justifyV = justifyV
	return self
end

---Set the text.
---@param value string|number|ReactivePublisherSchemaBase<string|number> The text or a publisher
---@return self
function Text:SetText(value)
	if type(value) == "number" then
		value = tostring(value)
	end
	if type(value) == "string" then
		self._state.textStr = value
	else
		self:_MethodPublisher(value, "SetText")
	end
	return self
end

---Set formatted text.
---@param message string The message or format string
---@param ... string|number|boolean The format arguments
---@return self
function Text:SetFormattedText(message, ...)
	self:SetText(format(message, ...))
	return self
end

---Gets the text string.
---@return string
function Text:GetText()
	return self._state.textStr
end

---Get the rendered text string width.
---@return number
function Text:GetStringWidth()
	return self._text:GetStringWidth()
end

---Get the rendered text string height.
---@return number
function Text:GetStringHeight()
	return self._text:GetStringHeight()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function Text:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth then
		return 0, self._state.width == nil
	else
		return self.__super:_GetMinimumDimension(dimension)
	end
end

function Text:_GetPreferredDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth then
		return self:GetStringWidth() + max(self:_GetPadding("LEFT") + self:_GetPadding("RIGHT"), MIN_AUTO_WIDTH_PADDING)
	else
		return self.__super:_GetPreferredDimension(dimension)
	end
end

function Text.__protected:_DrawForAutoWidth()
	local parent = self:GetParentElement()
	if parent then
		parent:Draw()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateJustifyH(justifyH)
	return justifyH == "LEFT" or justifyH == "CENTER" or justifyH == "RIGHT"
end

function private.ValidateJustifyV(justifyV)
	return justifyV == "TOP" or justifyV == "MIDDLE" or justifyV == "BOTTOM"
end

function private.StateToFontSpacing(font, textStr)
	if not font then
		return 0
	end
	-- There's a Blizzard bug where spacing incorrectly gets applied to embedded textures, so just set it to 0 in that case
	-- TODO: come up with a better fix if we need multi-line text with embedded textures
	if strfind(textStr, "|[TA]") then
		return 0
	end
	return Theme.GetFont(font):GetSpacing()
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {}
local THUMB_WIDTH = 8
local INPUT_WIDTH = 50
local INPUT_AREA_SPACE = 128
local CORNER_RADIUS = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local RangeInput = ComponentRegistry.Define("RangeInput", "Element")
RangeInput._STATE_SCHEMA = RangeInput._STATE_SCHEMA:Extend("RangeInputState")
	:AddDeferredStringField("value")
	:AddStringField("font", "BODY_SMALL")
	:AddStringField("textColor", "on/surface")
	:Commit()
RangeInput:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function RangeInput:__init()
	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)
	self._frame:EnableMouse(true)
	self._frame:TSMSetScript("OnMouseDown", self:__closure("_HandleFrameMouseDown"))
	self._frame:TSMSetScript("OnMouseUp", self:__closure("_HandleFrameMouseUp"))
	self._frame:TSMSetOnUpdate(self:__closure("_HandleFrameUpdate"))

	self._minValue = nil ---@type number!
	self._maxValue = nil ---@type number!
	self._dragging = nil

	local fontPublisher = self._state:Publisher("font")
		:Share()
	local textColorPublisher = self._state:Publisher("textColor")
		:Share()
	local valuePublisher = self._state:Publisher("value")
		:IgnoreNil()
		:Share()
	local inputBgPublisher = self:_GetOneShotPublisher("container/highest")
		:Share()

	-- Create the textures
	self._barTexture = self:_CreateTexture(self._frame, "BACKGROUND", 1)
	self._barTexture:TSMSubscribeColorTexture(self:_GetOneShotPublisher("container/medium"))
	self._activeBarTexture = self:_CreateTexture(self._frame, "BACKGROUND", 2)
	self._activeBarTexture:TSMSubscribeColorTexture(self:_GetOneShotPublisher("on/surface"))
	self._thumbTextureLeft = self:_CreateTexture(self._frame, "ARTWORK")
	TextureAtlas.SetTextureAndSize(self._thumbTextureLeft, "iconPack.14x14/Circle")
	self._thumbTextureRight = self:_CreateTexture(self._frame, "ARTWORK")
	TextureAtlas.SetTextureAndSize(self._thumbTextureRight, "iconPack.14x14/Circle")

	self._inputLeft = self:_CreateEditBox()
	self._inputLeft:SetJustifyH("CENTER")
	self._inputLeft:SetWidth(INPUT_WIDTH)
	self._inputLeft:SetHeight(24)
	self._inputLeft:SetAutoFocus(false)
	self._inputLeft:SetNumeric(true)
	self._inputLeft:TSMSetFont(fontPublisher)
	self._inputLeft:TSMSubscribeTextColor(textColorPublisher)
	self._inputLeft:TSMSetNumber(valuePublisher:Map(private.ValueToLeftValue))
	self._inputLeft:TSMSetScript("OnEscapePressed", self:__closure("_HandleInputEscapePressed"))
	self._inputLeft:TSMSetScript("OnEnterPressed", self:__closure("_HandleInputEnterPressed"))

	self._dash = self:_CreateFontString()
	self._dash:SetJustifyH("CENTER")
	self._dash:SetJustifyV("MIDDLE")
	self._dash:SetWidth(12)
	self._dash:TSMSetFont(fontPublisher)
	self._dash:TSMSubscribeTextColor(textColorPublisher)
	self._dash:SetText("-")

	self._inputRight = self:_CreateEditBox()
	self._inputRight:SetJustifyH("CENTER")
	self._inputRight:SetWidth(INPUT_WIDTH)
	self._inputRight:SetHeight(24)
	self._inputRight:SetNumeric(true)
	self._inputRight:SetAutoFocus(false)
	self._inputRight:TSMSetFont(fontPublisher)
	self._inputRight:TSMSubscribeTextColor(textColorPublisher)
	self._inputRight:TSMSetNumber(valuePublisher:Map(private.ValueToRightValue))
	self._inputRight:TSMSetScript("OnEscapePressed", self:__closure("_HandleInputEscapePressed"))
	self._inputRight:TSMSetScript("OnEnterPressed", self:__closure("_HandleInputEnterPressed"))

	self._barTexture:SetPoint("LEFT", 0, 0)
	self._barTexture:SetPoint("RIGHT", self._inputLeft, "LEFT", -16, 0)
	self._inputRight:SetPoint("RIGHT", 0)
	self._dash:SetPoint("RIGHT", self._inputRight, "LEFT", 0, 0)
	self._inputLeft:SetPoint("RIGHT", self._dash, "LEFT", 0)

	self._inputLeftBackground = self:_CreateRectangle(nil, self._inputLeft)
	self._inputLeftBackground:SetCornerRadius(CORNER_RADIUS)
	self._inputLeftBackground:SubscribeColor(inputBgPublisher)
	self._inputRightBackground = self:_CreateRectangle(nil, self._inputRight)
	self._inputRightBackground:SetCornerRadius(CORNER_RADIUS)
	self._inputRightBackground:SubscribeColor(inputBgPublisher)

	fontPublisher:EndShare()
	textColorPublisher:EndShare()
	valuePublisher:EndShare()
	inputBgPublisher:EndShare()
end

function RangeInput:Release()
	self._minValue = nil
	self._maxValue = nil
	self._dragging = nil
	self.__super:Release()
end

---Set the extents of the possible range.
---@param value string The range value with the lower and upper ends separated by a comma
---@return self
function RangeInput:SetRange(value)
	local minValue, maxValue = private.SplitValue(value)
	self._minValue = minValue
	self._maxValue = maxValue
	self:SetValue(value)
	return self
end

---Sets the current value.
---@param value string|ReactivePublisherSchemaBase The range value with the lower and upper ends separated by a comma or a publisher
---@return self
function RangeInput:SetValue(value)
	if type(value) == "string" then
		local leftValue, rightValue = private.SplitValue(value)
		assert(leftValue <= rightValue and leftValue >= self._minValue and rightValue <= self._maxValue)
		self._state.value = value
		self:_SendActionScript("OnValueChanged")
	else
		self:_MethodPublisher(value, "SetValue")
	end
	return self
end

---Gets the current value
---@return string
function RangeInput:GetValue()
	assert(self._state.value)
	return self._state.value
end

---Mirrors the value with the specified state.
---@param state ReactiveState The state to mirror
---@param key string The state key to mirror
---@return self
function RangeInput:MirrorValueState(state, key)
	self:AddCancellable(state:Publisher(key):CallMethod(self, "SetValue"))
	self._state:Publisher("value")
		:AssignToTableKey(state, key)
	return self
end

function RangeInput:Draw()
	self.__super:Draw()

	local sliderHeight = self:_GetDimension("HEIGHT") / 2
	local width = self:_GetDimension("WIDTH") - INPUT_AREA_SPACE
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local leftPos = Math.Scale(leftValue, self._minValue, self._maxValue, 0, width - THUMB_WIDTH)
	local rightPos = Math.Scale(rightValue, self._minValue, self._maxValue, 0, width - THUMB_WIDTH)

	self._barTexture:SetHeight(sliderHeight / 3)

	self._thumbTextureLeft:SetPoint("LEFT", self._barTexture, leftPos, 0)
	self._thumbTextureRight:SetPoint("LEFT", self._barTexture, rightPos, 0)

	self._activeBarTexture:SetPoint("LEFT", self._thumbTextureLeft, "CENTER")
	self._activeBarTexture:SetPoint("RIGHT", self._thumbTextureRight, "CENTER")
	self._activeBarTexture:SetHeight(sliderHeight / 3)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function RangeInput:_GetCursorPositionValue()
	local x = GetCursorPosition() / self._frame:GetEffectiveScale()
	local left = self._frame:GetLeft() + THUMB_WIDTH / 2
	local right = self._frame:GetRight() - THUMB_WIDTH / 2 - INPUT_AREA_SPACE
	x = min(max(x, left), right)
	local value = Math.Scale(x, left, right, self._minValue, self._maxValue)
	return min(max(Math.Round(value), self._minValue), self._maxValue)
end

function RangeInput:_UpdateLeftValue(value)
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local newValue = max(min(value, rightValue), self._minValue)
	if newValue == leftValue then
		self._inputLeft:SetNumber(leftValue)
		return
	end
	self:SetValue(newValue..","..rightValue)
	self:Draw()
end

function RangeInput:_UpdateRightValue(value)
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local newValue = min(max(value, leftValue), self._maxValue)
	if newValue == rightValue then
		self._inputRight:SetNumber(rightValue)
		return
	end
	self:SetValue(leftValue..","..newValue)
	self:Draw()
end

function RangeInput:_HandleFrameMouseDown()
	self._inputLeft:ClearFocus()
	self._inputRight:ClearFocus()
	local value = self:_GetCursorPositionValue()
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local leftDiff = abs(value - leftValue)
	local rightDiff = abs(value - rightValue)
	if value < leftValue then
		-- clicked to the left of the left thumb, so drag that
		self._dragging = "left"
	elseif value > rightValue then
		-- clicked to the right of the right thumb, so drag that
		self._dragging = "right"
	elseif leftValue == rightValue then
		-- just ignore this click since they clicked on both thumbs
	elseif leftDiff < rightDiff then
		-- clicked closer to the left thumb, so drag that
		self._dragging = "left"
	else
		-- clicked closer to the right thumb (or right in the middle), so drag that
		self._dragging = "right"
	end
end

function RangeInput:_HandleFrameMouseUp()
	self._dragging = nil
end

function RangeInput:_HandleFrameUpdate()
	if not self._dragging then
		return
	end
	if self._dragging == "left" then
		self:_UpdateLeftValue(self:_GetCursorPositionValue())
	elseif self._dragging == "right" then
		self:_UpdateRightValue(self:_GetCursorPositionValue())
	else
		error("Unexpected dragging: "..tostring(self._dragging))
	end
end

function RangeInput:_HandleInputEscapePressed(input)
	input:ClearFocus()
	local leftValue, rightValue = private.SplitValue(self._state.value)
	if input == self._inputLeft then
		input:SetNumber(leftValue)
	elseif input == self._inputRight then
		input:SetNumber(rightValue)
	else
		error("Invalid input")
	end
end

function RangeInput:_HandleInputEnterPressed(input)
	local value = input:GetNumber()
	input:ClearFocus()
	if input == self._inputLeft then
		self:_UpdateLeftValue(value)
	elseif input == self._inputRight then
		self:_UpdateRightValue(value)
	else
		error("Invalid input")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SplitValue(value)
	local leftValue, rightValue = strsplit(",", value)
	leftValue = tonumber(leftValue)
	rightValue = tonumber(rightValue)
	assert(leftValue and rightValue)
	return leftValue, rightValue
end

function private.ValueToLeftValue(value)
	local leftValue = private.SplitValue(value)
	return leftValue
end

function private.ValueToRightValue(value)
	local _, rightValue = private.SplitValue(value)
	return rightValue
end

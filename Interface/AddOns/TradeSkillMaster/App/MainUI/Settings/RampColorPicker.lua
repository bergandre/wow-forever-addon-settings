-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local ColorRamp = App:From("LibTSMUtil"):IncludeClassType("ColorRamp")
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local HUE_MAX = 360
local CHROMA_MAX = 0.4
local FIELD_SIZE = 180
local FIELD_RADIUS = FIELD_SIZE / 2
local CHIP_HEIGHT = 32
local PAD = 8
local FIELD_CHIP_GAP = 10
local FRAME_HEIGHT = PAD + FIELD_SIZE + FIELD_CHIP_GAP + CHIP_HEIGHT + PAD



-- ============================================================================
-- Element Definition
-- ============================================================================

local RampColorPicker = UIElements.Define("RampColorPicker", "Element")
RampColorPicker._STATE_SCHEMA = RampColorPicker._STATE_SCHEMA:Extend("RampColorPickerState")
	:AddNumberField("hue", 0)
	:AddNumberField("chroma", 0)
	:AddBooleanField("dragging", false)
	:AddNumberField("primaryStep", 80)
	:AddNumberField("onStep", 35)
	:Commit()
RampColorPicker:_AddActionScripts("OnRampChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function RampColorPicker:__init()
	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)

	self._ramp = ColorRamp.New(0, 0)

	-- The interactive hue (angle) by chroma (radius) wheel
	self._fieldFrame = self:_CreateFrame(self._frame)
	self._fieldFrame:SetSize(FIELD_SIZE, FIELD_SIZE)
	self._fieldFrame:SetPoint("TOPLEFT", PAD, -PAD)
	self._fieldFrame:EnableMouse(true)
	self._fieldFrame:TSMSetScript("OnMouseDown", self:__closure("_HandleFieldMouseDown"))
	self._fieldFrame:TSMSetScript("OnMouseUp", self:__closure("_HandleFieldMouseUp"))
	self._fieldFrame:TSMSetOnUpdate(self:__closure("_HandleFieldUpdate"))

	local field = self:_CreateTexture(self._fieldFrame, "BACKGROUND")
	field:SetAllPoints(self._fieldFrame)
	field:SetTexture("Interface\\AddOns\\TradeSkillMaster\\Media\\ramp_wheel.png")

	self._handle = self:_CreateTexture(self._fieldFrame, "OVERLAY", 2)
	self._handle:TSMSetTextureAndSize("iconPack.14x14/Circle")
	self._handle:TSMSubscribeVertexColor(self:_GetOneShotPublisher("on/surface"))
	self._handleBorder = self:_CreateTexture(self._fieldFrame, "OVERLAY", 1)
	self._handleBorder:TSMSetTextureAndSize("iconPack.18x18/Circle")
	self._handleBorder:TSMSubscribeVertexColor(self:_GetOneShotPublisher("container/lowest"))
	self._handleBorder:SetPoint("CENTER", self._handle, "CENTER", 0, 0)

	self._chipBackground = self:_CreateTexture(self._frame, "ARTWORK")
	self._chipBackground:SetSize(FIELD_SIZE, CHIP_HEIGHT)
	self._chipBackground:SetPoint("TOPLEFT", self._fieldFrame, "BOTTOMLEFT", 0, -FIELD_CHIP_GAP)
	self._chipText = self:_CreateFontString(self._frame)
	self._chipText:TSMSetFont("BODY_SMALL_SEMIBOLD")
	self._chipText:TSMSetJustifyH("CENTER")
	self._chipText:TSMSetText("Aa")
	self._chipText:SetPoint("CENTER", self._chipBackground, "CENTER", 0, 0)

	self._state:PublisherForKeys("hue", "chroma")
		:CallFunction(self:__closure("_UpdateHandle"))
	self._state:PublisherForKeys("hue", "chroma", "primaryStep", "onStep")
		:CallFunction(self:__closure("_UpdatePreview"))
end

function RampColorPicker:Acquire()
	self.__super:Acquire()
	self:SetSize(FIELD_SIZE + 2 * PAD, FRAME_HEIGHT)
end

---Sets the hue and chroma of the ramp being edited.
---@param hue number Hue in degrees from 0 to 360
---@param chroma number Chroma in OKLab units
---@return self
function RampColorPicker:SetRamp(hue, chroma)
	self._state.hue = Math.Bound(hue, 0, HUE_MAX)
	self._state.chroma = Math.Bound(chroma, 0, CHROMA_MAX)
	return self
end

---Sets which ramp steps the preview chip samples for its background and text colors.
---@param primaryStep number The step sampled for the chip background
---@param onStep number The step sampled for the chip text
---@return self
function RampColorPicker:SetPreviewSteps(primaryStep, onStep)
	self._state.primaryStep = primaryStep
	self._state.onStep = onStep
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function RampColorPicker.__private:_UpdateHandle()
	local radius = self._state.chroma / CHROMA_MAX * FIELD_RADIUS
	local angle = math.rad(self._state.hue)
	self._handle:SetPoint("CENTER", self._fieldFrame, "CENTER", radius * math.cos(angle), -radius * math.sin(angle))
end

function RampColorPicker.__private:_UpdatePreview()
	self._ramp:SetHueChroma(self._state.hue, self._state.chroma)
	local r, g, b = self._ramp:GetRGBA(self._state.primaryStep)
	self._chipBackground:SetColorTexture(r / 255, g / 255, b / 255)
	r, g, b = self._ramp:GetRGBA(self._state.onStep)
	self._chipText:SetTextColor(r / 255, g / 255, b / 255)
end

function RampColorPicker.__private:_UpdateFromCursor()
	local scale = self._fieldFrame:GetEffectiveScale()
	local left = self._fieldFrame:GetLeft()
	local top = self._fieldFrame:GetTop()
	if not left or not top then
		return
	end
	local cursorX, cursorY = GetCursorPosition()
	cursorX = cursorX / scale
	cursorY = cursorY / scale
	local dx = (cursorX - left) - FIELD_RADIUS
	local dy = (top - cursorY) - FIELD_RADIUS
	self._state.hue = math.deg(math.atan2(dy, dx)) % HUE_MAX
	self._state.chroma = Math.Bound(math.sqrt(dx * dx + dy * dy) / FIELD_RADIUS, 0, 1) * CHROMA_MAX
end

function RampColorPicker.__private:_HandleFieldMouseDown()
	self._state.dragging = true
	self:_UpdateFromCursor()
end

function RampColorPicker.__private:_HandleFieldMouseUp()
	self:_EndDrag()
end

function RampColorPicker.__private:_HandleFieldUpdate()
	if not self._state.dragging then
		return
	end
	if not IsMouseButtonDown("LeftButton") then
		self:_EndDrag()
		return
	end
	self:_UpdateFromCursor()
end

function RampColorPicker.__private:_EndDrag()
	if not self._state.dragging then
		return
	end
	self._state.dragging = false
	self:_SendActionScript("OnRampChanged", self._state.hue, self._state.chroma)
end

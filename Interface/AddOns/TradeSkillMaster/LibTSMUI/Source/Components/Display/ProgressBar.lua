-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local PROGRESS_ICON_PADDING = 4
local CORNER_RADIUS = 4
local BORDER_THICKNESS = 2
local PROGRESS_SCALE = 1000



-- ============================================================================
-- Element Definition
-- ============================================================================

local ProgressBar = ComponentRegistry.Define("ProgressBar", "Text")
ProgressBar._STATE_SCHEMA = ProgressBar._STATE_SCHEMA:Extend("ProgressBarState")
	:UpdateFieldDefault("font", "BODY_SMALL_SEMIBOLD")
	:UpdateFieldDefault("justifyH", "CENTER")
	:UpdateFieldDefault("color", "accent/main")
	:AddNumberField("progress", 0)
	:AddBooleanField("iconVisible", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ProgressBar:__init()
	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)

	local iconVisiblePublisher = self._state:Publisher("iconVisible")
		:Share()

	self._background = self:_CreateRectangle()
	self._background:SetCornerRadius(CORNER_RADIUS)
	self._background:SubscribeColor(self:_GetOneShotPublisher("container/lowest"))

	self._bar = self:_CreateRectangle(1)
	self._bar:SetCornerRadius(CORNER_RADIUS)
	self._bar:SetInset(BORDER_THICKNESS)
	self._bar:SubscribeColor(self:_GetOneShotPublisher("container/highest"))

	self._barMask = self:_CreateTexture(frame, "ARTWORK", 2)
	self._barMask:SetPoint("TOPRIGHT", -BORDER_THICKNESS, -BORDER_THICKNESS)
	self._barMask:SetPoint("BOTTOMRIGHT", -BORDER_THICKNESS, BORDER_THICKNESS)
	self._barMask:TSMSubscribeColorTexture(self:_GetOneShotPublisher("container/lowest"))

	-- Create the progress icon
	self._progressIcon = self:_CreateTexture(frame, "OVERLAY")
	self._progressIcon:SetPoint("RIGHT", self._text, "LEFT", -PROGRESS_ICON_PADDING, 0)
	self._progressIcon:TSMSetTextureAndSize("iconPack.18x18/Running")
	self._progressIcon:TSMSetShown(iconVisiblePublisher)
	self._progressIcon:TSMSubscribeVertexColor(self._state:Publisher("color"))

	self._progressIconAnimationGroup = self:_CreateAnimationGroup(self._progressIcon)
	local spin = self._progressIconAnimationGroup:CreateAnimation("Rotation")
	spin:SetDuration(2)
	spin:SetDegrees(360)
	self._progressIconAnimationGroup:SetLooping("REPEAT")
	self._progressIconAnimationGroup:TSMSetPlaying(iconVisiblePublisher)

	iconVisiblePublisher:EndShare()

	-- Redraw when the progress or text changes
	self._state:PublisherForKeys("progress", "textStr")
		:ReplaceWith(nil)
		:CallMethod(self, "Draw")
end

---Sets the progress.
---@param value number|ReactivePublisherSchemaBase The progress from a value of 0 to 1 (inclusive) or a publisher
---@return self
function ProgressBar:SetProgress(value)
	if type(value) == "number" then
		assert(value >= 0 and value <= 1)
		self._state.progress = Math.Round(value * PROGRESS_SCALE)
	else
		self:_MethodPublisher(value, "SetProgress")
	end
	return self
end

---Sets whether or not the progress indicator is hidden.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the progress indicator is hidden or a publisher
---@return self
function ProgressBar:SetProgressIconHidden(value)
	if type(value) == "boolean" then
		self._state.iconVisible = not value
	else
		self:_MethodPublisher(value, "SetProgressIconHidden")
	end
	return self
end

function ProgressBar:Draw()
	self.__super:Draw()

	self._text:ClearAllPoints()
	self._text:SetWidth(self:_GetDimension("WIDTH"))
	self._text:SetWidth(self._text:GetStringWidth())
	self._text:SetHeight(self:_GetDimension("HEIGHT"))
	self._text:SetPoint("CENTER", self._state.iconVisible and ((TextureAtlas.GetWidth("iconPack.18x18/Running") + PROGRESS_ICON_PADDING) / 2) or 0, 0)

	local progress = self._state.progress / PROGRESS_SCALE
	local maxWidth = self._frame:GetWidth() - BORDER_THICKNESS * 2
	local visibleWidth = min(Math.Round(progress * maxWidth), maxWidth)
	if visibleWidth == maxWidth then
		self._barMask:Hide()
	else
		self._barMask:Show()
		self._barMask:SetWidth(maxWidth - visibleWidth)
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Color = App:From("LibTSMUtil"):IncludeClassType("Color")
local ColorRamp = App:From("LibTSMUtil"):IncludeClassType("ColorRamp")
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local ThemeColorSets = App:From("LibTSMApp"):Include("Service.ThemeColorSets")
local HUE_MAX = 360
local CHROMA_MAX = 0.4
local BORDER_SIZE = 1
local CORNER_RADIUS = 4
local CARD_WIDTH = 160
local CARD_HEIGHT = 40
local LABEL_HEIGHT = 20
local LABEL_GAP = 4
local FRAME_HEIGHT = LABEL_HEIGHT + LABEL_GAP + CARD_HEIGHT
local DIALOG_WIDTH = 240
local DIALOG_HEIGHT = 294

---@event EditableRampColorAction
---| "ACTION_HANDLE_RAMP_CHANGED" -> hue: number, chroma: number
---| "ACTION_CLOSE_DIALOG"



-- ============================================================================
-- Element Definition
-- ============================================================================

local EditableRampColor = UIElements.Define("EditableRampColor", "Element")
EditableRampColor._STATE_SCHEMA = EditableRampColor._STATE_SCHEMA:Extend("EditableRampColorState")
	:AddNumberField("hue", 0)
	:AddNumberField("chroma", 0)
	:AddStringField("label", "")
	:AddStringField("tokenClass", "surface", function(value) return value == "surface" or value == "primary" or value == "secondary" end)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function EditableRampColor:__init()
	local frame = self:_CreateFrame()
	self._frame = frame
	self.__super:__init(frame)

	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_RAMP_CHANGED")
	self._ramp = ColorRamp.New(0, 0)
	self._mainColor = Color(0, 0, 0, 255)
	self._onColor = Color(0, 0, 0, 255)

	self._labelText = self:_CreateFontString(self._frame)
	self._labelText:TSMSetFont("BODY_SMALL_SEMIBOLD")
	self._labelText:TSMSetText(self._state:Publisher("label"))
	self._labelText:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface"))
	self._labelText:SetHeight(LABEL_HEIGHT)
	self._labelText:SetPoint("TOPLEFT")

	self._cardFrame = self:_CreateFrame(self._frame)
	self._cardFrame:SetSize(CARD_WIDTH, CARD_HEIGHT)
	self._cardFrame:SetPoint("TOPLEFT", self._frame, "TOPLEFT", 0, -(LABEL_HEIGHT + LABEL_GAP))

	self._borderRect = self:_CreateRectangle(nil, self._cardFrame)
	self._borderRect:SubscribeColor(self:_GetOneShotPublisher("outline/main"))
	self._borderRect:SetCornerRadius(CORNER_RADIUS)

	self._chipRect = self:_CreateRectangle(1, self._cardFrame)
	self._chipRect:SetInset(BORDER_SIZE)
	self._chipRect:SetCornerRadius(CORNER_RADIUS)

	self._chipText = self:_CreateFontString(self._cardFrame)
	self._chipText:TSMSetFont("BODY_SMALL_SEMIBOLD")
	self._chipText:TSMSetText("Aa")
	self._chipText:SetPoint("LEFT", 12, 0)

	self._editIcon = self:_CreateTexture(self._cardFrame, "OVERLAY")
	self._editIcon:SetPoint("RIGHT", -10, 0)
	self._editIcon:TSMSetTextureAndSize("iconPack.18x18/Edit")

	self._button = self:_CreateButton(self._cardFrame)
	self._button:SetAllPoints(self._cardFrame)
	self._button:TSMSetScript("OnClick", self:__closure("_ShowDialog"))

	self._state:PublisherForKeys("hue", "chroma")
		:CallFunction(self:__closure("_UpdateRampValue"))
	self._state:PublisherForKeys("tokenClass", "hue", "chroma")
		:Share()
		:Map("tokenClass")
		:Map(ThemeColorSets.GetMainTokenStep)
		:CallFunction(self:__closure("_UpdateMainColor"))
		:Map("tokenClass")
		:Map(ThemeColorSets.GetOnTokenStep)
		:CallFunction(self:__closure("_UpdateOnColor"))
		:EndShare()
end

function EditableRampColor:Acquire()
	self.__super:Acquire()
	self:SetSize(CARD_WIDTH, FRAME_HEIGHT)
end

---Configures the editable ramp color element.
---@param tokenClass ThemeColorTokenClass The token class
---@param label string The label
---@return self
function EditableRampColor:Configure(tokenClass, label)
	assert(label ~= "" and self._state.label == "")
	self._state.tokenClass = tokenClass
	self._state.label = label
	self:_FunctionPublisher(ThemeColorSets.GetRampsChangedPublisher(), self:__closure("_UpdateRamp"))
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function EditableRampColor.__private:_UpdateRamp()
	local hue, chroma = ThemeColorSets.GetCustomRamp(self._state.tokenClass)
	self._state.hue = Math.Bound(hue, 0, HUE_MAX)
	self._state.chroma = Math.Bound(chroma, 0, CHROMA_MAX)
end

---@param state EditableRampColorState
function EditableRampColor.__private:_UpdateRampValue(state)
	self._ramp:SetHueChroma(state.hue, state.chroma)
end

function EditableRampColor.__private:_UpdateMainColor(step)
	self._mainColor:SetRGBA(self._ramp:GetRGBA(step))
	self._chipRect:SetColor(self._mainColor)
end

function EditableRampColor.__private:_UpdateOnColor(step)
	self._onColor:SetRGBA(self._ramp:GetRGBA(step))
	self._chipText:TSMSetTextColor(self._onColor)
	self._editIcon:TSMSetVertexColor(self._onColor)
end

function EditableRampColor.__private:_ShowDialog()
	local hue, chroma = self._state.hue, self._state.chroma
	local mainStep = ThemeColorSets.GetMainTokenStep(self._state.tokenClass)
	local onStep = ThemeColorSets.GetOnTokenStep(self._state.tokenClass)
	self:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "rampColorDialog")
		:SetLayout("VERTICAL")
		:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
		:SetPadding(12, 12, 8, 12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("container/low")
		:SetMouseEnabled(true)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 12)
			:AddChild(UIElements.New("Text", "title")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(self._state.label)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetWidth(24)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		:AddChild(UIElements.New("RampColorPicker", "picker")
			:SetPreviewSteps(mainStep, onStep)
			:SetRamp(hue, chroma)
			:SetAction("OnRampChanged", "ACTION_HANDLE_RAMP_CHANGED")
		)
	)
end

---@param manager UIManager<EditableRampColorState>
---@param state EditableRampColorState
---@param action EditableRampColorAction
---@param ... params<EditableRampColorAction>
function EditableRampColor.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_RAMP_CHANGED" then
		local hue, chroma = ...
		ThemeColorSets.SetCustomRamp(state.tokenClass, hue, chroma)
	elseif action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

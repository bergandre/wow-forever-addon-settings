-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local UIElements = LibTSMUI:Include("UIElements")
local L = LibTSMUI.Locale.GetTable()
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local CONTENT_FRAME_OFFSET = 8
local DIALOG_RELATIVE_LEVEL = 25
local HEADER_HEIGHT = 40
local MIN_SCALE = 0.3
local MIN_ON_SCREEN_PX = 50
local CORNER_RADIUS = 6
local function NoOp() end

---@class ApplicationFrameContextTable
---@field width number
---@field height number
---@field centerX number
---@field centerY number
---@field scale number



-- ============================================================================
-- Element Definition
-- ============================================================================

local ApplicationFrame = ComponentRegistry.Define("ApplicationFrame", "BaseFrame")
ApplicationFrame:_AddActionScripts("OnSwitchButtonClick")
ApplicationFrame._STATE_SCHEMA = ApplicationFrame._STATE_SCHEMA:Extend("ApplicationFrameState")
	:UpdateFieldDefault("strata", "HIGH")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddDeferredUIElementField("titleFrame", "BaseFrame")
	:AddDeferredUIElementField("closeBtn", "BaseButton")
	:AddStringField("title", "")
	:AddBooleanField("addedAppStatus", false)
	:AddBooleanField("addedPlayerGold", false)
	:AddBooleanField("addedSwitchButton", false)
	:AddBooleanField("hideSwitchButton", false)
	:AddBooleanField("disableSwitchButton", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ApplicationFrame:__init()
	self.__super:__init()
	self._contextTable = nil ---@type ApplicationFrameContextTable!
	self._defaultContextTable = nil ---@type ApplicationFrameContextTable!
	self._resizeLeft = 0
	self._resizeTop = 0
	self._resizeOffsetX = 0
	self._resizeOffsetY = 0
	self._protected = nil
	self._minWidth = 0
	self._minHeight = 0
	self._dialogStack = {}

	local frame = self._frame
	if LibTSMUI.IsRetail() or LibTSMUI.IsForever() then
		frame:SetRoundLayoutToNearestPixel(true)
	end
	local globalFrameName = tostring(frame)
	_G[globalFrameName] = frame
	-- Insert our frames before other addons (i.e. Skillet) to avoid conflicts
	tinsert(UISpecialFrames, 1, globalFrameName)

	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_DRAG_START")
		:SuppressActionLog("ACTION_HANDLE_DRAG_STOP")
		:SuppressActionLog("ACTION_HANDLE_RESIZE_MOUSE_DOWN")
		:SuppressActionLog("ACTION_HANDLE_RESIZE_MOUSE_UP")

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)
	self._backgroundTexture:SubscribeColor(self:_GetOneShotPublisher("surface/main"))

	frame.resizeIcon = self:_CreateTexture() ---@diagnostic disable-line: inject-field
	frame.resizeIcon:SetPoint("BOTTOMRIGHT")
	frame.resizeIcon:TSMSetTextureAndSize("iconPack.14x14/Resize")

	frame.resizeBtn = self:_CreateButton() ---@diagnostic disable-line: inject-field
	frame.resizeBtn:SetAllPoints(frame.resizeIcon)
	frame.resizeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.resizeBtn:TSMSetScript("OnEnter", private.ResizeOnEnter)
	frame.resizeBtn:TSMSetScript("OnLeave", private.ResizeOnLeave)
	frame.resizeBtn:TSMSetScript("OnMouseDown", self._childManager:CallbackToProcessAction("ACTION_HANDLE_RESIZE_MOUSE_DOWN"))
	frame.resizeBtn:TSMSetScript("OnMouseUp", self._childManager:CallbackToProcessAction("ACTION_HANDLE_RESIZE_MOUSE_UP"))
	frame.resizeBtn:TSMSetScript("OnClick", self._childManager:CallbackToProcessAction("ACTION_HANDLE_RESIZE_CLICK"))
	Theme.RegisterChangeCallback(function()
		if self:IsVisible() then
			self:Draw()
		end
	end)
end

function ApplicationFrame:Acquire()
	self.__super:Acquire()
	self:SetParent(UIParent)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChildNoLayout(UIElements.New("BaseFrame", "titleFrame")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:AddAnchor("TOPLEFT", 8, -8)
			:AddAnchor("TOPRIGHT", -8, -8)
			:BindElement(self._state, "titleFrame")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseTexture", "icon")
				:SetMargin(0, 16, 0, 0)
				:SetTextureAndSize("uiFrames.SmallLogo")
			)
			:AddChild(UIElements.New("Text", "title")
				:AddAnchor("CENTER")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetTextColor("on/surface/low")
				:SetText(self._state:Publisher("title"))
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("AppStatusIcon", "appStatus")
				:SetMargin(0, 8, 0, 0)
				:SetShown(self._state:Publisher("addedAppStatus"))
			)
			:AddChild(UIElements.New("PlayerGoldText", "playerGold")
				:SetWidth("AUTO")
				:SetMargin(0, 8, 0, 0)
				:SetShown(self._state:Publisher("addedPlayerGold"))
			)
			:AddChild(UIElements.New("SmallSecondaryActionButton", "switchBtn")
				:SetWidth(83)
				:SetMargin(0, 8, 0, 0)
				:SetText(L["WoW UI"])
				:SetShown(self._state:Publisher([[addedSwitchButton and not hideSwitchButton]]))
				:SetDisabled(self._state:Publisher("disableSwitchButton"))
				:SetAction("OnClick", "ACTION_SWITCH_TO_DEFAULT")
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:BindElement(self._state, "closeBtn")
				:SetAction("OnClick", "ACTION_HIDE")
			)
		)
	end
	self._frame:EnableMouse(true)
	self._frame:SetMovable(true)
	self._frame:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self._childManager:CallbackToProcessAction("ACTION_HANDLE_DRAG_START"))
	self:SetScript("OnDragStop", self._childManager:CallbackToProcessAction("ACTION_HANDLE_DRAG_STOP"))
end

function ApplicationFrame:Release()
	if self._protected then
		tinsert(UISpecialFrames, 1, tostring(self._frame))
	end
	self._contextTable = nil
	self._defaultContextTable = nil
	self:_StopResizing()
	self._protected = nil
	self._minWidth = 0
	self._minHeight = 0
	self.__super:Release()
end

---Adds player gold text to the title frame.
---@return self
function ApplicationFrame:AddPlayerGold()
	self._state.addedPlayerGold = true
	return self
end

---Adds the app status icon to the title frame.
---@return self
function ApplicationFrame:AddAppStatusIcon()
	self._state.addedAppStatus = true
	return self
end

---Adds a switch button to the title frame.
---@return self
function ApplicationFrame:AddSwitchButton()
	self._state.addedSwitchButton = true
	return self
end

---Set the shown state of the switch button.
---@param value boolean|ReactivePublisherSchemaBase The shown state or a publisher
---@return self
function ApplicationFrame:SetSwitchShown(value)
	assert(self._state.addedSwitchButton)
	if type(value) == "boolean" then
		self._state.hideSwitchButton = not value
	else
		self:_MethodPublisher(value, "SetSwitchShown")
	end
	return self
end

---Set the disabled state of the switch button.
---@param value boolean|ReactivePublisherSchemaBase The disabled state or a publisher
---@return self
function ApplicationFrame:SetSwitchDisabled(value)
	assert(self._state.addedSwitchButton)
	if type(value) == "boolean" then
		self._state.disableSwitchButton = value
	else
		self:_MethodPublisher(value, "SetSwitchDisabled")
	end
	return self
end

---Set the disabled state of the close button.
---@param value boolean|ReactivePublisherSchemaBase The disabled state or a publisher
---@return self
function ApplicationFrame:SetCloseDisabled(value)
	if type(value) == "boolean" then
		self._state.closeBtn:SetDisabled(value)
	else
		self:_MethodPublisher(value, "SetCloseDisabled")
	end
	return self
end

---Overrides the close button action.
---@param action string The action for the OnClick script of the close button
---@param manager UIManager The UI manager
---@return self
function ApplicationFrame:OverrideCloseAction(action, manager)
	self._state.closeBtn:OverrideAction("OnClick", action)
		:SetManager(manager)
	return self
end

---Sets whether or not the frame is protected (doesn't close with ESC).
---@param value boolean|ReactivePublisherSchemaBase The protected state or a publisher
---@return self
function ApplicationFrame:SetProtected(value)
	if type(value) == "boolean" then
		self._protected = value
		local globalFrameName = tostring(self._frame)
		if value then
			Table.RemoveByValue(UISpecialFrames, globalFrameName)
		else
			if not Table.KeyByValue(UISpecialFrames, globalFrameName) then
				-- Insert our frames before other addons (i.e. Skillet) to avoid conflicts
				tinsert(UISpecialFrames, 1, globalFrameName)
			end
		end
	else
		self:_MethodPublisher(value, "SetProtected")
	end
	return self
end

---Sets the title text.
---@param value string|ReactivePublisherSchemaBase The title text or a publisher
---@return self
function ApplicationFrame:SetTitle(value)
	if type(value) == "string" then
		self._state.title = value
		self:DrawTitleFrame()
	else
		self:_MethodPublisher(value, "SetTitle")
	end
	return self
end

---Draws the title frame.
---@return self
function ApplicationFrame:DrawTitleFrame()
	self._state.titleFrame:Draw()
	return self
end

---Sets the content frame.
---@param frame BaseFrame The frame's content frame
---@return self
function ApplicationFrame:SetContentFrame(frame)
	assert(UIElements.IsType(frame, "BaseFrame"))
	self:AddChildNoLayout(frame
		:WipeAnchors()
		:AddAnchor("TOPLEFT", CONTENT_FRAME_OFFSET, -HEADER_HEIGHT)
		:AddAnchor("BOTTOMRIGHT", -CONTENT_FRAME_OFFSET, CONTENT_FRAME_OFFSET)
		:BindElement(self._state, "contentFrame")
	)
	return self
end

---Sets the context table which is used to persist position and size info.
---@param tbl table The context table
---@param defaultTbl ApplicationFrameContextTable Default values
---@return self
function ApplicationFrame:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.width > 0 and defaultTbl.height > 0)
	assert(defaultTbl.centerX and defaultTbl.centerY) ---@diagnostic disable-line: redundant-and
	tbl.width = tbl.width or defaultTbl.width
	tbl.height = tbl.height or defaultTbl.height
	tbl.centerX = tbl.centerX or defaultTbl.centerX
	tbl.centerY = tbl.centerY or defaultTbl.centerY
	tbl.scale = tbl.scale or defaultTbl.scale
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	return self
end

---Sets the context table from a settings object.
---@param settings SettingsView The settings object
---@param key string The setting key
---@return self
function ApplicationFrame:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

---Sets the minimum size the application frame can be resized to.
---@param minWidth number The minimum width
---@param minHeight number The minimum height
---@return self
function ApplicationFrame:SetMinResize(minWidth, minHeight)
	self._minWidth = minWidth
	self._minHeight = minHeight
	return self
end

---Shows a dialog frame.
---@param frame Element The element to show in a dialog
---@param context? any The context to set on the dialog frame
function ApplicationFrame:ShowDialogFrame(frame, context)
	local dialogFrame = UIElements.New("BaseFrame", "_dialog_"..random(1, 1000000))
		:SetRelativeLevel(DIALOG_RELATIVE_LEVEL * (#self._dialogStack + 1))
		:SetBackgroundColor("scrim/main")
		:AddAnchor("TOPLEFT", self._frame)
		:AddAnchor("BOTTOMRIGHT", self._frame)
		:SetMouseEnabled(true)
		:SetMouseWheelEnabled(true)
		:SetContext(context)
		:SetScript("OnMouseWheel", NoOp)
		:SetScript("OnMouseUp", private.DialogOnMouseUp)
		:SetScript("OnHide", self:__closure("_HandleDialogHide"))
		:AddChildNoLayout(frame)
	tinsert(self._dialogStack, dialogFrame)
	self._state.contentFrame:AddChildNoLayout(dialogFrame)
	dialogFrame:Show()
	dialogFrame:Draw()
end

---Show a confirmation dialog.
---@param title string The title of the dialog
---@param subTitle string The sub-title of the dialog
---@param callback function The callback for when the dialog is closed
---@param ... any Arguments to pass to the callback
function ApplicationFrame:ShowConfirmationDialog(title, subTitle, callback, ...)
	local context = TempTable.Acquire(...)
	context.callback = callback
	local frame = UIElements.New("BaseFrame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(328, 158)
		:SetPadding(12, 12, 8, 12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:SetMouseEnabled(true)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:AddChild(UIElements.New("Text", "title")
				:SetHeight(20)
				:SetMargin(32, 8, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("CENTER")
				:SetText(title)
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		:AddChild(UIElements.New("Text", "desc")
			:SetMargin(0, 0, 16, 16)
			:SetFont("BODY_XSMALL")
			:SetJustifyH("LEFT")
			:SetJustifyV("TOP")
			:SetText(subTitle)
		)
		:AddChild(UIElements.New("MediumPrimaryActionButton", "confirmBtn")
			:SetText(L["Confirm"])
			:SetAction("OnClick", "ACTION_DIALOG_CONFIRMED")
		)
	self:ShowDialogFrame(frame, context)
end

---Hides the current dialog.
function ApplicationFrame:HideDialog()
	local dialogFrame = self._dialogStack[#self._dialogStack]
	if not dialogFrame then
		return
	end
	local parent = dialogFrame:GetParentElement()
	assert(parent)
	---@cast parent Container
	parent:RemoveChild(dialogFrame)
end

function ApplicationFrame:Draw()
	self._frame:SetToplevel(true)
	self._frame:Raise()

	-- update the size if it's less than the set min size
	assert(self._minWidth > 0 and self._minHeight > 0)
	self._contextTable.width = max(self._contextTable.width, self._minWidth)
	self._contextTable.height = max(self._contextTable.height, self._minHeight)
	self._contextTable.scale = max(self._contextTable.scale, MIN_SCALE)

	-- set the frame size from the contextTable
	self:SetScale(self._contextTable.scale)
	self:SetSize(self._contextTable.width, self._contextTable.height)

	-- make sure at least 50px of the frame is on the screen and offset by at least 1 scaled pixel to fix some rendering issues
	local maxAbsCenterX = (UIParent:GetWidth() / self._contextTable.scale + self._contextTable.width) / 2 - MIN_ON_SCREEN_PX
	local maxAbsCenterY = (UIParent:GetHeight() / self._contextTable.scale + self._contextTable.height) / 2 - MIN_ON_SCREEN_PX
	local effectiveScale = UIParent:GetEffectiveScale()
	if self._contextTable.centerX < 0 then
		self._contextTable.centerX = min(max(self._contextTable.centerX, -maxAbsCenterX), -effectiveScale)
	else
		self._contextTable.centerX = max(min(self._contextTable.centerX, maxAbsCenterX), effectiveScale)
	end
	if self._contextTable.centerY < 0 then
		self._contextTable.centerY = min(max(self._contextTable.centerY, -maxAbsCenterY), -effectiveScale)
	else
		self._contextTable.centerY = max(min(self._contextTable.centerY, maxAbsCenterY), effectiveScale)
	end

	-- set the frame position from the contextTable
	self:WipeAnchors()
	self:AddAnchor("CENTER", self._contextTable.centerX, self._contextTable.centerY)

	self.__super:Draw()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<ApplicationFrameState>
---@param state ApplicationFrameState
function ApplicationFrame.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HIDE" then
		self:Hide()
	elseif action == "ACTION_HANDLE_RESIZE_MOUSE_DOWN" then
		local _, mouseButton = ...
		if mouseButton ~= "LeftButton" then
			return
		end
		self:_StartResizing()
	elseif action == "ACTION_HANDLE_RESIZE_MOUSE_UP" then
		local _, mouseButton = ...
		if mouseButton ~= "LeftButton" then
			return
		end
		self:_StopResizing()
	elseif action == "ACTION_HANDLE_RESIZE_CLICK" then
		local _, mouseButton = ...
		if mouseButton ~= "RightButton" then
			return
		end
		self._contextTable.scale = self._defaultContextTable.scale
		self._contextTable.width = self._defaultContextTable.width
		self._contextTable.height = self._defaultContextTable.height
		self._contextTable.centerX = self._defaultContextTable.centerX
		self._contextTable.centerY = self._defaultContextTable.centerY
		self:Draw()
	elseif action == "ACTION_HANDLE_DRAG_START" then
		self._frame:StartMoving()
	elseif action == "ACTION_HANDLE_DRAG_STOP" then
		self._frame:StopMovingOrSizing()
		self:_SavePosition()
		self:Draw()
	elseif action == "ACTION_CLOSE_DIALOG" then
		self:HideDialog()
	elseif action == "ACTION_DIALOG_CONFIRMED" then
		local dialogFrame = self._dialogStack[#self._dialogStack]
		local context = dialogFrame:GetContext()
		dialogFrame:SetContext(nil)
		self:HideDialog()
		context.callback(TempTable.UnpackAndRelease(context))
	elseif action == "ACTION_SWITCH_TO_DEFAULT" then
		self:_SendActionScript("OnSwitchButtonClick")
	else
		error("Unknown action: "..tostring(action))
	end
end

function ApplicationFrame.__private:_SavePosition()
	local frame = self._frame
	local parentFrame = frame:GetParent()
	local width = frame:GetWidth()
	local height = frame:GetHeight()
	-- the anchor is in our frame's scale, so convert the parent measurements to our scale
	local frameLeftOffset = frame:GetLeft() - parentFrame:GetLeft() / self._contextTable.scale
	self._contextTable.centerX = (frameLeftOffset - (parentFrame:GetWidth() / self._contextTable.scale - width) / 2)
	local frameBottomOffset = frame:GetBottom() - parentFrame:GetBottom() / self._contextTable.scale
	self._contextTable.centerY = (frameBottomOffset - (parentFrame:GetHeight() / self._contextTable.scale - height) / 2)
end

function ApplicationFrame.__private:_StartResizing()
	local frame = self._frame
	local scale = self._contextTable.scale
	local cursorX, cursorY = private.GetCursorPositionInParent()
	self._resizeLeft = frame:GetLeft() * scale
	self._resizeTop = frame:GetTop() * scale
	self._resizeOffsetX = frame:GetRight() * scale - cursorX
	self._resizeOffsetY = frame:GetBottom() * scale - cursorY
	frame.resizeBtn:TSMSetOnUpdate(self:__closure("_HandleResizeUpdate"))
end

function ApplicationFrame.__private:_StopResizing()
	self._frame.resizeBtn:TSMSetOnUpdate(nil)
end

function ApplicationFrame.__private:_HandleResizeUpdate()
	if not IsMouseButtonDown("LeftButton") then
		self:_StopResizing()
		return
	end
	local context = self._contextTable
	local cursorX, cursorY = private.GetCursorPositionInParent()
	local parentWidth = UIParent:GetWidth()
	local parentHeight = UIParent:GetHeight()
	local spanX = cursorX + self._resizeOffsetX - self._resizeLeft
	local spanY = self._resizeTop - (cursorY + self._resizeOffsetY)
	local scale, width, height = context.scale, context.width, context.height
	if IsShiftKeyDown() then
		scale = Math.Round(max(min((spanX / width + spanY / height) / 2, parentWidth / width, parentHeight / height), MIN_SCALE), 0.001)
	else
		width = Math.Round(max(min(spanX, parentWidth) / scale, self._minWidth))
		height = Math.Round(max(min(spanY, parentHeight) / scale, self._minHeight))
	end
	if scale == context.scale and width == context.width and height == context.height then
		return
	end
	context.scale = scale
	context.width = width
	context.height = height
	context.centerX = (self._resizeLeft - parentWidth / 2) / scale + width / 2
	context.centerY = (self._resizeTop - parentHeight / 2) / scale - height / 2
	self:Draw()
end

function ApplicationFrame.__private:_HandleDialogHide()
	local dialog = tremove(self._dialogStack)
	assert(dialog)
	local context = dialog:GetContext()
	if context then
		TempTable.Release(context)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ResizeOnEnter(btn)
	local text = strjoin("\n",
		L["Click and drag to resize this window."],
		L["Hold SHIFT while dragging to scale the window instead."],
		L["Right-Click to reset the window size, scale, and position to their defaults."]
	)
	TooltipUI.Show(btn, text, true)
end

function private.ResizeOnLeave()
	TooltipUI.Hide()
end

function private.GetCursorPositionInParent()
	local cursorX, cursorY = GetCursorPosition()
	local effectiveScale = UIParent:GetEffectiveScale()
	return cursorX / effectiveScale, cursorY / effectiveScale
end

function private.DialogOnMouseUp(dialog)
	dialog:GetParentElement():GetParentElement():HideDialog()
end

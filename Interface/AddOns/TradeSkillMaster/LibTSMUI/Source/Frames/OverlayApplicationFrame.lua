-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TITLE_HEIGHT = 40
local CONTENT_PADDING_BOTTOM = 16

---@class OverlayApplicationFrameContextTable
---@field minimized boolean
---@field topRightX number
---@field topRightY number



-- ============================================================================
-- Element Definition
-- ============================================================================

local OverlayApplicationFrame = ComponentRegistry.Define("OverlayApplicationFrame", "BaseFrame")
OverlayApplicationFrame._STATE_SCHEMA = OverlayApplicationFrame._STATE_SCHEMA:Extend("OverlayApplicationFrameState")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddStringField("title", "")
	:AddBooleanField("minimized", false)
	:AddBooleanField("backgroundLocked", false)
	:AddBooleanField("mouseOver", false)
	:Commit()
OverlayApplicationFrame:_AddActionScripts("OnClose")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OverlayApplicationFrame:__init()
	self.__super:__init()
	self._contextTable = nil ---@type OverlayApplicationFrameContextTable!
	self._defaultContextTable = nil ---@type OverlayApplicationFrameContextTable!
	Theme.RegisterChangeCallback(function()
		if self:IsVisible() then
			self:Draw()
		end
	end)
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))

	-- Publisher to set background / border color
	self._state:Publisher([[mouseOver or backgroundLocked]])
		:Share()
		:ReplaceBooleanWith("container/medium%50", nil)
		:CallMethod(self, "SetRoundedBackgroundColor")
		:ReplaceBooleanWith("outline/variant%50", nil)
		:AssignToTableKey(self._state, "borderColor")
		:EndShare()
end

function OverlayApplicationFrame:Acquire()
	self.__super:Acquire()
	self:SetParent(UIParent)
	self:SetStrata("HIGH")
	self._frame:EnableMouse(true)
	self._frame:SetMovable(true)
	self._frame:RegisterForDrag("LeftButton")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChildNoLayout(UIElements.New("BaseButton", "closeBtn")
			:SetManager(self._childManager)
			:AddAnchor("TOPRIGHT", -8, -11)
			:SetBackgroundAndSize("iconPack.18x18/Close/Circle")
			:SetAction("OnClick", "ACTION_CLOSE")
		)
		self:AddChildNoLayout(UIElements.New("BaseButton", "minimizeBtn")
			:AddAnchor("TOPRIGHT", -26, -11)
			:SetManager(self._childManager)
			:SetBackgroundAndSize(self._state:Publisher("minimized"):ReplaceBooleanWith("iconPack.18x18/Add/Circle", "iconPack.18x18/Subtract/Circle"))
			:SetAction("OnClick", "ACTION_TOGGLE_MINIMIZE")
		)
		self:AddChildNoLayout(UIElements.New("Text", "title")
			:SetHeight(24)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:AddAnchor("TOPLEFT", 8, -8)
			:AddAnchor("TOPRIGHT", -52, -8)
			:SetText(self._state:Publisher("title"))
		)
	end

	self:SetScript("OnDragStart", self:__closure("_HandleDragStart"))
	self:SetScript("OnDragStop", self:__closure("_HandleDragStop"))
	self:SetScript("OnEnter", self:__closure("_UpdateMouseOver"))
	self:SetScript("OnLeave", self:__closure("_UpdateMouseOver"))
end

function OverlayApplicationFrame:Release()
	self._contextTable = nil
	self._defaultContextTable = nil
	self._frame:SetResizeBounds(0, 0)
	self.__super:Release()
end

---Sets the title text.
---@param title string The title text
---@return self
function OverlayApplicationFrame:SetTitle(title)
	self._state.title = title
	return self
end

---Sets the content frame.
---@param frame BaseFrame The content frame
---@return self
function OverlayApplicationFrame:SetContentFrame(frame)
	self:AddChildNoLayout(frame
		:WipeAnchors()
		:AddAnchor("TOPLEFT", 0, -TITLE_HEIGHT)
		:AddAnchor("BOTTOMRIGHT", 0, CONTENT_PADDING_BOTTOM)
		:BindElement(self._state, "contentFrame")
	)
	return self
end

---Sets the context table which is used to persist position and size info.
---@param tbl table The context table
---@param defaultTbl OverlayApplicationFrameContextTable Default values
---@return self
function OverlayApplicationFrame:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.minimized ~= nil and defaultTbl.topRightX and defaultTbl.topRightY)
	if tbl.minimized == nil then
		tbl.minimized = defaultTbl.minimized
	end
	self._state.minimized = tbl.minimized
	self._state:Publisher("minimized")
		:AssignToTableKey(tbl, "minimized")
	tbl.topRightX = tbl.topRightX or defaultTbl.topRightX
	tbl.topRightY = tbl.topRightY or defaultTbl.topRightY
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	return self
end

---Sets the context table from a settings object.
---@param settings SettingsView The settings object
---@param key string The setting key
---@return self
function OverlayApplicationFrame:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

---Set whether or not the background is locked.
---@param value boolean|ReactivePublisherSchemaBase The locked state or a publisher
---@return self
function OverlayApplicationFrame:SetBackgroundLocked(value)
	if type(value) == "boolean" then
		self._state.backgroundLocked = value
	else
		self:_MethodPublisher(value, "SetBackgroundLocked")
	end
	return self
end

function OverlayApplicationFrame:Draw()
	if self._state.minimized then
		self._state.contentFrame:Hide()
		self:SetHeight(TITLE_HEIGHT)
	else
		self._state.contentFrame:Show()
		-- Set the height of the frame based on the height of the children
		local contentHeight, contentHeightExpandable = self._state.contentFrame:_GetMinimumDimension("HEIGHT")
		assert(not contentHeightExpandable)
		self:SetHeight(contentHeight + TITLE_HEIGHT + CONTENT_PADDING_BOTTOM)
	end

	-- Make sure the frame is on the screen
	self._contextTable.topRightX = max(min(self._contextTable.topRightX, 0), -UIParent:GetWidth() + 100)
	self._contextTable.topRightY = max(min(self._contextTable.topRightY, 0), -UIParent:GetHeight() + 100)

	-- Set the frame position from the contextTable
	self:WipeAnchors()
	self:AddAnchor("TOPRIGHT", self._contextTable.topRightX, self._contextTable.topRightY)

	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OverlayApplicationFrame.__private:_SavePosition()
	local parentFrame = self._frame:GetParent()
	self._contextTable.topRightX = self._frame:GetRight() - parentFrame:GetRight()
	self._contextTable.topRightY = self._frame:GetTop() - parentFrame:GetTop()
end

function OverlayApplicationFrame.__private:_HandleDragStart()
	self._frame:StartMoving()
end

function OverlayApplicationFrame.__private:_HandleDragStop()
	self._frame:StopMovingOrSizing()
	self:_SavePosition()
end

function OverlayApplicationFrame.__private:_UpdateMouseOver()
	self._state.mouseOver = self._frame:IsMouseOver()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param manager UIManager<OverlayApplicationFrameState>
---@param state OverlayApplicationFrameState
function OverlayApplicationFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE" then
		self:_SendActionScript("OnClose")
		self:Hide()
	elseif action == "ACTION_TOGGLE_MINIMIZE" then
		state.minimized = not state.minimized
		self:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

	-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	shownDialogs = {} ---@type table<PopupDialog,number>
}
local TOP_DIALOG_OFFSET = -250
local STACK_SPACING = 32
local FRAME_PADDING = 12
local BUTTON_HEIGHT = 24
local BUTTON_TOP_MARGIN = 16



-- ============================================================================
-- Element Definition
-- ============================================================================

local PopupDialog = ComponentRegistry.Define("PopupDialog", "BaseFrame")
PopupDialog._STATE_SCHEMA = PopupDialog._STATE_SCHEMA:Extend("PopupDialogState")
	:AddDeferredUIElementField("text", "Text")
	:AddDeferredUIElementField("buttonsFrame", "BaseFrame")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PopupDialog:__init()
	self.__super:__init()
	if LibTSMUI.IsRetail() or LibTSMUI.IsForever() then
		self._frame:SetRoundLayoutToNearestPixel(true)
	end
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function PopupDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetStrata("TOOLTIP")
	self:SetParent(UIParent)
	self:SetWidth(400)
	self:SetPadding(FRAME_PADDING)
	self:SetBackgroundColor("container/low")
	self:SetBorderColor("outline/variant", 4)
	self:AddChild(UIElements.New("Text", "text")
		:SetFont("BODY_SMALL_SEMIBOLD")
		:SetJustifyV("TOP")
		:SetJustifyH("CENTER")
		:BindElement(self._state, "text")
	)
	self:AddChild(UIElements.New("BaseFrame", "buttons")
		:SetLayout("HORIZONTAL")
		:SetHeight(BUTTON_HEIGHT)
		:SetMargin(0, 0, BUTTON_TOP_MARGIN, 0)
		:BindElement(self._state, "buttonsFrame")
		:SetManager(self._childManager)
	)
	local offset = TOP_DIALOG_OFFSET
	for _, height in pairs(private.shownDialogs) do
		offset = offset - height - STACK_SPACING
	end
	self:AddAnchor("TOP", 0, offset)
end

function PopupDialog:Release()
	private.shownDialogs[self] = nil
	local globalFrameName = tostring(self._frame)
	Table.RemoveByValue(UISpecialFrames, globalFrameName)
	_G[globalFrameName] = nil
	self.__super:Release()
end

---Sets the message.
---@param message string The message
---@return self
function PopupDialog:SetMessage(message)
	-- Get the height of the text to fully fit the message
	self:SetHeight(1000)
	self:Draw()
	local stringHeight = self._state.text
		:SetText(message)
		:GetStringHeight()
	-- Set the new height to fit the message
	self:SetHeight(FRAME_PADDING * 2 + BUTTON_HEIGHT + BUTTON_TOP_MARGIN + stringHeight)
	self:Draw()
	return self
end

---Sets the dialog to be hidden by the escape key.
---@return self
function PopupDialog:HideOnEscape()
	local frame = self._frame
	local globalFrameName = tostring(frame)
	_G[globalFrameName] = frame
	tinsert(UISpecialFrames, globalFrameName)
	return self
end

function PopupDialog:Draw()
	self.__super:Draw()
	private.shownDialogs[self] = self._state.height
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<PopupDialogState>
---@param state PopupDialogState
function PopupDialog.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE" then
		self:Hide()
		self:Release()
	else
		error("Unknown action: "..tostring(action))
	end
end

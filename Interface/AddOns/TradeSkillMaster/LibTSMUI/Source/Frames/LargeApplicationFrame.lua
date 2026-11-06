-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local NAV_BAR_SPACING = 16
local NAV_BAR_HEIGHT = 24
local NAV_BAR_TOP_OFFSET = -8



-- ============================================================================
-- Element Definition
-- ============================================================================

local LargeApplicationFrame = ComponentRegistry.Define("LargeApplicationFrame", "ApplicationFrame")
LargeApplicationFrame._STATE_SCHEMA = LargeApplicationFrame._STATE_SCHEMA:Extend("LargeApplicationFrameState")
	:AddOptionalNumberField("pulsingButtonIndex")
	:AddDeferredNumberField("selectedButtonIndex")
	:AddOptionalNumberField("mouseOverButtonIndex")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function LargeApplicationFrame:__init()
	self.__super:__init()
	self._buttons = {} ---@type FlashingNavButton[]
	self._buttonText = {}
end

function LargeApplicationFrame:Acquire()
	self:SetContentFrame(UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
	)
	self.__super:Acquire()
end

function LargeApplicationFrame:Release()
	wipe(self._buttons)
	wipe(self._buttonText)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the context table which is used to persist position and size info.
---@param tbl table The context table
---@param defaultTbl table Default values (required attributes: `width`, `height`, `centerX`, `centerY`, `page`)
---@return self
function LargeApplicationFrame:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.page)
	self._state:Publisher("selectedButtonIndex")
		:IgnoreNil()
		:AssignToTableKey(tbl, "page")
	self._state.selectedButtonIndex = tbl.page or defaultTbl.page
	self.__super:SetContextTable(tbl, defaultTbl)
	return self
end

---Adds a top-level navigation button.
---@param text string The button text
---@param drawCallback fun(frame: LargeApplicationFrame): Element The function called when the button is clicked to get the corresponding content
---@return self
function LargeApplicationFrame:AddNavButton(text, drawCallback)
	local index = #self._buttons + 1
	local button = nil
	for _ in self._state:WithAutoStorePaused() do
		button = UIElements.New("FlashingNavButton", "NavBar_"..text)
			:SetManager(self._childManager)
			:SetContext(drawCallback)
			:SetText(text)
			:SetPlaying(self._state:Publisher("pulsingButtonIndex"):ToBooleanEquals(index))
			:SetSelected(self._state:Publisher("selectedButtonIndex"):ToBooleanEquals(index))
			:SetAction("OnClick", "ACTION_HANDLE_NAV_CLICK")
	end
	self:AddChildNoLayout(button)
	tinsert(self._buttons, button)

	self._buttonText[index] = text
	self._buttonText[text] = index
	if self._buttonText[text] == self._state.selectedButtonIndex then
		self._state.contentFrame:ReleaseAllChildren()
		self._state.contentFrame:AddChild(drawCallback(self))
	end

	return self
end

---Set the selected nav button.
---@param buttonText string The button text
---@param redraw? boolean Whether or not to redraw the frame
---@return self
function LargeApplicationFrame:SetSelectedNavButton(buttonText, redraw)
	local index = self._buttonText[buttonText]
	if index == self._state.selectedButtonIndex then
		return self
	end
	self._state.selectedButtonIndex = index
	self._state.contentFrame:ReleaseAllChildren()
	self._state.contentFrame:AddChild(self._buttons[index]:GetContext()(self))
	if redraw then
		self:Draw()
	end
	return self
end

---Get the selected nav button.
---@return string
function LargeApplicationFrame:GetSelectedNavButton()
	return self._buttonText[self._state.selectedButtonIndex]
end

---Sets which nav button is pulsing.
---@param buttonText? string The button text or nil if no nav button should be pulsing
function LargeApplicationFrame:SetPulsingNavButton(buttonText)
	self._state.pulsingButtonIndex = buttonText and self._buttonText[buttonText] or nil
end

---Removes the border from the content frame.
---@return self
function LargeApplicationFrame:RemoveContentBorder()
	self._state.contentFrame
		:SetPadding(0)
		:SetBorderColor(nil)
	return self
end

function LargeApplicationFrame:Draw()
	self.__super:Draw()
	for _, button in ipairs(self._buttons) do
		button:Draw()
		button:SetSize(button:GetStringWidth(), NAV_BAR_HEIGHT)
	end

	local offsetX = 104
	for _, button in ipairs(self._buttons) do
		local buttonWidth = button:GetStringWidth()
		button:SetSize(buttonWidth, NAV_BAR_HEIGHT)
		button:WipeAnchors()
		button:AddAnchor("TOPLEFT", offsetX, NAV_BAR_TOP_OFFSET)
		offsetX = offsetX + buttonWidth + NAV_BAR_SPACING
		-- Draw the buttons again now that we know their dimensions
		button:Draw()
	end
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<LargeApplicationFrameState>
---@param state LargeApplicationFrameState
function LargeApplicationFrame.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_NAV_CLICK" then
		local buttonText = ...
		self:SetSelectedNavButton(buttonText, true)
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

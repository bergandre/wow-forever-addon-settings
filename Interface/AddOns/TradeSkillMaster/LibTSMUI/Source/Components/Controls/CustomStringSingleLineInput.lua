-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Errors = LibTSMUI:Include("Util.Errors")
local CustomString = LibTSMUI:From("LibTSMTypes"):Include("CustomString")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local private = {}
local POPOUT_ICON = "iconPack.12x12/Popout"
local PADDING_LEFT = 8
local PADDING_RIGHT = 20
local PADDING_TOP_BOTTOM = 4
local COPPER_PER_SILVER = 100



-- ============================================================================
-- Element Definition
-- ============================================================================

local CustomStringSingleLineInput = ComponentRegistry.Define("CustomStringSingleLineInput", "BaseInput")
CustomStringSingleLineInput._STATE_SCHEMA = CustomStringSingleLineInput._STATE_SCHEMA:Extend("CustomStringSingleLineInputState")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CustomStringSingleLineInput:__init()
	local frame = self:_CreateEditBox()
	self.__super:__init(frame, frame)
	frame:SetTextInsets(PADDING_LEFT, PADDING_RIGHT, PADDING_TOP_BOTTOM, PADDING_TOP_BOTTOM)

	self._popoutIcon = self:_CreateTexture(frame, "ARTWORK")
	self._popoutIcon:SetPoint("RIGHT", -4, 0)
	self._popoutIcon:TSMSetSize(POPOUT_ICON)
	self._popoutIcon:TSMSetTexture(self._state:PublisherForFunctionWithKeys(private.DisabledToPopoutIcon, "disabled"))

	self._popoutButton = self:_CreateButton()
	self._popoutButton:SetAllPoints(self._popoutIcon)
	self._popoutButton:TSMSetScript("OnClick", self:__closure("_ShowPopout"))
	self._popoutButton:TSMSetPropagate("OnEnter")
	self._popoutButton:TSMSetPropagate("OnLeave")
	self._popoutButton:SetHitRectInsets(-2, -2, -2, -2)

	self._isNumber = false
	self._isUndercut = false
	self._badSources = nil
	self._popoutTitle = nil
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function CustomStringSingleLineInput:Release()
	self._isNumber = false
	self._isUndercut = false
	self._badSources = nil
	self._popoutTitle = nil
	self.__super:Release()
end

---Sets whether or not the result of the custom string is a number rather than a price.
---@param isNumber boolean Whether or not the result is a number
---@return self
function CustomStringSingleLineInput:SetIsNumber(isNumber)
	self._isNumber = isNumber
	assert(self._settingTable and self._settingKey)
	local value = self._settingTable[self._settingKey]
	if not isNumber then
		local copperValue = tonumber(value)
		value = copperValue and Money.ToStringExact(copperValue) or value
	end
	self:SetValue(value)
	return self
end

---Sets whether or not the custom string is an undercut value which has additional validation (for retail).
---@param isUndercut boolean Whether the custom string is an undercut
---@return self
function CustomStringSingleLineInput:SetIsUndercut(isUndercut)
	self._isUndercut = isUndercut
	return self
end

---Sets the bad sources which can't be used in the custom string.
---@param badSources? table<string,any> The bad sources as keys
---@return self
function CustomStringSingleLineInput:SetBadSources(badSources)
	self._badSources = badSources
	return self
end

---Sets the popout dialog title.
---@param title string The popout dialog title
---@return self
function CustomStringSingleLineInput:SetPopoutTitle(title)
	self._popoutTitle = title
	return self
end

---Sets the tooltip based on a valid number range.
---@param tooltip string The tooltip
---@param range Range The valid range
---@param anchorToParent? boolean Anchor the tooltip the parent element instead
---@return self
function CustomStringSingleLineInput:SetRangeTooltip(tooltip, range, anchorToParent)
	return self:SetTooltip(strjoin(" ", tooltip, format(L["This value must be between %d to %d (inclusive)."], range:GetValues())), anchorToParent)
end

---@deprecated
function CustomStringSingleLineInput:SetValidateFunc()
	error("Cannot be called on CustomStringSingleLineInput", 2)
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function CustomStringSingleLineInput.__protected:_ValidateValue(value)
	value = strtrim(value)

	if self._isUndercut and not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() then
		local copperValue = tonumber(value)
		copperValue = Money.FromString(copperValue and Money.ToStringExact(copperValue) or value)
		if copperValue == 0 then
			return true
		elseif (copperValue or math.huge) < COPPER_PER_SILVER then
			return false, L["Invalid undercut. To post below the cheapest auction without a significant undercut, set your undercut to 0c."]
		end
	end

	local isValid, errType, errTokenStr = CustomString.Validate(value)
	if not isValid then
		assert(errType)
		return false, L["Invalid custom price."].." "..Errors.FormatCustomString(errType, errTokenStr)
	end

	local badSourceErr = self._badSources and Errors.CheckCustomStringDependencies(value, self._badSources) or nil
	if badSourceErr then
		return false, L["Invalid custom price."].." "..badSourceErr
	end

	return true
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<CustomStringSingleLineInputState>
---@param state CustomStringSingleLineInputState
function CustomStringSingleLineInput.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_DONE_EDITING" then
		local value = ...
		if not self._isNumber then
			local copperValue = tonumber(value)
			value = copperValue and Money.ToStringExact(copperValue) or value
		end
		self:SetValue(value)
		assert(self._escValue)
	else
		error("Unknown action: "..tostring(action))
	end
end

function CustomStringSingleLineInput.__private:_ShowPopout()
	assert(self._popoutTitle)
	self:GetBaseElement():ShowDialogFrame(UIElements.New("CustomStringDialog", "dialog")
		:Configure(self._popoutTitle, self:GetValue(), self:__closure("_ValidateValue"))
		:SetManager(self._childManager)
		:SetAction("OnDoneEditing", "ACTION_HANDLE_DONE_EDITING")
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DisabledToPopoutIcon(disabled)
	return TextureAtlas.GetColoredKey(POPOUT_ICON, disabled and "on/surface%40" or "on/surface")
end

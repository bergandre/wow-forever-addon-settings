-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local ICON_PADDING_LEFT_RIGHT = 8



-- ============================================================================
-- Element Definition
-- ============================================================================

local NumberInput = ComponentRegistry.Define("NumberInput", "BaseInput")
NumberInput._STATE_SCHEMA = NumberInput._STATE_SCHEMA:Extend("NumberInputState")
	:UpdateFieldDefault("value", "0")
	:AddNumberField("numValue", 0)
	:AddBooleanField("subAddEnabled", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function NumberInput:__init()
	local frame = self:_CreateEditBox()
	self._frame = frame
	self.__super:__init(frame, frame)

	self._minValue = -math.huge
	self._maxValue = math.huge
	self._roundSig = nil

	local addSubShownPublisher = self._state:Publisher("subAddEnabled")
		:Share()

	self._addIcon = self:_CreateTexture()
	self._addIcon:SetPoint("RIGHT", -ICON_PADDING_LEFT_RIGHT, 0)
	self._addIcon:TSMSetTextureAndSize("iconPack.14x14/Add/Default")
	self._addIcon:TSMSetShown(addSubShownPublisher)

	self._addBtn = self:_CreateButton()
	self._addBtn:SetAllPoints(self._addIcon)
	self._addBtn:TSMSetShown(addSubShownPublisher)
	self._addBtn:TSMSetScript("OnClick", self:__closure("Add"))
	self._addBtn:TSMSetPropagate("OnEnter")
	self._addBtn:TSMSetPropagate("OnLeave")

	self._subIcon = self:_CreateTexture()
	self._subIcon:SetPoint("RIGHT", self._addIcon, "LEFT", -ICON_PADDING_LEFT_RIGHT / 2, 0)
	self._subIcon:TSMSetTextureAndSize("iconPack.14x14/Subtract/Default")
	self._subIcon:TSMSetShown(addSubShownPublisher)

	self._subBtn = self:_CreateButton()
	self._subBtn:SetAllPoints(self._subIcon)
	self._subBtn:TSMSetShown(addSubShownPublisher)
	self._subBtn:TSMSetScript("OnClick", self:__closure("Subtract"))
	self._subBtn:TSMSetPropagate("OnEnter")
	self._subBtn:TSMSetPropagate("OnLeave")

	addSubShownPublisher:EndShare()

	-- Set up some computed state properties
	self._state:PublisherForFunctionWithKeys(tonumber, "value")
		:AssignToTableKey(self._state, "numValue")
end

function NumberInput:Release()
	self._minValue = -math.huge
	self._maxValue = math.huge
	self._roundSig = nil
	self.__super:Release()
end

---Sets whether or not the sub/add buttons are enabled.
---@param enabled boolean Whether or not the sub/add buttons are enabled
---@return self
function NumberInput:SetSubAddEnabled(enabled)
	self._state.subAddEnabled = enabled
	return self
end

---Subtract from the input.
---@return self
function NumberInput:Subtract()
	local value = tostring(max(self._state.numValue - (IsShiftKeyDown() and 10 or 1), self._minValue))
	assert(self:_SetValueHelper(value))
	self._escValue = self._state.value
	self._editBox:SetText(value)
	self._state.displayValue = value
	return self
end

---Add to the input.
---@return self
function NumberInput:Add()
	local value = tostring(min(self._state.numValue + (IsShiftKeyDown() and 10 or 1), self._maxValue))
	assert(self:_SetValueHelper(value))
	self._escValue = self._state.value
	self._editBox:SetText(value)
	self._state.displayValue = value
	return self
end

---Sets the current value.
---@param value number|ReactivePublisherSchemaBase The value or a publisher
---@return self
function NumberInput:SetValue(value)
	assert(type(value) ~= "string")
	self.__super:SetValue(value)
	return self
end

---Gets the input value.
---@return number
function NumberInput:GetValue()
	return self._state.numValue
end

---Sets the valid range for the number value.
---@param minValue number The minimum value
---@param maxValue number The maximum value
---@param roundSig? number The amount to round to
---@return self
function NumberInput:SetValidRange(minValue, maxValue, roundSig)
	assert(minValue <= maxValue)
	self._minValue = minValue
	self._maxValue = maxValue
	self._roundSig = roundSig
	return self
end

---@deprecated
function NumberInput:SetValidateFunc()
	error("Cannot call on NumberInput", 2)
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function NumberInput.__protected:_SetValueHelper(valueStr, noCallback)
	if self:_ValidateValue(valueStr) then
		local value = tonumber(strtrim(valueStr))
		assert(value)
		if self._roundSig then
			value = Math.Round(value, self._roundSig)
		end
		self._state.value = tostring(value)
		if self._settingTable then
			assert(self._settingKey)
			self._settingTable[self._settingKey] = self._state.numValue
		end
		if not noCallback then
			self._bindings:Process("VALUE", self._state.numValue)
			self:_SendActionScript("OnValueChanged")
		end
		self:_SetIsValid(true)
		return true
	else
		if self._state.value == "" then
			self._state.value = strtrim(valueStr)
		end
		self:_SetIsValid(false)
		return false
	end
end

function NumberInput.__protected:_ValidateValue(valueStr)
	local value = tonumber(strtrim(valueStr))
	if not value then
		return false, L["Invalid numeric value."]
	elseif value < self._minValue or value > self._maxValue then
		return false, format(L["Value must be between %d and %d."], self._minValue, self._maxValue)
	end
	return true
end

function NumberInput.__protected:_ShouldKeepFocus()
	if not IsMouseButtonDown("LeftButton") then
		return false
	elseif self._subBtn:IsVisible() and self._subBtn:IsMouseOver() then
		return true
	elseif self._addBtn:IsVisible() and self._addBtn:IsMouseOver() then
		return true
	else
		return false
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local ItemLinked = LibTSMUI:Include("Util.ItemLinked")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {}
local PADDING_LEFT = 8
local PADDING_RIGHT = 8
local PADDING_TOP_BOTTOM = 4
local LEAD_ICON_GAP = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local Input = ComponentRegistry.Define("Input", "BaseInput")
Input._STATE_SCHEMA = Input._STATE_SCHEMA:Extend("InputState")
	:AddOptionalStringField("iconTexture")
	:AddOptionalStringField("leadIconTexture")
	:AddBooleanField("clearEnabled", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Input:__init()
	local frame = self:_CreateEditBox()
	self._frame = frame
	self.__super:__init(frame, frame)

	self._autoComplete = nil
	self._allowItemInsert = nil

	local visibleIconTexturePublisher = self._state:PublisherForFunctionWithKeys(private.StateToIconTexture, "disabled", "displayValue", "clearEnabled", "hasFocus", "iconTexture")
		:Share()
	local leadIconTexturePublisher = self._state:PublisherForFunctionWithKeys(private.StateToLeadIconTexture, "disabled", "leadIconTexture")
		:Share()

	self._leadIcon = self:_CreateTexture()
	self._leadIcon:SetPoint("LEFT", PADDING_LEFT / 2, 0)
	self._leadIcon:TSMSetShown(leadIconTexturePublisher:ToBooleanNotEquals(nil):IgnoreDuplicates())
	self._leadIcon:TSMSetTextureAndSize(leadIconTexturePublisher:IgnoreNil())

	self._icon = self:_CreateTexture()
	self._icon:SetPoint("RIGHT", -PADDING_RIGHT / 2, 0)
	self._icon:TSMSetShown(visibleIconTexturePublisher:ToBooleanNotEquals(nil):IgnoreDuplicates())
	self._icon:TSMSetTextureAndSize(visibleIconTexturePublisher:IgnoreNil())

	self._clearBtn = self:_CreateButton()
	self._clearBtn:SetAllPoints(self._icon)
	self._clearBtn:TSMSetShown(self._state:Publisher([[clearEnabled and displayValue ~= ""]]))
	self._clearBtn:TSMSetDisabled(self._state:Publisher("disabled"))
	self._clearBtn:TSMSetScript("OnClick", self:__closure("_ClearBtnOnClick"))

	visibleIconTexturePublisher:CallFunction(self:__closure("_HandleIconChanged"))
	visibleIconTexturePublisher:EndShare()
	leadIconTexturePublisher:CallFunction(self:__closure("_HandleIconChanged"))
	leadIconTexturePublisher:EndShare()

	local function ItemLinkedCallback(name, link)
		if self._allowItemInsert == nil or not self:IsVisible() or not self._state.hasFocus then
			return
		end
		if self._allowItemInsert == true then
			self._editBox:Insert(link)
		else
			self._editBox:Insert(name)
		end
		return true
	end
	ItemLinked.RegisterCallback(ItemLinkedCallback)
end

function Input:Release()
	self._autoComplete = nil
	self._allowItemInsert = nil
	self.__super:Release()
end

---Sets the auto complete table.
---@param tbl table A list of strings to auto-complete to
---@return self
function Input:SetAutoComplete(tbl)
	assert(type(tbl) == "table")
	self._autoComplete = tbl
	return self
end

---Sets whether or not the clear button is enabled.
---@param enabled boolean Whether or not the clear button is enabled
---@return self
function Input:SetClearButtonEnabled(enabled)
	assert(type(enabled) == "boolean")
	self._state.clearEnabled = enabled
	return self
end

---Sets the trail icon texture.
---@param iconTexture? string The texture string to use for the icon texture
---@return self
function Input:SetIconTexture(iconTexture)
	assert(iconTexture == nil or TextureAtlas.IsValid(iconTexture))
	self._state.iconTexture = iconTexture
	return self
end

---Sets the lead icon texture.
---@param iconTexture? string The texture string to use for the lead icon texture
---@return self
function Input:SetLeadIconTexture(iconTexture)
	assert(iconTexture == nil or TextureAtlas.IsValid(iconTexture))
	self._state.leadIconTexture = iconTexture
	return self
end

---Allows inserting an item into the input by linking it while the input has focus.
---@param insertLink? boolean Insert the link instead of the item name
---@return self
function Input:AllowItemInsert(insertLink)
	assert(insertLink == true or insertLink == false or insertLink == nil)
	self._allowItemInsert = insertLink or false
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function Input.__protected:_ShouldKeepFocus()
	if not IsMouseButtonDown("LeftButton") then
		return false
	end
	if self._clearBtn:IsVisible() and self._clearBtn:IsMouseOver() then
		return true
	else
		return false
	end
end

function Input.__protected:_OnChar(c)
	self.__super:_OnChar(c)
	if not self._autoComplete then
		return
	end
	local frame = self._frame
	local text = frame:GetText()
	local match = nil
	for _, k in ipairs(self._autoComplete) do
		local start, ending = strfind(strlower(k), strlower(text), 1, true)
		if start == 1 and ending and ending == #text then
			match = k
			break
		end
	end
	if match and not IsControlKeyDown() then
		local compStart = #text
		frame:SetText(match)
		self:HighlightText(compStart, #match)
		frame:GetScript("OnTextChanged")(frame, true)
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Input.__private:_HandleIconChanged()
	local leadIconTexture = self._state.leadIconTexture
	local leftPadding = PADDING_LEFT
	if leadIconTexture then
		leftPadding = leftPadding + TextureAtlas.GetWidth(leadIconTexture) + LEAD_ICON_GAP
	end
	local trailIconTexture = private.StateToIconTexture(self._state.disabled, self._state.displayValue, self._state.clearEnabled, self._state.hasFocus, self._state.iconTexture)
	local rightPadding = PADDING_RIGHT + (trailIconTexture and TextureAtlas.GetWidth(trailIconTexture) or 0)
	self:_SetTextInsets(leftPadding, rightPadding, PADDING_TOP_BOTTOM, PADDING_TOP_BOTTOM)
end

function Input.__private:_ClearBtnOnClick()
	assert(self:_SetValueHelper(""))
	self._escValue = ""
	self._editBox:SetText(self._state.value)
	self._state.displayValue = self._state.value
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToIconTexture(disabled, displayValue, clearEnabled, hasFocus, iconTexture)
	local iconColorKey = "on/surface"
	if disabled then
		iconColorKey = iconColorKey.."%40"
	end
	if clearEnabled and displayValue ~= "" then
		return TextureAtlas.GetColoredKey("iconPack.18x18/Close/Default", iconColorKey)
	else
		return not hasFocus and iconTexture and TextureAtlas.GetColoredKey(iconTexture, iconColorKey) or nil
	end
end

function private.StateToLeadIconTexture(disabled, leadIconTexture)
	if not leadIconTexture then
		return nil
	end
	return TextureAtlas.GetColoredKey(leadIconTexture, disabled and "on/surface%40" or "on/surface")
end

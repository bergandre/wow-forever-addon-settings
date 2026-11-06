-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ColorPicker = LibTSMUI:Init("Util.ColorPicker")
local private = {
	setCallback = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Shows the color picker.
---@param r number The red value as a number from 0 to 1
---@param g number The green value as a number from 0 to 1
---@param b number The blue value as a number from 0 to 1
---@param baseFrame Frame The frame to center the color picker dialog within
---@param setCallback fun(r: number, g: number, b: number) The callback when the color is changed
function ColorPicker.Show(r, g, b, baseFrame, setCallback)
	private.setCallback = setCallback
	if LibTSMUI.IsRetail() or LibTSMUI.IsForever() then
		ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
		ColorPickerFrame.Content.ColorSwatchOriginal:SetColorTexture(r, g, b)
	else
		ColorPickerFrame:SetColorRGB(r, g, b) ---@diagnostic disable-line: undefined-field
	end
	---@diagnostic disable: inject-field
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.previousValues = ColorPickerFrame.previousValues or {}
	wipe(ColorPickerFrame.previousValues)
	ColorPickerFrame.previousValues.r = r
	ColorPickerFrame.previousValues.g = g
	ColorPickerFrame.previousValues.b = b
	if LibTSMUI.IsMistsClassic() then
		ColorPickerFrame.func = private.SetCallbackWrapper
	else
		ColorPickerFrame.swatchFunc = private.SetCallbackWrapper
	end
	ColorPickerFrame.cancelFunc = private.CancelCallbackWrapper
	ColorPickerFrame:ClearAllPoints()
	local x, y = baseFrame:GetLeft() + (baseFrame:GetWidth() / 2), baseFrame:GetTop() - (baseFrame:GetHeight() / 2) - UIParent:GetHeight()
	ColorPickerFrame:SetPoint("CENTER", UIParent, "TOPLEFT", x, y)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
	if LibTSMUI.IsMistsClassic() then
		ColorPickerFrame.swatchFunc = ColorPickerFrame.func
	end
	---@diagnostic enable: inject-field
end

---Hides the color picker.
function ColorPicker.Hide()
	private.setCallback = nil
	ColorPickerFrame:Hide()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SetCallbackWrapper()
	if not private.setCallback then
		return
	end
	private.setCallback(ColorPickerFrame:GetColorRGB())
end

function private.CancelCallbackWrapper(prev)
	if not private.setCallback then
		return
	end
	private.setCallback(prev.r, prev.g, prev.b)
	private.setCallback = nil
end

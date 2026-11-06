-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local INFO_LOOKUP = {
	[EnumTypes.MAILING_OPEN_TYPE.SALE] = { text = L["Sold"], allText = L["All Sold"] },
	[EnumTypes.MAILING_OPEN_TYPE.BUY] = { text = L["Bought"], allText = L["All Bought"] },
	[EnumTypes.MAILING_OPEN_TYPE.CANCEL] = { text = L["Cancelled"], allText = L["All Cancelled"] },
	[EnumTypes.MAILING_OPEN_TYPE.EXPIRE] = { text = L["Expired"], allText = L["All Expired"] },
	[EnumTypes.MAILING_OPEN_TYPE.OTHER] = { text = L["Other"], allText = L["All Other"] },
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OpenMailActionButton = UIElements.Define("OpenMailActionButton", "MediumSecondaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OpenMailActionButton:__init()
	self.__super:__init()
	self._openType = nil
end

function OpenMailActionButton:Release()
	self._openType = nil
	self.__super:Release()
end

---Sets the mail type opened with the button.
---@param openType EnumValue The open type
---@return self
function OpenMailActionButton:SetOpenType(openType)
	assert(not self._openType)
	local info = INFO_LOOKUP[openType]
	assert(info)
	self._openType = openType
	self:SetText((App.IsRetail() or App.IsForever()) and info.allText or info.text)
	self:SetModifierText((App.IsRetail() or App.IsForever()) and info.text or info.allText, "SHIFT")
	self:SetTooltip((App.IsRetail() or App.IsForever()) and L["Hold SHIFT to not continue after the inbox refreshes"] or L["Hold SHIFT to continue after the inbox refreshes"])
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OpenMailActionButton.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		-- Send extra arguments along with the OnClick action
		local autoRefresh = nil
		if App.IsRetail() or App.IsForever() then
			autoRefresh = not IsShiftKeyDown()
		else
			autoRefresh = IsShiftKeyDown()
		end
		return self.__super:_SendActionScript(script, self._openType, autoRefresh, false)
	else
		return self.__super:_SendActionScript(script, ...)
	end
end

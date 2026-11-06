-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OpenAllMailActionButton = UIElements.Define("OpenAllMailActionButton", "MediumPrimaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OpenAllMailActionButton:Acquire()
	self.__super:Acquire()
	self:SetText((App.IsRetail() or App.IsForever()) and L["Open Mail"] or L["Open All Mail"])
	self:SetModifierText((App.IsRetail() or App.IsForever()) and L["Open All Mail"] or L["Open Mail"], "SHIFT")
	self:SetModifierText((App.IsRetail() or App.IsForever()) and L["Open All Mail Without Money"] or L["Open Mail Without Money"], "CTRL")
	self:SetModifierText((App.IsRetail() or App.IsForever()) and L["Open Mail Without Money"] or L["Open All Mail Without Money"], "SHIFT", "CTRL")
	self:SetTooltip((App.IsRetail() or App.IsForever()) and L["Hold SHIFT to not continue after the inbox refreshes and CTRL to not open mail with money attached."] or L["Hold SHIFT to continue after the inbox refreshes and CTRL to not open mail with money attached."])
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function OpenAllMailActionButton.__protected:_SendActionScript(script, ...)
	if script == "OnClick" then
		local autoRefresh = nil
		if App.IsRetail() or App.IsForever() then
			autoRefresh = not IsShiftKeyDown()
		else
			autoRefresh = IsShiftKeyDown()
		end
		return self.__super:_SendActionScript(script, EnumTypes.MAILING_OPEN_TYPE.ALL, autoRefresh, IsControlKeyDown())
	else
		return self.__super:_SendActionScript(script, ...)
	end
end

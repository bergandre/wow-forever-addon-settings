-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SwitchButton = ComponentRegistry.Define("SwitchButton", "SmallSecondaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SwitchButton:Acquire()
	self.__super:Acquire()
	self:SetSize(60, (LibTSMUI.IsRetail() or LibTSMUI.IsForever()) and 15 or 16)
	self:AddAnchor("TOPRIGHT", (LibTSMUI.IsRetail() or LibTSMUI.IsForever()) and -27 or -26, (LibTSMUI.IsRetail() or LibTSMUI.IsForever()) and -4 or -3)
	self:SetRelativeLevel((LibTSMUI.IsRetail() or LibTSMUI.IsForever()) and 600 or 3)
	self:DisableClickCooldown()
	self:SetText("TSM")
end

---Sets the default UI parent frame.
---@param frame Frame The parent frame
---@return self
function SwitchButton:SetDefaultUIParentFrame(frame)
	self._frame:SetParent(frame)
	return self
end

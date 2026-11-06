-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local DEFAULT_LINE_THICKNESS = 1



-- ============================================================================
-- Element Definition
-- ============================================================================

local VerticalLine = ComponentRegistry.Define("VerticalLine", "BaseTexture")
VerticalLine._STATE_SCHEMA = VerticalLine._STATE_SCHEMA:Extend("VerticalLineState")
	:UpdateFieldDefault("color", "outline/variant")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VerticalLine:Acquire()
	self.__super:Acquire()
	self:SetWidth(DEFAULT_LINE_THICKNESS)
end

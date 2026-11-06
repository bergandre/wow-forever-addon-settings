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

local HorizontalLine = ComponentRegistry.Define("HorizontalLine", "BaseTexture")
HorizontalLine._STATE_SCHEMA = HorizontalLine._STATE_SCHEMA:Extend("HorizontalLineState")
	:UpdateFieldDefault("color", "outline/variant")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function HorizontalLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(DEFAULT_LINE_THICKNESS)
end

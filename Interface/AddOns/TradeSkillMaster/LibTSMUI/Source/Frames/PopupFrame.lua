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

local PopupFrame = ComponentRegistry.Define("PopupFrame", "BaseFrame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PopupFrame:__init()
	self.__super:__init()
	self._nineSlice = self:_CreateNineSlice()
	self._nineSlice:SetStyle("popup")
	-- TODO: Proper color
	self._nineSlice:SubscribePartVertexColor("center", self:_GetOneShotPublisher("container/low"))
end

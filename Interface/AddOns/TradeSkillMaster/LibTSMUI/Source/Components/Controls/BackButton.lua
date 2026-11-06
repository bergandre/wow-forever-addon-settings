-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")



-- ============================================================================
-- Element Definition
-- ============================================================================

local BackButton = ComponentRegistry.Define("BackButton", "SmallTertiaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BackButton:Acquire()
	self.__super:Acquire()
	self:SetWidth(64)
	self:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey("iconPack.14x14/Chevron/Right"))..BACK)
end

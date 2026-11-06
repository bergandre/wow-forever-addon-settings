-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ExitScanButton = ComponentRegistry.Define("ExitScanButton", "SmallTertiaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ExitScanButton:Acquire()
	self.__super:Acquire()
	self:SetWidth(108)
	self:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey(TextureAtlas.GetFlippedHorizontallyKey("iconPack.14x14/Chevron/Right"), "accent/main"))..L["Exit Scan"])
end

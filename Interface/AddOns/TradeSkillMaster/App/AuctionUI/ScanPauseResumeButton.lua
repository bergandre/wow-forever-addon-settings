-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local ScanPauseResumeButton = UIElements.Define("ScanPauseResumeButton", "MediumTertiaryActionButton")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ScanPauseResumeButton:Acquire()
	self.__super:Acquire()
	self:SetWidth(28)
	for _ in self._state:WithAutoStorePaused() do
		self:SetText(self._state:PublisherForFunctionWithKeys(private.DisabledToIconText, "disabled"))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DisabledToIconText(disabled)
	return TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.18x18/PlayPause", disabled and "on/surface/low" or "on/surface"))
end

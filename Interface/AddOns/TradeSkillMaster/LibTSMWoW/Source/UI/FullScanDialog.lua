-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local FullScanDialog = LibTSMWoW:Init("UI.FullScanDialog")
local DIALOG_NAME = "TSM_FULL_SCAN"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Shows the full scan dialog.
---@param onAcceptHandler fun() The function to call when the yes button is pressed
function FullScanDialog.Show(onAcceptHandler)
	if not StaticPopupDialogs[DIALOG_NAME] then
		StaticPopupDialogs[DIALOG_NAME] = {
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			text = "Start Scan?",
			button1 = YES,
			button2 = NO,
		}
	end
	local info = StaticPopupDialogs[DIALOG_NAME]
	info.OnAccept = onAcceptHandler
	info.preferredIndex = 4
	StaticPopup_Show(DIALOG_NAME)
	for i = 1, 100 do
		if _G["StaticPopup" .. i] and _G["StaticPopup" .. i].which == DIALOG_NAME then
			_G["StaticPopup" .. i]:SetFrameStrata("TOOLTIP")
			break
		end
	end
end

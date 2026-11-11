-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local WhatsNew = LibTSMApp:Init("UI.WhatsNew")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local UIElements = LibTSMApp:From("LibTSMUI"):Include("UIElements")
local private = {
	settings = nil,
}
local VERSION = 6
local CONTENT_LINES = {} ---@type WhatsNewContentLine[]
do
	-- Build up the content lines
	if LibTSMApp.IsForever() then
		tinsert(CONTENT_LINES, { label = L["WoW: Forever Support"], content = L["TSM now supports WoW: Forever, including AuctionDB price data from the TSM Desktop App."] })
	end
	tinsert(CONTENT_LINES, { label = L["Post Scan Results"], content = L["Post scans now show the current auctions for each item alongside your min, normal and max prices. Drag or double-click an auction to undercut it instead."] })
	tinsert(CONTENT_LINES, { label = L["Activity Feed"], content = L["The Dashboard now has an Activity feed showing your recent sales, purchases, expirations and cancellations."] })
	if LibTSMApp.IsRetail() then
		tinsert(CONTENT_LINES, { label = L["Crafting Improvements"], content = L["Crafting costs can now mix material qualities when that's cheaper, and you can choose how many of each quality to use. You can also craft with Concentration, costs account for expected Resourcefulness and Multicraft, and Dye Crafting is supported."] })
	end
	tinsert(CONTENT_LINES, { label = L["Base Group Support"], content = L["Mailing operations, the Banking UI and Vendoring group actions now support the Base Group, so you can act on every item that isn't in a group."] })
end



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(WhatsNew, function(db)
	private.settings = db:NewView("WhatsNewSettings")
		:AddKey("global", "internalData", "whatsNewVersion")
		:Commit()
	SlashCommands.RegisterDebug("whatsnew", private.ResetWhatsNew)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Shows the what's new frame if applicable.
---@param frame LargeApplicationFrame The frame to show the what's new frame within
function WhatsNew.ShowDialog(frame)
	if private.settings.whatsNewVersion == VERSION then
		return
	end
	frame:ShowDialogFrame(UIElements.New("WhatsNewDialog", "whatsNew")
		:AddAnchor("CENTER")
		:Configure(VERSION, CONTENT_LINES)
		:SetSettings(private.settings, "whatsNewVersion")
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ResetWhatsNew()
	private.settings.whatsNewVersion = 0
end

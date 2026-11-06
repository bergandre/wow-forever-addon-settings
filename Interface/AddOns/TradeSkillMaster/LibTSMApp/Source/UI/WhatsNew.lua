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
local VERSION = 5
local CONTENT_LINES = {} ---@type WhatsNewContentLine[]
do
	-- Build up the content lines
	if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
		tinsert(CONTENT_LINES, { label = L["New Sniper Mechanism"], content = L["In retail, Sniper works in a new way which makes it much faster and now supports the base group."] })
		tinsert(CONTENT_LINES, { label = L["Alternate AuctionDB Realm Data"], content = L["You can configure an alternate realm to load AuctionDB data for to allow easy comparison between two realms in item tooltips."] })
	end
	tinsert(CONTENT_LINES, { label = L["Scroll Table Improvements"], content = L["TSM uses scroll tables through the addon to show large amounts of data. 4.14 includes significant performance improvements, dragging to reorder columns, adding price sources and custom sources as additional columns, and more."] })
	tinsert(CONTENT_LINES, { label = L["Custom Strings in More Operations"], content = L["Mailing, Vendoring, and Warehousing operation settings now fully support using custom strings."] })
	tinsert(CONTENT_LINES, { label = L["Import Item IDs from Wowhead"], content = L["When searching for items on Wowhead, you can copy the results as a list of item IDs. TSM now allows you to paste that list directly into the group import dialog to make it easy to create TSM groups."] })
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

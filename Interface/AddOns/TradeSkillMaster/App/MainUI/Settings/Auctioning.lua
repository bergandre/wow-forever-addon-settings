-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Auctioning = App:Init("MainUI.Settings.Auctioning")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
}
local SETTING_TOOLTIPS = {
	cancelWithBid = L["If enabled, TSM will cancel undercut auctions even if they have been bid on."],
	disableInvalidMsg = L["When starting a post or cancel scan, TSM will display error messages in chat for items which have invalid settings. This setting will disable those messages."],
	scanCompleteSound = L["The sound to play when a post or cancel scan has completed and items are ready to be posted or cancelled respectively."],
	confirmCompleteSound = L["The sound to play when all posts or cancels have been confirmed by the game."],
	auctionSaleSound = L["The sound to play when one of your auctions sells."],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Auctioning, function(db)
	private.settings = db:NewView("AuctioningSettings")
		:AddKey("global", "auctioningOptions", "cancelWithBid")
		:AddKey("global", "auctioningOptions", "disableInvalidMsg")
		:AddKey("global", "auctioningOptions", "scanCompleteSound")
		:AddKey("global", "auctioningOptions", "confirmCompleteSound")
		:AddKey("global", "coreOptions", "auctionSaleSound")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the auctioning settings frame.
---@return BaseScrollFrame
function Auctioning.GetFrame()
	return private.GetAuctioningSettingsFrame()
end



-- ============================================================================
-- Auctioning Settings UI
-- ============================================================================

function private.GetAuctioningSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "auctioning")
	return UIElements.New("BaseScrollFrame", "auctioningSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general Auctioning options are below."])
			:AddChild(UIElements.New("BaseFrame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "cancelBids")
					:SetWidth("AUTO")
					:SetText(L["Cancel auctions with bids"])
					:SetSettingInfo(private.settings, "cancelWithBid")
					:SetTooltip(SETTING_TOOLTIPS.cancelWithBid)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "invalidPrice")
					:SetWidth("AUTO")
					:SetText(L["Disable invalid price warnings"])
					:SetSettingInfo(private.settings, "disableInvalidMsg")
					:SetTooltip(SETTING_TOOLTIPS.disableInvalidMsg)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "sounds")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Auction House Sounds"], L["Setup various sounds that play when doing Auctioning scans."])
			:AddChild(UIElements.New("BaseFrame", "soundLine")
				:SetLayout("HORIZONTAL")
				:SetHeight(46)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("SettingsField", "scan")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Scan complete sound"])
					:AddChild(UIElements.New("SoundDropdown", "scanComplete")
						:SetHeight(24)
						:SetSettingInfo(private.settings, "scanCompleteSound")
						:SetTooltip(SETTING_TOOLTIPS.scanCompleteSound)
					)
				)
				:AddChild(UIElements.New("SettingsField", "confirm")
					:SetLabel(L["Confirm complete sound"])
					:AddChild(UIElements.New("SoundDropdown", "confirmComplete")
						:SetHeight(24)
						:SetSettingInfo(private.settings, "confirmCompleteSound")
						:SetTooltip(SETTING_TOOLTIPS.confirmCompleteSound)
					)
				)
			)
			:AddChild(UIElements.New("SettingsField", "sale")
				:SetLabel(L["Auction sale sound"])
				:AddChild(UIElements.New("SoundDropdown", "saleSoundDropdown")
					:SetHeight(24)
					:SetSettingInfo(private.settings, "auctionSaleSound")
					:SetTooltip(SETTING_TOOLTIPS.auctionSaleSound)
				)
			)
		)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Mailing = App:Init("MainUI.Settings.Mailing")
local Item = App:From("LibTSMWoW"):Include("API.Item")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
}
local ITEM_QUALITY_KEYS = {}
local ITEM_QUALITY_DESCS = {}
do
	for i = 2, 4 do
		tinsert(ITEM_QUALITY_DESCS, Item.GetQualityString(i))
		tinsert(ITEM_QUALITY_KEYS, i)
	end
end
local SETTING_TOOLTIP = {
	inboxMessages = L["If enabled, TSM will add chat messages describing mail being opened."],
	keepMailSpace = L["TSM will stop automatically opening mail as needed in order keep this number of slots empty in your bags."],
	openMailSound = L["The sound to play when mail has finished automatically opening."],
	sendMessages = L["If enabled, TSM will add chat messages describing mail being sent."],
	sendItemsIndividually = L["Setting this will result in different items being sent in separate mails rather than mixing them within the same mail when sending with Mailing operations."],
	resendDelay = L["How long in minutes to wait between automatically attempting to re-send items according to your Mailing operations."],
	deMaxQuality = L["The max quality of item to send when mailing disenchantables in the 'Other' tab."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

AddonSettings.RegisterOnLoad(Mailing, function(db)
	private.settings = db:NewView("MailingSettings")
		:AddKey("global", "mailingOptions", "inboxMessages")
		:AddKey("global", "mailingOptions", "keepMailSpace")
		:AddKey("global", "mailingOptions", "openMailSound")
		:AddKey("global", "mailingOptions", "sendMessages")
		:AddKey("global", "mailingOptions", "sendItemsIndividually")
		:AddKey("global", "mailingOptions", "resendDelay")
		:AddKey("global", "mailingOptions", "deMaxQuality")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the mailing settings frame.
---@return BaseScrollFrame
function Mailing.GetFrame()
	return private.GetMailingSettingsFrame()
end



-- ============================================================================
-- Mailing Settings UI
-- ============================================================================

function private.GetMailingSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "mailing")
	return UIElements.New("BaseScrollFrame", "mailingSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "inbox")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Inbox Settings"], L["Some general 'Inbox' tab settings are below."])
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "inboxMessagesCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Enable inbox chat messages"])
					:SetSettingInfo(private.settings, "inboxMessages")
					:SetTooltip(SETTING_TOOLTIP.inboxMessages)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("SettingsField", "freeSpace")
				:SetMargin(0, 0, 0, 12)
				:SetLabel(L["Amount of bag space to keep free"])
				:AddChild(UIElements.New("BaseFrame", "freeSpaceFrame")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:AddChild(UIElements.New("NumberInput", "keepMailInput")
						:SetMargin(0, 8, 0, 0)
						:SetValidRange(0, 20)
						:SetSettingInfo(private.settings, "keepMailSpace")
						:SetTooltip(SETTING_TOOLTIP.keepMailSpace, true)
					)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["Min 0 - Max 20"])
					)
				)
			)
			:AddChild(UIElements.New("SettingsField", "sound")
				:SetLabel(L["Open mail complete sound"])
				:AddChild(UIElements.New("SoundDropdown", "mailSoundDropdown")
					:SetHeight(24)
					:SetSettingInfo(private.settings, "openMailSound")
					:SetTooltip(SETTING_TOOLTIP.openMailSound)
				)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "send")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Sending Settings"], L["Some general 'Send' tab settings are below."])
			:AddChild(UIElements.New("BaseFrame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "sendMessagesCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Enable sending chat messages"])
					:SetSettingInfo(private.settings, "sendMessages")
					:SetTooltip(SETTING_TOOLTIP.sendMessages)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "sendItemsCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Send grouped items individually"])
					:SetSettingInfo(private.settings, "sendItemsIndividually")
					:SetTooltip(SETTING_TOOLTIP.sendItemsIndividually)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("SettingsField", "restartDelay")
				:SetMargin(0, 0, 0, 12)
				:SetLabel(L["Restart delay (minutes)"])
				:AddChild(UIElements.New("BaseFrame", "restartDelayFrame")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:AddChild(UIElements.New("NumberInput", "restartDelay")
						:SetMargin(0, 8, 0, 0)
						:SetValidRange(0.5, 10, 0.5)
						:SetSettingInfo(private.settings, "resendDelay")
						:SetTooltip(SETTING_TOOLTIP.resendDelay, true)
					)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["Min 0.5 - Max 10"])
					)
				)
			)
			:AddChild(UIElements.New("SettingsField", "deMaxQuality")
				:SetLabel(L["Mail disenchantables max quality"])
				:AddChild(UIElements.New("SelectionDropdown", "mailPageDropdown")
					:SetHeight(24)
					:SetItems(ITEM_QUALITY_DESCS, ITEM_QUALITY_KEYS)
					:SetSettingInfo(private.settings, "deMaxQuality")
					:SetHintText(L["Select quality"])
					:SetTooltip(SETTING_TOOLTIP.deMaxQuality)
				)
			)
		)
end

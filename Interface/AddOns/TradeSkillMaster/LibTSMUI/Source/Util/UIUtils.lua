-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIUtils = LibTSMUI:Init("Util.UIUtils")
local Item = LibTSMUI:From("LibTSMWoW"):Include("API.Item")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Analytics = LibTSMUI:From("LibTSMService"):Include("Util.Analytics")
local private = {
	analyticsPath = {},
}
local TIME_LEFT_STRINGS = {}
local TIME_LEFT_COLOR_KEYS = {
	"error/main",
	"error/main",
	"warning/main",
	"positive/main",
}
do
	-- Set the TIME_LEFT_STRINGS values
	local hours = {}
	if LibTSMUI.IsVanillaClassic() then
		hours = { 0.5, 2, 8, 24 }
	elseif LibTSMUI.IsBCClassic() then
		hours = { 0.5, 2, 12, 48 }
	else
		hours = { 1, 2, 24, 48 }
	end
	assert(#hours == #TIME_LEFT_COLOR_KEYS)
	for i, hourValue in ipairs(hours) do
		if hourValue >= 1 then
			TIME_LEFT_STRINGS[i] = format(L["%dh"], hourValue)
		else
			TIME_LEFT_STRINGS[i] = format(L["%dm"], hourValue * 60)
		end
	end
end
---@type table<TSMSoundKey,string>
local SOUND_DESCRIPTIONS = {
	["TSM_NO_SOUND"] = "<"..L["No Sound"]..">",
	["TSM_CASH_REGISTER"] = L["Cash Register"],
	["AuctionWindowOpen"] = L["Auction Window Open"],
	["AuctionWindowClose"] = L["Auction Window Close"],
	["alarmclockwarning3"] = L["Alarm Clock"],
	["UI_AutoQuestComplete"] = L["Auto Quest Complete"],
	["HumanExploration"] = L["Exploration"],
	["Fishing Reel in"] = L["Fishing Reel In"],
	["LevelUp"] = L["Level Up"],
	["MapPing"] = L["Map Ping"],
	["MONEYFRAMEOPEN"] = L["Money Frame Open"],
	["IgPlayerInviteAccept"] = L["Player Invite Accept"],
	["QUESTADDED"] = L["Quest Added"],
	["QUESTCOMPLETED"] = L["Quest Completed"],
	["UI_QuestObjectivesComplete"] = L["Quest Objectives Complete"],
	["RaidWarning"] = L["Raid Warning"],
	["ReadyCheck"] = L["Ready Check"],
	["Repair"] = L["Repair"],
	["UnwrapGift"] = L["Unwrap Gift"],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets an item name formatted for display.
---@param item string The item to display
---@param tintPct? number The tintPct to apply to the quality color
---@return string?
function UIUtils.GetDisplayItemName(item, tintPct)
	local name = ItemInfo.GetName(item)
	local quality = ItemInfo.GetQuality(item)
	local craftedQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(item)
	if not name or not quality then
		return nil
	end
	return UIUtils.GetQualityColoredText(name, quality, craftedQuality, useMidnightIcon, tintPct)
end

---Colors text based on an item quality.
---@param name? string The name of the item
---@param quality? number The quality of the item
---@param craftedQuality? number The crafted quality of the item
---@param tintPct? number The tintPct to apply to the quality color
---@return string?
function UIUtils.GetQualityColoredText(name, quality, craftedQuality, useMidnightIcon, tintPct)
	if not name or not quality then
		return nil
	end
	local color = Theme.GetItemQualityColor(quality)
	local result = color:GetTint(tintPct or 0):ColorText(name)
	local craftedQualityIcon = craftedQuality and TradeSkill.GetCraftedQualityChatIcon(craftedQuality, useMidnightIcon)
	if craftedQualityIcon then
		result = result.." "..craftedQualityIcon
	end
	return result
end

---Gets the localized string representation of an auction time left.
---@param timeLeft number The time left index (i.e. from WoW APIs)
---@return string
function UIUtils.GetTimeLeftString(timeLeft)
	local str = TIME_LEFT_STRINGS[timeLeft]
	assert(str, "Invalid timeLeft: "..tostring(timeLeft))
	return Theme.GetColor(TIME_LEFT_COLOR_KEYS[timeLeft]):ColorText(str)
end

---Registers a UI for analytics tracking.
---@param uiName string The name of the UI
function UIUtils.RegisterUIForAnalytics(uiName)
	assert(not private.analyticsPath[uiName])
	private.analyticsPath[uiName] = ""
end

---Logs an analytics action for the UI path changing.
---@param uiName string The name of the UI
---@param ... string The extra path components
function UIUtils.AnalyticsRecordPathChange(uiName, ...)
	assert(private.analyticsPath[uiName])
	local path = strjoin("/", uiName, ...)
	if path == private.analyticsPath[uiName] then
		return
	end
	Analytics.Action("UI_NAVIGATION", private.analyticsPath[uiName], path)
	private.analyticsPath[uiName] = path
end

---Logs an analytics action for a UI being closed.
---@param uiName string The name of the UI
function UIUtils.AnalyticsRecordClose(uiName)
	assert(private.analyticsPath[uiName])
	if private.analyticsPath[uiName] == "" then
		return
	end
	Analytics.Action("UI_NAVIGATION", private.analyticsPath[uiName], "")
	private.analyticsPath[uiName] = ""
end

---Handles a modified item click from a UI.
---@param itemString string The itemString for the item which was clicked on
function UIUtils.HandleModifiedItemClick(itemString)
	Item.HandleModifiedItemClick(ItemInfo.GetLink(itemString))
end

---Gets the localized description of a sound.
---@param soundKey TSMSoundKey
---@return string
function UIUtils.GetSoundDescription(soundKey)
	local description = SOUND_DESCRIPTIONS[soundKey]
	assert(description)
	return description
end

---Configures tab navigation between a set of inputs (in the order provided, looping at the end).
---@param ... BaseInput The input elements to configure navigation between
function UIUtils.ConfigureInputTabNavigation(...)
	local numInputs = select("#", ...)
	assert(numInputs > 1)
	for i = 1, numInputs do
		local prevInput = select((i == 1) and numInputs or (i - 1), ...)
		local input = select(i, ...)
		local nextInput = select((i == numInputs) and 1 or (i + 1), ...)
		input:SetTabElements(prevInput, nextInput)
	end
end

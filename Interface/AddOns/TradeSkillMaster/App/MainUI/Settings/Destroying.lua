-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Destroying = App:Init("MainUI.Settings.Destroying")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Item = App:From("LibTSMWoW"):Include("API.Item")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local DestroyingApp = App:From("LibTSMApp"):Include("Destroying")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
}
local ITEM_QUALITY_KEYS = {}
local ITEM_QUALITY_DESCS = {}
do
	for i = 2, 4 do
		tinsert(ITEM_QUALITY_DESCS, Item.GetQualityString(i))
		tinsert(ITEM_QUALITY_KEYS, i)
	end
end
local SETTING_TOOLTIPS = {
	autoStack = L["Automatically combine smaller stacks of herbs and ore as needed for milling and prospecting respectively."],
	autoShow = L["Automatically show the Destroying UI when you have something in your bags to destroy."],
	includeSoulbound = L["Include soulbound items in the list of items to disenchant."],
	deMaxQuality = L["The max quality of item which Destroying will list for disenchanting."],
	deAbovePrice = L["Destroying will only list items with a disenchant value above this price for disenchanting."],

}
local STATE_SCHEMA = Reactive.CreateStateSchema("DestroyingSettingsUIState")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Destroying, function(db)
	private.settings = db:NewView("DestroyingSettings")
		:AddKey("global", "destroyingOptions", "autoStack")
		:AddKey("global", "destroyingOptions", "autoShow")
		:AddKey("global", "destroyingOptions", "includeSoulbound")
		:AddKey("global", "destroyingOptions", "deMaxQuality")
		:AddKey("global", "destroyingOptions", "deAbovePrice")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("DESTROYING_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetDestroyingSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the destroying settings frame.
---@return BaseScrollFrame
function Destroying.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Destroying Settings UI
-- ============================================================================

---@param state DestroyingSettingsUIState
function private.GetDestroyingSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "destroying")
	return UIElements.New("BaseScrollFrame", "destroyingSettings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general destroying settings are below."])
			:AddChild(UIElements.New("BaseFrame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "autoStackCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Enable automatic stack combination"])
					:SetSettingInfo(private.settings, "autoStack")
					:SetTooltip(SETTING_TOOLTIPS.autoStack)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "autoShowCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Show destroying frame automatically"])
					:SetSettingInfo(private.settings, "autoShow")
					:SetTooltip(SETTING_TOOLTIPS.autoShow)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "check3")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "includeSoulboundCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Include soulbound items"])
					:SetSettingInfo(private.settings, "includeSoulbound")
					:SetTooltip(SETTING_TOOLTIPS.includeSoulbound)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "disenchanting")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Disenchanting Options"], L["Some disenchant specific settings are below."])
			:AddChild(UIElements.New("SettingsField", "maxQuality")
				:SetMargin(0, 0, 0, 12)
				:SetLabel(L["Maximum disenchant quality"])
				:AddChild(UIElements.New("SelectionDropdown", "maxQualityDropDown")
					:SetHeight(24)
					:SetItems(ITEM_QUALITY_DESCS, ITEM_QUALITY_KEYS)
					:SetHintText(L["Select quality"])
					:SetSettingInfo(private.settings, "deMaxQuality")
					:SetTooltip(SETTING_TOOLTIPS.deMaxQuality)
				)
			)
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "deDisenchantPriceField")
				:ConfigureText(L["Only show items with disenchant values above this price"], SETTING_TOOLTIPS.deAbovePrice)
				:SetSettingInfo(private.settings, "deAbovePrice")
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "ignore")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Ignored Items"], L["Click on an item below to unignore it for destroying."])
			:AddChild(UIElements.New("SimpleItemList", "items")
				:SetHeight(136)
				:SetQuery(DestroyingApp.CreateIgnoreQuery())
				:SetAction("OnItemClick", "ACTION_REMOVE_IGNORED_ITEM")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<DestroyingSettingsUIState>
---@param state DestroyingSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_REMOVE_IGNORED_ITEM" then
		local itemString = ...
		DestroyingApp.ForgetIgnoreItemPermanent(itemString)
	else
		error("Unknown action: "..tostring(action))
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Vendoring = App:Init("MainUI.Settings.Vendoring")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local VendoringApp = App:From("LibTSMApp"):Include("Vendoring")
local private = {
	settings = nil,
	manager = nil,
}
local SETTING_TOOLTIPS = {
	displayMoneyCollected = L["If enabled, the total amount of money earned from selling items to the vendor will be displayed in chat."],
	qsMarketValue = L["How TSM determines the market value for the purpose of displaying in the 'Sell' tab of the Vendor UI."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringSettingsUIState")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Vendoring, function(db)
	private.settings = db:NewView("VendoringSettings")
		:AddKey("global", "vendoringOptions", "displayMoneyCollected")
		:AddKey("global", "vendoringOptions", "qsMarketValue")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetVendoringSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the vendoring settings frame.
---@return BaseScrollFrame
function Vendoring.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Vendoring Settings UI
-- ============================================================================

---@param state VendoringSettingsUIState
function private.GetVendoringSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "vendoring")
	return UIElements.New("BaseScrollFrame", "vendoringSettings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general vendoring options are below."])
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetWidth("AUTO")
					:SetSettingInfo(private.settings, "displayMoneyCollected")
					:SetText(L["Display total money received in chat"])
					:SetTooltip(SETTING_TOOLTIPS.displayMoneyCollected)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "qsMarketValueSourceField")
				:ConfigureText(L["Market value price source"], SETTING_TOOLTIPS.qsMarketValue)
				:SetSettingInfo(private.settings, "qsMarketValue")
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "ignore")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Ignored Items"], L["Click on an item below to unignore it for vendoring."])
			:AddChild(UIElements.New("SimpleItemList", "items")
				:SetHeight(326)
				:SetQuery(VendoringApp.CreateIgnoreQuery())
				:SetAction("OnItemClick", "ACTION_REMOVE_IGNORED_ITEM")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringSettingsUIState>
---@param state VendoringSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_REMOVE_IGNORED_ITEM" then
		local itemString = ...
		VendoringApp.ForgetIgnoreItemPermanent(itemString)
	else
		error("Unknown action: "..tostring(action))
	end
end

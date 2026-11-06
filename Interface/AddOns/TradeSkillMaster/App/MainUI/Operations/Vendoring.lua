-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Vendoring = App:Init("MainUI.Operations.Vendoring")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local VendoringOperation = App:From("LibTSMSystem"):Include("VendoringOperation")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
}
local OPERATION_TYPE_NAME = "Vendoring"
local RESTOCK_SOURCES = { GlobalStrings.Get("BANK"), GlobalStrings.Get("GUILD"), L["Alts"], L["Alts AH"], L["AH"], L["Mail"] }
local RESTOCK_SOURCES_KEYS = { "bank", "guild", "alts", "alts_ah", "ah", "mail" }
local SETTING_TOOLTIPS = {
	enableBuy = L["If enabled, items in the selected group will be purchased from the targeted vendor."],
	restockQty = L["The maximum number of items to have in your inventory when purchasing items from the targeted vendor. A value of 0 indicates no maximum restock quantity."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
	enableSell = L["If enabled, items in the selected group will be sold to the targeted vendor."],
	keepQty = L["The number of items to keep on hand before selling to the vendor."],
	sellAfterExpired = L["The minimum number times an item has expired from previously posted auctions before being eligible to be sold to a vendor."],
	vsMarketValue = L["A custom string to define the market value TSM references when determining whether to vendor an item based on the threshold defined in 'Max market value' field."],
	vsMaxMarketValue = L["A custom string to define the threshold of the 'Market value' to consider items for vendoring. Set this to '0c' to disable this condition."],
	vsDestroyValue = L["A custom string to define the destroy value TSM references when determining whether to vendor an item based on the threshold defined in 'Max destroy value' field."],
	vsMaxDestroyValue = L["A custom string to define the threshold of the 'Destroy value' to consider items for vendoring. Set this to '0c' to disable this condition."],
	sellSoulbound = L["If enabled, items that are soulbound will be sold to the targeted vendor."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddDeferredStringField("operationName")
	:AddBooleanField("enableBuy", false)
	:AddBooleanField("enableSell", false)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Vendoring:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetVendoringOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the vendoring operation settings frame.
---@param operationName string The current operation name
---@return BaseScrollFrame
function Vendoring.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Vendoring Operation Settings UI
-- ============================================================================

---@param state VendoringOperationsUIState
function private.GetVendoringOperationSettings(state, operationName)
	local operationSettings = VendoringOperation.GetSettings(operationName)
	state.operationName = operationName
	state.enableBuy = operationSettings.enableBuy
	state.enableSell = operationSettings.enableSell
	UIUtils.AnalyticsRecordPathChange("main", "operations", "vendoring")
	local disableBuyPublisher = state:Publisher("enableBuy")
		:InvertBoolean()
		:Share()
	local disableSellPublisher = state:Publisher("enableSell")
		:InvertBoolean()
		:Share()
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "buyOptions")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Buy Options"], L["Set what is bought from a vendor."])
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "enableBuy")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Enable buying"], SETTING_TOOLTIPS.enableBuy)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "enableBuy")
				:SetAction("OnValueChanged", "ACTION_ENABLE_BUY_CHANGED")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "restockQty")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Restock quantity"], SETTING_TOOLTIPS.restockQty, VendoringOperation.GetSettingRange("restockQty"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockQty")
				:SetDisabled(disableBuyPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedMultiselectionDropdownLine", "restockSources")
				:ConfigureText(L["Sources to include for restock"], L["No Sources"], L["%d Sources"], L["All Sources"], L["Select sources"], SETTING_TOOLTIPS.restockSources)
				:SetItems(RESTOCK_SOURCES, RESTOCK_SOURCES_KEYS)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockSources")
				:SetDisabled(disableBuyPublisher)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "sellOptions")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Sell Options"], L["Set what is sold to a vendor."])
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "enableSell")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Enable selling"], SETTING_TOOLTIPS.enableSell)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "enableSell")
				:SetAction("OnValueChanged", "ACTION_ENABLE_SELL_CHANGED")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "keepQty")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Keep quantity"], SETTING_TOOLTIPS.keepQty, VendoringOperation.GetSettingRange("keepQty"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "keepQty")
				:SetDisabled(disableSellPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "sellAfterExpired")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Min number of expires"], SETTING_TOOLTIPS.sellAfterExpired, VendoringOperation.GetSettingRange("sellAfterExpired"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "sellAfterExpired")
				:SetDisabled(disableSellPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "vsMarketValue")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Market value"], SETTING_TOOLTIPS.vsMarketValue)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "vsMarketValue")
				:SetDisabled(disableSellPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "vsMaxMarketValue")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Max market value (Enter '0c' to disable)"], SETTING_TOOLTIPS.vsMaxMarketValue)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "vsMaxMarketValue")
				:SetDisabled(disableSellPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "vsDestroyValue")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Destroy value"], SETTING_TOOLTIPS.vsDestroyValue)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "vsDestroyValue")
				:SetDisabled(disableSellPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "vsMaxDestroyValue")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Max destroy value (Enter '0c' to disable)"], SETTING_TOOLTIPS.vsMaxDestroyValue)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "vsMaxDestroyValue")
				:SetDisabled(disableSellPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "sellSoulbound")
				:SetMargin(0)
				:ConfigureText(L["Sell soulbound items"], SETTING_TOOLTIPS.sellSoulbound)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "sellSoulbound")
				:SetDisabled(disableSellPublisher)
			)
		)
		:AddChild(UIElements.New("OperationManagementSettingsFrame", "management")
			:Configure(OPERATION_TYPE_NAME, state.operationName, AddonSettings.GetDB())
			:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
			:SetAction("OnGroupsChanged", "ACTION_GROUPS_CHANGED")
		)
		:AddCancellable(disableBuyPublisher:EndShare())
		:AddCancellable(disableSellPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringOperationsUIState>
---@param state VendoringOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_ENABLE_BUY_CHANGED" then
		local operationSettings = VendoringOperation.GetSettings(state.operationName)
		state.enableBuy = operationSettings.enableBuy
	elseif action == "ACTION_ENABLE_SELL_CHANGED" then
		local operationSettings = VendoringOperation.GetSettings(state.operationName)
		state.enableSell = operationSettings.enableSell
	elseif action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		Util.ShowGroupSettings(groupPath)
	elseif action == "ACTION_GROUPS_CHANGED" then
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Shopping = App:Init("MainUI.Operations.Shopping")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ShoppingOperation = App:From("LibTSMSystem"):Include("ShoppingOperation")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
}
local OPERATION_TYPE_NAME = "Shopping"
local RESTOCK_SOURCES = { L["Alts"], L["Auctions"], GlobalStrings.Get("BANK"), GlobalStrings.Get("GUILD") }
local RESTOCK_SOURCES_KEYS = { "alts", "auctions", "bank", "guild" }
local MAX_PRICE_BAD_SOURCES = {
	shoppingopmax = true,
}
local SETTING_TOOLTIPS = {
	maxPrice = L["The max price to show in the shopping results."],
	showAboveMaxPrice = L["If enabled, auctions above the defined max price will be shown in shopping results."],
	restockQuantity = L["The maximum number of items to have in your inventory."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("ShoppingOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddOptionalStringField("operationName")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Shopping:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SHOPPING_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetShoppingOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the shopping operation settings frame.
---@param operationName string The current operation name
---@return BaseScrollFrame
function Shopping.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Shopping Operation Settings UI
-- ============================================================================

---@param state ShoppingOperationsUIState
---@param operationName string
function private.GetShoppingOperationSettings(state, operationName)
	state.operationName = operationName
	UIUtils.AnalyticsRecordPathChange("main", "operations", "shopping")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "generalOptions")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Set what items are shown during a Shopping scan."])
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "maxPrice")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Maximum price"], SETTING_TOOLTIPS.maxPrice)
				:SetBadSources(MAX_PRICE_BAD_SOURCES)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "maxPrice")
			)
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "showAboveMaxPrice")
				:SetMargin(0, 0, 0, 12)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "showAboveMaxPrice")
				:ConfigureText(L["Show auctions above max price"], SETTING_TOOLTIPS.showAboveMaxPrice)
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "restockQuantity")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Maximum restock quantity"], SETTING_TOOLTIPS.restockQuantity, ShoppingOperation.GetRestockValueRange())
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockQuantity")
			)
			:AddChild(UIElements.New("OperationLinkedMultiselectionDropdownLine", "restockSources")
				:ConfigureText(L["Sources to include for restock"], L["No Sources"], L["%d Sources"], L["All Sources"], L["Select sources"], SETTING_TOOLTIPS.restockSources)
				:SetItems(RESTOCK_SOURCES, RESTOCK_SOURCES_KEYS)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockSources")
			)
		)
		:AddChild(UIElements.New("OperationManagementSettingsFrame", "management")
			:Configure(OPERATION_TYPE_NAME, state.operationName, AddonSettings.GetDB())
			:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
			:SetAction("OnGroupsChanged", "ACTION_GROUPS_CHANGED")
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<ShoppingOperationsUIState>
---@param state ShoppingOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		Util.ShowGroupSettings(groupPath)
	elseif action == "ACTION_GROUPS_CHANGED" then
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

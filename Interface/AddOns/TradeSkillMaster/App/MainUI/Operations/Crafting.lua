-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Crafting = App:Init("MainUI.Operations.Crafting")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CraftingOperation = App:From("LibTSMSystem"):Include("CraftingOperation")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
}
local OPERATION_TYPE_NAME = "Crafting"
local CRAFT_VALUE_BAD_SOURCES = {
	crafting = true,
}
local SETTING_TOOLTIPS = {
	minRestock = L["This is the minimum number of items to add to your Crafting queue before any items are added to your Crafting queue. For example, if this is set to 10 and the operation would only add 3 items to the crafting queue, the items would not be added."],
	maxRestock = L["This is the maximum number of items you want to have in stock. If you already have more than this number, no more will be added to your Crafting queue."],
	minProfitToggle = L["If enabled, items would need to satisfy a minimum profit before being added to your crafting queue."],
	minProfitValue = L["If enabled, items would need to satisfy a minimum profit before being added to your crafting queue."],
	craftPriceMethodToggle = L["Enabling this allows overriding the default craft value method used to calculate profit of items associated with this operation."],
	craftPriceMethodValue = L["The craft value method to use for this operation."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("CraftingOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddOptionalStringField("operationName")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Crafting, function(db)
	private.settings = db:NewView("CraftingSettings")
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("CRAFTING_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetCraftingOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the crafting operation settings frame.
---@param operationName string The current operation name
---@return BaseScrollFrame
function Crafting.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Crafting Operation Settings UI
-- ============================================================================

---@param state CraftingOperationsUIState
---@param operationName string
function private.GetCraftingOperationSettings(state, operationName)
	state.operationName = operationName
	UIUtils.AnalyticsRecordPathChange("main", "operations", "crafting")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "restockQuantity")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Restock Options"], L["Adjust how crafted items are restocked."])
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "minRestock")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Minimum restock quantity"], SETTING_TOOLTIPS.minRestock, CraftingOperation.GetRestockValueRange())
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "minRestock")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "maxRestock")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Maximum restock quantity"], SETTING_TOOLTIPS.maxRestock, CraftingOperation.GetRestockValueRange())
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "maxRestock")
			)
			:AddChild(UIElements.New("OperationLinkedCraftingPrice", "minProfit")
				:ConfigureText(L["Set Min Profit"], L["Min profit amount"], SETTING_TOOLTIPS.minProfitToggle, SETTING_TOOLTIPS.minProfitValue)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "minProfit")
				:SetAction("OnValueChanged", "ACTION_REDRAW")
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "priceSettings")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Crafting Value"], L["Adjust how TSM values crafted items when calculating profit."])
			:AddChild(UIElements.New("OperationLinkedCraftingPrice", "craftPriceMethod")
				:ConfigureText(L["Override default craft value"], L["Craft value"], SETTING_TOOLTIPS.craftPriceMethodToggle, SETTING_TOOLTIPS.craftPriceMethodValue)
				:SetBadSources(CRAFT_VALUE_BAD_SOURCES)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "craftPriceMethod", private.settings.defaultCraftPriceMethod)
				:SetAction("OnValueChanged", "ACTION_REDRAW")
			)
		)
		:AddChild(UIElements.New("OperationManagementSettingsFrame", "management")
			:Configure(OPERATION_TYPE_NAME, state.operationName, AddonSettings.GetDB())
			:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
			:SetAction("OnGroupsChanged", "ACTION_REDRAW")
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<CraftingOperationsUIState>
---@param state CraftingOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		Util.ShowGroupSettings(groupPath)
	elseif action == "ACTION_REDRAW" then
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

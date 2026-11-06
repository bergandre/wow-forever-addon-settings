-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Warehousing = App:Init("MainUI.Operations.Warehousing")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local WarehousingOperation = App:From("LibTSMSystem"):Include("WarehousingOperation")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
}
local OPERATION_TYPE_NAME = "Warehousing"
local SETTING_TOOLTIPS = {
	moveQuantity = L["The number of items to move in or out of the bank via the Bank UI."],
	stackSize = L["Moves items in or out of the bank in the defined stack size. Set to 0 to disable."],
	keepBagQuantity = L["The number of items to keep in the character's bags when moving items to the bank."],
	keepBankQuantity = L["The number of items to keep in the bank when moving items to the character's bags."],
	restockQuantity = L["The maximum number of items to restock to a character's bags. Set this to 0 in order to always move the set 'Move quantity' value."],
	restockStackSize = L["Only move items in the defined stack size i.e. stack of 5 for destroying. Set to 0 to disable."],
	restockKeepBankQuantity = L["The number of items to keep in the bank when moving items to the characters bags."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("WarehousingOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddOptionalStringField("operationName")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Warehousing:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("WAREHOUSING_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetWarehousingOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the warehousing operation settings frame.
---@param operationName string The current operation name
---@return BaseScrollFrame
function Warehousing.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Warehousing Operation Settings UI
-- ============================================================================

---@param state WarehousingOperationsUIState
---@param operationName string
function private.GetWarehousingOperationSettings(state, operationName)
	state.operationName = operationName
	UIUtils.AnalyticsRecordPathChange("main", "operations", "warehousing")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "moveSettings")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Move Quantity Options"], L["Set how items are moved out of the bank."])
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "moveQuantity")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Quantity to move"], SETTING_TOOLTIPS.moveQuantity, WarehousingOperation.GetSettingRange("moveQuantity"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "moveQuantity")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "stackSize")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Stack size multiple"], SETTING_TOOLTIPS.stackSize, WarehousingOperation.GetSettingRange("stackSize"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "stackSize")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "keepBagQuantity")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Keep in bags quantity"], SETTING_TOOLTIPS.keepBagQuantity, WarehousingOperation.GetSettingRange("keepBagQuantity"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "keepBagQuantity")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "keepBankQuantity")
				:ConfigureText(L["Keep in bank quantity"], SETTING_TOOLTIPS.keepBankQuantity, WarehousingOperation.GetSettingRange("keepBankQuantity"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "keepBankQuantity")
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "restockSettings")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Restock Options"], L["Set how items are restocked from the bank."])
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "restockQuantity")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Restock quantity"], SETTING_TOOLTIPS.restockQuantity, WarehousingOperation.GetSettingRange("restockQuantity"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockQuantity")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "restockStackSize")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Stack size multiple"], SETTING_TOOLTIPS.restockStackSize, WarehousingOperation.GetSettingRange("restockStackSize"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockStackSize")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "restockKeepBankQuantity")
				:ConfigureText(L["Keep in bank Quantity"], SETTING_TOOLTIPS.restockKeepBankQuantity, WarehousingOperation.GetSettingRange("restockKeepBankQuantity"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockKeepBankQuantity")
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

---@param manager UIManager<WarehousingOperationsUIState>
---@param state WarehousingOperationsUIState
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

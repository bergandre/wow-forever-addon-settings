-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Mailing = App:Init("MainUI.Operations.Mailing")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local MailingOperation = App:From("LibTSMSystem"):Include("MailingOperation")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local private = {
	manager = nil,
}
local OPERATION_TYPE_NAME = "Mailing"
local RESTOCK_SOURCES_ITEMS = {
	GlobalStrings.Get("BANK"),
	GlobalStrings.Get("GUILD"),
}
local RESTOCK_SOURCES_KEYS = {
	"bank",
	"guild",
}
local SETTING_TOOLTIPS = {
	keepQty = L["The amount of items to keep in your bag, or the minimum number of items to have before TSM will send items with this operation."],
	maxQtyEnabled = L["Enables the max quantity setting for specifying the quantity of items to mail to the target character."],
	maxQty = L["Each time the mailing operation is executed, this number of items will be sent."],
	restockEnabled = L["When enabled, the maximum quantity indicates the maximum number of items the target character should have in their inventory."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("MailingOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddDeferredStringField("operationName")
	:AddBooleanField("maxQtyEnabled", false)
	:AddBooleanField("restockEnabled", false)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Mailing, function(db)
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetMailingOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the mailing operation settings frame.
---@param operationName string The current operation name
---@return BaseScrollFrame
function Mailing.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Mailing Operation Settings UI
-- ============================================================================

---@param state MailingOperationsUIState
function private.GetMailingOperationSettings(state, operationName)
	local operationSettings = MailingOperation.GetSettings(operationName)
	state.operationName = operationName
	state.maxQtyEnabled = operationSettings.maxQtyEnabled
	state.restockEnabled = operationSettings.restock
	UIUtils.AnalyticsRecordPathChange("main", "operations", "mailing")
	local maxQtyDisabledPublisher = state:Publisher("maxQtyEnabled")
		:InvertBoolean()
		:Share()
	return UIElements.New("BaseScrollFrame", "content")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "generalOptions")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Adjust how items are mailed."])
			:AddChild(UIElements.New("OperationLinkedMailingTargetInput", "target")
				:SetMargin(0, 0, 0, 12)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "target")
				:SetAutoComplete(PlayerInfo.GetConnectedAlts())
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "keepQty")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Keep this amount"], SETTING_TOOLTIPS.keepQty, MailingOperation.GetSettingRange("keepQty"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "keepQty")
			)
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "maxQtyEnabled")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Set max quantity"], SETTING_TOOLTIPS.maxQtyEnabled)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "maxQtyEnabled")
				:SetAction("OnValueChanged", "ACTION_MAX_QTY_ENABLED_CHANGED")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "maxQty")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Maximum quantity"], SETTING_TOOLTIPS.maxQty, MailingOperation.GetSettingRange("maxQty"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "maxQty")
				:SetDisabled(maxQtyDisabledPublisher)
			)
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "restock")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Restock target to max quantity"], SETTING_TOOLTIPS.restockEnabled)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restock")
				:SetDisabled(maxQtyDisabledPublisher)
				:SetAction("OnValueChanged", "ACTION_RESTOCK_VALUE_CHANGED")
			)
			:AddChild(UIElements.New("OperationLinkedMultiselectionDropdownLine", "restockSources")
				:ConfigureText(L["Sources to include for restock"], L["No Sources"], L["%d Sources"], L["All Sources"], L["Select sources"], SETTING_TOOLTIPS.restockSources)
				:SetItems(RESTOCK_SOURCES_ITEMS, RESTOCK_SOURCES_KEYS)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "restockSources")
				:SetDisabled(state:Publisher([[not restockEnabled or not maxQtyEnabled]]))
			)
		)
		:AddChild(UIElements.New("OperationManagementSettingsFrame", "management")
			:Configure(OPERATION_TYPE_NAME, state.operationName, AddonSettings.GetDB())
			:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
			:SetAction("OnGroupsChanged", "ACTION_GROUPS_CHANGED")
		)
		:AddCancellable(maxQtyDisabledPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MailingOperationsUIState>
---@param state MailingOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_MAX_QTY_ENABLED_CHANGED" then
		local operationSettings = MailingOperation.GetSettings(state.operationName)
		state.maxQtyEnabled = operationSettings.maxQtyEnabled
	elseif action == "ACTION_RESTOCK_VALUE_CHANGED" then
		local operationSettings = MailingOperation.GetSettings(state.operationName)
		state.restockEnabled = operationSettings.restock
	elseif action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		Util.ShowGroupSettings(groupPath)
	elseif action == "ACTION_GROUPS_CHANGED" then
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Sniper = App:Init("MainUI.Operations.Sniper")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
}
local OPERATION_TYPE_NAME = "Sniper"
local MAX_PRICE_BAD_SOURCES = {
	sniperopmax = true,
}
local SETTING_TOOLTIPS = {
	belowPrice = L["The maximum price of an auction to be included in the sniper results."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("SniperOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddOptionalStringField("operationName")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Sniper:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SNIPER_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetSniperOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the sniper operation settings frame.
---@param operationName string The current operation name
---@return BaseScrollFrame
function Sniper.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Sniper Operation Settings UI
-- ============================================================================

---@param state SniperOperationsUIState
---@param operationName string
function private.GetSniperOperationSettings(state, operationName)
	state.operationName = operationName
	UIUtils.AnalyticsRecordPathChange("main", "operations", "sniper")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "generalOptions")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Set what items are shown during a Sniper scan."])
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "belowPrice")
				:ConfigureText(L["Maximum price"], SETTING_TOOLTIPS.belowPrice)
				:SetBadSources(MAX_PRICE_BAD_SOURCES)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "belowPrice")
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

---@param manager UIManager<SniperOperationsUIState>
---@param state SniperOperationsUIState
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

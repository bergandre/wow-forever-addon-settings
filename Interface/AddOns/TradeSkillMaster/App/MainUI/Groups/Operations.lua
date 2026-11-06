-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Operations = App:Init("MainUI.Groups.Operations")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Group = App:From("LibTSMTypes"):Include("Group")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	manager = nil,
	showSettingsCallback = nil,
	typeCollapsed = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("GroupsOperationsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddStringField("groupPath", Group.GetRootPath())
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Operations:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("GROUPS_OPERATIONS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_DRAGGING")
		:AddFrameBuilder(private.GetOperationsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the operations code.
---@param showSettingsCallback fun(typeName: string, operationName: string) The callback to show the settings of an operation
function Operations.Configure(showSettingsCallback)
	private.showSettingsCallback = showSettingsCallback
end

---Gets the groups frame.
---@param groupPath GroupPathValue The current group path
---@return DividedContainer
function Operations.GetFrame(groupPath)
	return private.manager:BuildFrame(groupPath)
end



-- ============================================================================
-- Operations UI
-- ============================================================================

---@param state GroupsOperationsUIState
function private.GetOperationsFrame(state, groupPath)
	state.groupPath = groupPath
	UIUtils.AnalyticsRecordPathChange("main", "groups", "operations")
	return UIElements.New("BaseScrollFrame", "operations")
		:SetPadding(8, 8, 0, 8)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(private.GetModuleOperationFrame("Auctioning", state))
		:AddChild(private.GetModuleOperationFrame("Crafting", state))
		:AddChild(private.GetModuleOperationFrame("Mailing", state))
		:AddChild(private.GetModuleOperationFrame("Shopping", state))
		:AddChild(private.GetModuleOperationFrame("Sniper", state))
		:AddChild(private.GetModuleOperationFrame("Vendoring", state))
		:AddChild(private.GetModuleOperationFrame("Warehousing", state, true))
end

---@param state GroupsOperationsUIState
function private.GetModuleOperationFrame(typeName, state, isLast)
	return UIElements.New("GroupOperationsCollapsibleContainer", "operationInfo"..typeName)
		:SetMargin(0, 0, 0, isLast and 0 or 8)
		:SetContextTable(private.typeCollapsed, typeName)
		:Configure(typeName, state.groupPath)
		:SetAction("OnDraggingUpdate", "ACTION_UPDATE_DRAGGING")
		:SetAction("OnShowSettings", "ACTION_SHOW_SETTINGS")
		:SetAction("OnContentUpdated", "ACTION_REDRAW")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<GroupsOperationsUIState>
---@param state GroupsOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_DRAGGING" then
		state.frame:ScrollForDragging()
	elseif action == "ACTION_SHOW_SETTINGS" then
		local typeName, operationName = ...
		private.showSettingsCallback(typeName, operationName)
	elseif action == "ACTION_REDRAW" then
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

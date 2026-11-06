-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Groups = App:Init("VendoringUI.Groups")
local EnumType = App:From("LibTSMUtil"):Include("BaseType.EnumType")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Group = App:From("LibTSMTypes"):Include("Group")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Vendoring = App:From("LibTSMApp"):Include("Vendoring")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
	groupsTemp = {},
}
local OPERATION = EnumType.New("VENDORING_GROUPS_OPERATION", {
	BUY = EnumType.NewValue(),
	SELL = EnumType.NewValue(),
})
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringGroupsState")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddBooleanField("groupSelectionCleared", true)
	:AddNumberField("numGroups", 0)
	:AddNumberField("numItems", 0)
	:AddOptionalEnumField("operation", OPERATION)
	:Commit()

---@event VendoringGroupsAction
---| "ACTION_GROUP_SELECTION_CHANGED"
---| "ACTION_BUY"
---| "ACTION_SELL"
---| "ACTION_DO_OPERATION" -> operation: EnumValue, isDryRun: boolean
---| "ACTION_OPERATION_DONE"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Groups, function(db)
	private.settings = db:NewView("GroupsSettings")
		:AddKey("char", "vendoringUIContext", "groupTree")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING_GROUPS", state, private.ActionHandler)
		:AddFrameBuilder(private.GetFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the buyback frame.
---@return BaseFrame
function Groups.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Groups UI
-- ============================================================================

---@param state VendoringGroupsState
function private.GetFrame(state)
	UIUtils.AnalyticsRecordPathChange("vendoring", "groups")
	local buttonsDisabledPublisher = state:Publisher([[(groupSelectionCleared or operation) and true or false]])
		:Share()
	local operationPublisher = state:Publisher("operation")
		:Share()
	return UIElements.New("BaseFrame", "groups")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
			:SetOperationType("Vendoring")
			:SetTreeBackgroundColor("surface/main")
			:BindSelectionCleared(state, "groupSelectionCleared")
			:SetSettingsContext(private.settings, "groupTree")
			:BindElement(state, "groupTree")
			:SetAction("OnGroupSelectionChanged", "ACTION_GROUP_SELECTION_CHANGED")
		)
		:AddChild(UIElements.New("BaseFrame", "summary")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetMargin(0, 0, 8, 0)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("Text", "groupsLabel")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Groups"]..":")
			)
			:AddChild(UIElements.New("Text", "groupsValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(state:Publisher("numGroups"):ToStringFormat("%d"))
			)
			:AddChild(UIElements.New("Text", "itemsLabel")
				:SetWidth("AUTO")
				:SetMargin(24, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Items"]..":")
			)
			:AddChild(UIElements.New("Text", "itemsValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(state:Publisher("numItems"):ToStringFormat("%d"))
			)
			:AddChild(UIElements.New("Text", "goldLabel")
				:SetWidth("AUTO")
				:SetMargin(24, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Gold"]..":")
			)
			:AddChild(UIElements.New("PlayerGoldText", "goldValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)
		:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "buyBtn")
				:SetMargin(0, 8, 0, 0)
				:SetText(L["Buy Groups"])
				:SetDisabled(buttonsDisabledPublisher)
				:SetPressed(operationPublisher:ToBooleanEquals(OPERATION.BUY))
				:SetAction("OnClick", "ACTION_BUY")
				:SetTooltip(L["Hold CTRL to perform a dry-run where no items are actually bought, but chat messages will instead list what would be bought."])
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "sellBtn")
				:SetText(L["Sell Groups"])
				:SetModifierText(L["Sell Groups (Dry Run)"], "CTRL")
				:SetDisabled(buttonsDisabledPublisher)
				:SetPressed(operationPublisher:ToBooleanEquals(OPERATION.SELL))
				:SetAction("OnClick", "ACTION_SELL")
				:SetTooltip(L["Hold CTRL to perform a dry-run where no items are actually sold, but chat messages will instead list what would be bought."])
			)
		)
		:AddCancellable(buttonsDisabledPublisher:EndShare())
		:AddCancellable(operationPublisher:EndShare())
		:WithProcessAction("ACTION_GROUP_SELECTION_CHANGED")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringGroupsState>
---@param state VendoringGroupsState
---@param action VendoringGroupsAction
---@param ... params<VendoringGroupsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_GROUP_SELECTION_CHANGED" then
		local numGroups, numItems = 0, 0
		for _, groupPath in state.groupTree:SelectedGroupsIterator() do
			numGroups = numGroups + 1
			if groupPath == Group.GetRootPath() then
				-- TODO
			else
				for _ in Group.ItemIterator(groupPath) do
					numItems = numItems + 1
				end
			end
		end
		state.numGroups = numGroups
		state.numItems = numItems
	elseif action == "ACTION_BUY" then
		return manager:ProcessAction("ACTION_DO_OPERATION", OPERATION.BUY, IsControlKeyDown())
	elseif action == "ACTION_SELL" then
		return manager:ProcessAction("ACTION_DO_OPERATION", OPERATION.SELL, IsControlKeyDown())
	elseif action == "ACTION_DO_OPERATION" then
		local operation, isDryRun = ...
		assert(not state.operation)
		state.operation = operation
		assert(not next(private.groupsTemp))
		for _, groupPath in state.groupTree:SelectedGroupsIterator() do
			tinsert(private.groupsTemp, groupPath)
		end
		if operation == OPERATION.BUY then
			Vendoring.BuyGroups(manager:CallbackToProcessAction("ACTION_OPERATION_DONE"), private.groupsTemp, isDryRun)
		elseif operation == OPERATION.SELL then
			Vendoring.SellGroups(manager:CallbackToProcessAction("ACTION_OPERATION_DONE"), private.groupsTemp, isDryRun)
		else
			error("Unexpected operation: "..tostring(operation))
		end
		wipe(private.groupsTemp)
	elseif action == "ACTION_OPERATION_DONE" then
		state.operation = nil
		Vendoring.StopBuySell()
	else
		error("Unknown action: "..tostring(action))
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Operations = App:Init("MainUI.Operations")
local Auctioning = App:Include("MainUI.Operations.Auctioning")
local Crafting = App:Include("MainUI.Operations.Crafting")
local Mailing = App:Include("MainUI.Operations.Mailing")
local Shopping = App:Include("MainUI.Operations.Shopping")
local Sniper = App:Include("MainUI.Operations.Sniper")
local Vendoring = App:Include("MainUI.Operations.Vendoring")
local Warehousing = App:Include("MainUI.Operations.Warehousing")
local Util = App:Include("MainUI.Operations.Util")
local CallbackRegistry = App:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Group = App:From("LibTSMTypes"):Include("Group")
local GroupOperation = App:From("LibTSMTypes"):Include("GroupOperation")
local Operation = App:From("LibTSMTypes"):Include("Operation")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
	moduleCallbacks = CallbackRegistry.NewWithKeys(), ---@type CallbackRegistry<OperationsUIModuleCallbackFunc>
	numGroupsCache = {},
	numItemsCache = {},
	deleteTemp = {},
}
local VIRTUAL_FIELD_ARG_FIELDS = { "typeName", "operationName" }
local STATE_SCHEMA = Reactive.CreateStateSchema("OperationsUIState")
	:AddDeferredUIElementField("frame", "DividedContainer")
	:AddDeferredUIElementField("searchInput", "Input")
	:AddDeferredUIElementField("operationTree", "OperationTree")
	:AddDeferredUIElementField("content", "ViewContainer")
	:AddDeferredUIElementField("nameText", "EditableText")
	:AddDeferredUIElementField("summaryList", "OperationSummaryScrollTable")
	:AddDeferredUIElementField("settingsContent", "BaseFrame")
	:AddDeferredStringField("typeName")
	:AddDeferredStringField("operationName")
	:AddBooleanField("editingName", false)
	:AddBooleanField("summaryAllSelected", false)
	:AddNumberField("summaryNumSelected", 0)
	:Commit()

---@alias OperationsUIModuleCallbackFunc fun(operationName: string): Element

---@event OperationsUIAction
---| "ACTION_SET_SELECTED_OPERATION" -> typeName: string, operationName: string
---| "ACTION_SEARCH_CHANGED"
---| "ACTION_ADD_OPERATION" -> typeName: string, operationName: string, copyOperationName?: string
---| "ACTION_DELETE_OPERATION" -> typeName: string, operationName: string
---| "ACTION_DELETE_OPERATION_CONFIRMED" -> typeName: string, operationName: string
---| "ACTION_OPERATION_SELECTED" -> typeName?: string, operationName?: string
---| "ACTION_CREATE_OPERATION"
---| "ACTION_RENAME_OPERATION" -> newValue: string
---| "ACTION_START_RENAMING"
---| "ACTION_RESET_OPERATION"
---| "ACTION_RESET_OPERATION_CONFIRMED"
---| "ACTION_HANDLE_SUMMARY_OPERATION_CONFIGURE" -> operationName: string
---| "ACTION_SUMMARY_SELECT_ALL"
---| "ACTION_SUMMARY_CLEAR_ALL"
---| "ACTION_SUMMARY_DELETE_OPERATIONS"
---| "ACTION_SUMMARY_DELETE_OPERATIONS_CONFIRMED"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Operations, function(db)
	private.settings = db:NewView("OperationsSettings")
		:AddKey("global", "mainUIContext", "operationsDividedContainer")
		:AddKey("global", "mainUIContext", "operationsSummaryScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetOperationsFrame)

	private.moduleCallbacks:Add(Auctioning.GetFrame, "Auctioning")
	private.moduleCallbacks:Add(Crafting.GetFrame, "Crafting")
	private.moduleCallbacks:Add(Mailing.GetFrame, "Mailing")
	private.moduleCallbacks:Add(Shopping.GetFrame, "Shopping")
	private.moduleCallbacks:Add(Sniper.GetFrame, "Sniper")
	private.moduleCallbacks:Add(Vendoring.GetFrame, "Vendoring")
	private.moduleCallbacks:Add(Warehousing.GetFrame, "Warehousing")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the operations code.
---@param showGroupSettingsCallback fun(groupPath: GroupPathValue) The callback to show the settings of a group
function Operations.Configure(showGroupSettingsCallback)
	Util.Configure(showGroupSettingsCallback)
end

---Gets the operations frame.
---@return DividedContainer
function Operations.GetFrame()
	return private.manager:BuildFrame()
end

---Sets the selected operation.
---@param typeName string The operation type name
---@param operationName string The operation name
function Operations.SetSelectedOperation(typeName, operationName)
	private.manager:ProcessAction("ACTION_SET_SELECTED_OPERATION", typeName, operationName)
end



-- ============================================================================
-- Operations UI
-- ============================================================================

---@param state OperationsUIState
function private.GetOperationsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "operations")
	return UIElements.New("DividedContainer", "operations")
		:SetSettingsContext(private.settings, "operationsDividedContainer")
		:SetMinWidth(250, 250)
		:HideDivider()
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:SetLeftChild(UIElements.New("BaseFrame", "selection")
			:SetLayout("VERTICAL")
			:SetMargin(0, 3, 0, 0)
			:SetPadding(8)
			:SetRoundedBackgroundColor("container/low")
			:AddChild(UIElements.New("Input", "search")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:BindElement(state, "searchInput")
				:SetLeadIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:AllowItemInsert(true)
				:SetHintText(L["Search Operations"])
				:SetAction("OnValueChanged", "ACTION_SEARCH_CHANGED")
			)
			:AddChild(UIElements.New("OperationTree", "operationTree")
				:BindElement(state, "operationTree")
				:SetAction("OnOperationAdded", "ACTION_ADD_OPERATION")
				:SetAction("OnOperationDeleted", "ACTION_DELETE_OPERATION")
				:SetAction("OnOperationSelected", "ACTION_OPERATION_SELECTED")
			)
		)
		:SetRightChild(UIElements.New("ViewContainer", "content")
			:SetMargin(3, 0, 0, 0)
			:BindElement(state, "content")
			:SetContext(state)
			:SetNavCallback(private.GetOperationsContent)
			:AddPath("none", true)
			:AddPath("summary")
			:AddPath("operation")
		)
end

function private.GetOperationsContent(viewContainer, path)
	local state = viewContainer:GetContext() ---@type OperationsUIState
	if path == "none" then
		return UIElements.New("BaseFrame", "settings")
			:SetLayout("VERTICAL")
			:SetWidth("EXPAND")
			:AddChild(UIElements.New("BaseFrame", "title")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:AddChild(UIElements.New("BaseTexture", "icon")
					:SetMargin(0, 8, 0, 0)
					:SetTextureAndSize(TextureAtlas.GetColoredKey("iconPack.18x18/Operation", "on/surface"))
				)
				:AddChild(UIElements.New("Text", "text")
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(L["No Operation Selected"])
				)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
	elseif path == "summary" then
		return UIElements.New("BaseFrame", "settings")
			:SetLayout("VERTICAL")
			:SetWidth("EXPAND")
			:AddChild(UIElements.New("BaseFrame", "title")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(state:PublisherForFunctionWithKeys(private.TypeNameToSummaryTitle, "typeName"))
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("SmallTertiaryActionButton", "addBtn")
					:SetWidth("AUTO")
					:SetMargin(12, 4, 0, 0)
					:SetPadding(8, 8, 0, 0)
					:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.14x14/Add/Circle", "accent/main")).." "..L["Create New"])
					:SetAction("OnClick", "ACTION_CREATE_OPERATION")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:BindElement(state, "settingsContent")
				-- Will be filled in by the operation selection callback
			)
	elseif path == "operation" then
		return UIElements.New("BaseFrame", "settings")
			:SetLayout("VERTICAL")
			:SetWidth("EXPAND")
			:AddChild(UIElements.New("BaseFrame", "title")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:AddChild(UIElements.New("BaseTexture", "icon")
					:SetMargin(0, 8, 0, 0)
					:SetTextureAndSize(TextureAtlas.GetColoredKey("iconPack.18x18/Operation", "on/surface"))
				)
				:AddChild(UIElements.New("EditableText", "text")
					:AllowItemInsert(true)
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(state:Publisher("operationName"):CoalesceNil(L["No Operation Selected"]))
					:BindElement(state, "nameText")
					:BindEditing(state, "editingName")
					:SetAction("OnValueChanged", "ACTION_RENAME_OPERATION")
				)
				:AddChild(UIElements.New("SmallTertiaryActionButton", "renameBtn")
					:SetWidth("AUTO")
					:SetMargin(4, 0, 0, 0)
					:SetPadding(8, 8, 0, 0)
					:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.14x14/Edit", "accent/main")).." "..L["Rename"])
					:SetShown(state:Publisher("editingName"):InvertBoolean())
					:SetAction("OnClick", "ACTION_START_RENAMING")
				)
				:AddChild(UIElements.New("SmallTertiaryActionButton", "resetBtn")
					:SetWidth("AUTO")
					:SetPadding(8, 8, 0, 0)
					:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey("iconPack.14x14/Reset", "accent/main")).." "..L["Reset"])
					:SetAction("OnClick", "ACTION_RESET_OPERATION")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:BindElement(state, "settingsContent")
				-- Will be filled in by the operation selection callback
			)
	else
		error("Invalid path: "..tostring(path))
	end
end

---@param state OperationsUIState
function private.GetSummaryContent(state)
	wipe(private.numGroupsCache)
	wipe(private.numItemsCache)
	local query = Operation.NewQuery()
		:Equal("typeName", state.typeName)
		:VirtualField("numGroups", "number", private.NumGroupsVirtualField, VIRTUAL_FIELD_ARG_FIELDS)
		:VirtualField("numItems", "number", private.NumItemsVirtualField, VIRTUAL_FIELD_ARG_FIELDS)
	local mostGroupsName, mostGroupsValue = "---", -math.huge
	local leastGroupsName, leastGroupsValue = "---", math.huge
	local mostItemsName, mostItemsValue = "---", -math.huge
	local leastItemsName, leastItemsValue = "---", math.huge
	for _, operationName, numGroups, numItems in query:Iterator("operationName", "numGroups", "numItems") do
		if numGroups > mostGroupsValue then
			mostGroupsValue = numGroups
			mostGroupsName = operationName
		end
		if numGroups < leastGroupsValue then
			leastGroupsValue = numGroups
			leastGroupsName = operationName
		end
		if numItems > mostItemsValue then
			mostItemsValue = numItems
			mostItemsName = operationName
		end
		if numItems < leastItemsValue then
			leastItemsValue = numItems
			leastItemsName = operationName
		end
	end
	local noneSelectedPublisher = state:Publisher("summaryNumSelected")
		:ToBooleanEquals(0)
		:IgnoreDuplicates()
		:Share()
	return UIElements.New("BaseFrame", "summary")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("BaseFrame", "summary")
			:SetLayout("HORIZONTAL")
			:SetHeight(48)
			:SetMargin(8, 8, 0, 16)
			:AddChild(UIElements.New("BaseFrame", "groups")
				:SetLayout("VERTICAL")
				:SetMargin(0, 8, 0, 0)
				:SetPadding(8, 8, 2, 2)
				:SetRoundedBackgroundColor("container/low")
				:AddChild(UIElements.New("BaseFrame", "most")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 4)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["MOST GROUPS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(mostGroupsName)
					)
				)
				:AddChild(UIElements.New("BaseFrame", "least")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["LEAST GROUPS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(leastGroupsName)
					)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "items")
				:SetLayout("VERTICAL")
				:SetPadding(8, 8, 2, 2)
				:SetRoundedBackgroundColor("container/low")
				:AddChild(UIElements.New("BaseFrame", "most")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 4)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["MOST ITEMS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(mostItemsName)
					)
				)
				:AddChild(UIElements.New("BaseFrame", "least")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["LEAST ITEMS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(leastItemsName)
					)
				)
			)
		)
		:AddChild(UIElements.New("ListContainer", "table")
			:SetMargin(8, 8, 0, 0)
			:AddChild(UIElements.New("OperationSummaryScrollTable", "list")
				:BindElement(state, "summaryList")
				:BindSelectionstate(state, "summaryNumSelected", "summaryAllSelected")
				:SetSettings(private.settings, "operationsSummaryScrollingTable")
				:SetQuery(query)
				:SetAction("OnOperationConfigure", "ACTION_HANDLE_SUMMARY_OPERATION_CONFIGURE")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:AddChild(UIElements.New("SmallPrimaryActionButton", "deleteSelected")
				:SetMargin(0, 8, 0, 0)
				:SetText(state:Publisher("summaryNumSelected"):ToStringFormat(L["Delete %d Operation(s)"]))
				:SetDisabled(noneSelectedPublisher)
				:SetAction("OnClick", "ACTION_SUMMARY_DELETE_OPERATIONS")
			)
			:AddChild(UIElements.New("SmallTertiaryActionButton", "selectAll")
				:SetWidth("AUTO")
				:SetPadding(16, 16, 0, 0)
				:SetMargin(0, 4, 0, 0)
				:SetText(L["Select All"])
				:SetDisabled(state:Publisher("summaryAllSelected"))
				:SetAction("OnClick", "ACTION_SUMMARY_SELECT_ALL")
			)
			:AddChild(UIElements.New("SmallTertiaryActionButton", "clearAll")
				:SetWidth("AUTO")
				:SetPadding(16, 16, 0, 0)
				:SetText(L["Clear All"])
				:SetDisabled(noneSelectedPublisher)
				:SetAction("OnClick", "ACTION_SUMMARY_CLEAR_ALL")
			)
		)
		:AddCancellable(noneSelectedPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<OperationsUIState>
---@param state OperationsUIState
---@param action OperationsUIAction
---@param ... params<OperationsUIAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_SELECTED_OPERATION" then
		local typeName, operationName = ...
		state.operationTree:SetSelectedOperation(typeName, operationName)
	elseif action == "ACTION_SEARCH_CHANGED" then
		state.operationTree:SetOperationNameFilter(strlower(state.searchInput:GetValue()))
	elseif action == "ACTION_ADD_OPERATION" then
		local typeName, operationName, copyOperationName = ...
		-- Clear the filter
		state.searchInput
			:SetValue("")
			:Draw()
		state.operationTree:SetOperationNameFilter("")
		Operation.Create(typeName, operationName)
		if copyOperationName then
			Operation.Copy(typeName, operationName, copyOperationName)
		end
	elseif action == "ACTION_DELETE_OPERATION" then
		local typeName, operationName = ...
		state.frame:GetBaseElement():ShowConfirmationDialog(L["Delete Operation?"], L["Are you sure you want to delete this operation?"], manager:CallbackToProcessAction("ACTION_DELETE_OPERATION_CONFIRMED"), typeName, operationName)
	elseif action == "ACTION_DELETE_OPERATION_CONFIRMED" then
		local typeName, operationName = ...
		GroupOperation.DeleteOperation(typeName, operationName)
		state.operationTree:SetSelectedOperation(typeName, nil)
	elseif action == "ACTION_OPERATION_SELECTED" then
		local typeName, operationName = ...
		if typeName and operationName then
			state.typeName = typeName
			state.operationName = operationName
			Operation.UpdateFromRelationships(typeName, operationName)
			state.content:SetPath("operation")
			state.settingsContent:ReleaseAllChildren()
			state.settingsContent:AddChild(private.moduleCallbacks:Call(typeName, operationName))
		elseif typeName then
			state.typeName = typeName
			UIUtils.AnalyticsRecordPathChange("main", "operations", "summary")
			state.content:SetPath("summary")
			state.operationName = nil
			state.settingsContent:ReleaseAllChildren()
			state.settingsContent:AddChild(private.GetSummaryContent(state))
		else
			UIUtils.AnalyticsRecordPathChange("main", "operations", "none")
			state.content:SetPath("none")
			state.typeName = nil
			state.operationName = nil
		end
		state.content:Draw()
	elseif action == "ACTION_CREATE_OPERATION" then
		local operationName = Operation.GetDeduplicatedName(state.typeName, L["New Operation"])
		Operation.Create(state.typeName, operationName)
		state.operationTree:SetSelectedOperation(state.typeName, operationName)
	elseif action == "ACTION_RENAME_OPERATION" then
		local newValue = ...
		newValue = strtrim(newValue)
		assert(state.operationName)
		if newValue == state.operationName then
			-- Didn't change
			state.nameText:Draw()
		elseif newValue == "" then
			ChatMessage.PrintUser(L["Invalid operation name."])
			state.nameText:Draw()
		elseif Operation.Exists(state.typeName, newValue) then
			ChatMessage.PrintUser(L["Operation already exists."])
			state.nameText:Draw()
		else
			GroupOperation.RenameOperation(state.typeName, state.operationName, newValue)
			state.operationTree:SetSelectedOperation(state.typeName, newValue)
		end
	elseif action == "ACTION_START_RENAMING" then
		state.nameText:SetEditing(true)
	elseif action == "ACTION_RESET_OPERATION" then
		state.frame:GetBaseElement():ShowConfirmationDialog(L["Reset Operation?"], L["Resetting the operation will return all inputs back to default and cannot be undone. Click confirm to reset."], manager:CallbackToProcessAction("ACTION_RESET_OPERATION_CONFIRMED"))
	elseif action == "ACTION_RESET_OPERATION_CONFIRMED" then
		assert(state.operationName)
		Operation.Reset(state.typeName, state.operationName)
		state.settingsContent:ReleaseAllChildren()
		Operation.UpdateFromRelationships(state.typeName, state.operationName)
		state.settingsContent:AddChild(private.moduleCallbacks:Call(state.typeName, state.operationName))
		state.frame:GetBaseElement():HideDialog()
		local parent = state.settingsContent:GetParentElement()
		assert(parent)
		parent:Draw()
		ChatMessage.PrintfUser(L["%s - %s has been reset to default values."], state.typeName, Theme.GetColor("accent/main"):ColorText(state.operationName))
	elseif action == "ACTION_HANDLE_SUMMARY_OPERATION_CONFIGURE" then
		local operationName = ...
		state.operationTree:SetSelectedOperation(state.typeName, operationName)
	elseif action == "ACTION_SUMMARY_SELECT_ALL" then
		state.summaryList:SetSelectionState(true)
	elseif action == "ACTION_SUMMARY_CLEAR_ALL" then
		state.summaryList:SetSelectionState(false)
	elseif action == "ACTION_SUMMARY_DELETE_OPERATIONS" then
		state.frame:GetBaseElement():ShowConfirmationDialog(L["Delete Operations?"], L["Are you sure you want to delete the selected operations?"], manager:CallbackToProcessAction("ACTION_SUMMARY_DELETE_OPERATIONS_CONFIRMED"))
	elseif action == "ACTION_SUMMARY_DELETE_OPERATIONS_CONFIRMED" then
		assert(not next(private.deleteTemp))
		for operationName in state.summaryList:SelectedOperationsIterator() do
			tinsert(private.deleteTemp, operationName)
		end
		GroupOperation.DeleteOperations(state.typeName, private.deleteTemp)
		wipe(private.deleteTemp)
		state.operationTree:SetSelectedOperation(state.typeName, nil)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.TypeNameToSummaryTitle(typeName)
	return format(L["%s %s Operations"], Theme.GetColor("accent/main"):ColorText(Operation.GetNumber(typeName)), typeName)
end

function private.NumGroupsVirtualField(typeName, operationName)
	if not private.numGroupsCache[operationName] then
		local num = 0
		for _ in GroupOperation.GroupIteratorByOperation(typeName, operationName) do
			num = num + 1
		end
		private.numGroupsCache[operationName] = num
	end
	return private.numGroupsCache[operationName]
end

function private.NumItemsVirtualField(typeName, operationName)
	if not private.numItemsCache[operationName] then
		local includesBaseGroup = false
		local num = 0
		for _, groupPath in GroupOperation.GroupIteratorByOperation(typeName, operationName) do
			if groupPath == Group.GetRootPath() then
				includesBaseGroup = true
			else
				num = num + Group.GetNumItems(groupPath)
			end
		end
		if includesBaseGroup then
			num = num + 0.9
		end
		private.numItemsCache[operationName] = num
	end
	return private.numItemsCache[operationName]
end

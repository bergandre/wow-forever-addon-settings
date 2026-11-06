-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Items = App:Init("MainUI.Groups.Items")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local SmartMap = App:From("LibTSMUtil"):IncludeClassType("SmartMap")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local Group = App:From("LibTSMTypes"):Include("Group")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local ItemFilter = App:From("LibTSMService"):IncludeClassType("ItemFilter")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Analytics = App:From("LibTSMService"):Include("Util.Analytics")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
	itemFilter = ItemFilter.New(),
	itemFilterSmartMap = nil,
	ungroupedItemStringSmartMap = nil,
	itemsTemp = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("GroupsItemsUIState")
	:AddDeferredUIElementField("frame", "BaseFrame")
	:AddDeferredUIElementField("ungroupedItemList", "ItemList")
	:AddDeferredUIElementField("groupedItemList", "ItemList")
	:AddOptionalUIElementField("removeButton", "ActionButton")
	:AddStringField("groupPath", Group.GetRootPath())
	:AddBooleanField("hasParent", false)
	:AddStringField("itemFilter", "")
	:AddNumberField("ungroupedNumSelected", 0)
	:AddNumberField("groupedNumSelected", 0)
	:Commit()

---@event GroupsItemsAction
---| "ACTION_HANDLE_ITEM_SEARCH_CHANGED"
---| "ACTION_TOGGLE_SELECT_ALL_UNGROUPED"
---| "ACTION_TOGGLE_SELECT_ALL_GROUPED"
---| "ACTION_ADD_ITEMS"
---| "ACTION_REMOVE_ITEMS"



-- ============================================================================
-- Module Loading
-- ============================================================================

Items:OnModuleLoad(function()
	private.itemFilter:ParseStr("")
	private.itemFilterSmartMap = SmartMap.New("string", "boolean", private.ItemFilterLookup)
	private.ungroupedItemStringSmartMap = SmartMap.New("string", "string", private.UngroupedItemStringLookup)
end)

AddonSettings.RegisterOnLoad(Items, function(db)
	private.settings = db:NewView("ItemsSettings")
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "userData", "ungroupedItemMode")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("GROUPS_ITEMS", state, private.ActionHandler)
		:AddFrameBuilder(private.GetItemsFrame)

	-- Set up some computed properties
	private.manager:SetStateFromPublisher("hasParent", state:PublisherForFunctionWithKeys(Group.GetParent, "groupPath")
		:ToBooleanNotEquals(Group.GetRootPath())
	)

	private.manager:AddCancellable(private.settings:PublisherForKey("ungroupedItemMode")
		:CallFunction(function() private.ungroupedItemStringSmartMap:Invalidate() end)
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the items frame.
---@param groupPath GroupPathValue The group path
---@return BaseFrame
function Items.GetFrame(groupPath)
	return private.manager:BuildFrame(groupPath)
end



-- ============================================================================
-- Items UI
-- ============================================================================

---@param state GroupsItemsUIState
function private.GetItemsFrame(state, groupPath)
	assert(groupPath ~= Group.GetRootPath())
	state.groupPath = groupPath
	private.itemFilter:ParseStr("")
	private.itemFilterSmartMap:Invalidate()
	private.ungroupedItemStringSmartMap:Invalidate()
	state.groupedNumSelected = 0
	state.ungroupedNumSelected = 0
	UIUtils.AnalyticsRecordPathChange("main", "groups", "items")
	local groupedNumSelectedPublisher = state:Publisher("groupedNumSelected")
		:Share()
	local ungroupedNumSelectedPublisher = state:Publisher("ungroupedNumSelected")
		:Share()
	local frame = UIElements.New("BaseFrame", "items")
		:SetLayout("VERTICAL")
		:SetPadding(8, 8, 0, 8)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("Input", "filter")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:SetLeadIconTexture("iconPack.18x18/Search")
			:SetClearButtonEnabled(true)
			:SetValidateFunc(ItemFilter.ValidateStr)
			:SetHintText(L["Search items in group"])
			:BindValue(state, "itemFilter")
			:SetAction("OnValueChanged", "ACTION_HANDLE_ITEM_SEARCH_CHANGED")
		)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("Text", "text")
				:SetSize("AUTO", 24)
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_SMALL")
				:SetText(L["Show ungrouped items as:"])
			)
			:AddChild(UIElements.New("SelectionDropdown", "itemMode")
				:SetHeight(24)
				:AddItem(L["Specific Item"], "specific")
				:AddItem(L["Item Level"], "level")
				:AddItem(L["Base Item"], "base")
				:SetHintText(L["Select item type"])
				:SetSettingInfo(private.settings, "ungroupedItemMode")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:AddChild(UIElements.New("BaseFrame", "ungrouped")
				:SetLayout("VERTICAL")
				:SetMargin(0, 8, 0, 0)
				:AddChild(UIElements.New("ListContainer", "content")
					:AddHeader(UIElements.New("BaseFrame", "header")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:AddChild(UIElements.New("Text", "text")
							:SetMargin(8, 0, 4, 4)
							:SetFont("BODY_SMALL_SEMIBOLD")
							:SetText(L["Ungrouped Items"])
						)
						:AddChild(UIElements.New("BaseButton", "selectAllBtn")
							:SetSize(20, 20)
							:SetMargin(8, 4, 0, 0)
							:SetBackground("iconPack.18x18/Select All")
							:SetAction("OnClick", "ACTION_TOGGLE_SELECT_ALL_UNGROUPED")
							:SetTooltip(L["Select / Deselect All Items"])
						)
					)
					:AddChild(UIElements.New("ItemList", "itemList")
						:SetMargin(0, 0, 0, 4)
						:AddSectionQuery(Theme.GetColor("accent/main"):ColorText(L["Ungrouped Items in Bags"]), private.CreateUngroupedBagItemQueryAndGetFields())
						:BindElement(state, "ungroupedItemList")
						:BindNumSelected(state, "ungroupedNumSelected")
					)
				)
				:AddChild(UIElements.New("MediumPrimaryActionButton", "btn")
					:SetMargin(0, 0, 10, 0)
					:SetText(ungroupedNumSelectedPublisher:ToStringFormat(L["Add %d |4Item:Items"]))
					:SetDisabled(ungroupedNumSelectedPublisher:ToBooleanEquals(0))
					:SetAction("OnClick", "ACTION_ADD_ITEMS")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "grouped")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("ListContainer", "content")
					:AddHeader(UIElements.New("BaseFrame", "header")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:AddChild(UIElements.New("Text", "text")
							:SetMargin(8, 0, 4, 4)
							:SetFont("BODY_SMALL_SEMIBOLD")
							:SetText(L["Grouped Items"])
						)
						:AddChild(UIElements.New("BaseButton", "selectAllBtn")
							:SetSize(20, 20)
							:SetMargin(8, 4, 0, 0)
							:SetBackground("iconPack.18x18/Select All")
							:SetAction("OnClick", "ACTION_TOGGLE_SELECT_ALL_GROUPED")
							:SetTooltip(L["Select / Deselect All Items"])
						)
					)
					:AddChild(UIElements.New("ItemList", "itemList")
						:SetMargin(0, 0, 0, 4)
						:SetSingleQuery(private.CreateGroupedItemQueryAndGetFields(state.groupPath))
						:BindElement(state, "groupedItemList")
						:BindNumSelected(state, "groupedNumSelected")
					)
				)
				:AddChild(UIElements.New("MediumPrimaryActionButton", "btn")
					:SetMargin(0, 0, 10, 0)
					:SetText(groupedNumSelectedPublisher:ToStringFormat(L["Remove %d |4Item:Items"]))
					:SetDisabled(groupedNumSelectedPublisher:ToBooleanEquals(0))
					:BindElement(state, "removeButton")
					:SetAction("OnClick", "ACTION_REMOVE_ITEMS")
					:SetTooltip(state.hasParent and L["Hold shift to move the items to the parent group instead of removing them."] or nil)
				)
			)
		)
	if state.hasParent then
		assert(state.removeButton)
		state.ungroupedItemList:AddSectionQuery(Theme.GetColor("accent/main"):ColorText(L["Parent Items"]), private.CreateParentGroupItemQueryAndGetFields(state.groupPath))
		state.removeButton:SetModifierText(groupedNumSelectedPublisher:ToStringFormat(L["Move %d |4Item:Items"]), "SHIFT")
	end
	frame:AddCancellable(groupedNumSelectedPublisher:EndShare())
	frame:AddCancellable(ungroupedNumSelectedPublisher:EndShare())
	return frame
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<GroupsItemsUIState>
---@param state GroupsItemsUIState
---@param action GroupsItemsAction
---@param ... params<GroupsItemsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_SEARCH_CHANGED" then
		local isValid = private.itemFilter:ParseStr(state.itemFilter)
		assert(isValid)
		private.itemFilterSmartMap:Invalidate()
	elseif action == "ACTION_TOGGLE_SELECT_ALL_UNGROUPED" then
		state.ungroupedItemList:ToggleSelectAll()
	elseif action == "ACTION_TOGGLE_SELECT_ALL_GROUPED" then
		state.groupedItemList:ToggleSelectAll()
	elseif action == "ACTION_ADD_ITEMS" then
		assert(not next(private.itemsTemp))
		state.ungroupedItemList:GetSelectedItems(private.itemsTemp)
		Group.SetItemsGroup(private.itemsTemp, state.groupPath)
		Analytics.Action("ADDED_GROUP_ITEMS", state.groupPath, #private.itemsTemp)
		Table.WipeAndDeallocate(private.itemsTemp)
	elseif action == "ACTION_REMOVE_ITEMS" then
		local targetGroup = IsShiftKeyDown() and state.hasParent and Group.GetParent(state.groupPath) or nil
		assert(not next(private.itemsTemp))
		state.groupedItemList:GetSelectedItems(private.itemsTemp)
		Group.SetItemsGroup(private.itemsTemp, targetGroup)
		Analytics.Action("REMOVED_GROUP_ITEMS", state.groupPath, #private.itemsTemp, targetGroup or "")
		Table.WipeAndDeallocate(private.itemsTemp)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UngroupedItemStringLookup(itemString)
	if private.settings.ungroupedItemMode == "level" then
		return ItemString.ToLevel(itemString)
	elseif private.settings.ungroupedItemMode == "base" then
		return ItemString.GetBaseFast(itemString)
	elseif private.settings.ungroupedItemMode == "specific" then
		return itemString
	else
		error("Invalid ungrouped item mode: "..tostring(private.settings.ungroupedItemMode))
	end
end

function private.ItemFilterLookup(itemString)
	local basePrice = CustomString.GetValue(private.settings.groupPriceSource, itemString)
	return private.itemFilter:Matches(itemString, basePrice)
end

function private.CreateGroupedItemQueryAndGetFields(groupPath)
	local query = Group.CreateItemsQuery(groupPath, true)
	return private.PrepareQueryAndGetFields(query, "itemString")
end

function private.CreateUngroupedBagItemQueryAndGetFields()
	local query = BagTracking.CreateQueryBags()
		:Equal("isBound", false)
		:VirtualSmartMapField("ungroupedItemString", private.ungroupedItemStringSmartMap, "itemString")
		:Distinct("ungroupedItemString")
		:LeftJoin(Group.GetItemDBForJoin(), "ungroupedItemString", "itemString")
		:IsNil("groupPath")
	return private.PrepareQueryAndGetFields(query, "ungroupedItemString")
end

function private.CreateParentGroupItemQueryAndGetFields(groupPath)
	local parentGroupPath = Group.GetParent(groupPath)
	assert(parentGroupPath)
	local query = Group.CreateItemsQuery(parentGroupPath, false)
	return private.PrepareQueryAndGetFields(query, "itemString")
end

---@param query DatabaseQuery
function private.PrepareQueryAndGetFields(query, itemStringField)
	query
		:VirtualField("name", "string", ItemInfo.GetName, itemStringField, "?")
		:VirtualField("texture", "number", ItemInfo.GetTexture, itemStringField, ItemInfo.GetTexture(ItemString.GetUnknown()))
		:VirtualField("coloredItemName", "string", UIUtils.GetDisplayItemName, itemStringField, Theme.GetColor("error/main"):ColorText("?"))
		:VirtualSmartMapField("matchesFilter", private.itemFilterSmartMap, itemStringField)
		:Equal("matchesFilter", true)
		:OrderBy("name", true)
	return query, itemStringField, "texture", "coloredItemName"
end

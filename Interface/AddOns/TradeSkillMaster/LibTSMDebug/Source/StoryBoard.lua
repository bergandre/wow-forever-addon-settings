-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMDebug = select(2, ...).LibTSMDebug
local StoryBoard = LibTSMDebug:InitInternal("StoryBoard")
local Math = LibTSMDebug:From("LibTSMUtil"):Include("Lua.Math")
local SmartMap = LibTSMDebug:From("LibTSMUtil"):IncludeClassType("SmartMap")
local Reactive = LibTSMDebug:From("LibTSMReactive"):Include("Reactive")
local UIManager = LibTSMDebug:From("LibTSMReactive"):IncludeClassType("UIManager")
local Database = LibTSMDebug:From("LibTSMDatabase"):Include("Database")
local ItemInfo = LibTSMDebug:From("LibTSMService"):Include("Item.ItemInfo")
local ItemString = LibTSMDebug:From("LibTSMTypes"):Include("Item.ItemString")
local Profession = LibTSMDebug:From("LibTSMService"):Include("Profession")
local UIElements = LibTSMDebug:From("LibTSMUI"):Include("UIElements")
local UIUtils = LibTSMDebug:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = LibTSMDebug:From("LibTSMApp"):Include("Service.AddonSettings")
local SlashCommands = LibTSMDebug:From("LibTSMApp"):Include("Service.SlashCommands")
local private = {
	manager = nil,
	settings = nil,
	dividedContainerContext = {},
	itemListDB = nil,
	itemListShownSmartMap = nil,
	itemListMode = 2,
}
local MIN_FRAME_SIZE = { width = 400, height = 300 }
local DEFAULT_DIVIDED_CONTAINER_CONTEXT = { leftWidth = 200 }
local STATE_SCHEMA = Reactive.CreateStateSchema("StoryboardUIState")
	:AddOptionalUIElementField("frame", "ApplicationFrame")
	:AddDeferredUIElementField("content", "ViewContainer")
	:AddStringField("selectedPage", "actionButton")
	:AddBooleanField("itemFilterMode", true)
	:Commit()
local ITEM_SELECTOR_ITEMS = (LibTSMDebug.IsRetail() or LibTSMDebug.IsForever()) and {"i:2770", "i:2771", "i:2772", "i:3858", "i:10620", "i:189143", "i:188658", "i:190311", "i:190312", "i:190313", "i:190314"} or {"i:2770", "i:2771", "i:2772", "i:3858", "i:10620"}
local ITEM_LIST_ITEMS = {
	{"i:191461", 2}, -- Hochenblume Q2
	{"i:191462", 0}, -- Hochenblume Q3
	{"i:191464", 0}, -- Saxifrage Q1
	{"i:191465", 0}, -- Saxifrage Q2
	{"i:191466", 0}, -- Saxifrage Q3
	{"i:194862", 0}, -- Runed Writhebark Q1
	{"i:194863", 0}, -- Runed Writhebark Q2
	{"i:194864", 0}, -- Runed Writhebark Q3
}
local GRAPH_DATA_POINTS = {
	1200, 1280, 1240, 1360, 1520, 1460, 1610, 1690, 1650, 1820,
	1990, 1910, 2140, 2310, 2260, 2500, 2430, 2120, 1980, 2260,
	2560, 2830, 3010, 2920, 3200, 3480, 3390, 3730, 3960, 3880, 4300,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(StoryBoard, function(db)
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("STORY_BOARD", state, private.ActionHandler)

	private.settings = db:NewView("StoryBoardSettings")
		:AddKey("global", "storyBoardUIContext", "frame")
		:Commit()
	SlashCommands.RegisterDebug("sb", private.manager:CallbackToProcessAction("ACTION_TOGGLE"))
end)

StoryBoard:OnModuleLoad(function()
	private.itemListDB = Database.NewSchema("SB_ITEM_LIST")
		:AddStringField("itemString")
		:AddNumberField("mode")
		:Commit()
	private.itemListDB:BulkInsertStart()
	for _, data in ipairs(ITEM_LIST_ITEMS) do
		private.itemListDB:BulkInsertNewRow(unpack(data))
	end
	private.itemListDB:BulkInsertEnd()
	private.itemListShownSmartMap = SmartMap.New("number", "boolean", function(mode) return mode == 0 or mode == private.itemListMode end)
end)

StoryBoard:OnModuleUnload(function()
	private.manager:ProcessAction("ACTION_ON_DISABLE")
end)



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<StoryboardUIState>
---@param state StoryboardUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW" then
		assert(not state.frame)
		private.CreateMainFrame(state)
			:Show()
			:Draw()
		assert(state.frame)
	elseif action == "ACTION_FRAME_ON_HIDE" then
		assert(state.frame)
		state.frame:Release()
		assert(not state.frame)
	elseif action == "ACTION_TOGGLE" then
		if state.frame then
			state.frame:Hide()
		else
			return manager:ProcessAction("ACTION_FRAME_SHOW")
		end
	elseif action == "ACTION_ON_DISABLE" then
		if state.frame then
			state.frame:Hide()
		end
	elseif action == "ACTION_SHOW_ACTION_BUTTON_PAGE" then
		state.content:SetPath("actionButton", true)
	elseif action == "ACTION_SHOW_BASE_BUTTON_PAGE" then
		state.content:SetPath("baseButton", true)
	elseif action == "ACTION_SHOW_ITEM_SELECTOR_PAGE" then
		state.content:SetPath("itemSelector", true)
	elseif action == "ACTION_SHOW_CRAFT_TIER_BUTTON_PAGE" then
		state.content:SetPath("craftTierButton", true)
	elseif action == "ACTION_SHOW_GRAPH_PAGE" then
		state.content:SetPath("graph", true)
	elseif action == "ACTION_SHOW_COMBO_BOX_PAGE" then
		state.content:SetPath("comboBox", true)
	elseif action == "ACTION_SHOW_ITEM_LIST_PAGE" then
		state.content:SetPath("itemList", true)
	elseif action == "ACTION_HANDLE_BUTTON_CLICK" then
		print("Click!", ...)
	elseif action == "ACTION_HANDLE_SELECTION_CHANGED" then
		print("SELECTED", ...)
	elseif action == "ACTION_UPDATE_ITEM_LIST_MODE" then
		private.itemListMode = state.itemFilterMode and 2 or 1
		private.itemListShownSmartMap:Invalidate()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state StoryboardUIState
function private.CreateMainFrame(state)
	state.selectedPage = "actionButton"
	local selectedPagePublisher = state:Publisher("selectedPage")
		:Share()
	return UIElements.New("ApplicationFrame", "base")
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetTitle("TSM Story Board")
		:SetScript("OnHide", private.FrameOnHide)
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:SetContentFrame(UIElements.New("DividedContainer", "container")
			:SetContextTable(private.dividedContainerContext, DEFAULT_DIVIDED_CONTAINER_CONTEXT)
			:SetBackgroundColor("container/lowest")
			:SetMinWidth(100, 100)
			:SetLeftChild(UIElements.New("BaseScrollFrame", "left")
				:SetBackgroundColor("container/lowest")
				:AddChild(UIElements.New("Text", "controlsHeading")
					:SetHeight(20)
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetText("Controls")
				)
				:AddChild(UIElements.New("BaseButton", "actionButton")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetText("ActionButton")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("actionButton"))
					:SetAction("OnClick", "ACTION_SHOW_ACTION_BUTTON_PAGE")
				)
				:AddChild(UIElements.New("BaseButton", "button")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetText("BaseButton")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("baseButton"))
					:SetAction("OnClick", "ACTION_SHOW_BASE_BUTTON_PAGE")
				)
				:AddChild(UIElements.New("BaseButton", "itemSelector")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetText("Item Selector")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("itemSelector"))
					:SetAction("OnClick", "ACTION_SHOW_ITEM_SELECTOR_PAGE")
				)
				:AddChild(UIElements.New("BaseButton", "craftTierButton")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetDisabled(not Profession.HasScanned())
					:SetText("CraftTierButton")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("craftTierButton"))
					:SetAction("OnClick", "ACTION_SHOW_CRAFT_TIER_BUTTON_PAGE")
				)
				:AddChild(UIElements.New("BaseButton", "graph")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetText("Graph")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("graph"))
					:SetAction("OnClick", "ACTION_SHOW_GRAPH_PAGE")
				)
				:AddChild(UIElements.New("BaseButton", "comboBox")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetText("ComboBox")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("comboBox"))
					:SetAction("OnClick", "ACTION_SHOW_COMBO_BOX_PAGE")
				)
				:AddChild(UIElements.New("Text", "listTableHeading")
					:SetHeight(20)
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetText("Lists / Tables")
				)
				:AddChild(UIElements.New("BaseButton", "itemList")
					:SetHeight(20)
					:SetPadding(24, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("LEFT")
					:SetBackground("container/lowest", true)
					:SetText("ItemList")
					:SetHighlightLocked(selectedPagePublisher:ToBooleanEquals("itemList"))
					:SetAction("OnClick", "ACTION_SHOW_ITEM_LIST_PAGE")
				)
			)
			:SetRightChild(UIElements.New("ViewContainer", "right")
				:SetPadding(16)
				:SetContext(state)
				:BindElement(state, "content")
				:SetNavCallback(private.GetContentFrame)
				:AddPath("actionButton")
				:AddPath("baseButton")
				:AddPath("itemSelector")
				:AddPath("craftTierButton")
				:AddPath("graph")
				:AddPath("comboBox")
				:AddPath("itemList")
				:SetPath(state.selectedPage)
			)
		)
		:AddCancellable(selectedPagePublisher:EndShare())
end

function private.GetContentFrame(viewContainer, path)
	local state = viewContainer:GetContext() ---@type StoryboardUIState
	state.selectedPage = path
	if path == "actionButton" then
		return private.CreateActionButtonPage()
	elseif path == "baseButton" then
		return private.CreateBaseButtonPage()
	elseif path == "itemSelector" then
		return private.CreateItemSelectorPage()
	elseif path == "craftTierButton" then
		return private.CreateCraftTierButtonPage()
	elseif path == "graph" then
		return private.CreateGraphPage()
	elseif path == "comboBox" then
		return private.CreateComboBoxPage()
	elseif path == "itemList" then
		return private.CreateItemListPage(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

function private.CreateActionButtonPage()
	return UIElements.New("BaseFrame", "actionButton")
		:SetLayout("VERTICAL")
		:AddChild(private.CreateActionButtonRow("MediumPrimaryActionButton", "primaryMedium", "Primary Medium"))
		:AddChild(private.CreateActionButtonRow("SmallPrimaryActionButton", "primarySmall", "Primary Small"))
		:AddChild(UIElements.New("HorizontalLine", "line1")
			:SetMargin(0, 0, 4, 4)
		)
		:AddChild(private.CreateActionButtonRow("MediumSecondaryActionButton", "secondaryMedium", "Secondary Medium"))
		:AddChild(private.CreateActionButtonRow("SmallSecondaryActionButton", "secondarySmall", "Secondary Small"))
		:AddChild(UIElements.New("HorizontalLine", "line2")
			:SetMargin(0, 0, 4, 4)
		)
		:AddChild(private.CreateActionButtonRow("MediumTertiaryActionButton", "tertiaryMedium", "Tertiary Medium"))
		:AddChild(private.CreateActionButtonRow("SmallTertiaryActionButton", "tertiarySmall", "Tertiary Small"))
		:AddChild(UIElements.New("HorizontalLine", "line3")
			:SetMargin(0, 0, 16, 0)
		)
		:AddChild(private.CreateActionButton("MediumPrimaryActionButton", "modifier", "Modifier Button (Shift Not Pressed)")
			:SetMargin(0, 0, 16, 0)
			:SetModifierText("Modifier Button (Shift Pressed)", "SHIFT")
		)
		:AddChild(private.CreateActionButton("MediumPrimaryActionButton", "cooldown", "No Click Cooldown")
			:SetMargin(0, 0, 16, 0)
			:DisableClickCooldown()
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
end

function private.CreateActionButtonRow(elementType, id, label)
	return UIElements.New("BaseFrame", id)
		:SetLayout("HORIZONTAL")
		:SetHeight(40)
		:AddChild(UIElements.New("Text", "heading")
			:SetWidth("AUTO")
			:SetFont("BODY_XSMALL")
			:SetJustifyH("LEFT")
			:SetText(label..":")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(private.CreateActionButton(elementType, id.."Active", "Active")
			:SetWidth(80)
			:SetMargin(8, 8, 0, 0)
		)
		:AddChild(private.CreateActionButton(elementType, id.."Disabled", "Disabled")
			:SetWidth(80)
			:SetMargin(8, 8, 0, 0)
			:SetDisabled(true)
		)
		:AddChild(private.CreateActionButton(elementType, id.."Pressed", "Pressed")
			:SetWidth(80)
			:SetMargin(8, 8, 0, 0)
			:SetPressed(true)
		)
end

---@generic T: ActionButton
---@param elementType `T`
---@return T
function private.CreateActionButton(elementType, id, text)
	return UIElements.New(elementType, id)
		:SetText(text)
		:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
end

function private.CreateBaseButtonPage()
	return UIElements.New("BaseFrame", "baseButton")
		:SetLayout("VERTICAL")
		:AddChild(private.CreateButton("colored")
			:SetBackground("container/highest")
			:SetText("Solid Color")
		)
		:AddChild(private.CreateButton("coloredHighlight")
			:SetBackground("container/highest", true)
			:SetText("Solid Color with Highlight")
		)
		:AddChild(private.CreateButton("iconLeft")
			:SetIcon("iconPack.14x14/Add/Circle", "LEFT")
			:SetText("Button With Left Icon")
		)
		:AddChild(UIElements.New("BaseFrame", "iconRow")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 32, 0)
			:AddChild(UIElements.New("Spacer", "spacer1"))
			:AddChild(UIElements.New("BaseButton", "icon")
				:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
				:SetBackgroundAndSize("iconPack.14x14/Attention")
			)
			:AddChild(UIElements.New("Spacer", "spacer2"))
			:AddChild(UIElements.New("BaseButton", "texture")
				:SetSize(24, 24)
				:SetBackground(136254)
				:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
			)
			:AddChild(UIElements.New("Spacer", "spacer3"))
		)
		:AddChildIf(LibTSMDebug.IsRetail() or LibTSMDebug.IsForever(), UIElements.New("BaseFrame", "itemButtonRow")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 32, 0)
			:AddChild(UIElements.New("Spacer", "spacer1"))
			:AddChild(UIElements.New("ItemIconButton", "itemButton")
				:SetSize(40, 40)
				:SetMargin(0, 16, 32, 0)
				:SetItem("i:198414")
				:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
			)
			:AddChild(UIElements.New("Spacer", "spacer2"))
			:AddChild(UIElements.New("ItemIconButton", "itemButton2")
				:SetSize(40, 40)
				:SetMargin(0, 0, 32, 0)
				:SetItem("i:191461")
				:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
			)
			:AddChild(UIElements.New("Spacer", "spacer3"))
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
end

function private.CreateButton(id)
	return UIElements.New("BaseButton", id)
		:SetHeight(24)
		:SetMargin(0, 0, 32, 0)
		:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
end

function private.CreateItemSelectorPage()
	return UIElements.New("BaseFrame", "itemSelector")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Text", "controlsHeading")
			:SetHeight(20)
			:SetFont("BODY_SMALL")
			:SetJustifyH("LEFT")
			:SetText("Normal ItemSelector")
		)
		:AddChild(private.CreateItemSelector("select")
			:SetMargin(0, 0, 4, 0)
		)
		:AddChild(UIElements.New("Text", "controlsHeading")
			:SetHeight(20)
			:SetMargin(0, 0, 32, 0)
			:SetFont("BODY_SMALL")
			:SetJustifyH("LEFT")
			:SetText("Disabled ItemSelector")
		)
		:AddChild(private.CreateItemSelector("disabledSelect")
			:SetMargin(0, 0, 4, 0)
			:SetDisabled(true)
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
end

function private.CreateItemSelector(id)
	return UIElements.New("ItemSelector", id)
		:SetSize(32, 32)
		:SetItems(ITEM_SELECTOR_ITEMS)
		:SetAction("OnSelectionChanged", "ACTION_HANDLE_SELECTION_CHANGED")
end

function private.CreateCraftTierButtonPage()
	return UIElements.New("BaseFrame", "actionButton")
		:SetLayout("VERTICAL")
		:AddChild(private.CreateCraftTierButton(1, 137000, -15000, 0))
		:AddChild(private.CreateCraftTierButton(2, 546100, 15400, 0))
		:AddChild(private.CreateCraftTierButton(3, 1576400, 456400, 0))
		:AddChild(private.CreateCraftTierButton(4, 4610500, 640000, 0))
		:AddChild(private.CreateCraftTierButton(5, 8087600, -5046500, 55))
		:AddChild(UIElements.New("Spacer", "spacer"))
end

function private.CreateCraftTierButton(quality, cost, profit, concentration)
	return UIElements.New("BaseFrame", "q"..quality)
		:SetLayout("HORIZONTAL")
		:SetHeight(80)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("CraftTierButton", "button")
			:SetWidth(120)
			:SetCraftString("c:0:q"..quality, concentration)
			:SetPrices(cost, profit)
			:SetAction("OnClick", "ACTION_HANDLE_BUTTON_CLICK")
		)
end

function private.CreateGraphPage()
	return UIElements.New("BaseFrame", "graph")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Graph", "graph")
			:SetMargin(0, 0, 8, 0)
			:SetAxisStepFunctions(private.GraphXStepFunc, private.GraphYStepFunc)
			:SetXRange(0, #GRAPH_DATA_POINTS - 1, 1)
			:SetYValueFunction(private.GraphGetYValue)
			:SetFormatFunctions(private.GraphFormatX, private.GraphFormatY)
		)
end

function private.CreateComboBoxPage()
	return UIElements.New("BaseFrame", "comboBox")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("ComboBox", "comboBox")
			:SetHeight(24)
			:SetLeadIconTexture("iconPack.18x18/Mailing")
			:SetHintText("Enter recipient name")
			:SetClearButtonEnabled(true)
			:AddMenuCategory("Recents", private.ComboBoxMenuIterator, {"Bankalt", "Crafter-Area52", "Guildbank"})
			:AddMenuCategory("Alts", private.ComboBoxMenuIterator, {"Auctioneer", "Bankalt", "Enchanter", "Jewelcrafter", "Miner", "Scribe", "Tailor"})
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
end

---@param state StoryboardUIState
function private.CreateItemListPage(state)
	private.itemListShownSmartMap:Invalidate()
	local query = private.itemListDB:NewOwnedQuery()
		:VirtualSmartMapField("shown", private.itemListShownSmartMap, "mode")
		:VirtualField("texture", "number", ItemInfo.GetTexture, "itemString", ItemInfo.GetTexture(ItemString.GetUnknown()))
		:VirtualField("coloredItemName", "string", UIUtils.GetDisplayItemName, "itemString", "?")
		:Equal("shown", true)
		:OrderBy("itemString", true)
	return UIElements.New("BaseFrame", "actionButton")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("ItemList", "itemList")
			:SetHeight(100)
			:SetBackgroundColor("container/low")
			:SetSingleQuery(query, "itemString", "texture", "coloredItemName")
		)
		:AddChild(UIElements.New("HorizontalLine", "line")
			:SetMargin(0, 0, 8, 8)
		)
		:AddChild(UIElements.New("Checkbox", "filter")
			:SetSize("AUTO", 20)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText("Filter Mode")
			:MirrorIsCheckedState(state, "itemFilterMode")
			:SetAction("OnValueChanged", "ACTION_UPDATE_ITEM_LIST_MODE")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameOnHide()
	private.manager:ProcessAction("ACTION_FRAME_ON_HIDE")
end

function private.ComboBoxMenuIterator(items)
	local index = 0
	return function()
		index = index + 1
		return items[index]
	end
end

function private.GraphGetYValue(x)
	local lower = floor(x) + 1
	local upper = min(lower + 1, #GRAPH_DATA_POINTS)
	local frac = x - floor(x)
	return GRAPH_DATA_POINTS[lower] + (GRAPH_DATA_POINTS[upper] - GRAPH_DATA_POINTS[lower]) * frac
end

function private.GraphFormatX(value)
	return "Day "..floor(value)
end

function private.GraphFormatY(value, isTooltip)
	value = floor(value + 0.5)
	if isTooltip then
		return value.." g"
	elseif value >= 1000 then
		return format("%.1fk", value / 1000)
	else
		return tostring(value)
	end
end

function private.GraphXStepFunc(prevValue, suggestedStep)
	local step = max(1, Math.Round(suggestedStep, 1))
	return Math.Floor(prevValue, step) + step
end

function private.GraphYStepFunc(mode, ...)
	if mode == "RANGE" then
		local yMin, yMax, maxNumSteps = ...
		local minStep = max((yMax - yMin) / maxNumSteps / 10, yMax / 200)
		local stepSize = 1
		while stepSize < minStep do
			stepSize = stepSize * 10
		end
		yMin = Math.Floor(yMin, stepSize)
		yMax = Math.Ceil(yMax + stepSize / 3, stepSize)
		if yMin == yMax then
			yMax = yMax + stepSize
		end
		return yMin, yMax
	elseif mode == "NEXT" then
		local prevValue, yMax = ...
		local stepSize = 1
		while stepSize < yMax / 1000 do
			stepSize = stepSize * 10
		end
		return Math.Floor(prevValue, stepSize) + stepSize
	else
		error("Invalid mode")
	end
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Gathering = App:Init("CraftingUI.Gathering")
local TaskListUI = App:Include("TaskListUI")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Crafting = App:From("LibTSMApp"):Include("Crafting")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
	sourcesTemp = {},---@type number[]|table<GatheringSource,true>
	professionsTemp = {},
}
local SOURCE_LIST = { ---@type GatheringSource[]
	"bank",
	"vendor",
	"guildBank",
	"alt",
	"altGuildBank",
	"craftProfit",
	"craftNoProfit",
	"auction",
	"auctionDE",
	"auctionCrafting"
}
local SOURCE_TEXT_LOOKUP = { ---@type table<GatheringSource,string>
	bank = L["Bank"],
	vendor = L["Vendor"],
	guildBank = L["Guild Bank"],
	alt = L["Alts"],
	altGuildBank = L["Alt Guild Bank"],
	craftProfit = L["Craft (Profitable)"],
	craftNoProfit = L["Craft (Unprofitable)"],
	auction = L["AH"],
	auctionDE = L["AH (Disenchanting)"],
	auctionCrafting = L["AH (Crafting)"],
}
local OPEN_TASK_LIST_TEXTS = {
	noItems = L["No Materials to Gather"],
	visible = L["Tasks Added to Task List"],
	open = L["Open Task List"],
}
local INVALID_SOURCES = {}
do
	if App.IsRetail() then
		Table.InsertMultiple(INVALID_SOURCES, "bank")
	elseif App.IsVanillaClassic() then
		Table.InsertMultiple(INVALID_SOURCES, "guildBank", "altGuildBank")
	end
	for _, source in ipairs(INVALID_SOURCES) do
		assert(Table.RemoveByValue(SOURCE_LIST, source) == 1)
		SOURCE_TEXT_LOOKUP[source] = nil
	end
end
local STATE_SCHEMA = Reactive.CreateStateSchema("CraftingGatheringUIState")
	:AddDeferredUIElementField("frame", "DividedContainer")
	:AddDeferredUIElementField("crafterDropdown", "ListDropdown")
	:AddDeferredUIElementField("professionDropdown", "MultiselectionDropdown")
	:AddDeferredUIElementField("sourcesFrame", "BaseFrame")
	:AddOptionalClassField("query", "DatabaseQuery")
	:AddOptionalClassField("queryCancellable", "ReactivePublisher")
	:AddNumberField("numItems", 0)
	:AddBooleanField("taskListVisible", false)
	:Commit()

---@event CraftingGatheringAction
---| "ACTION_UPDATE_CONTEXT"
---| "ACTION_RESET_STATE"
---| "ACTION_SELECTED_CRAFTER_CHANGED"
---| "ACTION_SELECTED_PROFESSIONS_CHANGED"
---| "ACTION_MOVE_SOURCE" -> source: GatheringSource, targetElement?: Element
---| "ACTION_REBUILD_SOURCES"
---| "ACTION_TOGGLE_TASK_LIST"

---@alias GatheringSource
---|"bank"
---|"vendor"
---|"guildBank"
---|"alt"
---|"altGuildBank"
---|"craftProfit"
---|"craftNoProfit"
---|"auction"
---|"auctionDE"
---|"auctionCrafting"



-- ============================================================================
-- Module Functions
-- ============================================================================

AddonSettings.RegisterOnLoad(Gathering, function(db)
	private.settings = db:NewView("GatheringSettings")
		:AddKey("global", "craftingUIContext", "gatheringDividedContainer")
		:AddKey("global", "craftingUIContext", "gatheringScrollingTable")
		:AddKey("profile", "gatheringOptions", "sources")
		:Commit()

	-- Fix any invalid sources
	assert(not next(private.sourcesTemp))
	for i, source in ipairs(private.settings.sources) do
		if not SOURCE_TEXT_LOOKUP[source] or private.sourcesTemp[source] then
			-- Invalid or duplicate source
			tinsert(private.sourcesTemp, i)
		else
			private.sourcesTemp[source] = true
		end
	end
	for _, index in Table.ReverseIPairs(private.sourcesTemp) do
		tremove(private.settings.sources, index)
	end
	Table.WipeAndDeallocate(private.sourcesTemp)

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("CRAFTING_GATHERING", state, private.ActionHandler)
		:AddFrameBuilder(private.GetGatheringFrame)

	private.manager:ProcessActionFromPublisher("ACTION_RESET_STATE", state:Publisher("frame")
		:IgnoreIfNotEquals(nil)
	)

	Crafting.SetGatheringContextChangedCallback(private.manager:CallbackToProcessAction("ACTION_UPDATE_CONTEXT"))
	private.manager:SetStateFromPublisher("taskListVisible", TaskListUI.IsVisiblePublisher())
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the crafting frame.
---@return BaseFrame
function Gathering.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Gathering UI
-- ============================================================================

---@param state CraftingGatheringUIState
function private.GetGatheringFrame(state)
	UIUtils.AnalyticsRecordPathChange("crafting", "gathering")
	assert(not state.query)
	state.query = Crafting.CreateGatheringQuery()
	state.queryCancellable = state.query:Publisher()
		:Map("Count()")
		:AssignToTableKey(state, "numItems")
		:Stored()
	return UIElements.New("DividedContainer", "gathering")
		:SetMinWidth(284, 200)
		:HideDivider()
		:SetPadding(4)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:SetSettingsContext(private.settings, "gatheringDividedContainer")
		:SetLeftChild(UIElements.New("BaseFrame", "setup")
			:SetLayout("FILL")
			:SetMargin(0, 3, 0, 0)
			:SetRoundedBackgroundColor("container/low")
			:AddChild(UIElements.New("BaseScrollFrame", "content")
				:SetPadding(8)
				:AddChild(UIElements.New("SettingsField", "crafter")
					:SetHeight(46)
					:SetLabel(L["Crafter"])
					:AddChild(UIElements.New("ListDropdown", "crafterDropdown")
						:SetHeight(24)
						:BindElement(state, "crafterDropdown")
						:SetHintText(L["Select crafter"])
						:SetAction("OnSelectionChanged", "ACTION_SELECTED_CRAFTER_CHANGED")
					)
				)
				:AddChild(UIElements.New("SettingsField", "profession")
					:SetHeight(46)
					:SetMargin(0, 0, 12, 0)
					:SetLabel(L["Profession"])
					:AddChild(UIElements.New("MultiselectionDropdown", "professionDropdown")
						:SetHeight(24)
						:BindElement(state, "professionDropdown")
						:SetHintText(L["Select professions"])
						:SetSelectionText(L["No Professions"], L["%d Professions"], L["All Professions"])
						:SetAction("OnSelectionChanged", "ACTION_SELECTED_PROFESSIONS_CHANGED")
					)
				)
				:AddChild(UIElements.New("Text", "sourcesTitle")
					:SetHeight(24)
					:SetMargin(0, 0, 24, 0)
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetText(L["Sources"])
				)
				:AddChild(UIElements.New("Text", "sourcesDesc")
					:SetHeight(20)
					:SetMargin(0, 0, 4, 8)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetTextColor("on/surface/low")
					:SetText(L["Define the priority order of sources."])
				)
				:AddChild(UIElements.New("BaseFrame", "sources")
					:SetLayout("VERTICAL")
					:BindElement(state, "sourcesFrame")
					:AddChildrenWithFunction(private.CreateSourceRows)
				)
			)
		)
		:SetRightChild(UIElements.New("BaseFrame", "mats")
			:SetLayout("VERTICAL")
			:SetMargin(3, 0, 0, 0)
			:AddChild(UIElements.New("ListContainer", "table")
				:AddChild(UIElements.New("GatheringScrollTable", "table")
					:SetSettings(private.settings, "gatheringScrollingTable")
					:SetQuery(Crafting.CreateGatheringQuery()
						:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
						:VirtualField("sourcesDisplayStr", "string", private.GetSourcesDisplayStr, "sourcesStr")
					)
				)
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "openTaskListBtn")
				:SetMargin(0, 0, 8, 0)
				:SetDisabled(state:Publisher([[numItems == 0 or taskListVisible]]))
				:SetText(state:Publisher([[(numItems == 0 and "noItems") or (taskListVisible and "visible") or "open"]]):Map(OPEN_TASK_LIST_TEXTS))
				:SetAction("OnClick", "ACTION_TOGGLE_TASK_LIST")
			)
		)
		:WithProcessAction("ACTION_UPDATE_CONTEXT")
end

function private.CreateSourceRows(frame)
	assert(not next(private.sourcesTemp))
	for i, source in ipairs(private.settings.sources) do
		frame:AddChild(UIElements.New("GatheringSourceRow", source)
			:SetHeight(24)
			:SetMargin(0, 0, i > 1 and 12 or 0, 0)
			:Configure(source, i, SOURCE_TEXT_LOOKUP[source])
			:SetAction("OnDraggingDone", "ACTION_MOVE_SOURCE")
		)
		private.sourcesTemp[source] = true
	end
	frame:AddChild(UIElements.New("BaseFrame", "separator")
		:SetHeight(12)
	)
	for _, source in ipairs(SOURCE_LIST) do
		if not private.sourcesTemp[source] then
			frame:AddChild(UIElements.New("GatheringSourceRow", source)
				:SetHeight(24)
				:SetMargin(0, 0, 12, 0)
				:Configure(source, 0, SOURCE_TEXT_LOOKUP[source])
				:SetDisabled(true)
				:SetAction("OnDraggingDone", "ACTION_MOVE_SOURCE")
			)
		end
	end
	Table.WipeAndDeallocate(private.sourcesTemp)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<CraftingGatheringUIState>
---@param state CraftingGatheringUIState
---@param action CraftingGatheringAction
---@param ... params<CraftingGatheringAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_CONTEXT" then
		if not state.frame then
			return
		end
		state.crafterDropdown
			:SetItems(Crafting.GetGatheringCrafterList())
			:SetSelectedItem(Crafting.GetGatheringCrafter())
			:Draw()
		state.professionDropdown
			:SetItems(Crafting.GetGatheringProfessionList())
			:SetSelectedItems(Crafting.GetGatheringProfessions())
			:Draw()
	elseif action == "ACTION_RESET_STATE" then
		if state.queryCancellable then
			state.queryCancellable:Cancel()
			state.queryCancellable = nil
		end
		if state.query then
			state.query:Release()
			state.query = nil
		end
	elseif action == "ACTION_SELECTED_CRAFTER_CHANGED" then
		Crafting.SetGatheringCrafter(state.crafterDropdown:GetSelectedItem() or "")
		state.professionDropdown
			:SetItems(Crafting.GetGatheringProfessionList())
			:SetSelectedItems(Crafting.GetGatheringProfessions())
			:Draw()
	elseif action == "ACTION_SELECTED_PROFESSIONS_CHANGED" then
		assert(state.professionDropdown)
		assert(not next(private.professionsTemp))
		state.professionDropdown:GetSelectedItems(private.professionsTemp)
		Crafting.SetGatheringProfessions(private.professionsTemp)
		wipe(private.professionsTemp)
	elseif action == "ACTION_MOVE_SOURCE" then
		local source, targetElement = ...
		if not targetElement then
			-- Do nothing
		elseif not UIElements.IsType(targetElement, "GatheringSourceRow") then
			local prevIndex = Table.KeyByValue(private.settings.sources, source)
			if prevIndex then
				-- Remove the source
				tremove(private.settings.sources, prevIndex)
			else
				-- Add the source
				tinsert(private.settings.sources, source)
			end
		else
			---@cast targetElement GatheringSourceRow
			local prevIndex = Table.KeyByValue(private.settings.sources, source)
			local newIndex = Table.KeyByValue(private.settings.sources, targetElement:GetSource())
			if prevIndex and newIndex then
				-- Move the source
				Table.Move(private.settings.sources, prevIndex, newIndex)
			elseif prevIndex then
				-- Remove the source
				tremove(private.settings.sources, prevIndex)
			elseif newIndex then
				-- Add the source
				tinsert(private.settings.sources, newIndex, source)
			end
		end
		return manager:ProcessAction("ACTION_REBUILD_SOURCES")
	elseif action == "ACTION_REBUILD_SOURCES" then
		state.sourcesFrame
			:ReleaseAllChildren()
			:AddChildrenWithFunction(private.CreateSourceRows)
			:Draw()
	elseif action == "ACTION_TOGGLE_TASK_LIST" then
		TaskListUI.Toggle()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetSourcesDisplayStr(str)
	str = gsub(str, "/[^,]+", "")
	for _, source in ipairs(SOURCE_LIST) do
		str = gsub(str, source, SOURCE_TEXT_LOOKUP[source])
	end
	return str
end

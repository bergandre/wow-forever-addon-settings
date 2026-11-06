-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Other = App:Init("MainUI.Ledger.Other")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Money = App:From("LibTSMService"):Include("Ledger.Money")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	manager = nil,
	characters = {},
	characterFilter = {},
	typeFilter = {},
}
local TIME_LIST = { L["All Time"], L["Last 3 Days"], L["Last 7 Days"], L["Last 14 Days"], L["Last 30 Days"], L["Last 60 Days"] }
local TIME_KEYS = { 0, 3 * SECONDS_PER_DAY, 7 * SECONDS_PER_DAY, 14 * SECONDS_PER_DAY, 30 * SECONDS_PER_DAY, 60 * SECONDS_PER_DAY }
local TYPE_LIST = {
	expense = { L["Money Transfer"], L["Postage"], L["Repair Bill"], L["Crafting Order"] },
	income = { L["Money Transfer"], L["Garrison"], L["Crafting Order"] },
}
local TYPE_KEYS = {
	expense = { "Money Transfer", "Postage", "Repair Bill", "Crafting Order" },
	income = { "Money Transfer", "Garrison", "Crafting Order" },
}
local TYPE_STR_LOOKUP = {}
do
	-- Populate lookup table
	assert(#TYPE_LIST.expense == #TYPE_KEYS.expense)
	for i = 1, #TYPE_LIST.expense do
		TYPE_STR_LOOKUP[TYPE_KEYS.expense[i]] = TYPE_LIST.expense[i]
	end
	assert(#TYPE_LIST.income == #TYPE_KEYS.income)
	for i = 1, #TYPE_LIST.income do
		TYPE_STR_LOOKUP[TYPE_KEYS.income[i]] = TYPE_LIST.income[i]
	end
end
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerOtherUIState")
	:AddDeferredUIElementField("scrollTable", "LedgerOtherScrollTable")
	:AddStringField("type", "expense", function(value) return value == "expense" or value == "income" end)
	:AddNumberField("timeFrameFilter", 30 * SECONDS_PER_DAY)
	:Commit()

---@class LedgerOtherUIState
---@field type "expense"|"income"

---@event LedgerOtherAction
---| "ACTION_UPDATE_QUERY_AND_FILTER"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Other, function(db)
	private.settings = db:NewView("OtherSettings")
		:AddKey("global", "mainUIContext", "ledgerOtherScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_OTHER", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_QUERY_AND_FILTER")
		:AddFrameBuilder(private.GetOtherFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the other expenses frame.
---@return BaseFrame
function Other.GetExpensesFrame()
	return private.manager:BuildFrame("expense")
end

---Gets the other revenue frame.
---@return BaseFrame
function Other.GetIncomeFrame()
	return private.manager:BuildFrame("income")
end



-- ============================================================================
-- Other UI
-- ============================================================================

---@param state LedgerOtherUIState
function private.GetOtherFrame(state, recordType)
	state.type = recordType
	if state.type == "expense" then
		UIUtils.AnalyticsRecordPathChange("main", "ledger", "expenses", "other")
	elseif state.type == "income" then
		UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "other")
	else
		error("Unknown record type: "..tostring(state.type))
	end

	wipe(private.characters)
	for _, character in Money.CharacterIterator(state.type) do
		tinsert(private.characters, character)
		private.characterFilter[character] = true
	end
	Table.Sort(private.characters)
	wipe(private.typeFilter)
	for _, key in ipairs(TYPE_KEYS[state.type]) do
		private.typeFilter[key] = true
	end

	local frame = UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "filters")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("MultiselectionDropdown", "type")
				:SetMargin(0, 8, 0, 0)
				:SetItems(TYPE_LIST[state.type], TYPE_KEYS[state.type])
				:SetSettingInfo(private, "typeFilter")
				:SetSelectionText(L["No Types"], L["%d Types"], L["All Types"])
				:SetHintText(L["Select types"])
				:SetAction("OnSelectionChanged", "ACTION_UPDATE_QUERY_AND_FILTER")
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "character")
				:SetMargin(0, 8, 0, 0)
				:SetItems(private.characters, private.characters)
				:SetSettingInfo(private, "characterFilter")
				:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
				:SetHintText(L["Select characters"])
				:SetAction("OnSelectionChanged", "ACTION_UPDATE_QUERY_AND_FILTER")
			)
			:AddChild(UIElements.New("SelectionDropdown", "time")
				:SetItems(TIME_LIST, TIME_KEYS)
				:SetSettingInfo(state, "timeFrameFilter")
				:SetHintText(L["Select time frame"])
				:SetAction("OnSelectionChanged", "ACTION_UPDATE_QUERY_AND_FILTER")
			)
		)
		:AddChild(UIElements.New("ListContainer", "content")
			:AddChild(UIElements.New("LedgerOtherScrollTable", "table")
				:BindElement(state, "scrollTable")
				:SetSettings(private.settings, "ledgerOtherScrollingTable")
				:SetQuery(Money.CreateQuery()
					:VirtualField("typeStr", "string", private.TypeStrVirtualField, "type")
				)
			)
		)

	private.manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	return frame
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerOtherUIState>
---@param state LedgerOtherUIState
---@param action LedgerOtherAction
---@param ... params<LedgerOtherAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_QUERY_AND_FILTER" then
		local typeFilter = Table.Count(private.typeFilter) ~= #TYPE_KEYS[state.type] and private.typeFilter or nil
		local player = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
		local timeFilter = state.timeFrameFilter ~= 0 and state.timeFrameFilter or nil
		state.scrollTable:SetFilters(state.type, typeFilter, player, timeFilter)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.TypeStrVirtualField(typeValue)
	return TYPE_STR_LOOKUP[typeValue]
end

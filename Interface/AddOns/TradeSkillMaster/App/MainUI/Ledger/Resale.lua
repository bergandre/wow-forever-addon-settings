-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Resale = App:Init("MainUI.Ledger.Resale")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Transactions = App:From("LibTSMService"):Include("Ledger.Transactions")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	manager = nil,
	showItemCallback = nil,
	summaryQuery = nil,
	characters = {},
	characterFilter = {},
	typeFilter = {},
	rarityFilter = {},
	groupFilter = {},
}
local TYPE_LIST = { L["Auction"], L["C.O.D."], L["Trade"], L["Vendor"] }
local TYPE_KEYS = { "Auction", "COD", "Trade", "Vendor" }
local RARITY_LIST = {}
local RARITY_KEYS = { 0, 1, 2, 3, 4, 5 }
do
	for _, key in ipairs(TYPE_KEYS) do
		private.typeFilter[key] = true
	end
	for _, key in ipairs(RARITY_KEYS) do
		tinsert(RARITY_LIST, _G[format("ITEM_QUALITY%d_DESC", key)])
		private.rarityFilter[key] = true
	end
end
local TIME_LIST = { L["All Time"], L["Last 3 Days"], L["Last 7 Days"], L["Last 14 Days"], L["Last 30 Days"], L["Last 60 Days"] }
local TIME_KEYS = { 0, 3 * SECONDS_PER_DAY, 7 * SECONDS_PER_DAY, 14 * SECONDS_PER_DAY, 30 * SECONDS_PER_DAY, 60 * SECONDS_PER_DAY }
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerResaleUIState")
	:AddDeferredUIElementField("groupSelector", "GroupSelector")
	:AddDeferredUIElementField("scrollTable", "LedgerResaleScrollTable")
	:AddDeferredUIElementField("footer", "BaseFrame")
	:AddNumberField("numItems", 0)
	:AddNumberField("totalProfit", 0)
	:AddStringField("searchFilter", "")
	:AddNumberField("timeFrameFilter", 30 * SECONDS_PER_DAY)
	:AddStringField("filteredItemMode", "specific")
	:Commit()

---@event LedgerResaleAction
---| "ACTION_HANDLE_ITEM_MODE_CHANGED"
---| "ACTION_HANDLE_GROUP_FILTER_CHANGED"
---| "ACTION_HANDLE_FILTER_CHANGED"
---| "ACTION_UPDATE_QUERY_AND_FILTER"
---| "ACTION_SHOW_ITEM" -> itemString: string



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Resale, function(db)
	private.settings = db:NewView("ResaleSettings")
		:AddKey("global", "mainUIContext", "ledgerResaleScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_RESALE", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_FILTER_CHANGED")
		:SuppressActionLog("ACTION_UPDATE_QUERY_AND_FILTER")
		:AddFrameBuilder(private.GetResaleFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the resale code.
---@param showItemCallback fun(itemString: string, recordType: LedgerTransactionType) The function to call to show item details
function Resale.Configure(showItemCallback)
	private.showItemCallback = showItemCallback
end

---Gets the resale frame.
---@return BaseFrame
function Resale.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Resale UI
-- ============================================================================

---@param state LedgerResaleUIState
function private.GetResaleFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "resale")
	wipe(private.characters)
	Transactions.GetCharacters(private.characters)
	Table.Sort(private.characters)
	for _, character in ipairs(private.characters) do
		private.characterFilter[character] = true
	end

	private.summaryQuery = private.summaryQuery or Transactions.CreateSummaryQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "?")
		:VirtualField("quality", "number", ItemInfo.GetQuality, "filteredItemString", 0)

	local content = UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "row1")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:AddChild(UIElements.New("Input", "filter")
				:SetMargin(0, 8, 0, 0)
				:SetLeadIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:AllowItemInsert()
				:SetHintText(L["Filter by keyword"])
				:MirrorValueState(state, "searchFilter")
				:SetAction("OnValueChanged", "ACTION_HANDLE_FILTER_CHANGED")
			)
			:AddChild(UIElements.New("SelectionDropdown", "itemMode")
				:SetWidth(220)
				:SetMargin(0, 8, 0, 0)
				:AddItem(L["Specific Item"], "specific")
				:AddItem(L["Item Level"], "level")
				:AddItem(L["Base Item"], "base")
				:SetSettingInfo(state, "filteredItemMode")
				:SetHintText(L["Select item type"])
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_ITEM_MODE_CHANGED")
			)
			:AddChild(UIElements.New("GroupSelector", "group")
				:SetWidth(240)
				:BindElement(state, "groupSelector")
				:SetHintText(L["Filter by groups"])
				:SetSelection(next(private.groupFilter) and private.groupFilter or nil)
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_GROUP_FILTER_CHANGED")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "row2")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 8)
			:AddChild(UIElements.New("MultiselectionDropdown", "type")
				:SetMargin(0, 8, 0, 0)
				:SetItems(TYPE_LIST, TYPE_KEYS)
				:SetSettingInfo(private, "typeFilter")
				:SetSelectionText(L["No Types"], L["%d Types"], L["All Types"])
				:SetHintText(L["Select types"])
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_FILTER_CHANGED")
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "rarity")
				:SetMargin(0, 8, 0, 0)
				:SetItems(RARITY_LIST, RARITY_KEYS)
				:SetSettingInfo(private, "rarityFilter")
				:SetSelectionText(L["No Rarities"], L["%d Rarities"], L["All Rarities"])
				:SetHintText(L["Select rarities"])
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_FILTER_CHANGED")
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "character")
				:SetMargin(0, 8, 0, 0)
				:SetItems(private.characters, private.characters)
				:SetSettingInfo(private, "characterFilter")
				:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
				:SetHintText(L["Select characters"])
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_FILTER_CHANGED")
			)
			:AddChild(UIElements.New("SelectionDropdown", "time")
				:SetItems(TIME_LIST, TIME_KEYS)
				:SetSettingInfo(state, "timeFrameFilter")
				:SetHintText(L["Select time frame"])
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_FILTER_CHANGED")
			)
		)
		:AddChild(UIElements.New("ListContainer", "content")
			:AddChild(UIElements.New("LedgerResaleScrollTable", "scrollTable")
				:BindElement(state, "scrollTable")
				:SetSettings(private.settings, "ledgerResaleScrollingTable")
				:SetQuery(private.summaryQuery)
				:SetAction("OnItemRowClick", "ACTION_SHOW_ITEM")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetMargin(0, 0, 8, 0)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:BindElement(state, "footer")
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("Text", "num")
				:SetWidth("AUTO")
				:SetMargin(0, 24, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(state:PublisherForFunctionWithKeys(private.NumItemsToString, "numItems"))
			)
			:AddChild(UIElements.New("Text", "profitLabel")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Total Profit"]..":")
			)
			:AddChild(UIElements.New("Text", "profit")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForUI, "totalProfit"))
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)

	private.manager:ProcessAction("ACTION_HANDLE_FILTER_CHANGED")
	private.manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	return content
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerResaleUIState>
---@param state LedgerResaleUIState
---@param action LedgerResaleAction
---@param ... params<LedgerResaleAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_MODE_CHANGED" then
		manager:ProcessAction("ACTION_HANDLE_FILTER_CHANGED")
		manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	elseif action == "ACTION_HANDLE_GROUP_FILTER_CHANGED" then
		wipe(private.groupFilter)
		for groupPath in state.groupSelector:SelectedGroupIterator() do
			private.groupFilter[groupPath] = true
		end
		return manager:ProcessAction("ACTION_HANDLE_FILTER_CHANGED")
	elseif action == "ACTION_HANDLE_FILTER_CHANGED" then
		state.scrollTable:SetFilters(Table.Count(private.rarityFilter) ~= #RARITY_LIST and private.rarityFilter or nil)
		return manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	elseif action == "ACTION_UPDATE_QUERY_AND_FILTER" then
		local groupFilter = next(private.groupFilter) and private.groupFilter or nil
		local searchFilter = state.searchFilter ~= "" and state.searchFilter or nil
		local typeFilter = Table.Count(private.typeFilter) ~= #TYPE_KEYS and private.typeFilter or nil
		local characterFilter = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
		local minTime = state.timeFrameFilter ~= 0 and (floor(App.GetTime()) - state.timeFrameFilter) or nil
		Transactions.UpdateSummaryData(state.filteredItemMode, groupFilter, searchFilter, typeFilter, characterFilter, minTime)

		local numItems, totalProfit = 0, 0
		for _, sold, bought, rowTotalProfit in private.summaryQuery:Iterator("sold", "bought", "totalProfit") do
			numItems = numItems + min(sold, bought)
			totalProfit = totalProfit + rowTotalProfit
		end
		state.numItems = numItems
		state.totalProfit = totalProfit
		state.footer:Draw()
	elseif action == "ACTION_SHOW_ITEM" then
		local itemString = ...
		private.showItemCallback(itemString, "sale")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NumItemsToString(numItems)
	return format(L["%s Items Resold"], Theme.GetColor("accent/main"):ColorText(FormatLargeNumber(numItems)))
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Transactions = App:Init("MainUI.Ledger.Transactions")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local TransactionsService = App:From("LibTSMService"):Include("Ledger.Transactions")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	manager = nil,
	showItemCallback = nil,
	query = nil,
	characters = {},
	characterFilter = {},
	typeFilter = {},
	groupFilter = {},
	rarityFilter = {},
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
local TOTAL_ARG_FIELDS = { "price", "quantity" }
local AUCTIONS_ARG_FIELDS = { "quantity", "stackSize" }
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerTransactionsUIState")
	:AddDeferredUIElementField("groupSelector", "GroupSelector")
	:AddDeferredUIElementField("scrollTable", "LedgerTransactionsScrollTable")
	:AddDeferredUIElementField("footer", "BaseFrame")
	:AddStringField("type", "buy", function(value) return value == "sale" or value == "buy" end)
	:AddNumberField("numItems", 0)
	:AddNumberField("total", 0)
	:AddStringField("searchFilter", "")
	:AddNumberField("timeFrameFilter", 30 * SECONDS_PER_DAY)
	:AddStringField("filteredItemMode", "specific")
	:Commit()

---@event LedgerTransactionsAction
---| "ACTION_HANDLE_ITEM_MODE_CHANGED"
---| "ACTION_HANDLE_GROUP_FILTER_CHANGED"
---| "ACTION_UPDATE_QUERY_AND_FILTER"
---| "ACTION_SHOW_ITEM" -> itemString: string



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Transactions, function(db)
	private.settings = db:NewView("TransactionsSettings")
		:AddKey("global", "mainUIContext", "ledgerTransactionsScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_TRANSACTIONS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_QUERY_AND_FILTER")
		:AddFrameBuilder(private.GetFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the transactions code.
---@param showItemCallback fun(itemString: string, recordType: LedgerTransactionType) The function to call to show item details
function Transactions.Configure(showItemCallback)
	private.showItemCallback = showItemCallback
end

---Gets the transaction purchases frame.
---@return BaseFrame
function Transactions.GetPurchasesFrame()
	return private.manager:BuildFrame("buy")
end

---Gets the transaction sales frame.
---@return BaseFrame
function Transactions.GetSalesFrame()
	return private.manager:BuildFrame("sale")
end



-- ============================================================================
-- Transactions UI
-- ============================================================================

---@param state LedgerTransactionsUIState
function private.GetFrame(state, transactionType)
	state.type = transactionType
	if state.type == "buy" then
		UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "purchases")
	elseif state.type == "sale" then
		UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "sales")
	else
		error("Unknown transaction type: "..tostring(state.type))
	end

	private.query = private.query or TransactionsService.CreateQuery()
	private.query:Reset()
		:Equal("type", state.type)
		:Distinct("player")
		:OrderBy("player", true)

	wipe(private.characters)
	for _, character in private.query:Iterator("player") do
		tinsert(private.characters, character)
		private.characterFilter[character] = true
	end

	private.query:Reset()
	TransactionsService.AddSmartMap(private.query)
	TransactionsService.UpdateSmartMap(state.filteredItemMode)

	private.query:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "?")
		:VirtualField("quality", "number", ItemInfo.GetQuality, "filteredItemString", 0)
		:VirtualField("total", "number", private.GetTotal, TOTAL_ARG_FIELDS)
		:VirtualField("auctions", "number", private.GetAuctions, AUCTIONS_ARG_FIELDS)

	local frame = UIElements.New("BaseFrame", "content")
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
				:SetAction("OnValueChanged", "ACTION_UPDATE_QUERY_AND_FILTER")
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
				:SetAction("OnSelectionChanged", "ACTION_UPDATE_QUERY_AND_FILTER")
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "rarity")
				:SetMargin(0, 8, 0, 0)
				:SetItems(RARITY_LIST, RARITY_KEYS)
				:SetSettingInfo(private, "rarityFilter")
				:SetSelectionText(L["No Rarities"], L["%d Rarities"], L["All Rarities"])
				:SetHintText(L["Select rarities"])
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
			:AddChild(UIElements.New("LedgerTransactionsScrollTable", "scrollingTable")
				:BindElement(state, "scrollTable")
				:SetSettings(private.settings, "ledgerTransactionsScrollingTable")
				:SetCreatedGroupName(L["Ledger"].." - "..(state.type == "sale" and L["Sales"] or L["Purchases"]))
				:SetQuery(private.query)
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
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(state:PublisherForFunctionWithKeys(private.StateToNumItemsString, "type", "numItems"))
			)
			:AddChild(UIElements.New("Text", "total")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForUI, "total"))
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)

	private.manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	return frame
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerTransactionsUIState>
---@param state LedgerTransactionsUIState
---@param action LedgerTransactionsAction
---@param ... params<LedgerTransactionsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_MODE_CHANGED" then
		TransactionsService.UpdateSmartMap(state.filteredItemMode)
		return manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	elseif action == "ACTION_HANDLE_GROUP_FILTER_CHANGED" then
		wipe(private.groupFilter)
		for groupPath in state.groupSelector:SelectedGroupIterator() do
			private.groupFilter[groupPath] = true
		end
		return manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	elseif action == "ACTION_UPDATE_QUERY_AND_FILTER" then
		local name = String.Escape(state.searchFilter)
		name = name ~= "" and name or nil
		local source = Table.Count(private.typeFilter) ~= #TYPE_KEYS and private.typeFilter or nil
		local quality = Table.Count(private.rarityFilter) ~= #RARITY_LIST and private.rarityFilter or nil
		local player = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
		local minTimeFrame = state.timeFrameFilter ~= 0 and state.timeFrameFilter or nil
		local group = next(private.groupFilter) and private.groupFilter or nil
		state.scrollTable:SetFilters(state.type, name, source, quality, player, minTimeFrame, group)
		state.numItems = private.query:Sum("quantity")
		state.total = private.query:Sum("total")
		state.footer:Draw()
	elseif action == "ACTION_SHOW_ITEM" then
		local itemString = ...
		private.showItemCallback(itemString, state.type)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetTotal(price, quantity)
	return price * quantity
end

function private.GetAuctions(quantity, stackSize)
	return quantity / stackSize
end

function private.StateToNumItemsString(recordType, numItems)
	return format((recordType == "sale" and L["%s Items Sold"] or L["%s Items Bought"])..":", Theme.GetColor("accent/main"):ColorText(FormatLargeNumber(numItems)))
end

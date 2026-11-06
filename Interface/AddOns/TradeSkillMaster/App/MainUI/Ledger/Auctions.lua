-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Auctions = App:Init("MainUI.Ledger.Auctions")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local AuctionsService = App:From("LibTSMService"):Include("Ledger.Auctions")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	manager = nil,
	query = nil,
	showItemCallback = nil,
	characters = {},
	characterFilter = {},
	groupFilter = {},
	rarityFilter = {},
}
local RARITY_LIST = {}
local RARITY_KEYS = { 0, 1, 2, 3, 4, 5 }
do
	for _, key in ipairs(RARITY_KEYS) do
		tinsert(RARITY_LIST, _G[format("ITEM_QUALITY%d_DESC", key)])
		private.rarityFilter[key] = true
	end
end
local TIME_LIST = { L["All Time"], L["Last 3 Days"], L["Last 7 Days"], L["Last 14 Days"], L["Last 30 Days"], L["Last 60 Days"] }
local TIME_KEYS = { 0, 3 * SECONDS_PER_DAY, 7 * SECONDS_PER_DAY, 14 * SECONDS_PER_DAY, 30 * SECONDS_PER_DAY, 60 * SECONDS_PER_DAY }
local AUCTIONS_ARG_FIELDS = { "quantity", "stackSize" }
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerAuctionsUIState")
	:AddDeferredUIElementField("groupSelector", "GroupSelector")
	:AddDeferredUIElementField("scrollTable", "LedgerAuctionsScrollTable")
	:AddDeferredUIElementField("footer", "BaseFrame")
	:AddStringField("type", "expire", function(value) return value == "expire" or value == "cancel" end)
	:AddNumberField("numItems", 0)
	:AddStringField("searchFilter", "")
	:AddNumberField("timeFrameFilter", 30 * SECONDS_PER_DAY)
	:AddStringField("filteredItemMode", "specific")
	:Commit()

---@event LedgerAuctionsAction
---| "ACTION_HANDLE_ITEM_MODE_CHANGED"
---| "ACTION_HANDLE_GROUP_FILTER_CHANGED"
---| "ACTION_UPDATE_QUERY_AND_FILTER"
---| "ACTION_SHOW_ITEM" -> itemString: string



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Auctions, function(db)
	private.settings = db:NewView("AuctionsSettings")
		:AddKey("global", "mainUIContext", "ledgerAuctionsScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_AUCTIONS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_QUERY_AND_FILTER")
		:AddFrameBuilder(private.GetFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the auctions code.
---@param showItemCallback fun(itemString: string, recordType: LedgerTransactionType) The function to call to show item details
function Auctions.Configure(showItemCallback)
	private.showItemCallback = showItemCallback
end

---Gets the expired auctions frame.
---@return BaseFrame
function Auctions.GetExpiredFrame()
	return private.manager:BuildFrame("expire")
end

---Gets the cancelled auctions frame.
---@return BaseFrame
function Auctions.GetCancelledFrame()
	return private.manager:BuildFrame("cancel")
end



-- ============================================================================
-- Auctions UIs
-- ============================================================================

---@param state LedgerAuctionsUIState
function private.GetFrame(state, recordType)
	state.type = recordType
	if state.type == "expire" then
		UIUtils.AnalyticsRecordPathChange("main", "ledger", "failed_auctions", "expired")
	elseif state.type == "cancel" then
		UIUtils.AnalyticsRecordPathChange("main", "ledger", "failed_auctions", "cancelled")
	else
		error("Unknown record type: "..tostring(state.type))
	end

	private.query = private.query or AuctionsService.CreateQuery()

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
	AuctionsService.AddSmartMap(private.query)
	AuctionsService.UpdateSmartMap(state.filteredItemMode)

	private.query:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "?")
		:VirtualField("quality", "number", ItemInfo.GetQuality, "filteredItemString", 0)
		:VirtualField("auctions", "number", private.AuctionsVirtualField, AUCTIONS_ARG_FIELDS)

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
			:AddChild(UIElements.New("LedgerAuctionsScrollTable", "scrollTable")
				:BindElement(state, "scrollTable")
				:SetSettings(private.settings, "ledgerAuctionsScrollingTable")
				:SetCreatedGroupName(L["Ledger"].." - "..(state.type == "expire" and L["Expired Auctions"] or L["Cancelled Auctions"]))
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
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(state:PublisherForFunctionWithKeys(private.StateToNumItemsString, "type", "numItems"))
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)

	private.manager:ProcessAction("ACTION_UPDATE_QUERY_AND_FILTER")
	return content
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerAuctionsUIState>
---@param state LedgerAuctionsUIState
---@param action LedgerAuctionsAction
---@param ... params<LedgerAuctionsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_MODE_CHANGED" then
		AuctionsService.UpdateSmartMap(state.filteredItemMode)
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
		local quality = Table.Count(private.rarityFilter) ~= #RARITY_LIST and private.rarityFilter or nil
		local player = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
		local timeFilter = state.timeFrameFilter ~= 0 and state.timeFrameFilter or nil
		local group = next(private.groupFilter) and private.groupFilter or nil
		state.scrollTable:SetFilters(state.type, name, quality, player, timeFilter, group)
		state.numItems = private.query:Sum("quantity")
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

function private.AuctionsVirtualField(quantity, stackSize)
	return quantity / stackSize
end

function private.StateToNumItemsString(recordType, numItems)
	return format(recordType == "expire" and L["%s Items Expired"] or L["%s Items Cancelled"], Theme.GetColor("accent/main"):ColorText(FormatLargeNumber(numItems)))
end

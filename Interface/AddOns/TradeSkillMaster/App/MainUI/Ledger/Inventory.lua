-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Inventory = App:Init("MainUI.Ledger.Inventory")
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Database = App:From("LibTSMDatabase"):Include("Database")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local Group = App:From("LibTSMTypes"):Include("Group")
local Auction = App:From("LibTSMService"):Include("Auction")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = App:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Mail = App:From("LibTSMService"):Include("Mail")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local AltTracking = App:From("LibTSMApp"):Include("Service.AltTracking")
local private = {
	settings = nil,
	manager = nil,
	db = nil,
	query = nil,
	groupFilter = {},
	valuePriceSource = "dbmarket",
	quantityTemp = {
		items = {},
		bag = {},
		bank = {},
		auction = {},
		mail = {},
		alt = {},
		guild = {},
		warbank = {},
	},
}
local TOTAL_VALUE_ARG_FIELDS = { "levelItemString", "totalQuantity" }
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerInventoryUIState")
	:AddDeferredUIElementField("groupSelector", "GroupSelector")
	:AddDeferredUIElementField("scrollTable", "LedgerInventoryScrollTable")
	:AddNumberField("totalValue", 0)
	:AddStringField("searchFilter", "")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Inventory:OnModuleLoad(function()
	private.db = Database.NewSchema("LEDGER_INVENTORY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("bagQuantity")
		:AddNumberField("bankQuantity")
		:AddNumberField("auctionQuantity")
		:AddNumberField("mailQuantity")
		:AddNumberField("altQuantity")
		:AddNumberField("guildQuantity")
		:AddNumberField("totalBankQuantity")
		:AddNumberField("totalQuantity")
		:Commit()
	private.query = private.db:NewOwnedQuery()
		:VirtualField("totalValue", "number", private.TotalValueVirtualField, TOTAL_VALUE_ARG_FIELDS)
		:VirtualField("name", "string", ItemInfo.GetName, "levelItemString", "")
		:VirtualField("groupPath", "string", Group.GetPathByItem, "levelItemString")
end)

AddonSettings.RegisterOnLoad(Inventory, function(db)
	private.settings = db:NewView("InventorySettings")
		:AddKey("global", "mainUIContext", "ledgerInventoryScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_INVENTORY", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_CONTENT")
		:AddFrameBuilder(private.GetInventoryFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the inventory frame.
---@return BaseFrame
function Inventory.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Inventory UI
-- ============================================================================

---@param state LedgerInventoryUIState
function private.GetInventoryFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "inventory")
	local quantityInfo = private.quantityTemp
	for _, tbl in pairs(quantityInfo) do
		assert(not next(tbl))
	end
	private.CollectQuantityInfo(BagTracking.QuantityIterator(), "bag", "bank")
	private.CollectQuantityInfo(Auction.QuantityIterator(), "auction")
	private.CollectQuantityInfo(Mail.QuantityIterator(), "mail")
	private.CollectQuantityInfo(AltTracking.QuantityIterator(), "alt")
	private.CollectQuantityInfo(AltTracking.GuildItemIterator(), "guild")
	private.CollectQuantityInfo(WarbankTracking.QuantityIterator(), "warbank")
	private.db:TruncateAndBulkInsertStart()
	for levelItemString in pairs(quantityInfo.items) do
		local bagQuantity = quantityInfo.bag[levelItemString] or 0
		local bankQuantity = quantityInfo.bank[levelItemString] or 0
		local auctionQuantity = quantityInfo.auction[levelItemString] or 0
		local mailQuantity = quantityInfo.mail[levelItemString] or 0
		local altQuantity = quantityInfo.alt[levelItemString] or 0
		local guildQuantity = quantityInfo.guild[levelItemString] or 0
		local warbankQuantity = quantityInfo.warbank[levelItemString] or 0
		local totalBankQuantity = bankQuantity + warbankQuantity
		local totalQuantity = bagQuantity + totalBankQuantity + guildQuantity + auctionQuantity + mailQuantity + altQuantity
		private.db:BulkInsertNewRow(levelItemString, bagQuantity, bankQuantity, auctionQuantity, mailQuantity, altQuantity, guildQuantity, totalBankQuantity, totalQuantity)
	end
	private.db:BulkInsertEnd()
	for _, tbl in pairs(quantityInfo) do
		Table.WipeAndDeallocate(tbl)
	end

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
				:SetAction("OnValueChanged", "ACTION_UPDATE_CONTENT")
			)
			:AddChild(UIElements.New("GroupSelector", "group")
				:SetWidth(240)
				:SetHintText(L["Filter by groups"])
				:BindElement(state, "groupSelector")
				:SetSelection(next(private.groupFilter) and private.groupFilter or nil)
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_GROUP_FILTER_CHANGED")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "row2")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 8)
			:AddChild(UIElements.New("Text", "label")
				:SetWidth("AUTO")
				:SetFont("BODY_XSMALL")
				:SetText(L["Value Price Source"])
			)
			:AddChild(UIElements.New("CustomStringSingleLineInput", "input")
				:SetMargin(4, 0, 0, 0)
				:SetPopoutTitle(L["Ledger Inventory Value"])
				:SetSettingInfo(private, "valuePriceSource")
				:SetAction("OnValueChanged", "ACTION_UPDATE_CONTENT")
			)
		)
		:AddChild(UIElements.New("ListContainer", "content")
			:AddChild(UIElements.New("LedgerInventoryScrollTable", "scrollTable")
				:BindElement(state, "scrollTable")
				:SetSettings(private.settings, "ledgerInventoryScrollingTable")
				:SetQuery(private.query)
			)
		)
		:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetMargin(0, 0, 8, 0)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("Text", "label")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Total Value"]..":")
			)
			:AddChild(UIElements.New("Text", "value")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(state:PublisherForFunctionWithKeys(Money.ToStringForUI, "totalValue"))
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)

	private.manager:ProcessAction("ACTION_UPDATE_CONTENT")
	return frame
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerInventoryUIState>
---@param state LedgerInventoryUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_GROUP_FILTER_CHANGED" then
		wipe(private.groupFilter)
		for groupPath in state.groupSelector:SelectedGroupIterator() do
			private.groupFilter[groupPath] = true
		end
		return manager:ProcessAction("ACTION_UPDATE_CONTENT")
	elseif action == "ACTION_UPDATE_CONTENT" then
		local nameFilter = String.Escape(state.searchFilter)
		nameFilter = nameFilter ~= "" and nameFilter or nil
		local groupFilter = next(private.groupFilter) and private.groupFilter or nil
		state.scrollTable:SetFilters(nameFilter, groupFilter)

		local totalValue = 0
		for _, itemTotalValue in private.query:Iterator("totalValue") do
			if not Math.IsNan(itemTotalValue) then
				totalValue = totalValue + itemTotalValue
			end
		end
		state.totalValue = totalValue
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CollectQuantityInfo(iter, ...)
	local numFields = select("#", ...)
	assert(numFields > 0 and numFields <= 3)
	local field1, field2, field3 = ...
	for _, levelItemString, quantity1, quantity2, quantity3 in iter do
		private.quantityTemp.items[levelItemString] = true
		private.quantityTemp[field1][levelItemString] = quantity1
		if field2 then
			private.quantityTemp[field2][levelItemString] = quantity2
			if field3 then
				private.quantityTemp[field3][levelItemString] = quantity3
			end
		end
	end
end

function private.TotalValueVirtualField(levelItemString, totalQuantity)
	local price = CustomString.GetValue(private.valuePriceSource, levelItemString)
	if not price then
		return Math.GetNan()
	end
	return price * totalQuantity
end

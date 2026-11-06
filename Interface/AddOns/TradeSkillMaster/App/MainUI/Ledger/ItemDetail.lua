-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local ItemDetail = App:Init("MainUI.Ledger.ItemDetail")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local TransactionsService = App:From("LibTSMService"):Include("Ledger.Transactions")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Accounting = App:From("LibTSMApp"):Include("Accounting")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	manager = nil,
	backCallback = nil,
	topPlayerQuantityTemp = {},
	topPlayersTemp = {},
}
local NUM_TOP_PLAYERS = 3
local TOTAL_PRICE_ARG_FIELDS = { "price", "quantity" }
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerItemDetailUIState")
	:AddStringField("recordType", "sale")
	:AddDeferredStringField("itemString")
	:AddStringField("topPlayers", "")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(ItemDetail, function(db)
	private.settings = db:NewView("ItemDetailSettings")
		:AddKey("global", "mainUIContext", "ledgerDetailScrollingTable")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_ITEM_DETAIL", state, private.ActionHandler)
		:AddFrameBuilder(private.GetItemDetailFrame)

	-- Set up some computed state properties.
	private.manager:SetStateFromPublisher("topPlayers", state:PublisherForFunctionWithKeys(private.StateToTopPlayers, "recordType", "itemString"))
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the item detail code.
---@param backCallback fun() The function to call to navigate back
function ItemDetail.Configure(backCallback)
	private.backCallback = backCallback
end

---Gets the item detail frame.
---@param itemString string The item string to show
---@param recordType LedgerTransactionType The record type to select by default
---@return BaseFrame
function ItemDetail.GetFrame(itemString, recordType)
	return private.manager:BuildFrame(itemString, recordType)
end



-- ============================================================================
-- Item Detail UI
-- ============================================================================

---@param state LedgerItemDetailUIState
function private.GetItemDetailFrame(state, itemString, recordType)
	state.itemString = itemString
	state.recordType = recordType
	local recordAndItemPublisher = state:PublisherForKeys("recordType", "itemString")
		:Share()
	local isSalePublisher = state:Publisher("recordType")
		:ToBooleanEquals("sale")
		:Share()
	return UIElements.New("BaseFrame", "content")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "top")
			:SetLayout("VERTICAL")
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("BackButton", "button")
					:SetAction("OnClick", "ACTION_BACK")
				)
				:AddChild(UIElements.New("BaseButton", "icon")
					:SetSize(16, 16)
					:SetMargin(8, 4, 0, 0)
					:SetBackground(ItemInfo.GetTexture(state.itemString))
					:SetTooltip(state.itemString)
				)
				:AddChild(UIElements.New("Text", "itemName")
					:SetFont("ITEM_BODY1")
					:SetText(UIUtils.GetDisplayItemName(state.itemString) or "?")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 8, 0)
				:SetPadding(8)
				:SetRoundedBackgroundColor("container/medium")
				:SetBorderColor("outline/variant")
				:AddChild(UIElements.New("BaseFrame", "heading")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("BaseButton", "saleBtn")
						:SetWidth("AUTO")
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetTextColor(isSalePublisher:ReplaceBooleanWith("accent/main", "on/surface/low"))
						:SetText(L["Sale Data"])
						:SetAction("OnClick", "ACTION_SHOW_SALES")
					)
					:AddChild(UIElements.New("BaseButton", "buyBtn")
						:SetWidth("AUTO")
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetTextColor(isSalePublisher:ReplaceBooleanWith("on/surface/low", "accent/main"))
						:SetText(L["Purchase Data"])
						:SetAction("OnClick", "ACTION_SHOW_BUYS")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "total")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetJustifyH("RIGHT")
						:SetText(L["Total"])
					)
					:AddChild(UIElements.New("Text", "last7")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetJustifyH("RIGHT")
						:SetText(L["Last 7 Days"])
					)
					:AddChild(UIElements.New("Text", "last30")
						:SetWidth(120)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetJustifyH("RIGHT")
						:SetText(L["Last 30 Days"])
					)
				)
				:AddChild(UIElements.New("BaseFrame", "quantity")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 4, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(isSalePublisher:ReplaceBooleanWith(L["Quantity Sold:"], L["Quantity Purchased:"]))
					)
					:AddChild(UIElements.New("Text", "total")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToQuantityText, nil))
					)
					:AddChild(UIElements.New("Text", "last7")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToQuantityText, SECONDS_PER_DAY * 7))
					)
					:AddChild(UIElements.New("Text", "last30")
						:SetWidth(120)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToQuantityText, SECONDS_PER_DAY * 30))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "avgPrice")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 4, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["Average Prices:"])
					)
					:AddChild(UIElements.New("Text", "total")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToAveragePriceText, nil))
					)
					:AddChild(UIElements.New("Text", "last7")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToAveragePriceText, SECONDS_PER_DAY * 7))
					)
					:AddChild(UIElements.New("Text", "last30")
						:SetWidth(120)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToAveragePriceText, SECONDS_PER_DAY * 30))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "totalPrice")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 4, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(L["Total Prices:"])
					)
					:AddChild(UIElements.New("Text", "total")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToTotalPriceText, nil))
					)
					:AddChild(UIElements.New("Text", "last7")
						:SetWidth(120)
						:SetMargin(0, 8, 0, 0)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToTotalPriceText, SECONDS_PER_DAY * 7))
					)
					:AddChild(UIElements.New("Text", "last30")
						:SetWidth(120)
						:SetFont("TABLE_XSMALL")
						:SetJustifyH("RIGHT")
						:SetText(recordAndItemPublisher:Map(private.StateToTotalPriceText, SECONDS_PER_DAY * 30))
					)
				)
				:AddChild(UIElements.New("BaseFrame", "top")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 4, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetMargin(0, 4, 0, 0)
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(isSalePublisher:ReplaceBooleanWith(L["Top Buyers"]..":", L["Top Sellers"]..":"))
					)
					:AddChild(UIElements.New("Text", "value")
						:SetFont("BODY_XSMALL")
						:SetText(state:Publisher("topPlayers"))
					)
				)
			)
		)
		:AddChild(UIElements.New("ListContainer", "content")
			:AddChild(UIElements.New("LedgerDetailScrollTable", "scrollingTable")
				:SetSettings(private.settings, "ledgerDetailScrollingTable")
				:SetQuery(TransactionsService.CreateQuery()
					:Equal("filteredItemString", state.itemString)
					:VirtualField("totalPrice", "number", private.TotalPriceVirtualField, TOTAL_PRICE_ARG_FIELDS)
				)
				:SetDeleteFunctions(Accounting.CanDeleteTransactionByUUID, TransactionsService.RemoveRowByUUID)
			)
		)
		:AddCancellable(recordAndItemPublisher:EndShare())
		:AddCancellable(isSalePublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerItemDetailUIState>
---@param state LedgerItemDetailUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_BACK" then
		private.backCallback()
	elseif action == "ACTION_SHOW_SALES" then
		state.recordType = "sale"
	elseif action == "ACTION_SHOW_BUYS" then
		state.recordType = "buy"
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.TotalPriceVirtualField(price, quantity)
	return price * quantity
end

---@param state LedgerItemDetailUIState
function private.StateToQuantityText(state, minTime)
	return TransactionsService.GetQuantity(state.itemString, minTime, state.recordType)
end

---@param state LedgerItemDetailUIState
function private.StateToAveragePriceText(state, minTime)
	return Money.ToStringForUI(TransactionsService.GetAveragePrice(state.itemString, minTime, state.recordType))
end

---@param state LedgerItemDetailUIState
function private.StateToTotalPriceText(state, minTime)
	return Money.ToStringForUI(TransactionsService.GetTotalPrice(state.itemString, minTime, state.recordType))
end

function private.StateToTopPlayers(recordType, itemString)
	if not itemString then
		return ""
	end
	assert(not next(private.topPlayerQuantityTemp) and not next(private.topPlayersTemp))
	TransactionsService.CreateQuery()
		:AutoRelease()
		:Equal("filteredItemString", itemString)
		:Equal("type", recordType)
		:GroupedSum("otherPlayer", "quantity", private.topPlayerQuantityTemp)
	Table.GetKeys(private.topPlayerQuantityTemp, private.topPlayersTemp)
	Table.SortWithValueLookup(private.topPlayersTemp, private.topPlayerQuantityTemp, true)
	local numTopPlayers = min(#private.topPlayersTemp, NUM_TOP_PLAYERS)
	for i = 1, numTopPlayers do
		local player = private.topPlayersTemp[i]
		local quantity = private.topPlayerQuantityTemp[player]
		private.topPlayersTemp[i] = player..Theme.GetColor("on/surface/low"):ColorText(" ("..quantity..")")
	end
	local topPlayers = #private.topPlayersTemp > 0 and table.concat(private.topPlayersTemp, ", ", 1, numTopPlayers) or L["None"]
	Table.WipeAndDeallocate(private.topPlayerQuantityTemp)
	Table.WipeAndDeallocate(private.topPlayersTemp)
	return topPlayers
end

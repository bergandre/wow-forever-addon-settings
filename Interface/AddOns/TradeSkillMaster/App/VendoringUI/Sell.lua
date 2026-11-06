-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Sell = App:Init("VendoringUI.Sell")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Item = App:From("LibTSMWoW"):Include("API.Item")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local Vendoring = App:From("LibTSMApp"):Include("Vendoring")
local private = {
	settings = nil,
	manager = nil,
	itemsTemp = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringSellState")
	:AddDeferredClassField("query", "DatabaseQuery")
	:AddStringField("filterText", "")
	:Commit()

---@event VendoringSellAction
---| "ACTION_IGNORE_ITEM" -> itemString: string, isPermanent: boolean
---| "ACTION_SELL_ITEM" -> itemString: string
---| "ACTION_SELL_TRASH"
---| "ACTION_SELL_BOE"
---| "ACTION_SELL_ALL"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Sell, function(db)
	private.settings = db:NewView("SellSettings")
		:AddKey("global", "vendoringUIContext", "sellScrollingTable")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING_SELL", state, private.ActionHandler)
		:AddFrameBuilder(private.GetFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the sell frame.
---@return BaseFrame
function Sell.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Sell UI
-- ============================================================================

---@param state VendoringSellState
function private.GetFrame(state)
	UIUtils.AnalyticsRecordPathChange("vendoring", "sell")
	state.filterText = ""
	state.query = state.query or Vendoring.CreateBagsQuery()

	return UIElements.New("BaseFrame", "sell")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("Input", "searchInput")
			:SetHeight(24)
			:SetLeadIconTexture("iconPack.18x18/Search")
			:SetClearButtonEnabled(true)
			:AllowItemInsert()
			:SetHintText(L["Search Bags"])
			:BindValue(state, "filterText")
		)
		:AddChild(UIElements.New("ListContainer", "content")
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("VendorSellScrollTable", "items")
				:SetSettings(private.settings, "sellScrollingTable")
				:SetQuery(state.query, private.QueryResetFiltersFunc)
				:SetFilters(state:Publisher("filterText"))
				:SetAction("OnIgnoreItem", "ACTION_IGNORE_ITEM")
				:SetAction("OnSellItem", "ACTION_SELL_ITEM")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "sellTrashBtn")
				:SetText(L["Sell Trash"])
				:SetAction("OnClick", "ACTION_SELL_TRASH")
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "sellBOEBtn")
				:SetMargin(8, 8, 0, 0)
				:SetText(L["Sell BoEs"])
				:SetAction("OnClick", "ACTION_SELL_BOE")
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "sellAllBtn")
				:SetText(L["Sell All"])
				:SetAction("OnClick", "ACTION_SELL_ALL")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringSellState>
---@param state VendoringSellState
---@param action VendoringSellAction
---@param ... params<VendoringSellAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_IGNORE_ITEM" then
		local itemString, isPermanent = ...
		if isPermanent then
			Vendoring.IgnoreItemPermanent(itemString)
		else
			Vendoring.IgnoreItemSession(itemString)
		end
	elseif action == "ACTION_SELL_ITEM" then
		local itemString = ...
		Vendoring.SellItem(itemString)
	elseif action == "ACTION_SELL_TRASH" then
		for _, itemString, quality in state.query:Iterator("itemString", "quality") do
			if Item.IsQualityTrash(quality) then
				Vendoring.SellItem(itemString)
			end
		end
	elseif action == "ACTION_SELL_BOE" then
		-- Checking if an item is disenchantable might cause our query to change since it depends on the ItemInfo DB, so cache the list of items first
		assert(not next(private.itemsTemp))
		state.query:AsTable(private.itemsTemp, "itemString")
		for _, itemString in ipairs(private.itemsTemp) do
			if ItemInfo.IsDisenchantable(itemString) then
				Vendoring.SellItem(itemString)
			end
		end
		wipe(private.itemsTemp)
	elseif action == "ACTION_SELL_ALL" then
		for _, itemString in state.query:Iterator("itemString") do
			Vendoring.SellItem(itemString)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueryResetFiltersFunc(query)
	Vendoring.ResetBagsQuery(query)
end

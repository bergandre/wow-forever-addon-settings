-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Ledger = App:Init("MainUI.Ledger")
local Auctions = App:Include("MainUI.Ledger.Auctions")
local Inventory = App:Include("MainUI.Ledger.Inventory")
local ItemDetail = App:Include("MainUI.Ledger.ItemDetail")
local Other = App:Include("MainUI.Ledger.Other")
local Resale = App:Include("MainUI.Ledger.Resale")
local Transactions = App:Include("MainUI.Ledger.Transactions")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	manager = nil,
}
local PATH_SEP = "_"
local PATHS = {
	"inventory",
	"revenue",
	"revenue_sales",
	"revenue_other",
	"revenue_resale",
	"expenses",
	"expenses_purchases",
	"expenses_other",
	"auctions",
	"auctions_expired",
	"auctions_cancelled",
}
local DEFAULT_PATH = "inventory"
local PATH_NAME = {
	inventory = L["Inventory"],
	revenue = L["Revenue"],
	revenue_sales = L["Sales"],
	revenue_other = L["Other"],
	revenue_resale = L["Resale"],
	expenses = L["Expenses"],
	expenses_purchases = L["Purchases"],
	expenses_other = L["Other"],
	auctions = L["Failed Auctions"],
	auctions_expired = L["Expired"],
	auctions_cancelled = L["Cancelled"],
}
local PARENT_PATH = {
	revenue_sales = "revenue",
	revenue_other = "revenue",
	revenue_resale = "revenue",
	expenses_purchases = "expenses",
	expenses_other = "expenses",
	auctions_expired = "auctions",
	auctions_cancelled = "auctions",
}
local FIRST_CHILD_PATH = {
	revenue = "revenue_sales",
	expenses = "expenses_purchases",
	auctions = "auctions_expired",
}
local STATE_SCHEMA = Reactive.CreateStateSchema("LedgerUIState")
	:AddDeferredUIElementField("navFrame", "BaseFrame")
	:AddDeferredUIElementField("view", "ViewContainer")
	:AddOptionalStringField("selectedPath")
	:AddOptionalStringField("itemDetailRecordType")
	:AddOptionalStringField("itemDetailItemString")
	:Commit()

---@event LedgerAction
---| "ACTION_SET_SELECTED_PATH" -> path: string?
---| "ACTION_SHOW_ITEM" -> itemString: string, recordType: LedgerTransactionType
---| "ACTION_ITEM_DETAIL_BACK"



-- ============================================================================
-- Module Loading
-- ============================================================================

Ledger:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("LEDGER_INVENTORY", state, private.ActionHandler)
		:AddFrameBuilder(private.GetLedgerFrame)

	-- Clear the selected page when the frame is hidden
	private.manager:SetStateFromPublisher("selectedPath", state:Publisher("navFrame"):IgnoreIfNotEquals(nil))

	ItemDetail.Configure(private.manager:CallbackToProcessAction("ACTION_ITEM_DETAIL_BACK"))
	Auctions.Configure(private.manager:CallbackToProcessAction("ACTION_SHOW_ITEM"))
	Resale.Configure(private.manager:CallbackToProcessAction("ACTION_SHOW_ITEM"))
	Transactions.Configure(private.manager:CallbackToProcessAction("ACTION_SHOW_ITEM"))
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the Ledger frame.
---@return BaseFrame
function Ledger.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Ledger UI
-- ============================================================================

---@param state LedgerUIState
function private.GetLedgerFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "ledger")
	local frame = UIElements.New("BaseFrame", "ledger")
		:SetLayout("HORIZONTAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "navigation")
			:SetLayout("VERTICAL")
			:SetWidth(140)
			:SetPadding(8, 8, 0, 0)
			:SetMargin(0, 16, 0, 0)
			:SetRoundedBackgroundColor("container/medium")
			:BindElement(state, "navFrame")
			:AddChildrenWithFunction(private.AddNavButtons, state)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
		:AddChild(UIElements.New("ViewContainer", "content")
			:SetContext(state)
			:BindElement(state, "view")
			:SetNavCallback(private.ContentNavCallback)
			:AddPath("itemDetail")
		)

	for _, path in ipairs(PATHS) do
		state.view:AddPath(path)
	end

	private.manager:ProcessAction("ACTION_SET_SELECTED_PATH", DEFAULT_PATH)
	return frame
end

---@param navFrame BaseFrame
---@param state LedgerUIState
function private.AddNavButtons(navFrame, state)
	local selectedPathPublisher = state:Publisher("selectedPath")
		:Share()
	local selectedParentPathPublisher = state:PublisherForFunctionWithKeys(private.SelectedPathToParentPath, "selectedPath")
		:Share()
	for _, path in ipairs(PATHS) do
		local parentPath = PARENT_PATH[path]
		local button = UIElements.New(parentPath and "LedgerSecondaryNavButton" or "LedgerPrimaryNavButton", path)
			:SetHeight(20)
			:SetMargin(parentPath and 8 or 0, 0, 8, 0)
			:Configure(PATH_NAME[path], path)
			:SetIsSelected(selectedPathPublisher:ToBooleanEquals(path))
			:SetAction("OnClick", "ACTION_SET_SELECTED_PATH")
		if parentPath then
			button:SetShown(selectedParentPathPublisher:ToBooleanEquals(parentPath))
		end
		navFrame:AddChild(button)
	end
	navFrame:AddCancellable(selectedPathPublisher:EndShare())
	navFrame:AddCancellable(selectedParentPathPublisher:EndShare())
end

function private.ContentNavCallback(viewContainer, path)
	if path == "itemDetail" then
		local state = viewContainer:GetContext() ---@type LedgerUIState
		assert(state.itemDetailItemString and state.itemDetailRecordType)
		return ItemDetail.GetFrame(state.itemDetailItemString, state.itemDetailRecordType)
	elseif path == "inventory" then
		return Inventory.GetFrame()
	elseif path == "revenue_sales" then
		return Transactions.GetSalesFrame()
	elseif path == "revenue_other" then
		return Other.GetIncomeFrame()
	elseif path == "revenue_resale" then
		return Resale.GetFrame()
	elseif path == "expenses_purchases" then
		return Transactions.GetPurchasesFrame()
	elseif path == "expenses_other" then
		return Other.GetExpensesFrame()
	elseif path == "auctions_expired" then
		return Auctions.GetExpiredFrame()
	elseif path == "auctions_cancelled" then
		return Auctions.GetCancelledFrame()
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<LedgerUIState>
---@param state LedgerUIState
---@param action LedgerAction
---@param ... params<LedgerAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SET_SELECTED_PATH" then
		local path = ...
		if state.selectedPath == path then
			return
		elseif not path then
			state.selectedPath = nil
			return
		end

		-- Select the first child if applicable
		path = FIRST_CHILD_PATH[path] or path

		state.selectedPath = path
		state.navFrame:Draw()
		state.view:SetPath(path, true)
	elseif action == "ACTION_SHOW_ITEM" then
		local itemString, recordType = ...
		assert(recordType == "sale" or recordType == "buy")
		state.itemDetailItemString = itemString
		state.itemDetailRecordType = recordType
		state.view:SetPath("itemDetail", true)
	elseif action == "ACTION_ITEM_DETAIL_BACK" then
		assert(state.selectedPath)
		state.view:SetPath(state.selectedPath, true)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SelectedPathToParentPath(selectedPath)
	return selectedPath and strsplit(PATH_SEP, selectedPath) or nil
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Buy = App:Init("VendoringUI.Buy")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local Merchant = App:From("LibTSMWoW"):Include("API.Merchant")
local Event = App:From("LibTSMWoW"):Include("Service.Event")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Vendor = App:From("LibTSMService"):Include("Vendor")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringBuyState")
	:AddDeferredUIElementField("frame", "BaseFrame")
	:AddOptionalNumberField("altCost")
	:AddStringField("currencyText", "")
	:AddStringField("currencyName", "")
	:AddStringField("filterText", "")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Buy, function(db)
	private.settings = db:NewView("BuySettings")
		:AddKey("global", "vendoringUIContext", "buyScrollingTable")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING_BUY", state, private.ActionHandler)
		:AddFrameBuilder(private.GetFrame)

	if App.IsRetail() or App.IsForever() then
		-- Update the alt cost when the frame is shown or the currency update event fires
		private.manager:SetStateFromPublisher("altCost", state:Publisher("frame")
			:IgnoreNil()
			:Map(Merchant.GetCurrencies)
			:Map(1)
		)
		private.manager:SetStateFromPublisher("altCost", Event.GetPublisher("CURRENCY_DISPLAY_UPDATE")
			:Map(Merchant.GetCurrencies)
			:Map(1)
		)

		-- Set up some computed state properties
		private.manager:SetStateFromPublisher("currencyText", state:Publisher("altCost")
			:MapNonNil(private.AltCostToText)
			:CoalesceNil("")
			:IgnoreDuplicates()
		)
		private.manager:SetStateFromPublisher("currencyName", state:Publisher("altCost")
			:MapNonNil(private.AltCostToName)
			:CoalesceNil("")
			:IgnoreDuplicates()
		)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the buy frame.
---@return BaseFrame
function Buy.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Buy UI
-- ============================================================================

---@param state VendoringBuyState
function private.GetFrame(state)
	UIUtils.AnalyticsRecordPathChange("vendoring", "buy")
	state.filterText = ""
	local currencyTextPublisher = state:Publisher("currencyText")
		:Share()
	local hasAltCostPublisher = state:Publisher("altCost")
		:ToBooleanNotEquals(nil)
		:Share()
	return UIElements.New("BaseFrame", "buy")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:BindElement(state, "frame")
		:AddChild(UIElements.New("Input", "searchInput")
			:SetHeight(24)
			:SetLeadIconTexture("iconPack.18x18/Search")
			:SetClearButtonEnabled(true)
			:AllowItemInsert()
			:SetHintText(L["Search Vendor"])
			:BindValue(state, "filterText")
		)
		:AddChild(UIElements.New("ListContainer", "items")
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("VendorBuyScrollTable", "items")
				:SetSettings(private.settings, "buyScrollingTable")
				:SetQuery(Vendor.NewScannerQuery()
					:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
					:VirtualField("itemLevel", "number", ItemInfo.GetItemLevel, "itemString", -1)
				)
				:SetFilters(state:Publisher("filterText"))
			)
		)
		:AddChild(UIElements.New("BaseFrame", "summary")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetMargin(0, 0, 8, 0)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:DrawPublisher(currencyTextPublisher)
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("Text", "goldLabel")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Gold"]..":")
			)
			:AddChild(UIElements.New("PlayerGoldText", "goldValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
			)
			:AddChild(UIElements.New("Text", "currencyLabel")
				:SetWidth("AUTO")
				:SetMargin(24, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(state:Publisher("currencyName"):ToStringFormat("%s:"))
				:SetShown(hasAltCostPublisher)
			)
			:AddChild(UIElements.New("BaseButton", "currencyValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(currencyTextPublisher)
				:SetTooltip(state:Publisher([[altCost and ("currency:" .. altCost) or nil]]))
				:SetShown(hasAltCostPublisher)
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)
		:AddChild(UIElements.New("VendorRepairButton", "repairBtn")
			:SetMargin(0, 0, 8, 0)
		)
		:AddCancellable(currencyTextPublisher:EndShare())
		:AddCancellable(hasAltCostPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringBuyState>
---@param state VendoringBuyState
function private.ActionHandler(manager, state, action, ...)
	error("Unknown action: "..tostring(action))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AltCostToName(currencyId)
	local name = Currency.GetInfo(currencyId)
	return name
end

function private.AltCostToText(currencyId)
	local name, texture, amount = Currency.GetInfo(currencyId)
	if not amount or not texture or name == "" then
		return ""
	end
	return amount.." |T"..texture..":12|t"
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Buyback = App:Init("VendoringUI.Buyback")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Merchant = App:From("LibTSMWoW"):Include("API.Merchant")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Vendor = App:From("LibTSMService"):Include("Vendor")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("VendoringBuybackState")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Buyback, function(db)
	private.settings = db:NewView("BuybackSettings")
		:AddKey("global", "vendoringUIContext", "buybackScrollingTable")
		:Commit()

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("VENDORING_BUYBACK", state, private.ActionHandler)
		:AddFrameBuilder(private.GetFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the buyback frame.
---@return BaseFrame
function Buyback.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Buyback UI
-- ============================================================================

function private.GetFrame()
	UIUtils.AnalyticsRecordPathChange("vendoring", "buyback")
	return UIElements.New("BaseFrame", "buyback")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("ListContainer", "content")
			:AddChild(UIElements.New("VendorBuybackScrollTable", "items")
				:SetSettings(private.settings, "buybackScrollingTable")
				:SetQuery(Vendor.NewBuybackScannerQuery()
					:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
				)
				:SetAction("OnBuyback", "ACTION_BUYBACK")
			)
		)
		:AddChild(UIElements.New("BaseFrame", "summary")
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetMargin(0, 0, 8, 0)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
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
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
		)
		:AddChild(UIElements.New("MediumPrimaryActionButton", "buybackAllBtn")
			:SetMargin(0, 0, 8, 0)
			:SetText(L["Buyback All"])
			:SetAction("OnClick", "ACTION_BUYBACK_ALL")
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<VendoringBuybackState>
---@param state VendoringBuybackState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_BUYBACK" then
		local index = ...
		Merchant.BuybackItem(index)
	elseif action == "ACTION_BUYBACK_ALL" then
		local query = Vendor.NewBuybackScannerQuery()
			:AutoRelease()
		for _, index in query:Iterator("index") do
			Merchant.BuybackItem(index)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end

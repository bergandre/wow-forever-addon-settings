-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Accounting = App:Init("MainUI.Settings.Accounting")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Auctions = App:From("LibTSMService"):Include("Ledger.Auctions")
local Money = App:From("LibTSMService"):Include("Ledger.Money")
local Transactions = App:From("LibTSMService"):Include("Ledger.Transactions")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
}
local SETTING_TOOLTIPS = {
	trackTrades = L["If enabled, TSM will automatically track trades where a single type of item is exchanged for an amount of gold as a sale or purchase."],
	autoTrackTrades = L["Disables the confirmation for tracking sales / purchases from trades."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("AccountingSettingsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddNumberField("days", 365)
	:AddBooleanField("daysIsValid", true)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Accounting, function(db)
	private.settings = db:NewView("AccountingSettings")
		:AddKey("global", "accountingOptions", "trackTrades")
		:AddKey("global", "accountingOptions", "autoTrackTrades")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("ACCOUNTING_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetAccountingSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the accounting settings frame.
---@return BaseScrollFrame
function Accounting.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Accounting Settings UI
-- ============================================================================

---@param state AccountingSettingsUIState
function private.GetAccountingSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "accounting")
	return UIElements.New("BaseScrollFrame", "accountingSettings")
		:SetPadding(8, 8, 8, 0)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "accounting")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general Accounting options are below."])
			:AddChild(UIElements.New("BaseFrame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "tradeCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Track Sales / Purchases via trade"])
					:SetSettingInfo(private.settings, "trackTrades")
					:SetTooltip(SETTING_TOOLTIPS.trackTrades)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "tradePromptCheckbox")
					:SetWidth("AUTO")
					:SetText(L["Don't prompt to record trades"])
					:SetSettingInfo(private.settings, "autoTrackTrades")
					:SetTooltip(SETTING_TOOLTIPS.autoTrackTrades)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "clearOld")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Clear Old Data"], L["You can clear old Accounting data for the current realm below to keep things running smoothly."])
			:AddChild(UIElements.New("BaseFrame", "daysOld")
				:SetLayout("HORIZONTAL")
				:SetHeight(46)
				:AddChild(UIElements.New("SettingsField", "days")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Remove Data Older Than (Days)"])
					:AddChild(UIElements.New("NumberInput", "input")
						:SetHeight(24)
						:SetHintText(L["Number of days"])
						:SetValidRange(0, 10000)
						:SetValue(365)
						:BindIsValid(state, "daysIsValid")
						:BindValue(state, "days")
					)
				)
				:AddChild(UIElements.New("SmallPrimaryActionButton", "clearBtn")
					:SetWidth("AUTO")
					:SetMargin(0, 0, 22, 0)
					:SetPadding(16, 16, 0, 0)
					:SetText(L["Clear Data"])
					:SetDisabled(state:Publisher("daysIsValid"):InvertBoolean())
					:SetAction("OnClick", "ACTION_CLEAR")
				)
			)
		)
end



-- ============================================================================
-- Action Handler
-- ===========================================================================

---@param manager UIManager<AccountingSettingsUIState>
---@param state AccountingSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLEAR" then
		local desc = format(L["Are you sure you want to clear accounting data older than %d days for the current realm?"], state.days)
		state.frame:GetBaseElement():ShowConfirmationDialog(L["Clear Old Data?"], desc, manager:CallbackToProcessAction("ACTION_CLEAR_CONFIRMED"))
	elseif action == "ACTION_CLEAR_CONFIRMED" then
		local numCleared = 0
		numCleared = numCleared + Transactions.RemoveOldData(state.days)
		numCleared = numCleared + Money.RemoveOldData(state.days)
		numCleared = numCleared + Auctions.RemoveOldData(state.days)
		ChatMessage.PrintfUser(L["Removed a total of %s old records."], numCleared)
	else
		error("Unknown action: "..tostring(action))
	end
end

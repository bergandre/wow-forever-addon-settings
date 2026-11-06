-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Other = App:Init("MailingUI.Other")
local EnumType = App:From("LibTSMUtil"):Include("BaseType.EnumType")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local MoneyFormatter = App:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local GoldTracker = App:From("LibTSMService"):Include("Ledger.GoldTracker")
local Mail = App:From("LibTSMService"):Include("Mail")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Mailing = App:From("LibTSMApp"):Include("Mailing")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local private = {
	manager = nil,
	settings = nil,
	itemsTemp = {},
}
local SEND_TYPE = EnumType.New("MAILING_OTHER_SEND_TYPE", {
	DISENCHANT = EnumType.NewValue(),
	GOLD = EnumType.NewValue(),
})
local STATE_SCHEMA = Reactive.CreateStateSchema("MailingOtherUIState")
	:AddNumberField("playerGold", 0)
	:AddStringField("disenchantChar", "")
	:AddBooleanField("disenchantCharValid", false)
	:AddStringField("goldChar", "")
	:AddBooleanField("goldCharValid", false)
	:AddStringField("goldLimitRaw", "")
	:AddOptionalNumberField("goldLimit")
	:AddNumberField("sendMoney", 0)
	:AddOptionalEnumField("sending", SEND_TYPE)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Other:OnModuleLoad(function()
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_OTHER", state, private.ActionHandler)
		:AddFrameBuilder(private.GetOtherFrame)

	-- Register for the player money updating
	private.manager:AddCancellable(GoldTracker.MoneyPublisher()
		:AssignToTableKey(state, "playerGold")
	)

	-- Set up some computed state properties
	private.manager:SetStateFromPublisher("disenchantCharValid", state:PublisherForFunctionWithKeys(Mail.IsValidRecipient, "disenchantChar"))
	private.manager:SetStateFromPublisher("sendMoney", state:Publisher([[goldLimit and (playerGold - 30 - goldLimit) or 0]]))
	private.manager:SetStateFromPublisher("goldCharValid", state:PublisherForFunctionWithKeys(Mail.IsValidRecipient, "goldChar"))
	private.manager:SetStateFromPublisher("goldLimit", state:PublisherForFunctionWithKeys(private.ConvertLimitValue, "goldLimitRaw"))
end)

AddonSettings.RegisterOnLoad(Other, function(db)
	private.settings = db:NewView("OtherSettings")
		:AddKey("factionrealm", "internalData", "mailDisenchantablesChar")
		:AddKey("factionrealm", "internalData", "mailExcessGoldChar")
		:AddKey("factionrealm", "internalData", "mailExcessGoldLimit")
		:AddKey("global", "mailingOptions", "deMaxQuality")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()

	-- Mirror the disenchant character / excess gold character / excess gold limit between the state and the settings
	private.manager:MirrorStateWithTable("disenchantChar", private.settings, "mailDisenchantablesChar")
	private.manager:MirrorStateWithTable("goldChar", private.settings, "mailExcessGoldChar")
	private.manager:MirrorStateWithTable("goldLimit", private.settings, "mailExcessGoldLimit")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the other frame.
---@return BaseFrame
function Other.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Other UI
-- ============================================================================

---@param state MailingOtherUIState
function private.GetOtherFrame(state)
	UIUtils.AnalyticsRecordPathChange("mailing", "other")
	local sendingPublisher = state:Publisher("sending")
		:Share()
	return UIElements.New("BaseFrame", "other")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("Text", "enchant")
			:SetHeight(24)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetText(L["Mail Disenchantables"])
		)
		:AddChild(UIElements.New("Text", "enchantDesc")
			:SetHeight(20)
			:SetMargin(0, 0, 4, 0)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetTextColor("on/surface/low")
			:SetText(L["Quickly mail all excess disenchantable items to a character"])
		)
		:AddChild(UIElements.New("BaseFrame", "enchantHeader")
			:SetLayout("HORIZONTAL")
			:SetHeight(46)
			:SetMargin(0, 0, 8, 0)
			:AddChild(private.CreateField("recipient", L["Recipient"])
				:SetMargin(0, 8, 0, 0)
				:AddChild(UIElements.New("ComboBox", "input")
					:SetHeight(24)
					:SetHintText(L["Enter recipient name"])
					:SetIconTexture("iconPack.18x18/Chevron/Down")
					:SetAutoComplete(PlayerInfo.GetConnectedAlts())
					:SetClearButtonEnabled(true)
					:AddMenuCategory(L["Recents"], Mail.RecentContactsIterator)
					:AddMenuCategory(L["Alts"], Mail.AltContactsIterator, private.settings.regionWide)
					:AddMenuCategory(L["Friends"], Mail.FriendContactsIterator)
					:AddMenuCategory(L["Guild"], Mail.GuildContactsIterator)
					:MirrorValueState(state, "disenchantChar")
				)
			)
			:AddChild(UIElements.New("SmallPrimaryActionButton", "send")
				:SetWidth("AUTO")
				:SetMargin(0, 0, 22, 0)
				:SetPadding(16, 16, 0, 0)
				:SetText(sendingPublisher:ToBooleanEquals(SEND_TYPE.DISENCHANT):ReplaceBooleanWith(L["Sending..."], L["Send Disenchantables"]))
				:SetPressed(sendingPublisher:ToBooleanEquals(SEND_TYPE.DISENCHANT))
				:SetDisabled(state:Publisher([[(sending and true or false) or not disenchantCharValid]]))
				:SetAction("OnClick", "ACTION_SEND_DISENCHANT")
			)
		)
		:AddChild(UIElements.New("Text", "gold")
			:SetHeight(24)
			:SetMargin(0, 0, 24, 0)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetText(L["Send Excess Gold to Banker"])
		)
		:AddChild(UIElements.New("Text", "goldDesc")
			:SetHeight(20)
			:SetMargin(0, 0, 4, 0)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetTextColor("on/surface/low")
			:SetText(L["Quickly mail all excess gold (limited to a certain amount) to a character"])
		)
		:AddChild(UIElements.New("BaseFrame", "goldHeader")
			:SetLayout("HORIZONTAL")
			:SetHeight(46)
			:SetMargin(0, 0, 8, 0)
			:AddChild(private.CreateField("recipient", L["Recipient"])
				:SetMargin(0, 8, 0, 0)
				:AddChild(UIElements.New("ComboBox", "input")
					:SetHeight(24)
					:SetHintText(L["Enter recipient name"])
					:SetIconTexture("iconPack.18x18/Chevron/Down")
					:SetAutoComplete(PlayerInfo.GetConnectedAlts())
					:SetClearButtonEnabled(true)
					:AddMenuCategory(L["Recents"], Mail.RecentContactsIterator)
					:AddMenuCategory(L["Alts"], Mail.AltContactsIterator, private.settings.regionWide)
					:AddMenuCategory(L["Friends"], Mail.FriendContactsIterator)
					:AddMenuCategory(L["Guild"], Mail.GuildContactsIterator)
					:MirrorValueState(state, "goldChar")
				)
			)
			:AddChild(private.CreateField("limit", L["Reserve"])
				:SetWidth(128)
				:SetMargin(0, 8, 0, 0)
				:AddChild(UIElements.New("Input", "input")
					:SetHeight(24)
					:SetJustifyH("RIGHT")
					:SetValidateFunc(private.LimitValidateFunc)
					:SetValue(state:Publisher("goldLimit"):MapNonNil(Money.ToStringForUIShort):CoalesceNil(""))
					:BindValue(state, "goldLimitRaw")
				)
			)
			:AddChild(UIElements.New("SmallPrimaryActionButton", "send")
				:SetWidth("AUTO")
				:SetMargin(0, 0, 22, 0)
				:SetPadding(16, 16, 0, 0)
				:SetText(sendingPublisher:ToBooleanEquals(SEND_TYPE.GOLD):ReplaceBooleanWith(L["Sending..."], L["Send Gold"]))
				:SetPressed(sendingPublisher:ToBooleanEquals(SEND_TYPE.GOLD))
				:SetDisabled(state:Publisher([[(sending and true or false) or not goldCharValid or sendMoney <= 0]]))
				:SetAction("OnClick", "ACTION_SEND_GOLD")
			)
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddCancellable(sendingPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MailingOtherUIState>
---@param state MailingOtherUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SEND_DISENCHANT" then
		assert(not next(private.itemsTemp))
		BagTracking.CreateQueryBags()
			:AutoRelease()
			:Equal("isBound", false)
			:Function("itemString", ItemInfo.IsDisenchantable)
			:VirtualField("quality", "number", ItemInfo.GetQuality, "itemString", math.huge)
			:LessThanOrEqual("quality", private.settings.deMaxQuality)
			:GroupedSum("itemString", "quantity", private.itemsTemp)
		if next(private.itemsTemp) then
			state.sending = SEND_TYPE.DISENCHANT
			Mailing.PrintSendMessage(0, private.itemsTemp, state.disenchantChar)
			Mail.SendItems(private.itemsTemp, state.disenchantChar, "TSM Mailing: Dsenchantables", manager:CallbackToProcessAction("ACTION_DONE_SENDING"))
		else
			ChatMessage.PrintUser(L["Nothing to send."])
		end
		Table.WipeAndDeallocate(private.itemsTemp)
	elseif action == "ACTION_SEND_GOLD" then
		state.sending = SEND_TYPE.GOLD
		Mailing.PrintSendMessage(state.sendMoney, nil, state.goldChar)
		Mail.SendGold(state.sendMoney, state.goldChar, "TSM Mailing: Excess Gold", manager:CallbackToProcessAction("ACTION_DONE_SENDING"))
	elseif action == "ACTION_DONE_SENDING" then
		state.sending = nil
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ConvertLimitValue(value)
	value = gsub(value, String.Escape(MoneyFormatter.GetLargeNumberSeparator()), "")
	value = tonumber(value) or Money.FromString(value)
	if not value then
		return nil
	end
	return value > 0 and value <= Currency.GetMaxMoney() and value or nil
end

function private.LimitValidateFunc(value)
	return private.ConvertLimitValue(value) and true or false
end

---@param id string
---@param label string
---@return BaseFrame
function private.CreateField(id, label)
	return UIElements.New("BaseFrame", id)
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Text", "label")
			:SetHeight(20)
			:SetPadding(4, 4, 0, 0)
			:SetMargin(0, 0, 0, 2)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(label)
		)
end

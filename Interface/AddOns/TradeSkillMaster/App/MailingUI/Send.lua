-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Send = App:Init("MailingUI.Send")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local MoneyFormatter = App:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Database = App:From("LibTSMDatabase"):Include("Database")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local Inbox = App:From("LibTSMWoW"):Include("API.Inbox")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = App:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = App:From("LibTSMWoW"):Include("UI.DefaultUI")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local Mail = App:From("LibTSMService"):Include("Mail")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Mailing = App:From("LibTSMApp"):Include("Mailing")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local private = {
	manager = nil,
	settings = nil,
	db = nil,
	query = nil,
	mailShowingTimer = nil,
	itemsTemp = {},
}
local COPPER_PER_GOLD = 100 * 100
local MAX_COD = 10000 * COPPER_PER_GOLD
local STATE_SCHEMA = Reactive.CreateStateSchema("MailingSendUIState")
	:AddDeferredUIElementField("frame", "BaseFrame")
	:AddDeferredUIElementField("recipientInput", "ComboBox")
	:AddDeferredUIElementField("subjectFrame", "BaseFrame")
	:AddDeferredUIElementField("itemsList", "SendItemsList")
	:AddDeferredUIElementField("footerFrame", "BaseFrame")
	:AddOptionalClassField("queryCancellable", "ReactivePublisher")
	:AddStringField("recipient", "")
	:AddStringField("subject", "")
	:AddStringField("body", "")
	:AddBooleanField("textEmpty", true)
	:AddStringField("moneyRaw", "")
	:AddNumberField("money", 0)
	:AddBooleanField("isCod", false)
	:AddNumberField("numItems", 0)
	:AddBooleanField("sending", false)
	:AddBooleanField("keepInfo", false)
	:Commit()

---@event MailingSendAction
---| "ACTION_FRAME_SHOW"
---| "ACTION_RESET_STATE"
---| "ACTION_SET_RECIPIENT" -> recipient: string
---| "ACTION_DRAG_RECEIVED"
---| "ACTION_SEND_MAIL"
---| "ACTION_DONE_SENDING"
---| "ACTION_ATTACHMENT_ADDED"
---| "ACTION_HANDLE_QUERY_UPDATE"
---| "ACTION_CLEAR_MAIL"
---| "ACTION_HANDLE_CLEAR_CLICK"
---| "ACTION_MAIL_HIDDEN"
---| "ACTION_SHOW_TEXT_DIALOG"
---| "ACTION_TEXT_DIALOG_HIDDEN"
---| "ACTION_REMOVE_ITEM" -> uuid: number



-- ============================================================================
-- Module Loading
-- ============================================================================

Send:OnModuleLoad(function()
	private.db = Database.NewSchema("MAILTRACKING_SEND_INFO")
		:AddStringField("itemString")
		:AddNumberField("quantity")
		:AddUniqueNumberField("slotId")
		:Commit()
	private.query = private.db:NewOwnedQuery()
	private.mailShowingTimer = DelayTimer.New("MAILING_SEND_MAIL_SHOWING", function()
		Inbox.SetSendMailShowing(true)
	end)

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_SEND", state, private.ActionHandler)
		:AddFrameBuilder(private.GetSendFrame)

	-- Set up some computed state properties
	private.manager:SetStateFromExpression("textEmpty", [[subject == "" and body == ""]])
	private.manager:SetStateFromPublisher("money", state:PublisherForFunctionWithKeys(private.ConvertMoneyValue, "moneyRaw", "isCod")
		:CoalesceNil(0)
	)
	private.manager:SetStateFromPublisher("numItems", private.query:Publisher()
		:Map("Count()")
	)

	private.manager:ProcessActionFromPublisher("ACTION_RESET_STATE", state:Publisher([[not frame and queryCancellable and true or false]])
		:IgnoreIfNotEquals(true)
	)

	-- Register for events
	DefaultUI.RegisterMailVisibleCallback(private.manager:CallbackToProcessAction("ACTION_MAIL_HIDDEN"), false)
	Event.Register("MAIL_FAILED", private.manager:CallbackToProcessAction("ACTION_DONE_SENDING"))
	Event.Register("MAIL_SEND_INFO_UPDATE", private.manager:CallbackToProcessAction("ACTION_ATTACHMENT_ADDED"))
end)

AddonSettings.RegisterOnLoad(Send, function(db)
	private.settings = db:NewView("SendSettings")
		:AddKey("global", "mailingOptions", "recentlyMailedList")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the current send recipient.
---@param recipient string The recipient character name
function Send.SetRecipient(recipient)
	private.manager:ProcessAction("ACTION_SET_RECIPIENT", recipient)
end

---Gets the groups frame.
---@return BaseFrame
function Send.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Send UI
-- ============================================================================

---@param state MailingSendUIState
function private.GetSendFrame(state)
	UIUtils.AnalyticsRecordPathChange("mailing", "send")
	assert(not state.queryCancellable)
	state.queryCancellable = private.query:Publisher()
		:CallFunction(private.manager:CallbackToProcessAction("ACTION_HANDLE_QUERY_UPDATE"))
		:Stored()
	local hasItemsPublisher = state:Publisher("numItems")
		:ToBooleanGreaterThanOrEquals(1)
		:IgnoreDuplicates()
		:Share()
	local textEmptyPublisher = state:Publisher("textEmpty")
		:Share()
	local sendingPublisher = state:Publisher("sending")
		:Share()
	return UIElements.New("BaseFrame", "send")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "top")
			:SetLayout("HORIZONTAL")
			:SetHeight(46)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("BaseFrame", "recipient")
				:SetLayout("VERTICAL")
				:SetWidth(300)
				:SetMargin(0, 8, 0, 0)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(20)
					:SetPadding(4, 4, 0, 0)
					:SetMargin(0, 0, 0, 2)
					:SetFont("BODY_SMALL_SEMIBOLD")
					:SetText(L["Recipient"])
				)
				:AddChild(UIElements.New("ComboBox", "input")
					:SetHeight(24)
					:BindElement(state, "recipientInput")
					:SetHintText(L["Enter recipient name"])
					:SetIconTexture("iconPack.18x18/Chevron/Down")
					:SetAutoComplete(PlayerInfo.GetConnectedAlts())
					:SetClearButtonEnabled(true)
					:AddMenuCategory(L["Recents"], Mail.RecentContactsIterator)
					:AddMenuCategory(L["Alts"], Mail.AltContactsIterator, private.settings.regionWide)
					:AddMenuCategory(L["Friends"], Mail.FriendContactsIterator)
					:AddMenuCategory(L["Guild"], Mail.GuildContactsIterator)
					:MirrorValueState(state, "recipient")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "subject")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("BaseFrame", "buttons")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:BindElement(state, "subjectFrame")
					:AddChild(UIElements.New("SmallTertiaryActionButton", "text")
						:SetWidth("AUTO")
						:SetPadding(8, 16, 0, 0)
						:SetText(textEmptyPublisher:Map(private.TextEmptyToSubjectButtonText))
						:SetAction("OnClick", "ACTION_SHOW_TEXT_DIALOG")
					)
					:AddChild(UIElements.New("SmallTertiaryActionButton", "button")
						:SetShown(textEmptyPublisher:InvertBoolean())
						:SetWidth("AUTO")
						:SetPadding(8, 8, 0, 0)
						:SetText(L["Edit"])
						:SetAction("OnClick", "ACTION_SHOW_TEXT_DIALOG")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
		)
		:AddChild(UIElements.New("ListContainer", "dragBox")
			:SetMargin(0, 0, 0, 8)
			:RegisterForDrag("LeftButton")
			:SetScript("OnReceiveDrag", private.manager:CallbackToProcessAction("ACTION_DRAG_RECEIVED"))
			:SetScript("OnMouseUp", private.manager:CallbackToProcessAction("ACTION_DRAG_RECEIVED"))
			:AddChild(UIElements.New("SendItemsList", "items")
				:BindElement(state, "itemsList")
				:SetQuery(private.query)
				:SetAction("OnRemoveItem", "ACTION_REMOVE_ITEM")
			)
			:AddChildNoLayout(UIElements.New("Text", "empty")
				:AddAnchor("LEFT", state.itemsList, 8, 0)
				:AddAnchor("RIGHT", state.itemsList, -8, 0)
				:SetHeight(20)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetTextColor("on/surface/low")
				:SetJustifyH("CENTER")
				:SetText(L["Drag & drop an item in to attach"])
				:SetShown(hasItemsPublisher:InvertBoolean())
			)
			:AddFooter(UIElements.New("BaseFrame", "footer")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:SetPadding(16, 16, 0, 0)
				:BindElement(state, "footerFrame")
				:AddChild(UIElements.New("Text", "postage")
					:SetWidth("AUTO")
					:SetFont("BODY_XSMALL")
					:SetText(state:PublisherForFunctionWithKeys(private.NumItemsToPostageText, "numItems"))
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "items")
					:SetWidth("AUTO")
					:SetFont("BODY_XSMALL")
					:SetJustifyH("RIGHT")
					:SetText(state:PublisherForFunctionWithKeys(private.NumItemsToItemsText, "numItems"))
					:SetShown(hasItemsPublisher)
				)
			)
		)
		:AddChild(UIElements.New("BaseFrame", "money")
			:SetLayout("HORIZONTAL")
			:SetHeight(32)
			:SetPadding(0, 0, 4, 4)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("Text", "amountText")
				:SetWidth("AUTO")
				:SetPadding(4, 4, 0, 0)
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Gold"])
			)
			:AddChild(UIElements.New("Input", "moneyInput")
				:SetWidth(107)
				:SetFont("BODY_XSMALL")
				:SetValidateFunc(private.MoneyValidateFunc, state)
				:SetJustifyH("RIGHT")
				:SetValue(state:PublisherForFunctionWithKeys(Money.ToStringExact, "money"))
				:BindValue(state, "moneyRaw")
			)
			:AddChild(UIElements.New("Checkbox", "cod")
				:SetSize("AUTO", 20)
				:SetMargin(16, 0, 0, 0)
				:SetText(L["Make COD"])
				:SetDisabled(hasItemsPublisher:InvertBoolean())
				:MirrorIsCheckedState(state, "isCod")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
		:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "sendMail")
				:SetText(sendingPublisher:ReplaceBooleanWith(L["Sending..."], L["Send Mail"]))
				:SetDisabled(state:PublisherForFunctionWithKeys(Mail.IsValidRecipient, "recipient"):InvertBoolean())
				:SetPressed(sendingPublisher)
				:SetAction("OnClick", "ACTION_SEND_MAIL")
				:SetTooltip(L["Hold SHIFT to keep the recipient populated."])
			)
			:AddChild(UIElements.New("MediumTertiaryActionButton", "clear")
				:SetWidth(96)
				:SetMargin(8, 0, 0, 0)
				:SetText(L["Clear All"])
				:SetAction("OnClick", "ACTION_HANDLE_CLEAR_CLICK")
				:SetTooltip(L["Hold SHIFT to keep the recipient populated."])
			)
		)
		:AddCancellable(hasItemsPublisher:EndShare())
		:AddCancellable(textEmptyPublisher:EndShare())
		:AddCancellable(sendingPublisher:EndShare())
		:WithProcessAction("ACTION_FRAME_SHOW")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MailingSendUIState>
---@param state MailingSendUIState
---@param action MailingSendAction
---@param ... params<MailingSendAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW" then
		private.mailShowingTimer:RunForFrames(2)
	elseif action == "ACTION_RESET_STATE" then
		assert(state.queryCancellable)
		state.queryCancellable:Cancel()
		state.queryCancellable = nil
		Mailing.StopSending()
		Inbox.SetSendMailShowing(false)
		private.db:Truncate()
	elseif action == "ACTION_SET_RECIPIENT" then
		local recipient = ...
		state.recipient = recipient
	elseif action == "ACTION_DRAG_RECEIVED" then
		local item, lockedSlotId = Inbox.ProcessSendCursor(state.numItems >= Inbox.GetMaxSendAttachments())
		if not item or not lockedSlotId then
			return
		elseif private.db:HasUniqueRow("slotId", lockedSlotId) then
			return
		end
		local quantity = BagTracking.GetQuantityBySlotId(lockedSlotId)
		if quantity == 0 then
			return
		end
		local itemString = ItemString.Get(item)
		private.db:InsertRow(itemString, quantity, lockedSlotId)
	elseif action == "ACTION_SEND_MAIL" then
		local money = state.isCod and -state.money or state.money
		state.recipientInput:SetFocused(false)
		private.UpdateRecentlyMailed(state.recipient)
		state.keepInfo = IsShiftKeyDown()
		local items = nil
		if state.numItems > 0 then
			assert(not next(private.itemsTemp))
			items = private.itemsTemp
			private.query:GroupedSum("itemString", "quantity", items)
		end
		state.sending = true
		private.db:SetQueryUpdatesPaused(true)
		Mailing.PrintSendMessage(money, items, state.recipient)
		Mail.SendLetter(state.recipient, state.subject, state.body, money, items, manager:CallbackToProcessAction("ACTION_DONE_SENDING"))
		if items then
			Table.WipeAndDeallocate(items)
		end
	elseif action == "ACTION_DONE_SENDING" then
		if not state.sending then
			return
		end
		state.sending = false
		private.db:SetQueryUpdatesPaused(false)
		manager:ProcessAction("ACTION_CLEAR_MAIL")
	elseif action == "ACTION_ATTACHMENT_ADDED" then
		if not state.frame or state.sending then
			return
		end
		if state.numItems >= Inbox.GetMaxSendAttachments() then
			Inbox.ShowMaxAttachmentError()
		else
			for i = 1, Inbox.GetMaxSendAttachments() do
				local itemLink, stackCount, itemName = Inbox.GetSendAttachment(i)
				if itemLink and stackCount and itemName then
					local itemString = ItemString.Get(itemLink)
					local slotId = BagTracking.CreateQueryBagsMailable()
						:AutoRelease()
						:OrderBy("slotId", true)
						:Equal("itemString", itemString)
						:Equal("quantity", stackCount)
						:Function("slotId", private.IsSlotIdUntracked)
						:GetFirstResult("slotId")
					if slotId then
						private.db:InsertRow(itemString, stackCount, slotId)
					end
					break
				end
			end
		end
		Inbox.ClearSendMail()
	elseif action == "ACTION_HANDLE_QUERY_UPDATE" then
		if not state.frame then
			return
		end
		state.subjectFrame:Draw()
		state.footerFrame:Draw()
	elseif action == "ACTION_CLEAR_MAIL" then
		if not state.keepInfo then
			manager:ProcessAction("ACTION_SET_RECIPIENT", "")
		end
		state.subject = ""
		state.body = ""
		state.moneyRaw = "0"
		state.isCod = false
		private.db:Truncate()
		if state.frame then
			state.subjectFrame:Draw()
			state.footerFrame:Draw()
		end
	elseif action == "ACTION_HANDLE_CLEAR_CLICK" then
		state.keepInfo = IsShiftKeyDown()
		return manager:ProcessAction("ACTION_CLEAR_MAIL")
	elseif action == "ACTION_MAIL_HIDDEN" then
		state.keepInfo = false
		return manager:ProcessAction("ACTION_CLEAR_MAIL")
	elseif action == "ACTION_SHOW_TEXT_DIALOG" then
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("MailSendTextDialog", "frame")
			:MirrorTextContentState(state, "subject", "body")
			:SetScript("OnHide", manager:CallbackToProcessAction("ACTION_TEXT_DIALOG_HIDDEN"))
		)
	elseif action == "ACTION_TEXT_DIALOG_HIDDEN" then
		if not state.subjectFrame then
			return
		end
		state.subjectFrame:Draw()
	elseif action == "ACTION_REMOVE_ITEM" then
		local uuid = ...
		private.db:DeleteRow(uuid)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param state MailingSendUIState
function private.MoneyValidateFunc(value, state)
	return private.ConvertMoneyValue(value, state.isCod) and true or false
end

function private.ConvertMoneyValue(value, isCod)
	value = gsub(value, String.Escape(MoneyFormatter.GetLargeNumberSeparator()), "")
	value = tonumber(value) or Money.FromString(value)
	if not value then
		return nil
	end
	local maxVal = isCod and MAX_COD or Currency.GetMaxMoney()
	return value >= 0 and value <= maxVal and value or nil
end

function private.IsSlotIdUntracked(slotId)
	return not private.db:HasUniqueRow("slotId", slotId)
end

function private.TextEmptyToSubjectButtonText(textEmpty)
	local iconKey = textEmpty and "iconPack.14x14/Add/Default" or "iconPack.14x14/Checkmark/Default"
	local text = textEmpty and L["Add subject & description (optional)"] or L["Subject & description added"]
	return TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey(iconKey, "accent/main")).." "..text
end

function private.NumItemsToItemsText(numItems)
	return format(L["%s Items Selected"], Theme.GetColor("positive/main"):ColorText(numItems.."/"..Inbox.GetMaxSendAttachments()))
end

function private.NumItemsToPostageText(numItems)
	return format(L["Total Postage"]..": %s", Money.ToStringForUI(30 * max(numItems, 1)))
end

function private.UpdateRecentlyMailed(recipient)
	if not Mail.IsValidRecipient(recipient) then
		return
	end

	local size = 0
	local oldestName = nil
	local oldestTime = nil
	for k, v in pairs(private.settings.recentlyMailedList) do
		size = size + 1
		if not oldestName or not oldestTime or oldestTime > v then
			oldestName = k
			oldestTime = v
		end
	end

	if size >= 20 then
		private.settings.recentlyMailedList[oldestName] = nil
	end

	private.settings.recentlyMailedList[recipient] = floor(App.GetTime())
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Inbox = App:From("LibTSMWoW"):Include("API.Inbox")
local SessionInfo = App:From("LibTSMWoW"):Include("Util.SessionInfo")
local Mail = App:From("LibTSMService"):Include("Mail")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailContentsFrame = UIElements.Define("MailContentsFrame", "BaseFrame")
MailContentsFrame._STATE_SCHEMA = MailContentsFrame._STATE_SCHEMA:Extend("MailContentsFrameState")
	:AddDeferredUIElementField("attachmentsFrame", "BaseFrame")
	:AddDeferredUIElementField("itemList", "MailItemsList")
	:AddNumberField("index", 0)
	:AddOptionalStringField("sender")
	:AddBooleanField("hasBody", false)
	:AddNumberField("money", 0)
	:AddNumberField("cod", 0)
	:AddNumberField("itemCount", 0)
	:AddBooleanField("noQueryItems", false)
	:AddBooleanField("canReply", false)
	:AddBooleanField("canDelete", false)
	:AddBooleanField("isTextTakeable", false)
	:AddBooleanField("textCreated", false)
	:AddStringField("subject", "")
	:AddBooleanField("isGM", false)
	:Commit()
MailContentsFrame:_AddActionScripts("OnMailClosed", "OnReply")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailContentsFrame:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._itemsQuery = nil ---@type DatabaseQuery!
end

function MailContentsFrame:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	local bodyPublisher = self._state:Publisher("index")
		:Map(private.GetMailBody)
		:Share()
		:ToBooleanNotEquals("")
		:AssignToTableKey(self._state, "hasBody")
	for _ in self._state:WithAutoStorePaused() do
		local showCodPublisher = self._state:Publisher("cod")
			:ToBooleanGreaterThanOrEquals(1)
			:Share()
		self
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:SetManager(self._childManager)
				:AddChild(UIElements.New("BaseFrame", "top")
					:SetLayout("HORIZONTAL")
					:SetHeight(40)
					:AddChild(UIElements.New("BackButton", "button")
						:SetMargin(0, 36, 0, 0)
						:SetAction("OnClick", "ACTION_BACK_BUTTON_CLICKED")
					)
					:AddChild(UIElements.New("Text", "title")
						:SetFont("BODY_BODY1_EXTRABOLD")
						:SetJustifyH("CENTER")
						:SetText(L["Open Mail"])
					)
					:AddChild(UIElements.New("SmallTertiaryActionButton", "button")
						:SetWidth(100)
						:SetText(TextureAtlas.GetTextureLink("iconPack.14x14/Duplicate")..L["Copy Letter"])
						:SetDisabled(self._state:Publisher([[textCreated or not isTextTakeable]]))
						:SetAction("OnClick", "ACTION_COPY_LETTER")
					)
				)
				:AddChild(UIElements.New("BaseFrame", "content")
					:SetLayout("VERTICAL")
					:SetPadding(1)
					:SetMargin(0, 0, 8, 0)
					:SetBackgroundColor("container/low")
					:SetBorderColor("outline/variant")
					:AddChild(UIElements.New("BaseFrame", "header")
						:SetLayout("VERTICAL")
						:SetPadding(4)
						:AddChild(UIElements.New("BaseFrame", "left")
							:SetLayout("HORIZONTAL")
							:SetHeight(24)
							:SetMargin(0, 0, 0, 4)
							:AddChild(UIElements.New("Text", "label")
								:SetWidth("AUTO")
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetText(L["From"]..": ")
							)
							:AddChild(UIElements.New("Text", "sender")
								:SetFont("BODY_SMALL")
								:SetText(self._state:Publisher("sender"):CoalesceNil(UNKNOWN))
								:SetTextColor(self._state:Publisher("isGM"):ReplaceBooleanWith("BLIZZARD_GM", "on/surface/low"))
							)
							:AddChild(UIElements.New("SmallTertiaryActionButton", "report")
								:SetShown(self._state:Publisher("index"):Map(Inbox.CanReport))
								:SetWidth(124)
								:SetText(L["Report Spam"])
								:SetAction("OnClick", "ACTION_REPORT_SPAM")
							)
						)
						:AddChild(UIElements.New("BaseFrame", "left")
							:SetLayout("HORIZONTAL")
							:SetHeight(20)
							:AddChild(UIElements.New("Text", "label")
								:SetWidth("AUTO")
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetText(L["Subject"]..": ")
							)
							:AddChild(UIElements.New("Text", "subject")
								:SetFont("BODY_SMALL")
								:SetText(self._state:Publisher("subject"))
							)
						)
					)
					:AddChild(UIElements.New("MultiLineInput", "input")
						:SetMargin(0, 0, 0, 12)
						:SetShown(self._state:Publisher("hasBody"))
						:SetReadOnly()
						:SetValue(bodyPublisher)
					)
					:AddChild(UIElements.New("BaseFrame", "attachments")
						:SetLayout("VERTICAL")
						:SetHeight(self._state:Publisher([[(hasBody and noQueryItems and 52) or 148]]))
						:BindElement(self._state, "attachmentsFrame")
						:AddChild(UIElements.New("BaseFrame", "header")
							:SetLayout("HORIZONTAL")
							:SetHeight(24)
							:SetMargin(0, 0, 0, 8)
							:AddChild(UIElements.New("Text", "text")
								:SetWidth("AUTO")
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetText(self._state:Publisher([[hasBody and noQueryItems]]):ReplaceBooleanWith(L["No Attachments"], L["Attachments"]))
							)
							:AddChild(UIElements.New("SmallTertiaryActionButton", "takeAll")
								:SetShown(self._state:Publisher("itemCount"):ToBooleanGreaterThanOrEquals(1))
								:SetWidth("AUTO")
								:SetPadding(8, 8, 0, 0)
								:SetText(L["Move all to Bags"])
								:SetAction("OnClick", "ACTION_TAKE_ALL")
							)
							:AddChild(UIElements.New("Spacer", "spacer"))
							:AddChild(UIElements.New("Text", "cod")
								:SetShown(showCodPublisher)
								:SetMargin(0, 5, 0, 0)
								:SetFont("BODY_SMALL_SEMIBOLD")
								:SetJustifyH("RIGHT")
								:SetText(L["C.O.D."]..":")
							)
							:AddChild(UIElements.New("Text", "codAmount")
								:SetShown(showCodPublisher)
								:SetWidth("AUTO")
								:SetMargin(0, 8, 0, 0)
								:SetFont("BODY_SMALL")
								:SetJustifyH("RIGHT")
								:SetText(self._state:PublisherForFunctionWithKeys(private.CodToText, "cod"))
							)
						)
						:AddChild(UIElements.New("MailItemsList", "items")
							:BindElement(self._state, "itemList")
							:SetAction("OnItemClick", "ACTION_HANDLE_ITEM_CLICKED")
						)
					)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "footer")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:SetMargin(0, 0, 8, 0)
				:SetManager(self._childManager)
				:AddChild(UIElements.New("MediumPrimaryActionButton", "reply")
					:SetMargin(0, 8, 0, 0)
					:SetText(L["Reply"])
					:SetDisabled(self._state:Publisher(format([[not sender or not canReply or sender == "%s"]], SessionInfo.GetCharacterName())))
					:SetAction("OnClick", "ACTION_REPLY")
				)
				:AddChild(UIElements.New("MediumPrimaryActionButton", "delete")
					:SetWidth(144)
					:SetText(self._state:Publisher("canDelete"):ReplaceBooleanWith(DELETE, MAIL_RETURN))
					:SetDisabled(self._state:Publisher([[canDelete and (cod > 0 or money > 0)]]))
					:SetAction("OnClick", "ACTION_DELETE")
				)
			)
			:AddCancellable(showCodPublisher:EndShare())
	end

	bodyPublisher:EndShare()

	-- Set up some computed state properties
	self._state:Publisher("index")
		:Share()
		:CallFunction(self:__closure("_UpdateHeaderInfoForIndex"))
		:Map(private.IndexToIsTextTakeable)
		:AssignToTableKey(self._state, "isTextTakeable")
		:Map(Inbox.CanDelete)
		:AssignToTableKey(self._state, "canDelete")
		:EndShare()

	-- Bypass the inbox check while a mail is open
	Mail.SetInboxCheckTimerBypassed(true)
end

function MailContentsFrame:Release()
	Mail.SetInboxCheckTimerBypassed(false)
	self.__super:Release()
	if self._itemsQuery then
		self._itemsQuery:Release()
		self._itemsQuery = nil
	end
end

---Sets the index of the mail being shown.
---@param index number The mail index
---@return self
function MailContentsFrame:SetIndex(index)
	assert(not self._itemsQuery)
	self._itemsQuery = Mail.NewItemQuery()
		:OrderBy("itemIndex", true)
		:Equal("index", index)
	self._state.itemList:SetQuery(self._itemsQuery)
	self._state.noQueryItems = self._itemsQuery:Count() == 0
	self._state.index = index
	self._state.attachmentsFrame:SetHeight((self._state.hasBody and self._state.noQueryItems and 52) or (self._state.hasBody and 148) or nil)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MailContentsFrame.__private:_UpdateHeaderInfoForIndex(index)
	local sender, money, cod, itemCount, subject, _, textCreated, isGM, canReply = Inbox.GetHeaderInfo(index)
	self._state.sender = sender
	self._state.money = money
	self._state.cod = cod
	self._state.itemCount = itemCount
	self._state.subject = subject or ""
	self._state.textCreated = textCreated or false
	self._state.isGM = isGM or false
	self._state.canReply = canReply or false
end

---@param manager UIManager<MailContentsFrameState>
---@param state MailContentsFrameState
function MailContentsFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_BACK_BUTTON_CLICKED" then
		self:_SendActionScript("OnMailClosed")
	elseif action == "ACTION_COPY_LETTER" then
		Inbox.TakeTextItem(self._state.index)
		self._state.isTextTakeable = false
	elseif action == "ACTION_HANDLE_ITEM_CLICKED" then
		local index, itemIndex = ...
		local _, _, cod = Inbox.GetHeaderInfo(index)
		if cod > 0 then
			self:GetBaseElement():ShowConfirmationDialog(L["Accept COD?"], format(L["Accepting this item will cost: %s"], Money.ToStringExact(cod)), manager:CallbackToProcessAction("ACTION_TAKE_ITEM"), itemIndex)
		else
			return manager:ProcessAction("ACTION_TAKE_ITEM", itemIndex)
		end
	elseif action == "ACTION_TAKE_ITEM" then
		local itemIndex = ...
		local hasSingleItem = self._itemsQuery:Count() == 1
		if itemIndex == 0 then
			Inbox.TakeMoney(state.index)
		else
			Inbox.TakeItem(state.index, itemIndex)
		end
		if hasSingleItem then
			self:_SendActionScript("OnMailClosed")
		end
	elseif action == "ACTION_TAKE_ALL" then
		local _, _, cod = Inbox.GetHeaderInfo(state.index)
		if cod > 0 then
			self:GetBaseElement():ShowConfirmationDialog(L["Accept COD?"], format(L["Accepting this item will cost: %s"], Money.ToStringExact(cod)), manager:CallbackToProcessAction("ACTION_AUTO_LOOT_MAIL"))
		else
			return manager:ProcessAction("ACTION_AUTO_LOOT_MAIL")
		end
	elseif action == "ACTION_AUTO_LOOT_MAIL" then
		-- Marks the mail as read
		Inbox.GetText(state.index)
		Inbox.AutoOpenMail(state.index)
		self:_SendActionScript("OnMailClosed")
	elseif action == "ACTION_REPORT_SPAM" then
		Inbox.ReportSpam(state.index)
	elseif action == "ACTION_REPLY" then
		local sender = Inbox.GetHeaderInfo(state.index)
		self:_SendActionScript("OnReply", sender)
	elseif action == "ACTION_DELETE" then
		local _, money, _, itemCount = Inbox.GetHeaderInfo(state.index)
		if Inbox.CanDelete(state.index) then
			if itemCount > 0 or money > 0 then
				return
			else
				Inbox.DeleteMail(state.index)
			end
		else
			Inbox.ReturnMail(state.index)
		end
		self:_SendActionScript("OnMailClosed")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IndexToIsTextTakeable(index)
	return select(2, Inbox.GetText(index)) or false
end

function private.CodToText(cod)
	return cod > 0 and Money.ToStringExact(cod, Theme.GetColor("error/main"):GetTextColorPrefix()) or ""
end

function private.GetMailBody(index)
	local mailType = Inbox.GetMailType(index)
	if mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
		local itemName, seller, bid, buyout = Inbox.GetInvoiceInfo(index)
		seller = Inbox.CoalesceSellerName(seller)
		local purchaseType = bid == buyout and BUYOUT or HIGH_BIDDER
		return strjoin(
			"\n",
			ITEM_PURCHASED_COLON.." "..(itemName or "?"),
			SOLD_BY_COLON.." "..seller.." ("..purchaseType..")",
			"",
			AMOUNT_PAID_COLON.." "..Money.ToStringExact(bid)
		)
	elseif mailType == Inbox.MAIL_TYPE.SALE.AUCTION then
		local itemName, buyer, bid, buyout, deposit, consignment = Inbox.GetInvoiceInfo(index)
		buyer = Inbox.CoalesceBuyerName(buyer)
		local purchaseType = bid == buyout and BUYOUT or HIGH_BIDDER
		return strjoin(
			"\n",
			ITEM_SOLD_COLON.." "..(itemName or "?"),
			PURCHASED_BY_COLON.." "..buyer.." ("..purchaseType..")",
			"",
			L["Sale Price"]..": "..Money.ToStringExact(bid),
			L["Deposit"]..": +"..Money.ToStringExact(deposit),
			L["Auction House Cut"]..": -"..Money.ToStringExact(consignment, Theme.GetColor("error/main"):GetTextColorPrefix()),
			"",
			AMOUNT_RECEIVED_COLON.." "..Money.ToStringExact(bid + deposit - consignment)
		)
	elseif mailType == Inbox.MAIL_TYPE.OTHER.TEMP_INVOICE then
		local itemName, buyer, bid, buyout, deposit, consignment = Inbox.GetInvoiceInfo(index)
		buyer = Inbox.CoalesceBuyerName(buyer)
		local purchaseType = bid == buyout and BUYOUT or HIGH_BIDDER
		return strjoin(
			"\n",
			ITEM_SOLD_COLON.." "..(itemName or "?"),
			PURCHASED_BY_COLON.." "..buyer.." ("..purchaseType..")",
			"",
			AUCTION_INVOICE_PENDING_FUNDS_COLON.." "..Money.ToStringExact(bid + deposit - consignment)
		)
	elseif mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER then
		local _, commission, crafter, recipeName = Inbox.GetCraftingOrderInfo(index)
		assert(commission)
		return strjoin(
			"\n",
			format(CRAFTING_ORDER_MAIL_ORDER_HEADER, recipeName),
			format(CRAFTING_ORDER_MAIL_FULFILLED_BY, crafter),
			"",
			CRAFTING_ORDER_MAIL_COMMISSION_PAID.." "..Money.ToStringExact(commission)
		)
	elseif mailType == Inbox.MAIL_TYPE.SALE.CRAFTING_ORDER then
		local _, commission, customer, recipeName = Inbox.GetCraftingOrderInfo(index)
		assert(commission)
		return strjoin(
			"\n",
			format(CRAFTING_ORDER_MAIL_ORDER_HEADER, recipeName),
			format(CRAFTING_ORDER_MAIL_FULFILLED_TO, customer),
			"",
			CRAFTING_ORDER_COMMISSION_ENCLOSED.." "..Money.ToStringExact(commission)
		)
	elseif mailType == Inbox.MAIL_TYPE.CANCEL.CRAFTING_ORDER then
		return CRAFTING_ORDER_MAIL_CANCELED_BODY
	elseif mailType == Inbox.MAIL_TYPE.EXPIRE.CRAFTING_ORDER then
		return CRAFTING_ORDER_MAIL_EXPIRED_BODY
	else
		return Inbox.GetText(index) or ""
	end
end

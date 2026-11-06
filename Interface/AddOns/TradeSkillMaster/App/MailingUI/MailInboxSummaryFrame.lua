-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Inbox = App:From("LibTSMWoW"):Include("API.Inbox")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailInboxSummaryFrame = UIElements.Define("MailInboxSummaryFrame", "BaseFrame")
MailInboxSummaryFrame._STATE_SCHEMA = MailInboxSummaryFrame._STATE_SCHEMA:Extend("MailInboxSummaryFrameState")
	:AddBooleanField("filterActive", false)
	:AddNumberField("inboxNumMail", 0)
	:AddNumberField("inboxTotalMail", 0)
	:AddNumberField("queryNumMail", 0)
	:AddNumberField("numVisibleMail", 0)
	:AddNumberField("totalGold", 0)
	:AddNumberField("totalItems", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailInboxSummaryFrame:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self
			:SetLayout("HORIZONTAL")
			:SetHeight(30)
			:SetRoundedBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:AddChild(UIElements.New("Spacer", "leftSpacer"))
			:AddChild(UIElements.New("Text", "mail")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(self._state:PublisherForFunctionWithKeys(private.StateToMailText, "numVisibleMail", "inboxTotalMail"))
			)
			:AddChild(UIElements.New("Text", "items")
				:SetWidth("AUTO")
				:SetMargin(24, 0, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(self._state:PublisherForFunctionWithKeys(private.StateToItemsText, "totalItems"))
			)
			:AddChild(UIElements.New("Text", "goldLabel")
				:SetWidth("AUTO")
				:SetMargin(24, 4, 0, 0)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Gold"]..":")
			)
			:AddChild(UIElements.New("Text", "goldValue")
				:SetWidth("AUTO")
				:SetFont("BODY_SMALL")
				:SetText(self._state:PublisherForFunctionWithKeys(Money.ToStringForUI, "totalGold"))
			)
			:AddChild(UIElements.New("Spacer", "rightSpacer"))
	end

	-- Set up some computed state properties
	self._state:Publisher([[filterActive and queryNumMail or inboxNumMail]])
		:AssignToTableKey(self._state, "numVisibleMail")
end

---Sets the query which is being used to populate the list of visible mail.
---@param query DatabaseQuery
---@return self
function MailInboxSummaryFrame:SetQuery(query)
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets whether or not there's an active filter.
---@param value boolean|ReactivePublisherSchemaBase The value or a publisher
---@return self
function MailInboxSummaryFrame:SetFilterActive(value)
	if type(value) == "boolean" then
		self._state.filterActive = value
	else
		self:_MethodPublisher(value, "SetFilterActive")
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MailInboxSummaryFrame.__private:_HandleQueryUpdate(query)
	self._state.inboxNumMail, self._state.inboxTotalMail = Inbox.GetNumItems()
	self._state.queryNumMail = query:Count()
	self._state.totalItems = query:Sum("itemCount")
	self._state.totalGold = query:Sum("money")
	-- Need to explicitly draw since the text widths may change
	self:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToMailText(numVisibleMail, inboxTotalMail)
	return format(L["%s Mail"], Theme.GetColor("accent/main"):ColorText(FormatLargeNumber(numVisibleMail).."/"..FormatLargeNumber(inboxTotalMail)))
end

function private.StateToItemsText(totalItems)
	return format(L["%s Items"], Theme.GetColor("accent/main"):ColorText(FormatLargeNumber(totalItems)))
end

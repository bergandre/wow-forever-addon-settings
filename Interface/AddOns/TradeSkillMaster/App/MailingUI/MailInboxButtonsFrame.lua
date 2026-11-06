-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local Inbox = App:From("LibTSMWoW"):Include("API.Inbox")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailInboxButtonsFrame = UIElements.Define("MailInboxButtonsFrame", "BaseFrame")
MailInboxButtonsFrame._STATE_SCHEMA = MailInboxButtonsFrame._STATE_SCHEMA:Extend("MailInboxButtonsFrameState")
	:AddOptionalEnumField("opening", EnumTypes.MAILING_OPEN_TYPE)
	:AddNumberField("numSales", 0)
	:AddNumberField("numBuys", 0)
	:AddNumberField("numCancels", 0)
	:AddNumberField("numExpires", 0)
	:AddNumberField("numOther", 0)
	:Commit()
MailInboxButtonsFrame:_AddActionScripts("OnStartOpening")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailInboxButtonsFrame:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_UPDATE_DATA")
	self._query = nil ---@type DatabaseQuery!
end

function MailInboxButtonsFrame:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		local openingPublisher = self._state:Publisher("opening")
			:Share()
		self:AddChild(UIElements.New("OpenAllMailActionButton", "openAllMail")
			:SetManager(self._childManager)
			:SetDisabled(self._state:Publisher([[opening and true or (numSales + numBuys + numCancels + numExpires + numOther) == 0]]))
			:SetPressed(openingPublisher:ToBooleanEquals(EnumTypes.MAILING_OPEN_TYPE.ALL))
			:SetAction("OnClick", "ACTION_START_OPENING")
		)
		self:AddChild(UIElements.New("BaseFrame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("OpenMailActionButton", "openAllSales")
				:SetMargin(0, 10, 0, 0)
				:SetOpenType(EnumTypes.MAILING_OPEN_TYPE.SALE)
				:SetDisabled(self._state:Publisher([[opening and true or numSales == 0]]))
				:SetPressed(openingPublisher:ToBooleanEquals(EnumTypes.MAILING_OPEN_TYPE.SALE))
				:SetAction("OnClick", "ACTION_START_OPENING")
			)
			:AddChild(UIElements.New("OpenMailActionButton", "openAllBuys")
				:SetMargin(0, 10, 0, 0)
				:SetOpenType(EnumTypes.MAILING_OPEN_TYPE.BUY)
				:SetDisabled(self._state:Publisher([[opening and true or numBuys == 0]]))
				:SetPressed(openingPublisher:ToBooleanEquals(EnumTypes.MAILING_OPEN_TYPE.BUY))
				:SetAction("OnClick", "ACTION_START_OPENING")
			)
			:AddChild(UIElements.New("OpenMailActionButton", "openAllCancels")
				:SetMargin(0, 10, 0, 0)
				:SetOpenType(EnumTypes.MAILING_OPEN_TYPE.CANCEL)
				:SetDisabled(self._state:Publisher([[opening and true or numCancels == 0]]))
				:SetPressed(openingPublisher:ToBooleanEquals(EnumTypes.MAILING_OPEN_TYPE.CANCEL))
				:SetAction("OnClick", "ACTION_START_OPENING")
			)
			:AddChild(UIElements.New("OpenMailActionButton", "openAllExpires")
				:SetMargin(0, 10, 0, 0)
				:SetOpenType(EnumTypes.MAILING_OPEN_TYPE.EXPIRE)
				:SetDisabled(self._state:Publisher([[opening and true or numExpires == 0]]))
				:SetPressed(openingPublisher:ToBooleanEquals(EnumTypes.MAILING_OPEN_TYPE.EXPIRE))
				:SetAction("OnClick", "ACTION_START_OPENING")
			)
			:AddChild(UIElements.New("OpenMailActionButton", "openAllOthers")
				:SetOpenType(EnumTypes.MAILING_OPEN_TYPE.OTHER)
				:SetDisabled(self._state:Publisher([[opening and true or numOther == 0]]))
				:SetPressed(openingPublisher:ToBooleanEquals(EnumTypes.MAILING_OPEN_TYPE.OTHER))
				:SetAction("OnClick", "ACTION_START_OPENING")
			)
		)
		self:AddCancellable(openingPublisher:EndShare())
	end
end

function MailInboxButtonsFrame:Release()
	self._query = nil
	self.__super:Release()
end

---Sets the query which is being used to populate the list of visible mail.
---@param query DatabaseQuery
---@return self
function MailInboxButtonsFrame:SetQuery(query)
	assert(not self._query)
	self._query = query
	self:_AddQueryUpdatePublisher(query, self._childManager:CallbackToProcessAction("ACTION_UPDATE_DATA"))
	return self
end

---Sets a publisher for when the filter value changes.
---@param publisher ReactivePublisherSchemaBase
---@return self
function MailInboxButtonsFrame:SetFilterChangedPublisher(publisher)
	return self:_FunctionPublisher(publisher, self._childManager:CallbackToProcessAction("ACTION_UPDATE_DATA"))
end

---Notifies the buttons frame that opening mail is done.
---@return self
function MailInboxButtonsFrame:OpeningDone()
	self._state.opening = nil
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state MailInboxButtonsFrameState
function MailInboxButtonsFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_DATA" then
		local sales, buys, cancels, expires, other = 0, 0, 0, 0, 0
		for _, mailType in self._query:Iterator("type") do
			if mailType == Inbox.MAIL_TYPE.SALE then
				sales = sales + 1
			elseif mailType == Inbox.MAIL_TYPE.BUY then
				buys = buys + 1
			elseif mailType == Inbox.MAIL_TYPE.CANCEL then
				cancels = cancels + 1
			elseif mailType == Inbox.MAIL_TYPE.EXPIRE then
				expires = expires + 1
			elseif mailType == Inbox.MAIL_TYPE.OTHER then
				other = other + 1
			else
				assert(mailType == Inbox.MAIL_TYPE.LETTER)
			end
		end
		state.numSales = sales
		state.numBuys = buys
		state.numCancels = cancels
		state.numExpires = expires
		state.numOther = other
	elseif action == "ACTION_START_OPENING" then
		local openType, autoRefresh, keepMoney = ...
		state.opening = openType
		self:_SendActionScript("OnStartOpening", private.OpenTypeToFilterType(openType), autoRefresh, keepMoney)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OpenTypeToFilterType(openType)
	if openType == EnumTypes.MAILING_OPEN_TYPE.ALL then
		return nil
	elseif openType == EnumTypes.MAILING_OPEN_TYPE.SALE then
		return Inbox.MAIL_TYPE.SALE
	elseif openType == EnumTypes.MAILING_OPEN_TYPE.BUY then
		return Inbox.MAIL_TYPE.BUY
	elseif openType == EnumTypes.MAILING_OPEN_TYPE.CANCEL then
		return Inbox.MAIL_TYPE.CANCEL
	elseif openType == EnumTypes.MAILING_OPEN_TYPE.EXPIRE then
		return Inbox.MAIL_TYPE.EXPIRE
	elseif openType == EnumTypes.MAILING_OPEN_TYPE.OTHER then
		return Inbox.MAIL_TYPE.OTHER
	else
		error("Invalid open type: "..tostring(openType))
	end
end

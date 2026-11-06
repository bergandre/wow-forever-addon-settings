-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Database = App:From("LibTSMDatabase"):Include("Database")
local Inbox = App:From("LibTSMWoW"):Include("API.Inbox")
local Mail = App:From("LibTSMService"):Include("Mail")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}

---@class MailInboxFrameSettings: SettingsView
---@field mailsScrollingTable table



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailInboxFrame = UIElements.Define("MailInboxFrame", "BaseFrame")
MailInboxFrame._STATE_SCHEMA = MailInboxFrame._STATE_SCHEMA:Extend("MailInboxFrameState")
	:AddDeferredUIElementField("scrollTable", "MailsScrollTable")
	:AddDeferredUIElementField("buttonsFrame", "MailInboxButtonsFrame")
	:AddOptionalStringField("filter")
	:Commit()
MailInboxFrame:_AddActionScripts("OnShowContents", "OnStartOpening")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailInboxFrame:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._itemsQuery = nil
	self._inboxQuery = nil
end

function MailInboxFrame:Acquire()
	self.__super:Acquire()
	self._itemsQuery = Mail.NewItemQuery()
		:Equal("index", Database.BoundQueryParam())
	self._inboxQuery = Mail.NewMailQuery()
		:VirtualField("itemList", "string", self:__closure("_GetItemListVirtualField"), "index")
	local filterPublisher = self._state:Publisher("filter")
		:Share()
	self
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("MailInboxTopFrame", "top")
			:BindFilterValue(self._state, "filter")
		)
		:AddChild(UIElements.New("ListContainer", "content")
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("MailsScrollTable", "mails")
				:BindElement(self._state, "scrollTable")
				:SetManager(self._childManager)
				:SetFilter(filterPublisher)
				:SetAction("OnRowClick", "ACTION_ROW_CLICKED")
			)
		)
		:AddChild(UIElements.New("MailInboxSummaryFrame", "summary")
			:SetMargin(0, 0, 8, 8)
			:SetQuery(self._inboxQuery)
			:SetFilterActive(filterPublisher:ToBooleanNotEquals(nil):IgnoreDuplicates())
		)
		:AddChild(UIElements.New("MailInboxButtonsFrame", "bottom")
			:BindElement(self._state, "buttonsFrame")
			:SetManager(self._childManager)
			:SetQuery(self._inboxQuery)
			:SetFilterChangedPublisher(filterPublisher)
			:SetAction("OnStartOpening", "ACTION_START_OPENING")
		)
	filterPublisher:EndShare()
end

function MailInboxFrame:Release()
	self._itemsQuery:Release()
	self.__super:Release()
	self._inboxQuery:Release()
end

---Configure the mail inbox frame.
---@param settings MailInboxFrameSettings The settings object
---@return self
function MailInboxFrame:Configure(settings)
	self._state.scrollTable
		:SetSettings(settings, "mailsScrollingTable")
		:SetQuery(self._inboxQuery)
	return self
end

---Notifies the buttons frame that opening mail is done.
---@return self
function MailInboxFrame:OpeningDone()
	self._state.buttonsFrame:OpeningDone()
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MailInboxFrame.__private:_GetItemListVirtualField(index)
	self._itemsQuery:BindParams(index)
	return self._itemsQuery:Iterator("itemLink", "quantity")
		:SetMapFunc(private.ItemNameQuantityStr)
		:ToJoinedValueString(", ")
end

---@param manager UIManager<MailInboxFrameState>
---@param state MailInboxFrameState
function MailInboxFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_ROW_CLICKED" then
		local index = ...
		if IsShiftKeyDown() then
			local _, _, cod = Inbox.GetHeaderInfo(index)
			if cod <= 0 then
				-- Marks the mail as read
				Inbox.GetText(index)
				Inbox.AutoOpenMail(index)
			end
		else
			self:_SendActionScript("OnShowContents", index)
		end
	elseif action == "ACTION_START_OPENING" then
		local filterType, autoRefresh, keepMoney = ...
		self:_SendActionScript("OnStartOpening", filterType, autoRefresh, keepMoney, state.filter or "")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemNameQuantityStr(_, itemLink, quantity)
	local itemName = tonumber(itemLink) and "" or UIUtils.GetDisplayItemName(itemLink) or ""
	return quantity > 1 and (itemName.." (x"..quantity..")") or itemName
end

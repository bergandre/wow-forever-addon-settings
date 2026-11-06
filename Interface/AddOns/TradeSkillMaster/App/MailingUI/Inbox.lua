-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Inbox = App:Init("MailingUI.Inbox")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Event = App:From("LibTSMWoW"):Include("Service.Event")
local SoundAlert = App:From("LibTSMWoW"):Include("UI.SoundAlert")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Mailing = App:From("LibTSMApp"):Include("Mailing")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
	replyFunc = nil,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("MailingInboxUIState")
	:AddOptionalNumberField("openMailIndex")
	:AddDeferredUIElementField("viewContainer", "ViewContainer")
	:AddDeferredUIElementField("inboxFrame", "MailInboxFrame")
	:AddStringField("openMailSound", SoundAlert.NO_SOUND_KEY)
	:AddBooleanField("hasOpened", false)
	:Commit()

---@event MailingInboxAction
---| "ACTION_SHOW_MAIL_CONTENTS" -> index: number
---| "ACTION_START_OPENING" -> filterType?: EnumValue, autoRefresh: boolean, keepMoney: boolean, filter: string
---| "ACTION_DONE_OPENING"
---| "ACTION_MAIL_CONTENTS_CLOSED"
---| "ACTION_REPLY" -> sender: string
---| "ACTION_PLAYER_REPORT_SUBMITTED"



-- ============================================================================
-- Module Loading
-- ============================================================================

Inbox:OnModuleLoad(function()
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_INBOX", state, private.ActionHandler)
		:AddFrameBuilder(private.GetInboxFrame)

	-- Stop opening mail when the inbox frame is hidden after being opened
	private.manager:SetStateFromPublisher("hasOpened", state:Publisher("inboxFrame")
		:ToBooleanNotEquals(nil)
		:IgnoreIfNotEquals(true)
		:IgnoreDuplicates()
	)
	private.manager:AddCancellable(state:Publisher([[inboxFrame == nil and hasOpened]])
		:IgnoreIfNotEquals(true)
		:CallFunction(Mailing.StopOpening)
	)

	Event.Register("PLAYER_REPORT_SUBMITTED", private.manager:CallbackToProcessAction("ACTION_PLAYER_REPORT_SUBMITTED"))
end)

AddonSettings.RegisterOnLoad(Inbox, function(db)
	private.settings = db:NewView("InboxSettings")
		:AddKey("global", "mailingUIContext", "mailsScrollingTable")
		:AddKey("global", "mailingOptions", "openMailSound")
		:Commit()
	-- Mirror sound settings value to state
	private.manager:SetStateFromPublisher("openMailSound", private.settings:PublisherForKey("openMailSound"))
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the function to call
---@param func fun(sender: string) The function to call when the reply button is clicked on a mail
function Inbox.SetReplyFunc(func)
	assert(not private.replyFunc)
	private.replyFunc = func
end

---Gets the inbox frame.
---@return BaseFrame
function Inbox.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Inbox UI
-- ============================================================================

---@param state MailingInboxUIState
function private.GetInboxFrame(state)
	UIUtils.AnalyticsRecordPathChange("mailing", "inbox")
	return UIElements.New("BaseFrame", "frame")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("ViewContainer", "view")
			:SetContext(state)
			:SetNavCallback(private.GetViewContentFrame)
			:AddPath("mails", true)
			:AddPath("items")
			:BindElement(state, "viewContainer")
		)
end

function private.GetViewContentFrame(viewContainer, path)
	local state = viewContainer:GetContext() ---@type MailingInboxUIState
	if path == "mails" then
		state.openMailIndex = nil
		return UIElements.New("MailInboxFrame", "inbox")
			:Configure(private.settings --[[@as MailInboxFrameSettings]])
			:BindElement(state, "inboxFrame")
			:SetAction("OnShowContents", "ACTION_SHOW_MAIL_CONTENTS")
			:SetAction("OnStartOpening", "ACTION_START_OPENING")
	elseif path == "items" then
		assert(state.openMailIndex)
		return UIElements.New("MailContentsFrame", "items")
			:SetIndex(state.openMailIndex)
			:SetAction("OnMailClosed", "ACTION_MAIL_CONTENTS_CLOSED")
			:SetAction("OnReply", "ACTION_REPLY")
	else
		error("Unexpected path: "..tostring(path))
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MailingInboxUIState>
---@param state MailingInboxUIState
---@param action MailingInboxAction
---@param ... params<MailingInboxAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_MAIL_CONTENTS" then
		local index = ...
		state.openMailIndex = index
		state.viewContainer:SetPath("items", true)
	elseif action == "ACTION_START_OPENING" then
		local filterType, autoRefresh, keepMoney, filter = ...
		Mailing.StartOpening(manager:CallbackToProcessAction("ACTION_DONE_OPENING"), autoRefresh, keepMoney, filter, filterType)
	elseif action == "ACTION_DONE_OPENING" then
		SoundAlert.Play(state.openMailSound)
		state.inboxFrame:OpeningDone()
	elseif action == "ACTION_MAIL_CONTENTS_CLOSED" then
		state.viewContainer:SetPath("mails", true)
	elseif action == "ACTION_REPLY" then
		local sender = ...
		private.replyFunc(sender)
	elseif action == "ACTION_PLAYER_REPORT_SUBMITTED" then
		if not state.viewContainer then
			return
		end
		state.viewContainer:SetPath("mails", true)
	else
		error("Unknown action: "..tostring(action))
	end
end

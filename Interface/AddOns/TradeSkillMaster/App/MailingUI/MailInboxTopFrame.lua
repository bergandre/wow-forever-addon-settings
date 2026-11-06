-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Mail = App:From("LibTSMService"):Include("Mail")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local MAIL_REFRESH_TIME = (App.IsRetail() or App.IsForever()) and 15 or 60



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailInboxTopFrame = UIElements.Define("MailInboxTopFrame", "BaseFrame")
MailInboxTopFrame._STATE_SCHEMA = MailInboxTopFrame._STATE_SCHEMA:Extend("MailInboxTopFrameState")
	:AddDeferredUIElementField("filterInput", "Input")
	:AddNumberField("nextUpdateSeconds", MAIL_REFRESH_TIME)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailInboxTopFrame:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_UPDATE_COUNTDOWN")
	self._updateCounterTimer = DelayTimer.New("MAIL_INBOX_UPDATE_COUNTER", self._childManager:CallbackToProcessAction("ACTION_UPDATE_COUNTDOWN"))
end

function MailInboxTopFrame:Acquire()
	self.__super:Acquire()
	for _ in self._state:WithAutoStorePaused() do
		self
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:AddChild(UIElements.New("Input", "filterInput")
				:SetMargin(0, 8, 0, 0)
				:AllowItemInsert()
				:SetLeadIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:BindElement(self._state, "filterInput")
				:SetHintText(L["Search items in mailbox"])
				:SetDisabled(false)
			)
			:AddChild(UIElements.New("MailReloadButton", "reload")
				:SetWidth(110)
				:SetText(self._state:Publisher("nextUpdateSeconds"):ToStringFormat(L["Reload UI (%02d)"]))
			)
	end
	self._childManager:ProcessAction("ACTION_UPDATE_COUNTDOWN", true)
	self._updateCounterTimer:RunForTime(0)
	self:SetManager(self._childManager)
end

function MailInboxTopFrame:Release()
	self._updateCounterTimer:Cancel()
	self.__super:Release()
end

---Binds a state property to the filter value.
---@param state ReactiveState The state to store the values in
---@param key string The state key to store the value at
---@return self
function MailInboxTopFrame:BindFilterValue(state, key)
	self._state.filterInput:BindValue(state, key)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<MailInboxTopFrameState>
---@param state MailInboxTopFrameState
function MailInboxTopFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_COUNTDOWN" then
		local force = ...
		if not force then
			self._updateCounterTimer:RunForTime(1)
		end
		local nextUpdate = MAIL_REFRESH_TIME - (App.GetTime() - Mail.GetLastInboxCheckTime())
		if nextUpdate <= 0 then
			nextUpdate = MAIL_REFRESH_TIME
		end
		state.nextUpdateSeconds = Math.Round(nextUpdate)
	else
		error("Unknown action: "..tostring(action))
	end
end

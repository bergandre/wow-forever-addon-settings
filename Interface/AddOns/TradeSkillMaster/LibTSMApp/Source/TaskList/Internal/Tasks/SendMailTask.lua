-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ItemTask = LibTSMApp:IncludeClassType("ItemTask")
local SendMailTask = LibTSMApp:DefineInternalClassType("SendMailTask", ItemTask)
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local Mailing = LibTSMApp:Include("Mailing")
local DefaultUI = LibTSMApp:From("LibTSMWoW"):Include("UI.DefaultUI")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local private = {
	currentlySending = nil,
	activeTasks = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the send mail task code.
function SendMailTask.__static.Configure()
	DefaultUI.RegisterMailVisibleCallback(private.FrameCallback)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SendMailTask:__init()
	self.__super:__init()
	self._target = nil
	self._isSending = false
end

function SendMailTask:Acquire(doneHandler, category)
	self.__super:Acquire(doneHandler, category, "")
	private.activeTasks[self] = true
end

function SendMailTask:Release()
	self.__super:Release()
	self._target = nil
	self._isSending = false
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SendMailTask:SetTarget(target)
	self._target = target
	self._desc = format(L["Mail to %s"], target)
end

function SendMailTask:OnButtonClick()
	private.currentlySending = self
	self._isSending = true
	local items = self:GetItems()
	assert(self._target and next(items))
	Mailing.PrintSendMessage(0, items, self._target)
	Mail.SendItems(items, self._target, nil, self:__closure("_SendCallback"))
	self:_UpdateState()
	UpdateManager.HandleUpdate()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SendMailTask:_UpdateState()
	if not DefaultUI.IsMailVisible() then
		return self:_SetButtonState(false, L["NOT OPEN"])
	elseif self._isSending then
		return self:_SetButtonState(false, L["SENDING"])
	elseif private.currentlySending then
		return self:_SetButtonState(false, L["BUSY"])
	else
		return self:_SetButtonState(true, strupper(L["Send"]))
	end
end

function SendMailTask.__private:_SendCallback()
	if not self then
		return
	end
	assert(self._isSending)
	self._isSending = false
	private.currentlySending = nil
	for itemString, quantity in pairs(self:GetItems()) do
		self:_RemoveItem(itemString, quantity)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameCallback()
	for task in pairs(private.activeTasks) do
		task:Update()
	end
end

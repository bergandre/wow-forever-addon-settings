-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ItemTask = LibTSMApp:IncludeClassType("ItemTask")
local OpenMailTask = LibTSMApp:DefineInternalClassType("OpenMailTask", ItemTask)
local DefaultUI = LibTSMApp:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	activeTasks = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the open mail task code.
function OpenMailTask.__static.Configure()
	DefaultUI.RegisterMailVisibleCallback(private.FrameCallback)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function OpenMailTask:Acquire(doneHandler, category)
	self.__super:Acquire(doneHandler, category, L["Open Mail"])
	private.activeTasks[self] = true
end

function OpenMailTask:Release()
	self.__super:Release()
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OpenMailTask:OnButtonClick()
	-- TODO
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OpenMailTask:_UpdateState()
	if not DefaultUI.IsMailVisible() then
		return self:_SetButtonState(false, L["NOT OPEN"])
	else
		return self:_SetButtonState(false, L["OPEN"])
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

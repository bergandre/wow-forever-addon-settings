-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local ErrorConfig = LibTSMApp:Init("Config.ErrorConfig")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local CombatLockdown = LibTSMApp:From("LibTSMWoW"):Include("Service.CombatLockdown")
local ErrorHandler = LibTSMApp:From("LibTSMService"):Include("Debug.ErrorHandler")
local ErrorFrame = LibTSMApp:From("LibTSMUI"):IncludeClassType("ErrorFrame")
local private = {
	errorFrame = nil,
	pendingError = nil,
	combatLockdownPublisher = nil, ---@diagnostic disable-line: tsm-private
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ErrorConfig:OnModuleLoad(function()
	ErrorHandler.ConfigureUI(private.ShowUI, private.HideUI)
	SlashCommands.RegisterDebug("error", ErrorHandler.ShowManual)
	private.combatLockdownPublisher = CombatLockdown.GetPublisher()
		:CallFunction(private.HandleCombatLockdownChange)
		:Stored()
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ShowUI(errorStr, errorInfo, fullErrorInfo, isManual)
	if CombatLockdown.IsActive() then
		private.pendingError = {
			errorStr = errorStr,
			errorInfo = errorInfo,
			fullErrorInfo = fullErrorInfo,
			isManual = isManual,
		}
		return
	end
	private.errorFrame = private.errorFrame or ErrorFrame.Create()
	private.errorFrame:Show(errorStr, errorInfo, fullErrorInfo, isManual)
end

function private.HideUI()
	private.pendingError = nil
	if not private.errorFrame then
		return
	end
	private.errorFrame:Hide()
end

function private.HandleCombatLockdownChange(inCombat)
	if inCombat or not private.pendingError then
		return
	end
	local pendingError = private.pendingError
	private.pendingError = nil
	private.ShowUI(pendingError.errorStr, pendingError.errorInfo, pendingError.fullErrorInfo, pendingError.isManual)
end

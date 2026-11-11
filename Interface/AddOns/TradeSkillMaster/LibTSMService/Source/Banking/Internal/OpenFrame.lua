-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local OpenFrame = LibTSMService:InitInternal("Banking.OpenFrame")
local Util = LibTSMService:Include("Banking.Util")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	openFrame = nil,
	callbacks = CallbackRegistry.NewList(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

OpenFrame:OnModuleLoad(function()
	if LibTSMService.IsRetail() or LibTSMService.IsForever() then
		Container.RegisterBankFrameCallback(private.HandleBankVisible)
	end
	DefaultUI.RegisterBankVisibleCallback(private.HandleBankVisible)
	DefaultUI.RegisterAccountBankVisibleCallback(private.HandleBankVisible)
	if not LibTSMService.IsVanillaClassic() then
		DefaultUI.RegisterGuildBankVisibleCallback(function(visible)
			private.SetOpenFrame(visible and Util.FRAME.GUILD_BANK or nil)
		end)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for when the open frame changes.
---@param callback fun(frame: EnumValue?) Callback which is passed the open frame
function OpenFrame.RegisterCallback(callback)
	private.callbacks:Add(callback)
end

---Gets the current open banking frame.
---@return EnumValue?
function OpenFrame.Get()
	return private.openFrame
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleBankVisible(visible)
	if visible then
		private.SetOpenFrame(Container.IsWarbankOpen() and Util.FRAME.CONTAINER.WARBANK or Util.FRAME.CONTAINER.BANK)
	else
		private.SetOpenFrame(nil)
	end
end

function private.SetOpenFrame(frame)
	if private.openFrame == frame then
		return
	end
	Log.Info("Open frame changed: %s", frame)
	private.openFrame = frame
	private.callbacks:CallAll(private.openFrame)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Expiring = LibTSMService:InitInternal("Mail.Expiring")
local Scanner = LibTSMService:Include("Mail.Scanner")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	expiringStorage = nil,
	callbacks = CallbackRegistry.NewList(),
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param expiringData table<string,number> Expiring time by character
function Expiring.Load(expiringData)
	private.expiringStorage = expiringData
	Scanner.RegisterMailCallback(private.HandleMailCallback)
end

---Registers a callback for when the expiring time changes.
---@param func fun()
function Expiring.RegisterCallback(func)
	private.callbacks:Add(func)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleMailCallback()
	-- Update the expiration time
	local nextExpiration = Scanner.NewMailQuery()
		:AutoRelease()
		:GreaterThan("itemCount", 0)
		:GreaterThan("money", 0)
		:OrderBy("expires", true)
		:GetFirstResult("expires")
	local playerName = SessionInfo.GetCharacterName()
	private.expiringStorage[playerName] = nextExpiration and floor(LibTSMService.GetTime() + (nextExpiration * 24 * 60 * 60)) or nil
	private.callbacks:CallAll()
end

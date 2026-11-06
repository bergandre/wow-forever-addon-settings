-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ChatEvent = LibTSMWoW:Init("Service.ChatEvent")
local Event = LibTSMWoW:Include("Service.Event")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local String = LibTSMWoW:From("LibTSMUtil"):Include("Lua.String")
local private = {
	patternStrings = {},
	lootHandlers = CallbackRegistry.NewList(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ChatEvent:OnModuleLoad(function()
	tinsert(private.patternStrings, "^"..String.FormatToMatchPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE).."$")
	tinsert(private.patternStrings, "^"..String.FormatToMatchPattern(LOOT_ITEM_PUSHED_SELF).."$")
	tinsert(private.patternStrings, "^"..String.FormatToMatchPattern(LOOT_ITEM_CREATED_SELF_MULTIPLE).."$")
	tinsert(private.patternStrings, "^"..String.FormatToMatchPattern(LOOT_ITEM_CREATED_SELF).."$")
	Event.Register("CHAT_MSG_LOOT", private.HandleChatMessage)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a handler for loot messages.
---@param handler fun(itemLink: string, quantity: number) The handler
function ChatEvent.RegisterLootHandler(handler)
	private.lootHandlers:Add(handler)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleChatMessage(_, msg)
	if (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and issecretvalue(msg) then
		-- The message is a secret, so just ignore it
		return
	end
	if private.lootHandlers:IsEmpty() then
		return
	end
	for _, pattern in ipairs(private.patternStrings) do
		local itemLink, quantity = strmatch(msg, pattern)
		if itemLink then
			quantity = quantity or 1
			private.lootHandlers:CallAll(itemLink, tonumber(quantity))
			return
		end
	end
end

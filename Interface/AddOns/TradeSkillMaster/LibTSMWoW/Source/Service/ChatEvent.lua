-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ChatEvent = LibTSMWoW:Init("Service.ChatEvent")
local Event = LibTSMWoW:Include("Service.Event")
local ChatFrame = LibTSMWoW:Include("API.ChatFrame")
local CallbackRegistry = LibTSMWoW:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local String = LibTSMWoW:From("LibTSMUtil"):Include("Lua.String")
local private = {
	patternStrings = {},
	lootHandlers = CallbackRegistry.NewList(),
	playerNotFoundPattern = nil,
	playerNotFoundHandlers = CallbackRegistry.NewList(),
	playerNotFoundFilter = nil,
	skillHandlers = CallbackRegistry.NewList(),
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
	Event.Register("CHAT_MSG_SKILL", private.HandleSkillMessage)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a handler for loot messages.
---@param handler fun(itemLink: string, quantity: number) The handler
function ChatEvent.RegisterLootHandler(handler)
	private.lootHandlers:Add(handler)
end

---Registers a handler for "player not found" system messages.
---@param handler fun(character: string) The handler
function ChatEvent.RegisterPlayerNotFoundHandler(handler)
	private.InitPlayerNotFound()
	private.playerNotFoundHandlers:Add(handler)
end

---Sets a filter which hides "player not found" system messages from chat when it returns true.
---@param func fun(character: string): boolean The filter function
function ChatEvent.SetPlayerNotFoundFilter(func)
	assert(not private.playerNotFoundFilter)
	private.InitPlayerNotFound()
	private.playerNotFoundFilter = func
	ChatFrame.AddMessageFilter(private.FilterPlayerNotFound)
end

---Registers a handler for skill messages.
---@param handler fun(msg: string) The handler
function ChatEvent.RegisterSkillHandler(handler)
	private.skillHandlers:Add(handler)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.InitPlayerNotFound()
	if private.playerNotFoundPattern then
		return
	end
	private.playerNotFoundPattern = "^"..String.FormatToMatchPattern(ERR_CHAT_PLAYER_NOT_FOUND_S).."$"
	Event.Register("CHAT_MSG_SYSTEM", private.HandleSystemMessage)
end

function private.HandleSystemMessage(_, msg)
	if private.playerNotFoundHandlers:IsEmpty() then
		return
	end
	local character = private.GetPlayerNotFoundCharacter(msg)
	if character then
		private.playerNotFoundHandlers:CallAll(character)
	end
end

function private.FilterPlayerNotFound(_, _, msg)
	local character = private.GetPlayerNotFoundCharacter(msg)
	return character and private.playerNotFoundFilter(character) or false
end

function private.GetPlayerNotFoundCharacter(msg)
	if (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and issecretvalue(msg) then
		return nil
	end
	return strmatch(msg, private.playerNotFoundPattern)
end

function private.HandleSkillMessage(_, msg)
	if private.skillHandlers:IsEmpty() or ((LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and issecretvalue(msg)) then
		return
	end
	private.skillHandlers:CallAll(msg)
end

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

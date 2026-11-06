-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local ChatMessage = LibTSMService:Init("UI.ChatMessage")
local Theme = LibTSMService:Include("UI.Theme")
local ChatFrame = LibTSMService:From("LibTSMWoW"):Include("API.ChatFrame")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Prints a raw user-facing message to chat.
---@param str string The message
function ChatMessage.PrintUserRaw(str)
	ChatFrame.AddMessage(str)
end

---Prints a raw, formatted user-facing message to chat.
---@param message string The message or format string
---@param ... string|number|boolean The format arguments
function ChatMessage.PrintfUserRaw(message, ...)
	ChatMessage.PrintUserRaw(format(message, ...))
end

---Prints a user-facing message to chat.
---@param str string The message
function ChatMessage.PrintUser(str)
	ChatMessage.PrintUserRaw(Theme.GetColor("accent/main"):ColorText("TSM")..": "..str)
end

---Prints a formatted user-facing message to chat.
---@param message string The message or format string
---@param ... string|number|boolean The format arguments
function ChatMessage.PrintfUser(message, ...)
	ChatMessage.PrintUser(format(message, ...))
end

---Colors some accent text for display to the user.
---@param text string The text to color
---@return string
function ChatMessage.ColorUserAccentText(text)
	return Theme.GetColor("accent/main"):ColorText(text)
end

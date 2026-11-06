-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Mailing = LibTSMApp:Init("Mailing")
local Groups = LibTSMApp:Include("Mailing.Groups")
local Open = LibTSMApp:Include("Mailing.Open")
local Util = LibTSMApp:Include("Mailing.Util")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Prints information about money / items being sent to chat.
---@param money number The amount of money being sent (negative for CoD)
---@param items? table<string,number> The items being sent
---@param recipient string The recipient name
function Mailing.PrintSendMessage(money, items, recipient)
	Util.PrintSendMessage(money, items, recipient)
end

---Sends items in the specified groups.
---@param callback fun() A callback function for when sending is complete
---@param groupList GroupPathValue[] The list of groups to send
---@param sendRepeat boolean Automatically repeat the sending
---@param isDryRun boolean Whether or not this is a dry run
function Mailing.SendGroups(callback, groupList, sendRepeat, isDryRun)
	Mailing.StopSending()
	Groups.StartSending(callback, groupList, sendRepeat, isDryRun)
end

---Stops all sending.
function Mailing.StopSending()
	Groups.StopSending()
	Mail.StopSending()
end

---Starts opening mail.
---@param callback fun() The callback for when opening is complete
---@param autoRefresh boolean Automatically refresh the inbox and keep opening
---@param keepMoney boolean Keep mail with money in the inbox
---@param filterText string Only open mail which matches the filter text
---@param filterType? EnumValue Only open mail which matches the filter type
function Mailing.StartOpening(callback, autoRefresh, keepMoney, filterText, filterType)
	Open.Start(callback, autoRefresh, keepMoney, filterText, filterType)
end

---Stops opening mail.
function Mailing.StopOpening()
	Open.Stop()
end

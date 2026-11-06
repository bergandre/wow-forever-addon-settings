-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Guild = LibTSMWoW:Init("API.Guild")
local SlotId = LibTSMWoW:Include("Type.SlotId")
local private = {}
-- Don't use MAX_GUILDBANK_SLOTS_PER_TAB since it isn't available right away
local GUILD_BANK_TAB_SLOTS = 98



-- ============================================================================
-- Module Functions
-- ============================================================================

---Return whether or not the player is in a guild.
---@return boolean
function Guild.IsInGuild()
	return IsInGuild() and true or false
end

---Gets the name of the current guild if any.
---@return string?
function Guild.GetName()
	local name = GetGuildInfo("player")
	return name
end

---Returns whether or not the player is the guild leader.
---@return boolean
function Guild.IsLeader()
	return IsGuildLeader()
end

---Iterates over the members in the guild.
---@return fun(): number, string, boolean @Iterator with fields: `index`, `name`, `isLeader`
---@return nil
---@return number
function Guild.MemberIterator()
	return private.MemberIterator, nil, 0
end

---Gets the amount of gold in the guild bank.
---@return number
function Guild.GetMoney()
	return GetGuildBankMoney()
end

---Gets the amount of money that can be withdrawn from the guild bank.
---@return number
function Guild.GetWithdrawMoney()
	return GetGuildBankWithdrawMoney()
end

---Iterate over all the slot IDs within a guild bank tab.
---@param tab number The tab index
---@return fun(): number @Iterator with fields: `slotId`
---@return number
---@return number
function Guild.SlotIdIterator(tab)
	return private.SlotIdIterator, SlotId.Join(tab, GUILD_BANK_TAB_SLOTS), SlotId.Join(tab, 0)
end

---Gets the currently-loaded guild bank tab.
---@return number
function Guild.GetCurrentTab()
	return GetCurrentGuildBankTab() --[[@as number]]
end

---Queries a guild bank tab to load its data.
---@param tab number The tab index
function Guild.QueryTab(tab)
	QueryGuildBankTab(tab)
end

---Queries all the guild bank tabs to load their data.
function Guild.QueryAllTabs()
	local initialTab = Guild.GetCurrentTab()
	for i = 1, Guild.GetNumTabs() do
		Guild.QueryTab(i)
	end
	Guild.QueryTab(initialTab)
end

---Gets the number of guild bank tabs.
---@return number
function Guild.GetNumTabs()
	return GetNumGuildBankTabs() --[[@as number]]
end

---Gets the number of daily withdrawals for a guild bank tab.
---@param tab number The tab index
---@return number
function Guild.GetNumDailyWithdrawals(tab)
	local _, _, _, _, numWithdrawals = GetGuildBankTabInfo(tab)
	return numWithdrawals
end

---Checks whether or not the player has permissions to withdraw at least the entire tab.
---@param tab number The tab index
---@return boolean
function Guild.CanWithdrawEntireTab(tab)
	local numWithdrawals = Guild.GetNumDailyWithdrawals(tab)
	return numWithdrawals == -1 or numWithdrawals >= GUILD_BANK_TAB_SLOTS
end

---Gets the item link for a given guild bank slot.
---@param slotId number The slot ID
---@return string
function Guild.GetItemLink(slotId)
	return GetGuildBankItemLink(SlotId.Split(slotId))
end

---Gets the number of items in a guild bank slot.
---@param slotId number The slot ID
---@return number
function Guild.GetItemCount(slotId)
	local _, itemCount = GetGuildBankItemInfo(SlotId.Split(slotId))
	return itemCount
end

---Places part of a stack of items from a guild bank slot onto the cursor.
---@param slotId number The slot ID
---@param quantity number The quantity to split
function Guild.SplitItem(slotId, quantity)
	local tab, slot = SlotId.Split(slotId)
	SplitGuildBankItem(tab, slot, quantity)
end

---Places the item from the cursor into a guild bank slot.
---@param slotId number The slot ID
function Guild.PlaceItemFromCursor(slotId)
	if GetCursorInfo() == "item" then
		PickupGuildBankItem(SlotId.Split(slotId))
	end
	ClearCursor()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MemberIterator(_, index)
	index = index + 1
	if index > GetNumGuildMembers() then
		return
	end
	local name, _, rankIndex = GetGuildRosterInfo(index)
	return index, name, rankIndex == 0
end

function private.SlotIdIterator(maxSlotId, slotId)
	slotId = slotId + 1
	if slotId > maxSlotId then
		return
	end
	return slotId
end

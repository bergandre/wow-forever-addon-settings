-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:InitInternal("Guild.Scanner")
local CallbackRegistry = LibTSMService:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Guild = LibTSMService:From("LibTSMWoW"):Include("API.Guild")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	indexDB = nil,
	quantityDB = nil,
	baseItemQuantityQuery = nil,
	scanTimer = nil,
	nameTimer = nil,
	quantityStorage = nil,
	currentQuantityStorage = nil,
	playerGuild = nil,
	nameCallbacks = CallbackRegistry.NewList(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	private.indexDB = Database.NewSchema("GUILD_BANK_INDEX")
		:AddUniqueNumberField("slotId")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("quantity")
		:AddIndex("slotId")
		:AddIndex("itemString")
		:Commit()
	private.quantityDB = Database.NewSchema("GUILD_BANK_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("guildQuantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewOwnedQuery()
		:Equal("baseItemString", Database.BoundQueryParam())
	if not LibTSMService.IsVanillaClassic() then
		private.scanTimer = DelayTimer.New("GUILD_BANK_SCAN", private.GuildBankChangedDelayed)
	end
	private.nameTimer = DelayTimer.New("GUILD_BANK_GUILD_NAME", private.GetGuildName)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param quantityData table<string,number> Guild bank item quantities
function Scanner.Load(quantityData)
	if LibTSMService.IsVanillaClassic() then
		wipe(quantityData)
		return
	end
	private.quantityStorage = quantityData
end

---Starts running the scanning code.
function Scanner.Start()
	if not LibTSMService.IsVanillaClassic() then
		DefaultUI.RegisterGuildBankVisibleCallback(Guild.QueryAllTabs, true)
		Event.Register("GUILDBANKBAGSLOTS_CHANGED", function() private.scanTimer:RunForFrames(2) end)
	end
	Event.Register("PLAYER_GUILD_UPDATE", private.GetGuildName)
	private.nameTimer:RunForFrames(1)
end

---Registers a function to call when the player's guild name is loaded or changes.
---@param func fun(name?: string)
function Scanner.RegisterNameCallback(func)
	private.nameCallbacks:Add(func)
end

---Creates a query against the index DB.
---@return DatabaseQuery
function Scanner.NewIndexQuery()
	return private.indexDB:NewOwnedQuery()
end

---Creates a query against the index DB for a specific item.
---@param itemString string The item string
---@return DatabaseQuery
function Scanner.NewIndexQueryItem(itemString)
	local itemStringField = nil
	if itemString == ItemString.GetBaseFast(itemString) then
		itemStringField = "baseItemString"
	elseif ItemString.IsLevel(itemString) then
		itemStringField = "levelItemString"
	else
		itemStringField = "itemString"
	end
	return Scanner.NewIndexQuery()
		:Equal(itemStringField, itemString)
end

---Gets the quantity of a given item.
---@param itemString string The item string
---@return number
function Scanner.GetQuantity(itemString)
	if itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("guildQuantity")
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if not private.quantityDB:HasUniqueRow("levelItemString", levelItemString) then
		return 0
	end
	return private.quantityDB:GetRowFields(private.quantityDB:GetUniqueRow("levelItemString", levelItemString), "guildQuantity")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetGuildName()
	if not Guild.IsInGuild() then
		private.SetPlayerGuild(nil)
		return
	end
	if not private.SetPlayerGuild(Guild.GetName()) then
		-- Try again next frame
		private.nameTimer:RunForFrames(1)
		return
	end
	if not LibTSMService.IsVanillaClassic() then
		assert(private.currentQuantityStorage)
		for levelItemString, quantity in pairs(private.currentQuantityStorage) do
			if quantity <= 0 or levelItemString ~= ItemString.ToLevel(levelItemString) then
				private.currentQuantityStorage[levelItemString] = nil
			end
		end
		private.RebuildQuantityDB()
	end
end

function private.SetPlayerGuild(name)
	if private.playerGuild == name then
		return
	end
	private.playerGuild = name
	private.nameCallbacks:CallAll(name)
	if not LibTSMService.IsVanillaClassic() and name then
		private.quantityStorage[name] = private.quantityStorage[name] or {}
		private.currentQuantityStorage = private.quantityStorage[name] --[[@as table<string,number>]]
	else
		private.currentQuantityStorage = nil
	end
	return name and true or false
end

function private.RebuildQuantityDB()
	private.quantityDB:TruncateAndBulkInsertStart()
	assert(private.currentQuantityStorage)
	for levelItemString, quantity in pairs(private.currentQuantityStorage) do
		if quantity > 0 then
			private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
		else
			private.currentQuantityStorage[levelItemString] = nil
		end
	end
	private.quantityDB:BulkInsertEnd()
end

function private.GuildBankChangedDelayed()
	if not DefaultUI.IsGuildBankVisible() then
		return
	end
	if not private.currentQuantityStorage then
		-- We don't have the guild name yet, so try again after a short delay
		private.scanTimer:RunForFrames(2)
		return
	end

	wipe(private.currentQuantityStorage)
	private.indexDB:TruncateAndBulkInsertStart()
	local didFail = false
	for tab = 1, Guild.GetNumTabs() do
		-- Only scan tabs which we have at least enough withdrawals to withdraw every slot
		if Guild.CanWithdrawEntireTab(tab) then
			for slotId in Guild.SlotIdIterator(tab) do
				local itemLink = Guild.GetItemLink(slotId)
				if itemLink then
					local itemString = ItemString.Get(itemLink)
					local levelItemString = itemString and ItemString.ToLevel(itemString)
					if levelItemString == ItemString.GetPetCage() then
						levelItemString = nil
					end
					if levelItemString then
						local quantity = Guild.GetItemCount(slotId)
						if quantity == 0 then
							-- The info for this slot isn't fully loaded yet
							Log.Err("Failed to scan guild bank slot (%d)", slotId)
							didFail = true
							break
						end
						private.currentQuantityStorage[levelItemString] = (private.currentQuantityStorage[levelItemString] or 0) + quantity
						private.indexDB:BulkInsertNewRow(slotId, itemString, quantity)
					end
				end
			end
		end
		if didFail then
			break
		end
	end
	private.RebuildQuantityDB()
	private.indexDB:BulkInsertEnd()

	if didFail then
		private.scanTimer:RunForFrames(2)
	end
end

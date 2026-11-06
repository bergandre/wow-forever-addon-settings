-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Accounting = LibTSMApp:Init("Accounting")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Inventory = LibTSMApp:Include("Service.Inventory")
local PlayerInfo = LibTSMApp:Include("Service.PlayerInfo")
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local TimeFormat = LibTSMApp:From("LibTSMWoW"):Include("UI.TimeFormat")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auctions = LibTSMApp:From("LibTSMService"):Include("Ledger.Auctions")
local GoldTracker = LibTSMApp:From("LibTSMService"):Include("Ledger.GoldTracker")
local Money = LibTSMApp:From("LibTSMService"):Include("Ledger.Money")
local Trade = LibTSMApp:From("LibTSMService"):Include("Ledger.Trade")
local Transactions = LibTSMApp:From("LibTSMService"):Include("Ledger.Transactions")
local TransactionSync = LibTSMApp:From("LibTSMService"):Include("Ledger.TransactionSync")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local Lifecycle = LibTSMApp:From("LibTSMService"):Include("Util.Lifecycle")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local UIElements = LibTSMApp:From("LibTSMUI"):Include("UIElements")
local private = {
	settingsDB = nil,
	settings = nil,
	cancellables = {},
	characterGuildTemp = {},
	tradeDialogShown = false,
}
local SECONDS_PER_DAY = 24 * 60 * 60



-- ============================================================================
-- Module Loading
-- ============================================================================

Accounting:OnModuleLoad(function()
	-- Configure the gold tracker code
	GoldTracker.Configure(L["Warbank"], function(character)
		return PlayerInfo.IsPlayer(gsub(character, "%-", " - "), true)
	end)

	-- Configure the trade code
	Trade.Configure(private.HandleTrade)

	-- Configure the transactions code
	Transactions.RegisterCallback(private.OnItemRecordsChanged)
	Transactions.RegisterSyncCallback(TransactionSync.OnTransactionsChanged)

	-- Register custom string sources
	CustomString.RegisterSource("Accounting", "AvgSell", L["Avg Sell Price"], Transactions.GetAverageSalePrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MaxSell", L["Max Sell Price"], Transactions.GetMaxSalePrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MinSell", L["Min Sell Price"], Transactions.GetMinSalePrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "AvgBuy", L["Avg Buy Price"], Transactions.GetAverageBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "SmartAvgBuy", L["Smart Avg Buy Price"], private.GetSmartAverageBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MaxBuy", L["Max Buy Price"], Transactions.GetMaxBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MinBuy", L["Min Buy Price"], Transactions.GetMinBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "NumExpires", L["Expires Since Last Sale"], private.GetNumExpiresSinceSale, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "SaleRate", L["Sale Rate"], private.GetSaleRate, CustomString.SOURCE_TYPE.NORMAL)
	CustomStringFormat.SetFormat("NumExpires", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("SaleRate", CustomStringFormat.FORMAT.NUMBER)
	Inventory.RegisterDependentCustomSource("SmartAvgBuy")

	-- Register lifecycle handlers
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
	Lifecycle.RegisterCallback(private.HandleLogout, Lifecycle.EVENT.LOGOUT)
end)

AddonSettings.RegisterOnLoad(Accounting, function(db)
	private.settingsDB = db
	private.settings = db:NewView("AccountingSettings")
		:AddKey("sync", "internalData", "goldLog")
		:AddKey("sync", "internalData", "goldLogLastUpdate")
		:AddKey("sync", "internalData", "money")
		:AddKey("realm", "internalData", "csvCancelled")
		:AddKey("realm", "internalData", "saveTimeCancels")
		:AddKey("realm", "internalData", "csvExpired")
		:AddKey("realm", "internalData", "saveTimeExpires")
		:AddKey("realm", "internalData", "csvExpense")
		:AddKey("realm", "internalData", "csvIncome")
		:AddKey("realm", "internalData", "accountingTrimmed")
		:AddKey("realm", "internalData", "csvSales")
		:AddKey("realm", "internalData", "saveTimeSales")
		:AddKey("realm", "internalData", "csvBuys")
		:AddKey("realm", "internalData", "saveTimeBuys")
		:AddKey("factionrealm", "internalData", "guildGoldLog")
		:AddKey("factionrealm", "internalData", "guildGoldLogLastUpdate")
		:AddKey("factionrealm", "internalData", "characterGuilds")
		:AddKey("global", "accountingOptions", "trackTrades")
		:AddKey("global", "accountingOptions", "autoTrackTrades")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "internalData", "warbankGoldLog")
		:AddKey("global", "internalData", "warbankGoldLogLastUpdate")
		:AddKey("global", "internalData", "warbankMoney")
		:Commit()

	-- Load gold log data
	local validGuilds = {}
	for _, data, character, factionrealm in private.settings:AccessibleValueIterator("goldLog") do
		local guild = private.settings:GetForScopeKey("characterGuilds", factionrealm)[character]
		if guild then
			validGuilds[guild] = true
		end
		local lastUpdate = private.settings:GetForScopeKey("goldLogLastUpdate", character, factionrealm) or 0
		local characterKey = SessionInfo.FormatCharacterName(character, factionrealm, true)
		GoldTracker.LoadCharacter(characterKey, data, lastUpdate)
	end
	for _, guildData, factionrealm in private.settings:AccessibleValueIterator("guildGoldLog") do
		for guild, data in pairs(guildData) do
			local lastUpdate = private.settings:GetForScopeKey("guildGoldLogLastUpdate", factionrealm)
			GoldTracker.LoadGuild(guild, data, lastUpdate, validGuilds[guild])
		end
	end

	-- Load warbank gold log data
	if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
		GoldTracker.LoadWarbank(private.settings.warbankGoldLog, private.settings.warbankGoldLogLastUpdate)
	end

	-- Track the money of the current character
	GoldTracker.MoneyPublisher()
		:AssignToTableKey(private.settings, "money")
		:StoreIn(private.cancellables)
	GoldTracker.WarbankMoneyPublisher()
		:AssignToTableKey(private.settings, "warbankMoney")
		:StoreIn(private.cancellables)

	-- Load auctions data
	local auctionsData = {}
	for _, csvCancelled, realm in private.settings:AccessibleValueIterator("csvCancelled") do
		local saveTimeCancels = private.settings:GetForScopeKey("saveTimeCancels", realm)
		Table.InsertMultiple(auctionsData, "cancel", csvCancelled, saveTimeCancels, realm == SessionInfo.GetRealmName())
	end
	for _, csvExpired, realm in private.settings:AccessibleValueIterator("csvExpired") do
		local saveTimeExpires = private.settings:GetForScopeKey("saveTimeExpires", realm)
		Table.InsertMultiple(auctionsData, "expire", csvExpired, saveTimeExpires, realm == SessionInfo.GetRealmName())
	end
	Auctions.LoadData(auctionsData)

	-- Load money data
	local moneyData = {}
	for _, csvExpense, realm in private.settings:AccessibleValueIterator("csvExpense") do
		Table.InsertMultiple(moneyData, "expense", csvExpense, realm == SessionInfo.GetRealmName())
	end
	for _, csvIncome, realm in private.settings:AccessibleValueIterator("csvIncome") do
		Table.InsertMultiple(moneyData, "income", csvIncome, realm == SessionInfo.GetRealmName())
	end
	Money.LoadData(moneyData)


	-- Handle trimmed data
	if private.settings.accountingTrimmed.sales then
		ChatMessage.PrintfUser(L["%sIMPORTANT:|r When Accounting data was last saved for this realm, it was too big for WoW to handle, so old data was automatically trimmed in order to avoid corruption of the saved variables. The last %s of sale data has been preserved."], Theme.GetColor("error/main"):GetTextColorPrefix(), TimeFormat.Duration(LibTSMApp.GetTime() - private.settings.accountingTrimmed.sales))
		private.settings.accountingTrimmed.sales = nil
	end
	if private.settings.accountingTrimmed.buys then
		ChatMessage.PrintfUser(L["%sIMPORTANT:|r When Accounting data was last saved for this realm, it was too big for WoW to handle, so old data was automatically trimmed in order to avoid corruption of the saved variables. The last %s of purchase data has been preserved."], Theme.GetColor("error/main"):GetTextColorPrefix(), TimeFormat.Duration(LibTSMApp.GetTime() - private.settings.accountingTrimmed.buys))
		private.settings.accountingTrimmed.buys = nil
	end

	-- Load transactions data
	local currentRealm = SessionInfo.GetRealmName()
	local transactionsData = {}
	Table.InsertMultiple(transactionsData, "sale", private.settings.csvSales, private.settings.saveTimeSales, currentRealm)
	Table.InsertMultiple(transactionsData, "buy", private.settings.csvBuys, private.settings.saveTimeBuys, currentRealm)
	for _, csvSales, realm in private.settings:AccessibleValueIterator("csvSales") do
		if realm ~= currentRealm then
			local saveTimes = private.settings:GetForScopeKey("saveTimeSales", realm)
			assert(saveTimes)
			Table.InsertMultiple(transactionsData, "sale", csvSales, saveTimes, realm)
		end
	end
	for _, csvBuys, realm in private.settings:AccessibleValueIterator("csvBuys") do
		if realm ~= currentRealm then
			local saveTimes = private.settings:GetForScopeKey("saveTimeBuys", realm)
			assert(saveTimes)
			Table.InsertMultiple(transactionsData, "buy", csvBuys, saveTimes, realm)
		end
	end
	local truncatedRealms = {}
	Transactions.LoadData(transactionsData, truncatedRealms)
	for _, realm in ipairs(truncatedRealms) do
		ChatMessage.PrintfUser(L["Only the last 6 months of Accounting purchases and sales data for %s was loaded. Consider clearing old Accounting data from the TSM settings on that realm."], realm)
	end
	private.OnItemRecordsChanged("sale")
	private.OnItemRecordsChanged("buy")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over summary data.
---@param timeFilterStart? number The start time of the time filter
---@param timeFilterEnd? number The end time of the time filter
---@param ignoredCharacters? table<string,boolean> Ignored characters
---@return IteratorObject<fun(): number, string, string, number, number> @Iterator with fields: `index`, `type`, `itemString`, `price`, `quantity`
function Accounting.SummaryDataIterator(timeFilterStart, timeFilterEnd, ignoredCharacters)
	if ignoredCharacters then
		wipe(private.characterGuildTemp)
		for characterGuild in pairs(ignoredCharacters) do
			local character, realm = strmatch(characterGuild, "^(.+) %- .+ %- (.+)$")
			if character and realm == SessionInfo.GetRealmName() then
				private.characterGuildTemp[character] = true
			end
		end
	end
	return Transactions.CreateQuery()
		:AutoRelease()
		:If(timeFilterStart ~= nil)
			:GreaterThan("time", timeFilterStart)
		:End()
		:If(timeFilterEnd ~= nil)
			:LessThan("time", timeFilterEnd)
		:End()
		:If(ignoredCharacters ~= nil)
			:NotInTable("player", private.characterGuildTemp)
		:End()
		:Iterator("type", "itemString", "price", "quantity")
end

---Returns whether or not a transaction can be deleted based on its UUID.
---@param uuid number The UUID of the transaction
---@return boolean
function Accounting.CanDeleteTransactionByUUID(uuid)
	return private.settingsDB:GetOwnerSyncAccountKey(Transactions.GetPlayerByUUID(uuid)) == private.settingsDB:GetLocalSyncAccountKey()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	GoldTracker.Start()
	return true
end

function private.HandleLogout()
	-- Save the gold log data
	private.settings.goldLog, private.settings.goldLogLastUpdate = GoldTracker.SaveCharacter()
	local guild = PlayerInfo.GetPlayerGuild(SessionInfo.GetCharacterName(), SessionInfo.GetFactionrealmName())
	if guild then
		local guildLog, guildLastUpdate = GoldTracker.SaveGuild(guild)
		if guildLog then
			private.settings.guildGoldLog[guild] = guildLog
			private.settings.guildGoldLogLastUpdate[guild] = guildLastUpdate
		end
	end
	if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
		private.settings.warbankGoldLog, private.settings.warbankGoldLogLastUpdate = GoldTracker.SaveWarbank()
	end

	-- Save the auctions data
	if Auctions.DataDidChange() then
		local csvCancelled, saveTimeCancels, csvExpired, saveTimeExpires = Auctions.SaveData()
		private.settings.csvCancelled = csvCancelled
		private.settings.saveTimeCancels = saveTimeCancels
		private.settings.csvExpired = csvExpired
		private.settings.saveTimeExpires = saveTimeExpires
	end

	-- Save the money data
	if Money.DataDidChange() then
		local csvExpense, csvIncome = Money.SaveData()
		private.settings.csvExpense = csvExpense
		private.settings.csvIncome = csvIncome
	end

	-- Save the transactions data
	if Transactions.DataDidChange() then
		local csvSales, saveTimeSales, trimmedSales, csvBuys, saveTimeBuys, trimmedBuys = Transactions.SaveData()
		private.settings.csvSales, private.settings.saveTimeSales, private.settings.accountingTrimmed.sales = csvSales, saveTimeSales, trimmedSales
		private.settings.csvBuys, private.settings.saveTimeBuys, private.settings.accountingTrimmed.buys = csvBuys, saveTimeBuys, trimmedBuys
	end
	return true
end

function private.OnItemRecordsChanged(recordType, itemString)
	if recordType == "sale" then
		CustomString.InvalidateCache("AvgSell", itemString)
		CustomString.InvalidateCache("MaxSell", itemString)
		CustomString.InvalidateCache("MinSell", itemString)
		CustomString.InvalidateCache("NumExpires", itemString)
	elseif recordType == "buy" then
		CustomString.InvalidateCache("AvgBuy", itemString)
		CustomString.InvalidateCache("MaxBuy", itemString)
		CustomString.InvalidateCache("MinBuy", itemString)
	else
		error("Invalid recordType: "..tostring(recordType))
	end
end

function private.GetSmartAverageBuyPrice(itemString)
	local totalQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
	if totalQuantity == 0 then
		return nil
	end
	local totalPrice, totalNum = Transactions.GetBuyStats(itemString, totalQuantity)
	return totalPrice and Math.Round(totalPrice / totalNum) or nil
end

function private.GetNumExpiresSinceSale(itemString)
	return Auctions.GetNumExpires(itemString, Transactions.GetLastSaleTime(itemString))
end

function private.GetSaleRate(itemString)
	-- Since auction data only goes back 180 days, limit the sales to that same time range
	local _, totalSaleNum = Transactions.GetSaleStats(itemString, LibTSMApp.GetTime() - 180 * SECONDS_PER_DAY)
	if not totalSaleNum then
		return nil
	end
	local _, _, totalFailed = Auctions.GetStats(itemString)
	return Math.Round(totalSaleNum / (totalSaleNum + totalFailed), 0.01)
end

function private.HandleTrade(tradeType, itemString, money, count, name)
	if not private.settings.trackTrades then
		return
	end
	if private.settings.autoTrackTrades then
		if tradeType == "sale" then
			Transactions.InsertTradeSale(itemString, count, money / count, name)
		elseif tradeType == "buy" then
			Transactions.InsertTradeBuy(itemString, count, money / count, name)
		else
			error("Unknown type: "..tostring(tradeType))
		end
	else
		if private.tradeDialogShown then
			-- Popup already visible so ignore this
			return
		end
		private.tradeDialogShown = true
		UIElements.New("RecordTradeDialog", "dialog")
			:Configure(tradeType, itemString, money, count, name)
			:SetScript("OnHide", private.TradeDialogOnHide)
			:Show()
			:Draw()
	end
end

function private.TradeDialogOnHide()
	private.tradeDialogShown = false
end

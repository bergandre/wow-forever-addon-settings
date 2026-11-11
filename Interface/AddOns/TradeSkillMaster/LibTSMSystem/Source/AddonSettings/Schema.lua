-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local Schema = LibTSMSystem:Init("AddonSettings.Schema")
local Settings = LibTSMSystem:From("LibTSMTypes"):Include("Settings")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the settings schema.
---@return SettingsSchema
function Schema.Get()
	-- Changelog:
	-- [102] Initial 4.11 version (current min supported version)
	-- [103] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable},global.craftingUIContext.professionScrollingTable
	-- [104] removed factionrealm.internalData.{csvAuctionDBScan,auctionDBScanTime,auctionDBScanHash}
	-- [105] updated factionrealm.internalData.crafts, factionrealm.userData.craftingCooldownIgnore, char.internalData.craftingCooldowns
	-- [106] added global.userData.ungroupedItemMode
	-- [107] added global.tooltipOptions.{destroyTooltipFormat,convertTooltipFormat}, removed global.tooltipOptions.{deTooltip,millTooltip,prospectTooltip,transformTooltip,detailedDestroyTooltip}
	-- [108] updated global.tooltipOptions.moduleTooltips
	-- [109] updated global.craftingUIContext.professionScrollingTable
	-- [110] removed factionrealm.auctioningOptions.whitelist on retail
	-- [111] updated global.craftingUIContext.{professionScrollingTable,professionDividedContainer}
	-- [112] updated global.craftingUIContext.professionScrollingTable
	-- [113] updated global.craftingUIContext.professionDividedContainerBottom
	-- [114] updated factionrealm.internalData.crafts
	-- [115] removed global.internalData.optionalMatTextLookup
	-- [116] updated global.internalData.destroyingHistory
	-- [117] added global.storyBoardUIContext, updated global.craftingUIContext.{craftsScrollingTable,matsScrollingTable,gatheringScrollingTable}
	-- [118] updated factionrealm.internalData.crafts
	-- [119] added global.coreOptions.regionWide
	-- [120] updated factionrealm.internalData.crafts
	-- [121] rename global.userData.operations to global.userData.sharedOperations
	-- [122] updated global.auctionUIContext.{myAuctionsScrollingTable,auctioningBagScrollingTable,auctioningLogScrollingTable,auctioningAuctionScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}
	--  updated global.craftingUIContext.{craftsScrollingTable,matsScrollingTable,gatheringScrollingTable,professionScrollingTable}
	--  updated global.destroyingUIContext.itemsScrollingTable
	-- 	updated global.mailingUIContext.mailsScrollingTable
	--  updated global.mainUIContext.{operationsSummaryScrollingTable,ledgerDetailScrollingTable,ledgerTransactionsScrollingTable,ledgerResaleScrollingTable,ledgerInventoryScrollingTable,ledgerOtherScrollingTable}
	--  updated global.vendoringUIContext.buyScrollingTable,buybackScrollingTable,sellScrollingTable
	-- [123] added global.userData.customPriceSourceFormat
	-- [124] updated global.auctionUIContext.auctioningBagScrollingTable
	-- [125] updated global.shoppingOptions.maxDeSearchLvl
	-- [126] added realm.coreOptions.auctionDBAltRealm
	-- [127] added global.internalData.warbankQuantity
	-- [128] added global.internalData.{warbankMoney,warbankGoldLog,warbankGoldLogLastUpdate}
	-- [129] updated factionrealm.internalData.crafts
	-- [130/131] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable}, factionrealm.auctioningOptions.whitelist
	-- [132] removed factionrealm.auctioningOptions.whitelist, factionrealm.auctioningOptions, global.auctioningOptions.matchWhitelist
	-- [133] added global.craftingOptions.mixedQualityThreshold
	-- [134] removed sync.internalData.reagentBankQuantity
	-- [135] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}
	-- [136] updated global.auctionUIContext.{auctioningBagScrollingTable,myAuctionsScrollingTable,sniperScrollingTable}
	--  updated global.craftingUIContext.{craftsScrollingTable,matsScrollingTable,gatheringScrollingTable}
	--  updated global.destroyingUIContext.itemsScrollingTable
	--  updated global.mailingUIContext.mailsScrollingTable
	--  updated global.vendoringUIContext.{buybackScrollingTable,buyScrollingTable,sellScrollingTable}
	-- [137] removed global.appearanceOptions.{colorSet,customColorSet}, added global.appearanceOptions.{activeThemeKey,customThemeRamps}
	-- [138] updated factionrealm.internalData.craftingQueue
	-- [139] added global.auctionUIContext.{auctioningPostDividedContainer,auctioningPostLogScrollingTable}
	-- [140] updated global.auctionUIContext.{auctioningAuctionScrollingTable,auctioningLogScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}
	-- [141] updated global.mailingUIContext.mailsScrollingTable
	-- [142] updated global.auctionUIContext.auctioningBagScrollingTable, global.craftingUIContext.professionScrollingTable, global.mainUIContext.operationsSummaryScrollingTable
	-- [143] updated global.craftingUIContext.gatheringScrollingTable
	-- [144] updated global.craftingUIContext.professionDividedContainerBottom
	-- [145] updated global.vendoringUIContext.{buybackScrollingTable,buyScrollingTable,sellScrollingTable}
	-- [146] removed the default Warehousing, Mailing, and Vendoring operations from the base group in profile.userData.groups
	-- [147] updated global.craftingUIContext.gatheringScrollingTable
	-- [148] updated global.craftingUIContext.{craftsScrollingTable,matsScrollingTable}
	-- [149] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}
	-- [150] renamed the Forever realms to Normal, Roleplay, and Roleplay PvP
	-- [151] cleared factionrealm.internalData.{crafts,craftingQueue}, factionrealm.userData.craftingCooldownIgnore on classic
	-- [152] added global.internalData.groupImportResults
	return Settings.NewSchema(152, 102)
		:EnterScope("global")
			:EnterNamespace("debug")
				:AddBoolean("chatLoggingEnabled", false, 102)
			:LeaveNamespace()
			:EnterNamespace("internalData")
				:AddString("lastCharacter", "???", 102)
				:AddTable("vendorItems", {}, 102)
				:AddNumber("appMessageId", 0, 102)
				:AddTable("destroyingHistory", {}, 116)
				:AddNumber("whatsNewVersion", 0, 102)
				:AddTable("warbankQuantity", {}, 127)
				:AddNumber("warbankMoney", 0, 128)
				:AddString("warbankGoldLog", "", 128)
				:AddNumber("warbankGoldLogLastUpdate", 0, 128)
				:AddTable("groupImportResults", {}, 152)
			:LeaveNamespace()
			:EnterNamespace("appearanceOptions")
				:AddBoolean("taskListBackgroundLock", false, 102)
				:AddBoolean("showTotalMoney", false, 102)
				:AddString("activeThemeKey", "default", 137)
				:AddTable("customThemeRamps", {}, 137)
			:LeaveNamespace()
			:EnterNamespace("auctionUIContext")
				:AddTable("frame", { width = 830, height = 587, centerX = -300, centerY = 100, scale = 1, page = 1 }, 102)
				:AddBoolean("showDefault", false, 102)
				:AddTable("auctioningSelectionDividedContainer", { leftWidth = 272 }, 102)
				:AddTable("auctioningSelectionVerticalDividedContainer", { leftWidth = 220 }, 102)
				:AddTable("auctioningBagScrollingTable", { cols = { { id = "selected", width = 16, hidden = nil }, { id = "item", width = 265, hidden = nil }, { id = "operation", width = 206, hidden = nil }, { id = "group", width = 160, hidden = true } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 142)
				:AddTable("auctioningLogScrollingTable", { cols = { { id = "index", width = 14, hidden = nil }, { id = "item", width = 184, hidden = nil }, { id = "buyout", width = 110, hidden = nil }, { id = "operation", width = 108, hidden = nil }, { id = "seller", width = 90, hidden = nil }, { id = "info", width = 234, hidden = nil } }, colWidthLocked = nil, sortCol = "index", sortAscending = false }, 140)
				:AddTable("auctioningAuctionScrollingTable", { cols = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic()) and { { id = "item", width = 220, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "qty", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 136, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, } or { { id = "item", width = 228, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "posts", width = 40, hidden = nil }, { id = "stack", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 80, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, }, sortCol = "pct", sortAscending = true }, 149)
				:AddTable("auctioningPostDividedContainer", { leftWidth = 547 }, 139)
				:AddTable("auctioningPostLogScrollingTable", { cols = { { id = "index", width = 14, hidden = nil }, { id = "item", width = 363, hidden = nil }, { id = "buyout", width = 120, hidden = nil }, { id = "operation", width = 108, hidden = true }, { id = "seller", width = 90, hidden = true }, { id = "info", width = 234, hidden = true } }, colWidthLocked = nil, sortCol = "index", sortAscending = false }, 139)
				:AddTable("myAuctionsScrollingTable", { cols = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic()) and { { id = "item", width = 242, hidden = nil }, { id = "stackSize", width = 30, hidden = nil }, { id = "timeLeft", width = 40, hidden = nil }, { id = "group", width = 228, hidden = nil }, { id = "currentBid", width = 100, hidden = nil }, { id = "buyout", width = 100, hidden = nil } } or { { id = "item", width = 242, hidden = nil }, { id = "stackSize", width = 30, hidden = nil }, { id = "timeLeft", width = 40, hidden = nil }, { id = "highBidder", width = 110, hidden = nil }, { id = "group", width = 110, hidden = nil }, { id = "currentBid", width = 100, hidden = nil }, { id = "buyout", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic()) and "item" or nil, sortAscending = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic()) and true or nil }, 149)
				:AddTable("shoppingSelectionDividedContainer", { leftWidth = 272 }, 102)
				:AddTable("shoppingAuctionScrollingTable", { cols = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic()) and { { id = "item", width = 220, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "qty", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 136, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, } or { { id = "item", width = 228, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "posts", width = 40, hidden = nil }, { id = "stack", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 80, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, }, sortCol = "pct", sortAscending = true }, 149)
				:AddTable("sniperScrollingTable", { cols = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic()) and { { id = "icon", width = 24, hidden = nil }, { id = "item", width = 224, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "qty", width = 40, hidden = nil }, { id = "seller", width = 134, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, } or { { id = "icon", width = 24, hidden = nil }, { id = "item", width = 224, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "posts", width = 40, hidden = nil }, { id = "stack", width = 40, hidden = nil }, { id = "seller", width = 86, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, }, sortCol = "pct", sortAscending = true }, 149)
				:AddTable("shoppingSearchesTabGroup", { pathIndex = 1 }, 102)
				:AddTable("auctioningTabGroup", { pathIndex = 1 }, 102)
			:LeaveNamespace()
			:EnterNamespace("bankingUIContext")
				:AddTable("frame", { width = 325, height = 600, centerX = 500, centerY = 0, scale = 1 }, 102)
				:AddBoolean("isOpen", true, 102)
				:AddString("tab", "Warehousing", 102)
			:LeaveNamespace()
			:EnterNamespace("craftingUIContext")
				:AddTable("frame", { width = 820, height = 587, centerX = -200, centerY = 0, scale = 1, page = 1 }, 102)
				:AddBoolean("showDefault", false, 102)
				:AddTable("craftsScrollingTable", { cols = { { id = "queued", width = 30, hidden = nil }, { id = "craftName", width = 212, hidden = nil }, { id = "operation", width = 80, hidden = nil }, { id = "bags", width = 28, hidden = nil }, { id = "ah", width = 24, hidden = nil }, { id = "craftingCost", width = 100, hidden = nil }, { id = "itemValue", width = 100, hidden = nil }, { id = "profit", width = 100, hidden = nil } , { id = "profitPct", width = 50, hidden = true }, { id = "saleRate", width = 32, hidden = nil } }, colWidthLocked = nil, sortCol = "craftName", sortAscending = true }, 148)
				:AddTable("matsScrollingTable", { cols = { { id = "name", width = 244, hidden = nil }, { id = "price", width = 100, hidden = nil }, { id = "professions", width = 302, hidden = nil }, { id = "num", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = "name", sortAscending = true }, 148)
				:AddTable("gatheringDividedContainer", { leftWidth = 284 }, 102)
				:AddTable("gatheringScrollingTable", { cols = { { id = "name", width = 197, hidden = nil }, { id = "sources", width = 160, hidden = nil }, { id = "have", width = 50, hidden = nil }, { id = "need", width = 50, hidden = nil } }, colWidthLocked = nil, sortCol = "name", sortAscending = true }, 147)
				:AddTable("professionScrollingTable", { cols = { { id = "name", width = 308, hidden = nil }, { id = "qty", width = 54, hidden = nil }, { id = "craftingCost", width = 100, hidden = true }, { id = "itemValue", width = 100, hidden = true }, { id = "profit", width = 100, hidden = nil }, { id = "profitPct", width = 50, hidden = true }, { id = "saleRate", width = 42, hidden = nil } }, colWidthLocked = nil, collapsed = {} }, 142)
				:AddTable("professionDividedContainer", { leftWidth = 556 }, 111)
				:AddTable("professionDividedContainerBottom", { leftWidth = (LibTSMSystem.IsRetail() or LibTSMSystem.IsForever()) and 320 or 348 }, 144)
			:LeaveNamespace()
			:EnterNamespace("destroyingUIContext")
				:AddTable("frame", { width = 296, height = 442, centerX = 0, centerY = 0, scale = 1 }, 102)
				:AddTable("itemsScrollingTable", { cols = { { id = "item", width = 208, hidden = nil }, { id = "num", width = 30, hidden = nil } }, colWidthLocked = nil }, 136)
			:LeaveNamespace()
			:EnterNamespace("storyBoardUIContext")
				:AddTable("frame", { width = 800, height = 600, centerX = 0, centerY = 0, scale = 1 }, 117)
			:LeaveNamespace()
			:EnterNamespace("mailingUIContext")
				:AddTable("frame", { width = 620, height = 516, centerX = -200, centerY = 0, scale = 1, page = 1 }, 102)
				:AddBoolean("showDefault", false, 102)
				:AddTable("mailsScrollingTable", { cols = { { id = "items", width = 338, hidden = nil }, { id = "sender", width = 100, hidden = true }, { id = "expires", width = 96, hidden = nil }, { id = "money", width = 120, hidden = nil } }, colWidthLocked = nil }, 141)
			:LeaveNamespace()
			:EnterNamespace("mainUIContext")
				:AddTable("frame", { width = 900, height = 700, centerX = 0, centerY = 0, scale = 1, page = 1 }, 102)
				:AddTable("ledgerDetailScrollingTable", { cols = { { id = "activityType", width = 91, hidden = nil }, { id = "source", width = 60, hidden = nil }, { id = "buyerSeller", width = 100, hidden = nil }, { id = "qty", width = 45, hidden = nil }, { id = "perItem", width = 120, hidden = nil }, { id = "totalPrice", width = 120, hidden = nil }, { id = "time", width = 110, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerInventoryScrollingTable", { cols = { { id = "item", width = 160, hidden = nil }, { id = "totalItems", width = 50, hidden = nil }, { id = "bags", width = 50, hidden = nil }, { id = "banks", width = 50, hidden = nil }, { id = "mail", width = 50, hidden = nil }, { id = "alts", width = 50, hidden = nil }, { id = "guildVault", width = 50, hidden = nil }, { id = "auctionHouse", width = 50, hidden = nil }, { id = "totalValue", width = 120, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 122)
				:AddTable("ledgerAuctionsScrollingTable", { cols = { { id = "item", width = 305, hidden = nil }, { id = "player", width = 110, hidden = nil }, { id = "stackSize", width = 55, hidden = nil }, { id = "quantity", width = 72, hidden = nil }, { id = "time", width = 120, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerOtherScrollingTable", { cols = { { id = "type", width = 200, hidden = nil }, { id = "character", width = 110, hidden = nil }, { id = "otherCharacter", width = 122, hidden = nil }, { id = "amount", width = 120, hidden = nil }, { id = "time", width = 110, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerTransactionsScrollingTable", { cols = { { id = "item", width = 156, hidden = nil }, { id = "player", width = 95, hidden = nil }, { id = "type", width = 50, hidden = nil }, { id = "stack", width = 55, hidden = nil }, { id = "auctions", width = 60, hidden = nil }, { id = "perItem", width = 120, hidden = nil }, { id = "total", width = 120, hidden = true }, { id = "time", width = 110, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerResaleScrollingTable", { cols = { { id = "item", width = 194, hidden = nil }, { id = "bought", width = 50, hidden = nil }, { id = "avgBuyPrice", width = 120, hidden = nil }, { id = "sold", width = 50, hidden = nil }, { id = "avgSellPrice", width = 120, hidden = nil }, { id = "avgProfit", width = 120, hidden = nil }, { id = "totalProfit", width = 120, hidden = true }, { id = "profitPct", width = 80, hidden = true } }, colWidthLocked = nil, sortCol = "item", sortAscending = true } , 122)
				:AddTable("dashboardDividedContainer", { leftWidth = 300 }, 102)
				:AddTable("dashboardUnselectedCharacters", {}, 102)
				:AddNumber("dashboardTimeRange", -1, 102)
				:AddTable("groupsDividedContainer", { leftWidth = 300 }, 102)
				:AddTable("operationsDividedContainer", { leftWidth = 306 }, 102)
				:AddTable("importExportDividedContainer", { leftWidth = 300 }, 102)
				:AddTable("operationsSummaryScrollingTable", { cols = { { id = "selected", width = 16, hidden = nil }, { id = "name", width = 231, hidden = nil }, { id = "groups", width = 130, hidden = nil }, { id = "items", width = 130, hidden = nil } }, colWidthLocked = nil, sortCol = "name", sortAscending = true }, 142)
			:LeaveNamespace()
			:EnterNamespace("taskListUIContext")
				:AddTable("frame", { topRightX = -220, topRightY = -10, minimized = false, isOpen = true }, 102)
				:AddBoolean("isOpen", true, 102)
			:LeaveNamespace()
			:EnterNamespace("vendoringUIContext")
				:AddTable("frame", { width = 560, height = 500, centerX = -200, centerY = 0, scale = 1, page = 1 }, 102)
				:AddBoolean("showDefault", false, 102)
				:AddTable("buyScrollingTable", { cols = { { id = "qty", width = 40, hidden = nil }, { id = "item", width = 304, hidden = nil }, { id = "ilvl", width = 32, hidden = true }, { id = "cost", width = 150, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 145)
				:AddTable("buybackScrollingTable", { cols = { { id = "qty", width = 40, hidden = nil }, { id = "item", width = 354, hidden = nil }, { id = "cost", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 145)
				:AddTable("sellScrollingTable", { cols = { { id = "item", width = 294, hidden = nil }, { id = "vendorSell", width = 100, hidden = nil }, { id = "potential", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 145)
			:LeaveNamespace()
			:EnterNamespace("coreOptions")
				:AddBoolean("globalOperations", false, 102)
				:AddBoolean("protectAuctionHouse", false, 102)
				:AddString("chatFrame", "", 102)
				:AddString("auctionSaleSound", "TSM_NO_SOUND", 102)
				:AddTable("minimapIcon", { hide = false, minimapPos = 220, radius = 80 }, 102)
				:AddString("destroyValueSource", "dbmarket", 102)
				:AddString("groupPriceSource", "dbmarket", 102)
				:AddBoolean("regionWide", false, 119)
			:LeaveNamespace()
			:EnterNamespace("accountingOptions")
				:AddBoolean("trackTrades", true, 102)
				:AddBoolean("autoTrackTrades", false, 102)
			:LeaveNamespace()
			:EnterNamespace("auctioningOptions")
				:AddBoolean("cancelWithBid", false, 102)
				:AddBoolean("disableInvalidMsg", false, 102)
				:AddString("scanCompleteSound", "TSM_NO_SOUND", 102)
				:AddString("confirmCompleteSound", "TSM_NO_SOUND", 102)
			:LeaveNamespace()
			:EnterNamespace("craftingOptions")
				:AddString("defaultMatCostMethod", "min(dbmarket, crafting, vendorbuy, convert(dbmarket))", 102)
				:AddString("defaultCraftPriceMethod", "first(dbminbuyout, dbmarket)*0.95", 102)
				:AddTable("ignoreCharacters", {}, 102)
				:AddTable("ignoreGuilds", {}, 102)
				:AddNumber("mixedQualityThreshold", 5, 133)
			:LeaveNamespace()
			:EnterNamespace("destroyingOptions")
				:AddBoolean("autoStack", true, 102)
				:AddBoolean("includeSoulbound", false, 102)
				:AddBoolean("autoShow", true, 102)
				:AddNumber("deMaxQuality", 3, 102)
				:AddString("deAbovePrice", "0c", 102)
			:LeaveNamespace()
			:EnterNamespace("mailingOptions")
				:AddBoolean("sendItemsIndividually", false, 102)
				:AddBoolean("inboxMessages", true, 102)
				:AddBoolean("sendMessages", true, 102)
				:AddNumber("resendDelay", 1, 102)
				:AddNumber("keepMailSpace", 0, 102)
				:AddNumber("deMaxQuality", 2, 102)
				:AddString("openMailSound", "TSM_NO_SOUND", 102)
				:AddTable("recentlyMailedList", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("shoppingOptions")
				:AddNumber("minDeSearchLvl", 1, 102)
				:AddNumber("maxDeSearchLvl", 600, 125)
				:AddNumber("maxDeSearchPercent", 100, 102)
				:AddString("pctSource", "dbmarket", 102)
				:AddBoolean("buyoutConfirm", false, 102)
				:AddString("buyoutAlertSource", "min(100000g, 200% dbmarket)", 102)
				:AddBoolean("searchAutoFocus", true, 102)
			:LeaveNamespace()
			:EnterNamespace("sniperOptions")
				:AddString("sniperSound", "TSM_NO_SOUND", 102)
			:LeaveNamespace()
			:EnterNamespace("vendoringOptions")
				:AddBoolean("displayMoneyCollected", false, 102)
				:AddString("qsMarketValue", "dbmarket", 102)
			:LeaveNamespace()
			:EnterNamespace("tooltipOptions")
				:AddBoolean("enabled", true, 102)
				:AddBoolean("embeddedTooltip", true, 102)
				:AddTable("customPriceTooltips", {}, 102)
				:AddTable("moduleTooltips", {}, 108)
				:AddBoolean("vendorBuyTooltip", true, 102)
				:AddBoolean("vendorSellTooltip", true, 102)
				:AddBoolean("groupNameTooltip", true, 102)
				:AddString("destroyTooltipFormat", "simple", 107)
				:AddString("convertTooltipFormat", "simple", 107)
				:AddTable("operationTooltips", {}, 102)
				:AddString("tooltipShowModifier", "none", 102)
				:AddString("inventoryTooltipFormat", "full", 102)
				:AddString("tooltipPriceFormat", "text", 102)
			:LeaveNamespace()
			:EnterNamespace("userData")
				:AddTable("sharedOperations", {}, 121)
				:AddTable("customPriceSources", {}, 102)
				:AddTable("customPriceSourceFormat", {}, 123)
				:AddTable("destroyingIgnore", {}, 102)
				:AddTable("savedShoppingSearches", { filters = {}, name = {}, isFavorite = {} }, 102)
				:AddTable("vendoringIgnore", {}, 102)
				:AddTable("savedAuctioningSearches", { filters = {}, searchTypes = {}, name = {}, isFavorite = {} }, 102)
				:AddString("ungroupedItemMode", "specific", 106)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("profile")
			:EnterNamespace("internalData")
				:AddBoolean("createdDefaultOperations", false, 102)
			:LeaveNamespace()
			:EnterNamespace("userData")
				:AddTable("groups", {}, 102)
				:AddTable("items", {}, 102)
				:AddTable("operations", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("gatheringOptions")
				:AddTable("sources", { "vendor", "guildBank", "alt", "altGuildBank", "craftProfit", "auction", "craftNoProfit" }, 102)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("factionrealm")
			:EnterNamespace("internalData")
				:AddTable("characterGuilds", {}, 102)
				:AddTable("guildVaults", {}, 102)
				:AddTable("pendingMail", {}, 102)
				:AddTable("expiringMail", {}, 102)
				:AddTable("expiringAuction", {}, 102)
				:AddString("mailDisenchantablesChar", "", 102)
				:AddString("mailExcessGoldChar", "", 102)
				:AddNumber("mailExcessGoldLimit", 10000000000, 102)
				:AddTable("crafts", {}, 129)
				:AddTable("craftingQueue", {}, 138)
				:AddTable("mats", {}, 102)
				:AddTable("guildGoldLog", {}, 102)
				:AddTable("guildGoldLogLastUpdate", {}, 102)
				:AddTable("isCraftFavorite", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("coreOptions")
				:AddTable("ignoreGuilds", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("gatheringContext")
				:AddString("crafter", "", 102)
				:AddTable("professions", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("userData")
				:AddTable("craftingCooldownIgnore", {}, 105)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("realm")
			:EnterNamespace("internalData")
				:AddString("csvSales", "", 102)
				:AddString("csvBuys", "", 102)
				:AddString("csvIncome", "", 102)
				:AddString("csvExpense", "", 102)
				:AddString("csvExpired", "", 102)
				:AddString("csvCancelled", "", 102)
				:AddString("saveTimeSales", "", 102)
				:AddString("saveTimeBuys", "", 102)
				:AddString("saveTimeExpires", "", 102)
				:AddString("saveTimeCancels", "", 102)
				:AddTable("accountingTrimmed", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("coreOptions")
				:AddString("auctionDBAltRealm", "", 126)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("char")
			:EnterNamespace("internalData")
				:AddTable("auctionPrices", {}, 102)
				:AddTable("auctionMessages", {}, 102)
				:AddTable("craftingCooldowns", {}, 105)
				:AddTable("auctionSaleHints", {}, 102)
			:LeaveNamespace()
			:EnterNamespace("auctionUIContext")
				:AddTable("auctioningGroupTree", { collapsed = {}, unselected = {} }, 102)
				:AddTable("shoppingGroupTree", { collapsed = {}, unselected = {} }, 102)
			:LeaveNamespace()
			:EnterNamespace("bankingUIContext")
				:AddTable("warehousingGroupTree", { collapsed = {}, unselected = {} }, 102)
				:AddTable("auctioningGroupTree", { collapsed = {}, unselected = {} }, 102)
				:AddTable("mailingGroupTree", { collapsed = {}, unselected = {} }, 102)
			:LeaveNamespace()
			:EnterNamespace("craftingUIContext")
				:AddTable("groupTree", { collapsed = {}, unselected = {} }, 102)
			:LeaveNamespace()
			:EnterNamespace("mailingUIContext")
				:AddTable("groupTree", { collapsed = {}, unselected = {} }, 102)
			:LeaveNamespace()
			:EnterNamespace("vendoringUIContext")
				:AddTable("groupTree", { collapsed = {}, unselected = {} }, 102)
			:LeaveNamespace()
			:EnterNamespace("mainUIContext")
				:AddTable("groupsManagementGroupTree", { collapsed = {} }, 102)
				:AddTable("importGroupTree", { collapsed = {}, selected = {} }, 102)
				:AddTable("exportGroupTree", { collapsed = {}, unselected = {} }, 102)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("sync")
			-- NOTE: whenever these are changed, the sync version needs to be increased in LibTSMService/Source/Sync/Classes/Constants.lua
			:EnterNamespace("internalData")
				:AddNumber("money", 0, 102)
				:AddString("classKey", "", 102)
				:AddTable("bagQuantity", {}, 102)
				:AddTable("bankQuantity", {}, 102)
				:AddTable("auctionQuantity", {}, 102)
				:AddTable("mailQuantity", {}, 102)
				:AddString("goldLog", "", 102)
				:AddNumber("goldLogLastUpdate", 0, 102)
				:AddTable("playerProfessions", {}, 102)
			:LeaveNamespace()
		:LeaveScope()
		:Commit()
end

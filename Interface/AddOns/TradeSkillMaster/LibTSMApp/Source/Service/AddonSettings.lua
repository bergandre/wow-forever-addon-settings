-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AddonSettings = LibTSMApp:Init("Service.AddonSettings")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local Iterator = LibTSMApp:From("LibTSMUtil"):Include("BaseType.Iterator")
local OrderedTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.OrderedTable")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local ExecutionTime = LibTSMApp:From("LibTSMUtil"):Include("Util.ExecutionTime")
local Schema = LibTSMApp:From("LibTSMSystem"):Include("AddonSettings.Schema")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local Settings = LibTSMApp:From("LibTSMTypes"):Include("Settings")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local RealmInfo = LibTSMApp:From("LibTSMService"):Include("Data.RealmInfo")
local Sync = LibTSMApp:From("LibTSMService"):Include("Sync")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Lifecycle = LibTSMApp:From("LibTSMService"):Include("Util.Lifecycle")
local private = {
	db = nil,
	loadCallbacks = {}, ---@type OrderedTable.Table<AddonSettingsCallbackFunction,string>
}
local FOREVER_REALM_RENAMES = {
	PvE = "Normal",
	RP = "Roleplay",
	["RP PvP"] = "Roleplay PvP",
}

---@alias AddonSettingsCallbackFunction fun(db: SettingsDB)



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings:OnModuleLoad(function()
	SlashCommands.Register("profile", private.ChangeProfile, L["Changes to the specified profile (i.e. '/tsm profile Default' changes to the 'Default' profile)"])
	Lifecycle.RegisterCallback(private.HandleLoaded, Lifecycle.EVENT.LOADED)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the addon settings database.
function AddonSettings.LoadDB()
	-- Load the settings DB
	local connectedRealms = {}
	for _, name in RealmInfo.ConnectedRealmIterator() do
		tinsert(connectedRealms, name)
	end
	local factionName = SessionInfo.GetFactionName()
	local accessibleFactions = nil
	if LibTSMApp.IsRetail() then
		accessibleFactions = { "Horde", "Alliance", "Neutral" }
	else
		accessibleFactions = { factionName }
	end
	local db, upgradeObj = Settings.NewDB("TradeSkillMasterDB", Schema.Get(), SessionInfo.GetRealmName(), factionName, SessionInfo.GetCharacterName(), connectedRealms, accessibleFactions)
	if upgradeObj then
		private.ProcessUpgrade(db, upgradeObj)
	end
	private.db = db

	-- Call the load callbacks
	for _, callback, debugName in OrderedTable.Iterator(private.loadCallbacks) do
		for _ in ExecutionTime.WithMeasurement("Loading settings for %s", debugName) do
			callback(db)
		end
	end
	wipe(private.loadCallbacks)

	-- Configure the sync code
	local svCopyError = L["It appears that you've manually copied your saved variables between accounts which will cause TSM's automatic sync'ing to not work. You'll need to undo this, and/or delete the TradeSkillMaster saved variables files on both accounts (with WoW closed) in order to fix this."]
	Sync.Load(db, svCopyError)
end

---Register a callback when the settings are loaded.
---@param debugName any A name used for debugging or the module / class registering the callback
---@param callback AddonSettingsCallbackFunction The callback function
function AddonSettings.RegisterOnLoad(debugName, callback)
	assert(not private.db and not private.loadCallbacks[callback])
	OrderedTable.Insert(private.loadCallbacks, callback, tostring(debugName))
end

---Gets the addon settings DB
---@return SettingsDB
function AddonSettings.GetDB()
	assert(private.db)
	return private.db
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLoaded()
	AddonSettings.LoadDB()
	return true
end

---@param db SettingsDB
---@param upgradeObj SettingsMigration
function private.ProcessUpgrade(db, upgradeObj)
	local prevVersion = upgradeObj:GetPrevVersion()
	if prevVersion < 105 and (LibTSMApp.IsRetail() or LibTSMApp.IsForever()) then
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "userData", "craftingCooldownIgnore") do
			if prevVersion < 99 then
				local IGNORED_COOLDOWN_SEP = "\001"
				local newValue = {}
				for entry in pairs(value) do
					local characterKey, spellId = strsplit(IGNORED_COOLDOWN_SEP, entry)
					newValue[characterKey..IGNORED_COOLDOWN_SEP.."c:"..spellId] = true
				end
				value = newValue
			end
			db:Set("factionrealm", upgradeObj:GetScopeKey(key), "userData", "craftingCooldownIgnore", value)
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("char", nil, "internalData", "craftingCooldowns") do
			if prevVersion < 99 then
				local newValue = {}
				for spellId, data in pairs(value) do
					newValue["c:"..spellId] = data
				end
				value = newValue
			end
			db:Set("char", upgradeObj:GetScopeKey(key), "internalData", "craftingCooldowns", value)
		end
	end
	if prevVersion < 108 then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "tooltipOptions", "moduleTooltips") do
			-- update AuctionDB.{marketValue,regionMarketValue} values
			if value.AuctionDB then
				value.AuctionDB.marketValue = value.AuctionDB.marketValue and "withTrend" or "none"
				value.AuctionDB.regionMarketValue = value.AuctionDB.regionMarketValue and "noTrend" or "none"
			end
			db:Set("global", upgradeObj:GetScopeKey(key), "tooltipOptions", "moduleTooltips", value)
		end
	end
	if prevVersion < 121 then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "userData", "operations") do
			db:Set("global", upgradeObj:GetScopeKey(key), "userData", "sharedOperations", value)
		end
	end
	if prevVersion < 122 then
		local function MigrateScrollTableContext(namespace, settingKey)
			for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, namespace, settingKey) do
				local newValue = db:Get("global", upgradeObj:GetScopeKey(key), namespace, settingKey)
				if value.colWidth then
					for _, colSettings in ipairs(newValue.cols) do
						local oldWidth = value.colWidth[colSettings.id]
						if type(oldWidth) == "number" then
							colSettings.width = oldWidth
						end
						colSettings.hidden = value.colHidden[colSettings.id] and true or nil
					end
					newValue.colWidthLocked = value.colWidthLocked and true or nil
					newValue.collapsed = value.collapsed
				end
			end
		end
		for _, _, value in upgradeObj:RemovedSettingIterator("global", nil, "auctionUIContext", "myAuctionsScrollingTable") do
			if value.colWidth then
				value.colWidth.highBidder = value.colWidth.highbidder
			end
		end
		MigrateScrollTableContext("auctionUIContext", "myAuctionsScrollingTable")
		MigrateScrollTableContext("destroyingUIContext", "itemsScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "auctioningBagScrollingTable")
		MigrateScrollTableContext("mainUIContext", "operationsSummaryScrollingTable")
		MigrateScrollTableContext("craftingUIContext", "craftsScrollingTable")
		MigrateScrollTableContext("craftingUIContext", "matsScrollingTable")
		MigrateScrollTableContext("craftingUIContext", "gatheringScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerAuctionsScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerDetailScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerInventoryScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerOtherScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerResaleScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerTransactionsScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "auctioningLogScrollingTable")
		MigrateScrollTableContext("vendoringUIContext", "buyScrollingTable")
		MigrateScrollTableContext("vendoringUIContext", "buybackScrollingTable")
		MigrateScrollTableContext("vendoringUIContext", "sellScrollingTable")
		MigrateScrollTableContext("mailingUIContext", "mailsScrollingTable")
		if prevVersion >= 82 then
			MigrateScrollTableContext("craftingUIContext", "professionScrollingTable")
		end
		MigrateScrollTableContext("auctionUIContext", "auctioningAuctionScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "shoppingAuctionScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "sniperScrollingTable")
	end
	if prevVersion < 129 then
		if LibTSMApp.IsRetail() or LibTSMApp.IsForever() then
			for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "internalData", "crafts") do
				if prevVersion < 99 then
					local newValue = {}
					for spellId, data in pairs(value) do
						newValue["c:"..spellId] = data
					end
					value = newValue
				end
				if prevVersion < 114 then
					for _, craft in pairs(value) do
						if craft.mats then
							for itemString in pairs(craft.mats) do
								if strmatch(itemString, "^o:") then
									craft.mats[itemString] = 1
								end
							end
						end
					end
				end
				if prevVersion < 129 then
					for _, craft in pairs(value) do
						for _, info in pairs(craft.players) do
							if type(info) == "table" and info.baseRecipeDifficulty then
								info.inspirationAmount = nil
								info.inspirationChance = nil
							end
						end
					end
				end
				db:Set("factionrealm", upgradeObj:GetScopeKey(key), "internalData", "crafts", value)
			end
		else
			for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "internalData", "crafts") do
				db:Set("factionrealm", upgradeObj:GetScopeKey(key), "internalData", "crafts", value)
			end
		end
	end
	if prevVersion < 146 then
		for _, profile in db:ScopeKeyIterator("profile") do
			local groups = db:Get("profile", profile, "userData", "groups")
			private.RemoveBaseGroupDefaultOperation(groups, "Warehousing")
			private.RemoveBaseGroupDefaultOperation(groups, "Mailing")
			private.RemoveBaseGroupDefaultOperation(groups, "Vendoring")
		end
	end
	if prevVersion < 150 and LibTSMApp.IsForever() then
		for oldRealmName, newRealmName in pairs(FOREVER_REALM_RENAMES) do
			db:RenameRealm(oldRealmName, newRealmName)
		end
		local IGNORED_COOLDOWN_SEP = "\001"
		for _, factionrealm in db:ScopeKeyIterator("factionrealm") do
			local ignored = {}
			for entry, value in pairs(db:Get("factionrealm", factionrealm, "userData", "craftingCooldownIgnore")) do
				local character, realm, craftString = strmatch(entry, "^(.+) %- (.+)"..IGNORED_COOLDOWN_SEP.."(.+)$")
				if realm and FOREVER_REALM_RENAMES[realm] then
					entry = character.." - "..FOREVER_REALM_RENAMES[realm]..IGNORED_COOLDOWN_SEP..craftString
				end
				ignored[entry] = value
			end
			db:Set("factionrealm", factionrealm, "userData", "craftingCooldownIgnore", ignored)
		end
	end
	if prevVersion < 151 and not LibTSMApp.IsRetail() and not LibTSMApp.IsForever() then
		for _, factionrealm in db:ScopeKeyIterator("factionrealm") do
			db:Set("factionrealm", factionrealm, "internalData", "crafts", {})
			db:Set("factionrealm", factionrealm, "internalData", "craftingQueue", {})
			db:Set("factionrealm", factionrealm, "userData", "craftingCooldownIgnore", {})
		end
	end
	-- NOTE: When adding migrations, be careful of multiple migrations modifying the same key, as
	-- the RemovedSettingIterator value could be stale.
end

function private.RemoveBaseGroupDefaultOperation(groups, typeName)
	local baseGroupInfo = groups[Group.GetRootPath()]
	local operations = baseGroupInfo and baseGroupInfo[typeName]
	if not operations or Table.RemoveByValue(operations, "#Default") == 0 then
		return
	end
	for groupPath, groupInfo in pairs(groups) do
		if type(groupPath) == "string" and Group.GetParent(groupPath) == Group.GetRootPath() and groupInfo[typeName] then
			groupInfo[typeName].override = true
		end
	end
end

function private.ChangeProfile(targetProfile)
	targetProfile = strtrim(targetProfile)
	if targetProfile == "" then
		ChatMessage.PrintfUser(L["No profile specified. Possible profiles: '%s'"], private.GetProfileListStr())
	else
		for _, profile in private.db:ScopeKeyIterator("profile") do
			if profile == targetProfile then
				if profile ~= private.db:GetCurrentProfile() then
					private.db:SetProfile(profile)
				end
				ChatMessage.PrintfUser(L["Profile changed to '%s'."], profile)
				return
			end
		end
		ChatMessage.PrintfUser(L["Could not find profile '%s'. Possible profiles: '%s'"], targetProfile, private.GetProfileListStr())
	end
end

function private.GetProfileListStr()
	return Iterator.Acquire(private.db:ScopeKeyIterator("profile"))
		:ToJoinedValueString("', '")
end

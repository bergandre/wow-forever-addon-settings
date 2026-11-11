-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Gathering = LibTSMApp:InitInternal("Crafting.Gathering")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local PlayerInfo = LibTSMApp:Include("Service.PlayerInfo")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local Conversion = LibTSMApp:From("LibTSMTypes"):Include("Item.Conversion")
local DelayTimer = LibTSMApp:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local CombatLockdown = LibTSMApp:From("LibTSMWoW"):Include("Service.CombatLockdown")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local VendorBuy = LibTSMApp:From("LibTSMService"):Include("Item.VendorBuy")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local private = {
	settingsDB = nil,
	settings = nil,
	db = nil,
	queuedCraftsUpdateQuery = nil, ---@diagnostic disable-line: tsm-private
	crafterList = {},
	professionList = {},
	contextChangedCallback = nil,
	dbUpdateTimer = nil,
	altsTemp = {},
	updateTemp = {
		sourceList = {},
		matSourceList = {},
		matsNumNeed = {},
		matsNumHave = {},
		matsNumHaveExtra = {},
		matQueue = {},
	},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Gathering:OnModuleLoad(function()
	private.db = Database.NewSchema("GATHERING_MATS")
		:AddUniqueStringField("itemString")
		:AddNumberField("numNeed")
		:AddNumberField("numHave")
		:AddStringField("sourcesStr")
		:Commit()
	private.queuedCraftsUpdateQuery = Crafting.CreateQueuedCraftsQuery()
		:SetUpdateCallback(private.OnQueuedCraftsUpdated)
	private.dbUpdateTimer = DelayTimer.New("GATHERING_DB_UPDATE", private.UpdateDB)

	BagTracking.RegisterQuantityCallback(function()
		private.dbUpdateTimer:RunForTime(1)
	end)
	WarbankTracking.RegisterQuantityCallback(function()
		private.dbUpdateTimer:RunForTime(1)
	end)
end)

AddonSettings.RegisterOnLoad(Gathering, function(db)
	private.settingsDB = db
	private.settings = db:NewView("GatheringSettings")
		:AddKey("profile", "gatheringOptions", "sources")
		:AddKey("factionrealm", "gatheringContext", "crafter")
		:AddKey("factionrealm", "gatheringContext", "professions")
		:AddKey("global", "coreOptions", "regionWide")
		:Commit()
	if LibTSMApp.IsVanillaClassic() then
		Table.RemoveByValue(private.settings.sources, "guildBank")
		Table.RemoveByValue(private.settings.sources, "altGuildBank")
	end
	if LibTSMApp.IsRetail() then
		Table.RemoveByValue(private.settings.sources, "bank")
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the callback which is called when the gathering context changes.
---@param callback fun() The callback function
function Gathering.SetContextChangedCallback(callback)
	assert(not private.contextChangedCallback)
	private.contextChangedCallback = callback
	private.OnQueuedCraftsUpdated()
end

---Creates a query.
---@return DatabaseQuery
function Gathering.CreateQuery()
	return private.db:NewOwnedQuery()
end

---Sets the crafter to gather for.
---@param crafter string The name of the crafter
function Gathering.SetCrafter(crafter)
	if crafter == private.settings.crafter then
		return
	end
	private.settings.crafter = crafter
	wipe(private.settings.professions)
	private.UpdateProfessionList()
	private.UpdateDB()
end

---Sets the professions to gather for.
---@param professions string[] The profession names
function Gathering.SetProfessions(professions)
	local numProfessions = Table.Count(private.settings.professions)
	local didChange = false
	if numProfessions ~= #professions then
		didChange = true
	else
		for _, profession in ipairs(professions) do
			if not private.settings.professions[profession] then
				didChange = true
				break
			end
		end
	end
	if not didChange then
		return
	end
	wipe(private.settings.professions)
	for _, profession in ipairs(professions) do
		assert(private.professionList[profession])
		private.settings.professions[profession] = true
	end
	private.UpdateDB()
end

---Gets the available crafters to gather for.
---@return string[]
function Gathering.GetCrafterList()
	return private.crafterList
end

---Gets the available professions to gather for.
---@return string[]|table<string,true>
function Gathering.GetProfessionList()
	return private.professionList
end

---Gets the current crafter.
---@return string?
function Gathering.GetCrafter()
	return private.settings.crafter ~= "" and private.settings.crafter or nil
end

---Gets the current set of professions being gathered for.
---@return table<string,true>
function Gathering.GetProfessions()
	return private.settings.professions
end

---Extracts a sources string from a DB row into tables.
---@param sourcesStr string The string value from the DB
---@param info table<string,number> The result table populated with quantities by source
---@param alts table<string,true> The result table populated with alts being used
function Gathering.SourcesStrToTable(sourcesStr, info, alts)
	for source, num, characters in gmatch(sourcesStr, "([a-zA-Z]+)/([0-9]+)/([^,]*)") do
		info[source] = tonumber(num)
		if source == "alt" or source == "altGuildBank" then
			for character in gmatch(characters, "([^`]+)") do
				alts[character] = true
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateCrafterList()
	local query = Crafting.CreateQueuedCraftsQuery()
		:AutoRelease()
	wipe(private.crafterList)
	for _, charactersIter in query:Iterator("characters") do
		for _, character in charactersIter do
			if not private.crafterList[character] then
				private.crafterList[character] = true
				tinsert(private.crafterList, character)
			end
		end
	end

	if private.settings.crafter ~= "" and not private.crafterList[private.settings.crafter] then
		-- The crafter which was selected no longer exists, so clear the selection
		private.settings.crafter = ""
	elseif #private.crafterList == 1 then
		-- There is only one crafter in the list, so select it
		private.settings.crafter = private.crafterList[1]
	end
	if private.settings.crafter == "" then
		wipe(private.settings.professions)
	end
end

function private.UpdateProfessionList()
	-- Update the professionList
	wipe(private.professionList)
	if private.settings.crafter ~= "" then
		-- Populate the list of professions
		Crafting.CreateQueuedCraftsQuery()
			:AutoRelease()
			:ListContains("characters", private.settings.crafter)
			:Distinct("profession")
			:AsTable(private.professionList, "profession")
		for _, profession in ipairs(private.professionList) do
			private.professionList[profession] = true
		end
	end

	-- Remove selected professions which are no longer in the list
	for profession in pairs(private.settings.professions) do
		if not private.professionList[profession] then
			private.settings.professions[profession] = nil
		end
	end

	-- Select all professions by default
	if not next(private.settings.professions) then
		for _, profession in ipairs(private.professionList) do
			private.settings.professions[profession] = true
		end
	end
end

function private.OnQueuedCraftsUpdated()
	if not private.contextChangedCallback then
		return
	end
	private.UpdateCrafterList()
	private.UpdateProfessionList()
	private.UpdateDB()
	private.contextChangedCallback()
end

function private.UpdateDB()
	-- Delay the update if we're in combat
	if CombatLockdown.IsActive() then
		private.dbUpdateTimer:RunForTime(1)
		return
	end
	local crafter = private.settings.crafter
	if crafter == "" or not next(private.settings.professions) then
		private.db:Truncate()
		return
	end

	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end

	local query = Crafting.CreateQueuedCraftsQuery()
		:AutoRelease()
		:ListContains("characters", crafter)
		:InTable("profession", private.settings.professions)
	for _, recipeString, numQueued in query:Iterator("recipeString", "num") do
		for _, itemString, quantity in Crafting.MatIteratorByRecipeString(recipeString) do
			updateTemp.matsNumNeed[itemString] = (updateTemp.matsNumNeed[itemString] or 0) + quantity * numQueued
		end
	end

	for itemString, numNeed in pairs(updateTemp.matsNumNeed) do
		updateTemp.matsNumHave[itemString] = private.GetCrafterInventoryQuantity(itemString)
		local numUsed = nil
		numNeed, numUsed = private.HandleNumHave(itemString, numNeed, updateTemp.matsNumHave[itemString])
		if numUsed < updateTemp.matsNumHave[itemString] then
			updateTemp.matsNumHaveExtra[itemString] = updateTemp.matsNumHave[itemString] - numUsed
		end
		if numNeed > 0 then
			updateTemp.matsNumNeed[itemString] = numNeed
			tinsert(updateTemp.matQueue, itemString)
		else
			updateTemp.matsNumNeed[itemString] = nil
		end
	end

	while #updateTemp.matQueue > 0 do
		local itemString = tremove(updateTemp.matQueue)
		wipe(updateTemp.sourceList)
		local numNeed = updateTemp.matsNumNeed[itemString]
		-- always add a task to get mail on the crafter if possible
		numNeed = private.ProcessSource(itemString, numNeed, "openMail", updateTemp.sourceList)
		assert(numNeed >= 0)
		for _, source in ipairs(private.settings.sources) do
			local isCraftSource = source == "craftProfit" or source == "craftNoProfit"
			local ignoreSource = false
			if isCraftSource then
				-- check if we are already crafting some materials of this craft so shouldn't craft this item
				local craftString = Crafting.GetMostProfitableCraftStringByItem(itemString, crafter, true)
				if craftString then
					for _, matItemString in Crafting.MatIterator(craftString) do
						if not ignoreSource and updateTemp.matSourceList[matItemString] and strmatch(updateTemp.matSourceList[matItemString], "craft[a-zA-Z]+/[^,]+/") then
							ignoreSource = true
						end
					end
				else
					-- can't craft this item
					ignoreSource = true
				end
			end
			if not ignoreSource then
				local prevNumNeed = numNeed
				numNeed = private.ProcessSource(itemString, numNeed, source, updateTemp.sourceList)
				assert(numNeed >= 0)
				if numNeed == 0 then
					if isCraftSource then
						-- we are crafting these, so add the necessary mats
						local craftString = Crafting.GetMostProfitableCraftStringByItem(itemString, crafter, true)
						assert(craftString)
						local numToCraft = ceil(prevNumNeed / Crafting.GetNumResult(craftString))
						for _, intMatItemString, intMatQuantity in Crafting.MatIterator(craftString) do
							local intMatNumNeed, numUsed = private.HandleNumHave(intMatItemString, numToCraft * intMatQuantity, updateTemp.matsNumHaveExtra[intMatItemString] or 0)
							if numUsed > 0 then
								updateTemp.matsNumHaveExtra[intMatItemString] = updateTemp.matsNumHaveExtra[intMatItemString] - numUsed
							end
							if intMatNumNeed > 0 then
								if not updateTemp.matsNumNeed[intMatItemString] then
									local intMatNumHave = private.GetCrafterInventoryQuantity(intMatItemString)
									if intMatNumNeed > intMatNumHave then
										updateTemp.matsNumHave[intMatItemString] = intMatNumHave
										updateTemp.matsNumNeed[intMatItemString] = intMatNumNeed - intMatNumHave
										tinsert(updateTemp.matQueue, intMatItemString)
									elseif intMatNumHave > intMatNumNeed then
										updateTemp.matsNumHaveExtra[intMatItemString] = intMatNumHave - intMatNumNeed
									end
								else
									updateTemp.matsNumNeed[intMatItemString] = (updateTemp.matsNumNeed[intMatItemString] or 0) + intMatNumNeed
									if updateTemp.matSourceList[intMatItemString] then
										-- already processed this item, so queue it again
										tinsert(updateTemp.matQueue, intMatItemString)
									end
								end
							end
						end
					end
					break
				end
			end
		end
		sort(updateTemp.sourceList)
		updateTemp.matSourceList[itemString] = table.concat(updateTemp.sourceList, ",")
	end
	private.db:TruncateAndBulkInsertStart()
	for itemString, numNeed in pairs(updateTemp.matsNumNeed) do
		private.db:BulkInsertNewRow(itemString, numNeed, updateTemp.matsNumHave[itemString], updateTemp.matSourceList[itemString])
	end
	private.db:BulkInsertEnd()

	for _, tbl in pairs(updateTemp) do
		Table.WipeAndDeallocate(tbl)
	end
end

function private.ProcessSource(itemString, numNeed, source, sourceList)
	local crafter = private.settings.crafter
	if source == "openMail" then
		local crafterMailQuantity = AltTracking.GetMailQuantity(itemString, crafter)
		if crafterMailQuantity > 0 then
			crafterMailQuantity = min(crafterMailQuantity, numNeed)
			if crafter == SessionInfo.GetCharacterName() then
				tinsert(sourceList, "openMail/"..crafterMailQuantity.."/")
			else
				tinsert(sourceList, "alt/"..crafterMailQuantity.."/"..crafter)
			end
			return numNeed - crafterMailQuantity
		end
	elseif source == "bank" then
		local bankQuantity = BagTracking.GetBankQuantity(itemString)
		if bankQuantity > 0 then
			bankQuantity = min(numNeed, bankQuantity)
			tinsert(sourceList, "bank/"..bankQuantity.."/")
			return 0
		end
	elseif source == "vendor" then
		if VendorBuy.Get(itemString) then
			-- assume we can buy all we need from the vendor
			tinsert(sourceList, "vendor/"..numNeed.."/")
			return 0
		end
	elseif source == "guildBank" then
		local guild = PlayerInfo.GetPlayerGuild(crafter, SessionInfo.GetFactionrealmName())
		local guildBankQuantity = guild and AltTracking.GetGuildQuantity(itemString, guild) or 0
		if guildBankQuantity > 0 then
			guildBankQuantity = min(guildBankQuantity, numNeed)
			if crafter == SessionInfo.GetCharacterName() then
				-- we are on the crafter
				tinsert(sourceList, "guildBank/"..guildBankQuantity.."/")
			else
				-- need to switch to the crafter to get items from the guild bank
				tinsert(sourceList, "altGuildBank/"..guildBankQuantity.."/"..crafter)
			end
			return numNeed - guildBankQuantity
		end
	elseif source == "alt" then
		if ItemInfo.IsSoulbound(itemString) then
			-- can't mail soulbound items
			return numNeed
		end
		if crafter ~= SessionInfo.GetCharacterName() then
			-- we are on the alt, so see if we can gather items from this character
			local bagQuantity, bankQuantity = BagTracking.GetQuantities(itemString)
			local mailQuantity = Mail.GetQuantity(itemString)

			if bagQuantity > 0 then
				bagQuantity = min(numNeed, bagQuantity)
				tinsert(sourceList, "sendMail/"..bagQuantity.."/")
				numNeed = numNeed - bagQuantity
				if numNeed == 0 then
					return 0
				end
			end
			if mailQuantity > 0 then
				mailQuantity = min(numNeed, mailQuantity)
				tinsert(sourceList, "openMail/"..mailQuantity.."/")
				numNeed = numNeed - mailQuantity
				if numNeed == 0 then
					return 0
				end
			end
			if bankQuantity > 0 then
				bankQuantity = min(numNeed, bankQuantity)
				tinsert(sourceList, "bank/"..bankQuantity.."/")
				numNeed = numNeed - bankQuantity
				if numNeed == 0 then
					return 0
				end
			end
		end

		-- check alts
		local altNum = 0
		assert(not next(private.altsTemp))
		for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
			for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm) do
				local characterKey = nil
				if factionrealm == SessionInfo.GetFactionrealmName() then
					characterKey = character
				else
					characterKey = character.." - "..factionrealm
				end
				if characterKey ~= crafter and characterKey ~= SessionInfo.GetCharacterName() then
					local num = 0
					num = num + AltTracking.GetBagQuantity(itemString, character, factionrealm)
					num = num + AltTracking.GetBankQuantity(itemString, character, factionrealm)
					num = num + AltTracking.GetMailQuantity(itemString, character, factionrealm)
					if num > 0 then
						tinsert(private.altsTemp, characterKey)
						altNum = altNum + num
					end
				end
			end
		end

		local altCharactersStr = table.concat(private.altsTemp, "`")
		wipe(private.altsTemp)
		if altNum > 0 then
			altNum = min(altNum, numNeed)
			tinsert(sourceList, "alt/"..altNum.."/"..altCharactersStr)
			return numNeed - altNum
		end
	elseif source == "altGuildBank" then
		local currentGuild = PlayerInfo.GetPlayerGuild(SessionInfo.GetCharacterName(), SessionInfo.GetFactionrealmName())
		if currentGuild and crafter ~= SessionInfo.GetCharacterName() then
			-- we are on an alt, so see if we can gather items from this character's guild bank
			local guildBankQuantity = Guild.GetQuantity(itemString)
			if guildBankQuantity > 0 then
				guildBankQuantity = min(numNeed, guildBankQuantity)
				tinsert(sourceList, "guildBank/"..guildBankQuantity.."/")
				numNeed = numNeed - guildBankQuantity
				if numNeed == 0 then
					return 0
				end
			end
		end

		-- check alts
		local totalGuildBankQuantity = 0
		assert(not next(private.altsTemp))
		for _, character, factionrealm in PlayerInfo.CharacterIterator(true) do
			local guild = PlayerInfo.GetPlayerGuild(character, factionrealm)
			if guild and guild ~= currentGuild then
				local guildBankQuantity = AltTracking.GetGuildQuantity(itemString, guild)
				if guildBankQuantity > 0 then
					local characterKey = nil
					if factionrealm == SessionInfo.GetFactionrealmName() then
						characterKey = character
					else
						characterKey = character.." - "..factionrealm
					end
					tinsert(private.altsTemp, characterKey)
					totalGuildBankQuantity = totalGuildBankQuantity + guildBankQuantity
				end
			end
		end
		local altCharactersStr = table.concat(private.altsTemp, "`")
		wipe(private.altsTemp)
		if totalGuildBankQuantity > 0 then
			totalGuildBankQuantity = min(totalGuildBankQuantity, numNeed)
			tinsert(sourceList, "altGuildBank/"..totalGuildBankQuantity.."/"..altCharactersStr)
			return numNeed - totalGuildBankQuantity
		end
	elseif source == "craftProfit" or source == "craftNoProfit" then
		local craftString, maxProfit, lowestCraftingCost = Crafting.GetMostProfitableCraftStringByItem(itemString, crafter, true)
		if craftString and (source == "craftNoProfit" or (maxProfit and maxProfit > 0) or (not maxProfit and ItemInfo.IsSoulbound(itemString) and lowestCraftingCost)) then
			-- assume we can craft all we need
			tinsert(sourceList, source.."/"..numNeed.."/")
			return 0
		end
	elseif source == "auction" then
		if ItemInfo.IsSoulbound(itemString) then
			-- can't buy soulbound items
			return numNeed
		end
		-- assume we can buy all we need from the AH
		tinsert(sourceList, "auction/"..numNeed.."/")
		return 0
	elseif source == "auctionCrafting" then
		if ItemInfo.IsSoulbound(itemString) then
			-- can't buy soulbound items
			return numNeed
		end
		if not Conversion.GetSourceItems(itemString) then
			-- can't convert to get this item
			return numNeed
		end
		-- assume we can buy all we need from the AH
		tinsert(sourceList, "auctionCrafting/"..numNeed.."/")
		return 0
	elseif source == "auctionDE" then
		if ItemInfo.IsSoulbound(itemString) then
			-- can't buy soulbound items
			return numNeed
		end
		if not Conversion.IsDisenchantTargetItem(itemString) then
			-- can't disenchant to get this item
			return numNeed
		end
		-- assume we can buy all we need from the AH
		tinsert(sourceList, "auctionDE/"..numNeed.."/")
		return 0
	else
		error("Unknown source: "..tostring(source))
	end
	return numNeed
end

function private.GetCrafterInventoryQuantity(itemString)
	local crafter = private.settings.crafter
	local quantity = AltTracking.GetBagQuantity(itemString, crafter)
	if LibTSMApp.IsRetail() then
		quantity = quantity + AltTracking.GetBankQuantity(itemString, crafter)
		quantity = quantity + WarbankTracking.GetQuantity(itemString)
	end
	return quantity
end

function private.HandleNumHave(itemString, numNeed, numHave)
	if numNeed > numHave then
		-- use everything we have
		numNeed = numNeed - numHave
		return numNeed, numHave
	else
		-- we have at least as many as we need, so use all of them
		return 0, numNeed
	end
end

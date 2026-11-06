-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatString = App:From("LibTSMTypes"):Include("Crafting.MatString")
local Group = App:From("LibTSMTypes"):Include("Group")
local GroupOperation = App:From("LibTSMTypes"):Include("GroupOperation")
local Item = App:From("LibTSMWoW"):Include("API.Item")
local TradeSkill = App:From("LibTSMWoW"):Include("API.TradeSkill")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = App:From("LibTSMService"):Include("Profession")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {
	updateTemp = {
		currentCategoryPath = {},
		insertedSpellId = {},
		newCategoryPath = {},
	},
	handledMatStringTemp = {},
}
local FAVORITE_CATEGORY_ID = -1
local INDENT_WIDTH = 8
local ICON_SPACING = 4
local EXPANDER_TEXTURE_EXPANDED = "iconPack.12x12/Caret/Down"
local EXPANDER_TEXTURE_COLLAPSED = "iconPack.12x12/Caret/Right"
local FAVORITE_TEXTURE_ACTIVE = "iconPack.12x12/Star/Filled"
local FAVORITE_TEXTURE_INACTIVE = "iconPack.12x12/Star/Unfilled"
local COL_INFO = {
	name = {
		title = L["Recipe Name"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		disableHiding = true,
		disableReordering = true,
	},
	qty = {
		title = L["Craft"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
	craftingCost = {
		title = L["Crafting Cost"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
	itemValue = {
		title = L["Item Value"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
	profit = {
		title = L["Profit"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
	profitPct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
	},
	saleRate = {
		titleIcon = "iconPack.18x18/SaleRate",
		justifyH = "CENTER",
		font = "TABLE_XSMALL",
	},
}

---@alias ProfessionScrollTableFavoritesContextTable table<number,true?>
---@class ProfessionScrollTable.SettingsValue: ScrollTable.SettingsValue
---@field collapsed table<number,boolean?>



-- ============================================================================
-- Element Definition
-- ============================================================================

local ProfessionScrollTable = UIElements.Define("ProfessionScrollTable", "ScrollTable")
ProfessionScrollTable:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ProfessionScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil ---@type DatabaseQuery!
	self._favoritesContextTable = nil ---@type ProfessionScrollTableFavoritesContextTable!
	self._rawData = {}
	self._isCraftString = {}
	self._selectedCraftString = nil
	self._currentFilters = {
		name = nil,
		haveSkillUp = nil,
		isCraftable = nil,
	}
	self._costsCache = {
		updateTime = 0,
		isCached = {},
		craftingCost = {},
		itemValue = {},
		profit = {},
		saleRate = {},
	}
end

function ProfessionScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
end

function ProfessionScrollTable:Release()
	local query = self._query
	self._query = nil
	self._favoritesContextTable = nil
	wipe(self._rawData)
	wipe(self._isCraftString)
	self._selectedCraftString = nil
	wipe(self._currentFilters)
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the settings view and key.
---@param settings SettingsView The settings object
---@param key string The settings key
---@param favorites ProfessionScrollTableFavoritesContextTable Table to store favorite craft information
---@return self
function ProfessionScrollTable:SetSettings(settings, key, favorites)
	assert(type(favorites) == "table")
	self.__super:SetSettings(settings, key)
	self._favoritesContextTable = favorites
	return self
end

---Sets whether or not the query should be loaded.
---@param loaded boolean Whether or not the query should be loaded
---@return self
function ProfessionScrollTable:SetQueryLoaded(loaded)
	assert(self._settings)
	wipe(self._currentFilters)
	if loaded then
		self._query = self._query or Profession.CreateScannerQuery()
			:OrderBy("index", true)
			:VirtualField("matNames", "string", Crafting.GetMatNames, "craftString")
			:Equal("level", 1)
			:SetUpdateCallback(self:__closure("_HandleQueryUpdate"))
		self:_HandleQueryUpdate()
	else
		if self._query then
			self._query:Release()
			self._query = nil
		end
		self:_SetNumRows(0)
		self:Draw()
		self:SetSelectedCraft(nil)
	end
	return self
end

---Sets the filters.
---@param name? string Recipe name filter
---@param haveSkillUp? boolean Only recipes with skill ups
---@param isCraftable? boolean Only craftable recipes
function ProfessionScrollTable:SetFilters(name, haveSkillUp, isCraftable)
	if not self._query then
		wipe(self._currentFilters)
		return
	end
	haveSkillUp = haveSkillUp or nil
	isCraftable = isCraftable or nil
	if self._currentFilters.name == name and self._currentFilters.haveSkillUp == haveSkillUp and self._currentFilters.isCraftable == isCraftable then
		return
	end
	self._query:ResetFilters()
		:Equal("level", 1)
	if name then
		self._query
			:Or()
				:Matches("name", name)
				:Matches("matNames", name)
			:End()
	end
	if haveSkillUp then
		self._query:NotEqual("difficulty", TradeSkill.RECIPE_DIFFICULTY.TRIVIAL)
	end
	if isCraftable then
		self._query:Function("craftString", Profession.HasMaterials)
	end
	self._currentFilters.name = name
	self._currentFilters.haveSkillUp = haveSkillUp
	self._currentFilters.isCraftable = isCraftable
	self:_HandleQueryUpdate()
end

---Sets the selected craft.
---@param craftString? string The craft string of the recipe to select
---@return self
function ProfessionScrollTable:SetSelectedCraft(craftString)
	local dataIndex = craftString and Table.KeyByValue(self._rawData, craftString) or nil
	if craftString and not dataIndex then
		return self
	end
	local prevDataIndex = self._selectedCraftString and Table.KeyByValue(self._rawData, self._selectedCraftString) or nil
	if craftString == self._selectedCraftString and (not craftString or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return self
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		self:_SetRowSelected(prevRow, false)
	end
	if dataIndex then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			self:_SetRowSelected(newRow, true)
		end
		self._selectedCraftString = self._rawData[dataIndex]
		self:_ScrollToRow(dataIndex)
	else
		self._selectedCraftString = nil
	end

	self:_SendActionScript("OnSelectionChanged")
	return self
end

---Gets the selected craft.
---@return string?
function ProfessionScrollTable:GetSelectedCraft()
	return self._selectedCraftString
end

---Forces a refresh of the scroll table data.
function ProfessionScrollTable:UpdateData()
	if #self._data.name == 0 then
		return
	end
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ProfessionScrollTable.__protected:_GetSettingsValue()
	return self.__super:_GetSettingsValue() --[[@as ProfessionScrollTable.SettingsValue]]
end

function ProfessionScrollTable.__protected:_IsValidSettingsKey(key)
	return self.__super:_IsValidSettingsKey(key) or key == "collapsed"
end

function ProfessionScrollTable.__private:_HandleQueryUpdate()
	wipe(self._rawData)
	wipe(self._isCraftString)

	local updateTemp = private.updateTemp
	for _, tbl in pairs(updateTemp) do
		assert(not next(tbl))
	end
	for _, craftString in self._query:Iterator("craftString") do
		local spellId = CraftString.GetSpellId(craftString)
		local isInserted, lowerLevelIndex = self:_IsCraftStringInserted(craftString, updateTemp.insertedSpellId)
		if self._favoritesContextTable[spellId] and (not isInserted or lowerLevelIndex) then
			if lowerLevelIndex then
				tremove(self._rawData, lowerLevelIndex)
				updateTemp.insertedSpellId[spellId] = nil
			end
			local categoryId = FAVORITE_CATEGORY_ID
			if categoryId ~= updateTemp.currentCategoryPath[#updateTemp.currentCategoryPath] then
				-- This is a new category, so create new category headers
				if updateTemp.currentCategoryPath[1] ~= categoryId then
					if not self:_IsCategoryHidden(categoryId) then
						tinsert(self._rawData, categoryId)
					end
				end
				wipe(updateTemp.currentCategoryPath)
				tinsert(updateTemp.currentCategoryPath, categoryId)
			end
			if not self:_GetSettingsValue().collapsed[categoryId] and not self:_IsCategoryHidden(categoryId) then
				tinsert(self._rawData, craftString)
				self._isCraftString[craftString] = true
				updateTemp.insertedSpellId[spellId] = #self._rawData
			end
		end
	end
	for _, craftString, categoryId in self._query:Iterator("craftString", "categoryId") do
		local spellId = CraftString.GetSpellId(craftString)
		local isInserted, lowerLevelIndex = self:_IsCraftStringInserted(craftString, updateTemp.insertedSpellId)
		if not self._favoritesContextTable[spellId] and (not isInserted or lowerLevelIndex) then
			if lowerLevelIndex then
				tremove(self._rawData, lowerLevelIndex)
				updateTemp.insertedSpellId[spellId] = nil
			end
			if categoryId ~= updateTemp.currentCategoryPath[#updateTemp.currentCategoryPath] then
				-- This is a new category
				assert(not next(updateTemp.newCategoryPath))
				local currentCategoryId = categoryId
				while currentCategoryId do
					tinsert(updateTemp.newCategoryPath, 1, currentCategoryId)
					currentCategoryId = Profession.GetParentCategoryId(currentCategoryId)
				end
				-- Create new category headers
				for i = 1, #updateTemp.newCategoryPath do
					local newCategoryId = updateTemp.newCategoryPath[i]
					if updateTemp.currentCategoryPath[i] ~= newCategoryId then
						if not self:_IsCategoryHidden(newCategoryId) and Profession.GetCategoryName(newCategoryId) then
							tinsert(self._rawData, newCategoryId)
						end
					end
				end
				wipe(updateTemp.currentCategoryPath)
				for _, category in ipairs(updateTemp.newCategoryPath) do
					tinsert(updateTemp.currentCategoryPath, category)
				end
				wipe(updateTemp.newCategoryPath)
			end
			if not self:_GetSettingsValue().collapsed[categoryId] and not self:_IsCategoryHidden(categoryId) then
				tinsert(self._rawData, craftString)
				self._isCraftString[craftString] = true
				updateTemp.insertedSpellId[spellId] = #self._rawData
			end
		end
	end
	for _, tbl in pairs(updateTemp) do
		Table.WipeAndDeallocate(tbl)
	end

	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	local firstCraftString, hasExistingSelection = nil, false
	for _, data in ipairs(self._rawData) do
		if self._isCraftString[data] then
			firstCraftString = firstCraftString or data
			hasExistingSelection = hasExistingSelection or data == self._selectedCraftString
			local name = Profession.GetNameByCraftString(data)
			assert(name)
			local nameColor = nil
			local tradeSkillType = TradeSkill.GetType()
			if tradeSkillType == TradeSkill.TYPE.GUILD then
				nameColor = Theme.GetProfessionDifficultyColor(TradeSkill.RECIPE_DIFFICULTY.EASY)
			elseif tradeSkillType == TradeSkill.TYPE.NPC then
				nameColor = Theme.GetProfessionDifficultyColor("nodifficulty")
			else
				nameColor = Theme.GetProfessionDifficultyColor(Profession.GetDifficultyByCraftString(data) --[[@as EnumValue]])
			end
			tinsert(self._data.name, nameColor:ColorText(name))
			tinsert(self._data.qty, self.DEFERRED_DATA)
			tinsert(self._data.craftingCost, self.DEFERRED_DATA)
			tinsert(self._data.itemValue, self.DEFERRED_DATA)
			tinsert(self._data.profit, self.DEFERRED_DATA)
			tinsert(self._data.profitPct, self.DEFERRED_DATA)
			tinsert(self._data.saleRate, self.DEFERRED_DATA)
		else
			if data == FAVORITE_CATEGORY_ID then
				tinsert(self._data.name, L["Favorited Patterns"])
			else
				local currentSkillLevel, maxSkillLevel = Profession.GetCategorySkillLevel(data)
				local name = Profession.GetCategoryName(data)
				if name and currentSkillLevel and maxSkillLevel then
					name = name.." ("..currentSkillLevel.."/"..maxSkillLevel..")"
				end
				if name then
					local isTopLevel = data == FAVORITE_CATEGORY_ID or Profession.GetCategoryNumIndents(data) == 0
					tinsert(self._data.name, Theme.GetColor(isTopLevel and "accent/main" or "on/surface"):ColorText(name))
				else
					-- This happens if we're switching to another profession
					tinsert(self._data.name, "?")
				end
			end
			tinsert(self._data.qty, "")
			tinsert(self._data.craftingCost, "")
			tinsert(self._data.itemValue, "")
			tinsert(self._data.profit, "")
			tinsert(self._data.profitPct, "")
			tinsert(self._data.saleRate, "")
		end
	end

	self:_SetNumRows(#self._rawData)
	self:Draw()

	-- Update the selection if necessary
	if not hasExistingSelection then
		self:SetSelectedCraft(firstCraftString)
	end
end

function ProfessionScrollTable.__private:_IsCraftStringInserted(craftString, insertedSpellId)
	local spellId = CraftString.GetSpellId(craftString)
	local prevIndex = insertedSpellId[spellId]
	local prevCraftString = prevIndex and self._rawData[prevIndex]
	if not prevCraftString then
		return false
	end
	local level = CraftString.GetLevel(craftString)
	if not level then
		return true
	end
	local isHigherLevel = level > (CraftString.GetLevel(prevCraftString) or -1)
	return true, isHigherLevel and prevIndex or nil
end

function ProfessionScrollTable.__private:_IsCategoryHidden(categoryId)
	if categoryId == FAVORITE_CATEGORY_ID then
		return false
	end
	local parent = Profession.GetParentCategoryId(categoryId)
	while parent do
		if self:_GetSettingsValue().collapsed[parent] then
			return true
		end
		parent = Profession.GetParentCategoryId(parent)
	end
	return false
end

function ProfessionScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local data = self._rawData[dataIndex]
	-- TODO: Support optional materials here
	local num, numAll = Profession.GetNumCraftable(data)
	assert(num)
	local qty = nil
	if num == numAll then
		qty = num > 0 and Theme.GetColor("positive/main"):ColorText(num) or num
	elseif num > 0 then
		qty = Theme.GetColor("positive/main"):ColorText(num.."-"..numAll)
	elseif numAll > 0 then
		qty = Theme.GetColor("warning/main"):ColorText(num.."-"..numAll)
	else
		qty = num.."-"..numAll
	end
	self._data.qty[dataIndex] = qty
	local craftingCost, itemValue, profit, saleRate = self:_GetCosts(data)
	self._data.craftingCost[dataIndex] = craftingCost and Money.ToStringForUI(craftingCost, nil) or ""
	self._data.itemValue[dataIndex] =  itemValue and Money.ToStringForUI(itemValue) or ""
	local profitColor = profit and Theme.GetColor(profit >= 0 and "positive/main" or "error/main")
	self._data.profit[dataIndex] =  profit and Money.ToStringForUI(profit, profitColor:GetTextColorPrefix()) or ""
	self._data.profitPct[dataIndex] =  profit and profitColor:ColorText(floor(profit * 100 / craftingCost).."%") or ""
	self._data.saleRate[dataIndex] =  saleRate and gsub(format("%.3f", saleRate), "0%.", ".") or ""
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	local name = row:GetText("name")
	local expander = row:AddTexture("expander")
	expander:TSMSetSize(EXPANDER_TEXTURE_EXPANDED)
	expander:SetPoint("RIGHT", name, "LEFT", -ICON_SPACING, 0)
	local favorite = row:AddTexture("favorite")
	favorite:TSMSetSize(FAVORITE_TEXTURE_ACTIVE)
	favorite:SetPoint("RIGHT", name, "LEFT", -ICON_SPACING, 0)
	favorite:Hide()
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowDraw(row)
	self.__super:_HandleRowDraw(row)
	local data = self._rawData[row:GetDataIndex()]

	local indentLevel = 0
	if self._isCraftString[data] then
		indentLevel = 2
	elseif data ~= FAVORITE_CATEGORY_ID then
		indentLevel = Profession.GetCategoryNumIndents(data) * 2
	end

	local colSpacing = Theme.GetColSpacing()
	local text = row:GetText("name")
	text:SetWidth(text:GetWidth() - indentLevel * INDENT_WIDTH)
	text:SetPoint("LEFT", self._header.moreButton:GetWidth() + colSpacing * 1.5 + indentLevel * INDENT_WIDTH, 0)
	row:GetTexture("actionIcon"):SetPoint("LEFT", colSpacing / 2, 0)

	local expander = row:GetTexture("expander")
	if self._isCraftString[data] then
		expander:Hide()
	else
		expander:Show()
		expander:TSMSetTexture(self:_GetSettingsValue().collapsed[data] and EXPANDER_TEXTURE_COLLAPSED or EXPANDER_TEXTURE_EXPANDED)
	end

	local favorite = row:GetTexture("favorite")
	if self._isCraftString[data] then
		favorite:TSMSetTexture(self._favoritesContextTable[CraftString.GetSpellId(data)] and FAVORITE_TEXTURE_ACTIVE or FAVORITE_TEXTURE_INACTIVE)
	else
		favorite:Hide()
	end
	self:_SetRowSelected(row, data == self._selectedCraftString)
end

---@param row ListRow
function ProfessionScrollTable.__private:_SetRowSelected(row, selected)
	local data = self._rawData[row:GetDataIndex()]
	if self._isCraftString[data] then
		local favorite = row:GetTexture("favorite")
		if TradeSkill.GetType() == TradeSkill.TYPE.PLAYER and selected then
			favorite:Show()
		elseif not row:IsHovering() then
			favorite:Hide()
		end
	end
	row:SetSelected(selected)
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowEnter(row)
	local data = self._rawData[row:GetDataIndex()]
	if not self._isCraftString[data] or TradeSkill.GetType() ~= TradeSkill.TYPE.PLAYER then
		return
	end
	row:GetTexture("favorite"):Show()
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowLeave(row)
	local data = self._rawData[row:GetDataIndex()]
	if data ~= self._selectedCraftString then
		row:GetTexture("favorite"):Hide()
	end
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local data = self._rawData[row:GetDataIndex()]
	if self._isCraftString[data] then
		if mouseButton ~= "LeftButton" then
			return
		end
		local favorite = row:GetTexture("favorite")
		if favorite:IsVisible() and favorite:IsMouseOver() then
			local spellId = CraftString.GetSpellId(data)
			self._favoritesContextTable[spellId] = not self._favoritesContextTable[spellId] or nil
			favorite:TSMSetTexture(self._favoritesContextTable[spellId] and FAVORITE_TEXTURE_ACTIVE or FAVORITE_TEXTURE_INACTIVE)
			self:_HandleQueryUpdate()
		elseif IsShiftKeyDown() then
			Profession.LinkRecipe(data)
		else
			self:SetSelectedCraft(data)
		end
	else
		local collapsedSettings = self:_GetSettingsValue().collapsed
		collapsedSettings[data] = not collapsedSettings[data] or nil
		self:_HandleQueryUpdate()
	end
end

function ProfessionScrollTable.__protected:_PopulateMoreDialog(menuDialog)
	self.__super:_PopulateMoreDialog(menuDialog)
	menuDialog:AddRow("CREATE_GROUPS", "", L["Create Profession Groups"])
end

function ProfessionScrollTable.__protected:_HandleMoreDialogClick(menuDialog, id1, id2, extra)
	if id1 == "CREATE_GROUPS" then
		assert(not id2)
		self:GetBaseElement():HideDialog()
		self:_CreateGroups()
	else
		self.__super:_HandleMoreDialogClick(menuDialog, id1, id2, extra)
	end
end

function ProfessionScrollTable.__private:_CreateGroups()
	local profName = Profession.GetCurrentProfession()
	if not profName then
		ChatMessage.PrintUser(L["There is currently no profession open, so cannot create profession groups."])
		return
	end
	if not Group.Exists(profName) then
		GroupOperation.CreateGroup(profName)
	end
	local itemsGroupPath = Group.JoinPath(profName, L["Items"])
	if not Group.Exists(itemsGroupPath) then
		GroupOperation.CreateGroup(itemsGroupPath)
	end
	local matsGroupPath = Group.JoinPath(profName, L["Materials"])
	if not Group.Exists(matsGroupPath) then
		GroupOperation.CreateGroup(matsGroupPath)
	end

	local numMats, numItems = 0, 0
	assert(not next(private.handledMatStringTemp))
	-- TODO: Use self._query instead
	local query = Profession.CreateScannerQuery()
		:AutoRelease()
	for _, craftString in query:Iterator("craftString") do
		local itemString = Profession.GetItemStringByCraftString(craftString)
		if itemString and not Group.IsItemInGroup(itemString) and not ItemInfo.IsSoulbound(itemString) then
			Group.SetItemGroup(itemString, itemsGroupPath)
			numItems = numItems + 1
		end
		for _, matString in Profession.MatIterator(craftString) do
			if not private.handledMatStringTemp[matString] then
				private.handledMatStringTemp[matString] = true
				local matType = MatString.GetType(matString)
				if matType == MatString.TYPE.NORMAL or matType == MatString.TYPE.QUALITY then
					for matItemString in MatString.ItemIterator(matString) do
						local classId = ItemInfo.GetClassId(matItemString)
						assert(classId)
						if not Group.IsItemInGroup(matItemString) and not ItemInfo.IsSoulbound(matItemString) and not Item.VariationImpactsQualityByClass(classId) then
							Group.SetItemGroup(matItemString, matsGroupPath)
							numMats = numMats + 1
						end
					end
				end
			end
		end
	end
	Table.WipeAndDeallocate(private.handledMatStringTemp)

	if numMats > 0 or numItems > 0 then
		ChatMessage.PrintfUser(L["%s group updated with %d items and %d materials."], profName, numItems, numMats)
	else
		ChatMessage.PrintfUser(L["%s group is already up to date."], profName)
	end
end

function ProfessionScrollTable.__private:_GetCosts(craftString)
	if App.GetTime() - self._costsCache.updateTime > 0.5 then
		wipe(self._costsCache.isCached)
		wipe(self._costsCache.craftingCost)
		wipe(self._costsCache.itemValue)
		wipe(self._costsCache.profit)
		wipe(self._costsCache.saleRate)
		self._costsCache.updateTime = App.GetTime()
	end
	if not self._costsCache.isCached[craftString] then
		local craftingCost, itemValue, profit = Crafting.GetCostsByCraftString(craftString)
		self._costsCache.isCached[craftString] = true
		self._costsCache.craftingCost[craftString] = craftingCost
		self._costsCache.itemValue[craftString] = itemValue
		self._costsCache.profit[craftString] = profit
		self._costsCache.saleRate[craftString] = Crafting.GetSaleRateByCraftString(craftString)
	end
	return self._costsCache.craftingCost[craftString], self._costsCache.itemValue[craftString], self._costsCache.profit[craftString], self._costsCache.saleRate[craftString]
end

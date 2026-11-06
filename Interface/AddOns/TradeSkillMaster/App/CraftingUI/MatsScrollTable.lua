-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}
local COL_INFO = {
	name = {
		title = NAME,
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	price = {
		title = L["Material Cost"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "matCost",
	},
	professions = {
		title = L["Professions Used In"],
		justifyH = "LEFT",
		sortField = "professionsStr",
	},
	num = {
		title = L["Number Owned"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "totalQuantity",
	},
}
local PROFESSION_SEP = ","



-- ============================================================================
-- Element Definition
-- ============================================================================

local MatsScrollTable = UIElements.Define("MatsScrollTable", "ScrollTable")
MatsScrollTable:_AddActionScripts("OnRowClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MatsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "name_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function MatsScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the settings view and key.
---@param settings SettingsView The settings object
---@param key string The settings key
---@return self
function MatsScrollTable:SetSettings(settings, key)
	assert(not self._settings and not self._query)
	self.__super:SetSettings(settings, key)
	-- Set up the query now that we have the settings set
	self._query = Crafting.CreateMatItemQuery()
		:VirtualField("professionsStr", "string", private.ProfessionsString, "professions")
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:AddCancellable(self._query:Publisher()
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Sets the filters.
---@param name? string Item name filter
---@param profession? string Profession filter
---@param hasCustomValue? boolean Whether or not there is a custom value set
function MatsScrollTable:SetFilters(name, profession, hasCustomValue)
	self._query:ResetFilters()
	if name then
		self._query:Matches("name", name)
	end
	if profession then
		self._query:ListContains("professions", profession)
	end
	if hasCustomValue == true then
		self._query:NotEqual("customValue", "")
	elseif hasCustomValue == false then
		self._query:Equal("customValue", "")
	end
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MatsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, itemString, name, professions, totalQuantity in self._query:Iterator("itemString", "name", "professionsStr", "totalQuantity") do
		tinsert(self._data.name, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or name))
		tinsert(self._data.name_tooltip, itemString)
		tinsert(self._data.price, self.DEFERRED_DATA)
		tinsert(self._data.professions, professions)
		tinsert(self._data.num, totalQuantity or "0")
		self._createGroupsData[itemString] = L["Materials"]
	end
	self:_SetNumRows(#self._data.name)
	self:Draw()
end

function MatsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local matCost = self._query:GetNthResult(dataIndex, "matCost")
	self._data.price[dataIndex] = Math.IsNan(matCost) and "" or Money.ToStringForUI(matCost)
end

---@param row ListRow
function MatsScrollTable.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	local itemString = self._query:GetNthResult(dataIndex, "itemString")
	self:_SendActionScript("OnRowClick", itemString)
end

function MatsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param professionsIter IteratorObject
function private.ProfessionsString(professionsIter)
	return professionsIter:ToJoinedValueString(PROFESSION_SEP)
end

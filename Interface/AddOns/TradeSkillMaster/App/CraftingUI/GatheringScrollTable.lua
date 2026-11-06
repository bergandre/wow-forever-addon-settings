-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local COL_INFO = {
	name = {
		title = NAME,
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	sources = {
		title = L["Sources"],
		justifyH = "LEFT",
		sortField = "sourcesStr",
	},
	have = {
		title = L["Have"],
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "numHave",
	},
	need = {
		title = NEED,
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "numNeed",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local GatheringScrollTable = UIElements.Define("GatheringScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GatheringScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "name_tooltip"
	self._query = nil ---@type DatabaseQuery!
end

function GatheringScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function GatheringScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query
		:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_DrawSortFlag()
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function GatheringScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, itemString, name, sourcesDisplayStr, numHave, numNeed in self._query:Iterator("itemString", "name", "sourcesDisplayStr", "numHave", "numNeed") do
		tinsert(self._data.name, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or name))
		tinsert(self._data.name_tooltip, itemString)
		tinsert(self._data.sources, sourcesDisplayStr)
		tinsert(self._data.have, numHave)
		tinsert(self._data.need, numNeed)
	end
	self:_SetNumRows(#self._data.name)
	self:Draw()
end

function GatheringScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	self._query:ResetOrderBy()
		:OrderBy(self:_GetSortFieldInfo())
	self:_HandleQueryUpdate()
end

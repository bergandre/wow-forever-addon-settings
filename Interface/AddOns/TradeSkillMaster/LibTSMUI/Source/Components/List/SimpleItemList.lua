-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SimpleItemList = ComponentRegistry.Define("SimpleItemList", "List")
SimpleItemList:_AddActionScripts("OnItemClick")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SimpleItemList:__init()
	self.__super:__init()
	self._query = nil ---@type DatabaseQuery!
	self._text = {}
	self._itemString = {}
end

function SimpleItemList:Release()
	local query = self._query
	self._query = nil
	wipe(self._text)
	wipe(self._itemString)
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the list.
---@param query DatabaseQuery The query object
---@return self
function SimpleItemList:SetQuery(query)
	if self._query then
		self._query:Release()
	end
	self._query = query
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SimpleItemList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._text)
	wipe(self._itemString)
	for _, itemString in self._query:Iterator("itemString") do
		tinsert(self._text, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._itemString, itemString)
	end
	self:_SetNumRows(#self._text)
	self:Draw()
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("ITEM_XSMALL")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("text"):SetText(self._text[dataIndex])
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnItemClick", self._itemString[dataIndex])
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowEnter(row)
	local dataIndex = row:GetDataIndex()
	row:ShowTooltip(self._itemString[dataIndex])
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowLeave(row)
	-- TODO: Could this be handled by the ListRow code?
	TooltipUI.Hide()
end

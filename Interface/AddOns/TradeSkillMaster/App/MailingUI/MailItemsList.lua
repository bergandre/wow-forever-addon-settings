-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local TooltipUI = App:From("LibTSMUI"):Include("TooltipUI")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailItemsList = UIElements.Define("MailItemsList", "List")
MailItemsList:_AddActionScripts("OnItemClick")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function MailItemsList:__init()
	self.__super:__init()
	self._query = nil ---@type DatabaseQuery!
	self._text = {}
	self._tooltipData = {}
	self._index = {}
	self._itemIndex = {}
end

function MailItemsList:Release()
	self._query = nil
	wipe(self._text)
	wipe(self._tooltipData)
	wipe(self._index)
	wipe(self._itemIndex)
	self.__super:Release()
end

---Sets the query used to populate the list.
---@param query DatabaseQuery The query object
---@return self
function MailItemsList:SetQuery(query)
	assert(not self._query)
	self._query = query
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MailItemsList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._text)
	wipe(self._tooltipData)
	wipe(self._index)
	wipe(self._itemIndex)
	for _, itemIndex, itemLink, quantity, index in self._query:Iterator("itemIndex", "itemLink", "quantity", "index") do
		if itemIndex == 0 then
			local amount = tonumber(itemLink)
			assert(amount)
			tinsert(self._text, L["Gold"]..": "..Money.ToStringExact(amount, Theme.GetColor("positive/main"):GetTextColorPrefix()))
			tinsert(self._tooltipData, false)
		else
			local coloredItem = "|T"..(ItemInfo.GetTexture(itemLink) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemLink) or "?")
			if quantity > 1 then
				coloredItem = coloredItem..Theme.GetColor("on/surface/low"):ColorText(" (x"..quantity..")")
			end
			tinsert(self._text, coloredItem)
			tinsert(self._tooltipData, itemLink)
		end
		tinsert(self._index, index)
		tinsert(self._itemIndex, itemIndex)
	end
	self:_SetNumRows(#self._text)
	self:Draw()
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("ITEM_XSMALL")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("text"):SetText(self._text[dataIndex])
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowEnter(row)
	local data = self._tooltipData[row:GetDataIndex()]
	if not data then
		return
	end
	row:ShowTooltip(data)
end

function MailItemsList.__protected:_HandleRowLeave(row)
	-- The data might not exist anymore, so just hide the tooltip to be safe
	TooltipUI.Hide()
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	self:_SendActionScript("OnItemClick", self._index[dataIndex], self._itemIndex[dataIndex])
end

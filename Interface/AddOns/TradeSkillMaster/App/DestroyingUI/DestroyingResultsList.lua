-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Conversion = App:From("LibTSMTypes"):Include("Item.Conversion")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local Conversions = App:From("LibTSMService"):Include("Item.Conversions")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local TooltipUI = App:From("LibTSMUI"):Include("TooltipUI")
local CONVERSION_METHODS = {
	Conversion.METHOD.PROSPECT,
	Conversion.METHOD.MILL,
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DestroyingResultsList = UIElements.Define("DestroyingResultsList", "List")
DestroyingResultsList.ROW_HEIGHT = 14



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DestroyingResultsList:__init()
	self.__super:__init()
	self._itemString = {}
	self._text = {}
	self._rate = {}
end

function DestroyingResultsList:Release()
	wipe(self._itemString)
	wipe(self._text)
	wipe(self._rate)
	self.__super:Release()
end

---Sets the item to show destroy results for.
---@param itemString string|ReactivePublisherSchemaBase<string> The item string or a publisher
---@return self
function DestroyingResultsList:SetItemString(itemString)
	if type(itemString) == "string" then
		self:_UpdateData(itemString)
	else
		self:_MethodPublisher(itemString, "SetItemString")
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function DestroyingResultsList.__private:_UpdateData(itemString)
	wipe(self._itemString)
	wipe(self._text)
	wipe(self._rate)

	local classId = ItemInfo.GetClassId(itemString)
	local quality = ItemInfo.GetQuality(itemString)
	local itemLevel = App.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBaseFast(itemString))
	local expansion = App.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
	if classId and quality and itemLevel then
		for targetItemString in Conversion.DisenchantTargetItemIterator() do
			local amountOfMats, matRate, minAmount, maxAmount = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
			local infoStr = amountOfMats and self:_GetDestroyInfoString(targetItemString, amountOfMats, matRate, minAmount, maxAmount) or nil
			if infoStr then
				tinsert(self._itemString, targetItemString)
				self._text[targetItemString] = infoStr
				self._rate[targetItemString] = matRate
			end
		end
	end
	for _, method in ipairs(CONVERSION_METHODS) do
		for targetItemString, amountOfMats, matRate, minAmount, maxAmount in Conversion.TargetItemsByMethodIterator(itemString, method) do
			local infoStr = self:_GetDestroyInfoString(targetItemString, amountOfMats, matRate, minAmount, maxAmount)
			if infoStr then
				tinsert(self._itemString, targetItemString)
				self._text[targetItemString] = infoStr
				self._rate[targetItemString] = matRate
			end
		end
	end

	Table.SortWithValueLookup(self._itemString, self._rate, true)
	self:_SetNumRows(#self._itemString)
	self:Draw()
end

function DestroyingResultsList.__private:_GetDestroyInfoString(targetItemString, amountOfMats, matRate, minAmount, maxAmount)
	local name = ItemInfo.GetName(targetItemString)
	local color = ItemInfo.GetQualityColor(targetItemString)
	if not name or not color then
		return nil
	end
	local matRateStr = matRate and (matRate * 100).."% " or ""
	local rangeStr = (minAmount and maxAmount) and Theme.GetColor("on/surface/low"):ColorText(minAmount ~= maxAmount and (" ["..minAmount.."-"..maxAmount.."]") or (" ["..minAmount.."]")) or ""
	return color..matRateStr..name.." x"..amountOfMats.."|r"..rangeStr
end

---@param row ListRow
function DestroyingResultsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("ITEM_XSMALL")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function DestroyingResultsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local itemString = self._itemString[dataIndex]
	row:GetText("text"):SetText(self._text[itemString])
end


---@param row ListRow
function DestroyingResultsList.__protected:_HandleRowEnter(row)
	local dataIndex = row:GetDataIndex()
	row:ShowTooltip(self._itemString[dataIndex])
end

function DestroyingResultsList.__protected:_HandleRowLeave()
	-- TODO: Could this be handled by the ListRow code?
	-- The data might not exist anymore, so just hide the tooltip to be safe
	TooltipUI.Hide()
end

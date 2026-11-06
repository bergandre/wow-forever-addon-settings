-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local HEADER_HEIGHT = 20
local HEADER_LINE_HEIGHT = 1
local DIVIDER_LABEL_PADDING = 6
local POSTING_HORIZONTAL_INSET = 4
local POSTING_ROUNDED_INSET = 2
local POSTING_CORNER_RADIUS = 4
local DRAG_SCROLL_SPEED_FACTOR = 12
local DRAG_PLACEHOLDER_ALPHA = 0.4
local DIVIDER_LABELS = {
	min = L["Min Price"],
	normal = L["Normal Price"],
	max = L["Max Price"],
}

---@alias ExistingAuctionsListDropPriceFunc fun(unitPrice: number): number

---@class ExistingAuctionsList.Entry
---@field unitPrice number The unit price in copper
---@field quantity number The quantity
---@field isIgnored boolean Whether the auction is ignored by the operation
---@field isPosting boolean Whether this is the pending post



-- ============================================================================
-- Element Definition
-- ============================================================================

local ExistingAuctionsList = ComponentRegistry.Define("ExistingAuctionsList", "List")
ExistingAuctionsList:_AddActionScripts("OnPostingMoved")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ExistingAuctionsList:__init()
	self.__super:__init()
	self._rowType = {}
	self._unitPrice = {}
	self._quantity = {}
	self._isDragging = false
	self._dragPostingIndex = nil
	self._dropTargetIndex = nil
	self._dropPrice = nil
	self._dragOriginalPrice = nil
	self._dragOriginalTargetIndex = nil
	self._dropPriceFunc = nil ---@type ExistingAuctionsListDropPriceFunc!
	self._dragSnapshotRowType = {}
	self._dragSnapshotUnitPrice = {}
	self._dragSnapshotQuantity = {}

	local colSpacing = Theme.GetColSpacing()
	local rightInset = colSpacing + Theme.GetScrollbarMargin() + Theme.GetScrollbarWidth()

	local header = self:_CreateFrame(self._hContent)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	header:TSMSubscribeBackdropColor(self:_GetOneShotPublisher("container/low"))
	local headerPrice = self:_CreateFontString(header)
	headerPrice:TSMSetFont("BODY_XSMALL")
	headerPrice:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface"))
	headerPrice:SetJustifyH("RIGHT")
	headerPrice:SetPoint("TOPLEFT", colSpacing, 0)
	headerPrice:SetPoint("BOTTOMRIGHT", header, "BOTTOM", -colSpacing / 2, 0)
	headerPrice:SetText(L["Unit Price"])
	local headerQuantity = self:_CreateFontString(header)
	headerQuantity:TSMSetFont("BODY_XSMALL")
	headerQuantity:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface"))
	headerQuantity:SetJustifyH("RIGHT")
	headerQuantity:SetPoint("TOPLEFT", header, "TOP", colSpacing / 2, 0)
	headerQuantity:SetPoint("BOTTOMRIGHT", -rightInset, 0)
	headerQuantity:SetText(L["Quantity"])

	local headerLine = self:_CreateTexture(self._hContent)
	headerLine:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
	headerLine:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT)
	headerLine:SetHeight(HEADER_LINE_HEIGHT)
	headerLine:TSMSubscribeColorTexture(self:_GetOneShotPublisher("outline/variant"))

	self._vScrollFrame:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT - HEADER_LINE_HEIGHT)
	self._vScrollbar:SetPoint("TOPRIGHT", -Theme.GetScrollbarMargin(), -Theme.GetScrollbarMargin() - HEADER_HEIGHT - HEADER_LINE_HEIGHT)

	self._posting, self._postingPrice, self._postingQuantity = self:_CreatePill("container/medium")
	self._posting:EnableMouse(true)
	self._posting:RegisterForDrag("LeftButton")
	self._posting:TSMSetScript("OnDragStart", self:__closure("_HandlePostingDragStart"))
	self._dragGhost, self._dragGhostPrice, self._dragGhostQuantity = self:_CreatePill("container/high")

	self._dragUpdater = self:_CreateFrame(self._frame)
	self._dragUpdater:Hide()
end

function ExistingAuctionsList:Release()
	self:_StopDragging(false)
	self._dropPriceFunc = nil
	wipe(self._rowType)
	wipe(self._unitPrice)
	wipe(self._quantity)
	self._posting:Hide()
	self._posting:SetParent(self._content)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the function used to get the price of the pending post when dropped above an auction.
---@param func ExistingAuctionsListDropPriceFunc The function which takes an auction's unit price and returns the new price
---@return self
function ExistingAuctionsList:SetDropPriceFunction(func)
	self._dropPriceFunc = func
	return self
end

---Gets whether or not the pending post is currently being dragged.
---@return boolean
function ExistingAuctionsList:IsDragging()
	return self._isDragging
end

---Sets the auctions to show along with the operation's prices.
---@param entries ExistingAuctionsList.Entry[] The entries, sorted by unit price
---@param minPrice? number The operation's min price
---@param normalPrice? number The operation's normal price
---@param maxPrice? number The operation's max price
---@return self
function ExistingAuctionsList:SetData(entries, minPrice, normalPrice, maxPrice)
	wipe(self._rowType)
	wipe(self._unitPrice)
	wipe(self._quantity)
	for _, entry in ipairs(entries) do
		tinsert(self._rowType, (entry.isPosting and "posting") or (entry.isIgnored and "ignored") or "auction")
		tinsert(self._unitPrice, entry.unitPrice)
		tinsert(self._quantity, entry.quantity)
	end
	self:_InsertDivider("min", minPrice)
	self:_InsertDivider("normal", normalPrice)
	self:_InsertDivider("max", maxPrice)
	self:_SetNumRows(#self._rowType)
	if self._isDragging and self:_RowsMatchDragSnapshot() then
		self._dragPostingIndex = self:_GetPostingIndex()
		self._dropTargetIndex = nil
		self._dropPrice = nil
		self:Draw()
		self:_HandlePostingDragUpdate()
		return self
	end
	self:_StopDragging(false)
	self._posting:Hide()
	self:Draw()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function ExistingAuctionsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local rightInset = colSpacing + Theme.GetScrollbarMargin() + Theme.GetScrollbarWidth()
	row:SetHighlightEnabled(false)

	local price = row:AddText("price")
	price:SetHeight(self.ROW_HEIGHT)
	price:TSMSetFont("TABLE_XSMALL")
	price:SetJustifyH("RIGHT")
	local quantity = row:AddText("quantity")
	quantity:SetHeight(self.ROW_HEIGHT)
	quantity:TSMSetFont("TABLE_XSMALL")
	quantity:SetJustifyH("RIGHT")
	local rowFrame = price:GetParent()
	price:SetPoint("LEFT", colSpacing, 0)
	price:SetPoint("RIGHT", rowFrame, "CENTER", -colSpacing / 2, 0)
	quantity:SetPoint("LEFT", rowFrame, "CENTER", colSpacing / 2, 0)
	quantity:SetPoint("RIGHT", -rightInset, 0)

	local dividerLabel = row:AddText("dividerLabel")
	dividerLabel:SetHeight(self.ROW_HEIGHT)
	dividerLabel:TSMSetFont("BODY_XSMALL")
	dividerLabel:TSMSetTextColor("on/surface/low")
	dividerLabel:SetJustifyH("CENTER")
	dividerLabel:SetPoint("CENTER")
	local dividerLineLeft = row:AddTexture("dividerLineLeft")
	dividerLineLeft:SetHeight(1)
	dividerLineLeft:TSMSetColorTexture("on/surface/low")
	dividerLineLeft:SetPoint("LEFT", colSpacing, 0)
	dividerLineLeft:SetPoint("RIGHT", dividerLabel, "LEFT", -DIVIDER_LABEL_PADDING, 0)
	local dividerLineRight = row:AddTexture("dividerLineRight")
	dividerLineRight:SetHeight(1)
	dividerLineRight:TSMSetColorTexture("on/surface/low")
	dividerLineRight:SetPoint("LEFT", dividerLabel, "RIGHT", DIVIDER_LABEL_PADDING, 0)
	dividerLineRight:SetPoint("RIGHT", -rightInset, 0)
end

---@param row ListRow
function ExistingAuctionsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local rowType = self._rowType[dataIndex]
	local price = row:GetText("price")
	local quantity = row:GetText("quantity")
	local rowFrame = price:GetParent()
	local dividerLabel = DIVIDER_LABELS[rowType]
	local isAuction = rowType == "auction" or rowType == "ignored"
	price:SetShown(isAuction)
	quantity:SetShown(isAuction)
	row:GetText("dividerLabel"):SetShown(dividerLabel ~= nil)
	row:GetTexture("dividerLineLeft"):SetShown(dividerLabel ~= nil)
	row:GetTexture("dividerLineRight"):SetShown(dividerLabel ~= nil)
	if isAuction then
		local isIgnored = rowType == "ignored"
		price:SetText(Money.ToStringForAH(self._unitPrice[dataIndex], nil, isIgnored))
		price:TSMSetTextColor(isIgnored and "on/surface/low" or "on/surface")
		quantity:SetText(tostring(self._quantity[dataIndex]))
		quantity:TSMSetTextColor(isIgnored and "on/surface/low" or "on/surface")
	elseif dividerLabel then
		row:GetText("dividerLabel"):SetText(dividerLabel.." ("..Money.ToStringForAH(self._unitPrice[dataIndex], nil, true)..")")
	end
	if rowType == "posting" then
		self:_ShowPosting(rowFrame, self._unitPrice[dataIndex], self._quantity[dataIndex])
	elseif self._posting:GetParent() == rowFrame then
		if self._isDragging then
			self._posting:SetAlpha(0)
		else
			self._posting:Hide()
		end
	end
end

---@param row ListRow
---@param mouseButton MouseButton
function ExistingAuctionsList.__protected:_HandleRowDoubleClick(row, mouseButton)
	if mouseButton ~= "LeftButton" or self._isDragging then
		return
	end
	local dataIndex = row:GetDataIndex()
	local rowType = self._rowType[dataIndex]
	local postingIndex = self:_GetPostingIndex()
	if (rowType ~= "auction" and rowType ~= "ignored") or not postingIndex then
		return
	end
	local price = self._dropPriceFunc(self._unitPrice[dataIndex])
	if price == self._unitPrice[postingIndex] then
		return
	end
	self:_SendActionScript("OnPostingMoved", price)
end

function ExistingAuctionsList.__private:_ShowPosting(rowFrame, unitPrice, quantity)
	local posting = self._posting
	posting:SetParent(rowFrame)
	posting:SetFrameLevel(rowFrame:GetFrameLevel() + 1)
	posting:ClearAllPoints()
	posting:SetPoint("LEFT", POSTING_HORIZONTAL_INSET, 0)
	posting:SetPoint("RIGHT", -POSTING_HORIZONTAL_INSET, 0)
	self._postingPrice:SetText(Money.ToStringForAH(unitPrice))
	self._postingQuantity:SetText(tostring(quantity))
	posting:SetAlpha(self._isDragging and DRAG_PLACEHOLDER_ALPHA or 1)
	posting:Show()
end

function ExistingAuctionsList.__private:_HandlePostingDragStart()
	local postingIndex = self:_GetPostingIndex()
	if not postingIndex then
		return
	end
	self._isDragging = true
	self._dragPostingIndex = postingIndex
	self._dropTargetIndex = nil
	self._dropPrice = nil
	self._dragOriginalPrice = self._unitPrice[postingIndex]
	local originalTargetIndex = self:_GetAuctionIndexAfter(postingIndex)
	self._dragOriginalTargetIndex = originalTargetIndex and self:_GetIndexWithoutPosting(originalTargetIndex)
	for i = 1, #self._rowType do
		self._dragSnapshotRowType[i] = self._rowType[i]
		self._dragSnapshotUnitPrice[i] = self._unitPrice[i]
		self._dragSnapshotQuantity[i] = self._quantity[i]
	end
	self._posting:SetAlpha(DRAG_PLACEHOLDER_ALPHA)
	self._dragGhostPrice:SetText(Money.ToStringForAH(self._unitPrice[postingIndex]))
	self._dragGhostQuantity:SetText(tostring(self._quantity[postingIndex]))
	self._dragGhost:SetFrameLevel(self._content:GetFrameLevel() + 10)
	self._dragUpdater:TSMSetScript("OnUpdate", self:__closure("_HandlePostingDragUpdate"))
	self._dragUpdater:Show()
	self:_HandlePostingDragUpdate()
end

function ExistingAuctionsList.__private:_HandlePostingDragUpdate()
	if not IsMouseButtonDown("LeftButton") then
		self:_FinishDragging()
		return
	end
	local _, cursorY = GetCursorPosition()
	cursorY = cursorY / self._content:GetEffectiveScale()
	local top = self._vScrollFrame:GetTop()
	local bottom = self._vScrollFrame:GetBottom()
	if cursorY > top then
		self._vScrollbar:SetValue(self._vScrollbar:GetValue() - (cursorY - top) / DRAG_SCROLL_SPEED_FACTOR)
	elseif cursorY < bottom then
		self._vScrollbar:SetValue(self._vScrollbar:GetValue() + (bottom - cursorY) / DRAG_SCROLL_SPEED_FACTOR)
	end

	local ghostY = Math.Bound(cursorY, bottom + self.ROW_HEIGHT / 2, top - self.ROW_HEIGHT / 2) - self._content:GetTop()
	self._dragGhost:ClearAllPoints()
	self._dragGhost:SetPoint("LEFT", self._content, "TOPLEFT", POSTING_HORIZONTAL_INSET, ghostY)
	self._dragGhost:SetPoint("RIGHT", self._content, "TOPRIGHT", -POSTING_HORIZONTAL_INSET, ghostY)
	self._dragGhost:Show()

	local targetIndex = self:_GetDropTargetIndex(cursorY)
	if targetIndex and self:_GetIndexWithoutPosting(targetIndex) == self._dragOriginalTargetIndex then
		targetIndex = nil
	end
	if targetIndex then
		local dropPrice = self._dropPriceFunc(self._unitPrice[targetIndex])
		local priceChanged = dropPrice ~= self._dropPrice
		self._dropPrice = dropPrice
		local postingIndex = self._dragPostingIndex
		assert(postingIndex)
		self._unitPrice[postingIndex] = dropPrice
		self._dropTargetIndex = self:_MovePostingBefore(targetIndex)
		if priceChanged then
			self:_DrawRows()
		end
	elseif self._dropTargetIndex then
		self._dropTargetIndex = nil
		self._dropPrice = nil
		self:_RestoreDragSnapshot()
	end
	local ghostPrice = self._dropPrice or self._dragOriginalPrice
	assert(ghostPrice)
	self._dragGhostPrice:SetText(Money.ToStringForAH(ghostPrice))
end

function ExistingAuctionsList.__private:_FinishDragging()
	if not self._isDragging then
		return
	end
	local dropPrice = self._dropTargetIndex and self._dropPrice
	self:_StopDragging(true)
	if dropPrice then
		self:_SendActionScript("OnPostingMoved", dropPrice)
	end
end

function ExistingAuctionsList.__private:_StopDragging(restoreSnapshot)
	if not self._isDragging then
		return
	end
	self._isDragging = false
	self._dragPostingIndex = nil
	self._dropTargetIndex = nil
	self._dropPrice = nil
	self._dragOriginalPrice = nil
	self._dragOriginalTargetIndex = nil
	self._dragUpdater:TSMSetScript("OnUpdate", nil)
	self._dragUpdater:Hide()
	self._dragGhost:Hide()
	if restoreSnapshot then
		self:_RestoreDragSnapshot()
	end
	wipe(self._dragSnapshotRowType)
	wipe(self._dragSnapshotUnitPrice)
	wipe(self._dragSnapshotQuantity)
end

function ExistingAuctionsList.__private:_RowsMatchDragSnapshot()
	if #self._rowType ~= #self._dragSnapshotRowType then
		return false
	end
	for i = 1, #self._rowType do
		if self._rowType[i] ~= self._dragSnapshotRowType[i] or self._unitPrice[i] ~= self._dragSnapshotUnitPrice[i] or self._quantity[i] ~= self._dragSnapshotQuantity[i] then
			return false
		end
	end
	return true
end

function ExistingAuctionsList.__private:_RestoreDragSnapshot()
	for i = 1, #self._dragSnapshotRowType do
		self._rowType[i] = self._dragSnapshotRowType[i]
		self._unitPrice[i] = self._dragSnapshotUnitPrice[i]
		self._quantity[i] = self._dragSnapshotQuantity[i]
		if self._rowType[i] == "posting" and self._dragPostingIndex then
			self._dragPostingIndex = i
		end
	end
	self:_DrawRows()
end

function ExistingAuctionsList.__private:_MovePostingBefore(targetIndex)
	local postingIndex = self._dragPostingIndex
	if targetIndex == postingIndex + 1 then
		return targetIndex
	end
	local rowType = tremove(self._rowType, postingIndex)
	local unitPrice = tremove(self._unitPrice, postingIndex)
	local quantity = tremove(self._quantity, postingIndex)
	if targetIndex > postingIndex then
		targetIndex = targetIndex - 1
	end
	tinsert(self._rowType, targetIndex, rowType)
	tinsert(self._unitPrice, targetIndex, unitPrice)
	tinsert(self._quantity, targetIndex, quantity)
	self._dragPostingIndex = targetIndex
	self:_DrawRows()
	return targetIndex + 1
end

function ExistingAuctionsList.__private:_GetDropTargetIndex(cursorY)
	local slotIndex, firstVisibleIndex, lastVisibleIndex = nil, nil, nil
	for dataIndex = 1, #self._rowType do
		local row = self:_GetRow(dataIndex)
		if row then
			firstVisibleIndex = firstVisibleIndex or dataIndex
			lastVisibleIndex = dataIndex
			local rowFrame = row:GetText("price"):GetParent()
			local rowTop, rowBottom = rowFrame:GetTop(), rowFrame:GetBottom()
			if cursorY <= rowTop and cursorY >= rowBottom then
				slotIndex = cursorY >= (rowTop + rowBottom) / 2 and dataIndex or dataIndex + 1
			end
		end
	end
	if not firstVisibleIndex or not lastVisibleIndex then
		return nil
	end
	slotIndex = slotIndex or (cursorY > self._vScrollFrame:GetTop() - self.ROW_HEIGHT and firstVisibleIndex or lastVisibleIndex + 1)
	return self:_GetAuctionIndexAfter(slotIndex - 1)
end

function ExistingAuctionsList.__private:_GetPostingIndex()
	for i, rowType in ipairs(self._rowType) do
		if rowType == "posting" then
			return i
		end
	end
	return nil
end

function ExistingAuctionsList.__private:_GetAuctionIndexAfter(index)
	for dataIndex = index + 1, #self._rowType do
		local rowType = self._rowType[dataIndex]
		if rowType == "auction" or rowType == "ignored" then
			return dataIndex
		end
	end
	return nil
end

function ExistingAuctionsList.__private:_GetIndexWithoutPosting(index)
	local postingIndex = self._dragPostingIndex
	assert(postingIndex)
	return index > postingIndex and index - 1 or index
end

function ExistingAuctionsList.__private:_CreatePill(backgroundColor)
	local colSpacing = Theme.GetColSpacing()
	local rightInset = colSpacing + Theme.GetScrollbarMargin() + Theme.GetScrollbarWidth()
	local frame = self:_CreateFrame(self._content)
	frame:Hide()
	frame:SetHeight(self.ROW_HEIGHT)
	local background = self:_CreateRectangle(nil, frame)
	background:SetInset(POSTING_ROUNDED_INSET)
	background:SetCornerRadius(POSTING_CORNER_RADIUS)
	background:SubscribeColor(self:_GetOneShotPublisher(backgroundColor))
	local handle = self:_CreateTexture(frame, "ARTWORK")
	handle:TSMSetTextureAndSize("iconPack.12x12/Grip")
	handle:TSMSubscribeVertexColor(self:_GetOneShotPublisher("on/surface"))
	handle:SetPoint("LEFT", POSTING_ROUNDED_INSET + colSpacing / 2, 0)
	local price = self:_CreateFontString(frame)
	price:TSMSetFont("TABLE_XSMALL")
	price:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface"))
	price:SetJustifyH("RIGHT")
	price:SetHeight(self.ROW_HEIGHT)
	price:SetPoint("LEFT", colSpacing - POSTING_HORIZONTAL_INSET, 0)
	price:SetPoint("RIGHT", frame, "CENTER", -colSpacing / 2, 0)
	local quantity = self:_CreateFontString(frame)
	quantity:TSMSetFont("TABLE_XSMALL")
	quantity:TSMSubscribeTextColor(self:_GetOneShotPublisher("on/surface"))
	quantity:SetJustifyH("RIGHT")
	quantity:SetHeight(self.ROW_HEIGHT)
	quantity:SetPoint("LEFT", frame, "CENTER", colSpacing / 2, 0)
	quantity:SetPoint("RIGHT", -rightInset + POSTING_HORIZONTAL_INSET, 0)
	return frame, price, quantity
end

function ExistingAuctionsList.__private:_InsertDivider(rowType, price)
	if not price then
		return
	end
	local index = #self._rowType + 1
	for i = 1, #self._rowType do
		local unitPrice = self._unitPrice[i]
		if unitPrice > price or (unitPrice == price and rowType ~= "max" and not DIVIDER_LABELS[self._rowType[i]]) then
			index = i
			break
		end
	end
	tinsert(self._rowType, index, rowType)
	tinsert(self._unitPrice, index, price)
	tinsert(self._quantity, index, 0)
end

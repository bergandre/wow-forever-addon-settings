-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Group = App:From("LibTSMTypes"):Include("Group")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {}
local SECONDS_PER_MIN = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MIN
local SHOW_HIGH_BIDDER = App.IsVanillaClassic() or App.IsBCClassic()
local COL_INFO = {
	item = {
		title = L["Item Name"],
		justifyH = "LEFT",
		font = "ITEM_XSMALL",
		hasTooltip = true,
		disableHiding = true,
		sortField = "itemName",
	},
	stackSize = {
		title = L["Qty"],
		justifyH = "CENTER",
		font = "TABLE_XSMALL",
		sortField = "stackSize",
	},
	timeLeft = {
		titleIcon = "iconPack.14x14/Clock",
		justifyH = "CENTER",
		sortField = "duration",
	},
	highBidder = SHOW_HIGH_BIDDER and {
		title = HIGH_BIDDER,
		justifyH = "LEFT",
	} or nil,
	group = {
		title = GROUP,
		justifyH = "LEFT",
		sortField = "group",
	},
	currentBid = {
		title = BID,
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "currentBid",
	},
	buyout = {
		title = BUYOUT,
		justifyH = "RIGHT",
		font = "TABLE_XSMALL",
		sortField = "buyout",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MyAuctionsScrollTable = UIElements.Define("MyAuctionsScrollTable", "ScrollTable")
MyAuctionsScrollTable._STATE_SCHEMA = MyAuctionsScrollTable._STATE_SCHEMA:Extend("MyAuctionsScrollTableState")
	:AddOptionalNumberField("selectedAuctionId")
	:AddBooleanField("isSelectionPending", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MyAuctionsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil ---@type DatabaseQuery!
	self._data.auctionId = {}
	self._selectionSortValue = nil
end

function MyAuctionsScrollTable:Release()
	local query = self._query
	self._query = nil
	self._selectionSortValue = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets whether or not sorting is disabled.
---@param disabled boolean
---@return self
function MyAuctionsScrollTable:SetSortingDisabled(disabled)
	assert(not self._query and not self._settings)
	assert(type(disabled) == "boolean")
	self._sortDisabled = disabled
	return self
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return self
function MyAuctionsScrollTable:SetQuery(query)
	assert(self._settings)
	assert(not self._query)
	self._query = query
	query:ResetFilters()
	if not self._sortDisabled then
		query:ResetOrderBy()
			:OrderBy("isSold", false)
			:OrderBy(self:_GetSortField(), self:_GetSettingsValue().sortAscending)
			:OrderBy("auctionId", true)
		self:_DrawSortFlag()
	end
	self:_AddQueryUpdatePublisher(query, self:__closure("_HandleQueryUpdate"))
	return self
end

---Sets the filters.
---@param name? string Item name filter
---@param duration? number Duration filter
---@param groupsStr? string Group filter as a separated string (using '\001')
---@param hasBid? boolean Show only auctions with or without a bid (nil to disable)
---@param soldOnly? boolean Show only sold auctions (false/nil to disable)
function MyAuctionsScrollTable:SetFilters(name, duration, groupsStr, hasBid, soldOnly)
	self._query:ResetFilters()
	if name then
		self._query:Matches("itemName", name)
	end
	if duration then
		if App.IsVanillaClassic() or App.IsBCClassic() then
			self._query:Equal("duration", duration)
		else
			if duration == 1 then
				self._query:LessThan("duration", App.GetTime() + (30 * SECONDS_PER_MIN))
			elseif duration == 2 then
				self._query:LessThan("duration", App.GetTime() + (2 * SECONDS_PER_HOUR))
			elseif duration == 3 then
				self._query:LessThanOrEqual("duration", App.GetTime() + (12 * SECONDS_PER_HOUR))
			else
				self._query:GreaterThan("duration", App.GetTime() + (12 * SECONDS_PER_HOUR))
			end
		end
	end
	if groupsStr then
		self._query:Function("group", private.InGroupFilterStr, groupsStr)
	end
	if hasBid ~= nil then
		if hasBid then
			self._query:NotEqual("highBidder", "")
		else
			self._query:Equal("highBidder", "")
		end
	end
	if soldOnly then
		self._query:Equal("isSold", true)
	end
	self:_HandleQueryUpdate()
end

---Selects the next row.
---@return self
function MyAuctionsScrollTable:SelectNextRow()
	local auctionId = nil
	local dataIndex = self._state.selectedAuctionId and Table.KeyByValue(self._data.auctionId, self._state.selectedAuctionId) or 0
	for i = dataIndex + 1, #self._data.auctionId do
		if not self._query:GetNthResult(i, "isSold") then
			auctionId = self._data.auctionId[i]
			break
		end
	end
	self:_SetSelectedAuction(auctionId)
	return self
end

---Gets the totals for the visible rows.
---@return number numPosted
---@return number numSold
---@return number postedGold
---@return number soldGold
function MyAuctionsScrollTable:GetTotals()
	local numPosted, numSold, postedGold, soldGold = 0, 0, 0, 0
	for _, itemString, isSold, buyout, currentBid, stackSize in self._query:Iterator("itemString", "isSold", "buyout", "currentBid", "stackSize") do
		if isSold then
			numSold = numSold + 1
			-- If somebody did a buyout, then bid will be equal to buyout, otherwise it'll be the winning bid
			soldGold = soldGold + currentBid
		else
			numPosted = numPosted + 1
			if ItemInfo.IsCommodity(itemString) then
				postedGold = postedGold + (buyout * stackSize)
			else
				postedGold = postedGold + buyout
			end
		end
	end
	return numPosted, numSold, postedGold, soldGold
end

---Binds a state property to the selected auction ID.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function MyAuctionsScrollTable:BindSelectedAuctionId(state, key)
	self._state:Publisher("selectedAuctionId")
		:AssignToTableKey(state, key)
	return self
end

---Binds a state property to whether or not the selected auction is pending.
---@param state ReactiveState The state to store the value in
---@param key string The state key to store the value at
---@return self
function MyAuctionsScrollTable:BindIsSelectionPending(state, key)
	self._state:Publisher("isSelectionPending")
		:AssignToTableKey(state, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MyAuctionsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	wipe(self._actionIcon)
	local sortAscending = self:_GetSettingsValue().sortAscending
	local hasExistingSelection, nextSelectionAuctionId, isSelectionPending = false, nil, false
	for _, isSold, itemName, itemQuality, itemString, stackSize, duration, isPending, group, currentBid, highBidder, buyout, auctionId, sortValue in self._query:Iterator("isSold", "itemName", "itemQuality", "itemString", "stackSize", "duration", "isPending", "group", "currentBid", "highBidder", "buyout", "auctionId", self:_GetSortField()) do
		local itemTexturePrefix = "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "
		if isSold then
			local color = Theme.GetColor("accent/main")
			tinsert(self._data.item, itemTexturePrefix..color:ColorText(itemName))
			tinsert(self._data.stackSize, color:ColorText(stackSize))
			tinsert(self._data.currentBid, color:ColorText(L["Sold"]))
			tinsert(self._data.buyout, Money.ToStringForAH(currentBid))
		else
			tinsert(self._data.item, itemTexturePrefix..(UIUtils.GetQualityColoredText(itemName, itemQuality) or "?"))
			tinsert(self._data.stackSize, stackSize)
			local bidColor = not SHOW_HIGH_BIDDER and highBidder ~= "" and Theme.GetColor("accent/main"):GetTextColorPrefix() or nil
			tinsert(self._data.currentBid, Money.ToStringForAH(currentBid, bidColor))
			tinsert(self._data.buyout, Money.ToStringForAH(buyout))
		end
		tinsert(self._actionIcon, isSold and "iconPack.12x12/Bid" or false)
		if self._data.highBidder then
			tinsert(self._data.highBidder, isSold and Theme.GetColor("accent/main"):ColorText(highBidder) or highBidder)
		end
		tinsert(self._data.item_tooltip, itemString)
		if not isSold and isPending then
			tinsert(self._data.timeLeft, "...")
		elseif isSold or not SHOW_HIGH_BIDDER then
			local timeLeft = floor(duration - App.GetTime())
			local timeLeftStr = nil
			if timeLeft < SECONDS_PER_MIN then
				timeLeftStr = format(L["%ds"], timeLeft)
			elseif timeLeft < SECONDS_PER_HOUR then
				timeLeftStr = format(L["%dm"], floor(timeLeft / SECONDS_PER_MIN))
			else
				timeLeftStr = format(L["%dh"], floor(timeLeft / SECONDS_PER_HOUR))
			end
			local timeLeftColor = nil
			if isSold then
				timeLeftColor = "accent/main"
			elseif timeLeft <= 2 * SECONDS_PER_HOUR then
				timeLeftColor = "error/main"
			elseif timeLeft <= ((App.IsVanillaClassic() or App.IsBCClassic()) and 8 or 24) * SECONDS_PER_HOUR then
				timeLeftColor = "accent/main"
			else
				timeLeftColor = "positive/main"
			end
			tinsert(self._data.timeLeft, Theme.GetColor(timeLeftColor):ColorText(timeLeftStr))
		else
			tinsert(self._data.timeLeft, UIUtils.GetTimeLeftString(duration))
		end
		local groupName = Group.GetName(group)
		tinsert(self._data.group, Theme.GetGroupColor(Group.GetLevel(group)):ColorText(groupName))
		tinsert(self._data.auctionId, auctionId)
		if self._state.selectedAuctionId and not isSold then
			if auctionId == self._state.selectedAuctionId then
				hasExistingSelection = true
				isSelectionPending = isPending and true or false
			elseif not nextSelectionAuctionId then
				if type(sortValue) == "string" then
					sortValue = strlower(sortValue)
				end
				if (not App.IsVanillaClassic() and not App.IsBCClassic()) and sortValue == self._selectionSortValue and auctionId > self._state.selectedAuctionId then
					nextSelectionAuctionId = auctionId
				elseif sortAscending then
					assert(self._selectionSortValue)
					nextSelectionAuctionId = sortValue > self._selectionSortValue and auctionId or nil
				else
					assert(self._selectionSortValue)
					nextSelectionAuctionId = sortValue < self._selectionSortValue and auctionId or nil
				end
			end
		end
		self._createGroupsData[itemString] = L["My Auctions"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()

	-- Update the selection if necessary
	if hasExistingSelection then
		self._state.isSelectionPending = isSelectionPending
	else
		self:_SetSelectedAuction(nextSelectionAuctionId)
	end
end

---@param row ListRow
function MyAuctionsScrollTable.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	self.__super:_HandleRowDraw(row)
	row:SetSelected(self._data.auctionId[dataIndex] == self._state.selectedAuctionId)
end

---@param row ListRow
function MyAuctionsScrollTable.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	if self._query:GetNthResult(dataIndex, "isSold") then
		return
	end
	self:_SetSelectedAuction(self._data.auctionId[dataIndex])
end

function MyAuctionsScrollTable.__private:_GetSortField()
	if self._sortDisabled then
		return "index"
	end
	local field = COL_INFO[self:_GetSettingsValue().sortCol].sortField
	assert(field)
	return field
end

function MyAuctionsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	if self._state.selectedAuctionId then
		local selectionDataIndex = Table.KeyByValue(self._data.auctionId, self._state.selectedAuctionId) or nil
		local isSold, sortValue = self._query:GetNthResult(selectionDataIndex, "isSold", self:_GetSortField())
		if type(sortValue) == "string" then
			sortValue = strlower(sortValue)
		end
		assert(not isSold)
		self._selectionSortValue = sortValue
	end
	self._query:ResetOrderBy()
		:OrderBy("isSold", false)
		:OrderBy(self:_GetSortField(), self:_GetSettingsValue().sortAscending)
		:OrderBy("auctionId", true)
	self:_HandleQueryUpdate()
end

function MyAuctionsScrollTable.__private:_SetSelectedAuction(auctionId)
	local dataIndex = auctionId and Table.KeyByValue(self._data.auctionId, auctionId) or nil
	local prevDataIndex = self._state.selectedAuctionId and Table.KeyByValue(self._data.auctionId, self._state.selectedAuctionId) or nil
	if auctionId == self._state.selectedAuctionId and (not auctionId or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return self
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	local isSold, isPending, sortValue = nil, nil, nil
	if dataIndex then
		isSold, isPending, sortValue = self._query:GetNthResult(dataIndex, "isSold", "isPending", self:_GetSortField())
	end
	if isSold == false then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			newRow:SetSelected(true)
		end
		if type(sortValue) == "string" then
			sortValue = strlower(sortValue)
		end
		self._selectionSortValue = sortValue
		self._state.isSelectionPending = isPending and true or false
		self._state.selectedAuctionId = self._data.auctionId[dataIndex]
		self:_ScrollToRow(dataIndex)
	else
		self._selectionSortValue = nil
		self._state.isSelectionPending = false
		self._state.selectedAuctionId = nil
	end
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.InGroupFilterStr(group, groupsFilter)
	return String.SeparatedContains(groupsFilter, "\001", group)
end

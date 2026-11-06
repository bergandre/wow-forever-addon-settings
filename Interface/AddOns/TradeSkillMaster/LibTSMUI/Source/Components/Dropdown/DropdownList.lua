-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local DropdownList = ComponentRegistry.Define("DropdownList", "List")
DropdownList:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DropdownList:__init()
	self.__super:__init()
	self._items = {}
	self._selectedItems = {}
	self._multiselect = nil
end

function DropdownList:Release()
	wipe(self._items)
	wipe(self._selectedItems)
	self._multiselect = nil
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DropdownList:SetMultiselect(multiselect)
	assert(multiselect ~= nil and self._multiselect == nil)
	self._multiselect = multiselect
	return self
end

function DropdownList:SetItems(items, selection)
	wipe(self._items)
	for _, item in ipairs(items) do
		tinsert(self._items, item)
	end
	self:_SetSelectionHelper(selection)
	self:_SetNumRows(#self._items)
	return self
end

function DropdownList:SelectAll()
	assert(self._multiselect)
	self:_SetSelectionHelper(true)
	self:_SendActionScript("OnSelectionChanged", self._selectedItems)
end

function DropdownList:DeselectAll()
	assert(self._multiselect)
	self:_SetSelectionHelper(false)
	self:_SendActionScript("OnSelectionChanged", self._selectedItems)
end

function DropdownList:IsNoneSelected()
	for _, item in ipairs(self._items) do
		if self._selectedItems[item] then
			return false
		end
	end
	return true
end

function DropdownList:IsAllSelected()
	for _, item in ipairs(self._items) do
		if not self._selectedItems[item] then
			return false
		end
	end
	return true
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function DropdownList.__protected:_HandleRowAcquired(row)
	assert(self._multiselect ~= nil)

	-- Add the text
	local text = row:AddText("text")
	text:TSMSetFont("BODY_SMALL")
	text:SetJustifyH("LEFT")
	text:SetHeight(self.ROW_HEIGHT)
	text:SetPoint("LEFT", Theme.GetColSpacing() / 2, 0)

	-- Add the check texture
	local check = row:AddTexture("check")
	check:SetDrawLayer("ARTWORK", 1)
	check:TSMSetTextureAndSize("iconPack.12x12/Checkmark/Default")
	check:SetPoint("RIGHT", -Theme.GetColSpacing() / 2, 0)
	text:SetPoint("RIGHT", check, "LEFT", -Theme.GetColSpacing() / 2, 0)
end

---@param row ListRow
function DropdownList.__protected:_HandleRowDraw(row)
	local item = self._items[row:GetDataIndex()]
	self:_DrawRowSelectedState(row, self._selectedItems[item])
	local text = row:GetText("text")
	text:SetText(item)
	text:TSMSetTextColor("on/surface")
end

---@param row ListRow
function DropdownList.__private:_DrawRowSelectedState(row, selected)
	row:GetTexture("check"):TSMSetShown(selected and true or false)
end

---@param row ListRow
function DropdownList.__protected:_HandleRowClick(row, mouseButton)
	local item = self._items[row:GetDataIndex()]
	if self._multiselect then
		self._selectedItems[item] = not self._selectedItems[item] or nil
		self:_DrawRowSelectedState(row, self._selectedItems[item])
	else
		wipe(self._selectedItems)
		self._selectedItems[item] = true
		self:_DrawRowSelectedState(row, true)
	end
	self:_SendActionScript("OnSelectionChanged", self._multiselect and self._selectedItems or item)
end

function DropdownList.__private:_SetSelectionHelper(selection)
	wipe(self._selectedItems)
	if self._multiselect then
		for i, item in ipairs(self._items) do
			if selection == true then
				-- Select all
				self._selectedItems[item] = true
			elseif selection == false then
				-- Deselect all - do nothing
			else
				-- Selection table
				self._selectedItems[item] = selection[item] and true or nil
			end
			local row = self:_GetRow(i)
			if row then
				self:_DrawRowSelectedState(row, self._selectedItems[item])
			end
		end
	else
		if selection then
			self._selectedItems[selection] = true
		end
		for i, item in ipairs(self._items) do
			local row = self:_GetRow(i)
			if row then
				self:_DrawRowSelectedState(row, self._selectedItems[item])
			end
		end
	end
end

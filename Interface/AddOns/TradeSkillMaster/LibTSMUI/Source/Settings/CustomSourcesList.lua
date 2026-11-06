
-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local BinarySearch = LibTSMUI:From("LibTSMUtil"):Include("Util.BinarySearch")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local HEADER_TEXT_HEIGHT = 20
local HEADER_LINE_HEIGHT = 1
local NAME_COL_WIDTH = 140
local FORMAT_COL_WIDTH = 100
local ICON_SPACING = 4
local EDIT_TEXTURE = "iconPack.18x18/Edit"
local DELETE_TEXTURE = "iconPack.18x18/Delete"
local TABLE_FORMAT_TEXT = {
	gold = L["Gold"],
	number = L["Number"],
	pct = L["Percent"],
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CustomSourcesList = ComponentRegistry.Define("CustomSourcesList", "StaticList")
CustomSourcesList.ROW_HEIGHT = 28
CustomSourcesList.HEADER_HEIGHT = HEADER_TEXT_HEIGHT + HEADER_LINE_HEIGHT
CustomSourcesList._STATE_SCHEMA = CustomSourcesList._STATE_SCHEMA:Extend("CustomSourcesListState")
	:UpdateFieldDefault("backgroundColor", "container/lowest")
	:Commit()
CustomSourcesList:_AddActionScripts("OnEdit", "OnDelete")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CustomSourcesList:__init()
	self.__super:__init()

	self._name = {}
	self._format = {}
	self._value = {}

	self._header = self:_CreateFrame(self._frame)
	self._header:SetPoint("TOPLEFT")
	self._header:SetPoint("TOPRIGHT")
	self._header:SetHeight(HEADER_TEXT_HEIGHT)

	self._line = self:_CreateTexture(self._frame)
	self._line:SetPoint("TOPLEFT", 0, -HEADER_TEXT_HEIGHT)
	self._line:SetPoint("TOPRIGHT", 0, -HEADER_TEXT_HEIGHT)
	self._line:SetHeight(HEADER_LINE_HEIGHT)
	self._line:TSMSubscribeColorTexture(self:_GetOneShotPublisher("outline/variant"))

	local colSpacing = Theme.GetColSpacing()
	local xOffset = colSpacing / 2

	self._header.item = self:_CreateHeaderText(L["Name"])
	self._header.item:SetWidth(NAME_COL_WIDTH)
	self._header.item:SetPoint("LEFT", xOffset, 0)
	xOffset = xOffset + NAME_COL_WIDTH + colSpacing

	self._header.format = self:_CreateHeaderText(L["Display Format"])
	self._header.format:SetWidth(FORMAT_COL_WIDTH)
	self._header.format:SetPoint("LEFT", xOffset, 0)
	xOffset = xOffset + FORMAT_COL_WIDTH + colSpacing

	self._header.value = self:_CreateHeaderText(L["String"])
	self._header.value:SetPoint("LEFT", xOffset, 0)
	self._header.value:SetPoint("RIGHT", -colSpacing / 2, 0)
end

function CustomSourcesList:Release()
	wipe(self._name)
	wipe(self._format)
	wipe(self._value)
	self.__super:Release()
end

---Sets the custom sources to be displayed.
---@param iter IteratorObject An iterator with fields: `index`, `name`, `format`, `value`
---@return self
function CustomSourcesList:SetData(iter)
	wipe(self._name)
	wipe(self._format)
	wipe(self._value)
	for _, name, format, value in iter do
		assert(type(name) == "string")
		assert(type(format) == "string" and TABLE_FORMAT_TEXT[format])
		assert(type(value) == "string")
		tinsert(self._name, name)
		self._format[name] = format
		self._value[name] = value
	end
	self:_RecreateRows(#self._name)
	return self
end

---Adds a custom source.
---@param name string The name
---@param format string The format
---@param value string The value
---@return self
function CustomSourcesList:AddRow(name, format, value)
	assert(type(format) == "string" and TABLE_FORMAT_TEXT[format])
	assert(type(value) == "string")
	local currentIndex, insertIndex = BinarySearch.Table(self._name, name)
	assert(currentIndex == nil and insertIndex ~= nil)
	tinsert(self._name, insertIndex, name)
	self._format[name] = format
	self._value[name] = value
	self:_AddRow(insertIndex)
	return self
end

---Updates an existing custom source.
---@param name string The name
---@param format string The format
---@param value string The value
---@return self
function CustomSourcesList:UpdateRow(name, format, value)
	assert(type(format) == "string" and TABLE_FORMAT_TEXT[format])
	assert(type(value) == "string")
	local index = Table.KeyByValue(self._name, name)
	assert(index)
	self._format[name] = format
	self._value[name] = value
	self:_DrawRows(index, index)
	return self
end

---Removes an existing custom source.
---@param name string The name
---@return self
function CustomSourcesList:RemoveRow(name)
	local index = Table.KeyByValue(self._name, name)
	assert(index)
	tremove(self._name, index)
	self._format[name] = nil
	self._value[name] = nil
	self:_RemoveRow(index)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function CustomSourcesList.__private:_CreateHeaderText(title)
	local text = self:_CreateFontString(self._header)
	text:SetHeight(HEADER_TEXT_HEIGHT)
	text:TSMSetFont("BODY_XSMALL")
	text:SetJustifyH("LEFT")
	text:SetText(title)
	return text
end

---@param row ListRow
function CustomSourcesList.__protected:_HandleRowAcquired(row)
	local name = row:AddText("name")
	name:SetSize(NAME_COL_WIDTH, self.ROW_HEIGHT)
	name:TSMSetFont("BODY_XSMALL")
	name:SetJustifyH("LEFT")

	local format = row:AddText("format")
	format:SetSize(FORMAT_COL_WIDTH, self.ROW_HEIGHT)
	format:TSMSetFont("BODY_XSMALL")
	format:SetJustifyH("LEFT")

	local value = row:AddText("value")
	value:SetHeight(self.ROW_HEIGHT)
	value:TSMSetFont("BODY_XSMALL")
	value:SetJustifyH("LEFT")

	local edit = row:AddTexture("edit")
	edit:TSMSetTextureAndSize(EDIT_TEXTURE)
	edit:Hide()

	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)
	delete:Hide()

	local colSpacing = Theme.GetColSpacing()
	local xOffset = colSpacing / 2
	name:SetPoint("LEFT", xOffset, 0)
	xOffset = xOffset + NAME_COL_WIDTH + colSpacing
	format:SetPoint("LEFT", xOffset, 0)
	xOffset = xOffset + FORMAT_COL_WIDTH + colSpacing
	value:SetPoint("LEFT", xOffset, 0)
	value:SetPoint("RIGHT", -colSpacing, 0)
	delete:SetPoint("RIGHT", -colSpacing, 0)
	edit:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
end

---@param row ListRow
function CustomSourcesList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local name = self._name[dataIndex]
	row:GetText("name"):SetText(name)
	row:GetText("format"):SetText(TABLE_FORMAT_TEXT[self._format[name]])
	row:GetText("value"):SetText(self._value[name])
end

---@param row ListRow
function CustomSourcesList.__protected:_HandleRowEnter(row)
	local value = row:GetText("value")
	local edit = row:GetTexture("edit")
	value:SetPoint("RIGHT", edit, "LEFT", -ICON_SPACING, 0)
	edit:Show()
	row:GetTexture("delete"):Show()
end

---@param row ListRow
function CustomSourcesList.__protected:_HandleRowLeave(row)
	row:GetText("value"):SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	row:GetTexture("edit"):Hide()
	row:GetTexture("delete"):Hide()
end

---@param row ListRow
function CustomSourcesList.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	if row:GetTexture("edit"):IsMouseOver() then
		self:_SendActionScript("OnEdit", self._name[dataIndex])
	elseif row:GetTexture("delete"):IsMouseOver() then
		self:_SendActionScript("OnDelete", self._name[dataIndex])
	end
end

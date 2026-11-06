-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ICON_SPACING = 4
local FAVORITE_TEXTURE = "iconPack.18x18/Star/Filled"
local NON_FAVORITE_TEXTURE = "iconPack.18x18/Star/Unfilled"
local EDIT_TEXTURE = "iconPack.18x18/Edit"
local DELETE_TEXTURE = "iconPack.18x18/Delete"



-- ============================================================================
-- Element Definition
-- ============================================================================

local SearchList = ComponentRegistry.Define("SearchList", "List")
SearchList.ROW_HEIGHT = 24
SearchList:_AddActionScripts("OnRowClick", "OnFavoriteChanged", "OnEdit", "OnDelete")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SearchList:__init()
	self.__super:__init()
	self._query = nil ---@type DatabaseQuery!
	self._name = {}
	self._isFavorite = {}
	self._index = {}
	self._editEnabled = nil
end

function SearchList:Release()
	if self._query then
		self._query:Release()
		self._query = nil
	end
	wipe(self._name)
	wipe(self._isFavorite)
	wipe(self._index)
	self._editEnabled = nil
	self.__super:Release()
end

---Sets whether or not editing is enabled.
---@param enabled boolean Whether or not the editing is enabled
---@return self
function SearchList:SetEditEnabled(enabled)
	assert(self._editEnabled == nil and type(enabled) == "boolean")
	self._editEnabled = enabled
	return self
end

---Sets the query used to populate the list.
---@param query DatabaseQuery The query object
---@return self
function SearchList:SetQuery(query)
	if self._query then
		self._query:Release()
	end
	self._query = query
	self._query:SetUpdateCallback(self:__closure("_HandleQueryUpdate"))
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SearchList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._name)
	wipe(self._isFavorite)
	wipe(self._index)
	for _, name, isFavorite, index in self._query:Iterator("name", "isFavorite", "index") do
		tinsert(self._name, name)
		tinsert(self._isFavorite, isFavorite)
		tinsert(self._index, index)
	end
	self:_SetNumRows(#self._name)
	self:Draw()
end

---@param row ListRow
function SearchList.__protected:_HandleRowAcquired(row)
	assert(self._editEnabled ~= nil)

	-- Name text
	local text = row:AddText("name")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("BODY_SMALL")
	text:SetJustifyH("LEFT")

	-- Favorite icon
	local favorite = row:AddTexture("favorite")
	favorite:TSMSetTextureAndSize(NON_FAVORITE_TEXTURE)
	favorite:Hide()

	-- Edit icon
	local edit = nil
	if self._editEnabled then
		edit = row:AddTexture("edit")
		edit:TSMSetTextureAndSize(EDIT_TEXTURE)
		edit:Hide()
	end

	-- Delete icon
	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)
	delete:Hide()

	-- Layout the elements
	local colSpacing = Theme.GetColSpacing()
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
	delete:SetPoint("RIGHT", -colSpacing, 0)
	if edit then
		edit:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
	end
	favorite:SetPoint("RIGHT", edit or delete, "LEFT", -ICON_SPACING, 0)
end

---@param row ListRow
function SearchList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("name"):SetText(self._name[dataIndex])
	row:GetTexture("favorite"):TSMSetTexture(self._isFavorite[dataIndex] and FAVORITE_TEXTURE or NON_FAVORITE_TEXTURE)
end

---@param row ListRow
function SearchList.__protected:_HandleRowEnter(row)
	local text = row:GetText("name")
	local favorite = row:GetTexture("favorite")
	text:SetPoint("RIGHT", favorite, "LEFT", -ICON_SPACING, 0)
	favorite:Show()
	if self._editEnabled then
		row:GetTexture("edit"):Show()
	end
	row:GetTexture("delete"):Show()
	row:ShowDelayedLongTextTooltip(text)
end

---@param row ListRow
function SearchList.__protected:_HandleRowLeave(row)
	row:GetText("name"):SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	row:GetTexture("favorite"):Hide()
	if self._editEnabled then
		row:GetTexture("edit"):Hide()
	end
	row:GetTexture("delete"):Hide()
	TooltipUI.Hide()
end

---@param row ListRow
function SearchList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	if row:GetTexture("favorite"):IsMouseOver() then
		self:_SendActionScript("OnFavoriteChanged", self._index[dataIndex], not self._isFavorite[dataIndex])
	elseif self._editEnabled and row:GetTexture("edit"):IsMouseOver() then
		self:_SendActionScript("OnEdit", self._index[dataIndex], self._name[dataIndex])
	elseif row:GetTexture("delete"):IsMouseOver() then
		self:_SendActionScript("OnDelete", self._index[dataIndex])
	else
		self:_SendActionScript("OnRowClick", self._index[dataIndex])
	end
end

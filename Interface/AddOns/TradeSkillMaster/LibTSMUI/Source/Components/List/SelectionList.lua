-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SelectionList = ComponentRegistry.Define("SelectionList", "List")
SelectionList:_AddActionScripts("OnEntrySelected")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SelectionList:__init()
	self.__super:__init()
	self._entries = {}
	self._selectedEntry = nil
end

function SelectionList:Release()
	wipe(self._entries)
	self._selectedEntry = nil
	self.__super:Release()
end

---Sets the entries.
---@param entries string[] A list of entries
---@param selectedEntry? string The selected entry
---@return self
function SelectionList:SetEntries(entries, selectedEntry)
	wipe(self._entries)
	for _, entry in ipairs(entries) do
		tinsert(self._entries, entry)
	end
	self._selectedEntry = selectedEntry
	self:_SetNumRows(#self._entries)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function SelectionList.__protected:_HandleRowAcquired(row)
	local text = row:AddText("name")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("BODY_SMALL")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", Theme.GetColSpacing() / 2, 0)
	text:SetPoint("RIGHT", -Theme.GetColSpacing() / 2, 0)
end

---@param row ListRow
function SelectionList.__protected:_HandleRowEnter(row)
	local text = row:GetText("name")
	row:ShowDelayedLongTextTooltip(text)
end

---@param row ListRow
function SelectionList.__protected:_HandleRowLeave(row)
	row:GetText("name"):SetPoint("RIGHT", -Theme.GetColSpacing() / 2, 0)
	TooltipUI.Hide()
end

---@param row ListRow
function SelectionList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local entry = self._entries[dataIndex]
	local text = row:GetText("name")
	text:TSMSetTextColor(entry == self._selectedEntry and "accent/main" or "on/surface")
	text:SetText(entry)
end

---@param row ListRow
function SelectionList.__protected:_HandleRowClick(row)
	self:_SendActionScript("OnEntrySelected", self._entries[row:GetDataIndex()])
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local Crafting = LibTSMUI:From("LibTSMService"):Include("Crafting")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local IgnoredCooldownList = ComponentRegistry.Define("IgnoredCooldownList", "List")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function IgnoredCooldownList:__init()
	self.__super:__init()
	self._query = nil ---@type DatabaseQuery!
	self._characterKey = {}
	self._craftString = {}
	self._text = {}
end

function IgnoredCooldownList:Acquire()
	self.__super:Acquire()
	self._query = Crafting.CreateIgnoredCooldownsQuery()
	self:AddCancellable(self._query:Publisher()
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
end

function IgnoredCooldownList:Release()
	local query = self._query
	self._query = nil
	wipe(self._characterKey)
	wipe(self._craftString)
	wipe(self._text)
	self.__super:Release()
	query:Release()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function IgnoredCooldownList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._characterKey)
	wipe(self._craftString)
	wipe(self._text)
	for _, characterKey, craftString, name in self._query:Iterator("characterKey", "craftString", "name") do
		tinsert(self._characterKey, characterKey)
		tinsert(self._craftString, craftString)
		tinsert(self._text, characterKey.." - "..name)
	end
	self:_SetNumRows(#self._text)
	self:Draw()
end

---@param row ListRow
function IgnoredCooldownList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(self.ROW_HEIGHT)
	text:TSMSetFont("BODY_XSMALL")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function IgnoredCooldownList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("text"):SetText(self._text[dataIndex])
end

---@param row ListRow
function IgnoredCooldownList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	Crafting.RemoveIgnoredCooldown(self._characterKey[dataIndex], self._craftString[dataIndex])
end

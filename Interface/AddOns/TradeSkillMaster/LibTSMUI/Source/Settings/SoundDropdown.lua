-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local SoundAlert = LibTSMUI:From("LibTSMWoW"):Include("UI.SoundAlert")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local SoundDropdown = ComponentRegistry.Define("SoundDropdown", "BaseDropdown")
SoundDropdown._STATE_SCHEMA = SoundDropdown._STATE_SCHEMA:Extend("SoundDropdownState")
	:AddStringField("selectedDescription", UIUtils.GetSoundDescription(SoundAlert.NO_SOUND_KEY))
	:UpdateFieldDefault("hintText", L["Select sound"])
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SoundDropdown:__init()
	self.__super:__init(false)
	self._keyLookup = {}
	self._state:Publisher("selectedDescription")
		:AssignToTableKey(self._state, "currentSelectionStr")
end

function SoundDropdown:Acquire()
	self.__super:Acquire()
	for _, key in SoundAlert.KeyIterator() do
		local description = UIUtils.GetSoundDescription(key)
		assert(not self._keyLookup[description] and not Table.KeyByValue(self._keyLookup, key))
		tinsert(self._items, description)
		self._keyLookup[description] = key
	end
	sort(self._items, private.SortHelper)
end

function SoundDropdown:Release()
	wipe(self._keyLookup)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the setting info to have the value of the dropdown automatically correspond with the value of a field in a settings table.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the dropdown state
---@return self
function SoundDropdown:SetSettingInfo(tbl, key)
	self._state.selectedDescription = UIUtils.GetSoundDescription(tbl[key] or SoundAlert.NO_SOUND_KEY)
	self._state:Publisher("selectedDescription")
		:Map(self._keyLookup)
		:AssignToTableKey(tbl, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<SoundDropdownState>
---@param state SoundDropdownState
function SoundDropdown.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_SELECTION_CHANGED" then
		local selection = ...
		self:GetBaseElement():HideDialog()
		state.selectedDescription = selection
		SoundAlert.Play(self._keyLookup[selection])
		self:Draw()
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end

function SoundDropdown.__protected:_GetDialogSelection()
	return self._state.selectedDescription
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SortHelper(a, b)
	local noSoundDesc = UIUtils.GetSoundDescription(SoundAlert.NO_SOUND_KEY)
	if a == noSoundDesc then
		return true
	elseif b == noSoundDesc then
		return false
	else
		return a < b
	end
end

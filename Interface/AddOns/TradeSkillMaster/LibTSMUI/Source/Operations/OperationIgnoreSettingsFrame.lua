-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local private = {
	factionrealmList = {},
	characterList = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationIgnoreSettingsFrame = ComponentRegistry.Define("OperationIgnoreSettingsFrame", "SettingsCollapsibleContainer")
OperationIgnoreSettingsFrame._STATE_SCHEMA = OperationIgnoreSettingsFrame._STATE_SCHEMA:Extend("OperationIgnoreSettingsFrameState")
	:AddDeferredUIElementField("factionrealmDropdown", "MultiselectionDropdown")
	:AddDeferredUIElementField("characterDropdown", "MultiselectionDropdown")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationIgnoreSettingsFrame:__init()
	self.__super:__init()
	self._typeName = nil
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_REBUILD_DB")
end

function OperationIgnoreSettingsFrame:Acquire()
	self.__super:Acquire()
	self:SetLargeHeading()
	self:SetHeadingDescription(L["Management Options"], L["Below you can ignore this operation on certain characters or realms."])
	self:AddChild(UIElements.New("SettingsField", "ignoreFactionRealms")
		:SetMargin(0, 0, 0, 12)
		:SetManager(self._childManager)
		:SetLabel(L["Ignore operation on faction-realms"])
		:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
			:SetHeight(24)
			:BindElement(self._state, "factionrealmDropdown")
			:SetSelectionText(L["No Faction-Realms"], L["%d Faction-Realms"], L["All Faction-Realms"])
			:SetHintText(L["Select faction-realms"])
			:SetAction("OnSelectionChanged", "ACTION_REBUILD_DB")
			:SetTooltip(L["This operation will be ignored on any of the selected faction-realms."])
		)
	)
	self:AddChild(UIElements.New("SettingsField", "ignoreCharacters")
		:SetManager(self._childManager)
		:SetLabel(L["Ignore operation on characters"])
		:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
			:SetHeight(24)
			:BindElement(self._state, "characterDropdown")
			:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
			:SetHintText(L["Select characters"])
			:SetAction("OnSelectionChanged", "ACTION_REBUILD_DB")
			:SetTooltip(L["This operation will be ignored on any of the selected characters."])
		)
	)
end

function OperationIgnoreSettingsFrame:Release()
	self._typeName = nil
	self.__super:Release()
end

---Configures the operation ignore settings frame.
---@param typeName string The operation type name
---@param operationName string The operation name
---@param settingsDB SettingsDB The settings DB to use to get the available factionrealms and characters
---@return self
function OperationIgnoreSettingsFrame:Configure(typeName, operationName, settingsDB)
	assert(not self._typeName)
	self._typeName = typeName

	assert(not next(private.factionrealmList) and not next(private.characterList))
	for _, factionrealm in settingsDB:ScopeKeyIterator("factionrealm") do
		tinsert(private.factionrealmList, factionrealm)
		for _, character in settingsDB:AccessibleCharacterIterator(nil, factionrealm) do
			tinsert(private.characterList, character.." - "..factionrealm)
		end
	end
	Table.Sort(private.factionrealmList)
	Table.Sort(private.characterList)

	local operationSettings = Operation.GetSettings(typeName, operationName)
	self._state.factionrealmDropdown
		:SetItems(private.factionrealmList, private.factionrealmList)
		:SetSettingInfo(operationSettings, "ignoreFactionrealm")
	self._state.characterDropdown
		:SetItems(private.characterList, private.characterList)
		:SetSettingInfo(operationSettings, "ignorePlayer")

	wipe(private.factionrealmList)
	wipe(private.characterList)
	return self
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

---@param manager UIManager<OperationIgnoreSettingsFrameState>
---@param state OperationIgnoreSettingsFrameState
function OperationIgnoreSettingsFrame.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_REBUILD_DB" then
		GroupOperation.RebuildDB()
	else
		error("Unknown action: "..tostring(action))
	end
end

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
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ICON_SPACING = 4
local CHECKED_TEXTURE = "iconPack.Misc/Checkbox/Checked"
local UNCHECKED_TEXTURE = "iconPack.Misc/Checkbox/Unchecked"
local RESET_TEXTURE = "iconPack.18x18/Reset"
local RENAME_TEXTURE = "iconPack.18x18/Edit"
local DUPLICATE_TEXTURE = "iconPack.18x18/Duplicate"
local DELETE_TEXTURE = "iconPack.18x18/Delete"

---@alias ProfilesListNameValidateFunc fun(name: string): boolean
---@alias ProfilesListDuplicateNameFunc fun(profile: string): string



-- ============================================================================
-- Element Definition
-- ============================================================================

local ProfilesList = ComponentRegistry.Define("ProfilesList", "StaticList")
ProfilesList.ROW_HEIGHT = 28
ProfilesList._STATE_SCHEMA = ProfilesList._STATE_SCHEMA:Extend("ProfilesListState")
	:AddDeferredUIElementField("renameInput", "Input")
	:AddStringField("renamePrevValue", "")
	:AddStringField("renameValue", "")
	:AddOptionalStringField("activeProfile")
	:Commit()
ProfilesList:_AddActionScripts("OnReset", "OnRename", "OnDuplicate", "OnDelete", "OnActivated")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ProfilesList:__init()
	self.__super:__init()
	self._nameValidateFunc = nil ---@type ProfilesListNameValidateFunc!
	self._duplicateNameFunc = nil ---@type ProfilesListDuplicateNameFunc!
	self._data = {}
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function ProfilesList:Release()
	self._nameValidateFunc = nil
	self._duplicateNameFunc = nil
	wipe(self._data)
	self.__super:Release()
end

---Configures the profiles list.
---@param settingsDB SettingsDB The settings DB object
---@param nameValidateFunc ProfilesListNameValidateFunc A function to validate a new profile name
---@param duplicateNameFunc ProfilesListDuplicateNameFunc A function to get the name of a new profile which duplicates an existing one
---@return self
function ProfilesList:Configure(settingsDB, nameValidateFunc, duplicateNameFunc)
	self._nameValidateFunc = nameValidateFunc
	self._duplicateNameFunc = duplicateNameFunc
	wipe(self._data)
	for _, profile in settingsDB:ScopeKeyIterator("profile") do
		tinsert(self._data, profile)
	end
	self:_RecreateRows(#self._data)
	self:_FunctionPublisher(settingsDB:CurrentProfilePublisher(), self:__closure("_HandleActiveProfileChanged"))
	return self
end

---Adds a new profile at the end of the list.
---@param profile string The name of the profile
---@return self
function ProfilesList:AddProfile(profile)
	tinsert(self._data, profile)
	self:_AddRow(#self._data)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<ProfilesListState>
---@param state ProfilesListState
function ProfilesList.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_RESET" then
		local profile = ...
		local desc = format(L["This will reset all groups and operations (if not stored globally) to be wiped from '%s'."], profile)
		self:GetBaseElement():ShowConfirmationDialog(L["Reset Profile?"], desc, manager:CallbackToProcessAction("ACTION_RESET_CONFIRMED"), profile)
	elseif action == "ACTION_RESET_CONFIRMED" then
		local profile = ...
		self:_SendActionScript("OnReset", profile)
	elseif action == "ACTION_RENAME" then
		local profile = ...
		state.renamePrevValue = profile
		state.renameValue = profile
		self:GetBaseElement():ShowDialogFrame(self:_CreateRenameDialog())
		assert(state.renameInput)
		state.renameInput:SetFocused(true)
	elseif action == "ACTION_RENAME_CONFIRMED" then
		local prevProfileName = state.renamePrevValue
		local newProfileName = state.renameValue
		if newProfileName == prevProfileName then
			-- Didn't change the name, so just hide the dialog
			self:GetBaseElement():HideDialog()
			return
		elseif not self._nameValidateFunc(newProfileName) then
			return
		end
		self:GetBaseElement():HideDialog()
		local index = self:_GetProfileDataIndex(prevProfileName)
		self._data[index] = newProfileName
		self:_DrawRowName(self._rowElements[index], newProfileName)
		self:_SendActionScript("OnRename", prevProfileName, newProfileName)
	elseif action == "ACTION_DUPLICATE" then
		-- Get the new profile name
		local profile = ...
		local newProfile = self._duplicateNameFunc(profile)
		tinsert(self._data, newProfile)
		self:_AddRow(#self._data)
		self:_SendActionScript("OnDuplicate", profile, newProfile)
	elseif action == "ACTION_DELETE" then
		local profile = ...
		local desc = format(L["This will permanently delete the '%s' profile."], profile)
		self:GetBaseElement():ShowConfirmationDialog(L["Delete Profile?"], desc, manager:CallbackToProcessAction("ACTION_DELETE_CONFIRMED"), profile)
	elseif action == "ACTION_DELETE_CONFIRMED" then
		local profile = ...
		assert(profile ~= state.activeProfile)
		local index = self:_GetProfileDataIndex(profile)
		tremove(self._data, index)
		self:_RemoveRow(index)
		self:_SendActionScript("OnDelete", profile)
	elseif action == "ACTION_SET_ACTIVE" then
		local profile = ...
		if profile == state.activeProfile then
			return
		end
		self:_SendActionScript("OnActivated", profile)
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param row ListRow
function ProfilesList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()

	local checkbox = row:AddTexture("checkbox")
	checkbox:TSMSetTextureAndSize(CHECKED_TEXTURE)
	checkbox:SetPoint("LEFT", colSpacing / 2, 0)

	local name = row:AddText("name")
	name:SetHeight(self.ROW_HEIGHT)
	name:TSMSetFont("BODY_XSMALL")
	name:SetJustifyH("LEFT")
	name:SetPoint("LEFT", checkbox, "RIGHT", colSpacing, 0)
	name:SetPoint("RIGHT", -colSpacing / 2, 0)

	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)
	delete:SetPoint("RIGHT", -colSpacing / 2, 0)
	delete:Hide()
	row:AddTooltipRegion("deleteTooltip", delete, self:__closure("_GetIconTooltip"))

	local duplicate = row:AddTexture("duplicate")
	duplicate:TSMSetTextureAndSize(DUPLICATE_TEXTURE)
	duplicate:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
	duplicate:Hide()
	row:AddTooltipRegion("duplicateTooltip", duplicate, self:__closure("_GetIconTooltip"))

	local rename = row:AddTexture("rename")
	rename:TSMSetTextureAndSize(RENAME_TEXTURE)
	rename:SetPoint("RIGHT", duplicate, "LEFT", -ICON_SPACING, 0)
	rename:Hide()
	row:AddTooltipRegion("renameTooltip", rename, self:__closure("_GetIconTooltip"))

	local reset = row:AddTexture("reset")
	reset:TSMSetTextureAndSize(RESET_TEXTURE)
	reset:SetPoint("RIGHT", rename, "LEFT", -ICON_SPACING, 0)
	reset:Hide()
	row:AddTooltipRegion("resetTooltip", reset, self:__closure("_GetIconTooltip"))
end

---@param row ListRow
function ProfilesList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local profile = self._data[dataIndex]
	self:_DrawRowName(row, profile)
	self:_DrawRowSelectedState(row, profile == self._state.activeProfile)
end

function ProfilesList.__private:_DrawRowName(row, name)
	row:GetText("name"):SetText(name)
end

---@param row ListRow
function ProfilesList.__private:_DrawRowSelectedState(row, selected)
	row:GetTexture("checkbox"):TSMSetTextureAndSize(selected and CHECKED_TEXTURE or UNCHECKED_TEXTURE)
	local colSpacing = Theme.GetColSpacing()
	-- Hide the delete icon if the row is selected
	local delete = row:GetTexture("delete")
	if selected then
		-- Move the delete icon off to the right so its tooltip button doesn't overlap with the duplicate icon
		delete:SetPoint("RIGHT", -colSpacing / 2 + (delete:GetWidth() + colSpacing), 0)
		delete:Hide()
	else
		delete:SetPoint("RIGHT", -colSpacing / 2, 0)
		delete:TSMSetShown(row:IsHovering())
	end
end

---@param row ListRow
function ProfilesList.__protected:_HandleRowEnter(row)
	local name = row:GetText("name")
	local reset = row:GetTexture("reset")
	name:SetPoint("RIGHT", reset, "LEFT", -ICON_SPACING, 0)
	reset:Show()
	row:GetTexture("rename"):Show()
	row:GetTexture("duplicate"):Show()
	if self._data[row:GetDataIndex()] ~= self._state.activeProfile then
		row:GetTexture("delete"):Show()
	end
end

---@param row ListRow
function ProfilesList.__protected:_HandleRowLeave(row)
	row:GetText("name"):SetPoint("RIGHT", -Theme.GetColSpacing() / 2, 0)
	row:GetTexture("reset"):Hide()
	row:GetTexture("rename"):Hide()
	row:GetTexture("duplicate"):Hide()
	row:GetTexture("delete"):Hide()
end

---@param row ListRow
function ProfilesList.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local profile = self._data[dataIndex]
	if row:GetTexture("reset"):IsMouseOver() then
		self._childManager:ProcessAction("ACTION_RESET", profile)
	elseif row:GetTexture("rename"):IsMouseOver() then
		self._childManager:ProcessAction("ACTION_RENAME", profile)
	elseif row:GetTexture("duplicate"):IsMouseOver() then
		self._childManager:ProcessAction("ACTION_DUPLICATE", profile)
	elseif row:GetTexture("delete"):IsMouseOver() then
		self._childManager:ProcessAction("ACTION_DELETE", profile)
	else
		self._childManager:ProcessAction("ACTION_SET_ACTIVE", profile)
	end
end

function ProfilesList.__private:_GetIconTooltip(_, key)
	if key == "resetTooltip" then
		return L["Reset the current profile to default settings"]
	elseif key == "renameTooltip" then
		return L["Rename the profile"]
	elseif key == "duplicateTooltip" then
		return L["Duplicate the profile"]
	elseif key == "deleteTooltip" then
		return L["Delete the profile"]
	else
		error("Invalid tooltip key: "..tostring(key))
	end
end

function ProfilesList.__private:_GetProfileDataIndex(profile)
	local index = Table.KeyByValue(self._data, profile)
	assert(index)
	return index
end

function ProfilesList.__private:_HandleActiveProfileChanged(activeProfile)
	local prevActiveProfile = self._state.activeProfile
	-- In the case of a rename, the previous profile would no longer be in the data
	if prevActiveProfile and tContains(self._data, prevActiveProfile) then
		self:_DrawRowSelectedState(self._rowElements[self:_GetProfileDataIndex(prevActiveProfile)], false)
	end
	self:_DrawRowSelectedState(self._rowElements[self:_GetProfileDataIndex(activeProfile)], true)
	self._state.activeProfile = activeProfile
end

function ProfilesList.__private:_CreateRenameDialog()
	local dialog = nil
	for _ in self._state:WithAutoStorePaused() do
		dialog = UIElements.New("BaseFrame", "frame")
			:SetLayout("VERTICAL")
			:SetSize(600, 185)
			:AddAnchor("CENTER")
			:SetBackgroundColor("container/low")
			:SetBorderColor("outline/variant")
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Text", "title")
				:SetHeight(44)
				:SetMargin(16, 16, 24, 16)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Rename Profile"])
			)
			:AddChild(UIElements.New("Input", "input")
				:SetHeight(24)
				:SetMargin(16, 16, 0, 25)
				:BindElement(self._state, "renameInput")
				:MirrorValueState(self._state, "renameValue")
				:SetAction("OnEnterPressed", "ACTION_RENAME_CONFIRMED")
			)
			:AddChild(UIElements.New("BaseFrame", "buttons")
				:SetLayout("HORIZONTAL")
				:SetMargin(16, 16, 0, 16)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("MediumPrimaryActionButton", "closeBtn")
					:SetWidth(126)
					:SetText(CLOSE)
					:SetAction("OnClick", "ACTION_RENAME_CONFIRMED")
				)
			)
	end
	return dialog
end

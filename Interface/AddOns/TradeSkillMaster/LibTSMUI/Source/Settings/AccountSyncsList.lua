-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TooltipUI = LibTSMUI:Include("TooltipUI")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Crafting = LibTSMUI:From("LibTSMService"):Include("Crafting")
local TransactionSync = LibTSMUI:From("LibTSMService"):Include("Ledger.TransactionSync")
local Sync = LibTSMUI:From("LibTSMService"):Include("Sync")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local NEW_ACCOUNT = newproxy(false)
local STATUS_TOOLTIP_X_OFFSET = 52
local ICON_SPACING = 4
local DELETE_TEXTURE = "iconPack.18x18/Delete"
local SEND_PROFILE_TEXTURE = "iconPack.18x18/Operation"
local private = {}

---@alias AccountSyncsListCharacterIterFunc fun(account: string): IteratorObject



-- ============================================================================
-- Element Definition
-- ============================================================================

local AccountSyncsList = ComponentRegistry.Define("AccountSyncsList", "StaticList")
AccountSyncsList.ROW_HEIGHT = 28
AccountSyncsList._STATE_SCHEMA = AccountSyncsList._STATE_SCHEMA:Extend("AccountSyncsListState")
	:UpdateFieldDefault("backgroundColor", "container/lowest")
	:Commit()
AccountSyncsList:_AddActionScripts("OnSendProfile", "OnRemove")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AccountSyncsList:__init()
	self.__super:__init()
	self._characterIterFunc = nil ---@type AccountSyncsListCharacterIterFunc!
	self._data = {}
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	Sync.RegisterConnectionChangedCallback(self._childManager:CallbackToProcessAction("ACTION_CONNECTION_CHANGED"))
end

function AccountSyncsList:Release()
	wipe(self._data)
	self._characterIterFunc = nil
	self.__super:Release()
end

---Configures the account syncs list.
---@param settingsDB SettingsDB The settings DB object
---@param characterIterFunc AccountSyncsListCharacterIterFunc A function which returns an iterator object with fields: `index`, `character`
---@return self
function AccountSyncsList:Configure(settingsDB, characterIterFunc)
	self._characterIterFunc = characterIterFunc
	wipe(self._data)
	if Sync.GetConnectingCharacter() then
		tinsert(self._data, NEW_ACCOUNT)
	end
	for _, account in settingsDB:SyncAccountIterator() do
		tinsert(self._data, account)
	end
	self:_RecreateRows(#self._data)
	return self
end

---Adds a row for a new connection.
---@return self
function AccountSyncsList:AddNewConnection()
	-- Add a new account row at the top
	if self._data[1] == NEW_ACCOUNT then
		-- Replacing the existing new account
		self:_DrawRowStatus(self._rowElements[1])
	else
		-- Add a new account row at the top
		tinsert(self._data, 1, NEW_ACCOUNT)
		self:_AddRow(1)
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager<AccountSyncsListState>
---@param state AccountSyncsListState
function AccountSyncsList.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CONNECTION_CHANGED" then
		local account = ...
		if not state.acquired then
			return
		end
		local existingIndex = Table.KeyByValue(self._data, account)
		local newAccountIndex = Table.KeyByValue(self._data, NEW_ACCOUNT)
		if existingIndex then
			self:_DrawRowStatus(self._rowElements[existingIndex])
		elseif newAccountIndex then
			if not Sync.GetConnectingCharacter() then
				-- New connection established
				self._data[newAccountIndex] = account
			end
			self:_DrawRowStatus(self._rowElements[newAccountIndex])
		end
	elseif action == "ACTION_DELETE" then
		local account = ...
		local index = Table.KeyByValue(self._data, account)
		assert(index)
		tremove(self._data, index)
		self:_RemoveRow(index)
		self:_SendActionScript("OnRemove", account)
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param row ListRow
function AccountSyncsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()

	local status = row:AddText("status")
	status:SetHeight(self.ROW_HEIGHT)
	status:TSMSetFont("BODY_SMALL")
	status:SetJustifyH("LEFT")
	status:SetPoint("LEFT", colSpacing / 2, 0)
	status:SetPoint("RIGHT", -colSpacing / 2, 0)
	row:AddTooltipRegion("statusTooltip", status, self:__closure("_GetTooltip"))

	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)
	delete:SetPoint("RIGHT", -colSpacing / 2, 0)
	delete:Hide()
	row:AddTooltipRegion("deleteTooltip", delete, self:__closure("_GetTooltip"))

	local sendProfile = row:AddTexture("sendProfile")
	sendProfile:TSMSetTextureAndSize(SEND_PROFILE_TEXTURE)
	sendProfile:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
	sendProfile:Hide()
	row:AddTooltipRegion("sendProfileTooltip", sendProfile, self:__closure("_GetTooltip"))
end

---@param row ListRow
function AccountSyncsList.__protected:_HandleRowDraw(row)
	self:_DrawRowStatus(row)
end

function AccountSyncsList.__private:_DrawRowStatus(row)
	local account = self._data[row:GetDataIndex()]
	if account == NEW_ACCOUNT then
		row:GetText("status"):SetText(format(L["Connecting to %s"], Sync.GetConnectingCharacter() or "?"))
	else
		local characterStr = self._characterIterFunc(account):ToJoinedValueString(", ", true)
		local isConnected, connectedCharacter = Sync.GetConnectionStatus(account)
		assert(isConnected == (connectedCharacter ~= nil))
		local color = Theme.GetColor(connectedCharacter and "positive/main" or "error/main")
		local statusText = color:ColorText(connectedCharacter and format(L["Connected to %s"], connectedCharacter) or L["Offline"])
		row:GetText("status"):SetText(statusText.." | "..characterStr)
	end
end

---@param row ListRow
function AccountSyncsList.__protected:_HandleRowEnter(row)
	local account = self._data[row:GetDataIndex()]
	if account == NEW_ACCOUNT then
		return
	end
	local sendProfile = row:GetTexture("sendProfile")
	row:GetText("status"):SetPoint("RIGHT", sendProfile, "LEFT", -ICON_SPACING, 0)
	sendProfile:Show()
	row:GetTexture("delete"):Show()
end

---@param row ListRow
function AccountSyncsList.__protected:_HandleRowLeave(row)
	row:GetText("status"):SetPoint("RIGHT", -Theme.GetColSpacing() / 2, 0)
	row:GetTexture("sendProfile"):Hide()
	row:GetTexture("delete"):Hide()
end

---@param row ListRow
function AccountSyncsList.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local account = self._data[dataIndex]
	if row:GetTexture("sendProfile"):IsMouseOver() then
		self:_SendActionScript("OnSendProfile", account)
	elseif row:GetTexture("delete"):IsMouseOver() then
		self._childManager:ProcessAction("ACTION_DELETE", account)
	end
end

function AccountSyncsList.__private:_GetTooltip(dataIndex, key)
	if key == "statusTooltip" then
		local account = self._data[dataIndex]
		return private.GetStatusTooltip(account), nil, account and STATUS_TOOLTIP_X_OFFSET or nil
	elseif key == "sendProfileTooltip" then
		return L["Send your active profile to this synced account"]
	elseif key == "deleteTooltip" then
		return L["Remove this account sync and all synced data from this account"]
	else
		error("Invalid tooltip key: "..tostring(key))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetStatusTooltip(account)
	if account == NEW_ACCOUNT then
		return L["Establishing connection..."]
	end
	return strjoin("\n",
		Theme.GetColor("accent/main"):ColorText(L["Sync Status"]),
		L["Inventory / Gold Graph"]..TooltipUI.GetSepChar()..private.GetMirrorStatusText(account),
		L["Profession Info"]..TooltipUI.GetSepChar()..private.GetCraftingSyncStatusText(account),
		L["Purchase / Sale Info"]..TooltipUI.GetSepChar()..private.GetTransactionSyncStatusText(account)
	)
end

function private.GetMirrorStatusText(account)
	local mirrorConnected, mirrorSynced = Sync.GetMirrorStatus(account)
	if not mirrorConnected then
		return Theme.GetColor("error/main"):ColorText(L["Not Connected"])
	elseif not mirrorSynced then
		return Theme.GetColor("warning/main"):ColorText(L["Updating"])
	else
		return Theme.GetColor("positive/main"):ColorText(L["Up to date"])
	end
end

function private.GetCraftingSyncStatusText(account)
	local craftingSyncStatus = Crafting.GetSyncStatus(account)
	if not craftingSyncStatus then
		return Theme.GetColor("error/main"):ColorText(L["Not Connected"])
	elseif craftingSyncStatus == Crafting.SYNC_STATUS.UPDATING or craftingSyncStatus == Crafting.SYNC_STATUS.RETRY then
		return Theme.GetColor("warning/main"):ColorText(L["Updating"])
	elseif craftingSyncStatus == Crafting.SYNC_STATUS.SYNCED then
		return Theme.GetColor("positive/main"):ColorText(L["Up to date"])
	else
		error("Invalid status: "..tostring(craftingSyncStatus))
	end
end

function private.GetTransactionSyncStatusText(account)
	local transactionStatus = TransactionSync.GetStatus(account)
	if transactionStatus == TransactionSync.STATUS.NOT_CONNECTED then
		return Theme.GetColor("error/main"):ColorText(L["Not Connected"])
	elseif transactionStatus == TransactionSync.STATUS.UPDATING or transactionStatus == TransactionSync.STATUS.RETRY then
		return Theme.GetColor("warning/main"):ColorText(L["Updating"])
	elseif transactionStatus == TransactionSync.STATUS.SYNCED then
		return Theme.GetColor("positive/main"):ColorText(L["Up to date"])
	else
		error("Invalid status: "..tostring(transactionStatus))
	end
end

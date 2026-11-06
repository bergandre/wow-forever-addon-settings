-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ProfileSync = LibTSMApp:Init("Service.ProfileSync")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local Memory = LibTSMApp:From("LibTSMUtil"):Include("Lua.Memory")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Operation = LibTSMApp:From("LibTSMTypes"):Include("Operation")
local TimeFormat = LibTSMApp:From("LibTSMWoW"):Include("UI.TimeFormat")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Sync = LibTSMApp:From("LibTSMService"):Include("Sync")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local private = {
	settingsDB = nil,
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ProfileSync:OnModuleLoad(function()
	Sync.RegisterRPC("CREATE_PROFILE", private.RPCCreateProfile)
end)

AddonSettings.RegisterOnLoad(ProfileSync, function(db)
	private.settingsDB = db
	private.settings = db:NewView("ProfileSyncSettings")
		:AddKey("profile", "userData", "groups")
		:AddKey("profile", "userData", "items")
		:AddKey("profile", "userData", "operations")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sends the current profile to another character on another account.
---@param targetCharacter string The target character to send the profile to
function ProfileSync.Send(targetCharacter)
	local profileName = private.settingsDB:GetCurrentProfile()
	local data = {
		groups = {},
	}
	for groupPath, moduleOperations in pairs(private.settings:GetForScopeKey("groups", profileName)) do
		data.groups[groupPath] = {}
		for _, module in Operation.TypeIterator() do
			local operations = moduleOperations[module]
			if operations.override then
				data.groups[groupPath][module] = operations
			end
		end
	end
	data.items = private.settings:GetForScopeKey("items", profileName)
	data.operations = private.settings:GetForScopeKey("operations", profileName)
	local result, estimatedTime = Sync.CallRPC("CREATE_PROFILE", targetCharacter, private.RPCCreateProfileResultHandler, profileName, SessionInfo.GetCharacterName(), data)
	if result and estimatedTime then
		estimatedTime = max(Math.Round(estimatedTime, 60), 60)
		ChatMessage.PrintfUser(L["Sending your '%s' profile to %s. Please keep both characters online until this completes. This will take approximately: %s"], profileName, targetCharacter, TimeFormat.Duration(estimatedTime))
	else
		ChatMessage.PrintUser(L["Failed to send profile. Ensure both characters are online and try again."])
	end
	Memory.CollectGarbage()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RPCCreateProfile(profileName, character, data)
	assert(private.settingsDB:IsValidProfileName(profileName))
	if private.settingsDB:ProfileExists(profileName) then
		return false, L["A profile with that name already exists on the target account. Rename it first and try again."]
	end

	-- Create the new profile
	private.settingsDB:CreateProfile(profileName)

	-- Copy all the data into this new profile
	Table.CopyFrom(private.settings:GetForScopeKey("groups", profileName), data.groups)
	Table.CopyFrom(private.settings:GetForScopeKey("items", profileName), data.items)
	Table.CopyFrom(private.settings:GetForScopeKey("operations", profileName), data.operations)

	ChatMessage.PrintfUser(L["Added '%s' profile which was received from %s."], profileName, character)

	return true, profileName, SessionInfo.GetCharacterName()
end

function private.RPCCreateProfileResultHandler(_, _, success, ...)
	if success == nil then
		ChatMessage.PrintUser(L["Failed to send profile."].." "..L["Ensure both characters are online and try again."])
		return
	elseif not success then
		local errMsg = ...
		ChatMessage.PrintUser(L["Failed to send profile."].." "..errMsg)
		return
	end

	local profileName, targetCharacter = ...
	ChatMessage.PrintfUser(L["Successfully sent your '%s' profile to %s!"], profileName, targetCharacter)
end

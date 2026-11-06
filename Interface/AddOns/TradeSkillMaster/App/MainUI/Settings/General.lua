-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local General = App:Init("MainUI.Settings.General")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CustomString = App:From("LibTSMTypes"):Include("CustomString")
local ChatFrame = App:From("LibTSMWoW"):Include("API.ChatFrame")
local CharacterInfo = App:From("LibTSMWoW"):Include("Util.CharacterInfo")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local SessionInfo = App:From("LibTSMWoW"):Include("Util.SessionInfo")
local AppHelper = App:From("LibTSMService"):Include("AppHelper")
local Sync = App:From("LibTSMService"):Include("Sync")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local GroupOperationConfig = App:From("LibTSMApp"):Include("Config.GroupOperationConfig")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local ProfileSync = App:From("LibTSMApp"):Include("Service.ProfileSync")
local private = {
	settingsDB = nil,
	settings = nil,
	manager = nil,
	characterList = {},
	characterKeys = {},
	guildList = {},
	chatFrameList = {},
	destroySources = {},
	destroySourceKeys = {},
	altRealmSources = {},
	altRealmSourceKeys = {},
}
local INVALID_DESTROY_PRICE_SOURCES = {
	crafting = true,
	vendorbuy = true,
	vendorsell = true,
	destroy = true,
	itemquality = true,
	itemlevel = true,
	requiredlevel = true,
	numinventory = true,
	numexpires = true,
	salerate = true,
	dbregionsalerate = true,
	dbregionsoldperday = true,
	auctioningopmin = true,
	auctioningopmax = true,
	auctioningopnormal = true,
	shoppingopmax = true,
	sniperopmax = true,
}
local CHARACTER_SEP = "\001"
local SETTING_TOOLTIPS = {
	regionWide = L["If enabled, TSM will load data (i.e. inventory / Accounting / gold tracking) from every realm you have characters on, instead of just connected realms."],
	globalOperations = L["If this option is enabled any operation created will be stored by TSM without any association to a specific profile that is loaded at the time of creation. This means operations will be available to all profiles. Note: Storing operations globally will also mean no operations are included when sending a profile to a synced account."],
	groupPriceSource = L["This field defines the value to filter items in groups. Note: This field is not related to Shopping, Browsing, or Sniping the Auction House."],
	chatFrame = L["Select the chat tab to show TSM addon related messages."],
	forgetCharacter = L["Selecting any character in this drop down list will instruct TSM to forget everything known about it including professions, inventory, and current gold."],
	ignoreGuilds = L["Selecting any guild in this drop down will instruct TSM to disregard the contents of the guild bank for inventory tracking purposes."],
	destroyValueSource = L["Select from any available price source in this drop down list to change the way TSM values the results of destroying an item (i.e. disenchanting, prospecting, or milling)."],
	auctionDBAltRealm = L["Loads AuctionDB data for an additional realm for display in the tooltip and use in custom strings (via the 'DBAlt*' sources)."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("GeneralSettingsUIState")
	:AddDeferredUIElementField("frame", "BaseScrollFrame")
	:AddDeferredUIElementField("globalOperationsCheckbox", "Checkbox")
	:AddDeferredUIElementField("forgetDropdown", "SelectionDropdown")
	:AddDeferredUIElementField("profilesList", "ProfilesList")
	:AddDeferredUIElementField("accountSyncsList", "AccountSyncsList")
	:AddStringField("newProfile", "")
	:AddStringField("newAccountCharacter", "")
	:Commit()

---@event GeneralSettingsAction
---| "ACTION_RELOAD"
---| "ACTION_CHANGE_GLOBAL_OPERATIONS"
---| "ACTION_CHANGE_GLOBAL_OPERATIONS_CONFIRMED" -> value: boolean
---| "ACTION_SET_ACTIVE_CHAT_TAB"
---| "ACTION_FORGET_CHARACTER"
---| "ACTION_SHOW_ALT_REALM_DIALOG"
---| "ACTION_CLOSE_ALT_REALM_DIALOG"
---| "ACTION_RESET_PROFILE" -> profile: string
---| "ACTION_RENAME_PROFILE" -> prevProfileName: string, newProfileName: string
---| "ACTION_DUPLICATE_PROFILE" -> prevProfileName: string, newProfileName: string
---| "ACTION_DELETE_PROFILE" -> profile: string
---| "ACTION_SET_ACTIVE_PROFILE" -> profile: string
---| "ACTION_NEW_PROFILE"
---| "ACTION_CONNECT_ACCOUNT"
---| "ACTION_SEND_PROFILE" -> account: string
---| "ACTION_REMOVE_ACCOUNT" -> account: string



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(General, function(db)
	private.settingsDB = db
	private.settings = db:NewView("GeneralSettings")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "coreOptions", "globalOperations")
		:AddKey("global", "coreOptions", "protectAuctionHouse")
		:AddKey("global", "coreOptions", "chatFrame")
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:AddKey("factionrealm", "coreOptions", "ignoreGuilds")
		:AddKey("factionrealm", "internalData", "pendingMail")
		:AddKey("factionrealm", "internalData", "characterGuilds")
		:AddKey("realm", "coreOptions", "auctionDBAltRealm")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("GENERAL_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetGeneralSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the general settings frame.
---@return BaseScrollFrame
function General.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- General Settings UI
-- ============================================================================

---@param state GeneralSettingsUIState
function private.GetGeneralSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "general")
	state.newAccountCharacter = ""

	wipe(private.chatFrameList)
	ChatFrame.GetFrames(private.chatFrameList)
	if not tContains(private.chatFrameList, private.settings.chatFrame) then
		local defaultChatFrame = ChatFrame.GetDefault()
		if defaultChatFrame and tContains(private.chatFrameList, defaultChatFrame) then
			-- Reset the setting to the default
			private.settings.chatFrame = defaultChatFrame
			ChatFrame.SetActive(defaultChatFrame)
		else
			-- All chat frames are hidden, so just disable the setting
			wipe(private.chatFrameList)
		end
	end

	wipe(private.characterList)
	wipe(private.characterKeys)
	for _, character, factionrealm in PlayerInfo.CharacterIterator(true) do
		if not SessionInfo.IsPlayer(character, factionrealm) then
			local key = character..CHARACTER_SEP..factionrealm
			local name = SessionInfo.FormatCharacterName(character, factionrealm)
			tinsert(private.characterKeys, key)
			private.characterKeys[key] = name
			tinsert(private.characterList, name)
		end
	end
	Table.Sort(private.characterList)
	Table.SortWithValueLookup(private.characterKeys, private.characterKeys)

	wipe(private.guildList)
	for _, guild in PlayerInfo.GuildIterator(true) do
		tinsert(private.guildList, guild)
	end
	Table.Sort(private.guildList)

	wipe(private.destroySources)
	wipe(private.destroySourceKeys)
	local foundCurrentSetting = false
	for _, key, label in CustomString.SourceIterator() do
		key = strlower(key)
		if not INVALID_DESTROY_PRICE_SOURCES[key] then
			tinsert(private.destroySources, label)
			tinsert(private.destroySourceKeys, key)
			if private.settings.destroyValueSource == key then
				foundCurrentSetting = true
			end
		end
	end
	if not foundCurrentSetting then
		-- The current setting isn't in the list, so reset it to the default
		private.settings.destroyValueSource = strlower(private.settings:GetDefaultReadOnly("destroyValueSource"))
	end

	wipe(private.altRealmSources)
	wipe(private.altRealmSourceKeys)
	tinsert(private.altRealmSources, L["None"])
	tinsert(private.altRealmSourceKeys, "")
	for altRealm in AppHelper.AltRealmIterator() do
		tinsert(private.altRealmSources, altRealm)
		tinsert(private.altRealmSourceKeys, altRealm)
	end
	if not tContains(private.altRealmSourceKeys, private.settings.auctionDBAltRealm) then
		private.settings:ResetToDefault("auctionDBAltRealm")
	end

	return UIElements.New("BaseScrollFrame", "generalSettings")
		:SetPadding(8, 8, 8, 0)
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general TSM options are below."])
			:AddChildIf(App.IsRetail() or App.IsForever(), UIElements.New("BaseFrame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "regionWide")
					:SetWidth("AUTO")
					:SetText(L["Enable region-wide trading (requires reload)"])
					:SetSettingInfo(private.settings, "regionWide")
					:SetAction("OnValueChanged", "ACTION_RELOAD")
					:SetTooltip(SETTING_TOOLTIPS.regionWide, true)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("BaseFrame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "globalOperations")
					:SetWidth("AUTO")
					:SetText(L["Share operations between all profiles"])
					:SetChecked(private.settings.globalOperations)
					:BindElement(state, "globalOperationsCheckbox")
					:SetAction("OnValueChanged", "ACTION_CHANGE_GLOBAL_OPERATIONS")
					:SetTooltip(SETTING_TOOLTIPS.globalOperations, true)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChildIf(App.IsVanillaClassic() or App.IsBCClassic(), UIElements.New("BaseFrame", "check3")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "protectAuctionHouse")
					:SetWidth("AUTO")
					:SetText(L["Prevent closing the Auction House with the esc key"])
					:SetSettingInfo(private.settings, "protectAuctionHouse")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "generalGroupPriceField")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Filter group item lists based on the following price source"], SETTING_TOOLTIPS.groupPriceSource)
				:SetSettingInfo(private.settings, "groupPriceSource")
			)
			:AddChild(UIElements.New("BaseFrame", "dropdownLine")
				:SetLayout("HORIZONTAL")
				:SetHeight(46)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("SettingsField", "chatTab")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Chat Tab"])
					:AddChild(UIElements.New("SelectionDropdown", "chatTabDropdown")
						:SetHeight(24)
						:SetItems(private.chatFrameList, private.chatFrameList)
						:SetSettingInfo(private.settings, "chatFrame")
						:SetHintText(L["Select chat tab"])
						:SetAction("OnSelectionChanged", "ACTION_SET_ACTIVE_CHAT_TAB")
						:SetTooltip(SETTING_TOOLTIPS.chatFrame, true)
					)
				)
				:AddChild(UIElements.New("SettingsField", "forget")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Forget Character"])
					:AddChild(UIElements.New("SelectionDropdown", "forgetDropdown")
						:SetHeight(24)
						:SetItems(private.characterList, private.characterKeys)
						:SetHintText(L["Select character"])
						:BindElement(state, "forgetDropdown")
						:SetAction("OnSelectionChanged", "ACTION_FORGET_CHARACTER")
						:SetTooltip(SETTING_TOOLTIPS.forgetCharacter, true)
					)
				)
				:AddChild(UIElements.New("SettingsField", "ignore")
					:SetLabel(L["Ignore Guilds"])
					:AddChild(UIElements.New("MultiselectionDropdown", "ignoreDropdown")
						:SetHeight(24)
						:SetItems(private.guildList, private.guildList)
						:SetSettingInfo(private.settings, "ignoreGuilds")
						:SetSelectionText(L["No Guilds"], L["%d Guilds"], L["All Guilds"])
						:SetHintText(L["Select guilds"])
						:SetTooltip(SETTING_TOOLTIPS.ignoreGuilds, true)
					)
				)
			)
			:AddChild(UIElements.New("BaseFrame", "dropdownLine2")
				:SetLayout("HORIZONTAL")
				:SetHeight(46)
				:AddChild(UIElements.New("SettingsField", "destroy")
					:SetMargin(0, 8, 0, 0)
					:SetLabel(L["Destroy value source"])
					:AddChild(UIElements.New("SelectionDropdown", "destroyDropdown")
						:SetHeight(24)
						:SetItems(private.destroySources, private.destroySourceKeys)
						:SetSettingInfo(private.settings, "destroyValueSource")
						:SetHintText(L["Select source"])
						:SetTooltip(SETTING_TOOLTIPS.destroyValueSource, true)
					)
				)
				:AddChildIf(App.IsRetail() or App.IsForever(), UIElements.New("SettingsField", "altRealm")
					:SetLabel(L["AuctionDB data alternate realm"])
					:AddChild(UIElements.New("SelectionDropdown", "altRealmDropdown")
						:SetHeight(24)
						:SetItems(private.altRealmSources, private.altRealmSourceKeys)
						:SetSettingInfo(private.settings, "auctionDBAltRealm")
						:SetHintText(L["Select realm"])
						:SetTooltip(SETTING_TOOLTIPS.auctionDBAltRealm, true)
						:SetAction("OnSelectionChanged", "ACTION_SHOW_ALT_REALM_DIALOG")
					)
				)
				:AddChildIf(not App.IsRetail() and not App.IsForever(), UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "profiles")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Profiles"], L["Set your active profile or create a new one."])
			:AddChild(UIElements.New("ProfilesList", "list")
				:SetMargin(0, 0, 0, 12)
				:Configure(private.settingsDB, private.ValidateProfileName, private.GetDuplicateProfileName)
				:BindElement(state, "profilesList")
				:SetAction("OnReset", "ACTION_RESET_PROFILE")
				:SetAction("OnRename", "ACTION_RENAME_PROFILE")
				:SetAction("OnDuplicate", "ACTION_DUPLICATE_PROFILE")
				:SetAction("OnDelete", "ACTION_DELETE_PROFILE")
				:SetAction("OnActivated", "ACTION_SET_ACTIVE_PROFILE")
			)
			:AddChild(UIElements.New("SettingsField", "newProfile")
				:SetLabel(L["Create new profile"])
				:AddChild(UIElements.New("Input", "newProfileInput")
					:SetHeight(24)
					:SetHintText(L["Enter profile name"])
					:SetMaxLetters(64)
					:MirrorValueState(state, "newProfile")
					:SetAction("OnEnterPressed", "ACTION_NEW_PROFILE")
				)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "accountSync")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Account Syncing"], L["TSM can automatically sync data between multiple WoW accounts."])
			:AddChild(UIElements.New("AccountSyncsList", "list")
				:SetMargin(0, 0, 0, 12)
				:Configure(private.settingsDB, private.GetAccountCharacterIterator)
				:BindElement(state, "accountSyncsList")
				:SetAction("OnSendProfile", "ACTION_SEND_PROFILE")
				:SetAction("OnRemove", "ACTION_REMOVE_ACCOUNT")
			)
			:AddChild(UIElements.New("SettingsField", "addAccount")
				:SetLabel(L["Add account"])
				:AddChild(UIElements.New("Input", "newAccountInput")
					:SetHeight(24)
					:SetHintText(L["Enter name of logged-in character on other account"])
					:MirrorValueState(state, "newAccountCharacter")
					:SetAction("OnEnterPressed", "ACTION_CONNECT_ACCOUNT")
				)
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<GeneralSettingsUIState>
---@param state GeneralSettingsUIState
---@param action GeneralSettingsAction
---@param ... params<GeneralSettingsAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_RELOAD" then
		UIElements.New("ReloadPopupDialog", "dialog")
			:SetMessage(L["This change requires a reload."])
			:Show()
			:Draw()
	elseif action == "ACTION_CHANGE_GLOBAL_OPERATIONS" then
		-- Restore the previous value until it's confirmed
		local value = state.globalOperationsCheckbox:IsChecked()
		state.globalOperationsCheckbox:SetChecked(not value, true)
		local desc = L["If you have multiple profiles set up with operations, enabling this will cause all but the current profile's operations to be irreversibly lost."]
		state.frame:GetBaseElement():ShowConfirmationDialog(L["Make Operations Global?"], desc, manager:CallbackToProcessAction("ACTION_CHANGE_GLOBAL_OPERATIONS_CONFIRMED"), value)
	elseif action == "ACTION_CHANGE_GLOBAL_OPERATIONS_CONFIRMED" then
		local value = ...
		state.globalOperationsCheckbox:SetChecked(value, true)
		GroupOperationConfig.SetOperationsStoredGlobally(value)
	elseif action == "ACTION_SET_ACTIVE_CHAT_TAB" then
		ChatFrame.SetActive(private.settings.chatFrame)
	elseif action == "ACTION_FORGET_CHARACTER" then
		local key = state.forgetDropdown:GetSelectedItemKey()
		if not key then
			return
		end
		private.ForgetCharacter(key)
		state.forgetDropdown:SetSelectedItem(nil)
			:SetItems(private.characterList, private.characterKeys)
			:Draw()
	elseif action == "ACTION_SHOW_ALT_REALM_DIALOG" then
		state.frame:GetBaseElement():ShowDialogFrame(private.GetAltRealmDialog())
	elseif action == "ACTION_CLOSE_ALT_REALM_DIALOG" then
		state.frame:GetBaseElement():HideDialog()
	elseif action == "ACTION_RESET_PROFILE" then
		local profile = ...
		local activeProfile = private.settingsDB:GetCurrentProfile()
		private.settingsDB:SetProfile(profile)
		private.settingsDB:ResetProfile()
		private.settingsDB:SetProfile(activeProfile)
	elseif action == "ACTION_RENAME_PROFILE" then
		local prevProfileName, newProfileName = ...
		-- Create a new profile, copy over the settings, then delete the old one
		local activeProfile = private.settingsDB:GetCurrentProfile()
		private.settingsDB:SetProfile(newProfileName)
		private.settingsDB:CopyProfile(prevProfileName)
		private.settingsDB:DeleteProfile(prevProfileName, newProfileName)
		if activeProfile ~= prevProfileName then
			private.settingsDB:SetProfile(activeProfile)
		end
	elseif action == "ACTION_DUPLICATE_PROFILE" then
		local prevProfileName, newProfileName = ...
		-- Create the new profile
		local activeProfile = private.settingsDB:GetCurrentProfile()
		private.settingsDB:SetProfile(newProfileName)
		private.settingsDB:CopyProfile(prevProfileName)
		private.settingsDB:SetProfile(activeProfile)
		state.frame:Draw()
	elseif action == "ACTION_DELETE_PROFILE" then
		local profile = ...
		private.settingsDB:DeleteProfile(profile, private.settingsDB:GetCurrentProfile())
		state.frame:Draw()
	elseif action == "ACTION_SET_ACTIVE_PROFILE" then
		local profile = ...
		private.settingsDB:SetProfile(profile)
	elseif action == "ACTION_NEW_PROFILE" then
		local profile = state.newProfile
		state.newProfile = ""
		if not private.settingsDB:IsValidProfileName(profile) then
			ChatMessage.PrintUser(L["This is not a valid profile name. Profile names must be at least one character long and may not contain '@' characters."])
			return
		elseif private.settingsDB:ProfileExists(profile) then
			ChatMessage.PrintUser(L["A profile with this name already exists."])
			return
		end
		state.profilesList:AddProfile(profile)
		private.settingsDB:SetProfile(profile)
		state.frame:Draw()
	elseif action == "ACTION_CONNECT_ACCOUNT" then
		local character = CharacterInfo.Ambiguate(state.newAccountCharacter)
		local isConnecting, errType = Sync.EstablishConnection(character)
		if isConnecting then
			ChatMessage.PrintfUser(L["Establishing connection to %s. Make sure that you've entered this character's name on the other account."], character)
			state.accountSyncsList:AddNewConnection()
			state.frame:Draw()
		else
			if errType == Sync.CONNECTION_ERROR.NOT_READY then
				ChatMessage.PrintUser(L["TSM is not yet ready to establish a new sync connection. Please try again later."])
			elseif errType == Sync.CONNECTION_ERROR.CURRENT_CHARACTER then
				ChatMessage.PrintUser(L["Sync Setup Error: You entered the name of the current character and not the character on the other account."])
			elseif errType == Sync.CONNECTION_ERROR.NOT_ONLINE then
				ChatMessage.PrintUser(L["Sync Setup Error: The specified player on the other account is not currently online."])
			elseif errType == Sync.CONNECTION_ERROR.ALREADY_KNOWN then
				ChatMessage.PrintUser(L["Sync Setup Error: This character is already part of a known account."])
			elseif errType then
				error("Unknown error type: "..tostring(errType))
			end
		end
		state.newAccountCharacter = ""
	elseif action == "ACTION_SEND_PROFILE" then
		local account = ...
		local _, player = Sync.GetConnectionStatus(account)
		if not player then
			return
		end
		ProfileSync.Send(player)
	elseif action == "ACTION_REMOVE_ACCOUNT" then
		local account = ...
		Sync.RemoveAccount(account)
		ChatMessage.PrintUser(L["Account sync removed. Please delete the account sync from the other account as well."])
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end




-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetAltRealmDialog()
	return UIElements.New("BaseFrame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(300, 120)
		:SetPadding(8)
		:AddAnchor("CENTER")
		:SetBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:SetManager(private.manager)
		:AddChild(UIElements.New("Text", "content")
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetJustifyV("TOP")
			:SetJustifyH("CENTER")
			:SetText(L["The alt realm selection will not take affect until you next log into the game or reload your UI."])
		)
		:AddChild(UIElements.New("BaseFrame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 8, 0)
			:AddChild(UIElements.New("Spacer", "spacer1"))
			:AddChild(UIElements.New("MediumPrimaryActionButton", "btn")
				:SetWidth(126)
				:SetText(GlobalStrings.Get("OKAY"))
				:SetAction("OnClick", "ACTION_CLOSE_ALT_REALM_DIALOG")
			)
			:AddChild(UIElements.New("Spacer", "spacer2"))
		)
end

function private.ForgetCharacter(key)
	local character, factionrealm = strsplit(CHARACTER_SEP, key)
	private.settingsDB:RemoveSyncCharacter(character, factionrealm)
	local pendingMail = private.settings:GetForScopeKey("pendingMail", factionrealm)
	if pendingMail then
		pendingMail[character] = nil
	end
	local characterGuilds = private.settings:GetForScopeKey("characterGuilds", factionrealm)
	if characterGuilds then
		characterGuilds[character] = nil
	end
	ChatMessage.PrintfUser(L["%s removed."], SessionInfo.FormatCharacterName(character, factionrealm))
	local index = Table.KeyByValue(private.characterKeys, key)
	assert(index)
	tremove(private.characterList, index)
	tremove(private.characterKeys, index)
end

function private.ValidateProfileName(name)
	if not private.settingsDB:IsValidProfileName(name) then
		ChatMessage.PrintUser(L["This is not a valid profile name. Profile names must be at least one character long and may not contain '@' characters."])
		return false
	elseif private.settingsDB:ProfileExists(name) then
		ChatMessage.PrintUser(L["A profile with this name already exists."])
		return false
	else
		return true
	end
end

function private.GetDuplicateProfileName(profile)
	local newProfile = profile
	while private.settingsDB:ProfileExists(newProfile) do
		newProfile = newProfile.." Copy"
	end
	return newProfile
end

function private.GetAccountCharacterIterator(account)
	return private.settingsDB:AccessibleCharacterIterator(account)
end

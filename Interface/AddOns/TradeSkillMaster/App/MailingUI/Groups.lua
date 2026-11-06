-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Groups = App:Init("MailingUI.Groups")
local Table = App:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local Mailing = App:From("LibTSMApp"):Include("Mailing")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
	groupsTemp = {},
}
local SECONDS_PER_MINUTE = 60
local STATE_SCHEMA = Reactive.CreateStateSchema("MailingGroupsUIState")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddBooleanField("groupSelectionCleared", true)
	:AddBooleanField("sending", false)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Groups:OnModuleLoad(function()
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_GROUPS", state, private.ActionHandler)
		:AddFrameBuilder(private.GetGroupsFrame)

	private.manager:AddCancellable(state:Publisher([[not groupTree and sending]])
		:IgnoreIfEquals(false)
		:CallFunction(private.manager:CallbackToProcessAction("ACTION_STOP_SENDING"))
	)
end)

AddonSettings.RegisterOnLoad(Groups, function(db)
	private.settings = db:NewView("GroupsSettings")
		:AddKey("char", "mailingUIContext", "groupTree")
		:AddKey("global", "mailingOptions", "resendDelay")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the groups frame.
---@return BaseFrame
function Groups.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Groups UI
-- ============================================================================

---@param state MailingGroupsUIState
function private.GetGroupsFrame(state)
	UIUtils.AnalyticsRecordPathChange("mailing", "groups")
	local sendingPublisher = state:Publisher("sending")
		:Share()
	return UIElements.New("BaseFrame", "groups")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
			:SetOperationType("Mailing")
			:SetTreeBackgroundColor("surface/main")
			:BindSelectionCleared(state, "groupSelectionCleared")
			:SetSettingsContext(private.settings, "groupTree")
			:BindElement(state, "groupTree")
		)
		:AddChild(UIElements.New("MediumSecondaryActionButton", "mailGroupBtn")
			:SetMargin(0, 0, 12, 0)
			:SetText(sendingPublisher:ReplaceBooleanWith(L["Sending..."], L["Mail Selected Groups"]))
			:SetPressed(sendingPublisher)
			:SetDisabled(state:Publisher("groupSelectionCleared"))
			:SetAction("OnClick", "ACTION_START_SENDING")
			:SetModifierText(L["Mail Selected Groups (Dry Run)"], "CTRL")
			:SetModifierText(L["Mail Selected Groups (Auto Resend)"], "SHIFT")
			:SetModifierText(L["Mail Selected Groups (Dry Run + Auto Resend)"], "SHIFT", "CTRL")
			:SetTooltip(format(L["Hold SHIFT to automatically resend items after '%s', and CTRL to perform a dry-run where no items are actually mailed, but chat messages will still display the result."], TimeFormat.Duration(private.settings.resendDelay * SECONDS_PER_MINUTE)))
		)
		:AddCancellable(sendingPublisher:EndShare())
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MailingGroupsUIState>
---@param state MailingGroupsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_STOP_SENDING" then
		Mailing.StopSending()
		state.sending = false
	elseif action == "ACTION_START_SENDING" then
		local sendRepeat = IsShiftKeyDown()
		local isDryRun = IsControlKeyDown()
		state.sending = true
		assert(not next(private.groupsTemp))
		for _, groupPath in state.groupTree:SelectedGroupsIterator() do
			tinsert(private.groupsTemp, groupPath)
		end
		Mailing.SendGroups(manager:CallbackToProcessAction("ACTION_DONE_SENDING"), private.groupsTemp, sendRepeat, isDryRun)
		Table.WipeAndDeallocate(private.groupsTemp)
	elseif action == "ACTION_DONE_SENDING" then
		state.sending = false
	else
		error("Unknown action: "..tostring(action))
	end
end

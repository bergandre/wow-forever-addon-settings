-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Groups = LibTSMApp:InitInternal("Mailing.Groups")
local Util = LibTSMApp:Include("Mailing.Util")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local MailingOperation = LibTSMApp:From("LibTSMSystem"):Include("MailingOperation")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local private = {
	thread = nil,
	settings = nil,
	sendDone = false,
	groupsTemp = {},
	numMailableTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Groups:OnModuleLoad(function()
	private.thread = Threading.New("MAIL_GROUPS", private.GroupsMailThread)
end)

AddonSettings.RegisterOnLoad(Groups, function(db)
	private.settings = db:NewView("GroupsSettings")
		:AddKey("global", "mailingOptions", "resendDelay")
		:AddKey("global", "mailingOptions", "sendItemsIndividually")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sends items in the specified groups.
---@param callback fun() A callback function for when sending is complete
---@param groupList GroupPathValue[] The list of groups to send
---@param sendRepeat boolean Automatically repeat the sending
---@param isDryRun boolean Whether or not this is a dry run
function Groups.StartSending(callback, groupList, sendRepeat, isDryRun)
	if isDryRun then
		ChatMessage.PrintUser(L["Performing a dry-run of your Mailing operations for the selected groups."])
	end
	wipe(private.groupsTemp)
	for _, groupPath in ipairs(groupList) do
		private.groupsTemp[groupPath] = true
	end
	Threading.SetCallback(private.thread, callback)
	Threading.Start(private.thread, private.groupsTemp, sendRepeat, isDryRun)
end

---Stops sending.
function Groups.StopSending()
	Threading.Kill(private.thread)
end



-- ============================================================================
-- Group Sending Thread
-- ============================================================================

function private.GroupsMailThread(groups, sendRepeat, isDryRun)
	while true do
		local targets = Threading.AcquireSafeTempTable()
		assert(not next(private.numMailableTemp))
		BagTracking.CreateQueryBagsMailable()
			:AutoRelease()
			:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
			:VirtualField("groupPath", "string", Group.GetPathByItem, "itemString", "")
			:InTable("groupPath", groups)
			:GroupedSum("autoBaseItemString", "quantity", private.numMailableTemp)
		for itemString, availableQuantity in pairs(private.numMailableTemp) do
			for _, target, quantity in MailingOperation.SendTargetIterator(itemString, availableQuantity) do
				if Mail.IsValidRecipient(target) then
					targets[target] = targets[target] or Threading.AcquireSafeTempTable()
					targets[target][itemString] = (targets[target][itemString] or 0) + quantity
				end
			end
		end
		wipe(private.numMailableTemp)

		if not next(targets) then
			ChatMessage.PrintUser(L["Nothing to send."])
		end
		for name, items in pairs(targets) do
			private.SendItems(name, items, isDryRun)
			TempTable.Release(items)
			Threading.Sleep(0.5)
		end

		TempTable.Release(targets)

		if sendRepeat then
			Threading.Sleep(private.settings.resendDelay * 60)
		else
			break
		end
	end
end

function private.SendItems(target, items, isDryRun)
	assert(items and next(items))
	if isDryRun then
		Util.PrintDryRunItemsSendMessage(items, target)
		return
	end
	private.sendDone = false
	Util.PrintSendMessage(0, items, target)
	Mail.SendGroupItems(items, target, private.settings.sendItemsIndividually, private.SendCallback)
	while not private.sendDone do
		Threading.Yield(true)
	end
end

function private.SendCallback()
	private.sendDone = true
end

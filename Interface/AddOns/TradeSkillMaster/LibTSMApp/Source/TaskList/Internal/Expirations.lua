-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Expirations = LibTSMApp:InitInternal("TaskList.Expirations")
local ExpiredAuctionTask = LibTSMApp:IncludeClassType("ExpiredAuctionTask")
local ExpiringMailTask = LibTSMApp:IncludeClassType("ExpiringMailTask")
local TaskPool = LibTSMApp:Include("TaskList.TaskPool")
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local ObjectPool = LibTSMApp:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local DelayTimer = LibTSMApp:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local private = {
	settings = nil,
	mailTaskPool = ObjectPool.New("EXPIRING_MAIL_TASK", ExpiringMailTask),
	auctionTaskPool = ObjectPool.New("EXPIRED_AUCTION_TASK", ExpiredAuctionTask),
	expiringMailTasks = {},
	expiredAuctionTasks = {},
	updateDelayedTimer = nil,
	updateTimer = nil,
}
local TASK_POOL_KEY = "EXPIRATIONS"
local DAYS_LEFT_LIMIT = 1



-- ============================================================================
-- Module Loading
-- ============================================================================

Expirations:OnModuleLoad(function()
	Mail.RegisterExpiresCallback(private.UpdateDelayed)
	TaskPool.Register(TASK_POOL_KEY)
end)

AddonSettings.RegisterOnLoad(Expirations, function(db)
	private.settings = db:NewView("ExpirationsSettings")
		:AddKey("factionrealm", "internalData", "expiringMail")
		:AddKey("factionrealm", "internalData", "expiringAuction")
		:Commit()

	ExpiringMailTask.Configure(db, private.PopulateTasks)
	ExpiredAuctionTask.Configure(db, private.PopulateTasks)

	private.updateDelayedTimer = DelayTimer.New("EXPIRATIONS_UPDATE_DELAYED", private.PopulateTasks)
	private.updateTimer = DelayTimer.New("EXPIRATIONS_UPDATE", private.PopulateTasks)
	Auction.RegisterExpiresCallback(private.PopulateTasks)

	private.PopulateTasks()
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateDelayed()
	private.updateDelayedTimer:RunForTime(0.5)
end

function private.PopulateTasks()
	local minPendingCooldown = math.huge

	TaskPool.Wipe(TASK_POOL_KEY)

	for _, task in pairs(private.expiringMailTasks) do
		task:WipeCharacters()
	end
	for _, task in pairs(private.expiredAuctionTasks) do
		task:WipeCharacters()
	end

	-- Expiring mails
	for character, expTime in pairs(private.settings.expiringMail) do
		local task = private.expiringMailTasks["ExpiringMails"]
		if not task then
			task = private.mailTaskPool:Get()
			task:Acquire(private.RemoveMailTask, L["Expirations"])
			private.expiringMailTasks["ExpiringMails"] = task
		end

		local expiration = floor(expTime - LibTSMApp.GetTime()) / 24 / 60 / 60
		if expiration <= DAYS_LEFT_LIMIT * -1 then
			private.settings.expiringMail[character] = nil
		else
			if not task:HasCharacter(character) and expiration <= DAYS_LEFT_LIMIT then
				task:AddCharacter(character, expiration)
			end
			if expiration > DAYS_LEFT_LIMIT then
				minPendingCooldown = min(minPendingCooldown, (expiration - DAYS_LEFT_LIMIT) * 24 * 60 * 60)
			elseif expiration > 0 then
				minPendingCooldown = min(minPendingCooldown, expiration * 24 * 60 * 60)
			else
				minPendingCooldown = min(minPendingCooldown, (expiration + DAYS_LEFT_LIMIT) * 24 * 60 * 60)
			end
		end
	end

	for character, task in pairs(private.expiringMailTasks) do
		if task:HasCharacters() then
			TaskPool.Insert(TASK_POOL_KEY, task)
			task:Update()
		else
			private.expiringMailTasks[character] = nil
			task:Release()
			private.mailTaskPool:Recycle(task)
		end
	end

	-- Expired auctions
	for character, expTime in pairs(private.settings.expiringAuction) do
		local task = private.expiredAuctionTasks["ExpiredAuctions"]
		if not task then
			task = private.auctionTaskPool:Get()
			task:Acquire(private.RemoveAuctionTask, L["Expirations"])
			private.expiredAuctionTasks["ExpiredAuctions"] = task
		end

		local expiration = floor(expTime - LibTSMApp.GetTime()) / 24 / 60 / 60
		if expiration > 0 then
			minPendingCooldown = min(minPendingCooldown, expiration * 24 * 60 * 60)
		else
			if not task:HasCharacter(character) then
				task:AddCharacter(character, expiration)
			end
		end
	end

	for character, task in pairs(private.expiredAuctionTasks) do
		if task:HasCharacters() then
			TaskPool.Insert(TASK_POOL_KEY, task)
			task:Update()
		else
			private.expiredAuctionTasks[character] = nil
			task:Release()
			private.auctionTaskPool:Recycle(task)
		end
	end

	UpdateManager.HandleUpdate()

	private.updateTimer:Cancel()
	if minPendingCooldown ~= math.huge then
		private.updateTimer:RunForTime(minPendingCooldown)
	end
end

function private.RemoveMailTask(task)
	TaskPool.Remove(TASK_POOL_KEY, task)
	task:Release()
	private.mailTaskPool:Recycle(task)
	UpdateManager.HandleUpdate()
end

function private.RemoveAuctionTask(task)
	TaskPool.Remove(TASK_POOL_KEY, task)
	task:Release()
	private.auctionTaskPool:Recycle(task)
	UpdateManager.HandleUpdate()
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Cooldowns = LibTSMApp:InitInternal("TaskList.Cooldowns")
local CooldownCraftingTask = LibTSMApp:IncludeClassType("CooldownCraftingTask")
local TaskPool = LibTSMApp:Include("TaskList.TaskPool")
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local ObjectPool = LibTSMApp:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local DelayTimer = LibTSMApp:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local private = {
	settings = nil,
	query = nil,
	taskPool = ObjectPool.New("COOLDOWN_TASK", CooldownCraftingTask),
	activeTaskByProfession = {}, ---@type table<string,CooldownCraftingTask>
	ignoredQuery = nil, ---@diagnostic disable-line: tsm-private
	updateTimer = nil,
}
local TASK_POOL_KEY = "COOLDOWNS"



-- ============================================================================
-- Module Loading
-- ============================================================================

Cooldowns:OnModuleLoad(function()
	TaskPool.Register(TASK_POOL_KEY)
end)

AddonSettings.RegisterOnLoad(Cooldowns, function(db)
	private.settings = db:NewView("CooldownsSettings")
		:AddKey("char", "internalData", "craftingCooldowns")
		:Commit()
	CooldownCraftingTask.Configure(db)

	private.updateTimer = DelayTimer.New("COOLDOWNS_UPDATE", private.PopulateTasks)
	private.query = Crafting.CreateCooldownCraftsQuery(SessionInfo.GetCharacterName())
		:SetUpdateCallback(private.PopulateTasks)
	private.ignoredQuery = Crafting.CreateIgnoredCooldownsQuery()
		:SetUpdateCallback(private.PopulateTasks)

	private.PopulateTasks()
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PopulateTasks()
	-- Clean DB entries with expired times
	for craftString, expireTime in pairs(private.settings.craftingCooldowns) do
		if expireTime <= LibTSMApp.GetTime() then
			private.settings.craftingCooldowns[craftString] = nil
		end
	end

	-- Clear out the existing tasks
	for _, task in pairs(private.activeTaskByProfession) do
		task:WipeCraftStrings()
	end

	local minPendingCooldown = math.huge
	for _, profession, craftString in private.query:Iterator("profession", "craftString") do
		if Crafting.IsCooldownIgnored(craftString) then
			-- This is ignored
		elseif private.settings.craftingCooldowns[craftString] then
			-- This is on CD
			minPendingCooldown = min(minPendingCooldown, private.settings.craftingCooldowns[craftString] - floor(LibTSMApp.GetTime()))
		else
			-- This is a new CD task
			local task = private.activeTaskByProfession[profession]
			if not task then
				task = private.taskPool:Get()
				task:Acquire(private.RemoveTask, L["Cooldowns"], profession)
				private.activeTaskByProfession[profession] = task
			end
			if not task:HasCraftString(craftString) then
				task:AddCraftString(craftString, 1)
			end
		end
	end

	-- Update our tasks
	TaskPool.Wipe(TASK_POOL_KEY)
	for profession, task in pairs(private.activeTaskByProfession) do
		if task:HasCraftStrings() then
			TaskPool.Insert(TASK_POOL_KEY, task)
			task:Update()
		else
			private.activeTaskByProfession[profession] = nil
			task:Release()
			private.taskPool:Recycle(task)
		end
	end
	UpdateManager.HandleUpdate()

	if minPendingCooldown ~= math.huge then
		private.updateTimer:RunForTime(minPendingCooldown)
	else
		private.updateTimer:Cancel()
	end
end

---@param task CooldownCraftingTask
function private.RemoveTask(task)
	local profession = task:GetProfession()
	TaskPool.Remove(TASK_POOL_KEY, task)
	assert(private.activeTaskByProfession[profession] == task)
	private.activeTaskByProfession[profession] = nil
	task:Release()
	private.taskPool:Recycle(task)
	UpdateManager.HandleUpdate()
end

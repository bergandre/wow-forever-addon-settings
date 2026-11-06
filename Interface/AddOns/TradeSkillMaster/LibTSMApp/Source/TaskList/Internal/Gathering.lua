-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Gathering = LibTSMApp:InitInternal("TaskList.Gathering")
local AltTask = LibTSMApp:IncludeClassType("AltTask")
local BankingTask = LibTSMApp:IncludeClassType("BankingTask")
local CraftingTask = LibTSMApp:IncludeClassType("CraftingTask")
local OpenMailTask = LibTSMApp:IncludeClassType("OpenMailTask")
local SendMailTask = LibTSMApp:IncludeClassType("SendMailTask")
local ShoppingTask = LibTSMApp:IncludeClassType("ShoppingTask")
local TaskPool = LibTSMApp:Include("TaskList.TaskPool")
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local VendoringTask = LibTSMApp:IncludeClassType("VendoringTask")
local CraftingApp = LibTSMApp:Include("Crafting")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local ObjectPool = LibTSMApp:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local private = {
	settings = nil,
	query = nil,
	sourceTasks = {}, ---@type table<GatheringItemSource,ItemTask>
	altTaskPool = ObjectPool.New("GATHERING_ALT_TASK", AltTask),
	professionTasks = {},
	prevHash = nil,
	altsTemp = {},
	sourceInfoTemp = {},
	startGatheringFunc = nil,
}
local TASK_POOL_KEY = "GATHERING"

---@alias GatheringItemSource
---|'"auction"'
---|'"auctionDE"'
---|'"auctionCrafting"'
---|'"vendor"'
---|'"bank"'
---|'"guildBank"'
---|'"sendMail"'
---|'"openMail"'



-- ============================================================================
-- Module Functions
-- ============================================================================

Gathering:OnModuleLoad(function()
	VendoringTask.Configure()
	OpenMailTask.Configure()
	SendMailTask.Configure()
	CraftingTask.Configure()
	BankingTask.Configure()
	ShoppingTask.Configure(private.StartGatheringSearch) -- FIXME
	private.sourceTasks.auction = ShoppingTask.CreateNormal()
	private.sourceTasks.auctionDE = ShoppingTask.CreateDisenchant()
	private.sourceTasks.auctionCrafting = ShoppingTask.CreateCrafting()
	private.sourceTasks.vendor = VendoringTask()
	private.sourceTasks.bank = BankingTask.CreateBank()
	private.sourceTasks.guildBank = BankingTask.CreateGuildBank()
	private.sourceTasks.sendMail = SendMailTask()
	private.sourceTasks.openMail = OpenMailTask()
	for _, task in pairs(private.sourceTasks) do
		task:Acquire(private.SourceProfessionTaskDone, L["Gathering"])
	end
	TaskPool.Register(TASK_POOL_KEY)
end)

AddonSettings.RegisterOnLoad(Gathering, function(db)
	private.settings = db:NewView("GatheringSettings")
		:AddKey("factionrealm", "gatheringContext", "crafter")
		:Commit()
	private.query = CraftingApp.CreateGatheringQuery()
		:GreaterThan("numNeed", 0)
		:SetUpdateCallback(private.PopulateTasks)
	private.PopulateTasks()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the function to call to start a gathering search.
---@param func ShoppingTaskStartSearchFunc The function to start a gathering search
function Gathering.SetStartGatheringFunc(func)
	private.startGatheringFunc = func
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StartGatheringSearch(...)
	private.startGatheringFunc(...)
end

function private.PopulateTasks()
	local hash = private.query:Hash("itemString", "sourcesStr")
	if hash == private.prevHash then
		-- Nothing changed
		return
	end
	private.prevHash = hash

	for _, task in TaskPool.Iterator(TASK_POOL_KEY) do
		if task:__isa(AltTask) then
			private.RemoveAltTask(task)
		end
	end
	TaskPool.Wipe(TASK_POOL_KEY)
	for _, task in pairs(private.sourceTasks) do
		task:WipeItems()
	end
	for _, task in pairs(private.professionTasks) do
		task:WipeCraftStrings()
	end

	assert(not next(private.altsTemp))
	for _, itemString, sourcesStr in private.query:Iterator("itemString", "sourcesStr") do
		assert(not next(private.sourceInfoTemp))
		CraftingApp.GatheringSourcesStrToTable(sourcesStr, private.sourceInfoTemp, private.altsTemp)
		private.sourceInfoTemp.alt = nil
		private.sourceInfoTemp.altGuildBank = nil
		for source, quantity in pairs(private.sourceInfoTemp) do
			if private.sourceTasks[source] then
				private.sourceTasks[source]:AddItem(itemString, quantity)
				private.sourceInfoTemp[source] = nil
			end
		end
		if private.sourceInfoTemp.craftProfit or private.sourceInfoTemp.craftNoProfit then
			local craftString = Crafting.GetMostProfitableCraftStringByItem(itemString, private.settings.crafter)
			if craftString then
				local profession = Crafting.GetProfession(craftString)
				if not private.professionTasks[profession] then
					private.professionTasks[profession] = CraftingTask()
					private.professionTasks[profession]:Acquire(private.SourceProfessionTaskDone, L["Gathering"], profession)
				end
				private.professionTasks[profession]:AddCraftString(craftString, private.sourceInfoTemp.craftProfit or private.sourceInfoTemp.craftNoProfit)
			end
			private.sourceInfoTemp.craftProfit = nil
			private.sourceInfoTemp.craftNoProfit = nil
		end
		-- Make sure we processed all sources
		assert(not next(private.sourceInfoTemp))
	end

	for character in pairs(private.altsTemp) do
		local task = private.altTaskPool:Get()
		task:Acquire(private.RemoveAltTask, L["Gathering"], character)
		TaskPool.Insert(TASK_POOL_KEY, task)
		task:Update()
	end
	wipe(private.altsTemp)

	if private.settings.crafter ~= "" then
		local task = private.sourceTasks.sendMail --[[@as SendMailTask]]
		task:SetTarget(private.settings.crafter)
	end
	for _, task in pairs(private.sourceTasks) do
		if task:HasItems() then
			TaskPool.Insert(TASK_POOL_KEY, task)
			task:Update()
		end
	end
	for _, task in pairs(private.professionTasks) do
		if task:HasCraftStrings() then
			TaskPool.Insert(TASK_POOL_KEY, task)
			task:Update()
		end
	end

	UpdateManager.HandleUpdate()
end

function private.RemoveAltTask(task)
	TaskPool.Remove(TASK_POOL_KEY, task)
	task:Release()
	private.altTaskPool:Recycle(task)
end

function private.SourceProfessionTaskDone(task)
	TaskPool.Remove(TASK_POOL_KEY, task)
	UpdateManager.HandleUpdate()
end

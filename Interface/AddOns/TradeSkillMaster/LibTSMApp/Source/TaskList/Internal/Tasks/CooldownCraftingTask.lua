-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local CraftingTask = LibTSMApp:IncludeClassType("CraftingTask")
local CooldownCraftingTask = LibTSMApp:DefineInternalClassType("CooldownCraftingTask", CraftingTask)
local Math = LibTSMApp:From("LibTSMUtil"):Include("Lua.Math")
local Crafting = LibTSMApp:From("LibTSMService"):Include("Crafting")
local Profession = LibTSMApp:From("LibTSMService"):Include("Profession")
local private = {
	settings = nil,
	activeTasks = {},
	ignoredCooldownsQuery = nil, ---@diagnostic disable-line: tsm-private
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the cooldown crafting task code.
---@param db SettingsDB The settings DB
function CooldownCraftingTask.__static.Configure(db)
	private.settings = db:NewView("CooldownCraftingTaskSettings")
		:AddKey("char", "internalData", "craftingCooldowns")
		:Commit()
	private.ignoredCooldownsQuery = Crafting.CreateIgnoredCooldownsQuery()
		:SetUpdateCallback(private.UpdateTasks)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function CooldownCraftingTask:Acquire(...)
	self.__super:Acquire(...)
	private.activeTasks[self] = true
end

function CooldownCraftingTask:Release()
	self.__super:Release()
	private.activeTasks[self] = nil
end

function CooldownCraftingTask:CanHideSubTasks()
	return true
end

function CooldownCraftingTask:HideSubTask(index)
	Crafting.AddIgnoredCooldown(self._craftStrings[index])
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CooldownCraftingTask:_UpdateState()
	local result = self.__super:_UpdateState()
	if not self:HasCraftStrings() then
		return result
	end
	for i = #self._craftStrings, 1, -1 do
		if self:_IsOnCooldown(self._craftStrings[i]) or Crafting.IsCooldownIgnored(self._craftStrings[i]) then
			self:_RemoveCraftString(self._craftStrings[i])
		end
	end
	if not self:HasCraftStrings() then
		self:_doneHandler()
		return true
	end
	return result
end

function CooldownCraftingTask:_IsOnCooldown(craftString)
	assert(not private.settings.craftingCooldowns[craftString])
	local remainingCooldown = Profession.GetRemainingCooldown(craftString)
	if remainingCooldown then
		private.settings.craftingCooldowns[craftString] = Math.Round(LibTSMApp.GetTime() + remainingCooldown)
		return true
	end
	return false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateTasks()
	for task in pairs(private.activeTasks) do
		if task:HasCraftStrings() then
			task:Update()
		end
	end
end

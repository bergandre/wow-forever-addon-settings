-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ItemTask = LibTSMApp:IncludeClassType("ItemTask")
local BankingTask = LibTSMApp:DefineClassType("BankingTask", ItemTask)
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local Banking = LibTSMApp:From("LibTSMService"):Include("Banking")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local private = {
	currentlyMoving = nil,
	activeTasks = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the banking task code.
function BankingTask.__static.Configure()
	Banking.RegisterFrameCallback(private.FrameCallback)
end

---Creates a banking task for the personal bank.
---@return BankingTask
function BankingTask.__static.CreateBank()
	return BankingTask(false)
end

---Creates a banking task for the guild bank.
---@return BankingTask
function BankingTask.__static.CreateGuildBank()
	return BankingTask(true)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function BankingTask:__init(isGuildBank)
	self.__super:__init()
	self._isMoving = false
	self._isGuildBank = isGuildBank
end

function BankingTask:Acquire(doneHandler, category)
	self.__super:Acquire(doneHandler, category, self._isGuildBank and L["Get from Guild Bank"] or L["Get from Bank"])
	private.activeTasks[self] = true
end

function BankingTask:Release()
	self.__super:Release()
	self._isMoving = false
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BankingTask:OnButtonClick()
	private.currentlyMoving = self
	self._isMoving = true
	Banking.WithdrawItems(self:GetItems(), self:__closure("_MoveCallback"))
	self:_UpdateState()
	UpdateManager.HandleUpdate()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function BankingTask:_UpdateState()
	local expectedFrame = self._isGuildBank and Banking.FRAME.GUILD_BANK or Banking.FRAME.CONTAINER.BANK
	if Banking.GetOpenFrame() ~= expectedFrame then
		return self:_SetButtonState(false, L["NOT OPEN"])
	end
	local canMove = false
	for itemString in pairs(self:GetItems()) do
		if self._isGuildBank and Guild.GetQuantity(itemString) > 0 then
			canMove = true
			break
		elseif not self._isGuildBank then
			-- TODO: Support the warbank
			local _, bankQuantity = BagTracking.GetQuantities(itemString)
			if bankQuantity > 0 then
				canMove = true
				break
			end
		end
	end
	if self._isMoving then
		return self:_SetButtonState(false, L["MOVING"])
	elseif private.currentlyMoving then
		return self:_SetButtonState(false, L["BUSY"])
	elseif not canMove then
		return self:_SetButtonState(false, L["NO ITEMS"])
	else
		return self:_SetButtonState(true, L["MOVE"])
	end
end

function BankingTask.__private:_MoveCallback(event, ...)
	assert(self._isMoving)
	if event == "MOVED" then
		local itemString, quantity = ...
		if self:_RemoveItem(itemString, quantity) then
			UpdateManager.HandleUpdate()
		end
		if not private.activeTasks[self] then
			-- This task finished
			private.currentlyMoving = nil
		end
	elseif event == "DONE" then
		self._isMoving = false
		private.currentlyMoving = nil
	elseif event == "PROGRESS" then
		-- Pass
	else
		error("Unexpected event: "..tostring(event))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameCallback()
	for task in pairs(private.activeTasks) do
		task:Update()
	end
end

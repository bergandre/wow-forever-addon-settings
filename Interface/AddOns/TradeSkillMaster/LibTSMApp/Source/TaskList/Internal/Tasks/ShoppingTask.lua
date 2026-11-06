-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ItemTask = LibTSMApp:IncludeClassType("ItemTask")
local ShoppingTask = LibTSMApp:DefineInternalClassType("ShoppingTask", ItemTask)
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local EnumTypes = LibTSMApp:From("LibTSMTypes"):Include("EnumTypes")
local DelayTimer = LibTSMApp:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local private = {
	startSearchFunc = nil,
	currentlyScanning = nil,
	activeTasks = {},
	updateTimer = nil,
	uiVisible = false,
	scanInProgress = false,
}
local TASK_NAME_LOOKUP = {
	[EnumTypes.SHOPPING_SEARCH_MODE.NORMAL] = L["Buy from AH"],
	[EnumTypes.SHOPPING_SEARCH_MODE.DISENCHANT] = L["Buy from AH (Disenchant)"],
	[EnumTypes.SHOPPING_SEARCH_MODE.CRAFTING] = L["Buy from AH (Crafting)"],
}

---@alias ShoppingTaskStartSearchFunc fun(items: table<string,number>, stateCallback: fun(state: string), buyCallback: fun(itemString: string, quantity: number), searchMode: EnumValue)



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the shopping task code.
---@param startSearchFunc ShoppingTaskStartSearchFunc Function to start a gathering search
function ShoppingTask.__static.Configure(startSearchFunc)
	assert(startSearchFunc)
	assert(not private.startSearchFunc)
	private.startSearchFunc = startSearchFunc
	private.updateTimer = DelayTimer.New("SHOPPING_TASK_UPDATE", private.UIUpdateCallbackDelayed)
end

---Sets whether or not the required UI is currently visible.
---@param visible boolean Whether or not the UI is visible
function ShoppingTask.__static.SetUIVisible(visible)
	assert(type(visible) == "boolean")
	private.uiVisible = visible
end

---Sets whether or not a scan is in progress.
---@param scanInProgress boolean Whether or not a scan is in progress
function ShoppingTask.__static.SetIsScanning(scanInProgress)
	assert(type(scanInProgress) == "boolean")
	private.scanInProgress = scanInProgress
end

---Handles the UI being updated.
function ShoppingTask.__static.HandleUIUpdate()
	private.UIUpdateCallback()
end

---Creates a normal shopping task.
---@return ShoppingTask
function ShoppingTask.__static.CreateNormal()
	return ShoppingTask(EnumTypes.SHOPPING_SEARCH_MODE.NORMAL)
end

---Creates a disenchant shopping task.
---@return ShoppingTask
function ShoppingTask.__static.CreateDisenchant()
	return ShoppingTask(EnumTypes.SHOPPING_SEARCH_MODE.DISENCHANT)
end

---Creates a crafting shopping task.
---@return ShoppingTask
function ShoppingTask.__static.CreateCrafting()
	return ShoppingTask(EnumTypes.SHOPPING_SEARCH_MODE.CRAFTING)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ShoppingTask:__init(searchMode)
	assert(EnumTypes.SHOPPING_SEARCH_MODE:HasValue(searchMode))
	self.__super:__init()
	self._isScanning = false
	self._isShowingResults = false
	self._searchMode = searchMode
end

function ShoppingTask:Acquire(doneHandler, category)
	local name = TASK_NAME_LOOKUP[self._searchMode]
	assert(name)
	self.__super:Acquire(doneHandler, category, name)
	private.activeTasks[self] = true
end

function ShoppingTask:Release()
	self.__super:Release()
	self._isScanning = false
	self._isShowingResults = false
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingTask:OnButtonClick()
	private.currentlyScanning = self
	private.startSearchFunc(self:GetItems(), self:__closure("_StateCallback"), self:__closure("_BuyCallback"), self._searchMode)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ShoppingTask:_UpdateState()
	if not private.uiVisible then
		return self:_SetButtonState(false, L["NOT OPEN"])
	elseif self._isScanning then
		return self:_SetButtonState(false, L["SCANNING"])
	elseif self._isShowingResults then
		return self:_SetButtonState(false, L["BUY"])
	elseif private.scanInProgress or private.currentlyScanning then
		return self:_SetButtonState(false, L["AH BUSY"])
	else
		return self:_SetButtonState(true, L["SCAN ALL"])
	end
end

function ShoppingTask:_OnSearchStateChanged(state)
	if state == "SCANNING" then
		self._isScanning = true
		self._isShowingResults = false
	elseif state == "RESULTS" then
		self._isScanning = false
		self._isShowingResults = true
	elseif state == "DONE" then
		assert(private.currentlyScanning == self)
		private.currentlyScanning = nil
		self._isScanning = false
		self._isShowingResults = false
	else
		error("Unexpected state: "..tostring(state))
	end
	self:Update()
end

function ShoppingTask.__private:_StateCallback(state)
	Log.Info("State changed (%s)", state)
	self:_OnSearchStateChanged(state)
	private.UIUpdateCallback()
end

function ShoppingTask.__private:_BuyCallback(itemString, quantity)
	Log.Info("Bought item (%s,%d)", itemString, quantity)
	if self:_RemoveItem(itemString, quantity) then
		UpdateManager.HandleUpdate()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UIUpdateCallback()
	private.updateTimer:RunForFrames(1)
end

function private.UIUpdateCallbackDelayed()
	for task in pairs(private.activeTasks) do
		task:Update()
	end
end

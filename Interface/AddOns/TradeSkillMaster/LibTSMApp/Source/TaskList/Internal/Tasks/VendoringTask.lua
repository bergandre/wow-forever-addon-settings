-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ItemTask = LibTSMApp:IncludeClassType("ItemTask")
local VendoringTask = LibTSMApp:DefineInternalClassType("VendoringTask", ItemTask)
local UpdateManager = LibTSMApp:Include("TaskList.UpdateManager")
local Vendor = LibTSMApp:From("LibTSMService"):Include("Vendor")
local private = {
	query = nil, ---@diagnostic disable-line: tsm-private
	uiVisible = false,
	activeTasks = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the vendoring task code.
function VendoringTask.__static.Configure()
	private.query = Vendor.NewScannerQuery()
		:SetUpdateCallback(private.QueryUpdateCallback)
end

---Sets whether or not the required UI is currently visible.
---@param visible boolean Whether or not the UI is visible
function VendoringTask.__static.SetUIVisible(visible)
	assert(type(visible) == "boolean")
	private.uiVisible = visible
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function VendoringTask:Acquire(doneHandler, category)
	self.__super:Acquire(doneHandler, category, L["Buy from Vendor"])
	private.activeTasks[self] = true
end

function VendoringTask:Release()
	self.__super:Release()
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendoringTask:OnButtonClick()
	local query = Vendor.NewScannerQuery()
		:AutoPauseDBQueryUpdates()
		:AutoRelease()
	local didBuy = false
	for _, itemString in query:Iterator("itemString") do
		local quantity = self:GetItems()[itemString]
		if quantity then
			Vendor.BuyItem(itemString, quantity)
			self:_RemoveItem(itemString, quantity)
			didBuy = true
		end
	end

	if didBuy then
		UpdateManager.HandleUpdate()
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function VendoringTask:_UpdateState()
	if not private.uiVisible then
		return self:_SetButtonState(false, L["NOT OPEN"])
	end
	local canBuy = false
	for itemString in pairs(self:GetItems()) do
		if Vendor.GetFirstIndex(itemString) then
			canBuy = true
			break
		end
	end
	if not canBuy then
		return self:_SetButtonState(false, L["NO ITEMS"])
	else
		return self:_SetButtonState(true, L["BUY"])
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueryUpdateCallback()
	for task in pairs(private.activeTasks) do
		task:Update()
	end
end

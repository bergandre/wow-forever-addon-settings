-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Util = LibTSMApp:InitInternal("Sniper.Util")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local SniperOperation = LibTSMApp:From("LibTSMSystem"):Include("SniperOperation")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local SoundAlert = LibTSMApp:From("LibTSMWoW"):Include("UI.SoundAlert")
local AuctionSearchContext = LibTSMApp:From("LibTSMService"):IncludeClassType("AuctionSearchContext")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Util, function(db)
	private.settings = db:NewView("UtilSettings")
		:AddKey("global", "sniperOptions", "sniperSound")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates an auction search context.
---@param name string The name of the thread
---@param prepareQueryFunc fun(query: AuctionQuery) Function which prepares the auction query
---@param rescanDelay number The rescan delay
---@return AuctionSearchContext
function Util.CreateSearchContext(name, prepareQueryFunc, rescanDelay)
	---@param auctionScan AuctionScanManager
	local function ThreadFunc(auctionScan)
		local query = auctionScan:NewQuery()
		prepareQueryFunc(query)
		auctionScan:SetScript("OnQueryDone", private.OnQueryDone)
		-- Just constantly rerun the scan until the thread is killed (don't care if it fails)
		while true do
			auctionScan:ScanQueriesThreaded()
			auctionScan:SleepThreaded(rescanDelay)
		end
	end
	local threadId = Threading.New(name, ThreadFunc)
	return AuctionSearchContext(threadId, private.MarketValueFunction)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnQueryDone(_, _, numNewResults)
	if numNewResults > 0 then
		SoundAlert.Play(private.settings.sniperSound)
	end
end

function private.MarketValueFunction(row)
	local itemString = row:GetItemString()
	return itemString and SniperOperation.GetMaxPrice(Group.TranslateItemString(itemString)) or nil
end

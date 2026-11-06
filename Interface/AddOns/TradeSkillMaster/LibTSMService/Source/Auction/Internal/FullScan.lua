-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local FullScan = LibTSMService:InitInternal("Auction.FullScan")
local ChatMessage = LibTSMService:Include("UI.ChatMessage")
local Encoder = LibTSMService:From("LibTSMUtil"):IncludeClassType("Encoder")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local FullScanDialog = LibTSMService:From("LibTSMWoW"):Include("UI.FullScanDialog")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	gameVersion = nil,
	encoder = nil,
	timer = nil,
	state = "INITIALIZED",
	startTime = nil,
	scannedIndex = {},
	scanData = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

FullScan:OnModuleLoad(function()
	if LibTSMService.IsVanillaClassic() then
		if SessionInfo.IsSeasonOfDiscovery() then
			private.gameVersion = "Season of Discovery"
		elseif SessionInfo.IsHardcore() then
			private.gameVersion = "Classic Era - Hardcore"
		else
			private.gameVersion = "Classic Era"
		end
	elseif LibTSMService.IsBCClassic() then
		private.gameVersion = "Classic Era - Fresh"
	elseif LibTSMService.IsMistsClassic() then
		private.gameVersion = "Wrath"
	else
		-- Ignore for retail
		return
	end
	private.encoder = Encoder.Create()
		:SetEncodingType("BASE64")
		:SetSerializationType("NONE")
	private.timer = DelayTimer.New("FULL_SCAN_LOOP", private.ScannerLoop)
	Event.Register("AUCTION_HOUSE_CLOSED", private.HandleAuctionHouseClosed)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Enables the full scan hook.
function FullScan.Enable()
	if private.gameVersion then
		Event.Register("AUCTION_HOUSE_SHOW", private.HandleAuctionHouseShow)
		AuctionHouse.SecureHookGetAllScan(private.StartScan)
	end
end

---Gets the encoded scan data.
---@return string? data
---@return number? scanTime
function FullScan.GetData()
	if Table.Count(private.scanData) <= 50 then
		return nil
	end
	return private.EncodeScanData(), private.startTime
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StartScan()
	if private.state ~= "INITIALIZED" and private.state ~= "DONE" then
		return
	end
	Log.Info("Starting scan")
	wipe(private.scannedIndex)
	wipe(private.scanData)
	private.state = "STARTED"
	private.startTime = floor(LibTSMService.GetTime())
	private.timer:RunForTime(1)
	-- Auctionator unregisters other frames from events while it processes a scan - so we create a frame to register for all events
	Event.RegisterAllEvents(private.HandleAllEvents)
end

function private.HandleAuctionHouseShow()
	if private.state ~= "INITIALIZED" or not LibTSMService.IsMistsClassic() then
		return
	end
	FullScanDialog.Show(private.HandleDialogAccept)
end

function private.HandleDialogAccept()
	AuctionHouse.StartGetAllScan()
	ChatMessage.PrintUserRaw("Started full scan.")
end

function private.HandleAuctionHouseClosed()
	if private.state ~= "INITIALIZED" then
		private.state = "INTERRUPTED"
	end
end

function private.HandleAllEvents(event)
	if private.state ~= "STARTED" then
		Event.UnregisterAllEvents(private.HandleAllEvents)
	end
	if event == "AUCTION_ITEM_LIST_UPDATE" or event == "REPLICATE_ITEM_LIST_UPDATE" then
		private.state = "GOT_UPDATE"
	end
end

function private.ScannerLoop()
	if private.state == "STARTED" then
		-- Waiting for AUCTION_ITEM_LIST_UPDATE event
		private.timer:RunForTime(0.5)
	elseif private.state == "GOT_UPDATE" then
		-- Wait another 0.5 seconds and then start scanning
		private.state = "SCANNING"
		private.timer:RunForTime(0.5)
	elseif private.state == "SCANNING" then
		-- Keep trying to scan any data we don't yet have
		local hasInvalid = false
		local numScanned = 0
		for i = 1, AuctionHouse.GetNumGetAllAuctions() do
			if not private.scannedIndex[i] then
				local isValid = private.ScanAuction(i)
				if isValid then
					private.scannedIndex[i] = true
					numScanned = numScanned + 1
				else
					hasInvalid = true
				end
			end
			if numScanned == 500 then
				break
			end
		end
		if hasInvalid or numScanned ~= 0 then
			private.timer:RunForTime(numScanned == 500 and 0.01 or 1)
		else
			private.state = "DONE"
			Log.Info("Finished scanning (%s items)", Table.Count(private.scanData))
			if LibTSMService.IsMistsClassic() then
				ChatMessage.PrintUserRaw("Finished full scan.")
			end
		end
	end
end

function private.ScanAuction(index)
	local itemLink, stackSize, buyout = AuctionHouse.GetGetAllResult(index)
	local itemString = itemLink and ItemString.Get(itemLink)
	if not itemString or not stackSize then
		return false
	end
	if not buyout or buyout == 0 then
		return true
	end
	buyout = floor(buyout / stackSize)
	private.scanData[itemString] = private.scanData[itemString] or {}
	tinsert(private.scanData[itemString], {buyout, stackSize, index})
	return true
end

function private.EncodeScanData()
	local result = {}
	tinsert(result, strjoin(",", private.startTime, private.gameVersion, SessionInfo.GetRegion(), SessionInfo.GetRealmName(), SessionInfo.GetFactionName(), SessionInfo.GetCharacterName()))
	for itemString, data in pairs(private.scanData) do
		-- Sort all the data by buyout
		Table.Sort(data, private.ScanDataSortHelper)
		local itemData = {}
		local i = 1
		while i <= #data do
			-- Add up all the quantities at this buyout price
			local buyout, quantity = unpack(data[i])
			i = i + 1
			while i <= #data and data[i][1] == buyout do
				quantity = quantity + data[i][2]
				i = i + 1
			end
			if quantity > 1 then
				tinsert(itemData, strjoin("x", buyout, quantity))
			else
				tinsert(itemData, buyout)
			end
		end
		tinsert(result, strjoin(",", itemString, unpack(itemData)))
	end
	return private.encoder:Serialize(table.concat(result, "\n"))
end

function private.ScanDataSortHelper(a, b)
	local aBuyout = a[1]
	local bBuyout = b[1]
	if aBuyout ~= bBuyout then
		return aBuyout < bBuyout
	end
	return a[3] < b[3]
end

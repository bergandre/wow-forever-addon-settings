local Name, AddOn = ...
local Gathering = AddOn.Gathering
local L = AddOn.L

local ReplicateItems = C_AuctionHouse.ReplicateItems
local GetNumReplicateItems = C_AuctionHouse.GetNumReplicateItems
local GetReplicateItemInfo = C_AuctionHouse.GetReplicateItemInfo

local function StorePrice(self, ID, Count, Buyout)
	if (not ID or not Count or Count <= 0 or not Buyout or Buyout <= 0) then
		return
	end

	local PerUnit = Buyout / Count
	local Current = self.MarketPrices[ID]

	if (not Current or PerUnit < Current) then
		self.MarketPrices[ID] = PerUnit
		GatheringMarketPrices[ID] = PerUnit
		self.TooltipPriceCache = nil
	end
end

function Gathering:ScanButtonOnClick()
	local TimeDiff = (GetTime() - (GatheringLastScan or 0))

	if (TimeDiff > 0) and (900 > TimeDiff) then -- 15 minute throttle
		print(format(L["You must wait %s until you can scan again."], Gathering:FormatTime(900 - TimeDiff)))
		return
	end

	if Gathering:IsEventRegistered("REPLICATE_ITEM_LIST_UPDATE") then -- Awaiting results already
		if (TimeDiff > 900) then
			self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
		else
			return
		end
	end

	Gathering:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")

	ReplicateItems()

	print(L["|cffFFC44DGathering|r is scanning market prices. This should take less than 10 seconds."])

	GatheringLastScan = GetTime()
end

function Gathering:AUCTION_HOUSE_SHOW()
	if (not self.ScanButton and AuctionHouseFrame) then
		self.ScanButton = CreateFrame("Button", "Gathering Scan Button", AuctionHouseFrame.MoneyFrameBorder, "UIPanelButtonTemplate")
		self.ScanButton:SetSize(140, 24)
		self.ScanButton:SetPoint("LEFT", AuctionHouseFrame.MoneyFrameBorder, "RIGHT", 3, 0)
		self.ScanButton:SetText(L["Gathering Scan"])
		self.ScanButton:SetScript("OnClick", self.ScanButtonOnClick)
	end
end

function Gathering:REPLICATE_ITEM_LIST_UPDATE()
	GatheringMarketPrices = GatheringMarketPrices or {}
	wipe(GatheringMarketPrices)
	self.MarketPrices = GatheringMarketPrices

	for i = 0, (GetNumReplicateItems() - 1) do
		local Index = i
		local _, _, Count, _, _, _, _, _, _, Buyout, _, _, _, _, _, _, ID, HasAllInfo = GetReplicateItemInfo(Index)

		if HasAllInfo then
			StorePrice(self, ID, Count, Buyout)
		elseif ID and Item and Item.CreateFromItemID then
			Item:CreateFromItemID(ID):ContinueOnItemLoad(function()
				local _, _, LoadedCount, _, _, _, _, _, _, LoadedBuyout, _, _, _, _, _, _, LoadedID = GetReplicateItemInfo(Index)
				StorePrice(self, LoadedID, LoadedCount, LoadedBuyout)
			end)
		end
	end

	self.TooltipPriceCache = nil
	self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")

	print(L["|cffFFC44DGathering|r updated market prices."])
end

Gathering:RegisterEvent("AUCTION_HOUSE_SHOW")
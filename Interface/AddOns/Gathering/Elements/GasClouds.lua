local Name, AddOn = ...
local Gathering = AddOn.Gathering
local L = AddOn.L

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetContainerItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo

if C_Container then
	GetContainerItemInfo = function(bag, slot)
		local info = C_Container.GetContainerItemInfo(bag, slot)

		if info then
			return info.iconFileID, info.stackCount
		end
	end
end

local function GetBagItemTotals()
	local Totals = {}

	for Bag = 0, NUM_BAG_SLOTS do
		for Slot = 1, GetContainerNumSlots(Bag) do
			local ID = GetContainerItemID(Bag, Slot)

			if ID then
				local _, Count = GetContainerItemInfo(Bag, Slot)
				Totals[ID] = (Totals[ID] or 0) + (Count or 1)
			end
		end
	end

	return Totals
end

local function AddGasResult(self, ID, Quantity)
	local ItemName, _, _, _, _, _, SubType, _, _, _, _, ClassID, SubClassID, BindType = GetItemInfo(ID)

	if (not SubType or not ClassID or not SubClassID) then
		return false
	end

	if (not self.TrackedItemTypes[ClassID] or not self.TrackedItemTypes[ClassID][SubClassID]) then
		return false
	end

	if (BindType and BindType ~= 0 and self.Settings["ignore-bop"]) then
		return false
	end

	if (self.Ignored[ID] or (ItemName and self.Ignored[ItemName])) then
		return false
	end

	local Now = GetTime()

	if (not self.Gathered[SubType]) then
		self.Gathered[SubType] = {}
	end

	if (not self.Gathered[SubType][ID]) then
		self.Gathered[SubType][ID] = {Initial = Now}
	end

	local Info = self.Gathered[SubType][ID]

	Info.Collected = (Info.Collected or 0) + Quantity
	Info.Last = Now

	self.TotalGathered = self.TotalGathered + Quantity
	self:AddStat("total", Quantity)

	return true
end

function Gathering:BAG_UPDATE_DELAYED()
	self:UpdateBagSlots()

	if (not self.BagResults) then
		self:UpdateItemsStat()

		return
	end

	local Current = GetBagItemTotals()
	local AddedAny = false

	for ID, Count in next, Current do
		local Previous = self.BagResults[ID] or 0

		if (Count > Previous) then
			AddedAny = AddGasResult(self, ID, Count - Previous) or AddedAny
		end
	end

	self.BagResults = nil

	if (not AddedAny) then
		self:UpdateItemsStat()

		return
	end

	if (self.Settings.DisplayMode == "TOTAL") then
		self.Text:SetFormattedText(L["Total: %s"], self.TotalGathered)
	end

	if (not self:GetScript("OnUpdate")) then
		self:StartTimer()
	end

	self.TooltipPriceCache = nil
	self:UpdateItemsStat()

	if self.MouseIsOver then
		self.Tooltip:ClearLines()
		self:OnEnter()
	end
end

function Gathering:UNIT_SPELLCAST_CHANNEL_START(unit, guid, id)
	if (unit ~= "player" or id ~= 30427) then -- Extract Gas
		return
	end

	self.BagResults = GetBagItemTotals()
	self:AddStat("clouds", 1)
end

Gathering:RegisterEvent("BAG_UPDATE_DELAYED")
Gathering:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
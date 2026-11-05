local Name, AddOn = ...
local Gathering = AddOn.Gathering

local gsub = string.gsub
local match = string.match
local format = string.format
local reverse = string.reverse
local ceil = math.ceil
local floor = math.floor
local abs = math.abs

local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local NUM_BAG_SLOTS = NUM_BAG_SLOTS

if C_Container then
	GetContainerNumSlots = C_Container.GetContainerNumSlots
	GetContainerItemInfo = C_Container.GetContainerItemInfo
	GetContainerItemLink = C_Container.GetContainerItemLink
end

function Gathering:FormatTime(seconds)
	if (seconds > 59) then
		return format("%dm", ceil(seconds / 60))
	else
		return format("%0.1fs", seconds)
	end
end

function Gathering:FormatFullTime(seconds)
	local Days = floor(seconds / 86400)
	local Hours = floor((seconds % 86400) / 3600)
	local Mins = floor((seconds % 3600) / 60)

	if (Days > 0) then
		return format("%dd", Days)
	elseif (Hours > 0) then
		return format("%dh %sm", Hours, Mins)
	elseif (Mins > 0) then
		return format("%sm", Mins)
	else
		return format("%ss", floor(seconds))
	end
end

function Gathering:FormatRecentTime(seconds)
	seconds = floor(math.max(seconds or 0, 0))

	local Days = floor(seconds / 86400)
	local Hours = floor((seconds % 86400) / 3600)
	local Mins = floor((seconds % 3600) / 60)
	local Secs = seconds % 60

	if (Days > 0) then
		return format("%dd %dh", Days, Hours)
	elseif (Hours > 0) then
		return format("%dh %dm", Hours, Mins)
	elseif (Mins > 0) then
		return format("%dm %ds", Mins, Secs)
	else
		return format("%ds", Secs)
	end
end


function Gathering:FormatClockTime(seconds)
	seconds = floor(math.max(seconds or 0, 0))

	local Hours = floor(seconds / 3600)
	local Mins = floor((seconds % 3600) / 60)
	local Secs = seconds % 60

	return format("%02d:%02d:%02d", Hours, Mins, Secs)
end

function Gathering:Comma(number)
	if (not number) then
		return
	end

   	local Left, Number = match(floor(number + 0.5), "^([^%d]*%d)(%d+)(.-)$")

	return Left and Left .. reverse(gsub(reverse(Number), "(%d%d%d)", "%1,")) or number
end

function Gathering:CopperToGold(copper)
	if (copper == nil) then
		return "0"
	end

	local Negative = copper < 0
	copper = floor(abs(copper))

	local Gold = floor(copper / (100 * 100))
	local Silver = floor((copper - (Gold * 100 * 100)) / 100)
	local Copper = floor(copper % 100)
	local Separator = ""
	local String = ""

	if (Gold > 0) then
		String = self:Comma(Gold) .. "|cffffe02eg|r"
		Separator = " "
	end

	if (Silver > 0) then
		String = String .. Separator .. Silver .. "|cffd6d6d6s|r"
		Separator = " "
	end

	if (Copper > 0 or String == "") then
		String = String .. Separator .. Copper .. "|cfffc8d2bc|r"
	end

	if Negative and copper > 0 then
		return "|cffff5555-|r" .. String
	end

	return String
end

function Gathering:GetPrice(link)
	local Price

	if self.HasTSM then
		Price = TSM_API.GetCustomPriceValue("dbMarket", TSM_API.ToItemString(link))

		if (Price and Price > 0) then
			return Price
		end
	end

	if self.HasAuctionator then
		Price = Auctionator.API.v1.GetAuctionPriceByItemLink("Gathering", link)

		if (Price and Price > 0) then
			return Price
		end
	end

	if GatheringMarketPrices and link then
		local ID

		if (type(link) == "number") then
			ID = link
		else
			ID = tonumber(match(link, "item:(%d+)"))
		end

		if ID then
			Price = GatheringMarketPrices[ID]

			if (Price and Price > 0) then
				return Price
			end
		end
	end
end

function Gathering:GetTrashValue()
	local Profit = 0

	for Bag = 0, NUM_BAG_SLOTS do
		for Slot = 1, GetContainerNumSlots(Bag) do
			local Link = GetContainerItemLink(Bag, Slot)

			if Link then
				local _, _, Quality, _, _, _, _, _, _, _, VendorPrice = GetItemInfo(Link)
				local Count

				if C_Container then
					local Info = GetContainerItemInfo(Bag, Slot)
					Count = Info and Info.stackCount or 1
				else
					Count = select(2, GetContainerItemInfo(Bag, Slot)) or 1
				end

				local TotalPrice = VendorPrice or 0

				if ((VendorPrice and (VendorPrice > 0)) and Count) then
					TotalPrice = VendorPrice * Count
				end

				if ((Quality and Quality < 1) and TotalPrice > 0) then
					Profit = Profit + TotalPrice
				end
			end
		end
	end

	return Profit
end
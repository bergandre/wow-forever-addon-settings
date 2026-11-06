-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Util = App:Init("VendoringUI.Util")
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local Currency = App:From("LibTSMWoW"):Include("API.Currency")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Vendor = App:From("LibTSMService"):Include("Vendor")
local private = {
	costTextTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the alt cost text for a vendor item.
---@param index number The vendor index
---@param quantity number The quantity to display the price of
---@return string
function Util.GetAltCostText(index, quantity)
	local price, numStacks = Vendor.GetTotalCost(index, quantity)
	local color = Vendor.GetNumCanAfford(index) < quantity and Theme.GetColor("error/main") or nil
	local priceText = price > 0 and Money.ToStringForUI(price, color and color:GetTextColorPrefix() or nil) or nil
	local costItemsText = private.GetAdditionalCostText(index, numStacks, color)
	if priceText and costItemsText then
		return priceText.." "..costItemsText
	else
		return priceText or costItemsText
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetAdditionalCostText(index, numStacks, costColor)
	assert(#private.costTextTemp == 0)
	for _, itemString, quantity in Vendor.AdditionalCostIterator(index) do
		quantity = quantity * numStacks
		if costColor then
			quantity = costColor:ColorText(quantity)
		end
		local currencyId = strmatch(itemString, "currency:(%d+)")
		currencyId = currencyId and tonumber(currencyId) or nil
		local currencyName, currencyTexture = nil, nil
		if currencyId then
			currencyName, currencyTexture = Currency.GetInfo(currencyId)
		end
		if currencyName then
			local suffixStr = currencyName == HONOR_POINTS and ":14:14:00:0:64:64:0:40:0:40|t" or ":12|t"
			tinsert(private.costTextTemp, quantity.." |T"..currencyTexture..suffixStr)
		else
			tinsert(private.costTextTemp, quantity.." |T"..(ItemInfo.GetTexture(itemString) or 0)..":12|t")
		end
	end
	local text = table.concat(private.costTextTemp, " ")
	wipe(private.costTextTemp)
	return text
end

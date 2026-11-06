-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Sell = LibTSMApp:InitInternal("Vendoring.Sell")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMApp:From("LibTSMWoW"):Include("API.Container")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sell an item to the vendor.
---@param itemString string The item string
function Sell.SellItem(itemString)
	local query = BagTracking.CreateQueryBags()
		:AutoRelease()
		:OrderBy("slotId", true)
		:Equal("isBound", false)
		:Equal("itemString", itemString)
	for _, slotId in query:Iterator("slotId") do
		local link = Container.GetItemLink(slotId)
		if link and ItemString.Get(link) == itemString then
			Container.UseItem(slotId)
		end
	end
end

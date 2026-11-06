-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local PotentialValue = LibTSMApp:InitInternal("Vendoring.PotentialValue")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local private = {
	potentialValueDB = nil,
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

PotentialValue:OnModuleLoad(function()
	private.potentialValueDB = Database.NewSchema("VENDORING_POTENTIAL_VALUE")
		:AddUniqueStringField("itemString")
		:AddNumberField("potentialValue")
		:Commit()
end)

AddonSettings.RegisterOnLoad(PotentialValue, function(db)
	private.settings = db:NewView("PotentialValueSettings")
		:AddKey("global", "vendoringOptions", "qsMarketValue")
		:Commit()
		:RegisterCallback("qsMarketValue", private.UpdatePotentialValueDB)
	BagTracking.RegisterCallback(private.UpdatePotentialValueDB)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the potential value DB for a join.
---@return DatabaseTable
function PotentialValue.GetDBForJoin()
	return private.potentialValueDB
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdatePotentialValueDB()
	private.potentialValueDB:TruncateAndBulkInsertStart()
	local query = BagTracking.CreateQueryBags()
		:AutoRelease()
		:OrderBy("slotId", true)
		:Distinct("itemString")
		:Equal("isBound", false)
	for _, itemString in query:Iterator("itemString") do
		local value = CustomString.GetValue(private.settings.qsMarketValue, itemString)
		if value then
			private.potentialValueDB:BulkInsertNewRow(itemString, value)
		end
	end
	private.potentialValueDB:BulkInsertEnd()
end

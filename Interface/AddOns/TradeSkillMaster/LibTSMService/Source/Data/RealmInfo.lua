
-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local RealmInfo = LibTSMService:Init("Data.RealmInfo")
local Realm = LibTSMService:From("LibTSMData"):Include("Realm")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	region = nil,
	connectedRealms = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

RealmInfo:OnModuleLoad(function()
	local packedRealmData = nil
	if LibTSMService.IsRetail() then
		packedRealmData = Realm.Retail
	elseif LibTSMService.IsForever() then
		packedRealmData = {}
	elseif LibTSMService.IsMistsClassic() then
		packedRealmData = Realm.Mists
	elseif LibTSMService.IsBCClassic() then
		packedRealmData = Realm.Classic
	elseif LibTSMService.IsVanillaClassic() then
		packedRealmData = Realm.Classic
	else
		error("Unknown game version")
	end
	local currentRealmName = gsub(SessionInfo.GetRealmName(), "\226", "'")
	local currentRealmId = SessionInfo.GetRealmId()
	for _, entry in ipairs(packedRealmData) do
		local name, id, region, extra = strsplit(",", entry)
		id = tonumber(id)
		assert(id and not extra)
		if id == currentRealmId then
			assert(not private.region or private.region == region)
			private.region = region
			if name ~= currentRealmName then
				tinsert(private.connectedRealms, name)
			end
		end
	end
	private.region = private.region or SessionInfo.GetRegion()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over the connected realms.
---@return fun(): number, string @Iterator with fields: `index`, `name`
---@return table
---@return number
function RealmInfo.ConnectedRealmIterator()
	return ipairs(private.connectedRealms)
end

---Gets the region from the realm data.
---@return string
function RealmInfo.GetRegion()
	return private.region
end

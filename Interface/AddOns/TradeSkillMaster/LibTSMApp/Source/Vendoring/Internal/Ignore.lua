-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Ignore = LibTSMApp:InitInternal("Vendoring.Ignore")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
	db = nil,
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Ignore:OnModuleLoad(function()
	private.db = Database.NewSchema("VENDORING_IGNORE")
		:AddUniqueStringField("itemString")
		:AddBooleanField("ignoreSession")
		:AddBooleanField("ignorePermanent")
		:Commit()
end)

AddonSettings.RegisterOnLoad(Ignore, function(db)
	private.settings = db:NewView("IgnoreSettings")
		:AddKey("global", "userData", "vendoringIgnore")
		:Commit()

	-- Clean up the vendoring ignore item strings
	local newItemStrings = {}
	for itemString in pairs(private.settings.vendoringIgnore) do
		local newItemString = ItemString.Get(itemString)
		if not newItemString then
			private.settings.vendoringIgnore[itemString] = nil
		elseif newItemString ~= itemString then
			newItemStrings[newItemString] = true
			private.settings.vendoringIgnore[itemString] = nil
		end
	end
	for itemString in pairs(newItemStrings) do
		private.settings.vendoringIgnore[itemString] = true
	end

	-- Populate our DB
	private.db:BulkInsertStart()
	for itemString in pairs(private.settings.vendoringIgnore) do
		private.db:BulkInsertNewRow(itemString, false, true)
	end
	private.db:BulkInsertEnd()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds an item to the ignore list for the remainder of the session.
---@param itemString string The item string
function Ignore.AddSession(itemString)
	if private.db:HasUniqueRow("itemString", itemString) then
		local uuid = private.db:GetUniqueRow("itemString", itemString)
		assert(private.db:GetRowFields(uuid, "ignoreSession") == false)
		private.db:UpdateRow(uuid, "ignoreSession", true)
	else
		private.db:InsertRow(itemString, true, false)
	end
end

---Adds an item to the ignore list permanently.
---@param itemString string The item string
function Ignore.AddPermanent(itemString)
	assert(not private.settings.vendoringIgnore[itemString])
	private.settings.vendoringIgnore[itemString] = true
	if private.db:HasUniqueRow("itemString", itemString) then
		local uuid = private.db:GetUniqueRow("itemString", itemString)
		assert(private.db:GetRowFields(uuid, "ignorePermanent") == false)
		private.db:UpdateRow(uuid, "ignorePermanent", true)
	else
		private.db:InsertRow(itemString, false, true)
	end
end

---Removes an item from the permanent ignore list
---@param itemString string The item string
function Ignore.RemovePermanent(itemString)
	assert(private.settings.vendoringIgnore[itemString])
	private.settings.vendoringIgnore[itemString] = nil

	local uuid = private.db:GetUniqueRow("itemString", itemString)
	assert(private.db:GetRowFields(uuid, "ignorePermanent"))
	if private.db:GetRowFields(uuid, "ignoreSession") then
		private.db:UpdateRow(uuid, "ignorePermanent", false)
	else
		private.db:DeleteRow(uuid)
	end
end

---Creates an ignore DB query.
---@return DatabaseQuery
function Ignore.CreateQuery()
	return private.db:NewOwnedQuery()
		:Equal("ignorePermanent", true)
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:OrderBy("name", true)
end

---Gets the ignore DB for a join.
---@return DatabaseTable
function Ignore.GetDBForJoin()
	return private.db
end

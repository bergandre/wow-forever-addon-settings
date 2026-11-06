-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Ignore = LibTSMApp:InitInternal("Destroying.Ignore")
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
	private.db = Database.NewSchema("DESTROYING_IGNORE")
		:AddUniqueStringField("itemString")
		:AddBooleanField("ignoreSession")
		:AddBooleanField("ignorePermanent")
		:Commit()
end)

AddonSettings.RegisterOnLoad(Ignore, function(db)
	private.settings = db:NewView("IgnoreSettings")
		:AddKey("global", "userData", "destroyingIgnore")
		:Commit()

	-- Clean up the destroying ignore item strings
	local newItemStrings = {}
	for itemString in pairs(private.settings.destroyingIgnore) do
		local newItemString = ItemString.Get(itemString)
		if not newItemString then
			private.settings.destroyingIgnore[itemString] = nil
		elseif newItemString ~= itemString then
			newItemStrings[newItemString] = true
			private.settings.destroyingIgnore[itemString] = nil
		end
	end
	for itemString in pairs(newItemStrings) do
		private.settings.destroyingIgnore[itemString] = true
	end

	-- Populate our DB
	private.db:BulkInsertStart()
	for itemString in pairs(private.settings.destroyingIgnore) do
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
	assert(not private.settings.destroyingIgnore[itemString])
	private.settings.destroyingIgnore[itemString] = true
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
	assert(private.settings.destroyingIgnore[itemString])
	private.settings.destroyingIgnore[itemString] = nil
	local uuid = private.db:GetUniqueRow("itemString", itemString)
	local ignoreSession, ignorePermanent = private.db:GetRowFields(uuid, "ignoreSession", "ignorePermanent")
	assert(ignorePermanent)
	if ignoreSession then
		private.db:UpdateRow(uuid, "ignorePermanent", false)
	else
		private.db:DeleteRow(uuid)
	end
end

---Returns whether or not an item is currently ignored.
---@param itemString string The item string
---@return boolean
function Ignore.HasItem(itemString)
	return private.db:HasUniqueRow("itemString", itemString)
end

---Creates an ignore DB query.
---@return DatabaseQuery
function Ignore.CreateQuery()
	return private.db:NewOwnedQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:VirtualField("texture", "number", ItemInfo.GetTexture, "itemString", ItemInfo.GetTexture(ItemString.GetUnknown()))
		:Equal("ignorePermanent", true)
		:OrderBy("name", true)
end

---Gets the ignore DB for joining.
---@return DatabaseTable
function Ignore.GetDBForJoin()
	return private.db
end

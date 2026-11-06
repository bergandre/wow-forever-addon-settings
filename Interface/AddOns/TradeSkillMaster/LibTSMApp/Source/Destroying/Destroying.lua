-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Destroying = LibTSMApp:Init("Destroying")
local BagDB = LibTSMApp:Include("Destroying.BagDB")
local Combine = LibTSMApp:Include("Destroying.Combine")
local Destroy = LibTSMApp:Include("Destroying.Destroy")
local Ignore = LibTSMApp:Include("Destroying.Ignore")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a bag DB query.
---@return DatabaseQuery
function Destroying.CreateBagQuery()
	return BagDB.CreateQuery()
end

---Creates an ignore DB query.
---@return DatabaseQuery
function Destroying.CreateIgnoreQuery()
	return Ignore.CreateQuery()
end

---Adds an item to the ignore list for the remainder of the session.
---@param itemString string The item string
function Destroying.IgnoreItemSession(itemString)
	Ignore.AddSession(itemString)
end

---Adds an item to the ignore list permanently.
---@param itemString string The item string
function Destroying.IgnoreItemPermanent(itemString)
	Ignore.AddPermanent(itemString)
end

---Removes an item from the permanent ignore list
---@param itemString string The item string
function Destroying.ForgetIgnoreItemPermanent(itemString)
	Ignore.RemovePermanent(itemString)
end

---Creates a publisher for whether or not there are stacks to combine.
---@return ReactivePublisherSchema
function Destroying.CanCombinePublisher()
	return BagDB.CanCombinePublisher()
end

---Starts combining any available stacks.
---@return Future
function Destroying.StartCombine()
	return Combine.Start()
end

---Starts destroying an item at a slot.
---@param prepareFunc DestroyingPrepareButtonFunc The function to call to prepare for destroying
---@param itemString string The item string to destroy
---@param slotId number The slot ID to destroy
---@return Future
function Destroying.StartDestroy(prepareFunc, itemString, slotId)
	return Destroy.Start(prepareFunc, itemString, slotId)
end

-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Log = LibTSMApp:InitInternal("Auctioning.Log")
local L = LibTSMApp.Locale.GetTable()
local EnumType = LibTSMApp:From("LibTSMUtil"):Include("BaseType.EnumType")
local Database = LibTSMApp:From("LibTSMDatabase"):Include("Database")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local AuctioningOperation = LibTSMApp:From("LibTSMSystem"):Include("AuctioningOperation")
local TextureAtlas = LibTSMApp:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {
	db = nil,
}
local STATE = EnumType.New("AUCTIONING_LOG_STATE", {
	PENDING = EnumType.NewValue(),
	POSTED = EnumType.NewValue(),
	CANCELLED = EnumType.NewValue(),
	SKIPPED = EnumType.NewValue(),
})
Log.STATE = STATE
local INFO_STR_ARG_FIELDS = { "state", "reasonKey" }
local INDEX_ICON_ARG_FIELDS = { "state", "reasonKey" }



-- ============================================================================
-- Module Loading
-- ============================================================================

Log:OnModuleLoad(function()
	private.db = Database.NewSchema("AUCTIONING_LOG")
		:AddNumberField("index")
		:AddStringField("itemString")
		:AddStringField("seller")
		:AddNumberField("buyout")
		:AddStringField("operation")
		:AddStringField("reasonStr")
		:AddEnumField("reasonKey", AuctioningOperation.RESULT)
		:AddStringField("reasonContext")
		:AddEnumField("state", STATE)
		:AddIndex("index")
		:Commit()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Truncate the log.
function Log.Truncate()
	private.db:Truncate()
end

---Create a query.
---@return DatabaseQuery
function Log.CreateQuery()
	return private.db:NewOwnedQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "")
		:VirtualField("infoStr", "string", private.InfoStrVirtualField, INFO_STR_ARG_FIELDS)
		:VirtualField("indexIcon", "string", private.IndexIconVirtualField, INDEX_ICON_ARG_FIELDS)
		:OrderBy("index", false)
end

---Update a log row.
---@param index number The index of the log row
---@param field string The field to update
---@param value any The value to set
function Log.UpdateRowByIndex(index, field, value)
	local uuid = private.db:NewAutoReleaseQuery()
		:Equal("index", index)
		:GetFirstResultWithUUID()
	if field == "state" then
		assert(STATE:HasValue(value) and value ~= STATE.PENDING)
		if not uuid then
			return
		end
	end
	assert(uuid)
	private.db:UpdateRow(uuid, field, value)
end

---Returns an iterator which executes to completion with log DB query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function Log.WithQueryUpdatesPaused(func, obj, key)
	return private.db:WithQueryUpdatesPaused(func, obj, key)
end

---Adds an entry to the log.
---@param itemString string The item string
---@param operationName string The operation name
---@param reasonKey EnumValue The reason string
---@param seller string The seller name
---@param buyout number The buyout
---@param index number The index
---@param reasonContext? string Context for the reason
function Log.AddEntry(itemString, operationName, reasonKey, seller, buyout, index, reasonContext)
	private.db:InsertRow(index, itemString, seller, buyout, operationName, private.GetResultText(reasonKey), reasonKey, reasonContext or "", STATE.PENDING)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.InfoStrVirtualField(state, reasonKey)
	if state == STATE.PENDING then
		return Theme.GetColor(private.GetResultColor(reasonKey)):ColorText(private.GetResultText(reasonKey))
	elseif state == STATE.POSTED then
		return Theme.GetColor("accent/main"):ColorText(L["Posted:"]).." "..private.GetResultText(reasonKey)
	elseif state == STATE.CANCELLED then
		return Theme.GetColor("accent/main"):ColorText(L["Cancelled:"]).." "..private.GetResultText(reasonKey)
	elseif state == STATE.SKIPPED then
		return Theme.GetColor("accent/main"):ColorText(L["Skipped:"]).." "..private.GetResultText(reasonKey)
	else
		error("Invalid state: "..tostring(state))
	end
end

function private.IndexIconVirtualField(state, reasonKey)
	if state == STATE.PENDING then
		-- Color the circle icon to match the color of the text
		return TextureAtlas.GetColoredKey("iconPack.12x12/Circle", private.GetResultColor(reasonKey))
	else
		return "iconPack.12x12/Checkmark/Default"
	end
end

function private.GetResultColor(result)
	if result == AuctioningOperation.RESULT.INVALID then
		return "error/main"
	elseif result == AuctioningOperation.RESULT.NOT_POSTING then
		return "warning/main"
	elseif result == AuctioningOperation.RESULT.POSTING_NOT_NEEDED then
		return "on/surface/low"
	elseif result == AuctioningOperation.RESULT.POSTING then
		return "positive/main"
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING then
		return "positive/main"
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED then
		return "on/surface/low"
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS then
		return "error/main"
	elseif result == AuctioningOperation.RESULT.WONT_CANCEL then
		return "error/main"
	elseif result == AuctioningOperation.RESULT.CANCELING then
		return "error/main"
	else
		error("Unknown result: "..tostring(result))
	end
end

function private.GetResultText(result)
	if result == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		return L["Item/Group is invalid (hover for info)."]
	elseif result == AuctioningOperation.RESULT.INVALID.SELLER then
		return L["Invalid seller data returned by server."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.DISABLED then
		return L["Posting disabled."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.NOT_ENOUGH then
		return L["Not enough items in bags."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.MAX_EXPIRES then
		return L["Above max expires."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.BELOW_MIN then
		return L["Cheapest auction below min price."]
	elseif result == AuctioningOperation.RESULT.POSTING_NOT_NEEDED.TOO_MANY then
		return L["Maximum amount already posted."]
	elseif result == AuctioningOperation.RESULT.POSTING.NORMAL then
		return L["Posting at normal price."]
	elseif result == AuctioningOperation.RESULT.POSTING.RESET_MIN then
		return L["Below min price. Posting at min."]
	elseif result == AuctioningOperation.RESULT.POSTING.RESET_MAX then
		return L["Below min price. Posting at max."]
	elseif result == AuctioningOperation.RESULT.POSTING.RESET_NORMAL then
		return L["Below min price. Posting at normal."]
	elseif result == AuctioningOperation.RESULT.POSTING.ABOVE_MAX_MIN then
		return L["Above max price. Posting at min."]
	elseif result == AuctioningOperation.RESULT.POSTING.ABOVE_MAX_MAX then
		return L["Above max price. Posting at max."]
	elseif result == AuctioningOperation.RESULT.POSTING.ABOVE_MAX_NORMAL then
		return L["Above max price. Posting at normal."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.ABOVE_MAX_NO_POST then
		return L["Above max price. Not posting."]
	elseif result == AuctioningOperation.RESULT.POSTING.UNDERCUT then
		return L["Undercutting competition."]
	elseif result == AuctioningOperation.RESULT.POSTING.PLAYER then
		return L["Posting at your current price."]
	elseif result == AuctioningOperation.RESULT.WONT_CANCEL.DISABLED then
		return L["Canceling disabled."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.NOT_UNDERCUT then
		return L["Your auction has not been undercut."]
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.BID then
		return L["Auction has been bid on."]
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.NO_MONEY then
		return L["Not enough money to cancel."]
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.KEEP_POSTED then
		return L["Keeping undercut auctions posted."]
	elseif result == AuctioningOperation.RESULT.WONT_CANCEL.BELOW_MIN then
		return L["Not canceling auction below min price."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_RESET then
		return L["Not canceling auction at reset price."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_NORMAL then
		return L["At normal price and not undercut."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_ABOVE_MAX then
		return L["At above max price and not undercut."]
	elseif result == AuctioningOperation.RESULT.CANCELING.UNDERCUT then
		return L["You've been undercut."]
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS.REPOST then
		return L["Canceling to repost at higher price."]
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS.RESET then
		return L["Canceling to repost at reset price."]
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS.PLAYER_UNDERCUT then
		return L["Canceling auction you've undercut."]
	else
		error("Unknown result: "..tostring(result))
	end
end

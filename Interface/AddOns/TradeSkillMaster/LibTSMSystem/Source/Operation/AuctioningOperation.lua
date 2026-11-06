-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local AuctioningOperation = LibTSMSystem:Init("AuctioningOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local EnumType = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.EnumType")
local Math = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Math")
local Range = LibTSMSystem:From("LibTSMUtil"):IncludeClassType("Range")
local Money = LibTSMSystem:From("LibTSMUtil"):Include("UI.Money")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local private = {
	defaultZeroUndercut = nil,
	includeStackSize = nil,
	maxStackSizeFunc = nil,
	valueRange = nil, ---@type table<AuctioningOperationRangeKeys,Range>
}
local RESULT = EnumType.NewNested("AUCTIONING_OPERATION_RESULT", {
	INVALID = {
		ITEM_GROUP = {
			POST_CAP = EnumType.NewValue(),
			STACK_SIZE = EnumType.NewValue(),
			KEEP_QUANTITY = EnumType.NewValue(),
			MAX_EXPIRES = EnumType.NewValue(),
			MIN_PRICE = EnumType.NewValue(),
			MAX_PRICE = EnumType.NewValue(),
			NORMAL_PRICE = EnumType.NewValue(),
			UNDERCUT = EnumType.NewValue(),
			NORMAL_BELOW_MIN = EnumType.NewValue(),
			MAX_BELOW_MIN = EnumType.NewValue(),
			CANCEL_REPOST_THRESHOLD = EnumType.NewValue(),
			OTHER = EnumType.NewValue(),
		},
		SELLER = EnumType.NewValue(),
	},
	POSTING = {
		NORMAL = EnumType.NewValue(),
		RESET_MIN = EnumType.NewValue(),
		RESET_MAX = EnumType.NewValue(),
		RESET_NORMAL = EnumType.NewValue(),
		ABOVE_MAX_MIN = EnumType.NewValue(),
		ABOVE_MAX_MAX = EnumType.NewValue(),
		ABOVE_MAX_NORMAL = EnumType.NewValue(),
		UNDERCUT = EnumType.NewValue(),
		PLAYER = EnumType.NewValue(),
	},
	NOT_POSTING = {
		DISABLED = EnumType.NewValue(),
		NOT_ENOUGH = EnumType.NewValue(),
		MAX_EXPIRES = EnumType.NewValue(),
		BELOW_MIN = EnumType.NewValue(),
		ABOVE_MAX_NO_POST = EnumType.NewValue(),
	},
	POSTING_NOT_NEEDED = {
		TOO_MANY = EnumType.NewValue(),
	},
	CANCELING = {
		UNDERCUT = EnumType.NewValue(),
	},
	NOT_CANCELING = {
		NOT_UNDERCUT = EnumType.NewValue(),
		AT_RESET = EnumType.NewValue(),
		AT_NORMAL = EnumType.NewValue(),
		AT_ABOVE_MAX = EnumType.NewValue(),
	},
	CANCELING_NOT_NEEDED = {
		BID = EnumType.NewValue(),
		NO_MONEY = EnumType.NewValue(),
		KEEP_POSTED = EnumType.NewValue(),
	},
	CANCELING_EXCESS = {
		REPOST = EnumType.NewValue(),
		RESET = EnumType.NewValue(),
		PLAYER_UNDERCUT = EnumType.NewValue(),
	},
	WONT_CANCEL = {
		DISABLED = EnumType.NewValue(),
		BELOW_MIN = EnumType.NewValue(),
	},
})
AuctioningOperation.RESULT = RESULT
local OPERATION_TYPE = "Auctioning"
local COPPER_PER_SILVER = 100
local VALID_PRICE_KEYS = {
	minPrice = true,
	normalPrice = true,
	maxPrice = true,
	undercut = true,
	cancelRepostThreshold = true,
	priceReset = true,
	aboveMax = true,
	postCap = true,
	stackSize = true,
	keepQuantity = true,
	maxExpires = true,
}
local IS_GOLD_PRICE_KEY = {
	minPrice = true,
	normalPrice = true,
	maxPrice = true,
	undercut = nil, -- Set by AuctioningOperation.Load()
	priceReset = true,
	aboveMax = true,
}

---@class AuctioningOperationSettings: OperationSettings
---@field ignoreLowDuration number
---@field postCap string
---@field keepQuantity string
---@field maxExpires string
---@field duration number
---@field bidPercent number
---@field undercut string
---@field minPrice string
---@field maxPrice string
---@field normalPrice string
---@field priceReset string
---@field aboveMax string
---@field cancelUndercut boolean
---@field cancelRepost boolean
---@field cancelRepostThreshold string
---@field matchStackSize boolean
---@field stackSize string
---@field stackSizeIsCap boolean

---@class AuctioningOperationLowestAuction
---@field hasInvalidSeller boolean
---@field isPlayer boolean
---@field buyout number
---@field bid number
---@field seller string
---@field auctionId number

---@class AuctioningOperationListedAuction
---@field auctionId number
---@field itemBuyout number
---@field itemBid number
---@field stackSize number
---@field duration number
---@field hasBid boolean
---@field canAffordCancel boolean

---@class AuctioningOperationCancelScanResult
---@field isPlayerOnlySeller boolean
---@field playerLowestItemBuyout? number
---@field playerLowestAuctionId? number
---@field secondLowestBuyout number
---@field nonPlayerLowestAuctionId? number

---@alias AuctioningOperationRangeKeys
---| "keepQuantity"
---| "maxExpires"
---| "postCap"
---| "stackSize"



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctioningOperation:OnModuleLoad(function()
	Util.ConfigureItemPrices(OPERATION_TYPE, function(itemString, operationSettings, key)
		local value = nil
		local settingValue = operationSettings[key] --[[@as string]]
		if key == "aboveMax" or key == "priceReset" then
			-- Redirect to the selected price (if applicable)
			if VALID_PRICE_KEYS[settingValue] then
				value = private.GetItemPrice(itemString, settingValue, operationSettings)
			end
		else
			value = CustomString.GetValue(settingValue, itemString, not IS_GOLD_PRICE_KEY[key])
		end
		if LibTSMSystem.IsRetail() and IS_GOLD_PRICE_KEY[key] then
			value = value and Math.Ceil(value, COPPER_PER_SILVER) or nil
		end
		local range = private.valueRange[key]
		if range and value and not range:Includes(value) then
			value = nil
		end
		return value
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Auctioning operation code.
---@param localizedName string The localized operation type name
---@param defaultZeroUndercut boolean Whether the default undercut should be 0c
---@param maxStackSizeFunc? fun(itemString: string): number? Function to look up the max stack size (or nil if stack size shouldn't be considered)
function AuctioningOperation.Load(localizedName, defaultZeroUndercut, maxStackSizeFunc)
	assert(not private.valueRange)
	private.defaultZeroUndercut = defaultZeroUndercut
	private.includeStackSize = maxStackSizeFunc and true or false
	private.maxStackSizeFunc = maxStackSizeFunc
	private.valueRange = {
		keepQuantity = Range.StaticStartEnd(0, 50000),
		maxExpires = Range.StaticStartEnd(0, 50000),
		postCap = Range.StaticStartEnd(0, maxStackSizeFunc and 200 or 50000),
		stackSize = maxStackSizeFunc and Range.StaticStartEnd(1, 200) or nil,
	}
	if not defaultZeroUndercut then
		IS_GOLD_PRICE_KEY.undercut = true
	end
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 20)
		:SetCustomSanitizeFunc(private.SanitizeSettings)
		:AddNumberSetting("ignoreLowDuration")
		:AddCustomStringSetting("postCap", "5")
		:AddCustomStringSetting("keepQuantity", "0")
		:AddCustomStringSetting("maxExpires", "0")
		:AddNumberSetting("duration", 2, private.SanitizeDuration)
		:AddNumberSetting("bidPercent", 1)
		:AddCustomStringSetting("undercut", defaultZeroUndercut and "0c" or "1c", private.SanitizeUndercut)
		:AddCustomStringSetting("minPrice", "check(first(crafting,dbmarket,dbregionmarketavg),max(0.25*avg(crafting,dbmarket,dbregionmarketavg),1.5*vendorsell))")
		:AddCustomStringSetting("maxPrice", "check(first(crafting,dbmarket,dbregionmarketavg),max(5*avg(crafting,dbmarket,dbregionmarketavg),30*vendorsell))")
		:AddCustomStringSetting("normalPrice", "check(first(crafting,dbmarket,dbregionmarketavg),max(2*avg(crafting,dbmarket,dbregionmarketavg),12*vendorsell))")
		:AddStringSetting("priceReset", "none")
		:AddStringSetting("aboveMax", "maxPrice")
		:AddBooleanSetting("cancelUndercut", true)
		:AddBooleanSetting("cancelRepost", true)
		:AddCustomStringSetting("cancelRepostThreshold", "1g")
	if maxStackSizeFunc then
		operationType:AddBooleanSetting("matchStackSize")
		operationType:AddCustomStringSetting("stackSize", "1")
		operationType:AddBooleanSetting("stackSizeIsCap")
	end
	Operation.RegisterType(operationType)
end

---Gets the (static) range of valid values for a setting.
---@param key AuctioningOperationRangeKeys The setting key
---@return Range
function AuctioningOperation.GetSettingRange(key)
	local range = private.valueRange[key]
	assert(range)
	return range
end

---Gets the settings and name of the first operation for a given item.
---@param itemString string The itemString
---@return AuctioningOperationSettings? operationSettings
---@return string? name
function AuctioningOperation.GetFirstByItem(itemString)
	local operationSettings, name = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	return operationSettings --[[@as AuctioningOperationSettings?]], name
end

---Gets the value of the min price setting for a given item and (optionally) operation.
---@param itemString string The item string
---@param operationSettings? AuctioningOperationSettings The operation settings to use (otherwise looks up the first one for the item)
---@return number?
function AuctioningOperation.GetItemMinPrice(itemString, operationSettings)
	return private.GetItemPrice(itemString, "minPrice", operationSettings)
end

---Gets the value of the normal price setting for a given item and (optionally) operation.
---@param itemString string The item string
---@param operationSettings? AuctioningOperationSettings The operation settings to use (otherwise looks up the first one for the item)
---@return number?
function AuctioningOperation.GetItemNormalPrice(itemString, operationSettings)
	return private.GetItemPrice(itemString, "normalPrice", operationSettings)
end

---Gets the value of the max price setting for a given item and (optionally) operation.
---@param itemString string The item string
---@param operationSettings? AuctioningOperationSettings The operation settings to use (otherwise looks up the first one for the item)
---@return number?
function AuctioningOperation.GetItemMaxPrice(itemString, operationSettings)
	return private.GetItemPrice(itemString, "maxPrice", operationSettings)
end

---Gets the value of the undercut setting for a given item and (optionally) operation.
---@param itemString string The item string
---@param operationSettings? AuctioningOperationSettings The operation settings to use (otherwise looks up the first one for the item)
---@return number?
function AuctioningOperation.GetItemUndercut(itemString, operationSettings)
	return private.GetItemPrice(itemString, "undercut", operationSettings)
end

---Returns whether or not an auction is filtered by the operation
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param itemBuyout number The auction item buyout
---@param quantity number The auction stack size
---@param timeLeft number The auction duration
---@return boolean
function AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft)
	if timeLeft <= operationSettings.ignoreLowDuration then
		-- Ignoring low duration
		return true
	elseif private.maxStackSizeFunc and operationSettings.matchStackSize and quantity ~= private.GetItemPrice(itemString, "stackSize", operationSettings) then
		-- Matching stack size
		return true
	elseif operationSettings.priceReset == "ignore" then
		local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
		local undercut = private.GetItemPrice(itemString, "undercut", operationSettings)
		if minPrice and undercut and itemBuyout - undercut < minPrice then
			-- Ignoring auctions below threshold
			return true
		end
	end
	return false
end

---Returns whether or not more scan data is needed to make a posting decision.
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param numBuyouts number The number of non-filtered buyouts seen so far
---@param minItemBuyout? number The minimum non-filtered item buyout seen so far
---@return boolean
function AuctioningOperation.ShouldKeepScanningForPosting(itemString, operationSettings, numBuyouts, minItemBuyout)
	if numBuyouts == 0 or not minItemBuyout then
		return true
	end
	local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
	local undercut = private.GetItemPrice(itemString, "undercut", operationSettings)
	if not minPrice or not undercut then
		-- The min price or undercut is not valid, so just keep scanning
		return true
	elseif minItemBuyout - undercut <= minPrice then
		if operationSettings.priceReset == "ignore" then
			-- We need to keep scanning to find auctions above min to undercut
			return true
		end
		-- For non-ignore priceReset, the posting decision is already determined (post at reset price or don't post)
		return false
	end
	return numBuyouts <= 1
end

---Validates an operation for posting.
---@param itemString string The item string
---@param num number The number of items to consider posting
---@param operationSettings AuctioningOperationSettings The operation settings
---@return (true shouldPost, number num, number keepQuantity)
---|       (nil)
---|       (nil, EnumValue errType)
---|       (nil, EnumValue errType, string errArg)
---|       (false, EnumValue errType)
---|       (false, EnumValue errType, string errArg)
---|       (false, EnumValue errType, string errArg, string errArg2)
function AuctioningOperation.ValidateForPosting(itemString, num, operationSettings)
	local postCap = private.GetItemPrice(itemString, "postCap", operationSettings)
	if not postCap then
		return nil, RESULT.INVALID.ITEM_GROUP.POST_CAP, operationSettings.postCap
	elseif postCap == 0 then
		-- Posting disabled
		return nil, RESULT.NOT_POSTING.DISABLED
	end

	local stackSize = nil
	local minPostQuantity = nil
	if private.maxStackSizeFunc then
		stackSize = private.GetItemPrice(itemString, "stackSize", operationSettings)
		-- Check the stack size
		if not stackSize then
			return nil, RESULT.INVALID.ITEM_GROUP.STACK_SIZE, operationSettings.stackSize
		end
		local maxStackSize = private.maxStackSizeFunc(itemString)
		minPostQuantity = operationSettings.stackSizeIsCap and 1 or stackSize
		if not maxStackSize then
			return false, RESULT.INVALID.ITEM_GROUP.STACK_SIZE
		elseif maxStackSize < minPostQuantity then
			-- Invalid stack size
			return nil
		end
	else
		minPostQuantity = 1
	end

	-- Check that we have enough to post
	local keepQuantity = private.GetItemPrice(itemString, "keepQuantity", operationSettings)
	if not keepQuantity then
		-- Invalid keepQuantity setting
		return nil, RESULT.INVALID.ITEM_GROUP.KEEP_QUANTITY, operationSettings.keepQuantity
	end
	num = num - keepQuantity
	if num < minPostQuantity then
		-- Not enough items to post for this operation
		return nil, RESULT.NOT_POSTING.NOT_ENOUGH
	end

	-- Check the max expires
	if not private.GetItemPrice(itemString, "maxExpires", operationSettings) then
		-- Invalid maxExpires setting
		return nil, RESULT.INVALID.ITEM_GROUP.MAX_EXPIRES, operationSettings.maxExpires
	end
	if private.HasReachedMaxExpires(itemString, operationSettings) then
		-- Too many expires, so ignore this operation
		return nil, RESULT.NOT_POSTING.MAX_EXPIRES
	end

	local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
	local normalPrice = private.GetItemPrice(itemString, "normalPrice", operationSettings)
	local maxPrice = private.GetItemPrice(itemString, "maxPrice", operationSettings)
	local undercut = private.GetItemPrice(itemString, "undercut", operationSettings)
	if not minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MIN_PRICE, operationSettings.minPrice
	elseif not maxPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MAX_PRICE, operationSettings.maxPrice
	elseif not normalPrice then
		return false, RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE, operationSettings.normalPrice
	elseif not undercut then
		return false, RESULT.INVALID.ITEM_GROUP.UNDERCUT, operationSettings.undercut
	elseif normalPrice < minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN, operationSettings.normalPrice, operationSettings.minPrice
	elseif maxPrice < minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN, operationSettings.maxPrice, operationSettings.minPrice
	end

	if private.maxStackSizeFunc then
		if not operationSettings.stackSizeIsCap then
			num = Math.Floor(num, stackSize)
		end
		assert(stackSize)
		num = min(stackSize * postCap, num)
	else
		num = min(num, postCap)
	end
	return true, num, keepQuantity
end

---Check is the min price is below the vendor sell price for an item and operation.
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param vendorSellPrice number The vendor sell price for the item
---@return boolean
function AuctioningOperation.IsMinPriceBelowVendorSell(itemString, operationSettings, vendorSellPrice)
	local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
	return minPrice and minPrice <= vendorSellPrice / 0.95 or false
end

---Makes a posting decision for an item.
---@param itemString string The item string
---@param lowestAuction AuctioningOperationLowestAuction? The lowest auction info
---@param operationSettings AuctioningOperationSettings The operation settings
---@return EnumValue result
---@return string? seller
---@return number? bid
---@return number? buyout
---@return number? activeAuctionsBid
---@return number? activeAuctionsBuyout
function AuctioningOperation.MakePostDecision(itemString, lowestAuction, operationSettings)
	local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
	local normalPrice = private.GetItemPrice(itemString, "normalPrice", operationSettings)
	local maxPrice = private.GetItemPrice(itemString, "maxPrice", operationSettings)
	local undercut = private.GetItemPrice(itemString, "undercut", operationSettings)
	local resetPrice = private.GetItemPrice(itemString, "priceReset", operationSettings)
	local aboveMax = private.GetItemPrice(itemString, "aboveMax", operationSettings)
	if not minPrice then
		return RESULT.INVALID.ITEM_GROUP.MIN_PRICE
	elseif not maxPrice then
		return RESULT.INVALID.ITEM_GROUP.MAX_PRICE
	elseif not normalPrice then
		return RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE
	elseif not undercut then
		return RESULT.INVALID.ITEM_GROUP.UNDERCUT
	end

	local reason, bid, buyout, seller, activeAuctionsBid, activeAuctionsBuyout = nil, nil, nil, nil, nil, nil
	if not lowestAuction then
		-- Post as many as we can at the normal price
		reason = RESULT.POSTING.NORMAL
		buyout = normalPrice
	elseif lowestAuction.hasInvalidSeller then
		return RESULT.INVALID.SELLER
	elseif lowestAuction.buyout - undercut < minPrice then
		seller = lowestAuction.seller
		if resetPrice then
			-- Lowest is below the min price, but there is a reset price
			if operationSettings.priceReset == "minPrice" then
				reason = RESULT.POSTING.RESET_MIN
			elseif operationSettings.priceReset == "maxPrice" then
				reason = RESULT.POSTING.RESET_MAX
			elseif operationSettings.priceReset == "normalPrice" then
				reason = RESULT.POSTING.RESET_NORMAL
			else
				error("Invalid below min price: "..tostring(operationSettings.priceReset))
			end
			buyout = resetPrice
			bid = max(bid or buyout * operationSettings.bidPercent, minPrice)
			activeAuctionsBid = floor(bid)
			activeAuctionsBuyout = buyout
		else
			-- Don't post this item
			return RESULT.NOT_POSTING.BELOW_MIN, seller
		end
	elseif lowestAuction.isPlayer then
		-- We are lowest, so match the current price and post as many as we can
		activeAuctionsBid = lowestAuction.bid
		activeAuctionsBuyout = lowestAuction.buyout
		reason = RESULT.POSTING.PLAYER
		bid = lowestAuction.bid
		buyout = lowestAuction.buyout
		seller = lowestAuction.seller
	elseif (lowestAuction.buyout - undercut) > maxPrice then
		-- We'd be posting above the max price, so resort to the aboveMax setting
		seller = lowestAuction.seller
		if operationSettings.aboveMax == "minPrice" then
			reason = RESULT.POSTING.ABOVE_MAX_MIN
		elseif operationSettings.aboveMax == "maxPrice" then
			reason = RESULT.POSTING.ABOVE_MAX_MAX
		elseif operationSettings.aboveMax == "normalPrice" then
			reason = RESULT.POSTING.ABOVE_MAX_NORMAL
		elseif operationSettings.aboveMax == "none" then
			return RESULT.NOT_POSTING.ABOVE_MAX_NO_POST
		else
			error("Invalid above max price: "..tostring(operationSettings.aboveMax))
		end
		buyout = aboveMax
	else
		-- We just need to do a normal undercut of the lowest auction
		reason = RESULT.POSTING.UNDERCUT
		buyout = lowestAuction.buyout - undercut
		seller = lowestAuction.seller
	end
	assert(buyout)
	buyout = max(buyout, minPrice)
	bid = max(bid or buyout * operationSettings.bidPercent, minPrice)
	assert(reason == RESULT.POSTING)
	return reason, seller, bid, buyout, activeAuctionsBid, activeAuctionsBuyout
end

---Gets additional posting settings.
---@param operationSettings AuctioningOperationSettings The operation settings
---@return number duration
---@return boolean stackSizeIsCap
function AuctioningOperation.GetPostSettings(operationSettings)
	return operationSettings.duration, private.maxStackSizeFunc and operationSettings.stackSizeIsCap or false
end

---Gets the number of items to consider posting.
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@param numHave number The number available to post
---@return number? maxCanPost
---@return number? perAuction
---@return number? postCap
function AuctioningOperation.GetPostQuantities(itemString, operationSettings, numHave)
	local perAuction, maxCanPost = nil, nil
	local postCap = private.GetItemPrice(itemString, "postCap", operationSettings)
	if not postCap then
		return nil, nil, nil
	end
	if private.maxStackSizeFunc then
		local stackSize = private.GetItemPrice(itemString, "stackSize", operationSettings)
		local maxStackSize = private.maxStackSizeFunc(itemString)
		if not stackSize or not maxStackSize or (stackSize > maxStackSize and not operationSettings.stackSizeIsCap) then
			return nil, nil, nil
		end

		perAuction = min(stackSize, maxStackSize)
		maxCanPost = min(floor(numHave / perAuction), postCap)
		if maxCanPost == 0 then
			if operationSettings.stackSizeIsCap then
				perAuction = numHave
				maxCanPost = 1
			else
				-- Not enough for single post
				return nil, nil, nil
			end
		end
	else
		perAuction = min(postCap, numHave)
		maxCanPost = 1
	end
	return maxCanPost, perAuction, postCap
end

---Validates an operation for canceling.
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings
---@return EnumValue? errType
---@return any? errArg
---@return any? errArg2
function AuctioningOperation.ValidateForCanceling(itemString, operationSettings)
	if not operationSettings.cancelUndercut and not operationSettings.cancelRepost then
		return RESULT.WONT_CANCEL.DISABLED
	end

	local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
	local normalPrice = private.GetItemPrice(itemString, "normalPrice", operationSettings)
	local maxPrice = private.GetItemPrice(itemString, "maxPrice", operationSettings)
	local undercut = private.GetItemPrice(itemString, "undercut", operationSettings)
	local cancelRepostThreshold = private.GetItemPrice(itemString, "cancelRepostThreshold", operationSettings)
	if not minPrice then
		return RESULT.INVALID.ITEM_GROUP.MIN_PRICE, operationSettings.minPrice
	elseif not maxPrice then
		return RESULT.INVALID.ITEM_GROUP.MAX_PRICE, operationSettings.maxPrice
	elseif not normalPrice then
		return RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE, operationSettings.normalPrice
	elseif operationSettings.cancelRepost and not cancelRepostThreshold then
		return RESULT.INVALID.ITEM_GROUP.CANCEL_REPOST_THRESHOLD, operationSettings.cancelRepostThreshold
	elseif not undercut then
		return RESULT.INVALID.ITEM_GROUP.UNDERCUT, operationSettings.undercut
	elseif maxPrice < minPrice then
		return RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN, operationSettings.maxPrice, operationSettings.minPrice
	elseif normalPrice < minPrice then
		return RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN, operationSettings.normalPrice, operationSettings.minPrice
	else
		return nil
	end
end

---Makes a canceling decision for an item.
---@param itemString string The item string
---@param operationSettings AuctioningOperationSettings The operation settings to use
---@param lowestAuction AuctioningOperationLowestAuction? The lowest auction info
---@param listedAuction AuctioningOperationListedAuction The listed auction info
---@param scanResult AuctioningOperationCancelScanResult The scan result info
---@return boolean handled
---@return EnumValue? result
function AuctioningOperation.MakeCancelDecision(itemString, operationSettings, lowestAuction, listedAuction, scanResult)
	if private.maxStackSizeFunc and operationSettings.matchStackSize and listedAuction.stackSize ~= private.GetItemPrice(itemString, "stackSize", operationSettings) then
		return false
	elseif listedAuction.hasBid then
		-- Don't cancel an auction if it has a bid and we're set to not cancel those
		return true, AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.BID
	elseif not listedAuction.canAffordCancel then
		return true, AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.NO_MONEY
	end


	local normalPrice = private.GetItemPrice(itemString, "normalPrice", operationSettings)
	local cancelRepostThreshold = operationSettings.cancelRepost and private.GetItemPrice(itemString, "cancelRepostThreshold", operationSettings) or nil
	if not lowestAuction and normalPrice and cancelRepostThreshold and normalPrice - listedAuction.itemBuyout > cancelRepostThreshold then
		-- All auctions which are posted (including ours) have been ignored, cancel to repost higher
		return true, AuctioningOperation.RESULT.CANCELING_EXCESS.REPOST
	elseif not lowestAuction then
		return false, AuctioningOperation.RESULT.NOT_CANCELING.NOT_UNDERCUT
	elseif lowestAuction.hasInvalidSeller then
		return false, AuctioningOperation.RESULT.INVALID.SELLER
	end

	local minPrice = private.GetItemPrice(itemString, "minPrice", operationSettings)
	local maxPrice = private.GetItemPrice(itemString, "maxPrice", operationSettings)
	local resetPrice = private.GetItemPrice(itemString, "priceReset", operationSettings)
	local undercut = private.GetItemPrice(itemString, "undercut", operationSettings)
	local aboveMax = private.GetItemPrice(itemString, "aboveMax", operationSettings)
	if not minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MIN_PRICE
	elseif not maxPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MAX_PRICE
	elseif not normalPrice then
		return false, RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE
	elseif operationSettings.cancelRepost and not cancelRepostThreshold then
		return false, RESULT.INVALID.ITEM_GROUP.CANCEL_REPOST_THRESHOLD
	elseif not undercut then
		return false, RESULT.INVALID.ITEM_GROUP.UNDERCUT
	end
	if listedAuction.itemBuyout < minPrice then
		-- This auction is below the min price
		if cancelRepostThreshold and resetPrice and listedAuction.itemBuyout < (resetPrice - cancelRepostThreshold) then ---@diagnostic disable-line: invalid-op
			-- Canceling to post at reset price
			return true, RESULT.CANCELING_EXCESS.RESET
		else
			return false, RESULT.WONT_CANCEL.BELOW_MIN
		end
	elseif lowestAuction.buyout < minPrice then
		-- Lowest buyout is below min price, so do nothing
		return false, RESULT.WONT_CANCEL.BELOW_MIN
	elseif operationSettings.cancelUndercut and scanResult.playerLowestItemBuyout and ((listedAuction.itemBuyout - undercut) > scanResult.playerLowestItemBuyout or (private.defaultZeroUndercut and (listedAuction.itemBuyout - undercut) == scanResult.playerLowestItemBuyout and listedAuction.auctionId ~= scanResult.playerLowestAuctionId and listedAuction.auctionId < (scanResult.nonPlayerLowestAuctionId or 0))) then
		-- We've undercut this auction
		return true, RESULT.CANCELING_EXCESS.PLAYER_UNDERCUT
	elseif scanResult.isPlayerOnlySeller then
		-- We are the only auction
		if cancelRepostThreshold and (normalPrice - listedAuction.itemBuyout) > cancelRepostThreshold then
			-- We can repost higher
			return true, RESULT.CANCELING_EXCESS.REPOST
		else
			return false, RESULT.NOT_CANCELING.AT_NORMAL
		end
	elseif lowestAuction.isPlayer and scanResult.secondLowestBuyout and scanResult.secondLowestBuyout > maxPrice then
		-- We are posted at the aboveMax price with no competition under our max price
		if cancelRepostThreshold and aboveMax and (aboveMax - listedAuction.itemBuyout) > cancelRepostThreshold then
			-- We can repost higher
			return true, RESULT.CANCELING_EXCESS.REPOST
		else
			return false, RESULT.NOT_CANCELING.AT_ABOVE_MAX
		end
	elseif lowestAuction.isPlayer then
		-- We are the lowest auction
		if cancelRepostThreshold and scanResult.secondLowestBuyout and ((scanResult.secondLowestBuyout - undercut) - lowestAuction.buyout) > cancelRepostThreshold then
			-- We can repost higher
			return true, RESULT.CANCELING_EXCESS.REPOST
		else
			return false, RESULT.NOT_CANCELING.NOT_UNDERCUT
		end
	elseif not operationSettings.cancelUndercut then
		-- We're undercut but not canceling undercut auctions
		return false, nil
	else
		-- We've been undercut
		return true, RESULT.CANCELING.UNDERCUT
	end
end

---Gets the total quantity which can be posted on the AH.
---@param itemString string The item string
---@return number
function AuctioningOperation.GetTotalPostQuantity(itemString)
	local moveQuantity = 0
	for _, operationSettings in Util.OperationIteratorByItem(OPERATION_TYPE, itemString) do
		---@cast operationSettings AuctioningOperationSettings
		moveQuantity = moveQuantity + private.GetTotalQuantity(itemString, operationSettings)
	end
	return moveQuantity
end

---Checks whether or not any of the item's operations have reached their max expires.
---@param itemString string The item string
---@return boolean
function AuctioningOperation.HasReachedMaxExpires(itemString)
	local result = false
	for _, operationSettings in Util.OperationIteratorByItem(OPERATION_TYPE, itemString) do
		---@cast operationSettings AuctioningOperationSettings
		result = result or private.HasReachedMaxExpires(itemString, operationSettings)
	end
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param operationSettings AuctioningOperationSettings
function private.SanitizeSettings(operationSettings)
	if not private.includeStackSize and operationSettings.stackSize and tonumber(operationSettings.postCap) and tonumber(operationSettings.stackSize) then
		operationSettings.postCap = tonumber(operationSettings.postCap) * tonumber(operationSettings.stackSize) ---@diagnostic disable-line: invalid-op
	end
	if private.defaultZeroUndercut and (type(operationSettings.undercut) == "number" and operationSettings.undercut or Money.FromString(operationSettings.undercut) or math.huge) < COPPER_PER_SILVER then
		operationSettings.undercut = "0c"
	end
end

function private.SanitizeDuration(value)
	-- convert from 12/24/48 durations to 1/2/3 API values
	if value == 12 then
		return 1
	elseif value == 24 then
		return 2
	elseif value == 48 then
		return 3
	else
		return value
	end
end

function private.SanitizeUndercut(value)
	local copperValue = tonumber(value)
	if private.defaultZeroUndercut and (Money.FromString(copperValue and Money.ToStringExact(copperValue) or value) or math.huge) < COPPER_PER_SILVER then
		return "0c"
	end
	return value
end

function private.GetItemPrice(itemString, key, operationSettings)
	return Util.GetItemPrice(OPERATION_TYPE, itemString, key, operationSettings)
end

---@param operationSettings AuctioningOperationSettings
function private.HasReachedMaxExpires(itemString, operationSettings)
	local maxExpires = private.GetItemPrice(itemString, "maxExpires", operationSettings) or 0
	if maxExpires == 0 then
		return false
	end
	local numExpires = CustomString.GetSourceValue("NumExpires", itemString) or 0
	return numExpires >= maxExpires
end

---@param operationSettings AuctioningOperationSettings
function private.GetTotalQuantity(itemString, operationSettings)
	if private.HasReachedMaxExpires(itemString, operationSettings) then
		return 0
	end
	local _, stackSize, postCap = AuctioningOperation.GetPostQuantities(itemString, operationSettings, math.huge)
	if not stackSize or not postCap then
		return 0
	end
	if not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic() then
		stackSize = 1
	end
	return stackSize * postCap
end

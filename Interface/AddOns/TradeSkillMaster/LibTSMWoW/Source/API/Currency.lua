-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Currency = LibTSMWoW:Init("API.Currency")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the current player money amount.
---@return number
function Currency.GetMoney()
	return GetMoney()
end

---Gets the max player money.
---@return number
function Currency.GetMaxMoney()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		return MAXIMUM_BID_PRICE
	elseif LibTSMWoW.IsMistsClassic() then
		return 9999999999
	else
		return 2147483647
	end
end

---Gets info on a currency.
---@param id number The currency ID
---@return string? name
---@return number? texture
---@return number? quantity
---@return number? maxQuantity
function Currency.GetInfo(id)
	local info = C_CurrencyInfo.GetCurrencyInfo(id) --[[@as CurrencyInfo?]]
	if not info then
		return nil, nil, nil, nil
	end
	return info.name, info.iconFileID, info.quantity, info.maxQuantity
end

---Gets how often a currency recharges.
---@param id number The currency ID
---@return number? seconds
function Currency.GetRechargeDuration(id)
	local info = C_CurrencyInfo.GetCurrencyInfo(id) --[[@as CurrencyInfo?]]
	if not info or info.rechargingCycleDurationMS <= 0 then
		return nil
	end
	return info.rechargingCycleDurationMS / 1000
end

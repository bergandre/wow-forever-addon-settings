-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local EnumTypes = LibTSMTypes:Init("EnumTypes")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")



-- ============================================================================
-- Auction House
-- ============================================================================

EnumTypes.AUCTIONING_SCAN_TYPE = EnumType.New("AUCTIONING_SCAN_TYPE", {
	CANCEL = EnumType.NewValue(),
	POST = EnumType.NewValue(),
})

EnumTypes.SHOPPING_SEARCH_MODE = EnumType.New("SHOPPING_SEARCH_MODE", {
	NORMAL = EnumType.NewValue(),
	DISENCHANT = EnumType.NewValue(),
	CRAFTING = EnumType.NewValue(),
})



-- ============================================================================
-- Banking
-- ============================================================================

EnumTypes.BANKING_MOVE_TYPE = EnumType.New("BANKING_MOVE_TYPE", {
	EMPTY_BAGS = EnumType.NewValue(),
	RESTORE_BAGS = EnumType.NewValue(),
	GROUPS_TO_BANK = EnumType.NewValue(),
	AUCTIONING_POST_CAP_TO_BAGS = EnumType.NewValue(),
	AUCTIONING_SHORTFALL_TO_BAGS = EnumType.NewValue(),
	AUCTIONING_MAX_EXPIRES_TO_BANK = EnumType.NewValue(),
	MAILING_NON_GROUP_TO_BANK = EnumType.NewValue(),
	MAILING_TARGET_SHORTFALL_TO_BAGS = EnumType.NewValue(),
	WAREHOUSING_GROUPS_TO_BANK = EnumType.NewValue(),
	WAREHOUSING_GROUPS_TO_BAGS = EnumType.NewValue(),
	WAREHOUSING_RESTOCK_BAGS = EnumType.NewValue(),
	WAREHOUSING_DEPOSIT_REAGENTS = EnumType.NewValue(),
	WAREHOUSING_DEPOSIT_WARBOUND = EnumType.NewValue(),
})

EnumTypes.BANKING_TAB = EnumType.New("BANKING_TAB", {
	WAREHOUSING = EnumType.NewValue(),
	AUCTIONING = EnumType.NewValue(),
	MAILING = EnumType.NewValue(),
})



-- ============================================================================
-- Dashboard
-- ============================================================================

EnumTypes.DASHBOARD_TIME_RANGE = EnumType.New("DASHBOARD_TIME_RANGE", {
	ONE_DAY = EnumType.NewValue(),
	ONE_WEEK = EnumType.NewValue(),
	ONE_MONTH = EnumType.NewValue(),
	THREE_MONTH = EnumType.NewValue(),
	SIX_MONTH = EnumType.NewValue(),
	ONE_YEAR = EnumType.NewValue(),
	TWO_YEAR = EnumType.NewValue(),
	ALL = EnumType.NewValue(),
})



-- ============================================================================
-- Mailing
-- ============================================================================

EnumTypes.MAILING_OPEN_TYPE = EnumType.New("MAILING_OPEN_TYPE", {
	ALL = EnumType.NewValue(),
	SALE = EnumType.NewValue(),
	BUY = EnumType.NewValue(),
	CANCEL = EnumType.NewValue(),
	EXPIRE = EnumType.NewValue(),
	OTHER = EnumType.NewValue(),
})

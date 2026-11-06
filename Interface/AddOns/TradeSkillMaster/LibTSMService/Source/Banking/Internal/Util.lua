-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Util = LibTSMService:InitInternal("Banking.Util")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
Util.FRAME = EnumType.NewNested("BANKING_FRAME", {
	CONTAINER = {
		BAG = EnumType.NewValue(),
		BANK = EnumType.NewValue(),
		WARBANK = EnumType.NewValue(),
	},
	GUILD_BANK = EnumType.NewValue(),
})

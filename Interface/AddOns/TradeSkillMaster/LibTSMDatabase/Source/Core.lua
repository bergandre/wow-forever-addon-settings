-- ------------------------------------------------------------------------------ --
--                                 LibTSMDatabase                                 --
--               https://github.com/TradeSkillMaster/LibTSMDatabase               --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMDatabase = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMDatabase")
	:AddDependency("LibTSMReactive")
	:AddDependency("LibTSMUtil")

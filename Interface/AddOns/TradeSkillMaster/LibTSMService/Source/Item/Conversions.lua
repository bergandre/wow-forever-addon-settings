-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Conversions = LibTSMService:Init("Item.Conversions")
local DisenchantData = LibTSMService:From("LibTSMData"):Include("Disenchant")
local Conversion = LibTSMService:From("LibTSMTypes"):Include("Item.Conversion")
local ItemClass = LibTSMService:From("LibTSMWoW"):Include("Util.ItemClass")
local DISENCHANT_CLASS_ID_LOOKUP = {
	[DisenchantData.ITEM_CLASSES.ARMOR] = ItemClass.GetArmorClassId(),
	[DisenchantData.ITEM_CLASSES.WEAPON] = ItemClass.GetWeaponClassId(),
	[DisenchantData.ITEM_CLASSES.PROFESSION] = ItemClass.GetProfessionClassId(),
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets info on the source item which disenchanting into the specified target item.
---@param targetItemString string The item string of the target item
---@param classId number The class ID of the source item
---@param quality number The quality of the source item
---@param itemLevel number The item level of the source item
---@param expansion? number The expansion of the source item
---@return (number amountOfMats, number matRate, number minAmount, number maxAmount, number? requiredSkill)
---|       (nil, nil, nil, nil, nil)
function Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
	local amountOfMats, matRate, minAmount, maxAmount, requiredSkill = nil, nil, nil, nil, nil
	local data = Conversion.GetDisenchantData(targetItemString)
	assert(data)
	for _, info in ipairs(data.sourceInfo) do
		local sourceClassId = DISENCHANT_CLASS_ID_LOOKUP[info.class]
		assert(sourceClassId)
		if sourceClassId == classId and info.quality == quality and itemLevel >= info.minItemLevel and itemLevel <= info.maxItemLevel and (not expansion or expansion == data.expansion) then
			amountOfMats = info.amountOfMats
			matRate = info.matRate
			minAmount = info.minAmount
			maxAmount = info.maxAmount
			requiredSkill = info.requiredSkill
			break
		end
	end
	return amountOfMats, matRate, minAmount, maxAmount, requiredSkill
end

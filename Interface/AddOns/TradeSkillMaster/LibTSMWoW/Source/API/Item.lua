-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Item = LibTSMWoW:Init("API.Item")
local ItemClass = LibTSMWoW:Include("Util.ItemClass")
local MAX_STACK_SIZE = 4000
local MAX_ITEM_LEVEL = nil
if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
	MAX_ITEM_LEVEL = 350
elseif LibTSMWoW.IsMistsClassic() then
	MAX_ITEM_LEVEL = 600
else
	MAX_ITEM_LEVEL = 200
end



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets item info or queries it if it's not already loaded.
---@param item string|number The WoW item string
---@return string? name
---@return string? link
---@return Enum.ItemQuality? quality
---@return number? itemLevel
---@return number? minLevel
---@return number? maxStack
---@return number? vendorSell
---@return number isBoP
---@return number? expansionId
---@return boolean? isCraftingReagent
function Item.GetInfo(item)
	local name, link, quality, itemLevel, minLevel, _, _, maxStack, _, _, vendorSell, _, _, bindType, expansionId, _, isCraftingReagent = C_Item.GetItemInfo(item)
	local isBoP = (bindType == LE_ITEM_BIND_ON_ACQUIRE or bindType == LE_ITEM_BIND_QUEST) and 1 or 0
	-- Some items (i.e. "i:117356::1:573") produce a negative min level
	---@cast minLevel number?
	minLevel = minLevel and max(minLevel, 0) or nil
	-- Some items (i.e. "i:40752" produce a very high max stack, so cap it)
	---@cast maxStack number?
	maxStack = maxStack and min(maxStack, MAX_STACK_SIZE) or nil
	return name, link, quality, itemLevel, minLevel, maxStack, vendorSell, isBoP, expansionId, isCraftingReagent
end

---Gets precached item info.
---@param itemId number The item ID
---@return number? texture
---@return number? classId
---@return number? subClassId
---@return number? invSlotId
function Item.GetInfoInstant(itemId)
	local _, classStr, subClassStr, equipSlot, texture, classId, subClassId = C_Item.GetItemInfoInstant(itemId)
	---@cast texture number?
	---@cast equipSlot string?
	equipSlot = equipSlot and equipSlot ~= "" and _G[equipSlot] or nil
	if not texture then
		return nil, nil, nil, nil
	end
	-- Some items (such as i:37445) give a classId of -1 for some reason in which case we can look up the classId
	if classId < 0 then
		classId = ItemClass.GetClassIdFromClassString(classStr)
		if not classId and not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever() then
			-- This can happen for items which don't yet exist in classic (i.e. WoW Tokens)
			return nil, nil, nil, nil
		end
		assert(subClassStr == "")
		subClassId = 0
	end
	local invSlotId = equipSlot and ItemClass.GetInventorySlotIdFromInventorySlotString(equipSlot) or 0
	return texture, classId, subClassId, invSlotId
end

---Gets the detailed item level for an item.
---@param item string The WoW item string
---@return number?
function Item.GetDetailedItemLevel(item)
	local itemLevel = C_Item.GetDetailedItemLevelInfo(item)
	return itemLevel
end

---Gets info on a pet.
---@param speciesId number The pet species ID
---@return (string name, number texture, number petTypeId)|(nil, nil, nil)
function Item.GetPetInfo(speciesId)
	local name, texture, petTypeId = C_PetJournal.GetPetInfoBySpeciesID(speciesId)
	if not texture or not petTypeId then
		return nil, nil, nil
	end
	return name, texture, petTypeId
end

---Requests loading of all pet info.
function Item.LoadPetInfo()
	for i = 1, C_PetJournal.GetNumPets() do
		C_PetJournal.GetPetInfoByIndex(i)
	end
end

---Returns whether or not items of a class can have variations (potentially only with a specific sub class ID).
---@param classId number The class ID
---@return (true canHaveVariations, number? specificSubClassId)|(false, nil)
function Item.ClassCanHaveVariations(classId)
	if classId == Enum.ItemClass.Armor or classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Battlepet then
		return true, nil
	elseif classId == Enum.ItemClass.Gem then
		return true, Enum.ItemGemSubclass.Artifactrelic
	else
		return false, nil
	end
end

---Returns whether or not the variation impacts the quality of the item for a given class.
---@param classId number The class ID
---@return boolean
function Item.VariationImpactsQualityByClass(classId)
	return classId == Enum.ItemClass.Armor or classId == Enum.ItemClass.Weapon
end

---Returns whether or not items of a class are disenchantable.
---@param classId number The class ID
---@return boolean
function Item.IsClassDisenchantable(classId)
	return classId == Enum.ItemClass.Armor or classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Profession
end

---Returns whether or not items of an inventory slot are disenchantable.
---@param invSlotId number The inventory slot ID
---@return boolean
function Item.IsInventorySlotDisenchantable(invSlotId)
	return invSlotId ~= Enum.InventoryType.IndexBodyType and invSlotId ~= Enum.InventoryType.IndexTabardType
end

---Returns whether or not items of a quality are disenchantable.
---@param quality number The quality
---@return boolean
function Item.IsQualityDisenchantable(quality)
	return quality >= (Enum.ItemQuality.Good or Enum.ItemQuality.Uncommon) and quality < Enum.ItemQuality.Legendary ---@diagnostic disable-line: undefined-field, redundant-or
end

---Returns whether or not items of a quality are considered trash.
---@param quality number The quality
---@return boolean
function Item.IsQualityTrash(quality)
	return quality == Enum.ItemQuality.Poor
end

---Returns whether or not items of a class and sub class are millable.
---@param classId number The class ID
---@param subClassId number The sub class ID
---@return boolean
function Item.IsClassMillable(classId, subClassId)
	return classId == Enum.ItemClass.Tradegoods and subClassId == ItemClass.GetTradegoodsSubClassHerb()
end

---Returns whether or not items of a class and sub class are prospectable.
---@param classId number The class ID
---@param subClassId number The sub class ID
---@return boolean
function Item.IsClassProspectable(classId, subClassId)
	return classId == Enum.ItemClass.Tradegoods and subClassId == ItemClass.GetTradegoodsSubClassMetalAndStone()
end

---Gets the color prefix string for a given item quality.
---@param quality number The quality
---@return string?
function Item.GetQualityColor(quality)
	return ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex or nil
end

---Gets the color prefix string for a given item quality.
---@param quality number The quality
---@return (number r, number g, number b)|(nil)
function Item.GetQualityColorRGB(quality)
	local info = ITEM_QUALITY_COLORS[quality]
	return info and info.color:GetRGB()
end

---Gets the item family.
---@param link string The item link
---@param classId number The class ID
---@return number
function Item.GetFamily(link, classId)
	if classId == Enum.ItemClass.Container then
		-- Bags report their family as what can go inside them, not what they can go inside
		return 0
	end
	return C_Item.GetItemFamily(link) or 0
end

---Installs a hook for an item being linked.
---@param hookFunc fun(link: string): boolean The hook function
function Item.HookLink(hookFunc)
	local origHandleModifiedItemClick = HandleModifiedItemClick
	HandleModifiedItemClick = function(link, ...)
		return origHandleModifiedItemClick(link, ...) or hookFunc(link)
	end
	local origChatEdit_InsertLink = ChatEdit_InsertLink
	ChatEdit_InsertLink = function(link, ...)
		return origChatEdit_InsertLink(link, ...) or hookFunc(link)
	end
end

---Handles a modified item click from a UI.
---@param link string The link of the item which was clicked on
function Item.HandleModifiedItemClick(link)
	if IsShiftKeyDown() then
		-- Extract the Blizzard itemString for both items and pets
		local blizzItemString = strmatch(link, "^\124c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\124H(item:[^\124]+)\124.+$")
		blizzItemString = blizzItemString or strmatch(link, "^\124c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\124H(battlepet:[^\124]+)\124.+$")
		blizzItemString = blizzItemString or strmatch(link, "^\124nIQ[0-9]:\124H(item:[^\124]+)\124.+$")
		blizzItemString = blizzItemString or strmatch(link, "^\124nIQ[0-9]:\124H(battlepet:[^\124]+)\124.+$")
		if blizzItemString then
			SetItemRef(blizzItemString, link, "LeftButton")
		end
	elseif IsControlKeyDown() then
		DressUpItemLink(link)
	end
end

---Gets the max item level.
---@return number
function Item.GetMaxItemLevel()
	return MAX_ITEM_LEVEL
end

---Uses an item by name.
---@param name string The item name
function Item.UseByName(name)
	C_Item.UseItemByName(name)
end

---Gets the localized string for a quality.
---@param quality number The quality
---@return string
function Item.GetQualityString(quality)
	return _G["ITEM_QUALITY"..quality.."_DESC"]
end

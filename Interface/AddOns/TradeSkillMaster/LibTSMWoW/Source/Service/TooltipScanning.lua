-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local TooltipScanning = LibTSMWoW:Init("Service.TooltipScanning")
local Container = LibTSMWoW:Include("API.Container")
local SlotId = LibTSMWoW:Include("Type.SlotId")
local String = LibTSMWoW:From("LibTSMUtil"):Include("Lua.String")
local private = {
	tooltip = nil, ---@type GameTooltip!
}

---@class BattlePetTooltipData: TooltipData
---@correlated battlePetSpeciesID, battlePetLevel, battlePetBreedQuality
---@field battlePetSpeciesID number?
---@field battlePetLevel number?
---@field battlePetBreedQuality number?



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets whether or not there are used charges for an item in the inventory (can not be used on clients with C_TooltipInfo).
---@param slotId number The slot ID
---@return boolean
function TooltipScanning.HasUsedCharges(slotId)
	assert(not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever())
	local itemId = Container.GetItemId(slotId)
	if not itemId then
		-- No item in this slot
		return false
	end

	-- Check if the item has max charges
	private.PrepareTooltip()
	local info = nil
	private.tooltip:SetItemByID(itemId)
	local maxCharges = private.ScanTooltipCharges(info)
	if not maxCharges then
		return false
	end

	-- Check if there are used charges on the container item
	private.PrepareTooltip()
	local bag, slot = SlotId.Split(slotId)
	if (not LibTSMWoW.IsRetail() and not LibTSMWoW.IsForever()) and bag == BANK_CONTAINER then
		private.tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
	else
		private.tooltip:SetBagItem(bag, slot)
	end
	if maxCharges and private.ScanTooltipCharges(info) ~= maxCharges then
		return true
	end
	return false
end

---Gets the max unique quantity of an item in the inbox.
---@param index number The index
---@param attachIndex number The attachment index
---@return number
function TooltipScanning.GetInboxMaxUnique(index, attachIndex)
	local speciesId, info = nil, nil
	private.PrepareTooltip()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		info = C_TooltipInfo.GetInboxItem(index, attachIndex) --[[@as BattlePetTooltipData]]
		speciesId = info.battlePetSpeciesID
	else
		speciesId = select(2, private.tooltip:SetInboxItem(index, attachIndex)) ---@diagnostic disable-line: redundant-parameter
	end
	if speciesId and speciesId > 0 then
		-- No max for battle pets
		return 0
	end

	for _, text in private.TooltipLineIterator(info) do
		if text == PROFESSIONS_MODIFIED_CRAFTING_REAGENT_BASIC then
			return 0
		elseif text == ITEM_UNIQUE then
			return 1
		else
			local match = strmatch(text, "^"..ITEM_UNIQUE.." %((%d+)%)$")
			if match then
				return tonumber(match) --[[@as number]]
			end
		end
	end

	return 0
end

---Gets battle pet info for an inbox item.
---@param index number The index
---@param attachIndex number The attachment index
---@return (number speciesId, number level, number quality)
---|       (nil, nil, nil)
function TooltipScanning.GetInboxBattlePetInfo(index, attachIndex)
	private.PrepareTooltip()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		local info = C_TooltipInfo.GetInboxItem(index, attachIndex) --[[@as BattlePetTooltipData]]
		if not info.battlePetSpeciesID then
			return nil, nil, nil
		end
		return info.battlePetSpeciesID, info.battlePetLevel, info.battlePetBreedQuality
	else
		local speciesId, level, quality = select(2, private.tooltip:SetInboxItem(index, attachIndex)) ---@diagnostic disable-line: redundant-parameter
		---@cast speciesId number?
		---@cast level number?
		---@cast quality number?
		---@correlated speciesId, level, quality
		if not speciesId then
			return nil, nil, nil
		end
		return speciesId, level, quality
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PrepareTooltip()
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		return
	end
	private.tooltip = private.tooltip or CreateFrame("GameTooltip", "TSMScanTooltip", UIParent, "GameTooltipTemplate")
	private.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	private.tooltip:ClearLines()
end

function private.ScanTooltipCharges(info)
	for _, text in private.TooltipLineIterator(info) do
		if text == PROFESSIONS_MODIFIED_CRAFTING_REAGENT_BASIC then
			return false
		end
		local maxCharges = nil
		if strfind(ITEM_SPELL_CHARGES, ":") then
			maxCharges = tonumber(strmatch(text, "^(%d+) "..String.StrictMatch(ITEM_SPELL_CHARGES, "\1244.+:(.+);").."$")) or tonumber(strmatch(text, "^(%d+) "..String.StrictMatch(ITEM_SPELL_CHARGES, "\1244(.+):.+;").."$"))
		else
			maxCharges = tonumber(strmatch(text, "^(%d+)"..String.StrictMatch(ITEM_SPELL_CHARGES, "%%d(.+)").."$"))
		end
		if maxCharges then
			return maxCharges
		end
	end
	return false
end

function private.TooltipLineIterator(info)
	if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
		assert(info)
		return private.TooltipLineIteratorHelper, info, 1
	else
		assert(not info)
		return private.TooltipLineIteratorHelper, nil, 1
	end
end

function private.TooltipLineIteratorHelper(info, index)
	while true do
		index = index + 1
		local numLines = (LibTSMWoW.IsRetail() or LibTSMWoW.IsForever()) and #info.lines or private.tooltip:NumLines()
		if index > numLines then
			return
		end
		local text = nil
		if LibTSMWoW.IsRetail() or LibTSMWoW.IsForever() then
			text = info.lines[index].leftText
		else
			local tooltipText = _G["TSMScanTooltipTextLeft"..index]
			text = strtrim(tooltipText and tooltipText:GetText() or "")
		end
		if text and text ~= "" then
			return index, text
		end
	end
end

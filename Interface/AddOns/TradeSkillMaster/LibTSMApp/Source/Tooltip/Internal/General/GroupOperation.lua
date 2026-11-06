-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local GroupOperation = LibTSMApp:InitInternal("Tooltip.General.GroupOperation")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local GroupOperationTypes = LibTSMApp:From("LibTSMTypes"):Include("GroupOperation")
local Operation = LibTSMApp:From("LibTSMTypes"):Include("Operation")
local private = {}
local GROUP_TEXT = L["Group"]
local GROUP_ITEM_LEVEL_TEXT = GROUP_TEXT.." ("..L["Item Level"]..")"
local GROUP_BASE_ITEM_TEXT = GROUP_TEXT.." ("..L["Base Item"]..")"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds tooltip entries.
---@param tooltipInfo TooltipInfo
function GroupOperation.AddEntries(tooltipInfo)
	tooltipInfo:AddSettingEntry("groupNameTooltip", nil, private.PopulateGroupLine)
	for _, typeName in Operation.TypeIterator() do
		tooltipInfo:AddSettingEntry("operationTooltips."..typeName, false, function(tooltip, itemString)
			private.PopulateOperationLine(tooltip, itemString, typeName)
		end)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param tooltip TooltipBuilder
function private.PopulateGroupLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(GROUP_TEXT, L["Example"])
		return
	end

	local groupPath = Group.GetPathByItem(itemString)
	if groupPath == Group.GetRootPath() then
		return
	end

	local leftText = nil
	if Group.IsItemInGroup(itemString) then
		leftText = GROUP_TEXT
	elseif ItemString.ParseLevel(Group.TranslateItemString(itemString)) then
		leftText = GROUP_ITEM_LEVEL_TEXT
	else
		leftText = GROUP_BASE_ITEM_TEXT
	end
	tooltip:AddTextLine(leftText, Group.FormatPath(groupPath))
end

---@param tooltip TooltipBuilder The tooltip object
function private.PopulateOperationLine(tooltip, itemString, typeName)
	assert(typeName)
	local label = format(L["%s Operation(s)"], Operation.GetLocalizedName(typeName))
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddLine(label, tooltip:ApplyValueColor(L["Example"]))
		return
	end

	local groupPath = Group.GetPathByItem(itemString)
	if groupPath == Group.GetRootPath() then
		return
	end

	local operationsList = GroupOperationTypes.OperationIterator(groupPath, typeName):ToJoinedValueString(", ")
	if operationsList == "" then
		return
	end
	tooltip:AddLine(label, tooltip:ApplyValueColor(operationsList))
end

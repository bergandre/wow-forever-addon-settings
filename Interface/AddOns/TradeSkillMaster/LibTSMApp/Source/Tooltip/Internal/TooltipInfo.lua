-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local TooltipInfo = LibTSMApp:DefineInternalClassType("TooltipInfo")
local TooltipEntry = LibTSMApp:IncludeClassType("TooltipEntry")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local ObjectPool = LibTSMApp:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local private = {
	entryObjPool = ObjectPool.New("TOOLTIP_ENTRY", TooltipEntry),
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(TooltipInfo, function(db)
	private.settings = db:NewView("TooltipInfoSettings")
		:AddKey("global", "tooltipOptions", "moduleTooltips")
		:AddKey("global", "tooltipOptions", "customPriceTooltips")
		:AddKey("global", "tooltipOptions", "vendorBuyTooltip")
		:AddKey("global", "tooltipOptions", "vendorSellTooltip")
		:AddKey("global", "tooltipOptions", "groupNameTooltip")
		:AddKey("global", "tooltipOptions", "destroyTooltipFormat")
		:AddKey("global", "tooltipOptions", "convertTooltipFormat")
		:AddKey("global", "tooltipOptions", "operationTooltips")
		:AddKey("global", "tooltipOptions", "inventoryTooltipFormat")
		:Commit()
end)



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TooltipInfo:__init()
	self._headingLeft = nil
	self._headingRight = nil
	self._settingsModule = nil
	self._entries = {} ---@type TooltipEntry[]
end

---Sets the heading text.
---@param leftStr? string The left heading text
---@param rightFunc? function A function to generate the right heading text
---@return self
function TooltipInfo:SetHeadings(leftStr, rightFunc)
	self._headingLeft = leftStr
	self._headingRight = rightFunc
	return self
end

---Sets the setting module name which is used as a key into the `moduleTooltips` settings table.
---@param settingsModule any
---@return self
function TooltipInfo:SetSettingsModule(settingsModule)
	self._settingsModule = settingsModule
	return self
end

---Adds a setting entry.
---@param key string The setting key
---@param defaultValue? boolean The default value for the setting
---@param populateFunc TooltipEntryPopulateFunc A function to populate the related tooltip entry info
---@param populateArg? any An extra argument to pass to the populate function
---@return self
function TooltipInfo:AddSettingEntry(key, defaultValue, populateFunc, populateArg)
	if defaultValue == nil then
		defaultValue = private.settings:GetDefaultReadOnly(key)
	end
	assert(type(defaultValue) == "boolean")
	local entry = private.entryObjPool:Get() ---@type TooltipEntry
	entry:Acquire(self, key, true, false, defaultValue, populateFunc, populateArg)
	tinsert(self._entries, entry)
	return self
end

---Adds a setting value entry.
---@param key string The setting key
---@param setValue any The set value of the setting
---@param clearValue any The clear value of the setting
---@param defaultValue any The default value of the setting
---@param populateFunc TooltipEntryPopulateFunc A function to populate the related tooltip entry info
---@param populateArg? any An extra argument to pass to the populate function
---@return self
function TooltipInfo:AddSettingValueEntry(key, setValue, clearValue, defaultValue, populateFunc, populateArg)
	local entry = private.entryObjPool:Get() ---@type TooltipEntry
	entry:Acquire(self, key, setValue, clearValue, defaultValue, populateFunc, populateArg)
	tinsert(self._entries, entry)
	return self
end

---Deletes setting entries which match the given string.
---@param matchStr string The match string
function TooltipInfo:DeleteSettingsByKeyMatch(matchStr)
	for i = #self._entries, 1, -1 do
		local entry = self._entries[i]
		if entry:KeyMatches(matchStr) then
			tremove(self._entries, i)
			entry:Release()
			private.entryObjPool:Recycle(entry)
		end
	end
end

---Populates a tooltip.
---@param tooltip TooltipBuilder The tooltip builder
---@param itemString string The item string
function TooltipInfo:Populate(tooltip, itemString, showStackValues)
	local headingRightText = self._headingRight and self._headingRight(tooltip, itemString) or nil
	tooltip:StartSection(self._headingLeft, headingRightText)
	for _, entry in ipairs(self._entries) do
		if entry:IsEnabled() then
			entry:Populate(tooltip, itemString, showStackValues)
		end
	end
	tooltip:EndSection()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
function TooltipInfo:_CheckDefaults()
	if self._settingsModule and not private.settings.moduleTooltips[self._settingsModule] then
		-- Populate all the default values
		private.settings.moduleTooltips[self._settingsModule] = {}
		for _, entry in ipairs(self._entries) do
			entry:ResetSetting()
		end
	end
end

---@private
function TooltipInfo:_GetSettingsTable()
	if self._settingsModule then
		return private.settings.moduleTooltips[self._settingsModule]
	else
		return private.settings
	end
end

---@private
function TooltipInfo:_GetEntry(index)
	return self._entries[index]
end

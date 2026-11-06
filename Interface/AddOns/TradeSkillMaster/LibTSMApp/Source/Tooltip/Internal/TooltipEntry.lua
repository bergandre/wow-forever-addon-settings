-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local TooltipEntry = LibTSMApp:DefineInternalClassType("TooltipEntry")

---@alias TooltipEntryPopulateFunc fun(tooltip: TooltipBuilder, itemString: string, arg: any, showStackValues: boolean)



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TooltipEntry:__init()
	self._info = nil ---@type TooltipInfo!
	self._settingKey = nil ---@type string!
	self._settingSetValue = nil ---@type any!
	self._settingClearValue = nil ---@type any!
	self._settingDefaultValue = nil ---@type any!
	self._populateFunc = nil ---@type TooltipEntryPopulateFunc!
	self._populateArg = nil ---@type any!
end

---Acquires the tooltip entry object.
---@param info TooltipInfo The tooltip info object which this entry belongs to
---@param key string The setting key
---@param setValue any The set value of the setting (defaults to `true`)
---@param clearValue any The clear value of the setting (defaults to `false`)
---@param defaultValue any The default value of the setting
---@param populateFunc TooltipEntryPopulateFunc A function to populate the related tooltip entry info
---@param populateArg any An extra argument to pass to the populate function
function TooltipEntry:Acquire(info, key, setValue, clearValue, defaultValue, populateFunc, populateArg)
	assert(setValue == nil or setValue)
	assert(clearValue ~= nil or defaultValue ~= nil)
	self._info = info
	self._settingKey = key
	self._settingSetValue = setValue or true
	self._settingClearValue = clearValue or false
	self._settingDefaultValue = defaultValue
	self._populateFunc = populateFunc
	self._populateArg = populateArg
end

---Releases the tooltip entry object.
function TooltipEntry:Release()
	self._info = nil
	self._settingKey = nil
	self._settingSetValue = nil
	self._settingClearValue = nil
	self._settingDefaultValue = nil
	self._populateFunc = nil
	self._populateArg = nil
end

---Returns whether or not the tooltip entry is enabled.
---@return boolean
function TooltipEntry:IsEnabled()
	local settingTbl, settingKey = self:_GetSettingInfo()
	local settingValue = settingTbl[settingKey]
	if settingValue == nil then
		assert(self._settingDefaultValue ~= nil)
		settingTbl[settingKey] = self._settingDefaultValue
		settingValue = settingTbl[settingKey]
	end
	return settingValue == self._settingSetValue
end

---Checks if the entry setting key matches the given string.
---@param matchStr string The match string
---@return boolean
function TooltipEntry:KeyMatches(matchStr)
	return strmatch(self._settingKey, matchStr) and true or false
end

---Resets the tooltip entry setting.
function TooltipEntry:ResetSetting()
	local tbl = self._info:_GetSettingsTable() ---@diagnostic disable-line: invisible
	if self._settingDefaultValue ~= nil then
		tbl[self._settingKey] = self._settingDefaultValue
	elseif self._settingClearValue ~= nil then
		tbl[self._settingKey] = self._settingClearValue
	else
		error("Invalid setting info")
	end
end

---Populates the tooltip from the entry.
---@param tooltip TooltipBuilder The tooltip
---@param itemString string The item string
---@param showStackValues boolean Show values for an entire stack
function TooltipEntry:Populate(tooltip, itemString, showStackValues)
	self._populateFunc(tooltip, itemString, self._populateArg, showStackValues)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function TooltipEntry.__private:_GetSettingInfo()
	local tbl = self._info:_GetSettingsTable() ---@diagnostic disable-line: invisible
	local key, key2, extra = strsplit(".", self._settingKey)
	---@cast key2 string?
	---@cast extra string?
	assert(not extra)
	if key2 then
		tbl = tbl[key]
		key = key2
	end
	assert(type(tbl) == "table")
	return tbl, key
end

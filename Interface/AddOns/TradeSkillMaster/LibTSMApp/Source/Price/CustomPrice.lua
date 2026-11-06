-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local CustomPrice = LibTSMApp:Init("Price.CustomPrice")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local ItemString = LibTSMApp:From("LibTSMTypes"):Include("Item.ItemString")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local private = {
	settings = nil,
	lastLoopError = nil,
	moduleListTemp = {},
	linesTemp = {},
}
local ERR_STR_LOOKUP = {
	[CustomString.ERROR_TYPE.INVALID_TOKEN] = L["Unexpected word ('%s') in custom string."],
	[CustomString.ERROR_TYPE.UNBALANCED_PARENS] = L["There are unbalanced parentheses in this custom string."],
	[CustomString.ERROR_TYPE.INVALID_NUM_ARGS] = L["The '%s' function has an invalid number of arguments."],
	[CustomString.ERROR_TYPE.TOO_MANY_VARS] = L["This custom string is too complex for WoW to handle; use custom sources to simplify it."],
	[CustomString.ERROR_TYPE.INVALID_ITEM_STRING] = L["'%s' is not a valid item argument."],
	[CustomString.ERROR_TYPE.INVALID_CONVERT_ARG] = L["'%s' is not a valid argument for convert()."],
	[CustomString.ERROR_TYPE.NO_ITEM_PARAM_PARENT] = L["The '%s' item parameter was used outside of a custom source."],
	[CustomString.ERROR_TYPE.EMPTY_STRING] = L["Empty custom string."],
	[CustomString.ERROR_TYPE.INVALID_SOURCE] = L["'%s' is not a valid source."],
	[CustomString.ERROR_TYPE.NO_VALUE] = L["No value was returned by the custom price for the specified item."],
	[CustomString.ERROR_TYPE.INVALID_CHARACTER] = L["Custom string names can only contain lowercase letters."],
	[CustomString.ERROR_TYPE.ALREADY_EXISTS] = L["Custom string name '%s' already exists."],
	[CustomString.ERROR_TYPE.RESERVED_WORD] = L["Custom string name '%s' is a reserved word which cannot be used."],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CustomPrice:OnModuleLoad(function()
	SlashCommands.Register("sources", private.PrintSources, L["Prints out the available price sources for use in custom prices"])
	SlashCommands.Register("price", private.TestPriceSource, L["Allows for testing of custom prices"])
	CustomString.SetLoopHandler(private.LoopHandler)
	CustomString.SetFrameTimeFunc(ClientInfo.GetFrameNumber)
end)

AddonSettings.RegisterOnLoad(CustomPrice, function(db)
	private.settings = db:NewView("CustomPriceSettings")
		:AddKey("global", "userData", "customPriceSources")
		:AddKey("global", "userData", "customPriceSourceFormat")
		:AddKey("global", "tooltipOptions", "customPriceTooltips")
		:Commit()
	local removedKeys = {}
	CustomString.LoadCustomSources(private.settings.customPriceSources, removedKeys)
	for _, key in ipairs(removedKeys) do
		ChatMessage.PrintfUser(L["Removed custom price source (%s) which has an invalid name."], key)
	end

	-- Clean up the custom price source formats
	for name in pairs(private.settings.customPriceSourceFormat) do
		if not private.settings.customPriceSources[name] then
			private.settings.customPriceSourceFormat[name] = nil
		end
	end
	for name in pairs(private.settings.customPriceSources) do
		private.settings.customPriceSourceFormat[name] = private.settings.customPriceSourceFormat[name] or "gold"
	end
	for name in pairs(private.settings.customPriceTooltips) do
		if not private.settings.customPriceSources[name] then
			private.settings.customPriceTooltips[name] = nil
		end
	end

	-- Configure the format code
	CustomStringFormat.Configure(private.settings.customPriceSourceFormat)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Validate a custom price name.
---@param name string The custom price name
---@return (true result, nil)|(false, string errStr)
function CustomPrice.ValidateCustomSourceName(name)
	local isValid, errType, errTokenStr = CustomString.ValidateCustomSourceName(name)
	if isValid then
		return true, nil
	else
		return false, format(ERR_STR_LOOKUP[errType], errTokenStr)
	end
end

---Validate a custom price string.
---@param text string The custom price string
---@param badPriceSources? table A table of price sources (as keys) which aren't allowed to be used
---@return (true result, nil)|(false, string errStr)
function CustomPrice.Validate(text, badPriceSources)
	local isValid, errType, errTokenStr = CustomString.Validate(text)
	if not isValid then
		return false, format(ERR_STR_LOOKUP[errType], errTokenStr)
	end
	if badPriceSources then
		for source in pairs(badPriceSources) do
			if CustomString.DependsOnSource(text, source) then
				return false, format(L["You cannot use '%s' as part of this custom string."], source)
			end
		end
	end
	return true, nil
end

---Evaluates a custom string for an item.
---@param str string The custom string
---@param itemString string The item to evaluate the custom string for
---@param allowZero? boolean If true, allows the result to be 0
---@return (number value)|(nil, string errStr)
function CustomPrice.GetValue(str, itemString, allowZero)
	local value, errType, errArg = CustomString.GetValue(str, itemString, allowZero)
	if value then
		return value
	else
		return nil, format(ERR_STR_LOOKUP[errType], errArg)
	end
end

---Iterates through all the available custom sources.
---@return fun(): number, string @Iterator with fields: `index`, `name`
---@return table
---@return number
function CustomPrice.CustomSourceIterator()
	local sources = TempTable.Acquire()
	Table.GetKeys(private.settings.customPriceSources, sources)
	sort(sources)
	return TempTable.Iterator(sources)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PrintSources()
	ChatMessage.PrintUser(L["Below is a list of all available price sources, along with a brief description of what they represent."])
	assert(not next(private.moduleListTemp))
	for _, _, _, moduleName in CustomString.SourceIterator() do
		if not private.moduleListTemp[moduleName] then
			private.moduleListTemp[moduleName] = true
			tinsert(private.moduleListTemp, moduleName)
		end
	end
	sort(private.moduleListTemp)
	assert(not next(private.linesTemp))
	for _, module in ipairs(private.moduleListTemp) do
		ChatMessage.PrintUserRaw("|cffffff00"..module..":|r")
		for _, key, label, moduleName in CustomString.SourceIterator() do
			if moduleName == module then
				tinsert(private.linesTemp, format("  %s (%s)", ChatMessage.ColorUserAccentText(key), label))
			end
		end
		sort(private.linesTemp)
		for _, line in ipairs(private.linesTemp) do
			ChatMessage.PrintfUserRaw(line)
		end
		wipe(private.linesTemp)
	end
	Table.WipeAndDeallocate(private.moduleListTemp)
end

function private.TestPriceSource(price)
	local _, endIndex, link = strfind(price, "(\124c[0-9a-f]+\124H[^\124]+\124h%[[^%]]+%]\124h\124r)")
	if not link then
		_, endIndex, link = strfind(price, "(\124cnIQ[0-9]:\124H[^\124]+\124h%[[^%]]+%]\124h\124r)")
	end
	price = link and strtrim(strsub(price, endIndex + 1))
	if not price or price == "" then
		ChatMessage.PrintUser(L["Usage: /tsm price <Item Link> <Custom String>"])
		return
	end

	local isValid, err = CustomPrice.Validate(price)
	if not isValid then
		ChatMessage.PrintfUser(L["%s is not a valid custom price and gave the following error: %s"], ChatMessage.ColorUserAccentText(price), err)
		return
	end

	local itemString = ItemString.Get(link)
	if not itemString then
		ChatMessage.PrintfUser(L["%s is a valid custom price but %s is an invalid item."], ChatMessage.ColorUserAccentText(price), link)
		return
	end

	local value = CustomString.GetValue(price, itemString)
	if not value then
		ChatMessage.PrintfUser(L["%s is a valid custom price but did not give a value for %s."], ChatMessage.ColorUserAccentText(price), link)
		return
	end

	ChatMessage.PrintfUser(L["A custom price of %s for %s evaluates to %s."], ChatMessage.ColorUserAccentText(price), link, Money.ToStringExact(value))
end

function private.LoopHandler(str)
	if (private.lastLoopError or 0) + 1 < LibTSMApp.GetTime() then
		private.lastLoopError = LibTSMApp.GetTime()
		ChatMessage.PrintUser(L["Loop detected in the following custom price:"].." "..ChatMessage.ColorUserAccentText(str))
	end
end

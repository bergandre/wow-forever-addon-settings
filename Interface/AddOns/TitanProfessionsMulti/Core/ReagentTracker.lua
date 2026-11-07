--[[
	Shared data-driven reagent tracker for Retail and Classic profession modules.
--]]

local ADDON_NAME, L = ...
local AceLocale = LibStub("AceLocale-3.0")
local ACE = AceLocale:GetLocale(rawget(_G, "TITAN_ID") or "Titan", true)
	or AceLocale:GetLocale("Titan", true)
	or AceLocale:GetLocale("TitanClassic", true)
	or {}
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local ReagentTracker = {}
L.ReagentTracker = ReagentTracker
L.ReagentRegistrationErrors = L.ReagentRegistrationErrors or {}
L.ReagentRuntimeErrors = L.ReagentRuntimeErrors or {}

local QUESTION_MARK_ICON = 134400
local REAGENT_MENU_COLOR = "FFEC7A37"
local trackers = {}
local eventFrame
local sessionStarted = false
local isRetail = WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local function getItemCount(itemID, includeBank)
	if isRetail then
		return C_Item.GetItemCount(itemID, includeBank, false, false, false) or 0
	end

	local ok, count = pcall(GetItemCount, itemID, includeBank, false, includeBank)
	if not ok then
		count = GetItemCount(itemID, includeBank)
	end

	return count or 0
end

local function readBagCounts()
	if not isRetail then return end

	local counts = {}
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local item = C_Container.GetContainerItemInfo(bag, slot)
			if item then
				counts[item.itemID] = (counts[item.itemID] or 0) + item.stackCount
			end
		end
	end
	return counts
end

local function getItemName(item)
	for _, itemID in ipairs(item.ids) do
		local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
		if not name then
			name = GetItemInfo(itemID)
		end
		if name then
			return name
		end
	end

	return item.name
end

local function getItemIcon(item)
	for _, itemID in ipairs(item.ids) do
		local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
		if not icon and GetItemInfoInstant then
			icon = select(5, GetItemInfoInstant(itemID))
		end
		if icon then
			return icon
		end
	end

	return QUESTION_MARK_ICON
end

local function getVariantLabel(itemID, fallbackName, rank)
	local link = C_Item and C_Item.GetItemLinkByID and C_Item.GetItemLinkByID(itemID)
	if not link then
		link = select(2, GetItemInfo(itemID))
	end

	if link then
		return link
	end
	if C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return L["qualityfallback"]:format(fallbackName, rank)
end

local function getCounts(item, countCache, bagCounts)
	local bags = 0
	local total = 0
	local seen = {}

	for _, itemID in ipairs(item.ids) do
		if not seen[itemID] then
			seen[itemID] = true

			local counts = countCache and countCache[itemID]
			if not counts then
				counts = {
					bags = bagCounts and (bagCounts[itemID] or 0) or getItemCount(itemID, false),
					total = getItemCount(itemID, true),
				}
				if countCache then
					countCache[itemID] = counts
				end
			end

			bags = bags + counts.bags
			total = total + counts.total
		end
	end

	return bags, total
end

function ReagentTracker.RefreshAll(resetSession)
	local countCache = {}
	local bagCounts = readBagCounts()

	for _, tracker in ipairs(trackers) do
		local ok, message = pcall(tracker.refresh, resetSession, countCache, bagCounts)
		if not ok and tracker.lastError ~= message then
			tracker.lastError = message
			L.ReagentRuntimeErrors[#L.ReagentRuntimeErrors + 1] = tracker.id .. ": " .. tostring(message)
		end
	end
end

local function ensureEventFrame()
	if eventFrame then return end

	eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_ENTERING_WORLD" then
			ReagentTracker.RefreshAll(not sessionStarted)

			if not sessionStarted then
				sessionStarted = true
				self:RegisterEvent("BAG_UPDATE_DELAYED")
				self:RegisterEvent("BANKFRAME_OPENED")
			end
		else
			ReagentTracker.RefreshAll(false)
		end
	end)
end

local function getHideVariable(item)
	return item.hideVariable or "HideItem_" .. item.ids[1]
end

local function getExpansionLabel(expansion, short)
	local key = short and expansion.shortLabelKey or expansion.labelKey
	local fallback = short and expansion.shortLabel or expansion.label

	return (key and L[key]) or fallback or expansion.name
end

local function addToggle(eddm, id, text, variable, onToggle)
	eddm.UIDropDownMenu_AddButton({
		text = text,
		checked = TitanGetVar(id, variable),
		keepShownOnClick = true,
		func = function()
			TitanToggleVar(id, variable)
			if onToggle then
				onToggle()
			else
				TitanPanelButton_UpdateButton(id)
			end
		end,
	})
end

function ReagentTracker.Register(config)
	local id = config.id
	local expansion = config.expansion
	local expansionLabel = getExpansionLabel(expansion, false)
	local expansionTooltip = getExpansionLabel(expansion, true)
	local professionName = L[config.professionKey] or config.professionName
	local states = {}
	local savedVariables = {
		ShowIcon = 1,
		ShowLabelText = false,
		ShowBarBalance = false,
		DisplayOnRightSide = false,
	}

	for index, item in ipairs(config.items) do
		states[index] = { current = 0, start = 0 }
		savedVariables[getHideVariable(item)] = false
	end

	local function refresh(resetSession, countCache, bagCounts)
		local changed = false

		for index, item in ipairs(config.items) do
			local bags, total = getCounts(item, countCache, bagCounts)
			total = math.max(bags, total)
			local state = states[index]

			if resetSession then
				state.start = total
			end

			if state.current ~= total then
				state.current = total
				changed = true
			end
		end

		if changed and TitanPlugins and TitanPlugins[id] and TitanPanelButton_UpdateButton then
			TitanPanelButton_UpdateButton(id)
		end
	end

	local function getButtonText(self, pluginID)
		local text = {}

		for index, item in ipairs(config.items) do
			if not TitanGetVar(pluginID, getHideVariable(item)) then
				local state = states[index]
				local itemText = "  |T" .. getItemIcon(item) .. ":0|t " .. TitanUtils_GetHighlightText(tostring(state.current))

				if TitanGetVar(pluginID, "ShowBarBalance") then
					local balance = state.current - state.start
					if balance > 0 then
						itemText = itemText .. " |cFF69FF69[+" .. balance .. "]|r"
					elseif balance < 0 then
						itemText = itemText .. " |cFFFF2e2e[" .. balance .. "]|r"
					end
				end

				text[#text + 1] = itemText
			end
		end

		return table.concat(text, " ")
	end

	local function getTooltipText()
		local grandTotal = 0
		for _, state in ipairs(states) do
			grandTotal = grandTotal + state.current
		end

		if grandTotal == 0 then
			return "\r" .. L["info"] .. "\r|cFFFF2e2e" .. L["noreagent"]
		end

		local lines = {}
		local bagCounts = readBagCounts()
		for _, item in ipairs(config.items) do
			local bags, total = getCounts(item, nil, bagCounts)
			local bank = math.max(0, total - bags)
			local name = getItemName(item)

			if #lines > 0 then
				lines[#lines + 1] = "\n "
			end
			lines[#lines + 1] = "\n|T" .. getItemIcon(item) .. ":0|t |cFFFFFFFF" .. name .. "|r"
			lines[#lines + 1] = "\n" .. L["totalbag"] .. "\t" .. TitanUtils_GetHighlightText(tostring(bags))
			lines[#lines + 1] = "\n" .. L["totalbank"] .. "\t" .. TitanUtils_GetHighlightText(tostring(bank))

			if #item.ids > 1 then
				lines[#lines + 1] = "\n" .. L["totalbyquality"]
				for rank, itemID in ipairs(item.ids) do
					local variantTotal = getItemCount(itemID, true)
					if bagCounts then
						variantTotal = math.max(bagCounts[itemID] or 0, variantTotal)
					end
					lines[#lines + 1] = "\n  " .. getVariantLabel(itemID, name, rank) .. "\t" .. TitanUtils_GetHighlightText(tostring(variantTotal))
				end
			end
		end

		return table.concat(lines)
	end

	local function prepareMenu(eddm)
		L.AddMenuTitle(eddm, TitanPlugins[id].menuText)
		L.AddMenuTitle(eddm, L["buttonText"])

		addToggle(eddm, id, ACE["TITAN_PANEL_MENU_SHOW_ICON"], "ShowIcon")
		addToggle(eddm, id, L["showbb"], "ShowBarBalance")
		addToggle(eddm, id, ACE["TITAN_CLOCK_MENU_DISPLAY_ON_RIGHT_SIDE"], "DisplayOnRightSide", function()
			TitanPanel_InitPanelButtons()
		end)

		eddm.UIDropDownMenu_AddSpace()
		L.AddMenuTitle(eddm, L["tooltip"])
		for _, item in ipairs(config.items) do
			addToggle(eddm, id, (L["hide"] or "Hide") .. " " .. getItemName(item), getHideVariable(item))
		end

		eddm.UIDropDownMenu_AddSpace()
		L.AddBarPositionMenu(eddm, id)
		L.AddMenuFooter(eddm, id)
	end

	local coloredName = "Titan|c" .. REAGENT_MENU_COLOR .. " " .. professionName
		.. "|r [|c" .. REAGENT_MENU_COLOR .. expansionLabel .. "|r] Multi"
	local frame = L.Elib({
		id = id,
		name = coloredName,
		tooltip = professionName .. "|r [|cFFEC7A37" .. expansionTooltip .. "|r]",
		icon = config.icon,
		category = L.ReagentCategory or "Profession",
		version = VERSION,
		getButtonText = getButtonText,
		getTooltipText = getTooltipText,
		prepareMenu = prepareMenu,
		savedVariables = savedVariables,
	})
	L.RestoreTitanMenuColor(frame, coloredName .. "|r")

	trackers[#trackers + 1] = {
		id = id,
		refresh = refresh,
	}
	ensureEventFrame()

	return frame
end

function ReagentTracker.RegisterExpansion(expansion)
	local frames = {}

	for _, config in ipairs(expansion.professions) do
		config.expansion = expansion

		local ok, result = pcall(ReagentTracker.Register, config)
		if ok then
			frames[#frames + 1] = result
		else
			L.ReagentRegistrationErrors[#L.ReagentRegistrationErrors + 1] = config.id .. ": " .. tostring(result)
		end
	end

	return frames
end

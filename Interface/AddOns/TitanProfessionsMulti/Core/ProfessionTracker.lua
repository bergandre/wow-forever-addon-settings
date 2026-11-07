--[[
	Shared Titan profession tracker for all supported clients.
	Presentation, session tracking and polling live here; individual professions
	are declared as data in Professions/Professions.lua.
--]]

local _, L = ...

local API = L.ProfessionAPI
local ProfessionTracker = {
	configs = {},
	states = {},
	updateFrame = nil,
}

local function getState(config)
	local state = ProfessionTracker.states[config.id]
	if not state then
		state = {
			skill = 0,
			maxSkill = 0,
			bonus = 0,
			startSkill = nil,
			info = nil,
			initialized = false,
		}
		ProfessionTracker.states[config.id] = state
	end

	return state
end

local function getSessionGain(state)
	if not state.startSkill then
		return 0
	end

	return state.skill - state.startSkill
end

local function getCombinationText(config)
	if not config.combinations or #config.combinations == 0 then
		return ""
	end

	local names = {}
	for index, key in ipairs(config.combinations) do
		names[index] = L[key]
	end

	return "\n \n" .. L["goodwith"] .. "\n" .. table.concat(names, ", ")
end

local function getButtonText(config)
	local state = getState(config)
	local bonusText = ""
	if state.bonus > 0 then
		bonusText = "|r|cFFFFFFFF + |r|cFF69FF69" .. state.bonus
			.. "|r|cFFFFFFFF " .. L["bonus"] .. " =|r|cFF69FF69 " .. (state.skill + state.bonus)
	end

	local maxText = ""
	if not TitanGetVar(config.id, "HideMax") then
		maxText = "|r/|cFFFF2e2e" .. state.maxSkill
	end

	local displayedBonus = bonusText
	if TitanGetVar(config.id, "SimpleBonus") and state.bonus > 0 then
		displayedBonus = "|r|cFFFFFFFF (+|r|cFF69FF69" .. state.bonus .. "|r|cFFFFFFFF)"
	end

	local balanceText = ""
	local sessionGain = getSessionGain(state)
	if state.maxSkill ~= 0 and sessionGain > 0 and TitanGetVar(config.id, "ShowBarBalance") then
		balanceText = " |cFF69FF69[" .. sessionGain .. "]"
	end

	local text
	if state.maxSkill == 0 then
		text = "|cFFFF2e2e" .. L["noprof"]
	elseif state.skill == state.maxSkill then
		if state.maxSkill == API:GetMaximumCap(config) then
			text = "|cFF69FF69" .. L["maximum"] .. "!" .. displayedBonus
		else
			text = "|cFFFFFFFF" .. state.skill .. "|cFF69FF69! [" .. L["maximum"] .. "]"
				.. displayedBonus .. balanceText
		end
	else
		text = "|cFFFFFFFF" .. state.skill .. maxText .. displayedBonus .. balanceText
	end

	return L[config.nameKey] .. ": ", text
end

local function getTooltipText(config)
	local state = getState(config)
	local combinations = getCombinationText(config)

	if state.skill == 0 then
		return L[config.unlearnedTextKey or "noskill"] .. combinations
	end

	local totalSkill = "\n" .. L["craftsmanship"] .. "|r\t|cFFFFFFFF" .. state.skill
	if state.bonus > 0 then
		totalSkill = "\n" .. L["craftsmanship"] .. "|r\t|cFF69FF69" .. (state.skill + state.bonus)
	end

	local bonusText = ""
	if state.bonus > 0 then
		bonusText = "\n" .. L["bonustext"] .. "\t|cFF69FF69" .. state.bonus
	end

	local maxSkillText = "\n" .. L["maxtext"] .. "\t" .. TitanUtils_GetHighlightText(state.maxSkill)

	local visibleCombinations = combinations
	if TitanGetVar(config.id, "HideCombination") then
		visibleCombinations = ""
	end

	local sessionText = ""
	local sessionGain = getSessionGain(state)
	if state.skill == API:GetMaximumCap(config) then
		sessionText = "\n" .. L["maxskill"]
	elseif sessionGain == 0 then
		sessionText = "\n" .. L["session"] .. "\t" .. TitanUtils_GetHighlightText("0")
	elseif sessionGain > 0 then
		sessionText = "\n" .. L["session"] .. "\t|cFF69FF69" .. sessionGain .. "|r"
	end

	local warning = ""
	if config.warningMax and state.skill == state.maxSkill and state.maxSkill ~= config.warningMax then
		warning = L["warning"]
	end

	local hint = ""
	if config.showHint ~= false then
		hint = L["hint"] .. "\n \n"
	end

	return hint .. L["info"] .. bonusText .. totalSkill .. maxSkillText .. sessionText
		.. visibleCombinations .. warning
end

local function updateState(config, info)
	local state = getState(config)
	local skill = info and info.skill or 0
	local maxSkill = info and info.maxSkill or 0
	local bonus = info and info.bonus or 0
	local changed = not state.initialized
		or state.skill ~= skill
		or state.maxSkill ~= maxSkill
		or state.bonus ~= bonus

	if info and not state.startSkill then
		state.startSkill = skill
	elseif not info then
		state.startSkill = nil
	end

	state.skill = skill
	state.maxSkill = maxSkill
	state.bonus = bonus
	state.info = info
	state.initialized = true

	return changed
end

function ProfessionTracker:Refresh()
	local snapshot = API:CreateSnapshot()
	for _, config in ipairs(self.configs) do
		local info = API:GetProfession(snapshot, config)
		if updateState(config, info) and type(TitanPanelButton_UpdateButton) == "function" then
			TitanPanelButton_UpdateButton(config.id)
		end
	end
end

function ProfessionTracker:Start()
	if self.updateFrame then
		return
	end

	local elapsed = 1
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed < 1 then
			return
		end

		elapsed = 0
		ProfessionTracker:Refresh()
	end)

	self.updateFrame = frame
end

function ProfessionTracker:Register(config)
	assert(type(config) == "table", "Profession configuration must be a table")
	assert(type(config.id) == "string", "Profession configuration requires an id")
	assert(type(config.nameKey) == "string", "Profession configuration requires a nameKey")
	assert(config.skillLineID or config.slot, "Profession configuration requires a skill line or slot")

	getState(config)
	table.insert(self.configs, config)

	local coloredName = "Titan|c" .. L.ProfessionMenuColor .. " " .. L[config.nameKey] .. "|r Multi"
	local registration = {
		id = config.id,
		name = coloredName,
		tooltip = L[config.nameKey],
		icon = config.icon,
		category = "Profession",
		version = config.version,
		getButtonText = function()
			return getButtonText(config)
		end,
		getTooltipText = function()
			return getTooltipText(config)
		end,
		prepareMenu = L.PrepareProfessionsMenu,
		savedVariables = {
			ShowIcon = 1,
			DisplayOnRightSide = false,
			HideMax = false,
			SimpleBonus = true,
			ShowBarBalance = false,
			ShowLabelText = false,
			HideCombination = config.hideCombinationByDefault ~= false,
		},
	}

	if config.clickable ~= false then
		registration.onClick = function(_, button)
			if button == "LeftButton" then
				return API:OpenProfession(getState(config).info)
			end
		end
	end

	local button = L.Elib(registration)
	L.RestoreTitanMenuColor(button, coloredName .. "|r")
	self:Start()
end

L.ProfessionTracker = ProfessionTracker

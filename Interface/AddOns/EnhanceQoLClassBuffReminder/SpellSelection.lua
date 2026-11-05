local addon = _G.EnhanceQoL
local Reminder = addon.ClassBuffReminder

local function spellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	if GetSpellInfo then return (GetSpellInfo(id)) end
end

function Reminder:IsSpellReminderDisabled(spellId)
	local disabled = addon.db and addon.db.classBuffReminderDisabledSpells
	if not spellId or type(disabled) ~= "table" then return false end
	if disabled[spellId] == true then return true end
	-- A choice applies to all ranks of the same spell, including newly learned ranks.
	local name = spellName(spellId)
	if not name then return false end
	for id, selected in pairs(disabled) do
		if selected == true and spellName(id) == name then return true end
	end
	return false
end

function Reminder:GetSpellReminderOptions()
	local options, seen = {}, {}
	local function add(id)
		local name = spellName(id)
		if not name or seen[name] then return end
		seen[name] = true
		options[#options + 1] = { value = id, text = name }
	end
	-- Keep saved choices visible even after changing specialization or learning a rank.
	for id, selected in pairs(addon.db.classBuffReminderDisabledSpells or {}) do
		if selected == true then add(id) end
	end
	local provider = self:GetProvider()
	for _, id in ipairs(provider and provider.spellIds or {}) do add(id) end
	table.sort(options, function(a, b) return a.text < b.text end)
	return options
end

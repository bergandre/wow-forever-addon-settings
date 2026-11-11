-- Export TSM's synced inventory (all accounts) to JSON.
-- Usage: lua tsm-export-inventory.lua <TradeSkillMaster.lua> <names.tsv> > inventory.json
local svPath, namesPath = arg[1], arg[2]

-- Item names (id \t name), scraped from item links in other addons' SavedVariables
local names = {}
for line in io.lines(namesPath) do
	local id, name = line:match("^(%d+)\t(.+)$")
	if id then names[tonumber(id)] = name end
end

-- SavedVariables files are plain Lua assignments, so just execute it
local f = assert(io.open(svPath, "rb"))
local src = f:read("a"):gsub("\r", "")
f:close()
local env = {}
assert(load(src, "sv", "t", env))()
local db = assert(env.TradeSkillMasterDB, "no TradeSkillMasterDB")

local LOCATIONS = { bag = "bags", bank = "bank", mail = "mail", auction = "auctions" }
local chars, totals = {}, {}
for key, value in pairs(db) do
	local char, field = key:match("^s@(.-) %- [^@]+@internalData@(%a+)$")
	if char then
		chars[char] = chars[char] or { money = 0, items = {} }
		local loc = field:match("^(%a+)Quantity$")
		if field == "money" then
			chars[char].money = value
		elseif loc and LOCATIONS[loc] then
			for itemString, qty in pairs(value) do
				local id = tonumber(itemString:match("^i:(%d+)"))
				if id and qty > 0 then
					local it = chars[char].items[id] or {}
					it[LOCATIONS[loc]] = (it[LOCATIONS[loc]] or 0) + qty
					chars[char].items[id] = it
					totals[id] = (totals[id] or 0) + qty
				end
			end
		end
	end
end

-- Minimal JSON writer with sorted keys for stable output
local function str(s) return '"' .. tostring(s):gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
local function sortedKeys(t)
	local k = {}
	for key in pairs(t) do k[#k + 1] = key end
	table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
	return k
end
local function money(c) return string.format("%dg %ds %dc", c // 10000, c // 100 % 100, c % 100) end

local out = { '{\n  "characters": {' }
local charKeys = sortedKeys(chars)
for ci, char in ipairs(charKeys) do
	local c = chars[char]
	out[#out + 1] = string.format('\n    %s: {\n      "money": %s,\n      "items": [', str(char), str(money(c.money)))
	local ids = sortedKeys(c.items)
	table.sort(ids)
	for ii, id in ipairs(ids) do
		local parts = { '"id": ' .. id, '"name": ' .. (names[id] and str(names[id]) or "null") }
		for _, loc in ipairs(sortedKeys(c.items[id])) do parts[#parts + 1] = str(loc) .. ": " .. c.items[id][loc] end
		out[#out + 1] = "\n        { " .. table.concat(parts, ", ") .. " }" .. (ii < #ids and "," or "")
	end
	out[#out + 1] = "\n      ]\n    }" .. (ci < #charKeys and "," or "")
end
out[#out + 1] = '\n  },\n  "totals": ['
local ids = sortedKeys(totals)
table.sort(ids)
for i, id in ipairs(ids) do
	out[#out + 1] = string.format('\n    { "id": %d, "name": %s, "count": %d }%s', id, names[id] and str(names[id]) or "null", totals[id], i < #ids and "," or "")
end
out[#out + 1] = "\n  ]\n}\n"
io.write(table.concat(out))

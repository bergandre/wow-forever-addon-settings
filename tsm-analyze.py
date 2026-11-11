#!/usr/bin/env python3
"""Cross-reference synced TSM inventory with TSM prices/demand, AtlasLoot recipes and Zygor
profession guides, and decide per item: KEEP (future profession), SELL (AH), VENDOR, IGNORE.

Usage: python3 tsm-analyze.py [--must Blacksmithing --must Cooking] [--later Engineering --later Tailoring]
                              [--json out.json] [--item "Scorpid Stinger" | --item 5466 ...]
  --must  : always KEEP reagents of recipes that still give you skill-ups (grey level > your skill)
  --later : postponed professions; their reagents are kept only if cheap / Zygor needs them
  --item  : print everything known about an item (holders, price, recipe uses, Zygor needs) and exit
Reads only; run any time (prices are as fresh as the last TSM desktop-app sync).
"""
import argparse, json, re, subprocess, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADDONS = ROOT / "Interface/AddOns"
TSM_SV = ROOT / "WTF/Account/120675253#1/SavedVariables/TradeSkillMaster.lua"  # holds all synced chars
APPDATA = ADDONS / "TradeSkillMaster_AppHelper/AppData.lua"
ATLAS_RECIPES = ADDONS / "AtlasLootContinued/Data/Profession.lua"
ATLAS_NAMES = ADDONS / "AtlasLootContinued_Crafting/data-forever.lua"
ZYGOR = ADDONS / "ZygorGuidesViewerForever/Guides-Forever/Professions/ZygorProfessionsHordeCLASSIC.lua"

PROF_NAMES = {1: "First Aid", 2: "Blacksmithing", 3: "Leatherworking", 4: "Alchemy", 5: "Herbalism",
              6: "Cooking", 7: "Mining", 8: "Tailoring", 9: "Engineering", 10: "Enchanting",
              11: "Fishing", 12: "Skinning", 13: "Jewelcrafting", 14: "Inscription"}

# Decision thresholds (copper / ratios)
MIN_SALE_RATE = 0.30      # region sale rate below this = listings mostly expire
MIN_NET_STACK = 50        # don't bother posting if the whole stack nets < 50c after AH cut
AH_CUT = 0.95
CHAR_PROFS = {}


def money(c):
    if c is None:
        return "-"
    c = int(round(c))
    g, s, cp = c // 10000, c // 100 % 100, c % 100
    return f"{g}g {s:02d}s {cp:02d}c" if g else (f"{s}s {cp:02d}c" if s else f"{cp}c")


# ---------------------------------------------------------------- inventory (TSM sync scope)
def load_inventory():
    """Each account's file is authoritative for its own characters (synced copies can be stale)."""
    lua = r'''
local f = assert(io.open(arg[1], "rb")); local src = f:read("a"):gsub("\r", ""); f:close()
local env = {}; assert(load(src, "sv", "t", env))()
local db = env.TradeSkillMasterDB
local own = {}
for _, key in pairs(db._syncAccountKey or {}) do own[key] = true end
local owned = {}
for syncKey, acc in pairs(db._syncOwner or {}) do
  if own[acc] then owned[syncKey] = true end
end
for key, value in pairs(db) do
  local sync, loc = key:match("^s@(.-)@internalData@(%a+)Quantity$")
  if sync and owned[sync] and type(value) == "table" then
    local char = sync:match("^(.-) %- ")
    for item, qty in pairs(value) do
      local id = item:match("^i:(%d+)$")
      if id and qty > 0 then print(char .. "\t" .. loc .. "\t" .. id .. "\t" .. qty) end
    end
  end
end
local wb = db["g@ @internalData@warbankQuantity"]
if type(wb) == "table" then
  for item, qty in pairs(wb) do
    local id = item:match("^i:(%d+)$")
    if id and qty > 0 then print("Warband\twarbank\t" .. id .. "\t" .. qty) end
  end
end'''
    inv = defaultdict(lambda: {"total": 0, "where": defaultdict(int)})
    seen_warbank = set()
    for sv in sorted(TSM_SV.parent.parent.parent.glob("*/SavedVariables/TradeSkillMaster.lua")):
        out = subprocess.run(["lua", "-", str(sv)], input=lua, capture_output=True, text=True, check=True).stdout
        for line in out.splitlines():
            char, loc, iid, qty = line.split("\t")
            if loc == "warbank":  # shared across accounts? count once per item
                if iid in seen_warbank:
                    continue
                seen_warbank.add(iid)
            inv[int(iid)]["total"] += int(qty)
            inv[int(iid)]["where"][f"{char}/{loc}"] += int(qty)
    return inv


# ---------------------------------------------------------------- TSM AuctionDB prices + demand
def load_prices():
    def dec(v):
        v = v.strip()
        return int(v[-6:], 32) + int(v[:-6], 32) * 2**30 if len(v) > 6 else int(v, 32)
    app = APPDATA.read_text(encoding="utf-8")
    data = defaultdict(dict)
    for fields, body in re.findall(r'LoadData\("[A-Z_]+","[^"]+",\[\[return \{downloadTime=\d+,fields=\{([^}]*)\},data=\{(.*?)\}\}', app, re.S):
        names = re.findall(r'"(\w+)"', fields)[1:]
        for row in re.findall(r'\{([^{}]*)\}', body):
            parts = row.split(",")
            if not parts[0].strip().isdigit():
                continue
            for f, v in zip(names, parts[1:]):
                data[int(parts[0])][f] = dec(v)
    for d in data.values():  # TSM stores these ratios x1000
        for k in ("regionSoldPerDay", "regionSalePercent"):
            if k in d:
                d[k] /= 1000
    return data


# ---------------------------------------------------------------- names (item links + guide text)
def load_names():
    names = {}
    for p in list((ROOT / "WTF").rglob("*.lua")):
        try:
            txt = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for iid, name in re.findall(r'Hitem:(\d+)[^|]*\|h\[([^\]]+)\]', txt):
            names.setdefault(int(iid), name)
    for p in ZYGOR.parent.glob("*.lua"):
        for name, iid in re.findall(r"([A-Z][A-Za-z' :,-]+?)##(\d+)", p.read_text(encoding="utf-8", errors="ignore")):
            names.setdefault(int(iid), name.strip())
    return names


# ---------------------------------------------------------------- AtlasLoot recipes: reagent -> uses
def load_recipes():
    # comments look like "--Scorpid Surprise / 60"; the "/ N" suffixes are AtlasLoot annotations, not part of the name
    spell_names = {int(s): re.sub(r'(\s*/\s*\d+)+$', '', n.strip())
                   for s, n in re.findall(r'\{\s*\d+,\s*(\d+)\s*\},\s*--(.+)', ATLAS_NAMES.read_text(encoding="utf-8"))}
    uses = defaultdict(list)
    # [spellId] = { productItem, profession, learn, green, grey, { reagents }, { counts } }
    pat = re.compile(r'\[(\d+)\]\s*=\s*\{\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*\{([^}]*)\},\s*\{([^}]*)\}')
    for spell, _product, prof, learn, _green, grey, reag, counts in pat.findall(ATLAS_RECIPES.read_text(encoding="utf-8")):
        if int(spell) not in spell_names or int(learn) > 300:
            continue  # not a Forever recipe (later-expansion data in the shared table)
        reag = [int(x) for x in reag.split(",") if x.strip()]
        counts = [int(x) for x in counts.split(",") if x.strip()]
        for r, c in zip(reag, counts):
            uses[r].append({"recipe": spell_names.get(int(spell), f"spell {spell}"), "prof": PROF_NAMES.get(int(prof), str(prof)),
                            "learn": int(learn), "grey": int(grey), "qty": c})
    return uses


# ---------------------------------------------------------------- Zygor: total mats per profession guide
def load_zygor_needs(profs):
    txt = ZYGOR.read_text(encoding="utf-8")
    needs = defaultdict(dict)  # item -> {prof: qty}
    for prof in profs:
        m = re.search(rf'RegisterGuide\("Profession Guides\\\\{prof}\\\\{prof} \(1-300\)".*?\]\]\)', txt, re.S)
        if not m:
            print(f"warning: no Zygor guide for {prof}", file=sys.stderr)
            continue
        guide = m.group(0)
        # The "collect all materials first" section = shopping list totals for raw mats
        shop = guide.split('label "Begin_Profession_Leveling"')[0]
        for qty, iid in re.findall(r'collect (\d+) [^#\n]+##(\d+)', shop):
            needs[int(iid)][prof] = max(needs[int(iid)].get(prof, 0), int(qty))
        # Tools the guide tells you to buy (e.g. Blacksmith Hammer for Engineering)
        for iid in re.findall(r'^\s*buy [A-Z][^#\n]+##(\d+)', guide, re.M):
            needs[int(iid)].setdefault(prof, 1)
        # Anything else the guide collects during leveling (smaller interim amounts)
        for qty, iid in re.findall(r'collect (\d+) [^#\n]+##(\d+)', guide):
            needs[int(iid)].setdefault(prof, int(qty))
    return needs


SMELTS_INTO = {2770: 2840, 2771: 3576, 2775: 2842, 2772: 3577}  # copper/tin/silver/iron ore -> bar (1:1)


def apply_smelting(inv, needs):
    """Ore you own covers the part of a bar requirement that your bars don't."""
    # Bronze Bar = 1 Copper Bar + 1 Tin Bar -> 2 Bronze (needs Mining 65)
    have = lambda i: inv.get(i, {"total": 0})["total"]
    for prof, qty in needs.get(2841, {}).items():
        pairs = -(-max(0, qty - have(2841)) // 2)  # ceil division
        if pairs:
            needs[2840][prof] = needs[2840].get(prof, 0) + pairs
            needs[3576][prof] = needs[3576].get(prof, 0) + pairs
    for ore, bar in SMELTS_INTO.items():
        if ore in inv and bar in needs:
            for prof, qty in needs[bar].items():
                shortfall = max(0, qty - inv.get(bar, {"total": 0})["total"])
                if shortfall:
                    needs[ore][prof] = shortfall


TOOLS = {2901: "Mining", 7005: "Skinning", 5956: "Blacksmithing", 6219: "Engineering", 6256: "Fishing"}

# Class spell reagents (Classic): item -> {CLASS: spell}. Kept if you have a character of that class.
CLASS_REAGENTS = {
    17056: {"PRIEST": "Levitate", "MAGE": "Slow Fall"},                       # Light Feather
    17028: {"PRIEST": "Prayer of Fortitude r1"},                                # Holy Candle
    17029: {"PRIEST": "Prayer of Fortitude/Spirit/Shadow Prot"},              # Sacred Candle
    17020: {"MAGE": "Arcane Brilliance"},                                       # Arcane Powder
    17031: {"MAGE": "Teleport"}, 17032: {"MAGE": "Portal"},                    # Runes
    17033: {"PALADIN": "Divine Intervention"}, 21177: {"PALADIN": "Greater Blessings"},
    17030: {"SHAMAN": "Reincarnation"},                                         # Ankh
    17057: {"SHAMAN": "Water Breathing"}, 17058: {"SHAMAN": "Water Walking"},  # Fish Scales / Fish Oil
    5565: {"WARLOCK": "Inferno"}, 16583: {"WARLOCK": "Ritual of Doom"},        # Infernal Stone / Demonic Figurine
    5140: {"ROGUE": "Vanish"}, 5530: {"ROGUE": "Blind"},                       # Flash / Blinding Powder
    17021: {"DRUID": "Gift of the Wild r1"}, 17026: {"DRUID": "Gift of the Wild r2"},  # Wild Berries / Thornroot
    17034: {"DRUID": "Rebirth"}, 17035: {"DRUID": "Rebirth"}, 17036: {"DRUID": "Rebirth"},
    17037: {"DRUID": "Rebirth"}, 17038: {"DRUID": "Rebirth"},                 # Rebirth seeds
}
CHAR_CLASSES = {}


def load_char_classes():
    classes = {}
    for sv in TSM_SV.parent.parent.parent.glob("*/SavedVariables/TradeSkillMaster.lua"):
        for char, cls in re.findall(r'\["s@(.+?) - [^@]+@internalData@classKey"\] = "(\w+)"', sv.read_text(encoding="utf-8", errors="ignore")):
            classes[char] = cls
    return classes


def load_char_professions():
    lua = r'''
local f = assert(io.open(arg[1], "rb")); local src = f:read("a"):gsub("\r", ""); f:close()
local env = {}; assert(load(src, "sv", "t", env))()
for key, value in pairs(env.TradeSkillMasterDB) do
  local char = key:match("^s@(.-) %- [^@]+@internalData@playerProfessions$")
  if char and type(value) == "table" then
    for prof, info in pairs(value) do print(char .. "\t" .. prof .. "\t" .. tostring(info.level)) end
  end
end'''
    out = subprocess.run(["lua", "-", str(TSM_SV)], input=lua, capture_output=True, text=True, check=True).stdout
    profs = defaultdict(dict)
    for line in out.splitlines():
        char, prof, level = line.split("\t")
        profs[prof][char] = level
    return profs


def best_skill(prof):
    """Highest current skill in a profession across all characters (0 if nobody has it)."""
    return max((int(l) for l in CHAR_PROFS.get(prof, {}).values() if str(l).isdigit()), default=0)


def decide(iid, have, price, recipes, needs, profs, must=()):
    # Must-keep professions: keep everything a not-yet-grey recipe uses
    live = [u for u in recipes.get(iid, []) if u["prof"] in must and u["grey"] > best_skill(u["prof"])]
    if live:
        u = min(live, key=lambda u: u["learn"])
        return "KEEP", have, 0, [f'must-keep {u["prof"]}: {u["recipe"]} (learn {u["learn"]}, grey {u["grey"]}, '
                                 f'you have {best_skill(u["prof"])})' + (f" +{len(live) - 1} more recipes" if len(live) > 1 else "")]
    keep_for = needs.get(iid, {})
    for cls, spell in CLASS_REAGENTS.get(iid, {}).items():
        chars = [c for c, k in CHAR_CLASSES.items() if k == cls]
        if chars:
            return "KEEP", have, 0, [f"class reagent: {spell} ({', '.join(chars)})"]
    tool_prof = TOOLS.get(iid)
    if tool_prof and (tool_prof in CHAR_PROFS or tool_prof in profs):
        owners = ", ".join(f"{c} {l}" for c, l in CHAR_PROFS.get(tool_prof, {}).items()) or "future"
        return "KEEP", min(have, 1), have - 1, [f"{tool_prof} tool ({owners})"]
    reserved = min(have, sum(keep_for.values())) if keep_for else 0
    surplus = have - reserved
    mv = price.get("marketValue") or price.get("marketValueRecent")
    unit = mv or price.get("regionMarketValue")
    rate = price.get("regionSalePercent")
    future_use = [u for u in recipes.get(iid, []) if u["prof"] in profs]
    reasons = []
    if keep_for:
        reasons.append("Zygor " + ", ".join(f"{p} needs {q}" for p, q in keep_for.items())
                       + (" (as bars, smelt it)" if iid in SMELTS_INTO else ""))
    elif future_use:
        reasons.append("used in " + ", ".join(sorted({f'{u["prof"]} {u["recipe"]} ({u["learn"]})' for u in future_use})))
    if surplus == 0:
        return "KEEP", reserved, 0, reasons
    if not unit:
        return ("KEEP" if keep_for or future_use else "IGNORE"), reserved, surplus, reasons + ["no AH data (quest/soulbound/new)"]
    net = unit * surplus * AH_CUT
    if future_use and not keep_for:
        reasons.append("keep if cheap to hold; sell if you need gold now")
    if reserved and (net < MIN_NET_STACK or (rate is not None and rate < MIN_SALE_RATE)):
        return "KEEP", reserved, surplus, reasons + [f"{surplus} extra not worth listing"]
    if rate is not None and rate < MIN_SALE_RATE:
        return "VENDOR", reserved, surplus, reasons + [f"low sale rate {rate:.0%}"]
    if net < MIN_NET_STACK:
        return "VENDOR", reserved, surplus, reasons + [f"stack nets only {money(net)}"]
    return ("SELL" if not future_use or keep_for else "SELL?"), reserved, surplus, reasons


def lookup(queries, inv, prices, names, recipes, needs, profs, must):
    """Answer 'is this item useful?' from data instead of memory."""
    for q in queries:
        ids = [int(q)] if q.isdigit() else sorted(i for i, n in names.items() if q.lower() in n.lower())
        if not ids:
            print(f'"{q}": no item with that name in local data (try the item id)\n')
            continue
        for iid in ids:
            have = inv.get(iid, {"total": 0, "where": {}})
            p = prices.get(iid, {})
            verdict, _, _, reasons = decide(iid, max(have["total"], 1), p, recipes, needs, profs, must)
            if not have["total"]:
                verdict = f"not owned (would be {verdict})"
            print(f"== {names.get(iid, '?')} (id {iid})  ->  {verdict}" + (f"  [{'; '.join(reasons)}]" if reasons else ""))
            print("  have:   " + (", ".join(f"{w} {n}" for w, n in sorted(have["where"].items())) or "none"))
            unit = p.get("marketValue") or p.get("marketValueRecent") or p.get("regionMarketValue")
            rate = p.get("regionSalePercent")
            print(f"  price:  {money(unit)} each" + (f", region sale rate {rate:.0%}" if rate is not None else "") if p else "  price:  no AH data")
            uses = sorted(recipes.get(iid, []), key=lambda u: (u["prof"], u["learn"]))
            print(f"  used in ({len(uses)} recipes):" if uses else "  used in: no known recipe (AtlasLoot)")
            for u in uses:
                skill = best_skill(u["prof"])
                state = "grey for you" if skill and skill >= u["grey"] else (f"you have {skill}" if skill else "nobody has it")
                tag = "MUST" if u["prof"] in must else ("later" if u["prof"] in profs else "")
                print(f'    {u["prof"]:<14} {u["recipe"]:<40} x{u["qty"]}  learn {u["learn"]}, grey {u["grey"]}  ({state}) {tag}')
            if needs.get(iid):
                print("  Zygor:  " + ", ".join(f"{pr} needs {n}" for pr, n in needs[iid].items()))
            print()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--must", action="append", default=None, help="must-keep profession (repeatable)")
    ap.add_argument("--later", action="append", default=None, help="postponed profession (repeatable)")
    ap.add_argument("--item", action="append", default=None, help="look up an item by id or name substring (repeatable)")
    ap.add_argument("--json", help="also write results to this file")
    args = ap.parse_args()
    must = args.must or ["Blacksmithing", "Cooking"]
    later = args.later or ["Engineering", "Tailoring"]
    profs = must + [p for p in later if p not in must]

    global CHAR_PROFS, CHAR_CLASSES
    CHAR_PROFS = load_char_professions()
    CHAR_CLASSES = load_char_classes()
    inv, prices, names = load_inventory(), load_prices(), load_names()
    recipes, needs = load_recipes(), load_zygor_needs(profs)
    apply_smelting(inv, needs)

    if args.item:
        return lookup(args.item, inv, prices, names, recipes, needs, profs, must)

    rows = []
    for iid, it in inv.items():
        p = prices.get(iid, {})
        verdict, reserved, surplus, reasons = decide(iid, it["total"], p, recipes, needs, profs, must)
        unit = p.get("marketValue") or p.get("marketValueRecent") or p.get("regionMarketValue")
        other_uses = sorted({f'{u["prof"]} {u["learn"]}-{u["grey"]}' for u in recipes.get(iid, []) if u["prof"] not in profs})
        rows.append({
            "id": iid, "name": names.get(iid, f"item {iid}"), "have": it["total"], "verdict": verdict,
            "keep": reserved, "surplus": surplus,
            "realmMarket": p.get("marketValue"), "minBuyout": p.get("minBuyout"), "regionMarket": p.get("regionMarketValue"),
            "listed": p.get("numAuctions"), "regionSoldPerDay": p.get("regionSoldPerDay"), "saleRate": p.get("regionSalePercent"),
            "surplusNet": round(unit * surplus * AH_CUT) if unit and verdict.startswith("SELL") else 0,
            "reasons": reasons, "demandFrom": other_uses, "where": dict(it["where"]),
        })

    order = {"SELL": 0, "SELL?": 1, "KEEP": 2, "VENDOR": 3, "IGNORE": 4}
    rows.sort(key=lambda r: (order[r["verdict"]], -r["surplusNet"], r["name"]))
    print(f"Must-keep: {', '.join(must)} | Later: {', '.join(later)}")
    print("Skills: " + ", ".join(f"{p} {best_skill(p)}" for p in profs) + "\n")
    print(f"| Verdict | Item | Have | Keep | Sell qty | Realm mkt | Min buyout | Region mkt | Listed | Sale rate | Region sold/day | Net if sold | Why | Demand from |")
    print("|" + "---|" * 14)
    for r in rows:
        rate = f'{r["saleRate"]:.0%}' if r["saleRate"] is not None else "-"
        spd = f'{r["regionSoldPerDay"]:,.0f}' if r["regionSoldPerDay"] is not None else "-"
        print(f'| {r["verdict"]} | {r["name"]} | {r["have"]} | {r["keep"]} | {r["surplus"] if r["verdict"].startswith("SELL") else "-"} | '
              f'{money(r["realmMarket"])} | {money(r["minBuyout"])} | {money(r["regionMarket"])} | {r["listed"] or "-"} | {rate} | {spd} | '
              f'{money(r["surplusNet"]) if r["surplusNet"] else "-"} | {"; ".join(r["reasons"]) or "-"} | {", ".join(r["demandFrom"]) or "-"} |')
    total = sum(r["surplusNet"] for r in rows)
    print(f"\nTotal net from SELL/SELL? items after 5% AH cut: {money(total)}")
    if args.json:
        Path(args.json).write_text(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()

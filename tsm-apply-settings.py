#!/usr/bin/env python3
"""Apply tuned TSM settings to every account's TradeSkillMaster.lua. Run with WoW closed."""
import glob, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.abspath(__file__))

if subprocess.run(["pgrep", "-f", "Wow.exe"], capture_output=True).returncode == 0:
    sys.exit("WoW is running - close all clients first (TSM overwrites the file on logout).")

# (regex, replacement)
SUBS = [
    # Crafting op: profit as % of cost with a floor, lower restock for a thin market
    (r'(\["minProfit"\] = )"[^"]*"', r'\1"max(50s, 15% crafting)"'),
    (r'(\["minRestock"\] = )"[^"]*"', r'\1"2"'),
    (r'(\["maxRestock"\] = )"[^"]*"', r'\1"5"'),
    # Auctioning op: beat the lowest auction by 1c instead of tying
    (r'(\["undercut"\] = )"[^"]*"', r'\1"1c"'),
    # Commodity AH: post the whole pile instead of 5 at a time
    (r'(\["postCap"\] = )"[^"]*"', r'\1"1000"'),
    # Sounds
    (r'(\["g@ @coreOptions@auctionSaleSound"\] = )"TSM_NO_SOUND"', r'\1"TSM_CASH_REGISTER"'),
    (r'(\["g@ @sniperOptions@sniperSound"\] = )"TSM_NO_SOUND"', r'\1"TSM_CASH_REGISTER"'),
    # Custom price sources
    (r'\["g@ @userData@customPriceSources"\] = \{\n\}',
     '["g@ @userData@customPriceSources"] = {\n'
     '["sell"] = "first(dbminbuyout, dbmarket, dbregionmarketavg)",\n'
     '["cheap"] = "min(dbmarket, dbregionmarketavg) * 0.8",\n}'),
]

def patch(text):
    for pat, rep in SUBS:
        text = re.sub(pat, rep, text)
    # Shopping maxPrice lives inside the "Shopping" operation block; only touch that one
    text = re.sub(r'(\["Shopping"\] = \{\n\["#Default"\] = \{(?:(?!\["(?:Sniper|Mailing|Auctioning|Crafting|Warehousing|Vendoring)"\]).)*?\["maxPrice"\] = )"dbmarket"',
                  r'\1"cheap"', text, flags=re.S)
    # Tooltip: show realm market value (AuctionDB block)
    text = re.sub(r'(\["AuctionDB"\] = \{(?:(?!\},).)*?\["marketValue"\] = )"none"',
                  r'\1"noTrend"', text, flags=re.S)
    return text

for f in glob.glob(os.path.join(ROOT, "WTF/Account/*/SavedVariables/TradeSkillMaster.lua")):
    raw = open(f, encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw  # keep the file's original line endings
    old = raw.replace("\r\n", "\n")
    new = patch(old)
    if new != old:
        open(f, "w", encoding="utf-8", newline="").write(new.replace("\n", "\r\n") if crlf else new)
        print("patched", os.path.relpath(f, ROOT))
    else:
        print("no change", os.path.relpath(f, ROOT))

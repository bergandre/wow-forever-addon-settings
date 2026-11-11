#!/usr/bin/env python3
"""Copy the Boophie Flipping Guide groups (items only) from the Anniversary TSM into every Forever account.

Imports the group tree, its item assignments and the "Boophie Snipe" sniper operation
(belowPrice = 100% dbmarket). Every other module keeps #Default: the Anniversary
auctioning ops are built for stack-based Classic posting and don't fit Forever.
Run with WoW closed. Re-running is a no-op. --dry-run prints counts without writing.
"""
import glob, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.expanduser("~/repositories/wow_anniversary_tbc/WTF/Account/120675253#1/SavedVariables/TradeSkillMaster.lua")
TOP = "Boophie: Flipping Guide"
OP = "Boophie Snipe"
DRY = "--dry-run" in sys.argv

if not DRY and subprocess.run(["pgrep", "-f", "Wow.exe"], capture_output=True).returncode == 0:
    sys.exit("WoW is running - close all clients first (TSM overwrites the file on logout).")


def section(lines, key):
    """Return (start, end) line indexes of a top-level `["key"] = {` table (end = closing `},`)."""
    start = lines.index(f'["{key}"] = {{')
    depth = 0
    for i in range(start, len(lines)):
        # one brace per line in TSM's serializer, so counting per line is enough
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0:
            return start, i
    raise ValueError(key)


src = open(SRC, encoding="utf-8").read().replace("\r\n", "\n").split("\n")
s, e = section(src, "p@Default@userData@items")
item_re = re.compile(r'^\["(i:[^"]+)"\] = "(' + re.escape(TOP) + r'(?:`[^"]*)?)",$')
items = {m.group(1): m.group(2) for l in src[s + 1:e] if (m := item_re.match(l))}
s, e = section(src, "p@Default@userData@groups")
group_re = re.compile(r'^\["(' + re.escape(TOP) + r'(?:`[^"]*)?)"\] = \{$')
groups = sorted({m.group(1) for l in src[s + 1:e] if (m := group_re.match(l))} | set(items.values()))
print(f"source: {len(groups)} groups, {len(items)} items")

MODULES = ["Auctioning", "Crafting", "Mailing", "Shopping", "Sniper", "Vendoring", "Warehousing"]


def group_block(path):
    out = [f'["{path}"] = {{']
    for mod in MODULES:
        out.append(f'["{mod}"] = {{')
        out.append(f'"{OP}",' if mod == "Sniper" else '"#Default",')
        if path == TOP and mod == "Sniper":
            out.append('["override"] = true,')  # subgroups inherit it from the top group
        out.append("},")
    out.append("},")
    return out


OP_BLOCK = [f'["{OP}"] = {{', '["ignoreFactionrealm"] = {', "},", '["belowPrice"] = "max(100% dbmarket)",',
            '["relationships"] = {', "},", '["ignorePlayer"] = {', "},", "},"]

for f in sorted(glob.glob(os.path.join(ROOT, "WTF/Account/*/SavedVariables/TradeSkillMaster.lua"))):
    raw = open(f, encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    lines = raw.replace("\r\n", "\n").split("\n")
    rel = os.path.relpath(f, ROOT)
    if f'["{TOP}"] = {{' in lines:
        print("already imported", rel)
        continue

    # Insert bottom-up so earlier indexes stay valid
    s, _ = section(lines, "p@Default@userData@items")
    have = {m.group(1) for l in lines if (m := re.match(r'^\["(i:[^"]+)"\] = "', l))}
    new_items = [f'["{i}"] = "{g}",' for i, g in sorted(items.items()) if i not in have]
    s_g, _ = section(lines, "p@Default@userData@groups")
    s_o, e_o = section(lines, "p@Default@userData@operations")
    sniper = lines.index('["Sniper"] = {', s_o, e_o)

    inserts = sorted([(s, new_items), (s_g, [l for g in groups for l in group_block(g)]), (sniper, OP_BLOCK)],
                     reverse=True)
    for at, block in inserts:
        lines[at + 1:at + 1] = block
    print(f"{rel}: +{len(groups)} groups, +{len(new_items)} items, +{OP}" + (" (dry run)" if DRY else ""))
    if not DRY:
        text = "\n".join(lines)
        open(f, "w", encoding="utf-8", newline="").write(text.replace("\n", "\r\n") if crlf else text)

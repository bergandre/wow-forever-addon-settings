# WoW Forever addon settings

## Rule: keep this file current

Knowledge about this repo lives **in this repo**, not only in chat or personal memory. Whenever you
change or discover something a future session would need, update this file (or a doc it links to)
in the same session, before finishing:

- custom addon settings you set or edited (which addon, which profile/keys, what and why)
- symlinks / linkages between accounts, characters, installs or repos
- copies of settings from other installs (source → target, any renames)
- addons installed, removed or rejected, and why
- quirks of the Forever client or an addon version that cost time to find out

Keep entries short and factual; replace outdated entries instead of appending contradictions.

This repo IS the live game UI: the WoW Forever install links its folders here.

```
bottles/bottleNetV12/drive_c/Program Files (x86)/World of Warcraft/_forever_/
  Interface -> ~/repositories/wow-forever-addon-settings/Interface
  WTF       -> ~/repositories/wow-forever-addon-settings/WTF
```

Edits here hit the game directly. Client: WoW Forever, `## Interface: 16001` (game ver 1.60.x);
many addons ship one TOC for 11509 / 16001 / 20506. Install addons via the CurseForge app with
the **Forever** flavor selected; not every Classic addon exists for Forever (e.g. Cell does not).

## Accounts and characters (realm folder `93`)

| Account dir      | Characters                                   | Role |
|------------------|----------------------------------------------|------|
| `120675253#1`    | Karums-Warrior (main), Opikol-*, Berg-Andre… | Warrior (Arms) |
| `120675253#2`    | Karums-Priest, Gniloe-Forever, Hypr-Land     | Healer in the multibox duo |
| `120675253#3`    | Invited-*, Tailoring-Altchar                 | alts |

Warrior + priest are multiboxed together (dungeons as a duo). Priest macros use `focus` = warrior.

## Editing SavedVariables safely

- `WTF/Account/<acc>/SavedVariables/<Addon>.lua` = account-wide, `.../93/<Char>/SavedVariables/` = per-char.
- The game writes SavedVariables on **logout and on `/reload`** — `/reload` saves the in-memory
  state first, so it overwrites file edits. Before editing a file: that account's characters must be
  at **character select** (or the client closed). Check with `pgrep -fa Wow.exe` (3 clients usual).
- Back up to the scratchpad before editing; validate after: `luac -p file.lua` and
  `lua -e "dofile('file.lua') ..."` to inspect tables.
- Profile keys: Grid2 and Plater both use `"Karums Priest"` (space, no realm) on Forever.
- `link-ui-settings.sh`: symlinks shared addon SavedVariables from `#1` into `#2`/`#3`
  (list `SHARED`). Run with WoW closed. Grid2 and Plater are NOT in that list (per-account files).
- Settings changed in-game survive addon updates (they live in SavedVariables, not in the addon folder).

## Healing / UI setup (Nov 2026)

- **Grid2** = party/raid frames (HealBot was tried, didn't show frames; Cell not on Forever).
  Custom statuses in priest + warrior profiles (warrior is a copy of priest):
  `buff-Renew-mine` (green) / `buff-Renew-other` (gray) on `corner-renew` (top-left);
  `buff-PWShield` (yellow) then `debuff-WeakenedSoul` (red) on `corner-shield` (top-right) —
  empty corner = can shield. Debuff center icons maxIcons=3, generic buffs bottom-left.
  Grid2 here is the "midnight" port: statuses `mbuff`/`mbuffs`/`mdebuffs` with `auras = {spellIDs}`
  (list all ranks) and `aura_filter.filter` = Blizzard filter string. Caster filter is only
  `PLAYER` / `!PLAYER` — no filtering by caster name.
  **Quirk:** a single `icon` indicator uses only its highest-priority aura status
  (`GridIndicatorAuras.lua` `GetStatusAurasFilter`); lower ones mapped to it are ignored. So
  mine/other on one corner doesn't work (Weakened Soul under PW:Shield is likewise dead). Warrior's
  `corner-renew` therefore maps only `buff-Renew-other`, filter `HELPFUL` (any caster), green.
- **Plater** = nameplates. Profiles copied from the Anniversary repo; `Default` = old paladin
  profile `FreamhOld`, old Default kept as `Default (TBC)`. Execute range: built-in mod
  **Forever = Plater "midnight" code path** (`DF.IsForeverWow()` → `IS_WOW_PROJECT_MIDNIGHT`,
  plus the new aura-container API). Consequences:
  - `unitFrame.InExecuteRange` is never set → builtin `Execute Range [Plater]` mod does nothing
    (disabled). Custom mod **`Execute Green`** (warrior, `hook_data`) wraps
    `Plater.GetHealthCutoffValue` to force a 20% range and recolors Plater's own execute zone
    texture (`healthBar.executeRange`, faded in by Plater only in range) green on OVERLAY;
    `health_cutoff_alpha = 0.85`. Not yet confirmed in-game.
  - Aura tracklist matches **by spell ID only** — by-name entries (`[id] = true`) don't work.
    `aura_tracker.debuff_tracked` (any caster, tracking stays **Automatic**) lists every rank with
    `= false`: warrior = SW:P ranks; priest = Rend + Sunder Armor ranks.
  - Global `GetSpellInfo` doesn't exist on Forever (use `C_Spell.GetSpellInfo` in `/run` tests).
  Threat colors (`tank.colors` / `dps.colors`): gray = fine (tank holds it), orange = act,
  yellow = threat switching, teal = (DPS/healer) mob is on someone else / the warrior. `tank_threat_colors` forces tank colors on Classic clients (auto-detect = Defensive
  Stance only): warrior `true` (tanks the duo in Battle Stance), priest `false`. Warrior macro
  `/run Plater.ToggleThreatColorMode()` flips tank↔DPS colors in groups with a real tank (works).
  Plater files were edited with a load→modify→serialize Lua script (keeps data exact; never
  format numbers with `%q` on Lua 5.4+, it writes hex floats).
  **Quirk:** edits to Plater.lua got overwritten twice by a client that was still in-world on
  that account (priest copy; warrior edit at 16:08). Before editing, confirm the account just did
  a full logout save: `find WTF/Account/<acc>/SavedVariables -name '*.lua' -mmin -15 | wc -l`
  should be ~40+. After the next login/logout, re-check the values are still there.
- Decursive installed for dispels. Clique (click-casting) recommended, not installed yet.
- User prefers existing addons over writing custom ones (a custom PartyAuras addon was tried and dropped).

## Other repos

- `~/repositories/wow_anniversary_tbc` — TBC Anniversary UI (same layout). Old addon settings
  (Plater, UnitFramesPlus, Clique, BigDebuffs…) can be copied from its `WTF`.

## Scripts here

- `tsm-*.py`, `tsm-export-inventory.lua`, `inventory.json` — TSM analysis/sync (run with WoW closed
  when they write SavedVariables). `tsm-analyze.py --item` for item questions.
- `.claude/skills/profession-plan` — profession leveling planner.

## Commits

Conventional commits, English. Large `dump` commits of WTF state are normal here.

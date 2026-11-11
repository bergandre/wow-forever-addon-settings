# WoW Forever addon settings

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
- Profile keys: Grid2 uses `"Karums Priest"` (space), Plater uses `"Name - Realm"`.
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
- **Plater** = nameplates. Profiles copied from the Anniversary repo; `Default` = old paladin
  profile `FreamhOld`, old Default kept as `Default (TBC)`. Execute range: built-in mod
  `Execute Range [Plater]` enabled (green bar < 20%). To show another character's DoTs use
  `aura_tracker.debuff_tracked` (any caster); automatic tracking shows only your own.
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

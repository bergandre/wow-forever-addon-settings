# Forever reagent catalogue

Reviewed 2026-10-31 against public Forever beta item data. These are known item
records, not a claim that every item is obtainable in the current client.

## Structure

`Reagents/ClassicData.lua` builds a fresh Classic baseline. `Classic.lua` registers
it unchanged. `Forever.lua` adds the following materials and registers it under
the localized Forever label. Only the Camelot manifest loads `Forever.lua`.
The six plugin IDs and existing `HideItem_<ID>` settings are retained.

| Tracker | Additions (item ID) |
| --- | --- |
| Enchanting | Mote of Magic (247786); Malleable Essence of Nature (274030) |
| Fishing | Whimsyfin (251524); Seasonal Fish Steaks (273295) |
| Herbalism | Frilled Lichen (249399); Rosecap (249424); Stranglevine (249274); Marefoil (248823); Demonsage (248821); Death Lotus (248822); Commonplace Herb Seeds (268415); Uncommon Herb Seeds (268416); Unusual Herb Seeds (268417); Scarce Herb Seeds (268418) |
| Mining | Pyrite (249391); Bauxite (249425); Pitchblende (249426); Heavy Thorium Ore (248815); Heavy Thorium Bar (251291); Azerothium Bar (249726); Legionite Bar (251290); Fel Crystal (248819); Torbernite (248820) |
| Skinning | Pristine Leather (249427); Pristine Hide (249428); Pristine Scale (249429); Fel Leather (248825); Fel Hide (248824) |
| Tailoring | Cerulean Dye (249409); Magenta Dye (249430); Viridian Dye (249431) |

## Sources

- [Forevercraft trade goods catalogue](https://www.forevercraft.app/reference/items?category=7): client item names and item IDs in catalogue links, including seeds, metals, leather and dyes.
- [Wowhead: Mote of Magic](https://www.wowhead.com/forever/item=247786/mote-of-magic): reagent identity and vendor availability.
- [Forever Codex: Malleable Essence of Nature](https://forever-codex.com/items/?id=274030): client tooltip, item ID and crafting uses.
- [Wowhead: Marefoil](https://www.wowhead.com/forever/item=248823/marefoil) and [Demonsage](https://www.wowhead.com/forever/item=248821/demonsage): herb identities.
- [Forever Codex: Pyrite](https://forever-codex.com/items/?id=249391) and [Stranglevine](https://www.foreverdb.app/en/forever/items/249274/stranglevine): IDs and recipe uses.
- [Forever Helper: Whimsyfin](https://wowforeverhelper.com/item/251524/whimsyfin): client item ID and Classic comparison.
- [Forevercraft: Seasonal Fish Steaks](https://www.forevercraft.app/items/273295): prepared fishing ingredient, separate from the raw fish.

## Scope and validation

The existing Classic material IDs remain in the Forever baseline. An item absent
from an incomplete beta extract is not treated as removed. Names are resolved
from the running client, so name/localization changes do not require new IDs.

This remains a curated material tracker for the existing six categories, not an
inventory of every recipe ingredient. Dyes are included with Tailoring because
they supply cloth crafts; the Mining group includes new bars and mineral-related
crafting reagents. This grouping does not assert a gathering source: for example,
Legionite Bar is an Alchemy transmute. Quest-only items, finished equipment,
camp objects, and the full range of Engineering parts are outside this change.

Automated checks cover catalogue isolation, item-ID uniqueness, preserved Classic
data and settings, TOC routing, registration, bank totals, and session changes
using mocked item APIs. Protected clicks, bank cache behavior and actual item
availability still require an in-game Forever check.

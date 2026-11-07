# Titan Professions Multi

Titan Professions Multi is a collection of Titan Panel plugins for tracking profession skill levels, session progress, reagents, and archaeology fragments across multiple versions of World of Warcraft.

Titan Panel is required.

![Titan Professions Multi menu](https://i.imgur.com/M6B4WGq.jpg)

![Profession plugins on the Titan bar](https://i.imgur.com/zgP7iIN.jpg)

## Features

- Individual Titan plugins for every profession available in the current game client.
- A **Master** plugin that summarizes all learned professions in one tooltip.
- Current and maximum profession skill values, active skill bonuses, and gains made during the current session.
- Left-click access to profession windows when supported by the game client.
- Optional profession-combination suggestions in tooltips.
- Reagent totals from bags and the bank, with session gains and losses.
- Per-item visibility controls for reagent plugins.
- A single archaeology-fragments plugin on Retail and Mists of Pandaria Classic.
- Expansion-aware loading, so each game client loads only the profession and reagent data it supports.

## Supported game versions

| Game client | Profession plugins | Reagent sets | Additional plugins |
| --- | --- | --- | --- |
| Retail / Midnight | All current professions | Legion, Battle for Azeroth, Shadowlands, and Midnight | Master and Archaeology Fragments |
| Mists of Pandaria Classic | All professions, including First Aid and Archaeology | Mists of Pandaria | Master and Archaeology Fragments |
| Classic Era | All available professions, including First Aid | Classic Era | Master |
| WoW: Forever (Camelot, interface 16001) | Classic professions, including First Aid | Classic base with Forever additions | Master |
| The Burning Crusade Classic | All available professions, including First Aid and Jewelcrafting | The Burning Crusade | Master |

First Aid is intentionally unavailable on Retail. Jewelcrafting is loaded for The Burning Crusade Classic but not for Classic Era.

Forever uses `TitanProfessionsMulti_Camelot.toc` and the modern profession API, with First Aid in its client-specific slot and a profession cap of 300. It does not load Archaeology or later-expansion reagent sets. Install a Forever-compatible version of Titan Panel alongside this addon. In-game validation on Forever is still required; local checks cannot verify protected clicks or bank behavior in the client.

Classic and Forever share `Reagents/ClassicData.lua`. Separate `Classic.lua` and `Forever.lua` entry points register the appropriate catalogue, so Forever additions never appear on Classic Era. Forever adds 31 materials across the existing six reagent plugins, including scarce materials, endgame herbs, herb seeds, new metals and bars, leather, dyes, and fishing ingredients. Plugin IDs and existing per-item settings are preserved. See [Forever reagent research](docs/forever-reagents.md) for item IDs, sources, and scope.

## How to use

1. Right-click the Titan Panel.
2. Open the **Profession** category to enable profession, Master, or archaeology plugins.
3. Open **Profession [Reagents]** to enable reagent plugins. Category names are translated for supported locales.
4. Right-click an enabled plugin to configure its display options.

Profession plugins can display the icon, maximum skill, simplified bonuses, profession combinations, and session gains. Reagent plugins can display session changes and let you hide individual reagent types. Every plugin menu also includes controls for moving the plugin left or right on its current Titan bar.

For easier identification in the Titan menu, profession plugins are yellow, reagent plugins are orange, and the Master plugin remains red.

## Archaeology Fragments

Add the **Archaeology Fragments** plugin to the Titan bar to track fragments by race. When an artifact is ready to solve, the plugin displays the corresponding race as ready. Its right-click menu can also show races that do not currently have enough fragments.

This plugin is available on Retail and Mists of Pandaria Classic.

## Languages

The addon currently includes translations for:

- English
- Brazilian Portuguese
- German
- Spanish (Spain)
- Spanish (Latin America)
- French
- Italian
- Korean
- Russian

Unsupported locales fall back to English. Reagent item names are obtained directly from the WoW client whenever available.

## Support

Please report problems through the [GitHub issue tracker](https://github.com/Canettieri/professionsmulti/issues). When reporting an issue, include the WoW game version, character locale, and any error message shown by the client.

## Donations

If you would like to support continued development, you can [donate through PayPal](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=7AEAZ7XG7WVDS&lc=US&item_name=Titan%20Multi%20Addons&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted).

Many thanks to the people who have helped maintain this project:

- Colleen Harper
- Patricia Rich
- Adrian Collins
- Jessica Allen
- Randol Ford
- Sebastian Edelmann
- Edwin Sutton Jr.
- Dean Grable
- Peter Cebull
- Max Toedtemeier

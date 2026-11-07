# Changelog

All notable changes to this project will be documented in this file.

## [11.1.0] - 2026-11-03

### Changed

- Label reagent subtotals by quality and clarify that they include bags and bank.
- Reduce the space above the first reagent while keeping a blank line between reagents.

### Fixed

- Count Retail reagents directly from equipped bags, including the reagent bag, before calculating the bank balance.
- Show the quality rank when a reagent variant's item link is still loading.

## [11.0.0] - 2026-11-01

### Added

- Added a dedicated Forever (Camelot, interface 16001) manifest with Classic professions, First Aid, Classic reagents, and Master.
- Added 31 Forever-specific materials across the six reagent plugins, with translated Forever menu labels.
- Added **Move Left** and **Move Right** controls to every plugin menu.
- Added translations for the new bar-position controls in all supported languages.

### Changed

- Updated the Retail interface version to 120105 for WoW 12.1.5.
- Adapted Forever's First Aid slot and 300-point profession cap to the shared tracker.
- Split Classic reagent data from client registration, keeping a shared baseline and a separate Forever additions file without changing existing plugin IDs or item settings.
- Use the modern spellbook API for profession and Master clicks when available, and skip profession casts during combat.
- Prefer modern C_Item APIs for reagent counts and item information, with legacy fallbacks.
- Added consistent spacing between the Bar Text, Tooltip, and Bar Position sections.
- Centralized the shared menu title, bar-position, Hide, and Close controls for consistent behavior across Retail, Mists of Pandaria Classic, Classic Era, and The Burning Crusade Classic.

## [10.0.0] - 2026-09-21

### Added

- Added profession reagent trackers for Midnight on Retail.
- Added reagent trackers for Mists of Pandaria Classic, Classic Era, and The Burning Crusade Classic.
- Added a dedicated Titan Panel category for reagent plugins: **Profession [Reagents]**.
- Added complete missing translations for German, Spanish (Spain and Latin America), French, Italian, Korean, and Russian.

### Changed

- Rebuilt all profession plugins around a shared, data-driven profession tracker while preserving their existing Titan plugin IDs and features.
- Rebuilt all reagent plugins around a shared reagent tracker with bag and bank totals, per-item visibility controls, and session gains and losses.
- Consolidated profession definitions into one file per client family instead of one file per profession.
- Consolidated reagent definitions into the new `Reagents` folder, with one file per expansion.
- Limited each reagent set to its appropriate game client: Retail, Mists of Pandaria Classic, Classic Era, or The Burning Crusade Classic.
- Integrated First Aid into the shared profession system for Mists of Pandaria Classic, Classic Era, and The Burning Crusade Classic while keeping it disabled on Retail.
- Kept Jewelcrafting exclusive to The Burning Crusade in the Vanilla/TBC profession set.
- Standardized plugin menus so the separator, Hide command, and Close command appear together at the bottom.
- Restored colored profession names in the Titan menu after Titan's sorting process.
- Standardized profession plugin names in yellow and reagent plugin names in orange, while preserving the Master plugin in red.
- Removed obsolete reagent localization entries; reagent item names now come from the WoW client whenever available.

### Fixed

- Preserved profession session gains, skill bonuses, maximum-skill warnings, tooltips, and click-to-open behavior after the shared-engine migration.
- Improved profession cap handling across Retail and Mists of Pandaria Classic, including Midnight values.
- Improved reagent updates when entering the world or changing bag and bank contents.
- Added isolated error handling so a faulty reagent definition cannot stop the remaining reagent plugins from loading or updating.
- Updated `LibAddonCompat` to version 1.1.0 (LibStub revision 13):
  - Fixed the Brazilian Portuguese name for Jewelcrafting.
  - Added safe handling for missing API functions and optional numeric values.
  - Added a fallback for Classic clients that do not reliably mark primary professions as abandonable.
  - Improved localized profession detection.

[11.1.0]: https://github.com/Canettieri/professionsmulti/releases/tag/v11.1.0
[11.0.0]: https://github.com/Canettieri/professionsmulti/releases/tag/v11.0.0
[10.0.0]: https://github.com/Canettieri/professionsmulti/releases/tag/v10.0.0

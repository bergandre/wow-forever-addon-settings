# Changelog

## [13.17.3] - 2026-11-05

### Fixed

- Buff Reminder: The settings page now visibly explains how to access additional options in Edit Mode.

### Added

- Cooldown Panels: Added a Well Fed template that tracks food buffs together and defaults to a desaturated icon when no matching buff is active.

## [13.17.2] - 2026-11-05

### Fixed

- Swing Timer: The bar texture setting now appears in the Bar tab instead of the Text tab.
- Unit Frames and Resource Bars: Mana values now refresh as frequently as other continuously updating resources.
- Health Macro: Windstone is now included as a healing consumable while in Skywall.
- Buff Reminder: Intellect, Stamina and Spirit scrolls now satisfy their matching class buff reminder when strong enough, accounting for improved buff talents.
- Drink Macro: Drinks now appear before optional food so the button shows your available drink first.
- Loot: The junk deletion button now appears with a full backpack even when some bag slots are unequipped.
- Mana regeneration marker: Aligns once with the first mana update after the five-second pause, then continues without restarting on every update.

## [13.17.1] - 2026-11-05

### Changed

- Nameplates: Removed the aura click-through option because default nameplate auras no longer intercept mouse input.

### Fixed

- Experience Bar: Completed quest XP can now be shown as a colored segment, value, or percentage.
- Combat logging: Automatic logging now stops outside selected content without restoring a previous logging state.
- Spell ranks: Updated rank selection for the current Forever spells, including new low-level Druid ranks and additional high-level ranks.
- Cooldown Panels: Updated Spell Group and defensive aura presets for the current talents and spell ranks while preserving existing Druid preset exclusions and ordering.
- Buff reminders and Healer Buff Placement: Removed obsolete Blessings of Light and Salvation and their saved selections, and added Oath of Light to the healer buff catalog.
- Bags: Fixed item slot backgrounds on the current Forever client.
- Local builds: Automatically detect the installed Forever client.

## [13.17.0] - 2026-11-03

### Added

- Cooldown Panels: Added horizontal and vertical bar layouts, four anchored bar groups, and shared or per-entry sizing, appearance, text and icon controls.
- Cooldown Panels: Link Spell Groups to bar groups, anchor panels to Resource Bars, and match the anchor size with an adjustable offset.
- Resource Bars: Assign resources to the shared Main, Secondary and Tertiary bars, with separate assignments for each Druid form.
- Spell Groups: Added templates for core rotation, rotational and healing cooldowns, active mitigation, ally protection and support.
- Castbars: Added optional interrupt-ready markers with configurable colors and Edit Mode previews.
- Health Macro: Configure potion priorities by expansion with automatic quality selection, and combine combat-end, target-change and timed resets with separate rules for each class.
- Bags: Set the maximum number of bank columns independently from your bags.
- Merchant: Mark collectibles with checkmarks and crosses without dimming item icons, names or prices.
- Minimap: Independent subzone text can use the current zone color.
- No Target Alert: Added an adjustable delay to avoid warnings during brief target gaps.
- Vendor: Baganator selling and destruction rules can be used for junk detection and grouping.

### Changed

- Spell Groups: Templates are listed alphabetically by localized name, with each ability assigned to one template.
- Merchant: Settings share one page with separate sections; collection marking and dimming turn each other off.
- Camera: Maximum camera zoom now uses a distance factor of 2.6.
- Merchant: Collected transmog sources use green checks; appearances known from another source use light blue checks.

### Fixed

- Resource Bars: Bars recover their position and width when an anchor panel is deleted, and reconnect when a temporarily unavailable anchor returns.
- Data Panels: Friends and guild popups adapt their columns to the available space, wrap long text and show clipped entries on hover.
- Container Actions: Learn and open actions pause while a merchant is open and resume when it closes.
- Party Frames: Newly invited members appear after their names become available.
- Vendor: Fixed repeated bag scans, unnecessary refreshes and performance spikes while using the Baganator junk integration.
- Merchant: Collection status correctly recognizes learned appearances, ensembles and cosmetic items, and refreshes after learning new appearances.

	ADDON  INFORMATION
	Name: TitanRestPlus
	Purpose: Keeps track of the RestXP amounts and status for all of your characters.
	Command-line: /restplus help
	Authors: Yunohu/Kernighan, Madysen and Vogonjeltz

TitanRestPlus keeps track of the RestXP amounts and status for all of your characters.

TitanRestPlus is a RestXP-displaying Titan plugin that features a compact and customizable display. It has been coded especially to assist players who have characters on more than one server -- for this reason, the display is very compact (allowing more characters to be shown than similar mods can), and it groups and sorts characters by server (with the current server displayed at the top of the list). The list is colorized based on the state of each character's Rest level.

TitanRestPlus saves information about your characters' experience (XP) and rest XP at logout. It uses this information to calculate the amount of rest experience accumulated for any of your characters at any time. This is accomplished using simple arithmetic: Every X hours you get 5% of the experience required to reach your next level, until you hit the cap of 150%. X is 8 hours if you are logged out in a resting state, and 32 if you are not.

The addon alerts you when one of your characters has enough rest XP to last until the end of their current level, and also when one of the characters has reached the rest XP cap.


FEATURES
-- Displays a list of all your characters and their RestXP information.
-- Sorts current server's characters to the top of the list.
-- Groups characters by server (with or without server labels enabled).
-- Colorizes character names so you know which ones are maxed, which can reach the next level, and which cannot.
-- Very compact display allows for more characters than similar addons can show.
-- Can display raw or percentage formats for XP, Rest, and/or the Titan button.
-- Can hide or display Server names, character classes, and/or levels.
-- Level 60 characters are supported by showing a "Maxed Experience" label in the tooltip display.
-- Can toggle the Titan bar display to show the icon, label text, both, or neither.


COMMANDS
/restplus                         = print rest info in chat
/restplus help                    = show command info
/restplus save                    = save current character
/restplus reset                   = delete all saved data
/restplus remove charName realm   = delete one character
/restplus sound                   = toggle sound on/off
/restplus timer                   = toggle timer on/off
/restplus delay n                 = set alert timer to n seconds
/restplus recycle                = reset options to default
/log                             = save current character and log out


VERSION HISTORY

v9.0.1.1
-- Fix variable for max level

v9.0.1.0
-- Fixed max level to be 60
-- Update ToC

v8.2.0.0
-- Update ToC

v8.0.1.0
-- Fixed Pandaren to show 300% Rest XP Cap
-- Fixed right-click menu
-- Added color option orange
-- Added option to display race (If character hasn't been loaded since update race shows "NA"

-v8.0.0.1
--- Update maxlevel to 120 now that BfA is released

v8.0.0.0
-- update for patch 8.0.1

v7.3.5.0
-- update for patch 7.3.5
   prep for Battle of Azeroth level increase for new max level 120
   
v7.3.0.0
--  Update for patch 7.3.0 by Madysen

v7.1.0.0
--  Update for patch 7.1.0 by Maillen

v7.0.3.0
--  Update for patch 7.0.3 by Maillen
--  Add new race Demon Hunter
v6.0.3.0
-- Update for 6.0.3

v5.0.4
--  Update for 5.0.4
--  Prep for Mists level increase and new Monk class

v4.0.3a
--  Max Level now determined by expansion level

v4.0.3
-- Updated for new max level 85

v4.0.1
-- added color options

v4.0.0
-- Updated for 4.0.1

v3.0.2
-- Fixed to show in Titan Panel 4

v3.0.1
-- Minor repair - change file location

v3.0.0
-- Updated for WOTKL and WoW 3.0.x.
-- Updated for 80 lvl

v2.0.2
-- Updated for patch 2.4.x.
-- Added some documentation.

v2.0.0
-- Updated for TBC and WoW 2.0.x.

v11100-1
-- Updated for Patch 1.11.

v10900-1
-- Initial release


WOW FOREVER / WELL RESTED LEGACY TALENTS
---------------------------------------
This build estimates offline rested XP for every character saved in RestPlus_Data and
applies the Well Rested rank saved for that character. The rank is shown as WR0-WR5 in
the character tooltip.

Automatic detection: on WoW Forever, the addon walks C_Traits configurations and trees,
resolves the talent entry name, and reads its allocated rank. The old GetTalentInfo route is
kept only as a compatibility fallback. Use /restplus wellrested auto to clear a manual override.

Manual setup (recommended if auto-detection does not work on your WoW Forever client):
  /restplus wellrested 0
  /restplus wellrested 1
  /restplus wellrested 2
  /restplus wellrested 3
  /restplus wellrested 4
  /restplus wellrested 5
/restplus wellrested auto  (clear manual override and retry detection)
Run the command on each character and choose that character's actual talent rank. The
manual value is saved per character and takes precedence over auto-detection.

Important limitations:
- The addon's character list comes from SavedVariables available to this WoW account and
  game installation. It cannot automatically read characters stored in a different WoW
  account or a separate installation unless their SavedVariables are copied/merged.
- Offline rested XP is an estimate; the server's actual XP accrual and talent effects are
  authoritative. The inherited base assumptions are 5% per 8 hours in a rested area and
  5% per 32 hours outside, with each Well Rested rank multiplying the rate by 1 + 0.04*rank.
- Requires Titan Panel, as did the original addon.

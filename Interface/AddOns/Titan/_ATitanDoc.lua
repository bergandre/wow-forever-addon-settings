--[======[ File
Starts the Titan developer documention.

2026 Aug : 
- Removed Var API.
- Removed ---Titan from code
- Updated per LDB changes and Edit Mode being in all WoW versions
--]======]

--[======[ Titan Documentation Beginning

This document will introduce Titan essentials for a Titan developer. 
The intent is simplify what may appear to be a daunting experience. 

We suggest you grab your favorite beverage, read this doc, and relax! 
Many Titan mysteries will be explained. 🙂

The Titan team and its users are available to answer questions.
The two most used ways are : 
- The Titan Discord community : Preferred for quick answers and discussion.
- The Titan Curse comments under Titan Panel addon : Much slower

====== IDE Tools used: See _TitanIDE.lua

====== Documentation blocks
These are created from annotations in the Lua files.

---API
These are XML templates and tables and routines Titan will keep stable.
Changes to these variables and routines will be broadcast to developers via Discord at a minimum.

--[===[ File
Contains ...
--]===]
Each file has a terse description of its contents.

--[===[ Var 
...
--]===]
These are critical tables and info used within Titan.


Note: !! All other variables and routines are Titan internal and may change at any time.
--]======]

--[======[ Titan Start editing

Before you start changing any code, it is HIGHLY recommended to install the following WoW addons:
- BugGrabber : Grabs errors and stores them
- BugSack : The visual part of BugGrabber
- WowLua : This allows you to try Lua code directly in WoW.

Small changes are recommended; then test your coding.
When testing, just start or reload WoW. All versions now check and load new files on reload.

Reload is /reload in game chat.

Regardless of tools used, please update any annotations and comments as changes are made!!!

====== Additional Help For You
A good Lua resource is https://www.lua.org/docs.html
NOTE: WoW uses Lua version 5.1 as its base.
NOTE: WoW does restrict, add, or even remove some Lua features. For example the file routines and many OS routines are not available to any addon.

There are sites that have deeper explanations about addon development, such as
- Wowhead.com
- World of Warcraft Wiki (Warcraft.Wiki.gg).
Please use these or other sites for more detailed addon and Blizzard API information. 
The API information changes as Blizzard adds features, changes API methods, or any other reason.
https://warcraft.wiki.gg/wiki/API_change_summaries

====== Folder Structure
Inside the Titan folder you will notice :
- Artwork folder : Contains icons and skins(textures) used by Titan
- libs : Library routines Titan uses
- A .toc file
- Many .lua files including this file
- An XML file : Containing Titan templates mainly for plugins


====== .toc
The site https://warcraft.wiki.gg/wiki/TOC_format contains more info than you will ever need on TOC format.

The folder and the .toc files MUST have the same name!
Sort of... the name prior to the underscore(_) must be the same as the folder name. 
The part after (postfix) has meaning to the WoW addon loader tells the loader the expansions the addon should be loaded for.

Titan uses at least one postfix value - _Vanilla - for Classic Era version to load Ammo and Regen for CE only.

====== .toc internals
Each .toc file begins with 'directives' which start with "##".

The ## Interface value should match the current interface value of the corresponding WoW version.
In BattleNet this is typically shown below the 'Play' button.
For example, DragonFlight 10.02.05 is represented without dots - 100207 - in the .toc.

If the interface value is higher or lower, WoW will complain that you are running 'out of date' addons.

The Interface value can be a list of WoW versions.

After the TOC directives, Titan lists the files in the order they are to be parsed.
This is important for Titan (or any addon) to load properly.

TitanGame.Lua specifies TITAN_ID used throughout Titan.

Then the Ace libraries. Note Titan does not use all the Ace libraries.
_Titan_Lib_Notes shows a running change history of the libraries.

Then all the localization files.

Then the Titan code files.

====== Artwork

WoW tends to use .tga image files.
Lookup TextureBase:SetTexture for current accepted image types.
NOTE: All versions of WoW may not accept all image types.

Most graphic art software can save to these formats. 
We don’t recommend using an online source to convert one image format to another. 
They have a tendency to add additional code or info to the image.
--]======]

--[======[ Titan Panel Profiles
Titan has always run on profiles. In release 9.* this became more explicit to the user with Sync.
Custom profiles have been available for some time before 9.* but are more usable with Sync and Sync All.
Note: Character profiles do not part of custom profiles. One can not log into custom profiles.

On PEW, Titan determines the profile to use - See code flow below. 
This sets Titan the way the user wants; showing the selected bars and plugins.

Also in Titan 9.* character data such as gold and mail (Post) were moved into the profile. 
This reduced the data built-in plugins needed to store on each character.
The moving of data changed Titan saved vars and processing.

Every character has had a section in saved variables since release 1.0:
TitanSettings.Players.<name>@<server>

A .Info table was also added in 9.* under each player saved vars to hold character information.
Some built-in plugins added a .<plugin> at the same level as .Info; such as .Gold for Gold
The table holds data needed for the plugin such as a show / hide character option.

The Saved Variables section below shows a sample saved variable structure.

Consequences of this change are:
1) Titan must ensure a .Info exists for each character profile.
This is done in TitanVariables before Titan decides the profile.
.Info can be an empty table for a character not logged into yet but it must exist. 
An empty table is easier than seeing if the table exists before every reference.

2) Plugins with their own data section must ensure the entry exists for each character profile.
This should be done as part of the OnShow to ensure Titan tables are whole.
The plugin Onload event is too early to check profile info. 
Titan **may** not be done processing the PEW event where the profile data is read and verified.

3) Titan and Plugins that need .Info must NOT assume values exist.
This allows information to be built over time as the user logs into characters.
Plugins should set default values as the table entry is created for each character.

--]======]

--[======[ Titan Addon code flow

First step: ======= Starting WoW
Wow will load Titan along with other addons installed. The order addons are loaded is not guaranteed!

The files listed in the TOC will will be loaded and run in the order listed.
Examples:
- TitanGlobal.lua sets up constants and variables used by Titan
- TitanTemplate.xml : Creates the Titan frame - TitanPanelBarButton - used to receive events.
- Titan.lua local variables and registering for some events such as ADDON_LOADED
- Creation of functions
- TitanLDB.lua creates LDB to Titan frame to handle LDB objects

ADDON_LOADED event is fired after every addon WoW loads.
When the ADDON_LOADED event for Titan is received:
- Titan registers for event PLAYER_ENTERING_WORLD
- Titan ensures its saved variables are whole and known player profiles are read.

NOTE: On ADDON_LOADED is the first time Titan saved variables should be considered loaded and safe!!
Using addon saved variables before ADDON_LOADED is likely to result in nil(s).

NOTE: The addon saved vars are NOT the Titan plugin saved vars via the registry (.savedVariables)! 
The registry is processed later!

Next: ======= Waiting for WoW
WoW fires a bunch of events as this and other addons are loaded.
Eventually the game and all addons are loaded and PLAYER_ENTERING_WORLD event is sent

Next: ======= Entering world - PLAYER_ENTERING_WORLD (PEW) event
NOTE: This event is sent on both login and reload with a parameter to tell the difference.

When PLAYER_ENTERING_WORLD event is received via OnEvent, the real work begins.
There is NO guarantee PEW events are sent in any order across addons!
See 'Titan Relationship' section below.

The local routine - TitanPanel_PlayerEnteringWorld - is called using pcall.
This ensures Titan reacts to errors rather than leaving Titan, and possibly WoW, in a bad state.
TitanPanel_PlayerEnteringWorld does all the variable and profile setup for the character entering the world.

On login PLAYER_ENTERING_WORLD - not reload - Titan
- Sets character profiles - Titan_G.vars.InitSettings
- Sets TitanPanel*Anchor for other addons to adjust for Titan
- Creates all Titan bars including right click menu and auto hide frames. See Frames below.
- Registers for events Titan - RegisterForEvents

On login and reload Titan
- Set THIS character profile () - Titan_G.vars.UseSettings - 
   See TitanVariables file for more details on saved variables; this is a simple concept but touchy to implement.
   The user chosen profile sets the user chosen plugin saved vars for both Titan and any plugins.
   Titan_G.vars.UseSettings uses
   - TitanPanel_InitPanelBarButton to set the bars the user wants.
   - Titan_G.bars.ShowPlugins to set the plugins the user wants on the user selected bars.
- Update the Titan config tables for the config screens - Titan_G.config.Update
- Set Titan font and strata
- Register and set up any Titan plugins.
- Wrap any LDB plugins with a generated Titan plugin- Titan_G.ldb.RefreshAll

If the above was successful then all is good
If the above failed then 
- tell user something bad happened along with the error they can pass to the dev team
- attempt to hide all bars as cleanup
- nuke the Titan config tables as cleanup

--]======]

--[======[ Titan Panel relationship to Titan plugins and LDB
Titan plugins list Titan as a dependency. 
This ensures Titan is loaded before the plugin and the plugin has access to Titan routines and libs.
Because Titan registers plugins during PEW, this means Titan calls the plugin OnShow BEFORE the plugin gets its PEW.

A best practice for Titan plugins is wait until OnShow to set up resources and processing.
Then nicely shut down those resources and processing in OnHide.
This keeps Titan from using resources when the user is not using a plugin.

Using PEW to initialize could lead to confusing behavior and unexpected results.

LDB objects are another source of Titan plugins. 
LDB objects are created by other addons using the LibDataBroker library :
LibStub("LibDataBroker-1.1"):NewDataObject ()
These objects can be created at any point before or after Titan is up and ready.
Titan will wrap each LDB object in a generated Titan plugin so it can be displayed by Titan.
TitanLDB.lua contains more information.

TitanUI is a LDB addon created to be a working example.
--]======]

--[======[ Frames and Frame Scripts : Titan Bars
Here we detour into XML. Titan uses XML only to declare virtual frames used throughout Titan.
Virtual frames can only be declared in XML.
They are frame templates used in the 'inherits' parameter of CreateFrame.
We find creating needed frames in Lua cleaner and less confusing.

TitanTemplate.xml contains the frame definitions used by Titan.
- TitanPanelBarButton : This "is" Titan in the sense that all events are attached to this frame.
- Titan_Bar__Display_Template : The template (Button) for a Titan bar.
- TitanPanelBarButtonHiderTemplate : The template (Button) paired to each full width Titan bar;
	Allows hiding and unhiding the paired Titan Bar.
- TitanPanelTooltip : This is used for plugin tool tips.

TitanBarData in TitanVariables.lua holds creation data for each bar.
Titan_G.bars.CreateBar in Titan.lua creates the full width bars and short bars by looping through TitanBarData.
TitanBarDataVars holds the Titan and user settings for each bar.
An initial setup / install uses TitanBarVarsDefaults.

======= OnClick frame scripts - Titan OnClick default behavior :
-- Right click is to open the Titan menu.

-- Left click is ignored.

======= OnDragStart and OnDragStop frame script :
For moving Short Bars using shift+left mouse button. 

======= OnMouseWheel frame script :
On Short Bars Titan registers to size a Short Bar using the SHIFT+mouse wheel.

======= OnShow frame script :
Not used by Titan bars.

======= OnHide frame script :
Not used by Titan bars.

======= OnEvent frame script :
Titan.lua sets the OnEvent stript for TitanPanelBarButton to redirect events to TitanPanelBarButton:<registered event> 
See local function RegisterForEvents for the list of eventsand their usage.

======= OnEnter frame script :
Used for auto hide feature, full width bars only.
Titan checks if the mouse is over the 'hider' bar and unhides the Titan bar if it is hidden.

======= OnLeave frame script :
Used for auto hide feature, full width bars only.
When the mouse leaves the bar, if auto hide is on, will move the Titan bar and replace it with the 'hider' bar.

--]======]

--[======[ Frames and Frame Scripts : Titan Plugins
TitanTemplate sets the Titan plugin frame scripts.
TitanLDB sets the Titan plugin frame scripts that LDB addons may have.

======= OnClick frame scripts
Default behavior via TitanTemplate:
-- Right click opens the Titan plugin menu.

-- Left click closes any tooltip and any menu.
Then looks for a control frame - frame with name of "TitanPanel" .. plugin_id .. "ControlFrame".
If a control frame exists, show it.
This is used by Volume and Clock to show sliders which are not possible in a menu.

LDB addons: Titan will call its OnClick, if it exists.
Otherwise Titan will call the TitanTemplate OnClick.

======= OnDragStart and OnDragStop frame script :
For moving plugins between bars or to 'end' of right/left side.

======= OnMouseWheel frame script :
Not used by Titan plugins.

======= OnShow frame script :
Titan will call the plugin frame OnShow.

======= OnHide frame script :
Titan will call the plugin frame OnHide.

======= OnEvent frame script :
Titan expects the plugin to register and handle any events it needs.

======= OnEnter frame script :
Used to show the plugin tooltip.
With the addition of 'secret' values in 12.0.0 (Midnight) Titan does not use the Blizzard GameTooltip.
Titan was blamed for 'secret' value access errors within and shortly after instances.

Also used by Titan Hider Bars to show the hidden Titan Bar.

LDB addons: Titan will call its OnEnter, if it exists.
Otherwise Titan will call the TitanTemplate OnEnter.

======= OnLeave frame script :
Used to hide the tooltip.

LDB addons: Titan will call its OnLeave, if it exists.
Otherwise Titan will call the TitanTemplate OnLeave.

======= OnHide frame script :
Used to hide the plugin by removing it from the Titan bar.

======= OnDoubleClick frame script :
If needed the plugin the plugin must set the script itself.
Titan Volume does this.

LDB addons: Titan will call its OnDoubleClick, if it exists.


--]======]

--[======[ Plugin .registry

====== Titan plugins
Plugins are the heart of Titan. They provide the information and features users want to see.
The routine - Titan_G.plugins.RegisterList - starts the plugin registry process.

See TitanBag.lua for a LOT more detail.

====== LDB objects : See TitanLDB.lua for many more details.
The OnEvent script of the LDBToTitan frame processes the PLAYER_LOGIN event.
This starts the process to convert all known LDB objects into Titan plugins.

Note: PLAYER_LOGIN occurs at same time or very close to PLAYER_ENTERING_WORLD.
This event was chosen by the orignal developer.

Each object found calls TitanLDBCreateObject using pcall to protect Titan.

Before Titan is initialized (first PLAYER_ENTERING_WORLD) the LDB object will be added to the plugin list.
As part of the PEW event processing, Titan_G.plugins.RegisterList will be used iteratively on each found LDB object.
Most LDB objects are created on loading by addons. There may be an issue for addons that create many LDB objects on demand.
--]======]

--[======[ Saved Variables
WoW allows saved variables to be 'by account' or 'by character'.
'by account' is a little misleading - it is 'by account' per WoW version.
Retail and Classic Era are distinct and can not reference each other!


See TitanVariables.lua for additional detail.

NOTE: Titan routines have used 1 as true since inception so be careful on 'true checks'. 
As an example
if ShowUsedSlots then 
*should* work fine if ShowUsedSlots is true or 1

====== Where are these saved variables?????
The saved variables can be found here: .../World of Warcraft/_retail_/WTF/Account/<account name>/SavedVariables/Titan.lua
There is a Titan.lua.bak which is the prior save (logout / exit / reload).

NOTE : _retail_ is for Retail WoW. 
Classic and other WoW versions will have different folder names, such as _classic_era_, _beta_, _*ptr_, etc.

The saved variables are specified in the Titan toc :
## SavedVariables: TitanAll, TitanSettings, TitanSkins

This will cause WoW to create a file - Titan.lua - with a table for each saved variable entry.


TitanSettings contains all the plugin saved variables.
Titan uses the single table structure to store the saved variables across characters.
This makes the setup code rather cumbersome and not straight forward - just warning...

It is HIGHLY recommended opening the saved variables file in an 
editor that can handle large files and with code folding features! 

I have 20+ characters on one server. Even though I do not use many addons, my file is nearly 90,000 lines long!
A plugin such as Titan Panel Reputation or Currencies Multi can create 100+ plugins.

Say we want to find a character named Stormblade on Staghelm which you are using for testing.
This would under
TitanSettings = {
	["Players"] = {
		["Stormblade@Staghelm"] = {
			["Panel"] = {
				-- Holds all the Titan level settings for this character
				}
			["Info"] = {
				-- Holds various information for this character, used by Titan and some built-in plugins
				-- example :
				["levelText"] = "80",
				["itemLevelPvp"] = 137.75,
				["class"] = "Demon Hunter",
				["raceName"] = "NightElf",
				["race"] = "Night Elf",
				["played_start"] = 1775660178,
				["factionName"] = "Alliance",
				["level"] = 80,
				["server"] = "Staghelm",
				["played_total"] = 805746,
				["gold_toon"] = 1086716295,
				["itemLevelEquipped"] = 137.75,
				["logout"] = 1775660193,
				["itemLevelAve"] = 137.75,
				["raceId"] = 4,
				["faction"] = "Alliance",
				["logoutStr"] = "2026-04-08 10:56",
				["name"] = "Stormblade",
				["className"] = "DEMONHUNTER",
				["subZoneText"] = "The Bazaar",
				["played_this_level"] = 128790,
				["classId"] = 12,
				["zoneText"] = "Silvermoon City",
				}
			[<plugin>] = {
				-- Holds various information for this character, specific to THIS plugin
				}
			["BarVars"] = {
				-- Holds all the Titan bar settings for this character
				}
			["Plugins"] = {
				-- Each registered plugin saved vars will be here
				-- Below is Location as an example
				["Location"] = {
					["CoordsLoc"] = "Bottom",
					["ShowZoneText"] = 1,
					["NumLabelsSeen"] = 2,
					["ShowRealmText"] = false,
					["ShowIcon"] = 1,
					["ShowCoordsText"] = true,
					["ShowSubZoneText"] = false,
					["CustomLabelText"] = "",
					["CustomLabel3TextShow"] = false,
					["CustomLabelTextShow"] = false,
					["ShowCoordsOnMap"] = true,
					["CustomLabel4Text"] = "",
					["ShowCursorOnMap"] = true,
					["CoordsFormat"] = "(%.d, %.d)",
					["ShowLabelText"] = 1,
					["DisplayOnRightSide"] = false,
					["ShowColoredText"] = 1,
					["UpdateWorldmap"] = false,
					["CustomLabel2Text"] = "",
					["CustomLabel2TextShow"] = false,
					["CoordsLabel"] = true,
					["CustomLabel3Text"] = "",
					["CustomLabel4TextShow"] = false,
				},
			["Adjust"] = {
				-- Holds offsets for frames the user may adjust 
				-- 2026 Jul this list should be empty; all WoW version have Edit Mode so Titan will not auto adjust frames
				}
			["Register"] = {
				-- Exists but empty - used to hold debug data as each plugin and LDB is attempted to be registered. 
				-- Titan > Configuration > Attempts shows some data, including errors.
				}
...
TitanAll = {
["OrderHall"] = true,
["TimerAdjust"] = 1,
["GlobalProfileUse"] = false,
["TimerPEW"] = 4,
["TooltipModiferAlt"] = false,
["TimerLDB"] = 2,
["TimerVehicle"] = 1,
["UseTooltipModifer"] = false,
["GlobalProfileName"] = "<>",
["Silenced"] = false,
["TooltipModiferCtrl"] = false,
["TooltipModiferShift"] = false,
["TimerDualSpec"] = 2,
["Registered"] = false,
}
TitanSkins = {
{
["titan"] = true,
["path"] = "Interface\\AddOns\\Titan\\Artwork\\",
["name"] = "Titan Default",
},
{
["titan"] = true,
["path"] = "Interface\\AddOns\\Titan\\Artwork\\Custom\\AllBlack Skin\\",
["name"] = "AllBlack",
},
...
}
--]======]

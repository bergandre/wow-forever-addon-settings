--[===[ File
This file contains 'recent changes' and notes for Titan Config.
It should be updated for each Titan release!

These are in a seperate file to
1) Increase the chance these strings get updated
2) Decrease the chance of breaking the code :).
--]===]

--- Release notes. Keep structure; most recent on 'top'
local recent_changes = {
   {
      version = "9.3.5",
      when = "2026/10/13",
      topics = {
         {
            topic = "Titan",
            lines = {
               "Change to get first and surname from API.",
            },
         },
         {
            topic = "Bags",
            lines = {
               "Update documentation comments.",
            },
         },
         {
            topic = "Devs",
            lines = {
               "Treat TitanPanelRightClickMenu_* as deprecated!!!",
               "Switch to Titan_Menu or your own custom menu implementation.",
               "Blizzard could remove the UIDropDownMenu functionality at any time.",
            },
         },
      },
   },
   {
      version = "9.3.4",
      when = "2026/10/04",
      topics = {
         {
            topic = "Titan",
            lines = {
               "Cleanup toc files : Classic, Loot.",
            },
         },
         {
            topic = "TitanUI",
            lines = {
               "Fix for keys being duplicated if run multiple times.",
            },
         },
         {
            topic = "Devs",
            lines = {
               "Treat TitanPanelRightClickMenu_* as deprecated!!!",
               "Switch to Titan_Menu or your own custom menu implementation.",
               "Blizzard could remove the UIDropDownMenu functionality at any time.",
            },
         },
      },
   },
   {
      version = "9.3.3",
      when = "2026/10/02",
      topics = {
         {
            topic = "Titan",
            lines = {
               "Delete and Reinstall!!!",
               "Added .controlCustom to .registry; move away from hard-coded frame names for Volume.",
               "Update Titan documentation.",
               "Fix error on delete of Profile.",
            },
         },
         {
            topic = "Repair",
            lines = {
               "Fix for WoW Forever Beta.",
            },
         },
         {
            topic = "UI",
            lines = {
               "New feature - user added slash commands!",
            },
         },
         {
            topic = "Classic folder",
            lines = {
               "Changed toc file; should not show in retail list.",
            },
         },
         {
            topic = "Ammo",
            lines = {
               "Moved to single toc file.",
            },
         },
         {
            topic = "Loot",
            lines = {
               "Moved to single toc file.",
            },
         },
         {
            topic = "Regen",
            lines = {
               "Moved to single toc file.",
            },
         },
         {
            topic = "Volume",
            lines = {
               "Use new .controlCustom to allow plugin named control mixer frame.",
            },
         },
         {
            topic = "Devs",
            lines = {
               "We are moving many Titan only routines and vars to internal structures.",
               "Routines and vars marked as ---API will remain accessible as before.",
               "If your plugin(s) rely on routines or vars NOT marked as ---API please contact us to discuss your needs via Discord or PM.",
            },
         },
         {
            topic = "Devs",
            lines = {
               "Treat TitanPanelRightClickMenu_* as deprecated!!!",
               "Switch to Titan_Menu or your own custom menu implementation.",
               "Blizzard could remove the UIDropDownMenu functionality at any time.",
            },
         },
      },
   },
   {
      version = "9.3.2",
      when = "2026/08/18",
      topics = {
         {
            topic = "Titan",
            lines = {
               "Fix drag and drop.",
               "Fix error on delete of Profile.",
            },
         },
      },
   },
   {
      version = "9.3.1",
      when = "2026/08/08",
      topics = {
         {
            topic = "TitanXP",
            lines = {
               "Restore XP kills to level.",
            },
         },
         {
            topic = "TitanUI",
            lines = {
               "Add lists for key binds and addons.",
            },
         },
      },
   },
   {
      version = "9.3.0",
      when = "2026/07/22",
      topics = {
         {
            topic = "Titan",
            lines = {
               "Remove frame adjust code.",
               "Remove old drop down lib code.",
               "Unused var cleanup.",
               "Ace3: Checkbox - r1399-alpha.",
            },
         },
      },
   },
}

---Format the release notes
local function BuildList()
   local max = 5
   local res = ""
   for idx = 1, #recent_changes do -- A release
      res = res .. "\n"            -- spacer
      local rc = recent_changes[idx]

      if idx <= max then
         res = res
             .. TitanUtils_GetGoldText(rc.version .. " : " .. rc.when .. "\n")

         for tops = 1, #rc.topics do -- Topic of change
            local rct = rc.topics[tops]
            res = res
                .. TitanUtils_GetGreenText(rct.topic .. " : \n")

            for line = 1, #rct.lines do -- Change details
               local rctl = rct.lines[line]
               res = res .. TitanUtils_GetHighlightText(rctl .. " \n")
            end
         end
      end
   end

   return res
end
Titan_G.recent_changes = BuildList()

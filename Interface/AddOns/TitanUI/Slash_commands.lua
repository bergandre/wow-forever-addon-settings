--[[ Key_binds.lua

Add a dump of slash commands to an edit box.

By: The Titan Panel Development Team

--]]

-- ******************************** Constants *******************************

local add_on_id, NS = ... -- folder and Lua table
local _G = _G             --getfenv(0);

-- ******************************** Variables *******************************
local trace = false -- true / false    Make true when debug output is needed.

--=========================== Slash Commands =============================

local keys = {}

local SHIFT = "SHIFT%-"
local CTRL = "CTRL%-"
local ALT = "ALT%-"

local function GetSlashCommands()
   local res = {}

   for name, func in pairs(SlashCmdList) do
      local i = 1
      local slash
      -- Check for SLASH_NAME1, SLASH_NAME2, etc.
      while true do
         slash = _G["SLASH_" .. name .. i]
         if not slash then break end
         --[[
         print("TUI slash get"
            .." "..tostring(slash)..""
            .." "..tostring(name)..""
         )
         --]]
         local entry = { cmd = slash, name = name }
         table.insert(res, entry)
         i = i + 1
      end
   end

   return res
end

function NS.GetSlashCmds()
   local cmds = GetSlashCommands()

   table.sort(cmds, function(a, b)
      if a.cmd ~= b.cmd then
         return a.cmd < b.cmd
      end

      return false -- do not kill the caller
   end)

   local str = ""
   for idx = 1, #cmds do
      str = str
          .. " " .. tostring(cmds[idx].cmd) .. ""
          .. " : " .. tostring(cmds[idx].name) .. ""
          .. "\n"
   end

   local summary = #cmds .. " found."
   --print(summary)

   --return str

   NS.ListBox:Show(str)
end

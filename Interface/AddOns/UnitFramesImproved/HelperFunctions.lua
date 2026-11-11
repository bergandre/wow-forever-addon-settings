-- Additional debug info can be found on http://www.wowwiki.com/Blizzard_DebugTools
-- /framestack [showhidden]
--		showhidden - if "true" then will also display information about hidden frames
-- /eventtrace [command]
-- 		start - enables event capturing to the EventTrace frame
--		stop - disables event capturing
--		number - captures the provided number of events and then stops
--		If no command is given the EventTrace frame visibility is toggled. The first time the frame is displayed, event tracing is automatically started.
-- /dump expression
--		expression can be any valid lua expression that results in a value. So variable names, function calls, frames or tables can all be dumped.

-- Adds message to the chatbox (only visible to the loacl player)
function dout(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg);
end

-- Debug print
function DebugPrint(status, category, level, msg)
  if DLAPI then
    DLAPI.DebugLog("UnitFramesImproved", "%s~%s~%s~%s", tostring(status), tostring(category), tostring(level), tostring(msg))
  else
    dout(msg)
  end
end

function DebugPrintf(...)
  local status, res = pcall(format, ...)
  if status then
    if DLAPI then
      DLAPI.DebugLog("UnitFramesImproved", res)
    else
      dout(res)
    end
  end
end

-- Table Dump Functions -- http://lua-users.org/wiki/TableSerialization
function print_r(t, indent, done)
  done = done or {}
  indent = indent or ''
  local nextIndent -- Storage for next indentation value
  for key, value in pairs(t) do
    if type(value) == "table" and not done[value] then
      nextIndent = nextIndent or
          (indent .. string.rep(' ', string.len(tostring(key)) + 2))
      -- Shortcut conditional allocation
      done[value] = true
      print(indent .. "[" .. tostring(key) .. "] => Table {");
      print(nextIndent .. "{");
      print_r(value, nextIndent .. string.rep(' ', 2), done)
      print(nextIndent .. "}");
    else
      print(indent .. "[" .. tostring(key) .. "] => " .. tostring(value) .. "")
    end
  end
end

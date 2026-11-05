--[===[ File
Contains routines used for tooltip creation and usage.

--]===]

-- Globals

-- Constants


-- Library instances
local _G = getfenv(0);
local InCombatLockdown = _G.InCombatLockdown

--- Set Titan_Debug.titan.tool_tips to output debug
--==========================

---local Helper to add a line of tooltip text to the tooltip.
---@param text string To add
---@param frame table Tooltip frame
--- Append a "\n" to the end if there is not one already there
local function AddTooltipText(text, frame)
	if (text) then
		-- Append a "\n" to the end
		if (string.sub(text, -1, -1) ~= "\n") then
			text = text .. "\n";
		end

		-- See if the string is intended for a double column
		for text1, text2 in string.gmatch(text, "([^\t\n]*)\t?([^\t\n]*)\n") do
			if (text2 ~= "") then
				-- Add as double wide
				frame:AddDoubleLine(text1, text2);
			elseif (text1 ~= "") then
				-- Add single column line
				frame:AddLine(text1);
			else
				-- Assume a blank line
				frame:AddLine("\n");
			end
		end
	else
		-- No text to display
	end
end

---local Helper to set both the parent and the position of Tooltip for the plugin tooltip.
---@param parent table Reference to the frame to attach the tooltip to
---@param anchorPoint string Tooltip anchor location (side or corner) to use
---@param relativeToFrame string name name of the frame, usually the plugin), to attach the tooltip to
---@param relativePoint string Parent anchor location (side or corner) to use
---@param xOffset number X offset
---@param yOffset number Y offset
---@param frame table Tooltip frame
---@param custom boolean If custom / not tooltip frame
local function SetOwnerPosition(parent, anchorPoint, relativeToFrame, relativePoint, xOffset, yOffset, frame, custom)
	-- Changes for WoW 9.1.5 Removed the background template from the Tooltip
	-- Making changes to it difficult and possibly changing the tooltip globally.

	if custom then
		-- do NOT set owner - it clears the contents!
	else
		frame:SetOwner(parent, "ANCHOR_NONE")
	end

	frame:SetPoint(anchorPoint, relativeToFrame, relativePoint, xOffset, yOffset);

	-- Set font size for the tooltip; only on show
	if Titan_G.vars.PanelGet("DisableTooltipFont") then
		-- use UI scale
	else
		--[[
		if TitanTooltipScaleSet < 1 then
			TitanTooltipOrigScale = frame:GetScale();
			TitanTooltipScaleSet = TitanTooltipScaleSet + 1;
		end
		--]]
		frame:SetScale(Titan_G.vars.PanelGet("TooltipFont"));
	end

	local dbg_msg = "_SetOwner _pos"
		.. " '" .. tostring(frame:GetName()) .. "'"
		.. " " .. tostring(frame:IsShown()) .. ""
		.. " @ '" .. tostring(relativeToFrame) .. "'"
		.. " " .. tostring(_G[relativeToFrame]:IsShown()) .. ""
	Titan_Debug.Out('titan', 'tool_tips', dbg_msg)
	dbg_msg = ">>_pos"
		.. " " .. tostring(anchorPoint) .. ""
		.. " " .. tostring(relativePoint) .. ""
		.. " w" .. tostring(format("%0.1f", frame:GetWidth())) .. ""
		.. " h" .. tostring(format("%0.1f", frame:GetHeight())) .. ""
	Titan_Debug.Out('titan', 'tool_tips', dbg_msg)
end

---local Helper to set the screen position of the tooltip frame
---@param self table Plugin frame
---@param id string Plugin id name
---@param frame table Tooltip frame to use
---@param custom? boolean If custom / not tooltip frame
local function PositionTooltip(self, id, frame, custom)
	local is_custom = custom or false
	local button = TitanUtils_GetButton(id)

	if button then
		-- Adjust the Y offset as needed
		local top = self:GetTop()
		local hgt = frame:GetHeight()
		local lft = self:GetLeft()

		local rel_y = top - hgt
		local pt = ""
		local rel_pt = ""
		if rel_y > 0 then
			pt = "TOP";
			rel_pt = "BOTTOM";
		else
			-- too close to bottom of screen
			pt = "BOTTOM";
			rel_pt = "TOP";
		end
		local rel_x = lft + hgt
		if (rel_x < GetScreenWidth()) then
			-- menu will fit
			pt = pt .. "LEFT";
			rel_pt = rel_pt .. "LEFT";
		else
			pt = pt .. "RIGHT";
			rel_pt = rel_pt .. "RIGHT";
		end

		SetOwnerPosition(button, pt, button:GetName(), rel_pt, 0, 0, frame, is_custom)
	end
end

---Determine if the tooltip should be shown
---@param self table Tooltip frame
---@return boolean ok to show tooltip
local function AllowTooltip(self)
	local ok = false
	local dbg_msg = "IsMenuOpen:"
	-- ensure that the 'self' passed is a valid frame reference
	if self:GetName() then
		local menu_mgr = Menu.GetManager()

		local id = self.registry_id
		local controlFrame = TitanUtils_GetControlFrame(id);
		local plugin = _G[self.plugin_frame_str]

		-- Jan 2026 : Place all checks to NOT show tooltip here...
		-- Checks in other places tooltips could show were causing visual oddities.
		dbg_msg = dbg_msg .. "'" .. self:GetName() .. "'"
		-- sanity checks
		if (Titan_G.vars.PanelGet("HideTipsInCombat") and InCombatLockdown()) then
			dbg_msg = dbg_msg .. " HideTipsInCombat"
		elseif (menu_mgr and menu_mgr:IsAnyMenuOpen()) then -- Blizzard_Menu
			dbg_msg = dbg_msg .. " IsAnyMenuOpen"
		elseif (controlFrame and controlFrame:IsVisible()) then -- Titan custom menu widget
			dbg_msg = dbg_msg .. " controlFrame"
		elseif TitanPanelRightClickMenu_IsVisible() then  -- UIDropDownMenu
			dbg_msg = dbg_msg .. " TitanPanelRightClickMenu_IsVisible"
		elseif not Titan_G.vars.PanelGet("ToolTipsShown") then -- user does not want tooltips
			dbg_msg = dbg_msg .. " not ToolTipsShown"
		elseif plugin.isMoving then                       -- this plugin is moving
			dbg_msg = dbg_msg .. " isMoving"
			plugin:Hide()
		elseif TITAN_PANEL_MOVING == 1 then -- another plugin is being moved
			dbg_msg = dbg_msg .. " TITAN_PANEL_MOVING"
		else
			ok = true -- whew, we can actually show!
		end
	else
		dbg_msg = dbg_msg .. " No frame"
		-- Cannot even start
	end

	local mods = false --
	local use_mod = Titan_G.vars.Get("UseTooltipModifer")
	local use_alt = Titan_G.vars.Get("TooltipModiferAlt")
	local use_ctrl = Titan_G.vars.Get("TooltipModiferCtrl")
	local use_shift = Titan_G.vars.Get("TooltipModiferShift")

	if use_mod then
		if (use_alt and IsAltKeyDown())
			or (use_ctrl and IsControlKeyDown())
			or (use_shift and IsShiftKeyDown())
		then
			mods = true
		end
	else
		mods = true
	end

	return (ok and mods)
end

---Set the tooltip of the given Titan plugin.
---@param self table Plugin frame
function Titan_G.tooltip.Setup(self)
	local dbg_msg = "_SetTooltip"
	local ok = false
	local frame = TitanPanelTooltip --GameTooltip
	local id = self.registry.id

	frame.registry_id = id -- for use in other routines
	frame.plugin_frame = self
	frame.plugin_frame_str = self:GetName()

	ok = AllowTooltip(frame)
	if ok then
		local call_ok = nil
		local tmp_txt = ""

		self.tooltipCustomFunction = nil;
		self.titan_tt_func = ""
		self.titan_tt_err = ""

		dbg_msg = dbg_msg .." "..tostring(id)..""
		if (id and Titan_G.plugins.IsRegistered(id)) then
			local plugin = Titan_G.plugins.Get(id)
			-- 2024 Jun Add id and frame name to 'pass' to tooltip routine.
			-- A compromise given that this mechanism is used by nearly all plugins.
			-- Used by Titan auto hide to better determine which bar the 'pin' / icon is on.
			self.plugin_id = id
			self.plugin_frame = TitanUtils_ButtonName(id)

			-- Tooltip method order : 
			-- 1) LDB object OnEnter / OnLeave OVERRIDES!!! This routine will not be called.
			-- 2) tooltipDisplayFrame
			-- 3) tooltipTemplateFunction 
			-- 4) tooltipCustomFunction
			-- 5) tooltipTextFunction
			if (plugin and plugin.tooltipDisplayFrame) then
				-- 2026 Mar : Added from LDB .tooltip to take advantage of Titan processing.
				-- Plugin is expected to handle its frame!
				-- Titan will position and show only!
				-- Plugin must handle any timeout and any other features.

				-- Hide the Titan Tooltip in case it is open.
				frame:Hide()

				dbg_msg = dbg_msg .. " | tooltipDisplayFrame"
					.." '"..tostring(plugin.tooltipDisplayFrame:GetName()).."'"
				PositionTooltip(self, id, plugin.tooltipDisplayFrame, true)

				plugin.tooltipDisplayFrame:Show() -- now show it
			elseif (plugin and plugin.tooltipTemplateFunction) then
				-- 2026 Mar Added to pass a tooltip frame to a plugin as an explicit agreement.
				-- Combines the Titan tooltip and LDB OnTooltipShow
				-- This acts as Blizz GameTooltip so plugin can 'add line' etc.

				-- Hide the Titan Tooltip in case it is open.
				frame:Hide()
				frame:ClearLines() -- Hand off a blank tooltip
				PositionTooltip(self, id, frame)

				-- The plugin is in full control of contents; pass it the tooltip frame to fill
				self.tooltipTemplateFunction = plugin.tooltipTemplateFunction;
				dbg_msg = dbg_msg .. " | tooltipTemplateFunction"
				call_ok, tmp_txt = pcall(self.tooltipTemplateFunction, frame)
				if call_ok then
					-- all is good
					dbg_msg = dbg_msg .. " | ok"
				else
					dbg_msg = dbg_msg .. " | Err: " .. tmp_txt
				end
				frame:Show(); -- now show it
			elseif (plugin and plugin.tooltipCustomFunction) then
				-- Hide the Titan Tooltip in case it is open.
				frame:Hide()
				-- 2026 Jan Switching to a Titan controlled frame made us realize
				-- changing GameTooltip for custom tooltips creates a hybrid mess...

				-- This should be treated as deprecated as of 2026 Mar.
				-- It is left so older plugins will work - but they can error as of Midnight (12.0.0)
				-- Use tooltipTemplateFunction instead!
				local custom_f = GameTooltip
				PositionTooltip(self, id, custom_f);

				-- Fill the tooltip
				self.tooltipCustomFunction = plugin.tooltipCustomFunction;
				dbg_msg = dbg_msg .. " | custom"
				call_ok, tmp_txt = pcall(self.tooltipCustomFunction, self)
				if call_ok then
					-- all is good
					dbg_msg = dbg_msg .. " | ok"
				else
					dbg_msg = dbg_msg .. " | Err: " .. tmp_txt
				end

				custom_f:Show(); -- now show it
			elseif (plugin) then
				-- 2026 Jan No longer require registry.tooltipTitle allowing dev to set their own
				-- From Lingkan dev of Titan Rep Continued
				local tooltipTextFunc = {} ---@type function
				local tt_func = plugin.tooltipTextFunction
				local func_ok = true

				if type(tt_func) == 'string' then
					-- Function MUST be in global namespace
					tooltipTextFunc = _G[tt_func]
					dbg_msg = dbg_msg .. " | string"
				elseif type(tt_func) == 'function' then
					-- Can be global or local to the plugin
					tooltipTextFunc = tt_func
					dbg_msg = dbg_msg .. " | function"
				else
					-- silently leave...
					dbg_msg = dbg_msg .. " | none found"
					func_ok = false
				end

				if func_ok then
					-- Hide the Tooltip while being updated, to avoid race conditions.
					frame:Hide()
					GameTooltip:Hide() -- Also hide in case. Cannot hide completly custom tool tips
					-- Prep the tooltip frame
					PositionTooltip(self, id, frame);
					if plugin.tooltipTitle then
						self.tooltipTitle = plugin.tooltipTitle;
						frame:SetText(self.tooltipTitle,
							HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
					else
						-- assume dev is doing their own thing
					end
					call_ok, tmp_txt = pcall(tooltipTextFunc, self)

					-- Fill the tooltip
					-- Any error will be in the tooltip
					self.tooltipText = tmp_txt
					if (self.tooltipText) then
						AddTooltipText(self.tooltipText, frame)
						dbg_msg = dbg_msg .. " | ok"
					else
						dbg_msg = dbg_msg .. " | No text"
					end

					frame:Show() -- now show it
				end
			else
				-- no recognized method to create tooltip
				dbg_msg = "No recognized tooltip method [.tooltipCustomFunction "
					.."then tooltipTextFunction (with .tooltipTitle, if set)]"
			end
		end
	else
		-- no need to waste cycles
	end

	Titan_Debug.Out('titan', 'tool_tips', dbg_msg)
end

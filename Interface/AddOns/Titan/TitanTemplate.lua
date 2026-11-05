--[===[ File
Contains routines defined in TitanTemplate.xml.

Contains the routines to control a Titan template frame whether Titan bar or plugin.
--]===]

--[===[ TitanPanelTemplate overview
Creates the following frames:
- TitanPanelBarButton : Main Titan frame handling events
- TitanPanelTooltip : Inherits from GameTooltipTemplate

Contains the routines to control a Titan template frame.
These could be:
- A Titan bar (full or short)
- A Titan plugin (built-in, thrid party, or LDB)

The Titan templates are defined in .xml.
There appears to be no other way to make frame templates - virtual="true".
See TitanPanelButtonTemplate.xml also for more detail.

TitanTemplate (Lua and XML) contain the basics for Titan plugin frames.
Titan templates contain elements used by Titan.

A Titan plugin is a frame created using one of the button types in TitanPanelButtonTemplate.xml.
The available plugin types are: ---API
- TitanPanelTextTemplate - * A frame that only displays text ("$parentText")
- TitanPanelIconTemplate - * A frame that only displays an icon ("$parentIcon")
- TitanPanelComboTemplate - * A frame that displays an icon then text ("$parentIcon"  "$parentText")
- TitanOptionsSliderTemplate - A frame that contains a basic vertical slider control. See TitanVolume for an example.

* Templates inherit TitanPanelButtonTemplate for common elements.

Most plugins use the combo template.

TitanPanelButtonTemplate contains:
- a frame to handle a menu invoked by a right mouse click ("$parentRightClickMenu")
- default event handlers for
			<OnLoad>
				Titan_G.plugins.OnLoad(self);
			</OnLoad>
			<OnShow>
				Titan_G.plugins.OnShow(self);
			</OnShow>
			<OnClick>
				Titan_G.plugins.OnClick(self, button);
			</OnClick>
			<OnEnter>
				Titan_G.plugins.OnEnter(self);
			</OnEnter>
			<OnLeave>
				Titan_G.plugins.OnLeave(self);
			</OnLeave>
If these events are overridden then the default routine needs to be included!


NOTE: TitanPanelChildButtonTemplate - Removed 2024 Jun
--]===]

-- Globals

-- Constants
local TITAN_PANEL_LABEL_SEPARATOR = "  "
local TITAN_PANEL_BUTTON_WIDTH_CHANGE_TOLERANCE = 10;
local TITAN_PANEL_BUTTON_TYPE_TEXT = 1;
local TITAN_PANEL_BUTTON_TYPE_ICON = 2;
local TITAN_PANEL_BUTTON_TYPE_COMBO = 3;
local TITAN_PANEL_BUTTON_TYPE_CUSTOM = 4;
local pluginOnEnter = nil;

-- Used for drag and drop, assuming one can only drag one plugin :)
local TITAN_PANEL_MOVE_ADDON = "";
--local TITAN_PANEL_DROPOFF_ADDON = "";
local FROM_BAR_SHORT = ""

-- Library instances
local LibQTip = nil
local _G = getfenv(0);
local InCombatLockdown = _G.InCombatLockdown
local media = LibStub("LibSharedMedia-3.0")

--- Set Titan_Debug.titan.tool_tips to output debug
--==========================

---local Is the given Titan plugin template type text?
---@param id string Plugin id name
---@return boolean IsText
local function IsText(id)
	if (Titan_G.plugins.GetType(id) == TITAN_PANEL_BUTTON_TYPE_TEXT) then
		return true
	else
		return false
	end
end

---local Is the given Titan plugin of type combo?
---@param id string Plugin id name
---@return boolean IsCombo
local function IsCombo(id)
	if (Titan_G.plugins.GetType(id) == TITAN_PANEL_BUTTON_TYPE_COMBO) then
		return true
	else
		return false
	end
end

---Is the given Titan plugin of type icon?
---@param id string Plugin id name
---@return boolean is_icon
local function IsIcon(id)
	local res = false
	if (Titan_G.plugins.GetType(id) == TITAN_PANEL_BUTTON_TYPE_ICON) then
		res = true
	else
		res = false
	end

	return res
end

---local Handle the OnDragStart event of the given Titan plugin.
---@param self table Plugin frame
--- Do nothing if the user has locked plugins or if in combat.
--- Set the .isMoving of the plugin (frame) so other routine can check it.
--- Set TITAN_PANEL_MOVING so any Titan routine will know a 'drag & drop' is in progress.
--- Set TITAN_PANEL_MOVE_ADDON so sanity checks can be done on the 'drop'.
local function TitanPanelButton_OnDragStart(self)
	-- Due to API change in 11.2.0, :ClearAllPoints immediately invalidates the rect...
	-- Need to change order of events between drag start and stop:
	-- - Remove but not Hide() the plugin - seems Hide() triggers OnDragStop without release of mouse button...
	-- - Make ALL 'do not drag' checks BEFORE remove!!
	--
	-- Dropped Ace Dewdrop-2.0 lib support as of 2025 Sep; last updated 2008 Sep
	-- Dropped Ace Tablet-2.0 lib support as of 2025 Sep; last updated 2009 Jan (marked as abandoned)

	if Titan_G.vars.PanelGet("LockButtons") or InCombatLockdown() then
		return -- not requested or not allowed
	else
		-- Proceed
	end

	local frname = self
	local frstr = self:GetName()
	local plugin_id = TitanUtils_GetButtonID(frstr)
	local str = ""
	str = "_OnDragStart start "
		.. " " .. tostring(plugin_id) .. ""
	--		.." from "..tostring(FROM_BAR_SHORT)..""
	Titan_Debug.Out('titan', 'plugin_drag_drop', str)


	-- Tell Titan that a drag & drop is in process
	TITAN_PANEL_MOVING = 1;
	-- Start the drag
	frname:StartMoving();
	frname.isMoving = true;

	-- Close any tooltips and control frames
	Titan_G.control.CloseAllControlFrames();
	TitanPanelRightClickMenu_Close();
	TitanPanelTooltip:Hide();

	-- LibQTip-1.0 support code
	LibQTip = LibStub("LibQTip-1.0", true)
	if LibQTip then
		for key, tip in LibQTip:IterateTooltips() do
			if tip then
				local _, relativeTo = tip:GetPoint()
				if relativeTo and relativeTo:GetName() == frstr then
					tip:Hide()
					break
				end
			end
		end
	end
	-- /LibQTip-1.0 support code

	FROM_BAR_SHORT = Titan_G.plugins.GetWhichBar(plugin_id) -- short name
	str = "_OnDragStart moving"
		.. " " .. tostring(plugin_id) .. ""
		.. " from " .. tostring(FROM_BAR_SHORT) .. ""
	Titan_Debug.Out('titan', 'plugin_drag_drop', str)
	-- Clear the plugin placement so we only move the intended plugin
	Titan_G.bars.RemovePlugin(plugin_id, false)
	frname:Show() -- 'remove' hid the plugin

	-- Hold the plugin id so we can do checks on the drop
	TITAN_PANEL_MOVE_ADDON = plugin_id

	-- Store the OnEnter handler so the tooltip does not show - or other oddities
	pluginOnEnter = self:GetScript("OnEnter")
	self:SetScript("OnEnter", nil)
end

---local Handle the OnDragStop event of the given Titan plugin.
---@param self table Plugin frame
--- Clear the .isMoving of the plugin (frame).
--- Clear TITAN_PANEL_MOVING.
--- Clear TITAN_PANEL_MOVE_ADDON.
local function TitanPanelButton_OnDragStop(self)
	-- The plugin is under the cursor so we MUST place the plugin somewhere!
	-- We cannot just return.
	-- Also means we can no longer swap plugins.
	-- For now, we will drop the plugin on the bar under the cursor;
	-- placing the plugin 'right' if set for that plugin

	local frname = self
	local frstr = self:GetName()
	local plugin_id = TitanUtils_GetButtonID(frstr)

	local str = ""
	str = "_OnDragStop start "
		.. " " .. tostring(plugin_id) .. ""
	Titan_Debug.Out('titan', 'plugin_drag_drop', str)

	if TITAN_PANEL_MOVING == 1 then
		frname:StopMovingOrSizing();
		frname.isMoving = false;
		TITAN_PANEL_MOVING = 0;

		local bar
		local tbar = "" -- bar short name
		local fbar = Titan_G.plugins.GetVar(plugin_id, "ForceBar")

		str = "_OnDragStop "
			.. " " .. tostring(plugin_id) .. ""
		if fbar == nil
			or fbar == false then
			-- Find which bar it was dropped on
			for idx, v in pairs(TitanBarData) do
				bar = idx
				if (bar and _G[bar]:IsMouseOver()) then
					tbar = TitanBarData[bar].name
				end
			end
			if tbar == "" then
				-- not sure what the user did...
				-- Likely released on UI so put back on the bar it came from
				str = str .. " back to"
				tbar = FROM_BAR_SHORT
			else
				str = str .. " onto"
			end
		else
			str = str .. " force to"
			tbar = fbar -- put it back; allows user to shift it
		end

		str = str .. " " .. tostring(tbar) .. ""
		Titan_Debug.Out('titan', 'plugin_drag_drop', str)
		Titan_G.plugins.AddOnBar(tbar, TITAN_PANEL_MOVE_ADDON)

		-- The plugin was added a bar so clean up.
		TITAN_PANEL_MOVE_ADDON = "";
		if pluginOnEnter then
			-- Restore the OnEnter script handler
			self:SetScript("OnEnter", pluginOnEnter)
		else
			-- No OnEnter was found at drag start
		end
		pluginOnEnter = nil;
	end
end

---API Set the color of the tooltip text to normal (white) with the value in green.
---@param text string Label to show
---@param value any Value to show; something tostring() can handle
---@return string str Formatted text and value
--- self.tooltipText = TitanOptionSlider_TooltipText("Addons", Titan_G.plugins.GetVar(TITAN_PERFORMANCE_ID, "NumOfAddons"));
function TitanOptionSlider_TooltipText(text, value)
	return tostring(text) .. " " .. GREEN_FONT_COLOR_CODE .. tostring(value) .. FONT_COLOR_CODE_CLOSE;
end

---Handle the OnLoad event of the requested Titan plugin. Ensure the plugin is set to be registered.
---@param self table Plugin frame
--- This is called from the Titan plugin frame in the OnLoad event - usually as the frame is created in the Titan template.
function Titan_G.plugins.OnLoad(self)
	--[[
--- This is called from the Titan plugin frame in the OnLoad event - usually as the frame is created in the Titan template.
--- This starts the plugin registration process. See TitanUtils for more details on plugin registration.
--- The plugin registration is a two step process because not all addons create Titan plugins in the frame create.
--- The Titan feature of converting LDB addons to Titan plugins is an example.
--- If the plugin needs an OnLoad process it should call this routine after its own. I.E.
--- TitanPanelLootTypeButton_OnLoad(self)
--- Titan_G.plugins.OnLoad(self)
--]]
	Titan_G.plugins.ToRegister(self)
end
TitanPanelButton_OnLoad = Titan_G.plugins.OnLoad ---API

---Handle the OnShow event of the requested Titan plugin.
---@param self table Plugin frame
function Titan_G.plugins.OnShow(self)
	local id = nil;
	-- ensure that the 'self' passed is a valid frame reference
	if self and self:GetName() then
		id = TitanUtils_GetButtonID(self:GetName());
	end
	-- ensure that id is a valid Titan plugin
	if (id) then
		Titan_G.plugins.UpdateButton(id, 1);
	end
end
TitanPanelButton_OnShow = Titan_G.plugins.OnShow ---API

---Handle the OnClick mouse event of the requested Titan plugin.
---@param self table Plugin frame
---@param button string Mouse button clicked
--- Only the left and right mouse buttons are handled by Titan.
--- Called from Titan templates unless overriden by plugin. If overridden the plugin should call this routine.
function Titan_G.plugins.OnClick(self, button)
	local id
	-- ensure that the 'self' passed is a valid frame reference
	if self and self:GetName() then
		id = TitanUtils_GetButtonID(self:GetName())
	end

	if id then
		local controlFrame = TitanUtils_GetControlFrame(id);

		if controlFrame and (button == "LeftButton") then
			local isControlFrameShown;
			if (not controlFrame) then
				isControlFrameShown = false;
			elseif (controlFrame:IsVisible()) then
				isControlFrameShown = false;
			else
				isControlFrameShown = true;
			end

			Titan_G.control.CloseAllControlFrames();
			TitanPanelRightClickMenu_Close();

			if (isControlFrameShown) then
				-- Note: This uses anchor points to place the control frame relative to the plugin on the screen.
				local parent = self:GetName() -- plugin with the control frame
				local point = ""  -- point of the control frame
				local rel_point = "" -- The middle - top or bottom edge - of the plugin to anchor to
				--[[ Mar 2023 : removed reference to Titan bar reference
					Instead use the relative position on the screen to show the control (plugin) frame properly.
					NOTE: If Titan bars need a left click to show a control frame the offset
					will need to be changed to use the cursor position like right click menu!!
				--]]
				local top = self:GetTop()
				local hgt = controlFrame:GetHeight()
				if (top - hgt) > 0 then
					point = "TOP"
					rel_point = "BOTTOM"
				else -- below screen
					point = "BOTTOM"
					rel_point = "TOP"
				end

				controlFrame:ClearAllPoints();
				controlFrame:SetPoint(point .. "LEFT", parent, rel_point, 0, 0) -- default left of plugin

				-- Adjust control frame position if it's off the screen
				local offscreenX = Titan_G.control.GetOffscreen(controlFrame);
				if (offscreenX == -1) then
					-- Off to left of screen which should not happen...
				elseif (offscreenX == 1) then
					-- off to right of screen, flip to right of plugin
					controlFrame:ClearAllPoints();
					controlFrame:SetPoint(point .. "RIGHT", parent, rel_point, 0, 0)
				end

				controlFrame:Show();
			end
		elseif (button == "RightButton") then
			Titan_G.control.CloseAllControlFrames();
			-- Show RightClickMenu anyway
			TitanPanelRightClickMenu_Close();
			TitanPanelRightClickMenu_Toggle(self);
		end

		TitanPanelTooltip:Hide();
	end
end
TitanPanelButton_OnClick = Titan_G.plugins.OnClick ---API

---Handle the OnEnter event of the requested Titan plugin.
---@param self table Plugin frame
--- The cursor has moved over the plugin so show the plugin tooltip if there are no blockers.
function Titan_G.plugins.OnEnter(self)
	local id = nil;
	-- ensure that the 'self' passed is a valid frame reference
	if self and self:GetName() then
		id = TitanUtils_GetButtonID(self:GetName())
	end

	if (id) then
		Titan_G.tooltip.Setup(self)
	end

	-- If tooltip was requested and successful, the tooltip OnUpdate
	-- will be active.
	-- NOTE: !!! The tooltip scripts will check if the mouseis over this
	-- plugin, if so then the tooltip will be kept visible !!!
end
TitanPanelButton_OnEnter = Titan_G.plugins.OnEnter ---API

---Handle the OnLeave event of the requested Titan plugin.
---@param self table Plugin frame
function Titan_G.plugins.OnLeave(self)
	local id = nil;
	-- ensure that the 'self' passed is a valid frame reference
	if self and self:GetName() then
		id = TitanUtils_GetButtonID(self:GetName())
	end

	local time_out = max (Titan_G.vars.PanelGet("TooltipTimeout"), 0.1)
	Titan_G.control.StartCounting(TitanPanelTooltip, time_out)

	-- The cursor has moved away from the plugin.
	-- Notes: 
	-- - The OnUpdate of the tooltip will Hide it.
	-- - Scale set OnShow
	--[[
	if Titan_G.vars.PanelGet("DisableTooltipFont") then
		-- use game font & scale
	else
		-- use Titan font & scale
--		TitanPanelTooltip:SetScale(TitanTooltipOrigScale);
		TitanTooltipScaleSet = 0;
	end
	--]]
end
TitanPanelButton_OnLeave = Titan_G.plugins.OnLeave ---API

-- local routines for Update Button


local format_with_label = { [0] = "" } -- Set format string once
for idx = 1, 4 do
	format_with_label[idx] = "%s%s" .. (TITAN_PANEL_LABEL_SEPARATOR .. "%s%s"):rep(idx - 1)
end
---local Set the width of the given icon Titan plugin - icon only.
---@param id string Plugin id
--- The plugin is expected to tell Titan what routine is to be called in <self>.registry.buttonTextFunction.
--- Note: Titan handles up to 4 label-value pairs. User may customize (override) the plugin labels.
--- The text routine is called in protected mode to ensure the Titan main routines still run.
local function SetButtonText(id)
	local dbg_msg = "ptxt : '" .. tostring(id) .. "'"
	local ok = false

	if (id and Titan_G.plugins.IsRegistered(id)) then
		-- seems valid, registered plugin
		ok = true
	else
		-- The plugin is not registered!
		dbg_msg = dbg_msg .. " | unregistered plugin"
	end

	local pdata = Titan_G.plugins.Get(id) -- get plugin data
	local buttonTextFunction = {} ---@type function

	if pdata then
		local bFunction = pdata.buttonTextFunction
		if type(bFunction) == 'string' then
			-- Function MUST be in global namespace
			buttonTextFunction = _G[bFunction]
			ok = true
		elseif type(bFunction) == 'function' then
			-- Can be global or local to the plugin
			buttonTextFunction = bFunction
			ok = true
		else
			dbg_msg = dbg_msg .. " | invalid function type"
			-- silently ...
		end
	else
		-- silently leve...
		dbg_msg = dbg_msg .. " | invalid plugin data"
	end

	if ok and buttonTextFunction then
		local label1, value1, label2, value2, label3, value3, label4, value4
		local call_ok = false
		local button = TitanUtils_GetButton(id) -- get plugin frame
		local buttonText = {}

		local text = false
		if button then
			buttonText = _G[button:GetName() .. Titan_G.bars.TEXT_STR];
			button:SetScale(Titan_G.vars.PanelGet("Scale"))

			local newfont = media:Fetch("font", Titan_G.vars.PanelGet("FontName"))
			if newfont then
				buttonText:SetFont(newfont, Titan_G.vars.PanelGet("FontSize"))
			end

			-- We'll be paranoid here and call the button text function in protected mode.
			-- In case the function fails it will not take Titan with it...
			call_ok,
			label1, value1, label2, value2, label3, value3, label4, value4 =
				pcall(buttonTextFunction, id)

			if call_ok then
				-- All is good
				text = true
			else
				buttonText:SetText("<?>")
				dbg_msg = dbg_msg .. " | Err '" .. tostring(label1) .. "'"
			end
		else
			dbg_msg = dbg_msg .. " | invalid plugin id"
		end

		--=====================================
		-- Determine the label value pairs : 1 - 4
		-- Each could be custom per user
		--
		-- NumLabelsSeen - used for the config to avoid confusing user
		-- Plugin MUST have been shown at least once.

		-- In the case of first label only (no value), set the button and return.
		--
		-- IF there is a label or value for the 1st then check for more values.
		-- 2025 Nov : Change to check each value (1-4) rather than nest them.
		if text and
			label1 and
			not (label2 or label3 or label4
				or value1 or value2 or value3 or value4) then
			buttonText:SetText(label1)

			Titan_G.plugins.SetVar(id, "NumLabelsSeen", 1)

			dbg_msg = dbg_msg .. " | single label; no value | "
		else
			local show_label = Titan_G.plugins.GetVar(id, "ShowLabelText")
			local values = 0
			if label1 or value1 then
				values = 1
				if show_label then
					if Titan_G.plugins.GetVar(id, "CustomLabelTextShow") then
						-- override the label per the user
						label1 = Titan_G.plugins.GetVar(id, "CustomLabelText")
					else
					end
				else
					label1 = ""
				end
				if label2 or value2 then
					values = 2
					if show_label then
						if Titan_G.plugins.GetVar(id, "CustomLabel2TextShow") then
							-- override the label per the user
							label2 = " " .. Titan_G.plugins.GetVar(id, "CustomLabel2Text")
						else
							label2 = " " .. label2
						end
					else
						label2 = " "
					end
				end
				if label3 or value3 then
					values = 3
					if show_label then
						if Titan_G.plugins.GetVar(id, "CustomLabel3TextShow") then
							-- override the label per the user
							label3 = " " .. Titan_G.plugins.GetVar(id, "CustomLabel3Text")
						else
							label3 = " " .. label3
						end
					else
						label3 = " "
					end
				end
				if label4 or value4 then
					values = 4
					if show_label then
						if Titan_G.plugins.GetVar(id, "CustomLabel43TextShow") then
							-- override the label per the user
							label4 = " " .. Titan_G.plugins.GetVar(id, "CustomLabel4Text")
						else
							label4 = " " .. label4
						end
					else
						label4 = " "
					end
				end
				dbg_msg = dbg_msg .. " | ok | " .. tostring(values)
			else
				-- no label or value
				-- Do nothing, it could be the right action for the plugin
				dbg_msg = dbg_msg .. " | no label or value : " .. tostring(values)
			end

			Titan_G.plugins.SetVar(id, "NumLabelsSeen", values)

			--[==[
			-- values tells which format to use from the array
			buttonText:SetFormattedText(format_with_label[values],
				label1 or "", value1 or "",
				label2 or "", value2 or "",
				label3 or "", value3 or "",
				label4 or "", value4 or ""
			)
			--]==]
			buttonText:SetText("" -- formatting was inserting undesired spaces
				.. (label1 or "") .. (value1 or "")
				.. (label2 or "") .. (value2 or "")
				.. (label3 or "") .. (value3 or "")
				.. (label4 or "") .. (value4 or "")
			)
		end
	else
		-- no valid routine to update the plugin text
		dbg_msg = dbg_msg .. " | no valid routine found"
	end
	Titan_Debug.Out('titan', 'plugin_text', dbg_msg)
end

---local Set the width of the given Titan plugin - text only.
---@param id string Plugin id
---@param setButtonWidth? integer Width in pixels
--- Titan uses a tolerance setting to prevent endless updating of the text width.
local function SetTextButtonWidth(id, setButtonWidth)
	if (id) then
		local button = TitanUtils_GetButton(id)
		if button then
			local text = _G[button:GetName() .. Titan_G.bars.TEXT_STR]
			local bwid = button:GetWidth()
			local twid = text:GetWidth()
			if (setButtonWidth
					or bwid == 0
					or bwid - twid > TITAN_PANEL_BUTTON_WIDTH_CHANGE_TOLERANCE
					or bwid - twid < -TITAN_PANEL_BUTTON_WIDTH_CHANGE_TOLERANCE) then
				button:SetWidth(twid);
				Titan_G.bars.Justify();
			end
		else
			-- no plugin registered, be silent
		end
	else
		-- no plugin received, be silent
	end
end

---local Set the width of the given Titan plugin - icon only.
---@param id string Plugin id
--- Wrap up by (re)drawing the plugins on the Bar.
--- Titan uses a tolerance setting to prevent endless updating of the text width.
local function SetIconButtonWidth(id)
	if (id) then
		local button = TitanUtils_GetButton(id)
		if button and (Titan_G.plugins.Get(id).iconButtonWidth) then
			button:SetWidth(Titan_G.plugins.Get(id).iconButtonWidth);
		else
			-- no plugin registered, be silent
		end
	else
		-- no plugin received, be silent
	end
end

---local Set the width of the given Titan plugin - combo icon & text.
---@param id string Plugin id
---@param setButtonWidth? integer Width in pixels; default to .registry.iconWidth
--- Wrap up by (re)drawing the plugins on the Bar.
--- Titan uses a tolerance setting to prevent endless updating of the text width.
local function SetComboButtonWidth(id, setButtonWidth)
	-- TODO - ensure this routine is proper - need this param?
	-- icon width default to .registry.iconWidth before getting the actual width
	if (id) then
		local button = TitanUtils_GetButton(id)
		if not button then return end -- sanity check

		local text = _G[button:GetName() .. Titan_G.bars.TEXT_STR];
		local icon = _G[button:GetName() .. "Icon"];

		local iwid = icon:GetWidth()
		local twid = text:GetWidth()
		local bwid = button:GetWidth()

		local iconButtonWidth, newButtonWidth;

		-- Get icon button width
		iconButtonWidth = 0;
		if (Titan_G.plugins.Get(id).iconButtonWidth) then
			iconButtonWidth = Titan_G.plugins.Get(id).iconButtonWidth;
		elseif (iwid) then
			iconButtonWidth = iwid
		end

		if (Titan_G.plugins.GetVar(id, "ShowIcon") and (iconButtonWidth ~= 0)) then
			icon:Show();
			text:ClearAllPoints();
			text:SetPoint("LEFT", icon:GetName(), "RIGHT", 2, 1);

			newButtonWidth = twid + iconButtonWidth;
		else
			icon:Hide();
			text:ClearAllPoints();
			text:SetPoint("LEFT", button:GetName(), "LEFT", 0, 1);

			newButtonWidth = twid
		end

		if (setButtonWidth
				or bwid == 0
				or bwid - newButtonWidth > TITAN_PANEL_BUTTON_WIDTH_CHANGE_TOLERANCE
				or bwid - newButtonWidth < -TITAN_PANEL_BUTTON_WIDTH_CHANGE_TOLERANCE)
		then
			button:SetWidth(newButtonWidth);
			Titan_G.bars.Justify();
		end
	end
end

---Update the display of the given Titan plugin.
---@param id string Plugin id
---@param setButtonWidth? integer Width in pixels
--- Use after any change to icon, label, or text (depending on Titan template used)
--- Titan_G.plugins.UpdateButton(ID)
function Titan_G.plugins.UpdateButton(id, setButtonWidth)
	local plugin = Titan_G.plugins.Get(id)
	-- safeguard to avoid errors
	if plugin and Titan_G.plugins.IsRegistered(id) then
		if (IsText(id)) then
			-- Update textButton
			SetButtonText(id);
			SetTextButtonWidth(id, setButtonWidth);
		elseif (IsIcon(id)) then
			-- Update iconButton
			Titan_G.plugins.SetIcon(id, (plugin.iconCoords or nil),
				(plugin.iconR or nil), (plugin.iconG or nil), (plugin.iconB or nil)
			);
			SetIconButtonWidth(id);
		elseif (IsCombo(id)) then
			-- Update comboButton
			SetButtonText(id);
			Titan_G.plugins.SetIcon(id, (plugin.iconCoords or nil),
				(plugin.iconR or nil), (plugin.iconG or nil), (plugin.iconB or nil)
			);
			SetComboButtonWidth(id, setButtonWidth);
		end
	else
		return
	end
end
TitanPanelButton_UpdateButton = Titan_G.plugins.UpdateButton ---API

---Update the tooltip of the given Titan plugin.
---@param self table Plugin frame
function Titan_G.plugins.UpdateTooltip(self)
	if not self then return end
	if (TitanPanelTooltip:IsOwned(self)) then
		local id = TitanUtils_GetButtonID(self:GetName());

		Titan_G.tooltip.Setup(self);
	end
end
TitanPanelButton_UpdateTooltip = Titan_G.plugins.UpdateTooltip ---API

--- Refresh the display of the passed in Titan plugin.
---@param table table | string Either {plugin id, action} OR plugin id
---@param oldarg string? action OR nil
--- Action :
--- 1 = refresh button
--- 2 = refresh tooltip
--- 3 = refresh button and tooltip
function Titan_G.plugins.OnUpdate(table, oldarg)
	--- This is used by some plugins.
	local id, updateType = nil, nil
	-- set the id and updateType
	-- old method
	if table and type(table) == "string" and oldarg then
		id = table
		updateType = oldarg
	end
	-- new method
	if table and type(table) == "table" then
		if table[1] then id = table[1] end
		if table[2] then updateType = table[2] end
	end

	-- id is required
	if id then
		if updateType == TITAN_PANEL_UPDATE_BUTTON
			or updateType == TITAN_PANEL_UPDATE_ALL then
			Titan_G.plugins.UpdateButton(id)
		end

		if (updateType == TITAN_PANEL_UPDATE_TOOLTIP
				or updateType == TITAN_PANEL_UPDATE_ALL)
			and (_G[TitanUtils_ButtonName(id)]:IsMouseOver()) then
--			and MouseIsOver(_G[TitanUtils_ButtonName(id)]) then
			Titan_G.tooltip.Setup(_G[TitanUtils_ButtonName(id)])
		end
	end
end
TitanPanelPluginHandle_OnUpdate = Titan_G.plugins.OnUpdate ---API

---Sets the OnDragStart & OnDragStop scripts of a Titan plugin.
---@param self Button Plugin
function Titan_G.plugins.AddMouseScripts(self)
	-- Ensure the id is not nil
	if self then
		self:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp");
		self:RegisterForDrag("LeftButton")

		-- Set the OnDragStart script
		self:SetScript("OnDragStart", function(self)
			if not IsShiftKeyDown()
				and not IsControlKeyDown()
				and not IsAltKeyDown() then
				TitanPanelButton_OnDragStart(self)
			end
		end)

		-- Set the OnDragStop script
		self:SetScript("OnDragStop", function(self)
			TitanPanelButton_OnDragStop(self)
		end)
	else
		-- nothing to add to ??
	end
end

---Set the icon of the given Titan plugin.
---@param id string Plugin id
---@param iconCoords table? As {left, right, top, bottom}
---@param iconR number? Red (.0. - 1.0)
---@param iconG number? Green (.0. - 1.0)
---@param iconB number? Blue (.0. - 1.0)
--- Using Titan_G.plugins.UpdateButton is preferred unless coords are needed
function Titan_G.plugins.SetIcon(id, iconCoords, iconR, iconG, iconB)
	if (id and Titan_G.plugins.IsRegistered(id)) then
		local button = TitanUtils_GetButton(id)
		if button then
			local icon = _G[button:GetName() .. "Icon"];
			local iconTexture = Titan_G.plugins.Get(id).icon;
			local iconWidth = Titan_G.plugins.Get(id).iconWidth;

			if (iconTexture) and icon then
				icon:SetTexture(iconTexture);
			end
			if (iconWidth) and icon then
				icon:SetWidth(iconWidth);
			end

			-- support for iconCoords, iconR, iconG, iconB attributes
			if iconCoords and icon then
				icon:SetTexCoord(unpack(iconCoords))
			end
			if iconR and iconG and iconB and icon then
				icon:SetVertexColor(iconR, iconG, iconB)
			end
		else
			-- plugin not registered
		end
	end
end
TitanPanelButton_SetButtonIcon = Titan_G.plugins.SetIcon ---API

---Get the type of the given Titan plugin.
--- This assumes that the developer is playing nice and is using the Titan templates as is...
---@param id string Plugin id name
---@return integer type (text-1, icon-2, combo-3 (default))
function Titan_G.plugins.GetType(id)
	-- This assumes that the developer is playing nice and is using the Titan templates as is...
	-- id is required
	local type = 0 -- unknown
	if id then
		local button = TitanUtils_GetButton(id);
		if button then
			local text = _G[button:GetName() .. Titan_G.bars.TEXT_STR];
			local icon = _G[button:GetName() .. "Icon"];

			if (text and icon) then
				type = TITAN_PANEL_BUTTON_TYPE_COMBO;
			elseif (text and not icon) then
				type = TITAN_PANEL_BUTTON_TYPE_TEXT;
			elseif (not text and icon) then
				type = TITAN_PANEL_BUTTON_TYPE_ICON;
			elseif (not text and not icon) then
				type = TITAN_PANEL_BUTTON_TYPE_CUSTOM;
			end
		else
			type = TITAN_PANEL_BUTTON_TYPE_COMBO;
		end
	else
		-- no id...
	end

	return type
end

---Loads the Backdrop for TitanOptionsSliderTemplate with new 9.0 API
---@param self table Control frame
function Titan_G.control.Slider_OnLoad(self)
	self:SetBackdrop({
		bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
		edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true,
		insets = {
			left = 6,
			right = 6,
			top = 3,
			bottom = 3,
		},
		tileSize = 8,
		edgeSize = 8,
	})

	self:EnableMouseWheel(true)
end

-- Set tool tip scripts
-- OnUpdate starts as soon as OnShow is done...
local tt_frame = TitanPanelTooltip

local debug_over = false
local debug_over_new = false
tt_frame:SetScript("OnUpdate", function(self, elapsed)
	-- Keep tooltip open as long as the curser stays over plugin 
	local is_over = self.plugin_frame:IsMouseOver()
	if is_over then
		Titan_G.control.StopCounting(self)
		debug_over_new = true
	else
		local status = Titan_G.control.CheckCounting(self, elapsed)
		if status == "Active" then
			-- counting down
		else
			-- should catch all the edge cases
			self:Hide()
		end
		debug_over = false
	end

	--[[
	if debug_over ~= debug_over_new then -- slow output a little...
		debug_over = debug_over_new
		local dbg_msg = "OnUpdate"
			.. " over: " .. tostring(is_over) .. ""
			.. " timeout: " .. tostring(time_out) .. ""
			.. " isCounting: " .. tostring(self.isCounting) .. ""
			.. " timer: " .. tostring(self.frameTimer) .. ""
		Titan_Debug.Out('titan', 'tool_tips', dbg_msg)
	else
	end
	--]]
end)

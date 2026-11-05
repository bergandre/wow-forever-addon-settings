--[===[ File
Contains various utility routines used by Titan and Plugins for menus (right click)
--]===]

--[===[ Overview
Titan controls menus for its builtin plugins. 
Third party Titan plugins may have Titan control its menu.
LDB plugins are assumed to control their own menus.

The Titan routines abstract the menu creation built into WoW.
The abstractions :
: Insulate 3rd party Titan plugin authors from Blizz or lib changes.
: Allow better maintainance if implementation changes.

Currently Titan 'supports' three menu schemes
1- Abstract of an old drop down lib - L_UIDropDownMenu_* : 2026 July Removed!!!!
2- Abstract of Blizzard UIDropDownMenu routines
3- Abstract of Blizzard_Menu which was introduced in 11.0.0

Having 3 methods evolved over the history of WoW and Titan, not to be dug up :).
1- This method is really for very old third party Titan plugins in Classic Era so they can run unchanged.
Many of these addons run but may not be actively maintained.
This wraps UIDropDownMenu routines to look like the lib routines.

2- This method wraps UIDropDownMenu routines with Titan oriented routines.

3- This method wraps the new Blizzard_Menu general routines to be oriented toward Titan features.
This method is very different from UIDropDownMenu. The two are distinct and do not overlap.
Titan uses the general routines to allow Blizzard_Menu to handle menu show / hide, and placement.
There is less flexability with the tradeoff being a consistent style and behavior.

When a menu is requested, Titan will use the .registry to find the routine to call.
This routine is expected to fill in the menu using one of the methods listed above.

2026 Jan Titan added a .registry on each bar for the new menu scheme to start combining plugin and bar routines,

Titan will use, in order :
1) registry.menuContextFunction  : NEW Jan 2026
2) registry.menuTextFunction  : Feb 2024
3) "TitanPanelRightClickMenu_Prepare" .. id .. "Menu" : Old as Titan :)


Jan 2026 : 
- Created this file by moving menu routines from TitanUtils.
- The UIDropDownMenu was deprecated as of 11.0.0 (Dragonflight) and could be removed from the game code.
- Thankfully the new method, Blizzard_Menu, is present in all versions of WoW.
Titan uses this scheme for its built-in plugins across all WoW versions.

Notes: 
- A Titan plugin being updated after 2026 Jan should switch to the Blizzard_Menu method.

- As of May 2025 Classic Era is the only version using an explicit timer to close menus.
Titan uses a routine only in CE (UIDropDownMenu_StartCounting) to determine which version to use.

- local drop_down_1 = "" -- changes depending on the drop down menu version. Blizzard hard-codes the value...

--]===]

local _G = getfenv(0);
local L = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID, true)
local drop_down_1 = "" -- changes if using Blizz drop down (retail) or lib (Classic)

--====== Set the default drop down menu routines per retail or Classic
drop_down_1 = "DropDownList1" -- Boo!! Per hard-coded Blizz UIDropDownMenu.lua


--====== Right click menu routines - Retail dropdown menu UIDROPDOWNMENU
--[[ In 11.0.0 (The War Within) Blizzard introduced a new menu scheme, Blizzard_Menu.
Titan_Menu wraps this scheme to provide a consistent interface for Titan and its plugins.

Treat TitanPanelRightClickMenu_* as **deprecated** and will be removed in a future WoW release by Blizzard.
Use Titan_Menu.* instead.
--]]

---Titan - Deprecated as of 11.0.0!!! Call the routine to right click menu frame.
---@param root_name string For frame name
function TitanPanelRightClickMenu_CreateFrame(root_name)
	-- There are two places these are created:
	-- 1) Each Titan bar - uses same menu
	-- 2) Each Plugin creation via the .registry
	local f = CreateFrame("Frame", root_name .. Titan_G.bars.MENU_PRE, UIParent, "UIDropDownMenuTemplate")
end

---local Add menu button at the given level.
---@param info table Filled in button to add
---@param level number menu level
local function Add_button(info, level)
	UIDropDownMenu_AddButton(info, level)
end

---API Menu - Get the base frame name of the user selected menu (without level).
---@return string frame_name
function TitanPanelRightClickMenu_GetDropdownFrameBase()
	local res = ""

	res = "DropDownList" -- Boo!! Per hard-coded Blizz UIDropDownMenu.lua

	return res
end

---API Menu - UIDropDown Deprecated as of 11.0.0!!! Get the frame name of the user selected menu.
---@return string frame_name
function TitanPanelRightClickMenu_GetDropdownFrame()
	local res = ""

	res = "DropDownList" .. tostring(UIDROPDOWNMENU_MENU_LEVEL)

	return res
end

---API Menu - UIDropDown Deprecated as of 11.0.0!!! Get the current level of the user selected menu.
---@return number level
function TitanPanelRightClickMenu_GetDropdownLevel()
	--	local res = _G[drop_down_1]
	local res = 1 -- proper typing

	res = UIDROPDOWNMENU_MENU_LEVEL

	return res
end

---API Menu -UIDropDown Deprecated as of 11.0.0!!! Get the current value of the user selected menu.
---@return any Value <button>.value usually a string; could be table to hold needed info
function TitanPanelRightClickMenu_GetDropdMenuValue()
	local res = nil
	res = UIDROPDOWNMENU_MENU_VALUE
	return res
end

---API Menu - UIDropDown Deprecated as of 11.0.0!!! Add given info (button) at the given menu level.
---@param info table Filled in button to add
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddButton(info, level)
	level = level or 1
	if (info) then
		Add_button(info, level)
	end
end

---API Menu - add a toggle Right Side (localized) command at the given level in the form of a button. Titan will properly control the "DisplayOnRightSide"
---@param id string Plugin id
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddToggleRightSide(id, level)
	level = level or 1
	local plugin = Titan_G.plugins.Get(id)
	if plugin and plugin.controlVariables and plugin.controlVariables.DisplayOnRightSide then
		-- copy of TitanPanelRightClickMenu_AddToggleVar adding a remove button
		local info = {};
		info.text = L["TITAN_CLOCK_MENU_DISPLAY_ON_RIGHT_SIDE"];
		info.value = { id, "DisplayOnRightSide" };
		info.func = function()
			local bar = Titan_G.plugins.GetWhichBar(id)
			TitanPanelRightClickMenu_ToggleVar({ id, "DisplayOnRightSide" })
			Titan_G.bars.RemovePlugin(id);
			Titan_G.plugins.AddOnBar(bar, id)
		end
		info.checked = Titan_G.plugins.GetVar(id, "DisplayOnRightSide");
		info.keepShownOnClick = 1;
		Add_button(info, level);
	end
end

---API Menu - add a localized title at the given level in the form of a button.
---@param title string localized title
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddTitle(title, level)
	level = level or 1
	if (title) then
		local info = {};
		info.text = title;
		info.notCheckable = true;
		info.notClickable = true;
		info.isTitle = 1;
		Add_button(info, level);
	end
end

---API Menu - add a toggle variable command at the given level in the form of a button.
---@param text string Localized text to show
---@param value string Internal button name
---@param functionName function | string Function to call on click
---@param level? number menu level
function TitanPanelRightClickMenu_AddCommand(text, value, functionName, level)
	level = level or 1
	local info = {};
	info.notCheckable = true;
	info.text = text;
	info.value = value;
	info.func = function()
		if functionName then
			local callback = functionName

			if type(callback) == 'string' then
				-- Function MUST be in global namespace
				callback = _G[callback]
			elseif type(callback) == 'function' then
				-- Can be global or local to the plugin
			else
				-- silently leave...
			end
			-- Redundant but the given string may not be a function
			if type(callback) == "function" then
				-- No return expected...
				callback(value)
			else
				-- Must be a function - spank developer
			end
		else
			-- Leave, creates an inactive button
		end
	end
	Add_button(info, level);
end

---API Menu - add a line at the given level in the form of an inactive button.
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddSeparator(level)
	level = level or 1

	UIDropDownMenu_AddSeparator(level)
end

---API Menu - add a blank line at the given level in the form of an inactive button.
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddSpacer(level)
	level = level or 1

	UIDropDownMenu_AddSpace(level)
end

---API This will remove the plugin from whichever Titan bar it is on.
---@param id string Plugin id
function TitanPanelRightClickMenu_Hide(id)
	Titan_G.bars.RemovePlugin(id);
end

---API Menu - add a toggle variable command at the given level in the form of a button.
---@param text string Localized text to show
---@param id string Plugin id
---@param var string the saved variable of the plugin to toggle
---@param toggleTable nil ! NOT USED !
---@param level number menu level
function TitanPanelRightClickMenu_AddToggleVar(text, id, var, toggleTable, level)
	local info = {};
	info.text = text;
	info.value = { id, var, toggleTable };
	info.func = function()
		TitanPanelRightClickMenu_ToggleVar({ id, var, toggleTable })
	end
	info.checked = Titan_G.plugins.GetVar(id, var);
	info.keepShownOnClick = 1;
	Add_button(info, level);
end

---API Menu - add a toggle Label (localized) command at the given level in the form of a button. Titan will properly control "ShowIcon"
---@param id string Plugin id
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddToggleIcon(id, level)
	level = level or 1
	local plugin = Titan_G.plugins.Get(id)
	if plugin and plugin.controlVariables and plugin.controlVariables.ShowIcon then
		TitanPanelRightClickMenu_AddToggleVar(L["TITAN_PANEL_MENU_SHOW_ICON"], id, "ShowIcon", nil, level);
	end
end

---API Menu - add a toggle Label (localized) command at the given level in the form of a button. Titan will properly control "ShowLabelText"
---@param id string Plugin id
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddToggleLabelText(id, level)
	level = level or 1
	local plugin = Titan_G.plugins.Get(id)
	if plugin and plugin.controlVariables and plugin.controlVariables.ShowLabelText then
		TitanPanelRightClickMenu_AddToggleVar(L["TITAN_PANEL_MENU_SHOW_LABEL_TEXT"], id, "ShowLabelText", nil, level);
	end
end

---API Menu - add a toggle Colored Text (localized) command at the given level in the form of a button. Titan will properly control "ShowColoredText"
---@param id string Plugin id
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddToggleColoredText(id, level)
	level = level or 1
	local plugin = Titan_G.plugins.Get(id)
	if plugin and plugin.controlVariables and plugin.controlVariables.ShowColoredText then
		TitanPanelRightClickMenu_AddToggleVar(L["TITAN_PANEL_MENU_SHOW_COLORED_TEXT"], id, "ShowColoredText", nil, level);
	end
end

---API Menu - add a Hide (localized) command at the given level in the form of a button. When clicked this will remove the plugin from the Titan bar.
---@param id string Plugin id
---@param level? number menu level or 1
function TitanPanelRightClickMenu_AddHide(id, level)
	level = level or 1
	local info = {};
	info.notCheckable = true;
	info.text = L["TITAN_PANEL_MENU_HIDE"];
	info.value = nil -- value; huh - what should this be?
	info.func = function()
		TitanPanelRightClickMenu_Hide(id)
	end
	Add_button(info, level);
end

---API This will toggle the Titan variable and the update the button.
---@param value table Plugin id and var to toggle
--- Example: {TITAN_XP_ID, "ShowSimpleToLevel"}
function TitanPanelRightClickMenu_ToggleVar(value)
	-- Update 2024 Mar - Removed the 'reverse' check.
	-- Not sure it was ever used or even worked.
	--	local id, var, toggleTable = "", nil, {}
	local id, var = "", ""

	-- table expected else do nothing
	if type(value) ~= "table" then return end

	if value and value[1] then id = value[1] end
	if value and value[2] then var = value[2] end
	--	if value and value[3] then toggleTable = value[3] end

	-- Toggle var
	Titan_G.plugins.ToggleVar(id, var);
	Titan_G.plugins.UpdateButton(id);
	--[=[]]
	if ( TitanPanelRightClickMenu_AllVarNil(id, toggleTable) ) then
		-- Undo if all vars in toggle table nil
		Titan_G.plugins.ToggleVar(id, var);
	else
		-- Otherwise continue and update the button
		Titan_G.plugins.UpdateButton(id, 1);
	end
--]=]
end

---API Set backdrop of the plugin. Used for custom created controls (Clock / Volume) to give a consistent look.
---@param frame table Plugin control frame
function TitanPanelRightClickMenu_SetCustomBackdrop(frame)
	--[[
Blizzard decided to remove direct Backdrop API in 9.0 (Shadowlands)
so inherit the template (XML) and set the values in the code (Lua)

9.5 The tooltip template was removed from the GameTooltip.
--]]

	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileEdge = true,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
		tileSize = 8,
		edgeSize = 8,
	})

	frame:SetBackdropBorderColor(
		TOOLTIP_DEFAULT_COLOR.r,
		TOOLTIP_DEFAULT_COLOR.g,
		TOOLTIP_DEFAULT_COLOR.b);
	frame:SetBackdropColor(
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
		, 1);
end

---API Menu - add the set of options per the plugin registry control variables.
---@param id string Plugin id
---@param level? number If not present, default to 1 (top)
function TitanPanelRightClickMenu_AddControlVars(id, level)
	level = level or 1 -- assume top menu
	TitanPanelRightClickMenu_AddSeparator(level)

	TitanPanelRightClickMenu_AddToggleIcon(id, level)
	TitanPanelRightClickMenu_AddToggleLabelText(id, level)
	TitanPanelRightClickMenu_AddToggleColoredText(id, level)
	TitanPanelRightClickMenu_AddToggleRightSide(id, level)

	TitanPanelRightClickMenu_AddSpacer();
	TitanPanelRightClickMenu_AddCommand(L["TITAN_PANEL_MENU_HIDE"], id, Titan_G.constants.MENU_FUNC_HIDE);
end

--====== Right click menu routines for Titan Panel bars and plugins

local function CloseAnyMenu()
	-- UIDropDownMenu from Blizzard
	if (_G["DropDownList1"] and _G["DropDownList1"]:IsVisible()) then
		_G["DropDownList1"]:Hide()
	else
		-- not open
	end

	-- Titan wrapped UIDropDownMenu
	if _G[drop_down_1] and _G[drop_down_1]:IsVisible() then
		_G[drop_down_1]:Hide()
	else
		-- not open
	end

	-- Newer Blizzard menu scheme
	local menu_mgr = Menu.GetManager()
	if (menu_mgr and menu_mgr:IsAnyMenuOpen()) then -- Blizzard_Menu
		menu_mgr:CloseMenus();
	else
		-- not open
	end
end

---Close the right click menu of any plugin, if it was open. Only one can be open at a time.
function Titan_Menu.CloseMenus()
	CloseAnyMenu()
end

local function PlaceMenu(self, menu)
	-- Mar 2023 : Rewritten to place menu relative to the passed in frame (button)
	-- Under the cover the menu is built as DropDownList1
	local frame = self:GetName()
	local menu_height = menu:GetHeight()
	local menu_width = menu:GetWidth()

	-- Adjust the Y offset as needed
	local ftop = _G[frame]:GetTop()
	local rel_y = ftop - menu_height
	if rel_y > 0 then
		menu.point = "TOP";
		menu.relativePoint = "BOTTOM";
	else
		-- too close to bottom of screen
		menu.point = "BOTTOM";
		menu.relativePoint = "TOP";
	end

	-- Adjust the X offset as needed
	local x_offset = 0
	local left = 0
	local flft = _G[frame]:GetLeft()
	local effscale = UIParent:GetEffectiveScale()
	if TitanBarData[frame] then
		-- on a Titan bar so use cursor for the 'left'
		left = GetCursorPosition() -- get x; ignore y
		left = left / effscale
		-- correct for beginning of Titan bar
		left = left - flft
	else
		-- a plugin
		left = flft
	end
	local rel_x = left + menu_width
	if (rel_x < GetScreenWidth()) then
		-- menu will fit
		menu.point = menu.point .. "LEFT";
		menu.relativePoint = menu.relativePoint .. "LEFT";

		if TitanBarData[frame] then
			x_offset = left
		else
			-- a plugin
			x_offset = 0
		end
	else
		-- Menu would go off right side of the screen
		menu.point = menu.point .. "RIGHT";
		menu.relativePoint = menu.relativePoint .. "RIGHT";

		if TitanBarData[frame] then
			-- correct is on Titan bar (bottom, far right)
			-- flip calc since we flipped the anchor to right
			x_offset = GetScreenWidth() - left
		else
			-- a plugin
			x_offset = 0
		end
	end
	--[[
print("RCM"
.." "..tostring(frame)..""
.." "..tostring(format("%0.1f", menu_height))..""
.." "..tostring(format("%0.1f", menu_width))..""
.." "..tostring(format("%0.1f", _G[frame]:GetLeft()))..""
.." "..tostring(menu.point)..""
.." "..tostring(menu.relativePoint)..""
.." "..tostring(format("%0.1f", left))..""
)
--]]
	ToggleDropDownMenu(1, nil, menu, frame, x_offset, 0, nil, self);
end

---local Prepare the plugin right click menu using the function given by the plugin OR Titan bar.
---@param self table Titan Bar or Plugin frame
---@param menu table Frame to use as the menu
--- Set Titan_Debug.titan.menu to output the error to Chat.
local function TitanRightClickMenu_OnLoad(self, menu)
	local id = ""
	local err = ""
	local context_menu = false

	if self.registry then
		id = self.registry.id -- is a plugin
	else
		id = "Bar"      -- is a Titan bar
	end

	if id == "" then
		err = "Could not display menu. "
			.. "Unknown Titan ID for "
			.. "'" .. (self:GetName() or "?") .. "'. "
	else
		--		local frame = Titan_G.plugins.Get(id) -- get plugin frame
		local frame = self.registry
		local prepareFunction -- function to call

		if frame and frame.menuContextFunction then
			prepareFunction = frame.menuContextFunction -- Blizzard_Menu 2026 Jan
			context_menu = true
		elseif frame and frame.menuTextFunction then
			prepareFunction = frame.menuTextFunction -- Newer method 2024 Feb
		else
			-- Older method used when Titan was created
			prepareFunction = "TitanPanelRightClickMenu_Prepare" .. id .. "Menu"
			--
		end
		if type(prepareFunction) == 'string' then
			-- Function MUST be in global namespace
			-- Becomes nil if not found
			prepareFunction = _G[prepareFunction]
		elseif type(prepareFunction) == 'function' then
			-- Can be global or local to the plugin
		else
			-- Invalid type, do not even try...
			prepareFunction = nil
		end
		if prepareFunction then
			if context_menu then
				-- using newer context menu for this plugin
				Titan_Menu.AddContextMenu(self, prepareFunction)
			else
				-- deprecated, may be removed in future
				UIDropDownMenu_Initialize(menu, prepareFunction, "MENU")
				PlaceMenu(self, menu)
			end
		else
			err = "Could not display menu. "
				.. "No function for '" .. tostring(id) .. "' "
				.. "[" .. tostring(type(prepareFunction)) .. "] "
				.. "[" .. tostring(prepareFunction) .. "] "
				.. ". "
		end
	end

	if err == "" then
		-- all is good
	else
		Titan_Debug.Out('titan', 'menu', "Error: " .. err)
	end
end

---Call the routine to build the plugin or bar menu then place it properly.
---@param self table Plugin frame
function TitanPanelRightClickMenu_Toggle(self)
--	local frame = self:GetName()
	local menu = _G[self:GetName() .. Titan_G.bars.MENU_PRE]

	-- Create menu based on the frame's routine for right click menu
	TitanRightClickMenu_OnLoad(self, menu)
end

---Determine if a right click menu is shown. There can only be one.
---@return boolean IsVisible
function TitanPanelRightClickMenu_IsVisible()
	local res = false
	if _G[drop_down_1] and _G[drop_down_1]:IsVisible() then
		res = true
	else
		res = false
	end
	return res
end

---Close the right click menu if shown. There can only be one.
function TitanPanelRightClickMenu_Close()
	CloseAnyMenu()
end

--[=====[ New menu scheme being used Jan 2026
Blizzard introduced a new menu scheme in 11.0.0 (July 2024) coded in Blizzard_Menu.
The menu scheme is so different we use a new namespace, Titan_Menu, for menu routines.
Titan_Menu wraps the common menu actions relieving the dev of some grunt work;
it also allows a consistent look and feel across Titan menus.

First: Blizzard_Menu works quite different than UIDropDownMenu.
The 'info' objects no longer exist, replaced by 'element descriptions' or menu widgets.

UIDropDownMenu iterated over the code to create and show the menu.
Blizzard_Menu iterates over the objects - not code.
Blizzard_Menu expects a set of nested objects (sort of the old info) to be created.
One major impact is - level and info.value disappear!
Check level and info.value to determine which portion of the menu to display is eliminated.

Now a 'root description' / menu is created to act as the new 'level 1' or main menu.
The routine to create the new menu widgets is passed to the menu create.
The output is expected to be a nested set of tables describing the menu.

Nesting of submenus are created by attaching a child widget to an already created widget.
Much as child frames are created with a parent. This acts as the old info.hasArrow.

Second: The scheme using UIDropDownMenu was deprecated and could be removed in the future.
Titan needs to keep new and old schemes working side by side for now.
Thankfully, the two menu schemes work side by side BUT look different.

Third: Blizzard_Menu is intended for options using a frame with full blown menu widgets
such as dropdowns, toggles, sliders, and more. It is used for Blizzard options, character creation, and more.

We decided to KISS (Keep It Simple, Stupid) when using Blizzard_Menu.
We use a small number of routines designed to use menu default settings. There are very few options to tweak.
There is no need to create frames for each bar and plugin. Blizzard_Menu handles frame (re)use.
Blizzard_Menu also handles positioning, showing, and hiding of the menu and its submenus.

Fourth: Titan_Menu wraps the parts of Blizzard_Menu Titan uses.
Titan_Menu should protect Titan plugin devs when Blizzard changes the internal menu implementation.
Titan provides routines in Titan_Menu to relieve the dev from some grunt work.

=== Implementation notes
The routines used as base for Titan menus are:
- MenuUtil.CreateContextMenu -- root of the menu; old UIDropDownMenu_Initialize
- MenuUtil.CreateButton -- old info.text; info.func
- MenuUtil.CreateCheckbox -- old info.text; info.checked; info.func
- MenuUtil.CreateRadio -- old info.text; info.checked; info.func
- owner:SetEnabled -- old info.disabled
These handle over 90% of Titan and plugin needs.
Many of these routines allow passing of functions. Titan makes these these distinct :
 such as AddSelector and AddSelectorCommand.
 This allows most calls to be simple but allows the more complex setup when the plugin needs more control.

A new Titan registry attribute, .menuContextFunction, was added to the .registry for plugins to use.
It was created to explicitly state the plugin routine used to create the menu widgets.

When asked to create a menu, Titan will use the first method found.
In order these are :
1) registry.menuContextFunction  : NEW Jan 2026
2) registry.menuTextFunction  : Feb 2024
3) "TitanPanelRightClickMenu_Prepare" .. id .. "Menu" : Old as Titan :)

On right click, Titan will, in order :
1) Create the context menu
2) Add a menu title at top using .registry.id
3) Call the plugin to fill it as before - using protected call, placing error in the menu
4) Add the plugin designated control vars + right side + Hide on bottom of menu
The top and bottom of the menu are common so Titan adds:
- a title 
- any defined control variables
- a Hide command
for consistent style and relieve the dev a bit.

In both schemes, menu widgets are added in the order the code runs.

The old create menu is left in TitanBag for comparison. As a quick example:
=== OLD
	info = {};
	info.text = L["TITAN_BAG_MENU_OPEN_BAGS"]
	info.func = function()
		Titan_G.plugins.ToggleVar(TITAN_BAG_ID, "OpenBags")
	end
	info.checked = Titan_G.plugins.GetVar(TITAN_BAG_ID, "OpenBags");
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
== NEW
	Titan_Menu.AddSelector(root, TITAN_BAG_ID, L["TITAN_BAG_MENU_OPEN_BAGS"], "OpenBags")
Where root is the context menu; the locale string (L) will be placed inline at the main menu.
===

Only atomic elements / widgets can easily be added to the context menu.
Such as command buttons (info.func) or radio / checkbox (info.checked and info.func).
Title, spacer, and divider are available.
Using code, widgets can be enhanced and interact but a complex widget is not possible.

It seems you can create frames and add new templates and widgets but additional code and knowledge will be needed :).
If you need complex widgets such as dropdown selector or slider you may need to create a fully fleshed frame.
The TitanVolume slider frame to control volume levels is an example of a complex widget.

--]=====]

--[=====[ Wrapper implementation notes
Wrapper notes:
- The wrappers will 'update Titan button' where it makes sense, relieving the dev from including it 'all over'.
- The parameter 'owner' used below is a 'menu description' in the new terms.
-- Most Blizzard_Menu 'create' routines must have an owner to attach the widget to.
-- Most Blizzard_Menu 'create' routines return the resulting widget.

- Blizzard_Menu create routines pass 'is selected' and 'set selected' as functions.
-- The wrappers use this method and extends the method to other needed routines.
- When a single selector is created, Titan uses a checkbox.
- When multiple selectors are created, Titan uses radio buttons and a divider (line) at top.

--]=====]

--[=====[ Implementation notes and lessons
- Once the menu 'generator' is called, the  menu is active. 
-- All set up and clean up must be done before generating the menu!
- No nesting of context menus.
- If a scroll bar is needed, it must be added at that level. The setting does not apply to children menus!
- CreateContextMenu will take other parameters (as ...) which are passed to GeneratorFunction.
-- A handy feature but not used in Titan.
--]=====]

--== menu helpers
local nop = function(obj) end

---local Helper Add a simple header for a list
---@param owner table Menu widget object
---@param label string Label of the selector
---@param color table Color object
---@return table elementDescription
local function GenHeader(owner, label, color)
	if color == nil then
		color = GRAY_FONT_COLOR
	end
	local elementDescription =
		owner:CreateTitle(label, color)

	elementDescription:AddInitializer(function(frame, description, menu)
		local fontFile, height, flags = frame.fontString:GetFont()
		--[[
		print("Hdr"
	.." "..tostring(fontFile)..""
	.." "..tostring(height)..""
	.." "..tostring(flags)..""
	)
	--]]
	end
	)

	-- in case we can and want need to modify in future...
	return elementDescription
end

---local Add a button that, when pressed runs a command passing any given parameters
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the  selector
---@param function_name function
---@param ... any
---@return table elementDescription
local function GenCommand(owner, id, label, function_name, ...)
	--    local callback = function_name
	local params = ...

	local elementDescription =
		owner:CreateButton(label, -- was info.text
			function()      -- was info.func
				function_name(params)
			end,
			id
		)
	-- in case we can and want need to modify in future...
	return elementDescription
	--[[
    if function_name then
        if type(callback) == 'string' then
            -- Function MUST be in global namespace
            callback = _G[callback]
        elseif type(callback) == 'function' then
            -- Can be global or local to the plugin
        else
            -- silently leave...
        end
        -- Redundant but the given string may not be a function
        if type(callback) == "function" then
            -- No return expected...
            callback(id)
        else
            -- Must be a function - spank developer
            -- Leave, create an inactive button
            callback = function() end
        end
    else
        -- Leave, create an inactive button
        callback = function() end
    end
--]]
end

---local Helper Add a simple radio
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the selector
---@param opt string Plugin option to read / change
---@return table elementDescription
local function GenRadio(owner, id, label, opt)
	local elementDescription =
		owner:CreateRadio(label, -- was info.text
			function()     -- isSelected was info.checked
				return Titan_G.plugins.GetVar(id, opt)
			end,
			function() -- SetSelected which was info.func
				local val = not Titan_G.plugins.GetVar(id, opt)
				Titan_G.plugins.SetVar(id, opt, val)
				Titan_G.plugins.UpdateButton(id);
			end
		)
	-- in case we can and want need to modify in future...
	return elementDescription
end

---local Helper Add a simple checkbox
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the selector
---@param opt string Plugin option to read / change
---@return table elementDescription
local function GenCheckbox(owner, id, label, opt)
	local elementDescription =
		owner:CreateCheckbox(label, -- was info.text
			function()        -- isSelected was info.checked
				return Titan_G.plugins.GetVar(id, opt)
			end,
			function() -- SetSelected which was info.func
				local val = not Titan_G.plugins.GetVar(id, opt)
				Titan_G.plugins.SetVar(id, opt, val)
				Titan_G.plugins.UpdateButton(id);
			end
		)
	-- in case we can and want need to modify in future...
	return elementDescription
end

---local Helper to Create a simple selector (radio) off the owner and call the function
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the selector
---@param opt string Plugin option to read / change
---@param sel_func function
---@param ... any
---@return table elementDescription
local function GenSelectorCommand(owner, id, label, opt, sel_func, ...)
	local params = ...

	local elementDescription =
		owner:CreateRadio(label, -- was info.text
			function()     -- isSelected was info.checked
				return Titan_G.plugins.GetVar(id, opt)
			end,
			function() -- SetSelected which was info.func
				local val = not Titan_G.plugins.GetVar(id, opt)
				Titan_G.plugins.SetVar(id, opt, val)
				-- Once the opt is set run the command
				if sel_func == nil then
					-- nothing requested
				else
					sel_func(params)
				end
				-- Then update...
				Titan_G.plugins.UpdateButton(id);
			end
		)
	-- in case we can and want need to modify in future...
	return elementDescription
end

---local Add title to owner
---@param owner table Menu widget object
---@param label string Label of the selector
---@return table elementDescription
local function GenTitle(owner, label)
	local elementDescription = owner:CreateTitle(label)
	return elementDescription
end

---local Add the desired control vars to the owner; this expected to end the menu!
---@param owner table Menu widget object
---@param id string Plugin ID
---@param add_hide boolean
local function GenControlVars(owner, id, add_hide)
	owner:CreateDivider()

	local plugin = Titan_G.plugins.Get(id)

	if plugin and plugin.controlVariables and plugin.controlVariables.ShowIcon then
		GenCheckbox(owner, id, L["TITAN_PANEL_MENU_SHOW_ICON"], "ShowIcon")
	end
	if plugin and plugin.controlVariables and plugin.controlVariables.ShowLabelText then
		GenCheckbox(owner, id, L["TITAN_PANEL_MENU_SHOW_LABEL_TEXT"], "ShowLabelText")
	end
	if plugin and plugin.controlVariables and plugin.controlVariables.ShowRegularText then --(LDB data sources only atm)
		GenCheckbox(owner, id, L["TITAN_PANEL_MENU_SHOW_PLUGIN_TEXT"], "ShowRegularText")
	end
	if plugin and plugin.controlVariables and plugin.controlVariables.ShowColoredText then
		GenCheckbox(owner, id, L["TITAN_PANEL_MENU_SHOW_COLORED_TEXT"], "ShowColoredText")
	end

	owner:CreateCheckbox(L["TITAN_CLOCK_MENU_DISPLAY_ON_RIGHT_SIDE"],
		function() -- isSelected
			return Titan_G.plugins.GetVar(id, "DisplayOnRightSide")
		end,
		function() -- SetSelected
			local bar = Titan_G.plugins.GetWhichBar(id)
			TitanPanelRightClickMenu_ToggleVar({ id, "DisplayOnRightSide" })
			Titan_G.bars.RemovePlugin(id);
			Titan_G.plugins.AddOnBar(bar, id)
		end
	)

	if add_hide then
		Titan_Menu.AddSpacer(owner)

		GenCommand(owner, id, L["TITAN_PANEL_MENU_HIDE"], TitanPanelRightClickMenu_Hide, id)
	else
		-- not requested
	end
end

local function MarkFromList(id, opt, list)
	for idx = 1, #list do
		local list_opt = list[idx][2]

		if list_opt == opt then
			Titan_G.plugins.SetVar(id, list_opt, true);
		else
			Titan_G.plugins.SetVar(id, list_opt, false);
		end
	end
end
--== end menu helpers

---API Add divider line
---@param owner table Menu widget object
---@return table elementDescription
function Titan_Menu.AddDivider(owner)
	local elementDescription = owner:CreateDivider()
	return elementDescription
end

---API Add spacer (blank) line
---@param owner table Menu widget object
---@return table elementDescription
function Titan_Menu.AddSpacer(owner)
	local elementDescription = owner:CreateSpacer()
	return elementDescription
end

---API Add header text
---@param owner table Menu widget object
---@param label string Label of the selector
---@param color? table Color object, if nil defaults to gray
---@return table elementDescription
function Titan_Menu.AddText(owner, label, color)
	local elementDescription = GenHeader(owner, label, color)

	return elementDescription
end

---API Set Enabled attribute on widget
---@param owner table Menu widget object
---@param enabled boolean
function Titan_Menu.SetAtribEnabled(owner, enabled)
	owner:SetEnabled(enabled) -- .isEnabled
end

---API Add scroll if menu is over given height in pixels
---@param owner table Menu widget object
---@param height number Pixels
function Titan_Menu.SetScroll(owner, height)
	owner:SetScrollMode(height) -- .isEnabled opts_plugins:SetScrollMode(scroll_hgt)
end

---API Add a simple button to menu
---@param owner table Menu widget object
---@param label string Label of the selector
---@return table elementDescription
function Titan_Menu.AddButton(owner, label)
	local elementDescription = owner:CreateButton(label)
	return elementDescription
end

---API Add simple selector
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the selector
---@param opt string Plugin option to read / change
---@return table elementDescription
function Titan_Menu.AddSelector(owner, id, label, opt)
	local elementDescription = GenCheckbox(owner, id, label, opt)
	return elementDescription
end

---API Add simple selector passing custom functions for isSelected and setSelected
---@param owner table Menu widget object
---@param label string Label of the selector
---@param isSelected function
---@param setSelected function
---@param data table Pass to functions as is
---@return table elementDescription
function Titan_Menu.AddSelectorGeneric(owner, label, isSelected, setSelected, data)
	local elementDescription =
		owner:CreateCheckbox(label, -- was info.text
			isSelected,
			setSelected,
			data -- passed to both functions as table
		)
	-- in case we can and want need to modify in future...
	return elementDescription
end

---API Add N selectors using N options (only one true)
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string? For Title, if desired
---@param list table Localized label - plugin option pair table
---User selected option will be set to true, all others false.
---Divider then optional label.
function Titan_Menu.AddSelectorExclusiveList(owner, id, label, list)
	Titan_Menu.AddDivider(owner)

	if label == nil then
		-- no title wanted
	else
		GenHeader(owner, label, GRAY_FONT_COLOR)
	end

	-- Whip through list of label - option (vars)
	for idx = 1, #list do
		local optlabel = list[idx][1]
		local opt = list[idx][2]
		owner:CreateRadio(
			optlabel,
			function() -- isSelected
				return Titan_G.plugins.GetVar(id, opt)
			end,
			function() -- SetSelected
				MarkFromList(id, opt, list)
				Titan_G.plugins.UpdateButton(id);
			end
		)
	end
end

---API Add N selectors values using 1 option; optional function called after selection
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string? For Title, if desired
---@param opt string Plugin option to read / change
---@param list table Localized label - Option value pair table
---@param sel_func? function
---@param ... any
---User selected option will be set to option value then optiona function will be called.
---Divider then optional label.
function Titan_Menu.AddSelectorList(owner, id, label, opt, list, sel_func, ...)
	local params = ...

	Titan_Menu.AddDivider(owner)

	if label == nil then
		-- no title wanted
	else
		GenHeader(owner, label, GRAY_FONT_COLOR)
	end

	-- Whip through list of label - option (vars)
	for idx = 1, #list do
		local optlabel = list[idx][1]
		local optvalue = list[idx][2]
		owner:CreateRadio(
			optlabel,
			function() -- isSelected
				return (Titan_G.plugins.GetVar(id, opt) == optvalue)
			end,
			function() -- SetSelected
				Titan_G.plugins.SetVar(id, opt, optvalue)
				-- Once the opt is set run the command
				if sel_func == nil then
					-- nothing requested
				else
					sel_func(params)
				end
				Titan_G.plugins.UpdateButton(id);
			end
		)
	end
end

---API Add a button to run a command passing any given parameters
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the  selector
---@param function_name function
---@return table elementDescription
function Titan_Menu.AddCommand(owner, id, label, function_name, ...)
	local params = ...
	local elementDescription = GenCommand(owner, id, label, function_name, params)
	return elementDescription
end

---Add the control vars; this is expected to end the menu!
---@param owner table Menu widget object
---@param id string Plugin ID
---Control vars are set in plugin registry.controlVariables.
function Titan_Menu.AddControlVars(owner, id)
	GenControlVars(owner, id, false)
end

---API Add simple selector then call the function before updating plugin.
---@param owner table Menu widget object
---@param id string Plugin ID
---@param label string Label of the selector
---@param opt string Plugin option to read / change
---@param function_name function
---@param ... any
---@return table elementDescription
function Titan_Menu.AddSelectorCommand(owner, id, label, opt, function_name, ...)
	local elementDescription = GenSelectorCommand(owner, id, label, opt, function_name, ...)
	return elementDescription
end

---Titan ONLY!! Create Root menu description to attach menu widgets to; called by Titan right click handler!
---@param owner table Plugin object / table
---@param gen_function function Used to add descriptions / widgets
---@return table Root Root description / widget
function Titan_Menu.AddContextMenu(owner, gen_function, ...)
	local params = ...

	local function gen_menu(plugin_frame, rootDescription, params_gen)
		local root = rootDescription

		-- Add a tile and divider to the menu
		local id = ""
		if plugin_frame.registry and plugin_frame.registry.menuText then
			id = plugin_frame.registry.menuText
		else
			id = "??"
		end
		GenTitle(root, id)
		Titan_Menu.AddDivider(root)

		-- Attach widgets or show error!
		local succ, val = pcall(gen_function, plugin_frame, root, params)
		if succ then
			-- all good
		else
			GenHeader(root, id .. " !! " .. val, RED_FONT_COLOR)
		end

		if plugin_frame and plugin_frame.registry.category == Titan_G.categories.TitanBar then
			-- Titan bar; do not show the control vars atm
		else
			-- Add the control variables + right side + Hide
			GenControlVars(root, plugin_frame.registry.id, true)
		end
	end

	-- This does return a menu object but we choose to let Blizz handle opening through closing.
	return MenuUtil.CreateContextMenu(owner, gen_menu, params)

	-- CreateContextMenu will take other parameters (as ...) which are passed to GeneratorFunction.
	-- A handy feature but not used in Titan.
end

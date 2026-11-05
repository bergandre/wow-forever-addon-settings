---@diagnostic disable: duplicate-set-field
--[[ Slash.lua

Provide user added slash commands.

By: The Titan Panel Development Team

--]]

-- ******************************** Constants *******************************

local add_on_id, NS = ... -- folder and Lua table
local _G = _G             --getfenv(0);

local artwork_path = "Interface\\AddOns\\" .. add_on_id .. "\\Artwork\\"
local TITLE = "Titan UI"
local edit_on_frame = {}
local VERSION = C_AddOns.GetAddOnMetadata(add_on_id, "Version")

local GREY_COLOR = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 }
local WHITE_COLOR = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }

local edit_h = 12 * 5
local offset_h = 15 -- from R / L sides

-- ******************************** Textures and icons *******************************
--[[
https://www.flaticon.com/
https://thenounproject.com/
https://www.magnific.com/

https://www.shareicon.net/search?kwd=24x24 -- search 24x24
--]]
local delete_icon = artwork_path .. "delete"
local clean_icon = artwork_path .. "clean"
local clear_icon = artwork_path .. "clear-broom"

-- ******************************** Variables *******************************
local trace = false -- true / false    Make true when debug output is needed.

-- MUST match the XML elements!!!
local edit_frame_name = "UISlashEditFrame"

local edit_frame = {}
local container = {} -- hold scroll elements

local row_name = "TitanUIRowTemplate"
local ScrollBox = {}
local ScrollBar = {}
local ScrollChild = {}
local ScrollView = {}
local DataProvider = {}

-- Create the tooltip frame to reuse, it requires a name, not nil
local tooltip = CreateFrame("GameTooltip", "TUITooltip", UIParent, "GameTooltipTemplate")

--TitanUI_User_Slash = nil -- saved vars
local user_slash_def = {
	{ show_on_menu = true, command = "reload",           notes = "Reload WoW UI" },
	{ show_on_menu = true, command = "titanpanel reset", notes = "Reset to defaults" },
	{ show_on_menu = true, command = "lua",              notes = "Typically WoWLua addon" },
	{ show_on_menu = true, command = "fstack",           notes = "Show frame stack" },
	{ show_on_menu = true, command = "eventtrace",       notes = "Show Trace events" },
}
local user_slash = {}

local function CleanText(s)
	local res = ""

	res = s:match('^%s*(.*)')         -- strip white space from left
	res = string.match(res, "^(.-)%s*$") -- string trailing white space

	res = res:match '^%/*(.*)'        -- strip any slash
	--res = string.gsub(res, "^%/", "") -- strip any slash
	return res
end

local function NewCmd(cmd_text)
	return {
		command = cmd_text,
		show_on_menu = true,
		notes = "New command",
	}
end

local function SortNodes(a, b)
	if a and a.command
		and b and b.command then
		return a.command < b.command
	else
		return false
	end
end

---Add a row to be displayed; keep in sync with saved vars!
---@param element table
local function RowInsert(element)
	-- Need to update both; DataProvider creates a copy on init

	DataProvider:Insert(element)           -- add to display
	table.insert(TitanUI_User_Slash, element) -- add to saved vars

	-- Using the same sort **should** keep these in sync...
	-- The DataProvider initializer uses SortNodes
	table.sort(TitanUI_User_Slash, SortNodes)
end

---Delete a row from display; keep in sync with saved vars!
---@param element any
local function RowRemove(element)
	-- Need to update both; DataProvider creates a copy on init

	local ed_idx = DataProvider:FindIndex(element) -- find it

	DataProvider:Remove(element)                -- remove from display
	table.remove(TitanUI_User_Slash, ed_idx)    -- remove from saved vars
end

---Is the command currently active
---@param cmd string
---@return boolean
local function IsSlashCmd(cmd)
	local first = string.match(cmd, "%w+")

	-- Ensure command starts with a slash
	if first:sub(1, 1) ~= "/" then
		first = "/" .. first
	end

	-- Search global table SLASH_* for a matching command
	for id, val in pairs(_G) do
		if id:sub(1, 5) == "SLASH" and val == first then
			return true
		end
	end
	return false
end

---Is this a run command
---@param cmd string
---@return boolean
local function IsRunCmd(cmd)
	local first = string.match(cmd, "%w+")
	if first == "run" then
		return true
	else
		return false
	end
end

---Color the tag for the user
---@param cmd string
---@return string
local function SetTag(cmd)
	local res = ""
	if IsRunCmd(cmd) then
		res = artwork_path .. "tag_yellow"
	elseif IsSlashCmd(cmd) then
		res = artwork_path .. "tag_green"
	else
		res = artwork_path .. "tag_red"
	end

	return res
end

---Attach a tooltip to the frame. Use .tui_tt_title / .tui_tt_text / .tui_tt_func on frame.
---@param tt_frame any Attach here
local function AttachTooltip(tt_frame)
	-- Create the items used here
	tt_frame.tui_tt_title = "?"
	tt_frame.tui_tt_text = "Not set, spank the Dev!!!"
	tt_frame.tui_tt_func = nil -- placeholder to set title and text

	-- On Enter: Show tooltip with text and a texture
	tt_frame:SetScript("OnEnter", function(self)
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
		tooltip:ClearLines()

		if type(tt_frame.tui_tt_func) == 'function' then
			pcall(tt_frame.tui_tt_func) -- expected to set title and text
		else
			-- not set, ignore
		end
		if tt_frame.tui_tt_title == "" or tt_frame.tui_tt_title == nil then
		else
			tooltip:SetText(tt_frame.tui_tt_title,
				WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b, WHITE_COLOR.a)
		end

		tooltip:AddLine(tt_frame.tui_tt_text)
		tooltip:Show()
	end);

	-- On Leave: Hide tooltip
	tt_frame:SetScript("OnLeave", function(self)
		tooltip:Hide()
	end)
end

---Attach an icon / texture to the frame.
---@param frame any Attach here
local function AttachIcon(frame, icon_path)
	local a_icon = frame:CreateTexture(nil, "ARTWORK")
	a_icon:SetAllPoints(frame)
	a_icon:SetTexture(artwork_path .. icon_path)
end

---Attach text edit scripts to the edit box.
---@param editBox table Attach here
local function AttachEditScripts(parent, editBox, hold_text)
	editBox:SetAutoFocus(false) -- Prevents automatic focus on creation
	editBox:SetMultiLine(true)
	editBox:SetIndentedWordWrap(false)
	editBox:SetMaxLetters(255)
	editBox:SetAllPoints(parent) -- Anchors to all 4 sides of the parent

	-- Optional: Adjust text insets for better padding within the border
	--	editBox:SetTextInsets(10, 10, 10, 10)

	-- Set initial placeholder and grey color
	editBox:SetText(hold_text)
	editBox:SetTextColor(GREY_COLOR.r, GREY_COLOR.g, GREY_COLOR.b, GREY_COLOR.a)
	editBox:SetFontObject("ChatFontSmall")

	-- Script: When user clicks into the box
	editBox:SetScript("OnEditFocusGained", function(self)
		-- If the text is the placeholder, clear it and set to white
		if self:GetText() == hold_text then
			self:SetText("")
			self:SetTextColor(WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b, WHITE_COLOR.a)
		end
	end)

	-- Helper function to get the real value (ignores placeholder)
	function editBox:SetRealText(new_text)
		-- If the box is empty, restore placeholder and grey color
		if new_text == "" or new_text == nil then
			self:SetText(hold_text)
			self:SetTextColor(GREY_COLOR.r, GREY_COLOR.g, GREY_COLOR.b, GREY_COLOR.a)
		else
			self:SetText(new_text)
		end
	end

	function editBox:GetRealText()
		local text = self:GetText()
		if text == hold_text then
			return ""
		end
		return text
	end

	-- Script: When user clicks out of the box
	editBox:SetScript("OnEditFocusLost", function(self)
		-- If the box is empty, restore placeholder and grey color
		if self:GetText() == "" or self:GetText() == nil then
			self:SetRealText("")
		end
	end)
end

local function CreateMainFrame(name, parent)
	local eframe = CreateFrame("Frame", name, parent, "BasicFrameTemplateWithInset")
	tinsert(UISpecialFrames, name) -- allows ESC to close the frame
	eframe:SetFrameStrata("DIALOG")
	eframe:SetSize(800, 400)
	eframe:SetPoint("CENTER")
	eframe:SetMovable(true)
	eframe:SetResizable(true)
	eframe:RegisterForDrag("LeftButton")
	eframe:EnableMouse(true)
	eframe:SetClampedToScreen(true)
	eframe:SetScript("OnMouseDown", function(frame, button)
		if button == "LeftButton" then
			frame:StartMoving()
		end
	end)
	eframe:SetScript("OnMouseUp", eframe.StopMovingOrSizing)
	eframe:Hide()

	eframe.TitleText:SetText(add_on_id .. " : Edit Slash Commands")

	return eframe
end

---Attach the Add button
---@param parent table
---@param edit_box table
---@param rel_to table
---@return table
local function CreateAddButton(parent, edit_box, rel_to)
	-- UIPanelButtonTemplate
	local add_cmd = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	add_cmd:SetSize(22, 22)
	add_cmd:SetPoint("TOPLEFT", rel_to, "TOPRIGHT", 10, 0)

	AttachIcon(add_cmd, "plus_green")
	AttachTooltip(add_cmd)

	add_cmd.tui_tt_title = "Edit Slash"
	add_cmd.tui_tt_text = "Add command to menu list."

	add_cmd:SetScript("OnClick", function(self, button)
		local text = edit_box:GetRealText()

		text = CleanText(text)
		local new_text = NewCmd(text)
		RowInsert(new_text)
		edit_box:SetRealText("") -- clear for next one
	end)
	return add_cmd
end

---Attach the Clear button
---@param parent table
---@param edit_box table
---@param rel_to table
---@return table
local function CreateCleanButton(parent, edit_box, rel_to)
	-- UIPanelButtonTemplate
	local add_cmd = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	add_cmd:SetSize(22, 22)
	add_cmd:SetPoint("TOPLEFT", rel_to, "TOPRIGHT", 10, 0)
	local a_icon = add_cmd:CreateTexture(nil, "ARTWORK")
	a_icon:SetAllPoints(add_cmd)
	a_icon:SetTexture(artwork_path .. "clear_broom")

	AttachTooltip(add_cmd)
	add_cmd.tui_tt_title = "" --"Edit Slash"
	add_cmd.tui_tt_text = "Clear command input."

	add_cmd:SetScript("OnClick", function(self, button)
		edit_box:SetRealText("")
	end)

	return add_cmd
end

local function CreateAddCommandEditBox(parent)
	-- Define the placeholder and colors
	local PLACEHOLDER_TEXT = "No slash - Add command here..."

	-- Create the EditBox
	local editMax = CreateFrame("ScrollFrame", nil, parent, "InputScrollFrameTemplate")
	editMax:SetSize(350, edit_h)
	editMax:SetPoint("TOPLEFT", parent, "TOPLEFT", offset_h, -35) -- below title and border and inset
	local editBox = editMax.EditBox                            --from InputScrollFrameTemplate
	AttachEditScripts(editMax, editBox, PLACEHOLDER_TEXT)

	local add_cmd = CreateAddButton(editMax, editBox, editMax)
	local clr_cmd = CreateCleanButton(editMax, editBox, add_cmd)

	editBox:Show()

	return editMax
end

local function CreateLegend(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(300, 24)
	holder:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", offset_h, -10)


	local g_tag = CreateFrame("Frame", nil, holder)
	g_tag:SetSize(16, 16)
	g_tag:SetPoint("LEFT", holder, "LEFT", 10, 0)
	local g_tex = g_tag:CreateTexture(nil, "ARTWORK")
	g_tex:SetAllPoints()
	g_tex:SetTexture(artwork_path .. "tag_green")
	local g_lab = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	g_lab:SetPoint("LEFT", g_tag, "RIGHT", 5, 0)
	g_lab:SetText("Registered")

	local r_tag = CreateFrame("Frame", nil, holder)
	r_tag:SetSize(16, 16)
	r_tag:SetPoint("LEFT", g_lab, "RIGHT", 10, 0)
	local r_tex = r_tag:CreateTexture(nil, "ARTWORK")
	r_tex:SetAllPoints()
	r_tex:SetTexture(artwork_path .. "tag_red")
	local r_lab = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	r_lab:SetPoint("LEFT", r_tag, "RIGHT", 5, 0)
	r_lab:SetText("NOT Registered")

	local y_tag = CreateFrame("Frame", nil, holder)
	y_tag:SetSize(16, 16)
	y_tag:SetPoint("LEFT", r_lab, "RIGHT", 10, 0)
	local y_tex = y_tag:CreateTexture(nil, "ARTWORK")
	y_tex:SetAllPoints()
	y_tex:SetTexture(artwork_path .. "tag_yellow")
	local y_lab = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	y_lab:SetPoint("LEFT", y_tag, "RIGHT", 5, 0)
	y_lab:SetText("Is /run command")


	holder:Show()
	return holder
end

function NS:CreateSlashEdit()
	if trace then
		NS.Debug(add_on_id, "Create DialogBoxFrame"
		--			.. " '" .. tostring(add_on_frame_name) .. "'"
		)
	end

	-- Show the frame
	edit_frame:Show()
end

local function AddUpdate(button, elementData)
	-- Give user some feedback for command and notes edit boxes
	-- save_black = no pending edits
	-- save_disk  = pending edits, user has changed text
	button.SaveIcon:SetNormalTexture(artwork_path .. "save_black")
	-- Start save button disabled, save some cpu cycles
	button.SaveIcon:Disable()

	-- Make command changable
	button.Command:SetScript("OnTextChanged", function(self, userModified)
		-- userModified is true if the change was caused by user input
		if userModified and self:HasFocus() then
			local currentText = self:GetText()

			button.SaveIcon:Enable()
			button.SaveIcon:SetNormalTexture(artwork_path .. "save_disk")
		end
	end)

	-- Make notes changable
	button.Notes:SetScript("OnTextChanged", function(self, userModified)
		-- userModified is true if the change was caused by user input
		if userModified and self:HasFocus() then
			local currentText = self:GetText()

			button.SaveIcon:Enable()
			button.SaveIcon:SetNormalTexture(artwork_path .. "save_disk")
		end
	end)

	-- Enable save / update to stick
	button.SaveIcon:SetScript("OnClick", function(self, mouse_button)
		-- need to get index of data element...
		local ed_idx = DataProvider:FindIndex(elementData) -- find it
		--[[
		print("TUI"
			.. " bc" .. tostring(button.Command:GetText()) .. ""
			.. " ec" .. tostring(elementData.command) .. ""
			.. " bn" .. tostring(button.Notes:GetText()) .. ""
			.. " en" .. tostring(elementData.notes) .. ""
		)
		--]]
		-- Grab updated text - do not care which changed, update both
		local new_elem = {}
		new_elem.command = button.Command:GetText()
		new_elem.notes = button.Notes:GetText()
		new_elem.show_on_menu = elementData.show_on_menu

		-- update the truth
		TitanUI_User_Slash[ed_idx].command = new_elem.command
		TitanUI_User_Slash[ed_idx].notes = new_elem.notes
		TitanUI_User_Slash[ed_idx].show_on_menu = new_elem.show_on_menu

		table.sort(TitanUI_User_Slash, SortNodes) -- keep in sync
		--TitanDumpTable(TitanUI_User_Slash)

		-- Update display frame
		-- no re-sort so... force one
		DataProvider:Remove(elementData)
		DataProvider:Insert(new_elem)

		button.SaveIcon:SetNormalTexture(artwork_path .. "save_black")
		button.SaveIcon:Disable()
	end)
end

local function SendSlash(slash)
	--[[
	print("TUI send:"
	.." "..tostring(slash)..""
	)
	--]]
	DEFAULT_CHAT_FRAME.editBox:SetText(slash)
	ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
end

---Format and fill each row as it is added
---@param button any
---@param elementData any
local function Initializer(button, elementData)
	-- button is the instance of the frame template
	-- elementData is the row table inserted into the DataProvider

	--[[ A bare XML frame template could have been used but :
	- all widgets (buttons, fontstrings, ) would have to be explicitly created here
	- all data explicit on frame
	- all positioning and style set here
	so we created an XML frame template
	- most of the non changing attributes are set

	In the XML
	- Use parentKey = <name> to declare a widget Lua can access here
	- Reference a name using relativeKey="$parent.<name>
	In Lua (here)
	- Reference parentKey using button.<name>

	Notes:
	- When creating a texture in XML, there seems to be an issue referencing the
	texture name. Trying several combinations, we where not successful.
	So the textures are created in Lua.
--]]

	--local edit_bg_name = bname .. "Background"
	--local edit_text_name = bname .. "Text"
	--local edit_cmd_name = elementData.Command
	local edit_cmd_name = button.Command
	local edit_notes_name = button.Notes
	local edit_onmenu_name = button.OnMenu
	local edit_clear_name = button.ClearIcon
	local edit_tag_name = button.CommandTag

	-- Prevents automatic focus on creation; by default edit box sets to true
	-- Allows ESC to close the window
	button.Command:SetAutoFocus(false)
	button.Notes:SetAutoFocus(false)
	-- Set the row data
	edit_cmd_name:SetText(elementData.command)
	edit_notes_name:SetText(elementData.notes)
	edit_onmenu_name:SetChecked(elementData.show_on_menu)
	edit_onmenu_name:SetScript("OnClick", function()
		elementData.show_on_menu = edit_onmenu_name:GetChecked()
	end)
	AttachTooltip(edit_onmenu_name)
	edit_onmenu_name.tui_tt_func = function()
		edit_onmenu_name.tui_tt_title = "" --no title
		if elementData.show_on_menu then
			edit_onmenu_name.tui_tt_text = "Will appear on menu."
		else
			edit_onmenu_name.tui_tt_text = "Will not appear on menu."
		end
	end

	-- Add ability to update / save command and notes
	AddUpdate(button, elementData)

	-- Add delete row
	edit_clear_name:SetScript("OnClick", function()
		RowRemove(elementData)
	end)

	-- Inform user if tag exists in SLASH_
	-- A bare Button seems to work best, just need to use SetNormalTexture (plus)
	button.CommandTag:SetNormalTexture(SetTag(elementData.command))

	button.RunIcon:SetScript("OnClick", function()
		local cmd = "/" .. elementData.command
		SendSlash(cmd)
	end)
end

function NS.SlashInit()
	if _G[edit_frame_name] then
		return -- if already created
	end

	if trace then
		NS.Debug(add_on_id, "Create frames"
			.. " '" .. tostring(edit_frame_name) .. "'"
		)
	end

	if TitanUI_User_Slash == nil then
		TitanUI_User_Slash = user_slash_def
	end
	-- makes local
	user_slash = TitanUI_User_Slash
	-- Start with a sorted list.
	table.sort(TitanUI_User_Slash, SortNodes)

	-- Create a frame to hold the edit box

	edit_frame = CreateMainFrame(edit_frame_name, UIParent)

	local add_cmd = CreateAddCommandEditBox(edit_frame)

	local legend = CreateLegend(add_cmd)

	-- Frame to hold scroll widgets
	container = CreateFrame("Frame", "UIEditContainer", edit_frame)
	container:SetPoint("TOPLEFT", legend, "BOTTOMLEFT", 0, 0)
	container:SetPoint("BOTTOMRIGHT", -offset_h, 10)
	container:SetScript("OnShow",
		function()
			if trace then
				NS.Debug(add_on_id, "Edit OnShow enter"
					.. " '" .. tostring(#user_slash) .. "'"
				)
			end
		end)
	container:Show()

	-- Hold rows of data
	ScrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
	ScrollBox:SetPoint("TOPLEFT", 0, 0)
	ScrollBox:SetPoint("BOTTOMRIGHT", 0, 0)
	ScrollBox:Show()

	-- The scroll bar
	ScrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
	ScrollBar:SetPoint("TOPRIGHT", ScrollBox, "TOPRIGHT", 0, 0)
	ScrollBar:SetPoint("BOTTOMRIGHT", ScrollBox, "BOTTOMRIGHT", 0, 0)
	ScrollBar:Show()

	-- Act on the rows of data
	ScrollView = CreateScrollBoxListLinearView()
	ScrollUtil.InitScrollBoxListWithScrollBar(ScrollBox, ScrollBar, ScrollView)

	-- Create the data provider
	DataProvider = CreateDataProvider()

	ScrollView:SetElementExtent(25) -- Set height of each row
	ScrollView:SetElementInitializer(row_name, Initializer)
	--ScrollView:SetPadding(16, 0, 0, 0, 0);

	DataProvider = CreateDataProvider(TitanUI_User_Slash)
	DataProvider:SetSortComparator(SortNodes) -- sort on insert / remove

	ScrollView:SetDataProvider(DataProvider)
	--ScrollBox:SetPanExtent(100) -- need??
end

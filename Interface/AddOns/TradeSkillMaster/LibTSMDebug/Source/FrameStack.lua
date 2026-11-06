-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

---@diagnostic disable: invisible

local LibTSMDebug = select(2, ...).LibTSMDebug
local FrameStack = LibTSMDebug:InitInternal("FrameStack")
local SlashCommands = LibTSMDebug:From("LibTSMApp"):Include("Service.SlashCommands")
local UIElements = LibTSMDebug:From("LibTSMUI"):Include("UIElements")
local WidgetsDebug = LibTSMDebug:From("LibTSMUI"):Include("Util.WidgetsDebug")
local ScriptWrapper = LibTSMDebug:From("LibTSMWoW"):Include("API.ScriptWrapper")
local Theme = LibTSMDebug:From("LibTSMService"):Include("UI.Theme")
local Math = LibTSMDebug:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMDebug:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMDebug:From("LibTSMUtil"):Include("Lua.Vararg")
local private = {
	tooltip = nil,
	selection = {
		altDown = nil,
		index = 1,
		numFrames = 0,
	},
	lastUpdate = nil,
	framesByStrata = { ---@type table<FrameStrata,Frame[]>
		WORLD = {},
		BACKGROUND = {},
		LOW = {},
		MEDIUM = {},
		HIGH = {},
		DIALOG = {},
		FULLSCREEN = {},
		FULLSCREEN_DIALOG = {},
		TOOLTIP = {},
	},
	baseFrameCache = {},
}
local STRATA_ORDER = {"TOOLTIP", "FULLSCREEN_DIALOG", "FULLSCREEN", "DIALOG", "HIGH", "MEDIUM", "LOW", "BACKGROUND", "WORLD"} ---@type FrameStrata[]
local ELEMENT_ATTR_KEYS = {
	"_hScrollbar",
	"_vScrollbar",
	"_hScrollFrame",
	"_hContent",
	"_vScrollFrame",
	"_header",
	"_frame",
	"_rowElements",
	"_background",
	"_borderOverlay",
	"_backgroundRectangle",
	"_borderRectangle",
	"_backgroundTexture",
}
local COLOR_KEYS = {
	GROUP_ONE = true,
	GROUP_TWO = true,
	GROUP_THREE = true,
	GROUP_FOUR = true,
	GROUP_FIVE = true,
	FULL_WHITE = true,
	BLIZZARD_YELLOW = true,
	BLIZZARD_GM = true,
}
local FONT_KEYS = {
	BODY_BODY1 = true,
	BODY_BODY1_MEDIUM = true,
	BODY_BODY3_MEDIUM = true,
	ITEM_BODY1 = true,
	ITEM_BODY2 = true,
}
local ELEMENT_STYLE_KEYS = {
	"_texture",
	"_backgroundColor",
	"_font",
	"_size",
	"_style",
}
local UPDATE_INTERVAL = 0.5



-- ============================================================================
-- Module Loading
-- ============================================================================

FrameStack:OnModuleLoad(function()
	SlashCommands.RegisterDebug("fstack", private.Toggle)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Toggle()
	if not private.tooltip then
		private.tooltip = CreateFrame("GameTooltip", "TSMFrameStackTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
		local highlightFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
		private.tooltip.highlightFrame = highlightFrame
		highlightFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
		highlightFrame:SetBackdropColor(1, 0, 0, 0.3)
		private.tooltip:Hide()
		ScriptWrapper.Set(private.tooltip, "OnUpdate", private.OnUpdate)
	end
	if private.tooltip:IsVisible() then
		private.tooltip:Hide()
		private.tooltip.highlightFrame:Hide()
	else
		private.lastUpdate = 0
		private.selection.altDown = nil
		private.selection.index = 1
		private.selection.numFrames = 0
		private.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		private.tooltip:SetPoint("TOPLEFT", 0, 0)
		private.tooltip:AddLine("Loading...")
		private.tooltip:Show()
		private.tooltip.highlightFrame:Show()
	end
end

function private.OnUpdate(self)
	if LibTSMDebug.GetTime() - private.lastUpdate < UPDATE_INTERVAL then
		return
	end
	private.lastUpdate = LibTSMDebug.GetTime()

	local numFrames = 0
	for _, strata in ipairs(STRATA_ORDER) do
		for _, strataFrame in ipairs(private.framesByStrata[strata]) do
			local name = private.GetFrameName(strataFrame)
			if not strmatch(name, "innerBorderFrame") then
				numFrames = numFrames + 1
			end
		end
	end

	private.UpdateSelection(numFrames)

	for _, strata in ipairs(STRATA_ORDER) do
		wipe(private.framesByStrata[strata])
	end
	wipe(private.baseFrameCache)

	local frame = EnumerateFrames()
	while frame do
		if frame ~= self.highlightFrame and not frame:IsForbidden() and frame:IsVisible() and private.IsTSMFrame(frame) and MouseIsOver(frame) then
			tinsert(private.framesByStrata[frame:GetFrameStrata()], frame)
			for _, region in Vararg.Iterator(frame:GetRegions()) do
				if private.IsNonFrameRegion(region) and not region:IsForbidden() and region:IsVisible() and MouseIsOver(region) and WidgetsDebug.GetOwner(region:GetName()) then
					tinsert(private.framesByStrata[frame:GetFrameStrata()], region)
				end
			end
		end
		frame = EnumerateFrames(frame)
	end

	self:ClearLines()
	self:AddDoubleLine("TSM Frame Stack", format("%0.2f, %0.2f", GetCursorPosition()))
	local currentIndex = 1
	local topFrame = nil
	for _, strata in ipairs(STRATA_ORDER) do
		if #private.framesByStrata[strata] > 0 then
			sort(private.framesByStrata[strata], private.FrameLevelSortFunction)
			self:AddLine(strata, 0.6, 0.6, 1)
			for _, strataFrame in ipairs(private.framesByStrata[strata]) do
				local isNonFrameRegion = private.IsNonFrameRegion(strataFrame)
				local level = (isNonFrameRegion and strataFrame:GetParent() or strataFrame):GetFrameLevel()
				local width = strataFrame:GetWidth()
				local height = strataFrame:GetHeight()
				local mouseEnabled = not isNonFrameRegion and strataFrame:IsMouseEnabled()
				local name = private.GetFrameName(strataFrame)
				local isIndexedFrame = false
				if not strmatch(name, "innerBorderFrame") then
					if not topFrame and currentIndex == private.selection.index then
						topFrame = strataFrame
						isIndexedFrame = true
					end
					currentIndex = currentIndex + 1
				end
				local text = format("  <%d%s> %s (%d, %d)", level, isNonFrameRegion and "+" or "", name, Math.Round(width), Math.Round(height))
				if isIndexedFrame then
					self:AddLine(text, 0.9, 0.9, 0.5)
					local element = UIElements.GetByFrame(strataFrame)
					if element then
						self:AddLine(format("    __class = %s", tostring(element.__class)), 0.7, 0.7, 0.7)
						for _, k in ipairs(ELEMENT_STYLE_KEYS) do
							local v = element[k]
							if v ~= nil then
								local vStr = private.GetStyleValueStr(v)
								if vStr then
									self:AddLine(format("    %s = %s", tostring(k), vStr), 0.7, 0.7, 0.7)
								end
							end
						end
						local state = element._state:_GetData()
						if next(state) then
							self:AddLine(format("    _state <%s> = {", tostring(element._state)), 0.7, 0.7, 0.7)
							for k, v in pairs(state) do
								local vStr = private.GetStyleValueStr(v)
								if vStr then
									self:AddLine(format("        %s = %s", tostring(k), vStr), 0.7, 0.7, 0.7)
								end
							end
							self:AddLine("    }", 0.7, 0.7, 0.7)
						end
					elseif strataFrame.__debug and next(strataFrame.__debug) then ---@diagnostic disable-line: undefined-field
						self:AddLine("    __debug = {", 0.7, 0.7, 0.7)
						for k, v in pairs(strataFrame.__debug) do ---@diagnostic disable-line: undefined-field
							local vStr = private.GetStyleValueStr(v)
							if vStr then
								self:AddLine(format("        %s = %s", tostring(k), vStr), 0.7, 0.7, 0.7)
							end
						end
						self:AddLine("    }", 0.7, 0.7, 0.7)
					end
				elseif mouseEnabled then
					self:AddLine(text, 0.6, 1, 1)
				else
					self:AddLine(text, 0.9, 0.9, 0.9)
				end
			end
		end
	end
	self.highlightFrame:ClearAllPoints()
	self.highlightFrame:SetAllPoints(topFrame)
	self.highlightFrame:SetFrameStrata("TOOLTIP")
	self:Show()
end

function private.UpdateSelection(numFrames)
	if numFrames ~= private.selection.numFrames then
		private.selection.index = 1
		private.selection.numFrames = numFrames
	end
	local leftAltDown = IsKeyDown("LALT")
	local rightAltDown = IsKeyDown("RALT")
	if not private.selection.altDown and leftAltDown and not rightAltDown then
		private.selection.altDown = "LEFT"
		if private.selection.index == private.selection.numFrames then
			private.selection.index = 1
		else
			private.selection.index = private.selection.index + 1
		end
	elseif not private.selection.altDown and not leftAltDown and rightAltDown then
		private.selection.altDown = "RIGHT"
		if private.selection.index == 1 then
			private.selection.index = private.selection.numFrames
		else
			private.selection.index = private.selection.index - 1
		end
	elseif private.selection.altDown == "LEFT" and not leftAltDown then
		private.selection.altDown = nil
	elseif private.selection.altDown == "RIGHT" and not rightAltDown then
		private.selection.altDown = nil
	end
end

function private.FrameLevelSortFunction(a, b)
	local aLevel = private.IsNonFrameRegion(a) and (a:GetParent():GetFrameLevel() + 0.1) or a:GetFrameLevel()
	local bLevel = private.IsNonFrameRegion(b) and (b:GetParent():GetFrameLevel() + 0.1) or b:GetFrameLevel()
	return aLevel > bLevel
end

function private.TableValueSearch(tbl, searchValue, currentKey, visited)
	visited = visited or {}
	for key, value in pairs(tbl) do
		if value == searchValue then
			return (currentKey and (currentKey..".") or "")..key
		elseif key ~= "_state" and type(value) == "table" and (not value.__isa or UIElements.IsType(value, "Element")) and not visited[value] then
			visited[value] = true
			local result = private.TableValueSearch(value, searchValue, (currentKey and (currentKey..".") or "")..key, visited)
			if result then
				return result
			end
		end
	end
	for _, key in ipairs(ELEMENT_ATTR_KEYS) do
		local value = tbl[key]
		if value == searchValue then
			return (currentKey and (currentKey..".") or "")..key
		elseif type(value) == "table" and (not value.__isa or UIElements.IsType(value, "Element")) and not visited[value] then
			visited[value] = true
			local result = private.TableValueSearch(value, searchValue, (currentKey and (currentKey..".") or "")..key, visited)
			if result then
				return result
			end
		end
	end
end

function private.IsTSMFrame(frame)
	frame = private.GetBaseFrame(frame)
	local globalName = not private.IsNonFrameRegion(frame) and frame:GetName()
	return globalName and strmatch(globalName, "^TSM_[A-Z_]+:")
end

function private.GetBaseFrame(frame)
	if not private.baseFrameCache[frame] then
		local parent = frame:GetParent()
		if not parent or parent == UIParent then
			private.baseFrameCache[frame] = frame
		else
			private.baseFrameCache[frame] = private.GetBaseFrame(parent)
		end
	end
	return private.baseFrameCache[frame]
end

function private.GetFrameNodeInfo(frame)
	local parent = frame:GetParent()
	parent = parent ~= UIParent and parent or nil
	local element = UIElements.GetByFrame(frame)
	if element then
		return element._id, parent
	end

	if parent then
		-- Check if this exists as an attribute of the parent table
		local parentKey = Table.KeyByValue(parent, frame)
		if parentKey then
			return tostring(parentKey), parent
		end

		-- Find the nearest element to which this frame belongs
		local parentElement = nil
		local testFrame = parent
		while testFrame and not parentElement do
			parentElement = UIElements.GetByFrame(testFrame)
			testFrame = testFrame:GetParent()
		end
		if parentElement then
			-- Check if this exists as an attribute of this element
			local tableKey = private.TableValueSearch(parentElement, frame)
			if not tableKey then
				-- Check if the owner exists as an attribute of this element
				local owner = WidgetsDebug.GetOwner(frame:GetName())
				local ownerTableKey = owner and private.TableValueSearch(parentElement, owner) or nil
				local relTableKey = ownerTableKey and private.TableValueSearch(owner, frame) or nil
				if relTableKey then
					tableKey = ownerTableKey.."."..relTableKey
				end
			end
			if tableKey then
				return tableKey, parentElement._frame
			end
		end
	end

	return nil, parent
end

function private.GetFrameName(frame)
	local name, parent = private.GetFrameNodeInfo(frame)
	local parentName = parent and (private.GetFrameName(parent)..".") or ""
	name = name or gsub(tostring(frame), ": ?0*", ":")
	return parentName..name
end

function private.GetStyleValueStr(value)
	for key in pairs(COLOR_KEYS) do
		if value == Theme.GetColor(key) then
			return "ThemeColor<"..key..">"
		end
	end
	for key in pairs(FONT_KEYS) do
		if value == Theme.GetFont(key) then
			return "ThemeFont<"..key..">"
		end
	end
	if type(value) == "string" then
		return "\""..value.."\""
	elseif value ~= false then
		return tostring(value)
	end
	return nil
end

function private.IsNonFrameRegion(obj)
	return obj:IsObjectType("Texture") or obj:IsObjectType("FontString")
end

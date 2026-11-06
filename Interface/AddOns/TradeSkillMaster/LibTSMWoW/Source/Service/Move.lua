-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Move = LibTSMWoW:Init("Service.Move")
local CombatLockdown = LibTSMWoW:Include("Service.CombatLockdown")
local Table = LibTSMWoW:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	combatLockdownPublisher = nil, ---@diagnostic disable-line: tsm-private
	framePoints = {},
	ignoreSetPoint = {},
	pointHooked = {},
	pendingRestore = {},
	pendingOffScreen = {},
}
local DEFAULT_POINTS = {
	["ProfessionsFrame"] = {
		anchor = "TOPLEFT",
		parent = "UIParent",
		relAnchor = "TOPLEFT",
		x = 15,
		y = -116,
	},
	["TradeSkillFrame"] = {
		anchor = "TOPLEFT",
		parent = "UIParent",
		relAnchor = "TOPLEFT",
		x = 0,
		y = -104,
	},
	["CraftFrame"] = {
		anchor = "TOPLEFT",
		parent = "UIParent",
		relAnchor = "TOPLEFT",
		x = 0,
		y = -104,
	},
	["AuctionHouseFrame"] = {
		anchor = "TOPLEFT",
		parent = "UIParent",
		relAnchor = "TOPLEFT",
		x = 36,
		y = -116,
	},
	["MerchantFrame"] = {
		anchor = "TOPLEFT",
		parent = "UIParent",
		relAnchor = "TOPLEFT",
		x = 16,
		y = -116,
	},
}
local DEFAULT_ATTRIBUTES = {
	["ProfessionsFrame"] = {
		["xoffset"] = 35,
		["width"] = LibTSMWoW.IsForever() and 750 or 942,
	},
	["TradeSkillFrame"] = {
		["xoffset"] = -16,
		["width"] = 352,
	},
	["CraftFrame"] = {
		["xoffset"] = -16,
		["width"] = 352,
	},
	["AuctionHouseFrame"] = {
		["xoffset"] = 0,
		["width"] = 800,
	},
	["MerchantFrame"] = {
		["xoffset"] = 0,
		["width"] = 336,
	},
}
local COMBAT_LOCKED_FRAMES = {
	["ProfessionsFrame"] = true,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Move:OnModuleLoad(function()
	private.combatLockdownPublisher = CombatLockdown.GetPublisher()
		:CallFunction(private.HandleCombatLockdownChange)
		:Stored()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not the default UI frame is currently locked from being moved.
---@param defaultFrame Frame
---@return boolean
function Move.IsDefaultUILocked(defaultFrame)
	return LibTSMWoW.IsForever() and COMBAT_LOCKED_FRAMES[defaultFrame:GetName()] and CombatLockdown.IsActive() or false
end

---Moves the default UI off the screen.
---@param defaultFrame Frame
function Move.SetDefaultUIOffScreen(defaultFrame)
	if Move.IsDefaultUILocked(defaultFrame) then
		return
	end
	private.pendingRestore[defaultFrame] = nil
	private.pendingOffScreen[defaultFrame] = nil
	local frameName = defaultFrame:GetName()
	defaultFrame.ignoreFramePositionManager = true
	SetUIPanelAttribute(defaultFrame, "xoffset", -32)
	SetUIPanelAttribute(defaultFrame, "width", 0)
	UpdateUIPanelPositions(defaultFrame)
	if not private.framePoints[frameName] then
		private.framePoints[frameName] = {}
	end
	if not next(private.framePoints[frameName]) then
		if defaultFrame:GetPoint(1) then
			Table.InsertMultiple(private.framePoints[frameName], defaultFrame:GetPoint(1))
		elseif DEFAULT_POINTS[frameName] then
			local point = DEFAULT_POINTS[frameName]
			Table.InsertMultiple(private.framePoints[frameName], point.anchor, point.parent, point.relAnchor, point.x, point.y)
		end
	end
	defaultFrame:ClearAllPoints()
	defaultFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100000, 100000)
	if not private.pointHooked[frameName] then
		hooksecurefunc(defaultFrame, "SetPoint", private.SetPointHook)
		private.pointHooked[frameName] = true
	end
end

---Restores the default UI to its original point and restores the default UI panel attributes, deferring until the
---default UI is no longer locked if needed.
---@param defaultFrame Frame
function Move.RestoreDefaultUI(defaultFrame)
	if Move.IsDefaultUILocked(defaultFrame) then
		private.pendingRestore[defaultFrame] = true
		return
	end
	private.pendingRestore[defaultFrame] = nil
	private.pendingOffScreen[defaultFrame] = nil
	local frameName = defaultFrame:GetName()
	defaultFrame:ClearAllPoints()
	if private.framePoints[frameName] and next(private.framePoints[frameName]) then
		local point, region, relativePoint, x, y = Table.UnpackAndWipe(private.framePoints[frameName])
		defaultFrame:SetPoint(point, region, relativePoint, x, y)
	elseif DEFAULT_POINTS[frameName] then
		local point = DEFAULT_POINTS[frameName]
		defaultFrame:SetPoint(point.anchor, point.parent, point.relAnchor, point.x, point.y)
	end
	defaultFrame.ignoreFramePositionManager = nil
	if DEFAULT_ATTRIBUTES[frameName] then
		for k, v in pairs(DEFAULT_ATTRIBUTES[frameName]) do
			SetUIPanelAttribute(defaultFrame, k, v)
		end
	end
	UpdateUIPanelPositions(defaultFrame)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleCombatLockdownChange(inCombat)
	if inCombat then
		return
	end
	for defaultFrame in pairs(private.pendingRestore) do
		Move.RestoreDefaultUI(defaultFrame)
	end
	for defaultFrame in pairs(private.pendingOffScreen) do
		private.pendingOffScreen[defaultFrame] = nil
		private.SetPointHook(defaultFrame)
	end
end

function private.SetPointHook(frame)
	local name = frame:GetName()
	if private.ignoreSetPoint[name] or not private.framePoints[name] or not next(private.framePoints[name]) then
		return
	elseif Move.IsDefaultUILocked(frame) then
		private.pendingOffScreen[frame] = true
		return
	end
	private.ignoreSetPoint[name] = true
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100000, 100000)
	private.ignoreSetPoint[name] = nil
end

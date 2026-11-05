local Name, AddOn = ...
local Gathering = AddOn.Gathering

local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetTime = GetTime
local max = math.max

function Gathering:GetXPRate()
	return max(self.XPGained or 0, 0) / max(GetTime() - (self.XPStartTime or GetTime()), 1)
end

function Gathering:GetTimeToLevel()
	local MaxXP = UnitXPMax("player") or 0

	if (MaxXP <= 0) then
		return nil, true
	end

	local Rate = self:GetXPRate()

	if (Rate <= 0) then
		return nil, false
	end

	return max(MaxXP - (UnitXP("player") or 0), 0) / Rate, false
end

function Gathering:PLAYER_XP_UPDATE()
	local XP = UnitXP("player")
	local MaxXP = UnitXPMax("player")

	if (MaxXP ~= self.LastMax) then -- Player leveled up
		local LevelXP = self.LastMax - self.LastXP + XP

		self.XPGained = self.XPGained + LevelXP
		self:AddStat("xp", LevelXP)
		self:AddStat("levels", 1)
	else -- Regular XP gain
		local GainedXP = XP - self.LastXP

		self.XPGained = self.XPGained + GainedXP
		self:AddStat("xp", GainedXP)
	end

	if (not self.XPStartTime) then
		self.XPStartTime = GetTime()
	end

	self.LastXP = XP
	self.LastMax = MaxXP

	self:UpdateXPStat()

	if (self.Settings.DisplayMode == "XPH" or self.Settings.DisplayMode == "TTL") then
		self:UpdateDisplayText()

		if (self.XPGained > 0 and not self:GetScript("OnUpdate")) then
			self:StartTimer()
		end
	end
end

Gathering:RegisterEvent("PLAYER_XP_UPDATE")
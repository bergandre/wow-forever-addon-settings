-- Bagnon_ItemInfo anchors the item level label at TOPLEFT, and the Blizzard
-- item button template puts JunkIcon at TOPLEFT too. Move the junk icon away.
local Addon = Bagnon or Bagnonium
if not Addon or not Addon.Item then return end

local POINT, X, Y = 'TOPRIGHT', -1, -1
local moved = setmetatable({}, {__mode = 'k'})

hooksecurefunc(Addon.Item, 'UpdateBorder', function(self)
	local icon = self.JunkIcon
	if icon and not moved[self] then
		icon:ClearAllPoints()
		icon:SetPoint(POINT, self, POINT, X, Y)
		moved[self] = true
	end
end)

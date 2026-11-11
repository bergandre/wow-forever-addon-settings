local _, ns = ...
local L = ns.L
local CliqueBar = ns.addon

local ICON = "Interface\\AddOns\\CliqueBar\\Media\\Icon.tga"

function CliqueBar:SetupBroker()
	local LDB = LibStub("LibDataBroker-1.1", true)
	local LDBIcon = LibStub("LibDBIcon-1.0", true)
	if not LDB then return end

	local dataObject = LDB:NewDataObject("CliqueBar", {
		type = "launcher",
		label = "CliqueBar",
		icon = ICON,
		OnClick = function(_, button)
			if button == "RightButton" then
				self.db.profile.locked = not self.db.profile.locked
				self:ApplyLock()
			else
				self:OpenOptions()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine("CliqueBar", 1, 1, 1)
			tooltip:AddLine(L["Left-click to open options"], 1, 0.82, 0)
			tooltip:AddLine(self.db.profile.locked and L["Right-click to unlock the bar"]
				or L["Right-click to lock the bar"], 1, 0.82, 0)
			if not _G.Clique then
				tooltip:AddLine(L["Clique needs to be loaded for CliqueBar to work properly"], 0.59, 0.67, 0.9)
			end
		end,
	})
	self.dataObject = dataObject

	if LDBIcon then
		LDBIcon:Register("CliqueBar", dataObject, self.db.profile.minimap)
		self.LDBIcon = LDBIcon
	end

	-- Show up in the addon compartment (the drawer at the top of the minimap).
	-- Compartment entries are single-action: every click opens the options, and the
	-- tooltip only lists that.
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon and not self.compartmentAdded then
		self.compartmentAdded = true
		AddonCompartmentFrame:RegisterAddon({
			text = "CliqueBar",
			icon = ICON,
			notCheckable = true,
			func = function() self:OpenOptions() end,
			funcOnEnter = function(button)
				GameTooltip:SetOwner(button, "ANCHOR_LEFT")
				GameTooltip:AddLine("CliqueBar", 1, 1, 1)
				GameTooltip:AddLine(L["Left-click to open options"], 1, 0.82, 0)
				if not _G.Clique then
					GameTooltip:AddLine(L["Clique needs to be loaded for CliqueBar to work properly"], 0.59, 0.67, 0.9)
				end
				GameTooltip:Show()
			end,
			funcOnLeave = function() GameTooltip:Hide() end,
		})
	end
end

-- Right-click menu on the minimap/broker icon or the bar: toggle the lock or jump to
-- the options. Prefers the modern MenuUtil context menu, falls back to EasyMenu.
function CliqueBar:ShowContextMenu(anchor)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(anchor or UIParent, function(_, root)
			root:CreateTitle("CliqueBar")
			root:CreateCheckbox(L["Lock bar"],
				function() return self.db.profile.locked end,
				function()
					self.db.profile.locked = not self.db.profile.locked
					self:ApplyLock()
				end)
			root:CreateButton(L["Show options"], function() self:OpenOptions() end)
		end)
		return
	end

	if not self.contextMenu then
		self.contextMenu = CreateFrame("Frame", "CliqueBarContextMenu", UIParent, "UIDropDownMenuTemplate")
	end
	local menu = {
		{ text = "CliqueBar", isTitle = true, notCheckable = true },
		{
			text = L["Lock bar"],
			checked = function() return self.db.profile.locked end,
			func = function()
				self.db.profile.locked = not self.db.profile.locked
				self:ApplyLock()
			end,
		},
		{
			text = L["Show options"],
			notCheckable = true,
			func = function() self:OpenOptions() end,
		},
	}
	if EasyMenu then
		EasyMenu(menu, self.contextMenu, anchor or "cursor", 0, 0, "MENU")
	else
		self:OpenOptions()
	end
end

function CliqueBar:ToggleMinimap()
	if not self.LDBIcon then return end
	if self.db.profile.minimap.hide then
		self.LDBIcon:Hide("CliqueBar")
	else
		self.LDBIcon:Show("CliqueBar")
	end
end

function CliqueBar:UpdateBroker()
end

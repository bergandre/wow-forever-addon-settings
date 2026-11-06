-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local General = LibTSMApp:InitInternal("Tooltip.General")
local Convert = LibTSMApp:Include("Tooltip.General.Convert")
local CustomSources = LibTSMApp:Include("Tooltip.General.CustomSources")
local Destroy = LibTSMApp:Include("Tooltip.General.Destroy")
local GroupOperation = LibTSMApp:Include("Tooltip.General.GroupOperation")
local Inventory = LibTSMApp:Include("Tooltip.General.Inventory")
local Vendor = LibTSMApp:Include("Tooltip.General.Vendor")
local TooltipInfo = LibTSMApp:IncludeClassType("TooltipInfo")
local Registry = LibTSMApp:Include("Tooltip.Registry")



-- ============================================================================
-- Module Functions
-- ============================================================================

function General.Register()
	local tooltipInfo = TooltipInfo()
		:SetHeadings(L["TSM General Info"])
	GroupOperation.AddEntries(tooltipInfo)
	Destroy.AddEntries(tooltipInfo)
	Convert.AddEntries(tooltipInfo)
	Vendor.AddEntries(tooltipInfo)
	CustomSources.AddEntries(tooltipInfo)
	Inventory.AddEntries(tooltipInfo)
	Registry.Add(tooltipInfo)
end

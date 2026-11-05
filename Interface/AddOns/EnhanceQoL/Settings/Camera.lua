local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local cameraCVar = "cameraDistanceMaxZoomFactor"
local isForever = addon.variables.isForever
local maximumFactor = 2.6
local previousValue

local function isMaximumEnabled()
	local value = tonumber(C_CVar.GetCVar(cameraCVar))
	return value ~= nil and value >= maximumFactor
end

local function setMaximumEnabled(enabled)
	local currentValue = C_CVar.GetCVar(cameraCVar)
	if currentValue == nil then return end
	if enabled then
		-- Preserve an existing larger value instead of reducing the user's range.
		if isMaximumEnabled() then return end
		previousValue = currentValue
		addon.functions.setCVarValue(cameraCVar, maximumFactor)
	else
		if not isMaximumEnabled() then return end
		local restoreValue = previousValue or C_CVar.GetCVarDefault(cameraCVar)
		if restoreValue == nil then return end
		addon.functions.setCVarValue(cameraCVar, restoreValue)
		previousValue = nil
	end
end

local category = addon.SettingsLayout.rootUI
local section
if isForever or addon.variables.isTBC then
	section = addon.functions.SettingsClassicUtilityBlock(CAMERA_LABEL, "camera", 100, isForever and "CameraForever" or "CameraZoom")
else
	section = addon.functions.SettingsCreateExpandableSection(category, {
		name = CAMERA_LABEL, configPageKey = "CameraZoom", modernCategory = "interface",
		iconKey = "settingspage", expanded = false, newTagID = "CameraZoom",
	})
end

addon.functions.SettingsCreateCheckbox(category, {
	var = isForever and "maxCameraZoomForever" or "maxCameraZoom", order = 110,
	text = L["maxCameraZoom"],
	desc = string.format(L["maxCameraZoomDesc"], maximumFactor),
	default = false,
	storage = false,
	newTagID = isForever and "maxCameraZoomForever" or "maxCameraZoom",
	get = isMaximumEnabled,
	func = setMaximumEnabled,
	parentSection = section,
})

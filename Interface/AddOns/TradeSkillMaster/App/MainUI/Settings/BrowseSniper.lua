-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local BrowseSniper = App:Init("MainUI.Settings.BrowseSniper")
local Math = App:From("LibTSMUtil"):Include("Lua.Math")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Item = App:From("LibTSMWoW"):Include("API.Item")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
}
local SETTING_TOOLTIPS = {
	searchAutoFocus = L["When enabled, the search input in the Browse tab of the AH will automatically be focused to allow for quickly searching the AH."],
	buyoutConfirm = L["If enabled, TSM will display an additional confirmation when attempting to buy an auction above the value set in the 'Buyout alert source' setting. This can help avoid accidental purchases of expensive auctions."],
	deSearchLevelRange = L["The item level range to show in the Disenchant search results."],
	maxDeSearchPercent = L["When running a Disenchant search, only auctions which are listed for below this percentage of their disenchant value will be displayed in the search results."],
	pctSource = L["This custom string defines how TSM determines the market value of items for calculating the '%' column in the search results. This value is only used when running a manual search in the Browse tab of the AH."],
	buyoutAlertSource = L["TSM will display an additional confirmation when attempting to buy an auction above this value. This can help avoid accidental purchases of expensive auctions."],
	sniperSound = L["The sound to play when an auction is found by the Sniper scan."],
}
local MAX_ITEM_LEVEL_RANGE = "0,"..Item.GetMaxItemLevel()
local STATE_SCHEMA = Reactive.CreateStateSchema("BrowseSniperSettingsUIState")
	:AddBooleanField("buyoutConfirmationAlertEnabled", false)
	:AddStringField("deSearchLevelRange", MAX_ITEM_LEVEL_RANGE)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(BrowseSniper, function(db)
	private.settings = db:NewView("BrowseSniperSettings")
		:AddKey("global", "shoppingOptions", "searchAutoFocus")
		:AddKey("global", "shoppingOptions", "buyoutConfirm")
		:AddKey("global", "shoppingOptions", "minDeSearchLvl")
		:AddKey("global", "shoppingOptions", "maxDeSearchLvl")
		:AddKey("global", "shoppingOptions", "maxDeSearchPercent")
		:AddKey("global", "shoppingOptions", "pctSource")
		:AddKey("global", "shoppingOptions", "buyoutAlertSource")
		:AddKey("global", "sniperOptions", "sniperSound")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	local maxItemLevel = Item.GetMaxItemLevel()
	local minDeSearchLvl = Math.Bound(private.settings.minDeSearchLvl, 0, maxItemLevel)
	local maxDeSearchLvl = Math.Bound(private.settings.maxDeSearchLvl, minDeSearchLvl, maxItemLevel)
	state.deSearchLevelRange = strjoin(",", minDeSearchLvl, maxDeSearchLvl)
	private.manager = UIManager.Create("BROWSE_SNIPER_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetBrowseSniperSettingsFrame)

	-- Set up a publisher to mirror buyoutConfirmationAlertEnabled to the settings value
	private.manager:MirrorStateWithTable("buyoutConfirmationAlertEnabled", private.settings, "buyoutConfirm")

	private.manager:AddCancellable(state:Publisher("deSearchLevelRange")
		:Share()
		:Map(private.LevelRangeToMinValue)
		:AssignToTableKey(private.settings, "minDeSearchLvl")
		:Map(private.LevelRangeToMaxValue)
		:AssignToTableKey(private.settings, "maxDeSearchLvl")
		:EndShare()
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the browse / sniper settings frame.
---@return BaseScrollFrame
function BrowseSniper.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Browse / Sniper Settings UI
-- ============================================================================

---@param state BrowseSniperSettingsUIState
function private.GetBrowseSniperSettingsFrame(state)
	state.buyoutConfirmationAlertEnabled = private.settings.buyoutConfirm
	UIUtils.AnalyticsRecordPathChange("main", "settings", "shopping")
	return UIElements.New("BaseScrollFrame", "shoppingSettings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "general")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Some general Browse/Sniper options are below."])
			:AddChild(UIElements.New("BaseFrame", "focusFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetWidth("AUTO")
					:SetText(L["Auto-focus browse search input"])
					:SetSettingInfo(private.settings, "searchAutoFocus")
					:SetTooltip(SETTING_TOOLTIPS.searchAutoFocus)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "marketValueSourceField")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Market value price source"], SETTING_TOOLTIPS.pctSource)
				:SetSettingInfo(private.settings, "pctSource")
			)
			:AddChild(UIElements.New("BaseFrame", "showConfirmFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetWidth("AUTO")
					:SetText(L["Show confirmation alert if buyout is above the alert price"])
					:SetSettingInfo(state, "buyoutConfirmationAlertEnabled")
					:SetTooltip(SETTING_TOOLTIPS.buyoutConfirm)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("SettingsCustomStringInputWithResetLine", "buyoutConfirmationAlert")
				:ConfigureText(L["Buyout confirmation alert"], SETTING_TOOLTIPS.buyoutAlertSource)
				:SetSettingInfo(private.settings, "buyoutAlertSource")
				:SetDisabled(state:Publisher("buyoutConfirmationAlertEnabled"):InvertBoolean())
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "disenchant")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Disenchant Search Options"], L["Some options for the Disenchant Search are below."])
			:AddChild(UIElements.New("SettingsField", "levelRange")
				:SetMargin(0, 0, 0, 12)
				:SetLabel(L["Disenchant level range"])
				:AddChild(UIElements.New("RangeInput", "levelRange")
					:SetHeight(24)
					:SetRange(MAX_ITEM_LEVEL_RANGE)
					:MirrorValueState(state, "deSearchLevelRange")
					:SetTooltip(SETTING_TOOLTIPS.deSearchLevelRange)
				)
			)
			:AddChild(UIElements.New("SettingsField", "pct")
				:SetLabel(L["Maximum disenchant search percent"])
				:AddChild(UIElements.New("BaseFrame", "pctInput")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:AddChild(UIElements.New("NumberInput", "input")
						:SetMargin(0, 8, 0, 0)
						:SetValidRange(0, 100)
						:SetSettingInfo(private.settings, "maxDeSearchPercent")
						:SetTooltip(SETTING_TOOLTIPS.maxDeSearchPercent, true)
					)
					:AddChild(UIElements.New("Text", "rangeText")
						:SetWidth("AUTO")
						:SetFont("BODY_XSMALL")
						:SetTextColor("on/surface/low")
						:SetText(format(L["(minimum 0 - maximum %d)"], 100))
					)
				)
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "sniper")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Sniper Options"], L["Options specific to Sniper are below."])
			:AddChild(UIElements.New("SettingsField", "sound")
				:SetLabel(L["Found auction sound"])
				:AddChild(UIElements.New("SoundDropdown", "sniperSoundDropdown")
					:SetHeight(24)
					:SetSettingInfo(private.settings, "sniperSound")
					:SetTooltip(SETTING_TOOLTIPS.sniperSound)
				)
			)
		)
end



-- ============================================================================
-- Action Handler
-- ===========================================================================

function private.ActionHandler(_, _, action, ...)
	error("Unknown action: "..tostring(action))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LevelRangeToMinValue(levelRange)
	local value = strsplit(",", levelRange)
	value = tonumber(value)
	assert(value)
	return value
end

function private.LevelRangeToMaxValue(levelRange)
	local _, value = strsplit(",", levelRange)
	value = tonumber(value)
	assert(value)
	return value
end

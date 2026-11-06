-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Auctioning = App:Init("MainUI.Operations.Auctioning")
local Util = App:Include("MainUI.Operations.Util")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local AuctioningOperation = App:From("LibTSMSystem"):Include("AuctioningOperation")
local AuctionHouse = App:From("LibTSMWoW"):Include("API.AuctionHouse")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
}
local OPERATION_TYPE_NAME = "Auctioning"
local IGNORE_DURATION_OPTIONS = {
	L["None"],
}
do
	for i = 1, 3 do
		local str, detailStr = AuctionHouse.GetTimeLeftStrings(i)
		tinsert(IGNORE_DURATION_OPTIONS, str.." ("..detailStr..")")
	end
end
local BELOW_MIN_ITEMS = { L["Don't Post Items"], L["Post at Minimum Price"], L["Post at Maximum Price"], L["Post at Normal Price"], L["Ignore Auctions Below Min"] }
local BELOW_MIN_KEYS = { "none", "minPrice", "maxPrice", "normalPrice", "ignore" }
local ABOVE_MAX_ITEMS = { L["Don't Post Items"], L["Post at Minimum Price"], L["Post at Maximum Price"], L["Post at Normal Price"] }
local ABOVE_MAX_KEYS = { "none", "minPrice", "maxPrice", "normalPrice" }
local BAD_PRICE_SOURCES = {
	auctioningopmin = true,
	auctioningopmax = true,
	auctioningopnormal = true,
}
local SETTING_TOOLTIPS = {
	ignoreLowDuration = L["When posting and canceling, auctions at or below the selected duration will be completely ignored."],
	matchStackSize = L["Enables this causes TSM to ignores auctions which aren't of the same stack size as you have set in the Posting settings and only undercut other auctions which match your stack size."],
	stackSizeIsCap = L["Whether or not to post a partial stack if you don't have a full stack in your inventory."],
	stackSize = L["The stack size to post on the AH."],
	duration = L["How long auctions are listed for on the AH."],
	postCap = (App.IsVanillaClassic() or App.IsBCClassic()) and L["The maximum number of stacks to post on the AH."] or L["The maximum number of items to post on the AH."],
	keepQuantity = L["The number of items to keep in your bags and not post on the AH. Set this to 0 to disable it."],
	maxExpires = L["After an item has expired this many times, it will no longer be posted on the AH. Set this to 0 to disable it."],
	bidPercent = L["When posting auctions, the bid price will be calculated as a percentage of the buyout price based on this setting."],
	undercut = L["The amount to undercut the lowest auction by when running a post scan. It's highly recommended to leave this at the default value."],
	minPrice = L["The lowest price you want TSM to consider posting your auctions for"].." "..L["TSM will always attempt to undercut the cheapest auction as long as it's between your minimum and maximum prices."],
	priceReset = L["This defines what TSM does when the lowest auction on the AH is below the minimum price you have set."],
	maxPrice = L["The highest price you want TSM to consider posting your auctions for."].." "..L["TSM will always attempt to undercut the cheapest auction as long as it's between your minimum and maximum prices."],
	aboveMax = L["This defines what TSM does when the lowest auction on the AH is above the maximum price you have set."],
	normalPrice = L["The price you want to post your auctions for when there's no competition on the AH."],
	cancelUndercut = L["Cancel auctions which have been undercut when running a Cancel Scan."],
	cancelRepost = L["Cancel auctions which can be reposted higher when running a Cancel Scan."],
	cancelRepostThreshold = L["Only cancel auctions which can be posted at least this much higher."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("AuctioningOperationsUIState")
	:AddDeferredUIElementField("frame", "SegmentedTabGroup")
	:AddStringField("tab", L["Details"])
	:AddDeferredStringField("operationName")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Auctioning:OnModuleLoad(function()
	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("AUCTIONING_OPERATIONS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetAuctioningOperationSettings)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the auctioning operation settings frame.
---@param operationName string The current operation name
---@return SegmentedTabGroup
function Auctioning.GetFrame(operationName)
	return private.manager:BuildFrame(operationName)
end



-- ============================================================================
-- Auctioning Operation Settings UI
-- ============================================================================

---@param state AuctioningOperationsUIState
function private.GetAuctioningOperationSettings(state, operationName)
	state.operationName = operationName
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning")
	return UIElements.New("SegmentedTabGroup", "tabs")
		:SetBarMargin(8)
		:SetManager(private.manager)
		:SetContext(state)
		:BindElement(state, "frame")
		:SetNavCallback(private.GetAuctioningSettings)
		:AddPath(L["Details"])
		:AddPath(L["Posting"])
		:AddPath(L["Canceling"])
		:SetPath(state.tab)
end

function private.GetAuctioningSettings(tabGroup, button)
	local state = tabGroup:GetContext() ---@type AuctioningOperationsUIState
	state.tab = button
	if button == L["Details"] then
		return private.GetDetailsSettings(state)
	elseif button == L["Posting"] then
		return private.GetPostingSettings(state)
	elseif button == L["Canceling"] then
		return private.GetCancelingSettings(state)
	else
		error("Unknown button!")
	end
end

---@param state AuctioningOperationsUIState
function private.GetDetailsSettings(state)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning", "details")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 0, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "generalOptions")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["General Options"], L["Adjust some general settings."])
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:AddChildrenWithFunction(private.AddMaxStackSizeSetting, state)
				:AddChild(UIElements.New("OperationLinkedAuctioningIgnoreDuration", "ignoreLowDuration")
					:ConfigureText(L["Ignore auctions by duration"], SETTING_TOOLTIPS.ignoreLowDuration)
					:SetItems(IGNORE_DURATION_OPTIONS)
					:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "ignoreLowDuration")
				)
			)
		)
		:AddChild(UIElements.New("OperationManagementSettingsFrame", "management")
			:Configure(OPERATION_TYPE_NAME, state.operationName, AddonSettings.GetDB())
			:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
			:SetAction("OnGroupsChanged", "ACTION_GROUPS_CHANGED")
		)
end

---@param state AuctioningOperationsUIState
function private.AddMaxStackSizeSetting(frame, state)
	if not App.IsVanillaClassic() and not App.IsBCClassic() then
		return
	end
	frame:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "matchStackSize")
		:SetMargin(0, 0, 0, 12)
		:ConfigureText(L["Match stack size"], SETTING_TOOLTIPS.matchStackSize)
		:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "matchStackSize")
	)
end

---@param state AuctioningOperationsUIState
function private.GetPostingSettings(state)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning", "posting")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 0, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "postingSettings")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Posting Options"], L["Adjust the settings below to set how groups attached to this operation will be auctioned."])
			:SetDescriptionHeight(40)
			:AddChild(UIElements.New("OperationLinkedListDropdownLine", "duration")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Auction duration"], L["Select duration"], SETTING_TOOLTIPS.duration)
				:SetItems(AuctionHouse.DURATIONS)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "duration")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "postCap")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Post cap"], SETTING_TOOLTIPS.postCap, AuctioningOperation.GetSettingRange("postCap"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "postCap")
			)
			:AddChildrenWithFunction(private.AddStackSizeSettings, state)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "keepQuantity")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Amount kept in bags"], SETTING_TOOLTIPS.keepQuantity, AuctioningOperation.GetSettingRange("keepQuantity"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "keepQuantity")
			)
			:AddChild(UIElements.New("OperationLinkedNumberInputLine", "maxExpires")
				:ConfigureText(L["Don't post after this many expires"], SETTING_TOOLTIPS.maxExpires, AuctioningOperation.GetSettingRange("maxExpires"))
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "maxExpires")
			)
		)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "postingPriceSettings")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Posting Price"], L["Adjust the settings below to set how groups attached to this operation will be priced."])
			:SetDescriptionHeight(40)
			:AddChild(UIElements.New("OperationLinkedAuctioningBidPercentInput", "bidPercent")
				:SetMargin(0, 0, 0, 12)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "bidPercent")
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "undercut")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Undercut amount"], SETTING_TOOLTIPS.undercut)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "undercut", true)
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "minPrice")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Minimum price"], SETTING_TOOLTIPS.minPrice)
				:SetBadSources(BAD_PRICE_SOURCES)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "minPrice")
			)
			:AddChild(UIElements.New("OperationSelectionDropdownLine", "priceReset")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["When below minimum:"], L["Select setting"], SETTING_TOOLTIPS.priceReset)
				:SetItems(BELOW_MIN_ITEMS, BELOW_MIN_KEYS)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "priceReset")
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "maxPrice")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Maximum price"], SETTING_TOOLTIPS.maxPrice)
				:SetBadSources(BAD_PRICE_SOURCES)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "maxPrice")
			)
			:AddChild(UIElements.New("OperationSelectionDropdownLine", "aboveMax")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["When above maximum:"], L["Select setting"], SETTING_TOOLTIPS.aboveMax)
				:SetItems(ABOVE_MAX_ITEMS, ABOVE_MAX_KEYS)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "aboveMax")
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "normalPrice")
				:ConfigureText(L["Normal price"], SETTING_TOOLTIPS.normalPrice)
				:SetBadSources(BAD_PRICE_SOURCES)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "normalPrice")
			)
		)
end

---@param state AuctioningOperationsUIState
function private.AddStackSizeSettings(frame, state)
	if not App.IsVanillaClassic() and not App.IsBCClassic() then
		return
	end
	frame:AddChild(UIElements.New("OperationLinkedNumberInputLine", "stackSize")
		:SetMargin(0, 0, 0, 12)
		:ConfigureText(L["Stack size"], SETTING_TOOLTIPS.stackSize, AuctioningOperation.GetSettingRange("stackSize"))
		:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "stackSize")
	)
	frame:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "stackSizeIsCap")
		:SetMargin(0, 0, 0, 12)
		:ConfigureText(L["Allow partial stack"], SETTING_TOOLTIPS.stackSizeIsCap)
		:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "stackSizeIsCap")
	)
end

---@param state AuctioningOperationsUIState
function private.GetCancelingSettings(state)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning", "canceling")
	return UIElements.New("BaseScrollFrame", "settings")
		:SetPadding(8, 8, 0, 0)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "cancelSettings")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Canceling Options"], L["Adjust the settings below to set how groups attached to this operation will be cancelled."])
			:SetDescriptionHeight(40)
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "cancelUndercut")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Cancel undercut auctions"], SETTING_TOOLTIPS.cancelUndercut)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "cancelUndercut")
			)
			:AddChild(UIElements.New("OperationLinkedToggleYesNoLine", "cancelRepost")
				:SetMargin(0, 0, 0, 12)
				:ConfigureText(L["Cancel to repost higher"], SETTING_TOOLTIPS.cancelRepost)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "cancelRepost")
			)
			:AddChild(UIElements.New("OperationLinkedCustomStringInputLine", "cancelRepostThreshold")
				:ConfigureText(L["Repost threshold"], SETTING_TOOLTIPS.cancelRepostThreshold)
				:SetOperationSetting(OPERATION_TYPE_NAME, state.operationName, "cancelRepostThreshold")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<AuctioningOperationsUIState>
---@param state AuctioningOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		Util.ShowGroupSettings(groupPath)
	elseif action == "ACTION_GROUPS_CHANGED" then
		state.frame:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

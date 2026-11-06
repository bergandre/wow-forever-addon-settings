-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Sniper = App:Init("AuctionUI.Sniper")
local AuctionBuyScan = App:IncludeClassType("AuctionBuyScan")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local PlayerInfo = App:From("LibTSMApp"):Include("Service.PlayerInfo")
local SniperApp = App:From("LibTSMApp"):Include("Sniper")
local private = {
	manager = nil,
	settings = nil,
	canHandleItemLink = false,
}
local HAS_BID_SNIPING = App.IsVanillaClassic() or App.IsBCClassic()
local STATE_SCHEMA = Reactive.CreateStateSchema("SniperUIState")
	:AddDeferredUIElementField("frame", "ViewContainer")
	:AddDeferredUIElementField("scanFrame", "BaseFrame")
	:AddDeferredUIElementField("scrollTable", "SniperScrollTable")
	:AddDeferredClassField("auctionBuyScan", AuctionBuyScan)
	:AddBooleanField("selectionFrameShown", false)
	:AddStringField("contentPath", "selection")
	:Commit()

---@event SniperAction
---| "ACTION_SELECTION_FRAME_HIDDEN"
---| "ACTION_START_BUYOUT_SEARCH"
---| "ACTION_START_BID_SEARCH"
---| "ACTION_START_SEARCH" -> contentPath: string, searchContext: AuctionSearchContext
---| "ACTION_RESTART_SEARCH"
---| "ACTION_BACK_BUTTON_CLICKED"



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Sniper, function(db)
	private.settings = db:NewView("SniperSettings")
		:AddKey("global", "auctionUIContext", "sniperScrollingTable")
		:AddKey("global", "sniperOptions", "sniperSound")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SNIPER", state, private.ActionHandler)
		:AddFrameBuilder(private.GetSniperFrame)

	private.canHandleItemLink = false -- Explicitly set private.canHandleItemLink at least once to appease the linter
	private.manager:AddCancellable(state:Publisher("selectionFrameShown")
		:InvertBoolean()
		:AssignToTableKey(private, "canHandleItemLink")
	)

	-- Create the auction buy scan
	state.auctionBuyScan = AuctionBuyScan.NewSniper(L["Sniper"], private.IsPlayer)
	private.manager:AddCancellable(state:Publisher("scrollTable")
		:CallMethod(state.auctionBuyScan, "SetAuctionScrollTable")
	)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the Sniper frame.
---@return ViewContainer
function Sniper.GetFrame()
	return private.manager:BuildFrame()
end

---Handles an item being linked.
---@param name string The item name
---@param itemLink string The item link
---@return boolean
---@return string?
function Sniper.HandleItemLinked(name, itemLink)
	if not private.canHandleItemLink then
		return false, nil
	end
	private.manager:ProcessAction("ACTION_BACK_BUTTON_CLICKED")
	return true, L["Browse"]
end



-- ============================================================================
-- Sniper UI
-- ============================================================================

---@param state SniperUIState
function private.GetSniperFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "sniper")
	if not state.auctionBuyScan:GetSearchContext() then
		state.contentPath = "selection"
	end
	return UIElements.New("ViewContainer", "sniper")
		:SetContext(state)
		:SetNavCallback(private.GetSniperContentFrame)
		:AddPath("selection")
		:AddPath("buyoutScan")
		:AddPath("bidScan")
		:SetPath(state.contentPath)
		:SetManager(private.manager)
		:BindElement(state, "frame")
end

function private.GetSniperContentFrame(viewContainer, path)
	local state = viewContainer:GetContext() ---@type SniperUIState
	state.contentPath = path
	if path == "selection" then
		return private.GetSelectionFrame(state)
	elseif path == "buyoutScan" then
		return private.GetScanFrame(state, true)
	elseif path == "bidScan" then
		return private.GetScanFrame(state, false)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state SniperUIState
function private.GetSelectionFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "sniper", "selection")
	state.selectionFrameShown = true
	return UIElements.New("BaseFrame", "selection")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:AddChild(UIElements.New("BaseFrame", "content")
			:SetLayout("VERTICAL")
			:SetPadding(8)
			:SetRoundedBackgroundColor("container/low")
			:AddChild(UIElements.New("Spacer", "topSpacer"))
			:AddChildIf(HAS_BID_SNIPING, UIElements.New("Text", "text")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 16)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Start either a 'Buyout' or 'Bid' sniper using the buttons below."])
			)
			:AddChild(UIElements.New("BaseFrame", "buttons")
				:SetLayout("HORIZONTAL")
				:SetHeight(28)
				:AddChild(UIElements.New("Spacer", "leftSpacer"))
				:AddChild(UIElements.New("MediumPrimaryActionButton", "buyoutScanBtn")
					:SetWidth(240)
					:SetMargin(0, HAS_BID_SNIPING and 8 or 0, 0, 0)
					:SetText(L["Run Buyout Sniper"])
					:SetAction("OnClick", "ACTION_START_BUYOUT_SEARCH")
				)
				:AddChildIf(HAS_BID_SNIPING, UIElements.New("MediumSecondaryActionButton", "bidScanBtn")
					:SetWidth(240)
					:SetText(L["Run Bid Sniper"])
					:SetAction("OnClick", "ACTION_START_BID_SEARCH")
				)
				:AddChild(UIElements.New("Spacer", "rightSpacer"))
			)
			:AddChild(UIElements.New("Spacer", "bottomSpacer"))
		)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_SELECTION_FRAME_HIDDEN"))
end

---@param state SniperUIState
function private.GetScanFrame(state, isBuyout)
	UIUtils.AnalyticsRecordPathChange("auction", "sniper", "scan")
	return UIElements.New("BaseFrame", "scan")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:BindElement(state, "scanFrame")
		:SetManager(private.manager)
		:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("ExitScanButton", "back")
				:SetAction("OnClick", "ACTION_BACK_BUTTON_CLICKED")
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_MEDIUM")
				:SetJustifyH("CENTER")
				:SetText(isBuyout and L["Buyout Sniper"] or L["Bid Sniper"])
			)
			:AddChild(UIElements.New("SmallSecondaryActionButton", "restartBtn")
				:SetWidth(108)
				:SetText(L["Restart"])
				:SetAction("OnClick", "ACTION_RESTART_SEARCH")
			)
		)
		:AddChild(UIElements.New("ListContainer", "results")
			:AddChild(UIElements.New("SniperScrollTable", "auctions")
				:SetSettings(private.settings, "sniperScrollingTable")
				:SetCreatedGroupName(L["Sniper"].." - "..L["Scan Results"])
				:SetIsPlayerFunction(PlayerInfo.AuctionOwnerIsPlayer)
				:BindElement(state, "scrollTable")
			)
		)
		:AddChild(state.auctionBuyScan:CreateBottomUIFrameForSniper(isBuyout))
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<SniperUIState>
---@param state SniperUIState
---@param action SniperAction
---@param ... params<SniperAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SELECTION_FRAME_HIDDEN" then
		state.selectionFrameShown = false
	elseif action == "ACTION_START_BUYOUT_SEARCH" then
		manager:ProcessAction("ACTION_START_SEARCH", "buyoutScan", SniperApp.GetBuyoutSearchContext())
	elseif action == "ACTION_START_BID_SEARCH" then
		manager:ProcessAction("ACTION_START_SEARCH", "bidScan", SniperApp.GetBidSearchContext())
	elseif action == "ACTION_START_SEARCH" then
		local contentPath, searchContext = ...
		state.frame:SetPath("selection", true)
		if not state.auctionBuyScan:PrepareStartSearch() then
			return
		end
		state.auctionBuyScan:StartSearch(searchContext)
		state.frame:SetPath(contentPath, true)
	elseif action == "ACTION_RESTART_SEARCH" then
		local searchContext = state.auctionBuyScan:GetSearchContext()
		assert(searchContext)
		state.auctionBuyScan:EndSearch()
		manager:ProcessAction("ACTION_START_SEARCH", state.contentPath, searchContext)
	elseif action == "ACTION_BACK_BUTTON_CLICKED" then
		state.frame:SetPath("selection", true)
		state.auctionBuyScan:EndSearch()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsPlayer(character, includeAlts)
	if includeAlts then
		return PlayerInfo.IsPlayer(character, true, true, true)
	else
		return PlayerInfo.IsPlayer(character)
	end
end

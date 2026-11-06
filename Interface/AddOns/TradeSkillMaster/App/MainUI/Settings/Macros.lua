-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Macros = App:Init("MainUI.Settings.Macros")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local Macro = App:From("LibTSMWoW"):Include("API.Macro")
local CombatLockdown = App:From("LibTSMWoW"):Include("Service.CombatLockdown")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local ChatMessage = App:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local Lifecycle = App:From("LibTSMService"):Include("Util.Lifecycle")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	manager = nil,
	linesTemp = {},
}
local MACRO_NAME = "TSMMacro"
local MACRO_ICON = (App.IsRetail() or App.IsForever()) and "Achievement_Faction_GoldenLotus" or "INV_Misc_Flower_01"
local BUTTON_NAMES = {
	myAuctionsCancel = "TSMCancelAuctionBtn",
	auctioning = "TSMAuctioningBtn",
	shoppingBuyout = "TSMShoppingBuyoutBtn",
	bidBuyConfirm = "TSMBidBuyConfirmBtn",
	sniper = "TSMSniperBtn",
	crafting = "TSMCraftingBtn",
	vendoringSellAll = "TSMVendoringSellAllButton",
}
local MAX_MACRO_LENGTH = 255
local STATE_SCHEMA = Reactive.CreateStateSchema("MacroSettingsUIState")
	:AddBooleanField("hasExisting", false)
	:AddBooleanField("up", true)
	:AddBooleanField("down", true)
	:AddBooleanField("ctrl", true)
	:AddBooleanField("alt", false)
	:AddBooleanField("shift", false)
	:AddBooleanField("myAuctionsCancel", false)
	:AddBooleanField("auctioning", true)
	:AddBooleanField("shoppingBuyout", true)
	:AddBooleanField("bidBuyConfirm", false)
	:AddBooleanField("sniper", true)
	:AddBooleanField("crafting", true)
	:AddBooleanField("vendoringSellAll", false)
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

Macros:OnModuleLoad(function()
	Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MACRO_SETTINGS_UI", state, private.ActionHandler)
		:AddFrameBuilder(private.GetMacrosSettingsFrame)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the macros settings frame.
---@return BaseScrollFrame
function Macros.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Macros Settings UI
-- ============================================================================

---@param state MacroSettingsUIState
function private.GetMacrosSettingsFrame(state)
	UIUtils.AnalyticsRecordPathChange("main", "settings", "macros")
	local body = Macro.GetBody(MACRO_NAME)
	state.hasExisting = body and true or false
	if body then
		-- Update the state from the existing macro/binding
		state.up, state.down, state.ctrl, state.alt, state.shift = Macro.GetBinding(MACRO_NAME)
		state.myAuctionsCancel = strfind(body, BUTTON_NAMES.myAuctionsCancel) and true or false
		state.auctioning = strfind(body, BUTTON_NAMES.auctioning) and true or false
		state.shoppingBuyout = strfind(body, BUTTON_NAMES.shoppingBuyout) and true or false
		state.bidBuyConfirm = strfind(body, BUTTON_NAMES.bidBuyConfirm) and true or false
		state.sniper = strfind(body, BUTTON_NAMES.sniper) and true or false
		state.crafting = strfind(body, BUTTON_NAMES.crafting) and true or false
		state.vendoringSellAll = strfind(body, BUTTON_NAMES.vendoringSellAll) and true or false
	end
	return UIElements.New("BaseScrollFrame", "macroSettings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:AddChild(UIElements.New("SettingsCollapsibleContainer", "setup")
			:SetMargin(0, 0, 0, 24)
			:SetLargeHeading()
			:SetHeadingDescription(L["Macro Setup"], L["Many commonly-used actions in TSM can be added to a macro and bound to your scroll wheel. Use the options below to setup this macro and scroll wheel binding."])
			:SetDescriptionHeight(40)
			:AddChild(UIElements.New("Text", "actionsSubHeading")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Bound Actions"])
			)
			:AddChild(UIElements.New("BaseFrame", "row1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "myauctionsCheckbox")
					:SetText(L["My Auctions"].." - "..Theme.GetColor("accent/main"):ColorText(GlobalStrings.Get("CANCEL")))
					:MirrorIsCheckedState(state, "myAuctionsCancel")
				)
				:AddChild(UIElements.New("Checkbox", "auctioningCheckbox")
					:SetText(L["Auctioning"].." - "..Theme.GetColor("accent/main"):ColorText(L["Post / Cancel"]))
					:MirrorIsCheckedState(state, "auctioning")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "row2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "shoppingCheckbox")
					:SetText(L["Browse"].." - "..Theme.GetColor("accent/main"):ColorText(GlobalStrings.Get("BUYOUT")))
					:MirrorIsCheckedState(state, "shoppingBuyout")
				)
				:AddChild(UIElements.New("Checkbox", "bidBuyConfirmBtn")
					:SetText(L["Browse / Sniper"].." - "..Theme.GetColor("accent/main"):ColorText(L["Bid / Buyout Confirmation"]))
					:MirrorIsCheckedState(state, "bidBuyConfirm")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "row3")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "sniperCheckbox")
					:SetText(L["Sniper"].." - "..Theme.GetColor("accent/main"):ColorText(GlobalStrings.Get("BUYOUT")))
					:MirrorIsCheckedState(state, "sniper")
				)
				:AddChild(UIElements.New("Checkbox", "craftingCheckbox")
					:SetText(L["Crafting"].." - "..Theme.GetColor("accent/main"):ColorText(L["Craft Next"]))
					:MirrorIsCheckedState(state, "crafting")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "row4")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "vendoringCheckbox")
					:SetText(L["Vendoring"].." - "..Theme.GetColor("accent/main"):ColorText(L["Sell All"]))
					:MirrorIsCheckedState(state, "vendoringSellAll")
				)
			)
			:AddChild(UIElements.New("Text", "scrollWheelSubHeading")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(L["Scroll Wheel Options"])
			)
			:AddChild(UIElements.New("BaseFrame", "direction")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 2)
					:SetFont("BODY_SMALL")
					:SetText(L["Scroll wheel direction"])
				)
				:AddChild(UIElements.New("BaseFrame", "check")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Checkbox", "up")
						:SetWidth("AUTO")
						:SetMargin(0, 16, 0, 0)
						:SetText(L["Up"])
						:MirrorIsCheckedState(state, "up")
					)
					:AddChild(UIElements.New("Checkbox", "down")
						:SetWidth("AUTO")
						:SetText(L["Down"])
						:MirrorIsCheckedState(state, "down")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "modifiers")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 2)
					:SetFont("BODY_SMALL")
					:SetText(L["Modifiers"])
				)
				:AddChild(UIElements.New("BaseFrame", "check")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Checkbox", "ctrl")
						:SetWidth("AUTO")
						:SetMargin(0, 16, 0, 0)
						:SetText(L["CTRL"])
						:MirrorIsCheckedState(state, "ctrl")
					)
					:AddChild(UIElements.New("Checkbox", "alt")
						:SetWidth("AUTO")
						:SetMargin(0, 16, 0, 0)
						:SetText(L["ALT"])
						:MirrorIsCheckedState(state, "alt")
					)
					:AddChild(UIElements.New("Checkbox", "shift")
						:SetWidth("AUTO")
						:SetText(L["SHIFT"])
						:MirrorIsCheckedState(state, "shift")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "createBtn")
				:SetText(state:Publisher("hasExisting"):ReplaceBooleanWith(L["Update existing macro"], L["Create macro"]))
				:SetAction("OnClick", "ACTION_CREATE_OR_UPDATE")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<MacroSettingsUIState>
---@param state MacroSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_CREATE_OR_UPDATE" then
		if CombatLockdown.IsActive() then
			ChatMessage.PrintUser(L["Can not create or update macros while in combat."])
			return
		elseif not Macro.CanCreate() then
			ChatMessage.PrintUser(L["Could not create macro as you already have too many. Delete one of your existing macros and try again."])
			return
		end

		-- Create or update the macro and binding
		local macroText = private.StateToMacroBody(state)
		Macro.CreateOrUpdate(MACRO_NAME, MACRO_ICON, macroText)
		Macro.UpdateBinding(MACRO_NAME, state.up, state.down, state.ctrl, state.alt, state.shift)

		state.hasExisting = true
		ChatMessage.PrintUser(L["Macro created and scroll wheel bound!"])
		if #macroText > MAX_MACRO_LENGTH then
			ChatMessage.PrintUser(L["WARNING: The macro was too long, so was truncated to fit by WoW."])
		end
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	-- Remove the TSMDestroy button from the macro since it's now part of our Bindings.xml instead
	local body = Macro.GetBody(MACRO_NAME)
	if body then
		body = gsub(body, "/click TSMDestroyBtn LeftButton 1\n", "")
		body = gsub(body, "\n/click TSMDestroyBtn LeftButton 1", "")
		body = gsub(body, "/click TSMDestroyBtn LeftButton 1", "")
		Macro.Update(MACRO_NAME, MACRO_ICON, body)
	end
	return true
end

---@param state MacroSettingsUIState
function private.StateToMacroBody(state)
	assert(not next(private.linesTemp))
	if state.myAuctionsCancel then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.myAuctionsCancel)
	end
	if state.auctioning then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.auctioning)
	end
	if state.shoppingBuyout then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.shoppingBuyout)
	end
	if state.bidBuyConfirm then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.bidBuyConfirm)
	end
	if state.sniper then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.sniper)
	end
	if state.crafting then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.crafting)
	end
	if state.vendoringSellAll then
		tinsert(private.linesTemp, "/click "..BUTTON_NAMES.vendoringSellAll)
	end
	local result = table.concat(private.linesTemp, "\n")
	wipe(private.linesTemp)
	return result
end

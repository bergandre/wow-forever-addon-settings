-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CraftingReports = App:Init("CraftingUI.CraftingReports")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local GlobalStrings = App:From("LibTSMWoW"):Include("Util.GlobalStrings")
local CraftingOperation = App:From("LibTSMSystem"):Include("CraftingOperation")
local Auction = App:From("LibTSMService"):Include("Auction")
local Crafting = App:From("LibTSMService"):Include("Crafting")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = App:From("LibTSMService"):Include("Profession")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local CustomPrice = App:From("LibTSMApp"):Include("Price.CustomPrice")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	settings = nil,
	manager = nil,
	craftProfessions = {},
	matProfessions = {},
}
local ALL_PROFESSIONS = L["All Professions"]
local MAT_PRICE_SOURCES = {GlobalStrings.Get("ALL"), L["Default Price"], L["Custom Price"]}
local STATE_SCHEMA = Reactive.CreateStateSchema("CraftingReportsUIState")
	:AddDeferredUIElementField("craftsScrollTable", "CraftsScrollTable")
	:AddDeferredUIElementField("matsScrollTable", "MatsScrollTable")
	:AddStringField("filterText", "")
	:AddOptionalStringField("profession")
	:AddOptionalStringField("matPriceSource")
	:AddBooleanField("craftableOnly", false)
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

AddonSettings.RegisterOnLoad(CraftingReports, function(db)
	private.settings = db:NewView("CraftingReportsSettings")
		:AddKey("global", "craftingOptions", "defaultMatCostMethod")
		:AddKey("global", "craftingUIContext", "craftsScrollingTable")
		:AddKey("global", "craftingUIContext", "matsScrollingTable")
		:AddKey("factionrealm", "internalData", "mats")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("CRAFTING_REPORTS", state, private.ActionHandler)
		:AddFrameBuilder(private.GetCraftingReportsFrame)
		:SuppressActionLog("ACTION_UPDATE_CRAFTS_CONTEXT")
		:SuppressActionLog("ACTION_UPDATE_MATS_CONTEXT")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the crafting frame.
---@return BaseFrame
function CraftingReports.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- CraftingReports UI
-- ============================================================================

---@param state CraftingReportsUIState
function private.GetCraftingReportsFrame(state)
	UIUtils.AnalyticsRecordPathChange("crafting", "crafting_reports")
	return UIElements.New("BaseFrame", "craftingReportsContent")
		:SetLayout("VERTICAL")
		:SetPadding(4)
		:SetManager(private.manager)
		:AddChild(UIElements.New("SegmentedTabGroup", "buttons")
			:SetContext(state)
			:SetNavCallback(private.GetTabElements)
			:AddPath(L["Crafts"], true)
			:AddPath(L["Materials"])
		)
end

function private.GetTabElements(tabGroup, path)
	local state = tabGroup:GetContext() ---@type CraftingReportsUIState
	state.filterText = ""
	state.profession = nil
	state.matPriceSource = nil
	state.craftableOnly = false
	if path == L["Crafts"] then
		UIUtils.AnalyticsRecordPathChange("crafting", "crafting_reports", "crafts")
		wipe(private.craftProfessions)
		tinsert(private.craftProfessions, ALL_PROFESSIONS)
		for _, player, profession in Profession.PlayerProfessionsIterator() do
			tinsert(private.craftProfessions, format("%s - %s", profession, player))
		end

		return UIElements.New("BaseFrame", "crafts")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("BaseFrame", "filters")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Input", "search")
					:SetMargin(0, 24, 0, 0)
					:AllowItemInsert()
					:SetLeadIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:SetHintText(L["Filter by keyword"])
					:BindValue(state, "filterText")
					:SetAction("OnValueChanged", "ACTION_UPDATE_CRAFTS_CONTEXT")
				)
				:AddChild(UIElements.New("ListDropdown", "profession")
					:SetWidth(180)
					:SetMargin(0, 24, 0, 0)
					:SetItems(private.craftProfessions)
					:MirrorSelectedItemState(state, "profession")
					:SetHintText(L["Filter by profession"])
					:SetAction("OnSelectionChanged", "ACTION_UPDATE_CRAFTS_CONTEXT")
				)
				:AddChild(UIElements.New("Checkbox", "craftable")
					:SetWidth("AUTO")
					:SetText(L["Only show craftable"])
					:MirrorIsCheckedState(state, "craftableOnly")
					:SetAction("OnValueChanged", "ACTION_UPDATE_CRAFTS_CONTEXT")
				)
			)
			:AddChild(UIElements.New("ListContainer", "content")
				:AddChild(UIElements.New("CraftsScrollTable", "crafts")
					:BindElement(state, "craftsScrollTable")
					:SetSettings(private.settings, "craftsScrollingTable")
					:SetQuery(Crafting.CreateCraftsQuery()
						:VirtualField("bagQuantity", "number", BagTracking.GetBagQuantity, "itemString")
						:VirtualField("auctionQuantity", "number", Auction.GetQuantity, "itemString")
						:VirtualField("firstOperation", "string", CraftingOperation.GetFirstOperationNameByItem, "itemString", "")
						:VirtualField("itemName", "string", ItemInfo.GetName, "itemString", "?")
					)
					:SetAction("OnQueueChanged", "ACTION_UPDATE_QUEUE")
				)
			)
	elseif path == L["Materials"] then
		UIUtils.AnalyticsRecordPathChange("crafting", "crafting_reports", "materials")
		wipe(private.matProfessions)
		tinsert(private.matProfessions, ALL_PROFESSIONS)
		for _, _, profession in Profession.PlayerProfessionsIterator() do
			if not private.matProfessions[profession] then
				tinsert(private.matProfessions, profession)
				private.matProfessions[profession] = true
			end
		end

		return UIElements.New("BaseFrame", "materials")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("BaseFrame", "filters")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Input", "search")
					:SetMargin(0, 24, 0, 0)
					:AllowItemInsert()
					:SetLeadIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:SetHintText(L["Filter by keyword"])
					:BindValue(state, "filterText")
					:SetAction("OnValueChanged", "ACTION_UPDATE_MATS_CONTEXT")
				)
				:AddChild(UIElements.New("ListDropdown", "profession")
					:SetWidth(180)
					:SetMargin(0, 24, 0, 0)
					:SetItems(private.matProfessions)
					:MirrorSelectedItemState(state, "profession")
					:SetHintText(L["Filter by profession"])
					:SetAction("OnSelectionChanged", "ACTION_UPDATE_MATS_CONTEXT")
				)
				:AddChild(UIElements.New("ListDropdown", "priceSource")
					:SetWidth(180)
					:SetItems(MAT_PRICE_SOURCES)
					:MirrorSelectedItemState(state, "matPriceSource")
					:SetHintText(L["Filter by price source"])
					:SetAction("OnSelectionChanged", "ACTION_UPDATE_MATS_CONTEXT")
				)
			)
			:AddChild(UIElements.New("ListContainer", "content")
				:AddChild(UIElements.New("MatsScrollTable", "mats")
					:BindElement(state, "matsScrollTable")
					:SetSettings(private.settings, "matsScrollingTable")
					:SetAction("OnRowClick", "ACTION_SHOW_MAT_DIALOG")
				)
			)
	else
		error("Unknown path: "..tostring(path))
	end
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<CraftingReportsUIState>
---@param state CraftingReportsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_CRAFTS_CONTEXT" then
		local name = String.Escape(strtrim(state.filterText))
		if name == "" then
			name = nil
		end
		local profession, player = nil, nil
		if state.profession and state.profession ~= ALL_PROFESSIONS then
			profession, player = strmatch(state.profession, "^(.+) %- (.+)$")
		end
		local craftableFilterFunc = state.craftableOnly and private.IsCraftableQueryFilter or nil
		state.craftsScrollTable:SetFilters(name, profession, player, craftableFilterFunc)
	elseif action == "ACTION_UPDATE_MATS_CONTEXT" then
		local name = String.Escape(strtrim(state.filterText))
		if name == "" then
			name = nil
		end
		local profession = state.profession ~= ALL_PROFESSIONS and state.profession or nil
		local hasCustomValue = nil
		if state.matPriceSource == MAT_PRICE_SOURCES[2] then
			hasCustomValue = false
		elseif state.matPriceSource == MAT_PRICE_SOURCES[3] then
			hasCustomValue = true
		end
		state.matsScrollTable:SetFilters(name, profession, hasCustomValue)
	elseif action == "ACTION_UPDATE_QUEUE" then
		local craftString, change = ...
		if CraftString.GetLevel(craftString) then
			return
		end
		Crafting.AdjustNumQueued(Crafting.GetCheapestRecipeString(craftString), change)
	elseif action == "ACTION_SHOW_MAT_DIALOG" then
		local itemString = ...
		state.matsScrollTable:GetBaseElement():ShowDialogFrame(UIElements.New("MatCostDialog", "dialog")
			:Configure(itemString, private.settings.mats[itemString].customValue, private.settings.defaultMatCostMethod, CustomPrice.Validate)
		)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsCraftableQueryFilter(craftString)
	return Crafting.GetNumCraftableFromDB(craftString) > 0
end

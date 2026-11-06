-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CraftingProfession = App:Init("CraftingUI.CraftingProfession")
local String = App:From("LibTSMUtil"):Include("Lua.String")
local SmartMap = App:From("LibTSMUtil"):IncludeClassType("SmartMap")
local Log = App:From("LibTSMUtil"):Include("Util.Log")
local Reactive = App:From("LibTSMReactive"):Include("Reactive")
local UIManager = App:From("LibTSMReactive"):IncludeClassType("UIManager")
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local TradeSkill = App:From("LibTSMWoW"):Include("API.TradeSkill")
local DelayTimer = App:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local SessionInfo = App:From("LibTSMWoW"):Include("Util.SessionInfo")
local CraftingService = App:From("LibTSMService"):Include("Crafting")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = App:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = App:From("LibTSMService"):Include("Item.ItemInfo")
local Profession = App:From("LibTSMService"):Include("Profession")
local TextureAtlas = App:From("LibTSMService"):Include("UI.TextureAtlas")
local CraftingUIUtils = App:From("LibTSMUI"):Include("Crafting.CraftingUIUtils")
local ItemLinked = App:From("LibTSMUI"):Include("Util.ItemLinked")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")
local CraftingApp = App:From("LibTSMApp"):Include("Crafting")
local AddonSettings = App:From("LibTSMApp"):Include("Service.AddonSettings")
local private = {
	manager = nil,
	settings = nil,
	professions = {},
	professionsKeys = {},
	professionSpells = {},
	showDelayTimer = nil,
	craftTimer = nil,
	craftResult = {
		success = nil,
		done = nil,
	},
}
local SHOW_DELAY_FRAMES = 2
local KEY_SEP = "\001"
local STATE_SCHEMA = Reactive.CreateStateSchema("CraftingProfessionUIState")
	:AddDeferredUIElementField("frame", "DividedContainer")
	:AddDeferredUIElementField("filterInput", "Input")
	:AddDeferredUIElementField("recipeList", "ProfessionScrollTable")
	:AddDeferredUIElementField("queueList", "CraftingQueueList")
	:AddDeferredUIElementField("professionDropdown", "SelectionDropdown")
	:AddDeferredUIElementField("filterBtn", "SmallTertiaryActionButton")
	:AddOptionalEnumField("professionType", TradeSkill.TYPE)
	:AddBooleanField("haveSkillUpFilter", false)
	:AddBooleanField("haveMaterialsFilter", false)
	:AddBooleanField("queueCanCraftNext", false)
	:AddNumberField("numQueued", 0)
	:AddOptionalStringField("selectedCraftString")
	:AddOptionalStringField("craftingRecipeString")
	:AddOptionalStringField("craftingCraftString")
	:AddOptionalNumberField("craftingQuantity")
	:AddOptionalEnumField("craftingSource", CraftingUIUtils.CRAFTING_SOURCE)
	:AddDeferredClassField("numCraftableItemStringSmartMap", SmartMap)
	:Commit()

---@event CraftingProfessionAction
---| "ACTION_FRAME_SHOW_DELAYED"
---| "ACTION_FRAME_HIDE"
---| "ACTION_OPEN_NO_PROFESSION"
---| "ACTION_PROFESSION_STATE_UPDATED"
---| "ACTION_PROFESSION_LOADED"
---| "ACTION_PROFESSION_UNLOADED"
---| "ACTION_FILTER_BUTTON_CLICKED"
---| "ACTION_HIDE_FILTER_DIALOG"
---| "ACTION_FILTER_DIALOG_ROW_CLICKED" -> id: string, checked: boolean
---| "ACTION_CLEAR_FILTERS"
---| "ACTION_RECIPE_FILTER_CHANGED"
---| "ACTION_QUEUE_BUTTON_CLICKED" -> recipeString: string, quantity: number
---| "ACTION_SELECT_CRAFT" -> craftString: string
---| "ACTION_RECIPE_SELECTION_CHANGED"
---| "ACTION_BAG_QUANTITY_UPDATED"
---| "ACTION_SKILL_UPDATE"
---| "ACTION_QUEUE_NEXT_CRAFT_CHANGED"
---| "ACTION_PREPARE_TO_CRAFT" -> recipeString: string, quantity: number, craftingSource: EnumValue, salvageSlotId?: number
---| "ACTION_START_CRAFT" -> recipeString: string, quantity: number, craftingSource: EnumValue, salvageSlotId?: number
---| "ACTION_HANDLE_CRAFT_DONE" -> success: boolean, isDone: boolean
---| "ACTION_DETAILS_CRAFT_BUTTON_CLICKED" -> recipeString: string, quantity: number, isVellum: boolean, salvageSlotId?: number
---| "ACTION_DETAILS_CRAFT_BUTTON_MOUSE_DOWN" -> recipeString: string, quantity: number, isVellum: boolean, salvageSlotId?: number
---| "ACTION_QUEUE_ROW_MOUSE_DOWN" -> recipeString: string
---| "ACTION_QUEUE_ROW_CLICK" -> recipeString: string, mouseButton: string
---| "ACTION_QUEUE_NUM_UPDATED" -> recipeString: string, num: number
---| "ACTION_CRAFT_NEXT_CLICK"
---| "ACTION_CLEAR_QUEUE"
---| "ACTION_SHOW_RESTOCK_DIALOG"
---| "ACTION_RESTOCK_GROUPS" -> groups: GroupPathValue[]
---| "ACTION_PROFESSION_SELECTION_CHANGED"



-- ============================================================================
-- Module Functions
-- ============================================================================

AddonSettings.RegisterOnLoad(CraftingProfession, function(db)
	private.settings = db:NewView("CraftingProfessionSettings")
		:AddKey("global", "craftingUIContext", "professionScrollingTable")
		:AddKey("global", "craftingUIContext", "professionDividedContainer")
		:AddKey("global", "craftingUIContext", "professionDividedContainerBottom")
		:AddKey("char", "craftingUIContext", "groupTree")
		:AddKey("factionrealm", "internalData", "isCraftFavorite")
		:Commit()

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	state.numCraftableItemStringSmartMap = SmartMap.New("string", "number", CraftingService.GetNumCraftableFromDBRecipeString)
	private.manager = UIManager.Create("CRAFTING_PROFESSION", state, private.ActionHandler)
		:SuppressActionLog("ACTION_SKILL_UPDATE")
		:SuppressActionLog("ACTION_RECIPE_FILTER_CHANGED")
		:SuppressActionLog("ACTION_BAG_QUANTITY_UPDATED")
		:AddFrameBuilder(private.GetCraftingFrame)

	-- Set up some computed state properties
	private.manager:SetStateFromPublisher("craftingCraftString", state:Publisher("craftingRecipeString")
		:MapNonNil(CraftString.FromRecipeString)
	)

	-- Set up some callbacks
	Profession.RegisterStateCallback(function()
		if Profession.GetCurrentProfession() and App.IsVanillaClassic() then
			TradeSkill.ShowOrHideDefaultUICraftButton()
		end
		private.manager:ProcessAction("ACTION_PROFESSION_STATE_UPDATED")
	end)
	local function ItemLinkedCallback(_, itemLink)
		if not state.frame then
			return
		end
		local itemString = ItemString.GetBase(itemLink)
		assert(itemString)
		state.filterInput
			:SetValue(ItemInfo.GetName(itemString) or "")
			:SetFocused(false)
		private.manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
		return true
	end
	ItemLinked.RegisterCallback(ItemLinkedCallback, true)
	Profession.RegisterHasScannedCallback(private.manager:CallbackToProcessAction("ACTION_PROFESSION_STATE_UPDATED"))
	BagTracking.RegisterQuantityCallback(private.manager:CallbackToProcessAction("ACTION_BAG_QUANTITY_UPDATED"))
	WarbankTracking.RegisterQuantityCallback(private.manager:CallbackToProcessAction("ACTION_BAG_QUANTITY_UPDATED"))

	-- Set up the show delay timer / frame hide handling
	private.showDelayTimer = DelayTimer.New("CRAFTING_SHOW_DELAY", private.manager:CallbackToProcessAction("ACTION_FRAME_SHOW_DELAYED"))
	private.manager:ProcessActionFromPublisher("ACTION_FRAME_HIDE", state:Publisher("frame")
		:IgnoreIfNotEquals(nil)
	)

	-- Set up the craft timer
	private.craftTimer = DelayTimer.New("CRAFTING_CRAFT", function()
		local success = private.craftResult.success
		local isDone = private.craftResult.isDone
		private.craftResult.success = nil
		private.craftResult.isDone = nil
		private.manager:ProcessAction("ACTION_HANDLE_CRAFT_DONE", success, isDone)
	end)

	-- Set up queries
	private.manager:SetStateFromPublisher("numQueued", CraftingService.CreateQueueQuery():Publisher()
		:Map("Count()")
	)
	local professionsQuery = Profession.CreatePlayerProfessionsQuery()
	private.manager:ProcessActionFromPublisher("ACTION_SKILL_UPDATE", professionsQuery:Publisher())
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the crafting frame.
---@return DividedContainer
function CraftingProfession.GetFrame()
	return private.manager:BuildFrame()
end



-- ============================================================================
-- Crafting UI
-- ============================================================================

---@param state CraftingProfessionUIState
function private.GetCraftingFrame(state)
	UIUtils.AnalyticsRecordPathChange("crafting", "crafting")
	private.showDelayTimer:RunForFrames(SHOW_DELAY_FRAMES)
	return UIElements.New("DividedContainer", "crafting")
		:SetMinWidth(200, (App.IsRetail() or App.IsForever()) and 189 or 156)
		:SetVertical()
		:HideDivider()
		:SetPadding(4)
		:SetSettingsContext(private.settings, "professionDividedContainerBottom")
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:SetTopChild(UIElements.New("DividedContainer", "top")
			:SetMinWidth(400, 200)
			:HideDivider()
			:SetMargin(0, 0, 0, 6)
			:SetSettingsContext(private.settings, "professionDividedContainer")
			:SetLeftChild(UIElements.New("BaseFrame", "left")
				:SetLayout("VERTICAL")
				:SetMargin(0, 2, 0, 0)
				:AddChild(UIElements.New("BaseFrame", "controls")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, 0, 8)
					:AddChild(UIElements.New(App.IsForever() and "SecureSelectionDropdown" or "SelectionDropdown", "professionDropdown")
						:SetWidth(220)
						:SetMargin(0, 8, 0, 0)
						:SetHintText(L["Select profession"])
						:BindElement(state, "professionDropdown")
						:SetAction("OnSelectionChanged", "ACTION_PROFESSION_SELECTION_CHANGED")
					)
					:AddChild(UIElements.New("Input", "filterInput")
						:SetMargin(0, 8, 0, 0)
						:SetLeadIconTexture("iconPack.18x18/Search")
						:SetClearButtonEnabled(true)
						:SetHintText(L["Search Patterns"])
						:BindElement(state, "filterInput")
						:SetAction("OnValueChanged", "ACTION_RECIPE_FILTER_CHANGED")
					)
					:AddChild(UIElements.New("SmallTertiaryActionButton", "filterBtn")
						:SetWidth(24)
						:SetMargin(0, 8, 0, 0)
						:SetText(TextureAtlas.GetTextureLink("iconPack.18x18/More/Horizontal"))
						:DisableClickCooldown()
						:SetHighlightLocked(state:Publisher([[haveSkillUpFilter or haveMaterialsFilter]]))
						:BindElement(state, "filterBtn")
						:SetAction("OnClick", "ACTION_FILTER_BUTTON_CLICKED")
					)
				)
				:AddChild(UIElements.New("ListContainer", "content")
					:AddChild(UIElements.New("ProfessionScrollTable", "recipeList")
						:SetSettings(private.settings, "professionScrollingTable", private.settings.isCraftFavorite)
						:BindElement(state, "recipeList")
						:SetAction("OnSelectionChanged", "ACTION_RECIPE_SELECTION_CHANGED")
					)
				)
			)
			:SetRightChild(UIElements.New("BaseFrame", "right")
				:SetLayout("VERTICAL")
				:SetMargin(4, 0, 0, 0)
				:AddChild(UIElements.New("SmallPrimaryActionButton", "restockDialog")
					:SetMargin(0, 0, 0, 8)
					:SetText(L["Restock Groups"])
					:SetAction("OnClick", "ACTION_SHOW_RESTOCK_DIALOG")
				)
				:AddChild(UIElements.New("ListContainer", "queue")
					:AddHeader(UIElements.New("BaseFrame", "header")
						:SetLayout("HORIZONTAL")
						:SetHeight(20)
						:SetPadding(8, 4, 0, 0)
						:AddChild(UIElements.New("Text", "title")
							:SetFont("BODY_XSMALL")
							:SetText(state:Publisher("numQueued"):ToStringFormat(L["Queue (%d)"]))
						)
						:AddChild(UIElements.New("CraftingQueueStatusIcon", "icon"))
					)
					:AddChild(UIElements.New("CraftingQueueList", "queueList")
						:SetMatIteratorFunc(CraftingService.MatIteratorByRecipeString)
						:SetQuery(CraftingService.CreateQueuedCraftsQuery(true)
							:VirtualSmartMapField("numCraftable", state.numCraftableItemStringSmartMap, "recipeString")
						)
						:BindElement(state, "queueList")
						:SetAction("OnRowMouseDown", "ACTION_QUEUE_ROW_MOUSE_DOWN")
						:SetAction("OnRowClick", "ACTION_QUEUE_ROW_CLICK")
						:SetAction("OnNumUpdated", "ACTION_QUEUE_NUM_UPDATED")
						:SetAction("OnNextCraftChanged", "ACTION_QUEUE_NEXT_CRAFT_CHANGED")
					)
					:AddFooter(UIElements.New("BaseFrame", "footer")
						:SetLayout("HORIZONTAL")
						:SetHeight(40)
						:SetPadding(8)
						:AddChild(UIElements.NewNamed("SmallPrimaryActionButton", "craftNextBtn", "TSMCraftingBtn")
							:SetMargin(0, 4, 0, 0)
							:SetText(L["Craft Next"])
							:SetPressed(state:Publisher([[craftingRecipeString and EnumEquals(craftingSource, "QUEUE_NEXT") or false]]))
							:SetDisabled(state:Publisher([[(not EnumEquals(professionType, "PLAYER") or not queueCanCraftNext or craftingRecipeString) and true or false]]))
							:SetAction("OnClick", "ACTION_CRAFT_NEXT_CLICK")
						)
						:AddChild(UIElements.New("SmallTertiaryActionButton", "clearBtn")
							:SetWidth("AUTO")
							:SetPadding(16, 16, 0, 0)
							:SetText(L["Clear All"])
							:SetAction("OnClick", "ACTION_CLEAR_QUEUE")
						)
					)
				)
			)
		)
		:SetBottomChild(UIElements.New("CraftDetails", "details")
			:SetSpellId(state:Publisher("selectedCraftString"):MapNonNil(CraftString.GetSpellId))
			:SetCraftingSource(state:Publisher([[selectedCraftString and craftingRecipeString and craftingSource or nil]]))
			:SetCraftingQuantity(state:Publisher([[craftingCraftString and craftingSource and (craftingCraftString == selectedCraftString and craftingQuantity or 1) or nil]]):IgnoreNil())
			:SetAction("OnCraftButtonClick", "ACTION_DETAILS_CRAFT_BUTTON_CLICKED")
			:SetAction("OnCraftButtonMouseDown", "ACTION_DETAILS_CRAFT_BUTTON_MOUSE_DOWN")
			:SetAction("OnQueueButtonClick", "ACTION_QUEUE_BUTTON_CLICKED")
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<CraftingProfessionUIState>
---@param state CraftingProfessionUIState
---@param action CraftingProfessionAction
---@param ... params<CraftingProfessionAction>
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW_DELAYED" then
		assert(not state.professionType)
		if private.IsProfessionLoaded() then
			return manager:ProcessAction("ACTION_PROFESSION_LOADED")
		else
			return manager:ProcessAction("ACTION_OPEN_NO_PROFESSION")
		end
	elseif action == "ACTION_FRAME_HIDE" then
		private.showDelayTimer:Cancel()
		manager:ProcessAction("ACTION_PROFESSION_UNLOADED")
		state.craftingRecipeString = nil
		state.craftingQuantity = nil
		state.craftingSource = nil
		state.selectedCraftString = nil
	elseif action == "ACTION_OPEN_NO_PROFESSION" then
		state.professionType = nil
		state.craftingRecipeString = nil
		state.craftingQuantity = nil
		state.craftingSource = nil
		private.UpdateProfessionsDropdown(state)
		state.queueList:HandleProfessionChange()
	elseif action == "ACTION_PROFESSION_STATE_UPDATED" then
		if not state.frame then
			return
		end
		local isProfessionLoaded = private.IsProfessionLoaded()
		if state.professionType and isProfessionLoaded then
			-- Switched professions
			state.frame:GetBaseElement():HideDialog()
			state.professionType = TradeSkill.GetType()
			private.UpdateProfessionsDropdown(state)
		elseif not state.professionType and not isProfessionLoaded then
			-- No change
		elseif isProfessionLoaded then
			-- Profession loaded
			manager:ProcessAction("ACTION_PROFESSION_LOADED")
		else
			-- Profession unloaded
			manager:ProcessAction("ACTION_PROFESSION_UNLOADED")
			manager:ProcessAction("ACTION_OPEN_NO_PROFESSION")
		end
	elseif action == "ACTION_PROFESSION_LOADED" then
		assert(not state.professionType)
		state.professionType = TradeSkill.GetType()
		state.filterInput
			:SetValue("")
			:SetFocused(false)
		local prevSelectedCraftString = state.selectedCraftString
		state.recipeList:SetQueryLoaded(true)
		if prevSelectedCraftString and Profession.GetIndexByCraftString(prevSelectedCraftString) then
			state.recipeList:SetSelectedCraft(prevSelectedCraftString)
		end
		private.UpdateProfessionsDropdown(state)
		state.queueList:HandleProfessionChange()
		manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
	elseif action == "ACTION_PROFESSION_UNLOADED" then
		state.professionType = nil
		state.haveSkillUpFilter = false
		state.haveMaterialsFilter = false
		if state.recipeList then
			state.recipeList:SetQueryLoaded(false)
		end
	elseif action == "ACTION_FILTER_BUTTON_CLICKED" then
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("BaseFrame", "dialog")
			:SetManager(manager)
			:AddChildNoLayout(UIElements.New("SmallTertiaryActionButton", "filterBtn")
				:AddAnchor("TOPLEFT", state.filterBtn)
				:AddAnchor("BOTTOMRIGHT", state.filterBtn)
				:SetText(TextureAtlas.GetTextureLink("iconPack.18x18/More/Horizontal"))
				:SetHighlightLocked(true)
				:SetAction("OnClick", "ACTION_HIDE_FILTER_DIALOG")
			)
			:AddChildNoLayout(UIElements.New("FilterMenuDialog", "menu")
				:AddAnchor("TOPRIGHT", state.filterBtn, "BOTTOMRIGHT", 0, -8)
				:SetTitle(L["Profession Filters"])
				:AddRow("SKILLUP", L["Has Skill Ups"], state.haveSkillUpFilter)
				:AddRow("MATS", L["Have Materials"], state.haveMaterialsFilter)
				:SetAction("OnRowClick", "ACTION_FILTER_DIALOG_ROW_CLICKED")
				:SetAction("OnClear", "ACTION_CLEAR_FILTERS")
			)
		)
	elseif action == "ACTION_HIDE_FILTER_DIALOG" then
		state.frame:GetBaseElement():HideDialog()
	elseif action == "ACTION_FILTER_DIALOG_ROW_CLICKED" then
		local id, checked = ...
		if id == "SKILLUP" then
			state.haveSkillUpFilter = checked
		elseif id == "MATS" then
			state.haveMaterialsFilter = checked
		else
			error("Unexpected id: "..tostring(id))
		end
		return manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
	elseif action == "ACTION_CLEAR_FILTERS" then
		state.haveSkillUpFilter = false
		state.haveMaterialsFilter = false
		return manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
	elseif action == "ACTION_RECIPE_FILTER_CHANGED" then
		local filterText = state.filterInput:GetValue()
		filterText = String.Escape(filterText)
		filterText = filterText ~= "" and filterText or nil
		state.recipeList:SetFilters(filterText, state.haveSkillUpFilter, state.haveMaterialsFilter)
	elseif action == "ACTION_QUEUE_BUTTON_CLICKED" then
		local recipeString, quantity = ...
		CraftingService.AdjustNumQueued(recipeString, quantity)
	elseif action == "ACTION_SELECT_CRAFT" then
		if not state.professionType then
			return
		end
		local craftString = ...
		if CraftingService.GetProfession(craftString) ~= Profession.GetCurrentProfession() then
			return
		end
		state.recipeList:SetSelectedCraft(craftString)
	elseif action == "ACTION_RECIPE_SELECTION_CHANGED" then
		state.frame:GetBaseElement():HideDialog()
		state.selectedCraftString = state.recipeList:GetSelectedCraft()
	elseif action == "ACTION_BAG_QUANTITY_UPDATED" then
		if not state.frame then
			return
		end
		state.numCraftableItemStringSmartMap:Invalidate()
		state.recipeList:UpdateData()
		state.queueList:UpdateData()
	elseif action == "ACTION_SKILL_UPDATE" then
		if not state.frame then
			return
		end
		state.professionType = TradeSkill.GetType()
		private.UpdateProfessionsDropdown(state)
	elseif action == "ACTION_QUEUE_NEXT_CRAFT_CHANGED" then
		if not state.frame then
			return
		end
		local recipeString, num = state.queueList:GetNextCraft()
		local craftString = recipeString and CraftString.FromRecipeString(recipeString)
		if recipeString and craftString and (not Profession.HasCraftString(craftString) or CraftingService.GetNumCraftableRecipeString(recipeString) == 0) then
			recipeString = nil
		end
		state.queueCanCraftNext = recipeString and true or false
		if recipeString and craftString and num then
			CraftingService.PrepareCraft(recipeString, num)
		end
	elseif action == "ACTION_PREPARE_TO_CRAFT" then
		local recipeString, quantity, craftingSource, salvageSlotId = ...
		state.craftingSource = craftingSource
		CraftingService.PrepareCraft(recipeString, quantity, salvageSlotId)
	elseif action == "ACTION_START_CRAFT" then
		local recipeString, quantity, craftingSource, salvageSlotId = ...
		local craftString = CraftString.FromRecipeString(recipeString)
		if state.craftingRecipeString or Profession.NeededTools(craftString) or (not salvageSlotId and CraftingService.GetNumCraftableRecipeString(recipeString) == 0) or Profession.GetRemainingCooldown(craftString) then
			return
		end
		state.craftingSource = craftingSource
		private.StartCraft(state, recipeString, quantity, salvageSlotId)
	elseif action == "ACTION_HANDLE_CRAFT_DONE" then
		local success, isDone = ...
		if success and state.craftingRecipeString then
			Log.Info("Crafted %s", state.craftingRecipeString)
			CraftingService.AdjustNumQueued(state.craftingRecipeString, -1)
			assert(state.craftingQuantity and state.craftingQuantity > 0)
			if state.craftingQuantity == 1 then
				assert(isDone)
			else
				state.craftingQuantity = state.craftingQuantity - 1
				isDone = false
			end
		else
			isDone = true
		end
		if isDone then
			state.craftingRecipeString = nil
			state.craftingQuantity = nil
			state.craftingSource = nil
		end
	elseif action == "ACTION_DETAILS_CRAFT_BUTTON_CLICKED" then
		local recipeString, quantity, isVellum, salvageSlotId = ...
		local craftingSource = isVellum and CraftingUIUtils.CRAFTING_SOURCE.VELLUM or CraftingUIUtils.CRAFTING_SOURCE.CRAFT
		if isVellum and not App.IsRetail() and not App.IsForever() then
			quantity = math.huge
		end
		return manager:ProcessAction("ACTION_START_CRAFT", recipeString, quantity, craftingSource, salvageSlotId)
	elseif action == "ACTION_DETAILS_CRAFT_BUTTON_MOUSE_DOWN" then
		local recipeString, quantity, isVellum, salvageSlotId = ...
		local craftingSource = isVellum and CraftingUIUtils.CRAFTING_SOURCE.VELLUM or CraftingUIUtils.CRAFTING_SOURCE.CRAFT
		if isVellum and not App.IsRetail() and not App.IsForever() then
			quantity = math.huge
		end
		return manager:ProcessAction("ACTION_PREPARE_TO_CRAFT", recipeString, quantity, craftingSource, salvageSlotId)
	elseif action == "ACTION_QUEUE_ROW_MOUSE_DOWN" then
		if state.craftingRecipeString or state.professionType ~= TradeSkill.TYPE.PLAYER then
			return
		end
		local recipeString = ...
		local craftString = CraftString.FromRecipeString(recipeString)
		if Profession.HasCraftString(craftString) then
			local quantity = CraftingService.GetNumQueued(recipeString)
			return manager:ProcessAction("ACTION_PREPARE_TO_CRAFT", recipeString, quantity, CraftingUIUtils.CRAFTING_SOURCE.QUEUE_CRAFT)
		end
	elseif action == "ACTION_QUEUE_ROW_CLICK" then
		if state.craftingRecipeString or state.professionType ~= TradeSkill.TYPE.PLAYER then
			return
		end
		local recipeString, mouseButton = ...
		local craftString = CraftString.FromRecipeString(recipeString)
		if mouseButton == "RightButton" then
			return manager:ProcessAction("ACTION_SELECT_CRAFT", craftString)
		elseif Profession.HasCraftString(craftString) then
			return manager:ProcessAction("ACTION_START_CRAFT", recipeString, CraftingService.GetNumQueued(recipeString), CraftingUIUtils.CRAFTING_SOURCE.QUEUE_CRAFT)
		end
	elseif action == "ACTION_QUEUE_NUM_UPDATED" then
		local recipeString, num = ...
		CraftingService.SetNumQueued(recipeString, num)
	elseif action == "ACTION_CRAFT_NEXT_CLICK" then
		local recipeString = state.queueList:GetNextCraft()
		assert(recipeString)
		private.manager:ProcessAction("ACTION_START_CRAFT", recipeString, CraftingService.GetNumQueued(recipeString), CraftingUIUtils.CRAFTING_SOURCE.QUEUE_NEXT)
	elseif action == "ACTION_CLEAR_QUEUE" then
		CraftingService.ClearQueue()
	elseif action == "ACTION_SHOW_RESTOCK_DIALOG" then
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("CraftingRestockDialog", "frame")
			:SetSize(540, 420)
			:AddAnchor("CENTER")
			:SetGroupTreeSettingsContext(private.settings, "groupTree")
			:SetManager(manager)
			:SetAction("OnRestockClick", "ACTION_RESTOCK_GROUPS")
		)
	elseif action == "ACTION_RESTOCK_GROUPS" then
		local groups = ...
		CraftingApp.RestockGroups(groups)
	elseif action == "ACTION_PROFESSION_SELECTION_CHANGED" then
		local key = state.professionDropdown:GetSelectedItemKey()
		if not key then
			return
		end
		local player, profession, skillId = strsplit(KEY_SEP, key)
		---@cast profession string?
		if not profession then
			-- The current linked / guild / NPC profession was re-selected, so just ignore this change
			return
		elseif profession == Profession.GetCurrentProfession() then
			-- The selection didn't change
			return
		end
		-- TODO: Support showing of other player's professions?
		assert(player == SessionInfo.GetCharacterName())
		if App.IsForever() then
			return
		end
		TradeSkill.OpenUI(not App.IsRetail() and profession or tonumber(skillId) --[[@as Enum.Profession]])
	else
		error("Unknown action: "..tostring(action))
	end
end

function private.IsProfessionLoaded()
	return not Profession.IsClosed() and Profession.GetCurrentProfession() and Profession.HasScanned() and Profession.ScannerHasSkills() and true or false
end

function private.StartCraft(state, recipeString, quantity, salvageSlotId)
	local numCrafted = CraftingService.ExecuteCraft(recipeString, quantity, state.craftingSource ~= CraftingUIUtils.CRAFTING_SOURCE.CRAFT, salvageSlotId, private.CraftCallback)
	Log.Info("Crafting %d (requested %s) of %s", numCrafted, quantity == math.huge and "all" or quantity, recipeString)
	if numCrafted == 0 then
		return
	end
	state.craftingRecipeString = recipeString
	state.craftingQuantity = numCrafted
end

function private.CraftCallback(success, isDone)
	private.craftResult.success = success
	private.craftResult.isDone = isDone
	private.craftTimer:RunForFrames(1)
end

---@param state CraftingProfessionUIState
function private.UpdateProfessionsDropdown(state)
	-- Update the professions dropdown info
	local dropdownSelection = nil
	local currentProfession = Profession.GetCurrentProfession()
	wipe(private.professions)
	wipe(private.professionsKeys)
	wipe(private.professionSpells)
	if currentProfession and state.professionType and state.professionType ~= TradeSkill.TYPE.PLAYER then
		assert(not App.IsVanillaClassic() and not App.IsBCClassic())
		local playerName = nil
		if state.professionType == TradeSkill.TYPE.LINKED then
			playerName = TradeSkill.GetLinkedPlayer() or "?"
		elseif state.professionType == TradeSkill.TYPE.NPC then
			playerName = L["NPC"]
		elseif state.professionType == TradeSkill.TYPE.GUILD then
			playerName = L["Guild"]
		end
		assert(playerName)
		tinsert(private.professions, currentProfession)
		local key = currentProfession
		tinsert(private.professionsKeys, key)
		dropdownSelection = key
	end

	for _, player, profession, skillId, level, maxLevel in Profession.PlayerProfessionsIterator() do
		if player == SessionInfo.GetCharacterName() then
			local isCurrentProfession = state.professionType == TradeSkill.TYPE.PLAYER and profession == currentProfession
			-- Skip station professions (no skillId) unless currently open since they can't be opened via the dropdown
			if (not App.IsRetail() and not App.IsForever()) or skillId > 0 or isCurrentProfession then
				if maxLevel == 0 then
					tinsert(private.professions, profession)
				else
					tinsert(private.professions, format("%s (%d/%d)", profession, level, maxLevel))
				end
				local key = player..KEY_SEP..profession..KEY_SEP..skillId
				tinsert(private.professionsKeys, key)
				if App.IsForever() then
					private.professionSpells[key] = TradeSkill.GetOpenUISpellName(profession)
				end
				if isCurrentProfession then
					assert(not dropdownSelection)
					dropdownSelection = key
				end
			end
		end
	end

	if App.IsForever() then
		local professionDropdown = state.professionDropdown --[[@as SecureSelectionDropdown]]
		professionDropdown:SetItems(private.professions, private.professionsKeys, private.professionSpells)
	else
		state.professionDropdown:SetItems(private.professions, private.professionsKeys)
	end
	state.professionDropdown
		:SetSelectedItemByKey(dropdownSelection, true)
		:Draw()
end

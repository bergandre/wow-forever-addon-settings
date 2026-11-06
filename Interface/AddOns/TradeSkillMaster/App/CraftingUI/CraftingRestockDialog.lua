-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Group = App:From("LibTSMTypes"):Include("Group")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {
	groupsTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingRestockDialog = UIElements.Define("CraftingRestockDialog", "BaseFrame")
CraftingRestockDialog:_AddActionScripts("OnRestockClick", "OnGroupSelectionChanged")
CraftingRestockDialog._STATE_SCHEMA = CraftingRestockDialog._STATE_SCHEMA:Extend("CraftingRestockDialogState")
	:AddDeferredUIElementField("groupTree", "ApplicationGroupTreeWithControls")
	:AddDeferredUIElementField("footerFrame", "BaseFrame")
	:AddBooleanField("selectionCleared", true)
	:AddNumberField("numItems", 0)
	:AddNumberField("numGroups", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftingRestockDialog:__init()
	self.__super:__init()
	self._filterText = ""
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_GROUP_SELECTION_CHANGED")
end

function CraftingRestockDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(8)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:SetMouseEnabled(true)
	for _ in self._state:WithAutoStorePaused() do
		self
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("Text", "title")
					:SetMargin(32, 8, 0, 0)
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetJustifyH("CENTER")
					:SetText(L["Restock TSM Groups"])
				)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetManager(self._childManager)
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("BaseFrame", "content")
				:SetLayout("VERTICAL")
				:SetBackgroundColor("container/low")
				:SetBorderColor("outline/variant")
				:SetPadding(1)
				:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
					:SetOperationType("Crafting")
					:SetManager(self._childManager)
					:BindElement(self._state, "groupTree")
					:SetAction("OnGroupSelectionChanged", "ACTION_GROUP_SELECTION_CHANGED")
				)
				:AddChild(UIElements.New("BaseFrame", "footer")
					:SetLayout("HORIZONTAL")
					:SetHeight(26)
					:BindElement(self._state, "footerFrame")
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "groupsText")
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetJustifyH("RIGHT")
						:SetText(self._state:Publisher("numGroups"):ToStringFormat(L["%d Groups Selected"]))
					)
					:AddChild(UIElements.New("Text", "itemsText")
						:SetWidth("AUTO")
						:SetMargin(16, 8, 0, 0)
						:SetFont("BODY_SMALL_SEMIBOLD")
						:SetJustifyH("RIGHT")
						:SetText(self._state:Publisher("numItems"):ToStringFormat(L["Total Items"]..": %d"))
					)
				)
			)
			:AddChild(UIElements.New("MediumPrimaryActionButton", "restockBtn")
				:SetMargin(0, 0, 8, 0)
				:SetText(L["Restock Groups"])
				:SetDisabled(self._state:Publisher("selectionCleared"))
				:SetManager(self._childManager)
				:SetAction("OnClick", "ACTION_RESTOCK_CLICKED")
			)
	end
end

function CraftingRestockDialog:Release()
	self._filterText = ""
	self.__super:Release()
end

---Sets the context table from a settings object for the group tree.
---@param settings SettingsView The settings object
---@param key string The setting key
---@return self
function CraftingRestockDialog:SetGroupTreeSettingsContext(settings, key)
	self._state.groupTree:SetSettingsContext(settings, key)
	self._childManager:ProcessAction("ACTION_GROUP_SELECTION_CHANGED")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<CraftingRestockDialogState>
---@param state CraftingRestockDialogState
function CraftingRestockDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_GROUP_SELECTION_CHANGED" then
		state.selectionCleared = state.groupTree:IsSelectionCleared()
		local numGroups, numItems = 0, 0
		for _, groupPath in state.groupTree:SelectedGroupsIterator() do
			numGroups = numGroups + 1
			if groupPath ~= Group.GetRootPath() then
				numItems = numItems + Group.GetNumItems(groupPath)
			end
		end
		state.numGroups = numGroups
		state.numItems = numItems
		state.footerFrame:Draw()
	elseif action == "ACTION_RESTOCK_CLICKED" then
		assert(not next(private.groupsTemp))
		for _, groupPath in state.groupTree:SelectedGroupsIterator() do
			tinsert(private.groupsTemp, groupPath)
		end
		self:_SendActionScript("OnRestockClick", private.groupsTemp)
		wipe(private.groupsTemp)
		return manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end

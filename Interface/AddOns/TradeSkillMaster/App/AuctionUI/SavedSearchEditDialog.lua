-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SavedSearchEditDialog = UIElements.Define("SavedSearchEditDialog", "BaseFrame")
SavedSearchEditDialog._STATE_SCHEMA = SavedSearchEditDialog._STATE_SCHEMA:Extend("SavedSearchEditDialogState")
	:AddDeferredUIElementField("nameInput", "Input")
	:AddStringField("name", "")
	:AddOptionalNumberField("index")
	:Commit()
SavedSearchEditDialog:_AddActionScripts("OnNameChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SavedSearchEditDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._index = nil
end

function SavedSearchEditDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(8)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("Text", "title")
			:SetHeight(30)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetJustifyH("CENTER")
			:SetText(L["Rename Search"])
		)
		self:AddChild(UIElements.New("Input", "nameInput")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 8)
			:AllowItemInsert(true)
			:BindElement(self._state, "nameInput")
			:MirrorValueState(self._state, "name")
			:SetManager(self._childManager)
			:SetAction("OnEnterPressed", "ACTION_ENTER_PRESSED")
		)
		self:AddChild(UIElements.New("BaseFrame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("MediumPrimaryActionButton", "closeBtn")
				:SetWidth(126)
				:SetText(CLOSE)
				:SetAction("OnClick", "ACTION_CLOSE")
			)
		)
	end
end

function SavedSearchEditDialog:Release()
	self.__super:Release()
	self._index = nil
end

---Configures the saved search being edited.
---@param name string The name of the saved search
---@param index number The index of the saved search
---@return self
function SavedSearchEditDialog:Configure(name, index)
	self._state.name = name
	self._state.index = index
	return self
end

---Sets whether or not the name input is focused.
---@param focused boolean Whether or not the name input is focused
---@return self
function SavedSearchEditDialog:SetNameInputFocused(focused)
	self._state.nameInput:SetFocused(focused)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param state SavedSearchEditDialogState
function SavedSearchEditDialog.__private:_ActionHandler(_, state, action, ...)
	if action == "ACTION_ENTER_PRESSED" then
		if state.name == "" then
			return
		end
		self:_SendActionScript("OnNameChanged", state.name, state.index)
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_CLOSE" then
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

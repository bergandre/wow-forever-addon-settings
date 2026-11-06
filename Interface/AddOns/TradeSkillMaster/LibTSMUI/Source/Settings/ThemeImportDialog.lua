-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ThemeImportDialog = ComponentRegistry.Define("ThemeImportDialog", "BaseFrame")
ThemeImportDialog._STATE_SCHEMA = ThemeImportDialog._STATE_SCHEMA:Extend("ThemeImportDialogState")
	:AddStringField("value", "")
	:Commit()
ThemeImportDialog:_AddActionScripts("OnImport")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ThemeImportDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function ThemeImportDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(540, 250)
	self:SetPadding(12)
	self:AddAnchor("CENTER")
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:SetMouseEnabled(true)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 12)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Import Theme"])
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		self:AddChild(UIElements.New("Text", "desc")
			:SetHeight(40)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_XSMALL")
			:SetText(L["You can import custom themes by pasting an import string into the box below."])
		)
		self:AddChild(UIElements.New("Text", "text")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 8)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(L["Import String"])
		)
		self:AddChild(UIElements.New("MultiLineInput", "input")
			:SetMargin(0, 0, 0, 12)
			:SetFocused(true)
			:SetPasteMode()
			:MirrorValueState(self._state, "value")
			:SetManager(self._childManager)
			:SetAction("OnValueChanged", "ACTION_IMPORT_VALUE")
		)
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<ThemeImportDialogState>
---@param state ThemeImportDialogState
function ThemeImportDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_IMPORT_VALUE" then
		local value = strtrim(state.value)
		self:_SendActionScript("OnImport", value)
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

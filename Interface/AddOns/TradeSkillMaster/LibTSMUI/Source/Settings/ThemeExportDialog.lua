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

local ThemeExportDialog = ComponentRegistry.Define("ThemeExportDialog", "BaseFrame")
ThemeExportDialog._STATE_SCHEMA = ThemeExportDialog._STATE_SCHEMA:Extend("ThemeExportDialogState")
	:AddDeferredUIElementField("input", "MultiLineInput")
	:AddStringField("value", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ThemeExportDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function ThemeExportDialog:Acquire()
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
				:SetText(L["Export Custom Theme"])
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		self:AddChild(UIElements.New("Text", "desc")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_XSMALL")
			:SetText(L["You can use the export string below to share this custom theme with others."])
		)
		self:AddChild(UIElements.New("Text", "heading")
			:SetMargin(0, 0, 0, 8)
			:SetHeight(20)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(L["Export String"])
		)
		self:AddChild(UIElements.New("MultiLineInput", "input")
			:BindElement(self._state, "input")
			:SetManager(self._childManager)
			:SetValue(self._state:Publisher("value"))
			:SetAction("OnValueChanged", "ACTION_ENTER_PRESSED")
		)
	end
end

---Sets the export string to display.
---@param value string The export string
---@return self
function ThemeExportDialog:SetValue(value)
	self._state.value = value
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<ThemeExportDialogState>
---@param state ThemeExportDialogState
function ThemeExportDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_ENTER_PRESSED" then
		state.input
			:SetValue(self._state.value)
			:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end

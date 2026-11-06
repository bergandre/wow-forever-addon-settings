-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local UIUtils = App:From("LibTSMUI"):Include("Util.UIUtils")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailSendTextDialog = UIElements.Define("MailSendTextDialog", "BaseFrame")
MailSendTextDialog._STATE_SCHEMA = MailSendTextDialog._STATE_SCHEMA:Extend("MailSendTextDialogState")
	:AddDeferredUIElementField("subjectInput", "Input")
	:AddDeferredUIElementField("bodyInput", "MultiLineInput")
	:AddStringField("subject", "")
	:AddStringField("body", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailSendTextDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function MailSendTextDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(478, 314)
	self:SetPadding(12)
	self:AddAnchor("CENTER")
	self:SetRoundedBackgroundColor("container/low")
	for _ in self._state:WithAutoStorePaused() do
		local textEmptyPublisher = self._state:Publisher([[subject == "" and body == ""]])
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 14)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Add Subject / Description"])
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
			)
		)
		self:AddChild(UIElements.New("Text", "subjectText")
			:SetMargin(0, 0, 0, 4)
			:SetHeight(20)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(L["Subject"])
		)
		self:AddChild(UIElements.New("Input", "subjectInput")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:SetMaxLetters(64)
			:SetClearButtonEnabled(true)
			:BindElement(self._state, "subjectInput")
			:MirrorValueState(self._state, "subject")
		)
		self:AddChild(UIElements.New("Text", "descriptionText")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 4)
			:SetFont("BODY_SMALL_SEMIBOLD")
			:SetText(DESCRIPTION)
		)
		self:AddChild(UIElements.New("MultiLineInput", "bodyInput")
			:SetIgnoreEnter()
			:SetMaxLetters(500)
			:BindElement(self._state, "bodyInput")
			:MirrorValueState(self._state, "body")
		)
		self:AddChild(UIElements.New("BaseFrame", "footer")
			:SetLayout("HORIZONTAL")
			:SetMargin(0, 0, 4, 12)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Text", "text")
				:SetHeight(20)
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_XSMALL")
				:SetJustifyH("RIGHT")
				:SetText(self._state:PublisherForFunctionWithKeys(strlenutf8, "body"):ToStringFormat(L["(%d/500 Characters)"]))
			)
			:AddChild(UIElements.New("SmallTertiaryActionButton", "clearAll")
				:SetWidth("AUTO")
				:SetPadding(8, 8, 0, 0)
				:SetText(L["Clear All"])
				:SetDisabled(textEmptyPublisher)
				:SetAction("OnClick", "ACTION_CLEAR_ALL")
			)
		)
		self:AddChild(UIElements.New("MediumPrimaryActionButton", "addMailBtn")
			:SetManager(self._childManager)
			:SetText(L["Add to Mail"])
			:SetDisabled(textEmptyPublisher)
			:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
		)
		self:AddCancellable(textEmptyPublisher:EndShare())
	end
	UIUtils.ConfigureInputTabNavigation(self._state.subjectInput, self._state.bodyInput)
end

---Mirrors the text content state.
---@param state ReactiveState The state to mirror with
---@param subjectKey string The state key to for the subject value
---@param bodyKey string The state key for the body value
---@return self
function MailSendTextDialog:MirrorTextContentState(state, subjectKey, bodyKey)
	self._state.subject = state[subjectKey]
	self._state.body = state[bodyKey]
	self._state:Publisher("subject")
		:AssignToTableKey(state, subjectKey)
	self._state:Publisher("body")
		:AssignToTableKey(state, bodyKey)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<MailSendTextDialogState>
---@param state MailSendTextDialogState
function MailSendTextDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_CLEAR_ALL" then
		state.subject = ""
		state.body = ""
		state.subjectInput:SetFocused(false)
		state.bodyInput:SetFocused(false)
	else
		error("Unknown action: "..tostring(action))
	end
end
